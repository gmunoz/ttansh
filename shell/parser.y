/* Yacc grammar for bash. */

/* Copyright (C) 1989-2004 Free Software Foundation, Inc.

   This file is part of GNU Bash, the Bourne Again SHell.

   Bash is free software; you can redistribute it and/or modify it under
   the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 2, or (at your option) any later
   version.

   Bash is distributed in the hope that it will be useful, but WITHOUT ANY
   WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
   for more details.

   You should have received a copy of the GNU General Public License along
   with Bash; see the file LICENSE.  If not, write to the Free Software
   Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA. */

%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include "list.h"
#include "cmd.h"
#include "redirect.h"
#include "alias.h"
#include "job.h"
#include "chartypes.h"
#include "error.h"
#include "config.h"

static int interactive = 1;
static struct expr_t *command = NULL;

/* External lex/yacc variables/functions */
static FILE *yyin;
int yylex(void);
extern void  yyrestart(FILE *);
extern void  yyerror(char *s);
%}

%union {
  struct word_desc_t *word;
  int number;
  struct list_t *word_list;
  struct expr_t *command;
  struct redirect_t *redirect;
	struct list_t *redirection_list;
  struct element_t element;
  /*PATTERN_LIST *pattern; A list of patterns (WORD_LIST and COMMAND)*/
}

%token <internal_command> INTERNAL_COMMAND

/* Reserved words.  Members of the first group are only recognized
   in the case that they are preceded by a list_terminator.  Members
   of the second group are for [[...]] commands.  Members of the
   third group are recognized only under special circumstances. */
%token IF THEN ELSE ELIF FI CASE ESAC FOR SELECT WHILE UNTIL DO DONE FUNCTION
%token COND_START COND_END COND_ERROR
%token IN BANG TIME TIMEOPT

/* More general tokens. yylex () knows how to make these. */
%token <word> WORD ASSIGNMENT_WORD
%token <number> NUMBER
%token <word_list> ARITH_CMD ARITH_FOR_EXPRS
%token <command> COND_CMD
%token AND_AND OR_OR GREATER_GREATER LESS_LESS LESS_AND LESS_LESS_LESS
%token GREATER_AND SEMI_SEMI LESS_LESS_MINUS AND_GREATER LESS_GREATER
%token GREATER_BAR

%token NEWLINE        /* '\n' */
%token PIPE AMPERSAND SEMICOLON LESSER GREATER MINUS
%token LEFT_PARENTH RIGHT_PARENTH LEFT_CURLY RIGHT_CURLY
%token EQUALS

/* The types that the various syntactical units return. */

/* -- VERIFIED -- */
%type <element> simple_command_element
%type <command> simple_command command pipeline
%type <command> simple_list1 simple_list
%type <command> inputunit pipeline_command
%type <redirect> redirection
%type <redirection_list> redirection_list
%type <command> if_command elif_clause for_command
%type <command> while_command until_command
%type <command> shell_command group_command
%type <command> list list0 list1 compound_list
%type <command> function_def function_body

/* -- UNVERIFIED -- */
%type <command> select_command case_command
%type <command> arith_command
%type <command> cond_command
%type <command> arith_for_command
%type <command> subshell
%type <word_list> word_list pattern
%type <pattern> pattern_list case_clause_sequence case_clause
%type <number> timespec
%type <number> list_terminator

%start inputunit

%left AMPERSAND SEMICOLON NEWLINE yacc_EOF
%left AND_AND OR_OR
%right PIPE
%%

inputunit:	simple_list simple_list_terminator
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "inputunit 0 matched\n");
#endif
		command = $1;
		if (interactive)
			YYACCEPT;
	}
	|	inputunit simple_list simple_list_terminator
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "inputunit 1 matched\n");
#endif
		cmd_append($1, $2);
		if (interactive)
			YYACCEPT;
	}
	|	NEWLINE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "inputunit 2 matched\n");
#endif
		if (interactive)
			YYACCEPT;
	}
	|	error NEWLINE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "inputunit 3 matched\n");
#endif
		if (interactive)
			YYACCEPT;
		else
			YYABORT;
	}
	|	yacc_EOF
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "inputunit 4 matched\n");
#endif
		if (interactive)
			YYACCEPT;
	}
	;

word_list:	WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "word_list 0 matched\n");
#endif
		err_msg(" => %s", $1);
		$$ = list_create(free);
		if (!$$) {
			err_msg("error: [yyparse] Unable to create word list.");
			YYABORT;
		}
		list_push($$, $1);
	}
	|	word_list WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "word_list 1 matched\n");
#endif
		list_push($$, $2);
	}
	;

redirection:	GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 0 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_OUTPUT;
		$$->output_filename = $2->word;
	}
	|	LESSER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 1 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_INPUT;
		$$->input_filename = $2->word;
	}
	|	NUMBER GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 2 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_OUTPUT;
		$$->output_filename = $3->word;
		$$->output_fd = $1;
	}
	|	NUMBER LESSER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 3 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_INPUT;
		$$->input_filename = $3->word;
		$$->input_fd = $1;
	}
	|	GREATER_GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 4 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_CONCAT;
		$$->concat_filename = $2->word;
	}
	|	NUMBER GREATER_GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 5 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_CONCAT;
		$$->concat_filename = $3->word;
		$$->output_fd = $1;
	}
	|	LESS_LESS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 6 matched\n");
#endif
		$$ = redirect_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection.");
			YYABORT;
		}
		$$->type = REDIRECT_INPUT;
		$$->input_filename = $2->word;
	}
	|	NUMBER LESS_LESS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 7 matched\n");
#endif
	}
	|	LESS_LESS_LESS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 8 matched\n");
#endif
	}
	|	NUMBER LESS_LESS_LESS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 9 matched\n");
#endif
	}
	|	LESS_AND NUMBER
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 10 matched\n");
#endif
	}
	|	NUMBER LESS_AND NUMBER
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 11 matched\n");
#endif
	}
	|	GREATER_AND NUMBER
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 12 matched\n");
#endif
	}
	|	NUMBER GREATER_AND NUMBER
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 13 matched\n");
#endif
	}
	|	LESS_AND WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 14 matched\n");
#endif
	}
	|	NUMBER LESS_AND WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 15 matched\n");
#endif
	}
	|	GREATER_AND WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 16 matched\n");
#endif
	}
	|	NUMBER GREATER_AND WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 17 matched\n");
#endif
	}
	|	LESS_LESS_MINUS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 18 matched\n");
#endif
	}
	|	NUMBER LESS_LESS_MINUS WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 19 matched\n");
#endif
	}
	|	GREATER_AND MINUS
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 20 matched\n");
#endif
	}
	|	NUMBER GREATER_AND MINUS
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 21 matched\n");
#endif
	}
	|	LESS_AND MINUS
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 22 matched\n");
#endif
	}
	|	NUMBER LESS_AND MINUS
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 23 matched\n");
#endif
	}
	|	AND_GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 24 matched\n");
#endif
	}
	|	NUMBER LESS_GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 25 matched\n");
#endif
	}
	|	LESS_GREATER WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 26 matched\n");
#endif
	}
	|	GREATER_BAR WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 27 matched\n");
#endif
	}
	|	NUMBER GREATER_BAR WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection 28 matched\n");
#endif
	}
	;

simple_command_element: WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command_element 0 matched\n");
		fprintf(stderr, " => Found WORD '%s'\n", $1->word);
#endif
		$$.word = $1->word;
	}
	|	ASSIGNMENT_WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command_element 1 matched\n");
#endif
		/* TODO: Parse an assignment word:
		 *   <assignment_word> ::= <word> '=' <word> */
		//$$.word = $1;
		//$$.redirect = NULL;
	}
	/*| WORD EQUALS pipeline_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command_element 1 matched\n");
#endif
	}*/
	|	redirection
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command_element 2 matched\n");
#endif
		$$.word = NULL;
		$$.redirect = $1;
	}
	;

redirection_list: redirection
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection_list 0 matched\n");
#endif
		$$ = list_create(redirect_destroy);
		if (!$$) {
			err_msg("error: [yyparse] Unable to create redirection list.");
			YYABORT;
		}
		list_push($$, $1);
	}
	|	redirection_list redirection
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "redirection_list 1 matched\n");
#endif
		list_push($1, $2);
		$$ = $1;
	}
	;

simple_command:	simple_command_element
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command 0 matched\n");
#endif
		/* Reached a terminal node. Create a new command. */
		$$ = cmd_create();
		if (!$$) {
			err_msg("error: [yyparse] Unable to create simple command.");
			YYABORT;
		}

		/* Store the word that has been parsed into the exec list. */
		cmd_set_type($$, CMD_SIMPLE);
		list_push($$->exec, $1.word);
		list_push($$->redirects, $1.redirect);
	}
	|	simple_command simple_command_element
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_command 1 matched\n");
#endif
		$$ = $1;
		/* If the element is only a redirect (i.e. word is NULL), then
		 * don't store the word as part of the exec parameters. */
		if ($2.word)
			list_push($$->exec, $2.word);
		list_push($$->redirects, $2.redirect);
	}
	;

command:	simple_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "command 0 matched\n");
#endif
		cmd_set_type($1, CMD);
		$$ = $1;
	}
	|	shell_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "command 1 matched\n");
#endif
		cmd_set_type($1, CMD);
		$$ = $1;
	}
	|	shell_command redirection_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "command 2 matched\n");
#endif
		cmd_set_type($1, CMD);
		$$ = $1;
		$$->redirects = $2;
	}
	|	function_def
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "command 3 matched\n");
#endif
		cmd_set_type($1, CMD);
		$$ = $1;
	}
	;

shell_command:	for_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 0 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	case_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 1 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	| while_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 2 matched\n");
#endif
		$$ = $1;
	}
	| until_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 3 matched\n");
#endif
		$$ = $1;
	}
	|	select_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 4 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	if_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 5 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	subshell
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 6 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	group_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 7 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	arith_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 8 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	cond_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 9 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	|	arith_for_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "shell_command 10 matched\n");
#endif
		cmd_set_type($1, CMD_SHELL);
		$$ = $1;
	}
	;

for_command:	FOR WORD IN command newline_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "for_command 0 matched\n");
#endif
		$$ = $4;
		cmd_mark_block($7);
		cmd_append($4, $7);
		cmd_set_type($4, CMD_FOR);
		cmd_set_type($4, CMD_IN);
		list_unshift($4->exec, $2); /* Push variable name onto the head */
	}
	| FOR command newline_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "for_command 1 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($5);
		cmd_append($2, $5);
		cmd_set_type($2, CMD_FOR);
	}
	;

arith_for_command:	FOR ARITH_FOR_EXPRS list_terminator newline_list DO compound_list DONE
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "arith_for_command 0 matched\n");
#endif
		}
	|		FOR ARITH_FOR_EXPRS list_terminator newline_list LEFT_CURLY compound_list RIGHT_CURLY
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "arith_for_command 1 matched\n");
#endif
		}
	|		FOR ARITH_FOR_EXPRS DO compound_list DONE
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "arith_for_command 2 matched\n");
#endif
		}
	|		FOR ARITH_FOR_EXPRS LEFT_CURLY compound_list RIGHT_CURLY
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "arith_for_command 3 matched\n");
#endif
		}
	;

while_command:	WHILE command newline_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "while_command 0 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($5);
		cmd_append($2, $5);
		cmd_set_type($2, CMD_WHILE);
	}
	;

until_command:	UNTIL command newline_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "until_command 0 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($5);
		cmd_append($2, $5);
		cmd_set_type($2, CMD_UNTIL);
	}
	;

select_command:	SELECT WORD newline_list DO list DONE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 0 matched\n");
#endif
	}
	|	SELECT WORD newline_list LEFT_CURLY list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 1 matched\n");
#endif
	}
	|	SELECT WORD SEMICOLON newline_list DO list DONE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 2 matched\n");
#endif
	}
	|	SELECT WORD SEMICOLON newline_list LEFT_CURLY list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 3 matched\n");
#endif
	}
	|	SELECT WORD newline_list IN word_list list_terminator newline_list DO list DONE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 4 matched\n");
#endif
	}
	|	SELECT WORD newline_list IN word_list list_terminator newline_list LEFT_CURLY list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "select_command 5 matched\n");
#endif
	}
	;

case_command:	CASE WORD newline_list IN newline_list ESAC
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_command 0 matched\n");
#endif
	}
	|	CASE WORD newline_list IN case_clause_sequence newline_list ESAC
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_command 1 matched\n");
#endif
	}
	|	CASE WORD newline_list IN case_clause ESAC
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_command 2 matched\n");
#endif
	}
	;

function_def:	WORD LEFT_PARENTH RIGHT_PARENTH newline_list function_body
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "function_def 0 matched\n");
#endif
		$$ = $5;
		list_unshift($5->exec, $1); /* Put func name on top of exec list. */
	}
	|	FUNCTION WORD LEFT_PARENTH RIGHT_PARENTH newline_list function_body
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "function_def 1 matched\n");
#endif
		$$ = $6;
		list_unshift($6->exec, $2); /* Put func name on top of exec list. */
	}
	|	FUNCTION WORD newline_list function_body
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "function_def 2 matched\n");
#endif
		$$ = $4;
		list_unshift($4->exec, $2); /* Put func name on top of exec list. */
	}
	;


function_body:	shell_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "function_body 0 matched\n");
#endif
		$$ = $1;
		cmd_mark_function($1);
	}
	|	shell_command redirection_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "function_body 1 matched\n");
#endif
		cmd_mark_function($1);
		$1->redirects = $2;
	}
	;

subshell:	LEFT_PARENTH compound_list RIGHT_PARENTH
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "subshell 0 matched\n");
#endif
		$$ = $2;
		cmd_set_type($2, CMD_SUBSHELL);
	}
	;

if_command:	IF compound_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "if_command 0 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_append($2, $4);
		cmd_set_type($2, CMD_IF);
	}
	|	IF compound_list LEFT_CURLY compound_list RIGHT_CURLY ELSE LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "if_command 1 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_mark_block($8);
		cmd_append($2, $4);
		cmd_append($4, $8);
		cmd_set_type($2, CMD_IF);
		cmd_set_type($8, CMD_ELSE);
	}
	|	IF compound_list LEFT_CURLY compound_list RIGHT_CURLY elif_clause
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "if_command 2 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_append($2, $4);
		cmd_append($4, $6);
		cmd_set_type($2, CMD_IF);
	}
	;


group_command: LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "group_command 0 matched\n");
#endif
		$$ = $2;
		cmd_set_type($2, CMD_GROUP);
	}
	;

arith_command:	ARITH_CMD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "arith_command 0 matched\n");
#endif
	}
	;

cond_command:	COND_START COND_CMD COND_END
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "cond_command 0 matched\n");
#endif
	}
	; 

elif_clause:	ELIF compound_list LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "elif_clause 0 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_append($2, $4);
		cmd_set_type($2, CMD_ELSE_IF);
	}
	|	ELIF compound_list LEFT_CURLY compound_list RIGHT_CURLY ELSE LEFT_CURLY compound_list RIGHT_CURLY
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "elif_clause 1 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_mark_block($8);
		cmd_append($2, $4);
		cmd_append($4, $8);
		cmd_set_type($2, CMD_ELSE_IF);
		cmd_set_type($8, CMD_ELSE);
	}
	|	ELIF compound_list LEFT_CURLY compound_list RIGHT_CURLY elif_clause
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "elif_clause 2 matched\n");
#endif
		$$ = $2;
		cmd_mark_block($4);
		cmd_append($2, $4);
		cmd_append($4, $6);
		cmd_set_type($2, CMD_ELSE_IF);
	}
	;

case_clause:	pattern_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_clause 0 matched\n");
#endif
	}
	|	case_clause_sequence pattern_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_clause 1 matched\n");
#endif
	}
	;

pattern_list:	newline_list pattern RIGHT_PARENTH compound_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern_list 0 matched\n");
#endif
	}
	|	newline_list pattern RIGHT_PARENTH newline_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern_list 1 matched\n");
#endif
	}
	|	newline_list LEFT_PARENTH pattern RIGHT_PARENTH compound_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern_list 2 matched\n");
#endif
	}
	|	newline_list LEFT_PARENTH pattern RIGHT_PARENTH newline_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern_list 3 matched\n");
#endif
	}
	;

case_clause_sequence:  pattern_list SEMI_SEMI
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_clause_sequence 0 matched\n");
#endif
	}
	|	case_clause_sequence pattern_list SEMI_SEMI
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "case_clause_sequence 1 matched\n");
#endif
	}
	;

pattern:	WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern 0 matched\n");
#endif
	}
	|	pattern PIPE WORD
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pattern 1 matched\n");
#endif
	}
	;

/* A list allows leading or trailing newlines and
   newlines as operators (equivalent to semicolons).
   It must end with a newline or semicolon.
   Lists are used within commands such as if, for, while.  */

list:		newline_list list0
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list 0 matched\n");
#endif
		$$ = $2;
	}
	;

compound_list:	list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "compound_list 0 matched\n");
#endif
		$$ = $1;
	}
	|	newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "compound_list 1 matched\n");
#endif
		$$ = $2;
	}
	;

list0:  	list1 NEWLINE newline_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list0 0 matched\n");
#endif
		$$ = $1;
	}
	|	list1 AMPERSAND newline_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list0 1 matched\n");
#endif
	}
	|	list1 SEMICOLON newline_list
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list0 2 matched\n");
#endif
	}

	;

list1:		list1 AND_AND newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 0 matched\n");
#endif
	}
	|	list1 OR_OR newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 1 matched\n");
#endif
	}
	|	list1 AMPERSAND newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 2 matched\n");
#endif
	}
	|	list1 SEMICOLON newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 3 matched\n");
#endif
	}
	|	list1 NEWLINE newline_list list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 4 matched\n");
#endif
		$$ = $1;
		cmd_append($1, $4);
	}
	|	pipeline_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list1 5 matched\n");
#endif
		$$ = $1;
	}
	;

simple_list_terminator:	NEWLINE
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list_terminator 0 matched\n");
#endif
	}
	|	yacc_EOF
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list_terminator 1 matched\n");
#endif
	}
	;

list_terminator: NEWLINE
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list_terminator 0 matched\n");
#endif
		}
	|	SEMICOLON
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list_terminator 1 matched\n");
#endif
		}
	|	yacc_EOF
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "list_terminator 2 matched\n");
#endif
		}
	;

newline_list:
	|	newline_list NEWLINE
		{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "newline_list 0 matched\n");
#endif
		}
	;

/* A simple_list is a list that contains no significant newlines
   and no leading or trailing newlines.  Newlines are allowed
   only following operators, where they are not significant.

   This is what an inputunit consists of.  */

simple_list:	simple_list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list 0 matched\n");
#endif
		$$ = $1;
		/* TODO: Do something here for 'Here Documents'. See bash parser. */
	}
	|	simple_list1 AMPERSAND
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list 1 matched\n");
#endif
	}
	|	simple_list1 SEMICOLON
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list 2 matched\n");
#endif
	}
	;

simple_list1:	simple_list1 AND_AND newline_list simple_list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list1 0 matched\n");
#endif
	}
	|	simple_list1 OR_OR newline_list simple_list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list1 1 matched\n");
#endif
	}
	|	simple_list1 AMPERSAND simple_list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list1 2 matched\n");
#endif
	}
	|	simple_list1 SEMICOLON simple_list1
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list1 3 matched\n");
#endif
	}

	|	pipeline_command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "simple_list1 4 matched\n");
#endif
		$$ = $1;
	}
	;

pipeline_command: pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 0 matched\n");
#endif
		$$ = $1;
	}
	|	BANG pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 1 matched\n");
#endif
	}
	|	timespec pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 2 matched\n");
#endif
	}
	|	timespec BANG pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 3 matched\n");
#endif
	}
	|	BANG timespec pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 4 matched\n");
#endif
	}
	|	timespec list_terminator
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline_command 5 matched\n");
#endif
	}
	;

pipeline:	pipeline PIPE newline_list pipeline
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline 0 matched\n");
#endif
		/* Store info regarding the pipe between these two commands. */
		$$ = cmd_pipe($1, $4);
	}
	|	command
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "pipeline 1 matched\n");
#endif
		$$ = $1;
	}
	;

timespec:	TIME
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "timespec 0 matched\n");
#endif
	}
	|	TIME TIMEOPT
	{
#ifndef NDEBUG_PARSER
		fprintf(stderr, "timespec 1 matched\n");
#endif
	}
	;
%%

void parse(FILE *file)
{
	if (file) {
		yyin = file;
		interactive = 0;

		while (!feof(yyin)) {
			yyparse();
		}
	} else {
		interactive = 1;
		yyin = stdin;
		yyparse();
	}
	cmd_print(command);
	cmd_destroy(command);
}

/* The token currently being read. */
static int current_token;

/* The last read token, or NULL.  read_token () uses this for context
 * checking. */
static int last_read_token;

/* The token read prior to last_read_token. */
static int token_before_that;

/* The token read prior to token_before_that. */
static int two_tokens_ago;

/* The current parser state. */
static int parser_state;

/* Place to remember the token.  We try to keep the buffer at a
 * reasonable size, but it can grow. */
static char *token = (char *)NULL;

/* Current size of the token buffer. */
static int token_buffer_size;

/* Global var is non-zero when end of file has been reached. */
int EOF_Reached = 0;

/* Where shell input comes from.  History expansion is performed on each
 * line when the shell is interactive. */
static char *shell_input_line = NULL;
static int shell_input_line_index;
static int shell_input_line_size; /* Amount allocated for shell_input_line. */
static int shell_input_line_len;  /* strlen (shell_input_line) */

/* If non-zero, it is the token that we want read_token to return
 * regardless of what text is (or isn't) present to be read.  This is
 * reset by read_token.  If token_to_read == WORD or ASSIGNMENT_WORD,
 * yylval.word should be set to word_desc_to_read. */
static int token_to_read;
static struct word_desc_t *word_desc_to_read;

/* Either zero or EOF. */
static int shell_input_line_terminator;

/* These are used by read_token_word, but appear up here so that
 * shell_getc can use them to decide when to add otherwise blank lines
 * to the history. */

/* The primary delimiter stack. */
struct dstack dstack = {  (char *)NULL, 0, 0 };

#define push_delimiter(ds, character) \
  do { \
		if (ds.delimiter_depth + 2 > ds.delimiter_space) \
			ds.delimiters = realloc \
			(ds.delimiters, (ds.delimiter_space += 10) * sizeof (char)); \
			ds.delimiters[ds.delimiter_depth] = character; \
			ds.delimiter_depth++; \
	} while (0)

#define pop_delimiter(ds) ds.delimiter_depth--

/* The globally known line number. */
int line_number = 0;

/* The number of lines read from input while creating the current
 * command. */
int current_command_line_count;

/* Variables to manage the task of reading here documents, because we
 * need to defer the reading until after a complete command has been
 * collected. */
static struct redirect_t *redir_stack[10];
int need_here_doc;

/* Possible states for the parser that require it to do special things. */
#define PST_CASEPAT 0x0001      /* in a case pattern list */
#define PST_ALEXPNEXT 0x0002    /* expand next word for aliases */
#define PST_ALLOWOPNBRC 0x0004  /* allow open brace for function def */
#define PST_NEEDCLOSBRC 0x0008  /* need close brace */
#define PST_DBLPAREN  0x0010    /* double-paren parsing */
#define PST_SUBSHELL  0x0020    /* ( ... ) subshell */
#define PST_CMDSUBST  0x0040    /* $( ... ) command substitution */
#define PST_CASESTMT  0x0080    /* parsing a case statement */
#define PST_CONDCMD 0x0100      /* parsing a [[...]] command */
#define PST_CONDEXPR  0x0200    /* parsing the guts of [[...]] */
#define PST_ARITHFOR  0x0400    /* parsing an arithmetic for command */
#define PST_ALEXPAND  0x0800    /* OK to expand aliases - unused */
#define PST_CMDTOKEN  0x1000    /* command token OK - unused */
#define PST_COMPASSIGN  0x2000  /* parsing x=(...) compound assignment */

#define RE_READ_TOKEN -99

#define READ   1
#define RESET  2

#define TOKEN_DEFAULT_INITIAL_SIZE 496

#define whitespace(c)  (((c) == ' ') || ((c) == '\t'))

#define ISXDIGIT(c) (IN_CTYPE_DOMAIN (c) && isxdigit (c))

#define DIGIT(c)    ((c) >= '0' && (c) <= '9')

#define ISOCTAL(c)  ((c) >= '0' && (c) <= '7')
#define OCTVALUE(c) ((c) - '0')

#define current_delimiter(ds) \
	(ds.delimiter_depth ? ds.delimiters[ds.delimiter_depth - 1] : 0)

#ifdef EXTENDED_GLOB
#  define PATTERN_CHAR(c) \
#    ((c) == '@' || (c) == '*' || (c) == '+' || (c) == '?' || (c) == '!')
#else
#  define PATTERN_CHAR(c) 0
#endif

#ifdef EXTENDED_GLOB
extern int extended_glob;
#endif

#define RESIZE_MALLOCED_BUFFER(str, cind, room, csize, sincr) \
	do { \
		if ((cind) + (room) >= csize) { \
			while ((cind) + (room) >= csize) \
				csize += (sincr); \
			str = realloc (str, csize); \
		} \
	} while (0)

/* Initial size to allocate for tokens and the amount to grow them by. */
#define TOKEN_DEFAULT_INITIAL_SIZE 496
#define TOKEN_DEFAULT_GROW_SIZE 512

#define SHOULD_PROMPT() (interactive)

#define interactive_shell (interactive)

#if defined (PROCESS_SUBSTITUTION)
#  define shellexp(c) ((c) == '$' || (c) == '<' || (c) == '>')
#else
#  define shellexp(c) ((c) == '$')
#endif

#if defined (HANDLE_MULTIBYTE)
#  define last_shell_getc_is_singlebyte \
  ((shell_input_line_index > 1) \
    ? shell_input_line_property[shell_input_line_index - 1] \
    : 1)
#  define MBTEST(x) ((x) && last_shell_getc_is_singlebyte)
#else
#  define last_shell_getc_is_singlebyte 1
#  define MBTEST(x) ((x))
#endif

/* Verify a requirement at compile-time (unlike assert, which is
 * runtime).  */
#define verify(name, assertion) struct name { char a[(assertion) ? 1 : -1]; }

intmax_t
strtoimax (const char *ptr, char **endptr, int base)
{
#ifdef HAVE_LONG_LONG
	verify(size_is_that_of_long_or_long_long,
			(sizeof (intmax_t) == sizeof (long) ||
			sizeof (intmax_t) == sizeof (long long)));

	if (sizeof (intmax_t) != sizeof (long))
		return (strtoll (ptr, endptr, base));
#else
	verify (size_is_that_of_long, sizeof (intmax_t) == sizeof (long));
#endif

	return (strtol (ptr, endptr, base));
}

/* Return non-zero if the characters pointed to by STRING constitute a
 * valid number.  Stuff the converted number into RESULT if RESULT is
 * not null. */
int
legal_number (char *string, intmax_t *result)
{
	intmax_t value;
	char *ep;

	if (result)
		*result = 0;

	errno = 0;
	value = strtoimax (string, &ep, 10);
	if (errno)
		return 0; /* errno is set on overflow or underflow */

	/* Skip any trailing whitespace, since strtoimax does not. */
	while (whitespace (*ep))
		ep++;

	/* If *string is not '\0' but *ep is '\0' on return, the entire string
	 * is valid. */
	if (string && *string && *ep == '\0') {
		if (result)
			*result = value;
			/* The SunOS4 implementation of strtol() will happily ignore
			 * overflow conditions, so this cannot do overflow correctly on
			 * those systems. */
		return 1;
	}

	return 0;
}

/* Convert STRING by expanding the escape sequences specified by the
 * ANSI C standard.  If SAWC is non-null, recognize `\c' and use that as
 * a string terminator.  If we see \c, set *SAWC to 1 before returning.
 * LEN is the length of STRING.  If (FLAGS&1) is non-zero, that we're
 * translating a string for `echo -e', and therefore should not treat a
 * single quote as a character that may be escaped with a backslash. If
 * (FLAGS&2) is non-zero, we're expanding for the parser and want to
 * quote CTLESC and CTLNUL with CTLESC */
#ifdef ESC 
#undef ESC
#endif
#define ESC '\033'  /* ASCII */

#define CTLESC '\001'
#define CTLNUL '\177'

/* Does shell-like quoting using single quotes. */
char *
sh_single_quote (char *string)
{
	register int c;
	char *result, *r, *s;

	result = malloc (3 + (4 * strlen (string)));
	r = result;
	*r++ = '\'';

	for (s = string; s && (c = *s); s++) {
		*r++ = c;

		if (c == '\'') {
			*r++ = '\\';  /* insert escaped single quote */
			*r++ = '\'';
			*r++ = '\'';  /* start new quoted string */
		}
	}

	*r++ = '\'';
	*r = '\0';

	return (result);
}

char *
ansicstr (char *string, int len, int flags, int *sawc, int *rlen)
{
	int c, temp;
	char *ret, *r, *s;
  
	if (string == 0 || *string == '\0')
		return ((char *)NULL);
  
	ret = malloc (2 * len + 1);  /* 2 * len for possible CTLESC */
	for (r = ret, s = string; s && *s; ) {
		c = *s++;
		if (c != '\\' || *s == '\0') {
			*r++ = c;
		} else {
			switch (c = *s++) {
#if defined (__STDC__)
				case 'a': c = '\a'; break;
				case 'v': c = '\v'; break;
#else
				case 'a': c = '\007'; break;
				case 'v': c = (int) 0x0B; break;
#endif
				case 'b': c = '\b'; break;
				case 'e': case 'E':   /* ESC -- non-ANSI */
					c = ESC; break;
				case 'f': c = '\f'; break;
				case 'n': c = '\n'; break;
				case 'r': c = '\r'; break;
				case 't': c = '\t'; break;
				case '0': case '1': case '2': case '3':
				case '4': case '5': case '6': case '7':
				/* If (FLAGS & 1), we're translating a string for echo -e (or
				 * the equivalent xpg_echo option), so we obey the SUSv3/
				 * POSIX-2001 requirement and accept 0-3 octal digits after a
				 * leading `0'. */
					temp = 2 + ((flags & 1) && (c == '0'));
					for (c -= '0'; ISOCTAL (*s) && temp--; s++)
						c = (c * 8) + OCTVALUE (*s);
					c &= 0xFF;
					break;
				case 'x':     /* Hex digit -- non-ANSI */
					if ((flags & 2) && *s == '{') {
						flags |= 16;    /* internal flag value */
						s++;
					}
					/* Consume at least two hex characters */
					for (temp = 2, c = 0; ISXDIGIT ((unsigned char)*s) && temp--; s++)
						c = (c * 16) + HEXVALUE (*s);
					/* DGK says that after a `\x{' ksh93 consumes ISXDIGIT chars
					 * until a non-xdigit or `}', so potentially more than two
					 * chars are consumed. */
					if (flags & 16) {
						for ( ; ISXDIGIT ((unsigned char)*s); s++)
							c = (c * 16) + HEXVALUE (*s);
						flags &= ~16;
						if (*s == '}')
							s++;
					}
					/* \x followed by non-hex digits is passed through unchanged */
					else if (temp == 2) {
						*r++ = '\\';
						c = 'x';
					}
					c &= 0xFF;
					break;
				case '\\':
					break;
				case '\'': case '"': case '?':
					if (flags & 1)
						*r++ = '\\';
					break;
				case 'c':
					if (sawc) {
						*sawc = 1;
						*r = '\0';
						if (rlen)
							*rlen = r - ret;
						return ret;
					} else if ((flags & 1) == 0 && (c = *s)) {
						s++;
						c = TOCTRL(c);
						break;
					}
				/* FALLTHROUGH */
				default:  *r++ = '\\'; break;
			}
			if ((flags & 2) && (c == CTLESC || c == CTLNUL))
				*r++ = CTLESC;
			*r++ = c;
		}
	}
	*r = '\0';
	if (rlen)
		*rlen = r - ret;

	return ret;
}


/* $'...' ANSI-C expand the portion of STRING between START and END and
 * return the result.  The result cannot be longer than the input
 * string. */
char *
ansiexpand (char *string, int start, int end, int *lenp)
{
	char *temp, *t;
	int len, tlen;

	temp = malloc (end - start + 1);
	for (tlen = 0, len = start; len < end; )
		temp[tlen++] = string[len++];
	temp[tlen] = '\0';

	if (*temp) {
		t = ansicstr (temp, tlen, 2, NULL, lenp);
		free(temp);
		return (t);
	} else {
		if (lenp)
			*lenp = 0;
		return (temp);
	}
}

/*
 * Returns a truth value of whether the given character 'c' is a
 * meta-character. Returns 1 if it is a meta-character or 0 if it is
 * not.
 *
 * TODO: This function could be implented more efficiently by populating
 * an array with these symbols and performing a lookup that way.
 */
int
shellmeta(int c)
{
	switch (c) {
		case ' ':
			return 1;
		case '\t':
			return 1;
		case '\n':
			return 1;
		case ';':
			return 1;
		case '(':
			return 1;
		case ')':
			return 1;
		case '<':
			return 1;
		case '>':
			return 1;
		case '|':
			return 1;
		case '&':
			return 1;
		default:
			return 0;
	}
	return 0;
}

int
shellquote(int c)
{
	switch (c) {
		case '\'':
			return 1;
		case '"':
			return 1;
		default:
			return 0;
	}
}

void
make_here_document(struct redirect_t *temp)
{
}

void
gather_here_documents()
{
	int r = 0;
	while (need_here_doc) {
		make_here_document (redir_stack[r++]);
		need_here_doc--;
	}
}

void
reset_parser(void)
{

}

static void
print_prompt()
{
	printf("$ ");
}

static void
prompt_again()
{
	printf("$ ");
}

/*
 * Return 1 if TOKSYM is a token that after being read would allow a
 * reserved word to be seen, else 0.
 */
static int
reserved_word_acceptable (int toksym)
{
	switch (toksym) {
		case '\n':
		case ';':
		case '(':
		case ')':
		case '|':
		case '&':
		case '{':
		case '}':   /* XXX */
		case AND_AND:
		case BANG:
		case DO:
		case DONE:
		case ELIF:
		case ELSE:
		case ESAC:
		case FI:
		case IF:
		case OR_OR:
		case SEMI_SEMI:
		case THEN:
		case TIME:
		case TIMEOPT:
		case UNTIL:
		case WHILE:
		case 0:
			return 1;
		default:
			return 0;
	}
}

/*
 * Match a $(...) or other grouping construct.  This has to handle
 * embedded quoted strings ('', ``, "") and nested constructs.  It also
 * must handle reprompting the user, if necessary, after reading a
 * newline (unless the P_NONL flag is passed), and returning correct
 * error values if it reads EOF. */
#define P_FIRSTCLOSE  0x01
#define P_ALLOWESC  0x02
#define P_DQUOTE  0x04

static char matched_pair_error;

static char *
parse_matched_pair (int qc, int open, int close, int *lenp, int flags)
{
	return NULL;
}

/*
 * Returns non-zero if STRING is an assignment statement.  The returned
 * value is the index of the `=' sign.
 */
#define legal_variable_starter(c) (ISALPHA(c) || (c == '_'))
#define legal_variable_char(c)  (ISALNUM(c) || c == '_')

#define command_token_position(token) \
	(((token) == ASSIGNMENT_WORD) || \
	 ((token) != SEMI_SEMI && reserved_word_acceptable(token)))

#define assignment_acceptable(token) \
	(command_token_position(token) && ((parser_state & PST_CASEPAT) == 0))

int
assignment (const char *string, int flags)
{
	register unsigned char c;
	register int newi, indx;

	c = string[indx = 0];

#if defined (ARRAY_VARS)
	if ((legal_variable_starter (c) == 0) && (flags && c != '[')) /* ] */
#else
	if (legal_variable_starter (c) == 0)
#endif
		return (0);

	while ((c = string[indx])) {
		/* The following is safe.  Note that '=' at the start of a word is
		 * not an assignment statement. */
		if (c == '=')
			return (indx);

#if defined (ARRAY_VARS)
		if (c == '[') {
			newi = skipsubscript (string, indx);
			if (string[newi++] != ']')
				return 0;
			return ((string[newi] == '=') ? newi : 0);
		}
#endif /* ARRAY_VARS */

		/* Variable names in assignment statements may contain only letters,
		 * digits, and `_'. */
		if (legal_variable_char (c) == 0)
			return (0);

		indx++;
	}

	return 0;
}

/*
 * Handle special cases of token recognition:
 *   IN is recognized if the last token was WORD and the token before
 *   that was FOR or CASE or SELECT.
 *
 *   DO is recognized if the last token was WORD and the token before
 *   that was FOR or SELECT.
 *
 *   ESAC is recognized if the last token caused `esacs_needed_count' to
 *   be set.
 *
 *   `{' is recognized if the last token as WORD and the token before
 *   that was FUNCTION, or if we just parsed an arithmetic `for' command.
 *
 *   `}' is recognized if there is an unclosed `{' present.
 *
 *   `-p' is returned as TIMEOPT if the last read token was TIME.
 *
 *   ']]' is returned as COND_END if the parser is currently parsing
 *   a conditional expression ((parser_state & PST_CONDEXPR) != 0)
 *
 *   `time' is returned as TIME if and only if it is immediately
 *   preceded by one of `;', `\n', `||', `&&', or `&'.
*/

/* When non-zero, we have read the required tokens which allow ESAC to
 * be the next one read. */
static int esacs_needed_count;

/* When non-zero, an open-brace used to create a group is awaiting a
 * close brace partner. */
static int open_brace_count;

/* String comparisons that possibly save a function call each. */
#define STREQ(a, b) ((a)[0] == (b)[0] && strcmp(a, b) == 0)

static int
special_case_tokens (char *tokstr)
{
	if ((last_read_token == WORD) &&
	    ((token_before_that == FOR) || (token_before_that == CASE)) &&
	    (tokstr[0] == 'i' && tokstr[1] == 'n' && tokstr[2] == 0)) {
		if (token_before_that == CASE) {
			parser_state |= PST_CASEPAT;
			esacs_needed_count++;
		}
		return IN;
	}

	if (last_read_token == WORD && (token_before_that == FOR) &&
	    (tokstr[0] == 'd' && tokstr[1] == 'o' && tokstr[2] == '\0'))
		return DO;

	/* Ditto for ESAC in the CASE case. Specifically, this handles "case
	 * word in esac", which is a legal construct, certainly because
	 * someone will pass an empty arg to the case construct, and we don't
	 * want it to barf. Of course, we should insist that the case
	 * construct has at least one pattern in it, but the designers
	 * disagree. */
	if (esacs_needed_count) {
		esacs_needed_count--;
		if (STREQ(tokstr, "esac")) {
			parser_state &= ~PST_CASEPAT;
			return ESAC;
		}
	}

	/* The start of a shell function definition. */
	if (parser_state & PST_ALLOWOPNBRC) {
		parser_state &= ~PST_ALLOWOPNBRC;
		if (tokstr[0] == '{' && tokstr[1] == '\0') {  /* '}' */
			open_brace_count++;
			/* TODO: DO I need this: function_bstart = line_number; */
			return '{';
		}
	}

	/* Handle ARITH_FOR_EXPRS */
	if (last_read_token == ARITH_FOR_EXPRS && tokstr[0] == '{' &&
	    tokstr[1] == '\0') {  /* '}' */
		open_brace_count++;
		return '{';
	}

	if (open_brace_count && reserved_word_acceptable (last_read_token) &&
	    tokstr[0] == '}' && !tokstr[1]) {
		open_brace_count--;  /* '{' */
		return '}';
	}

	return -1;
}

/* Return the next shell input character.  This always reads characters
 * from shell_input_line; when that line is exhausted, it is time to
 * read the next line.  This is called by read_token when the shell is
 * processing normal command input. */

/* This implements one-character lookahead/lookbehind across physical
 * input lines, to avoid something being lost because it's pushed back
 * with shell_ungetc when we're at the start of a line. */
static int eol_ungetc_lookahead = 0;

static int
shell_getc(int remove_quoted_newline)
{
	register int i;
	int c;
	unsigned char uc;

	if (eol_ungetc_lookahead) {
		c = eol_ungetc_lookahead;
		eol_ungetc_lookahead = 0;
		return c;
	}

#ifdef ALIAS
	if (!shell_input_line ||
	    ((!shell_input_line[shell_input_line_index]) &&
	    (pushed_string_list == NULL))) {
#else  /* !ALIAS */
	if (!shell_input_line || !shell_input_line[shell_input_line_index]) {
#endif /* !ALIAS */
		line_number++;

restart_read:

		/* Allow immediate exit if interrupted during input. */
		/* TODO: Implement this line yet: QUIT; */

		i = 0;
		shell_input_line_terminator = 0;

		/* If the shell is interatctive, but not currently printing a prompt
		 * (interactive_shell && interactive == 0), we don't want to print
		 * notifies or cleanup the jobs -- we want to defer it until we do
		 * print the next prompt. */
		if (interactive_shell == 0 || SHOULD_PROMPT()) {
#ifdef JOB_CONTROL
			notify_and_cleanup();
#else  /* !JOB_CONTROL */
			cleanup_dead_jobs();
#endif /* !JOB_CONTROL */
		}

		print_prompt();

		while (1) {
			c = fgetc(yyin);

			if (c == '\0')  /* Ignore null byte in input. */
				continue;

			RESIZE_MALLOCED_BUFFER(shell_input_line, i, 2, shell_input_line_size, 256);

			if (c == EOF) {
				if (i == 0)
					shell_input_line_terminator = EOF;

				shell_input_line[i] = '\0';
				break;
			}

			shell_input_line[i++] = c;

			if (c == '\n') {
				shell_input_line[--i] = '\0';
				current_command_line_count++;
				break;
			}
		}

		shell_input_line_index = 0;
		shell_input_line_len = i;  /* == strlen (shell_input_line) */

		/* TODO: Find out if I need this here: set_line_mbstate(); */

/* NOTE: PERFORM HISTORY HANDLING CODE */
#if defined (HISTORY)
		if (remember_on_history && shell_input_line && shell_input_line[0]) {
			char *expansions;
			int old_hist;

			/* If the current delimiter is a single quote, we should not be
			 * performing history expansion, even if we're on a different
			 * line from the original single quote. */
			old_hist = history_expansion_inhibited;
			if (current_delimiter(dstack) == '\'')
				history_expansion_inhibited = 1;

			expansions = pre_process_line(shell_input_line, 1, 1);
			history_expansion_inhibited = old_hist;
			if (expansions != shell_input_line) {
				free(shell_input_line);
				shell_input_line = expansions;
				shell_input_line_len = shell_input_line ? strlen(shell_input_line) : 0;
				if (!shell_input_line_len)
					current_command_line_count--;

				/* We have to force the realloc below because we don't know the
				 * true allocated size of shell_input_line anymore. */
				shell_input_line_size = shell_input_line_len;

				/* TODO: Find out if I need this here: set_line_mbstate(); */
			}
		} else if (remember_on_history && shell_input_line &&
	             shell_input_line[0] == '\0' &&
	             current_command_line_count > 1) {
			/* Try to do something intelligent with blank lines encountered
			 * while entering multi-line commands.  XXX - this is grotesque */
			if (current_delimiter(dstack)) {
				/* We know shell_input_line[0] == 0 and we're reading some sort
				 * of quoted string.  This means we've got a line consisting of
				 * only a newline in a quoted string.  We want to make sure this
				 * line gets added to the history. */
				maybe_add_history(shell_input_line);
			} else {
				char *hdcs;
				hdcs = history_delimiting_chars();
				if (hdcs && hdcs[0] == ';')
					maybe_add_history(shell_input_line);
			}
		}
#endif /* HISTORY */

		if (!shell_input_line) {
			shell_input_line_size = 0;
			prompt_again();
			goto restart_read;
		}

		/* Add the newline to the end of this string, iff the string does
		 * not already end in an EOF character. */
		if (shell_input_line_terminator != EOF) {
			if (shell_input_line_len + 3 > shell_input_line_size) {
				shell_input_line =
						realloc(shell_input_line, 1 + (shell_input_line_size += 2));
			}
			shell_input_line[shell_input_line_len] = '\n';
			shell_input_line[shell_input_line_len + 1] = '\0';

			/* TODO: Find out if I need this here: set_line_mbstate(); */
		}
	}

	uc = shell_input_line[shell_input_line_index];

	if (uc)
		shell_input_line_index++;

	if (uc == '\\' && remove_quoted_newline &&
	    shell_input_line[shell_input_line_index] == '\n') {
		if (SHOULD_PROMPT())
			prompt_again();
		line_number++;
		goto restart_read;
	}

#ifdef ALIAS
	/* If UC is NULL, we have reached the end of the current input string.
	 * If pushed_string_list is non-empty, it's time to pop to the
	 * previous string because we have fully consumed the result of the
	 * last alias expansion. Do it transparently; just return the next
	 * character of the string popped to. */
	if (!uc && (pushed_string_list != NULL)) {
		pop_string();
		uc = shell_input_line[shell_input_line_index];
		if (uc)
			shell_input_line_index++;
	}
#endif /* ALIAS */

	if (!uc && shell_input_line_terminator == EOF)
		return ((shell_input_line_index != 0) ? '\n' : EOF);

	return uc;
}

/* Put 'c' back into the input for the shell.  This might need changes
 * for HANDLE_MULTIBYTE around EOLs. Since we (currently) never push
 * back a character different than we read, shell_input_line_property
 * doesn't need to change when manipulating shell_input_line. The define
 * for last_shell_getc_is_singlebyte should take care of it, though. */
static void
shell_ungetc (c)
{
	if (shell_input_line && shell_input_line_index)
		shell_input_line[--shell_input_line_index] = c;
	else
		eol_ungetc_lookahead = c;
}

/* Discard input until CHARACTER is seen, then push that character back
 * onto the input stream. */
static void
discard_until (int character)
{
	int c;

	while ((c = shell_getc (0)) != EOF && c != character)
		;

	if (c != EOF)
	shell_ungetc (c);
}

/*
 * Reads in a token word, called from read_token().
 */

/* The line number in a script where the word in a `case WORD', `select
 * WORD' or `for WORD' begins.  This is a nested command maximum, since
 * the array index is decremented after a case, select, or for command
 * is parsed. */
#define MAX_CASE_NEST 128
static int word_lineno[MAX_CASE_NEST];
static int word_top = -1;

static int
read_token_word(int character)
{
	err_msg("DEBUG: Begin read_token_word()");

	/* The value for YYLVAL when a WORD is read. */
	struct word_desc_t *the_word;

	/* Index into the token that we are building. */
	int token_index;

	/* ALL_DIGITS becomes zero when we see a non-digit. */
	int all_digit_token;

	/* DOLLAR_PRESENT becomes non-zero if we see a `$'. */
	int dollar_present;

	/* QUOTED becomes non-zero if we see one of ("), ('), (`), or (\). */
	int quoted;

	/* Non-zero means to ignore the value of the next character, and just
	 * to add it no matter what. */
	int pass_next_character;

	/* The current delimiting character. */
	int cd;
	int result, peek_char;
	char *ttok, *ttrans;
	int ttoklen, ttranslen;
	intmax_t lvalue;

	if (token_buffer_size < TOKEN_DEFAULT_INITIAL_SIZE)
		token = realloc(token, token_buffer_size = TOKEN_DEFAULT_INITIAL_SIZE);

	token_index = 0;
	all_digit_token = DIGIT(character);
	dollar_present = quoted = pass_next_character = 0;

	for (;;) {
		if (character == EOF)
			goto got_token;

		if (pass_next_character) {
			pass_next_character = 0;
			goto got_character;
		}

		cd = current_delimiter(dstack);

		/* Handle backslashes.  Quote lots of things when not inside of
		 * double-quotes, quote some things inside of double-quotes. */
		if (character == '\\') {
			peek_char = shell_getc(0);

			/* Backslash-newline is ignored in all cases except when quoted
			 * with single quotes. */
			if (peek_char == '\n') {
				character = '\n';
				goto next_character;
			} else {
				shell_ungetc(peek_char);

				/* If the next character is to be quoted, note it now. */
				if (cd == 0 || cd == '`' ||
				    (cd == '"' && peek_char >= 0))/* FIXME: &&
				    (sh_syntaxtab[peek_char] & CBSDQUOTE))) */
					pass_next_character++;

				quoted = 1;
				goto got_character;
			}
		}

		/* Parse a matched pair of quote characters. */
		if (shellquote(character)) {
			push_delimiter(dstack, character);
			ttok = parse_matched_pair(character, character, character, &ttoklen, 0);
			pop_delimiter(dstack);
			if (ttok == &matched_pair_error)
				return -1;  /* Bail immediately. */

			RESIZE_MALLOCED_BUFFER (token, token_index, ttoklen + 2,
					token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
			token[token_index++] = character;
			strcpy(token + token_index, ttok);
			token_index += ttoklen;
			all_digit_token = 0;
			quoted = 1;
			dollar_present |= (character == '"' && strchr(ttok, '$') != 0);
			free(ttok);
			goto next_character;
		}

#ifdef EXTENDED_GLOB
		/* Parse a ksh-style extended pattern matching specification. */
		if (extended_glob && PATTERN_CHAR(character)) {
			peek_char = shell_getc(1);
			if (peek_char == '(') {  /* ) */
				push_delimiter(dstack, peek_char);
				ttok = parse_matched_pair(cd, '(', ')', &ttoklen, 0);
				pop_delimiter(dstack);
				if (ttok == &matched_pair_error)
					return -1;    /* Bail immediately. */

				RESIZE_MALLOCED_BUFFER(token, token_index, ttoklen + 2,
						token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
				token[token_index++] = character;
				token[token_index++] = peek_char;
				strcpy(token + token_index, ttok);
				token_index += ttoklen;
				free(ttok);
				dollar_present = all_digit_token = 0;
				goto next_character;
			} else {
				shell_ungetc(peek_char);
			}
		}
#endif  /* EXTENDED_GLOB */

		/* If the delimiter character is not single quote, parse some of the
		 * shell expansions that must be read as a single word. */
		if (shellexp(character)) {
			peek_char = shell_getc(1);
			/* $(...), <(...), >(...), $((...)), ${...}, and $[...] constructs */
			if (peek_char == '(' || \
			    ((peek_char == '{' || peek_char == '[') && character == '$')) {
				/* ) ] '}' */

				if (peek_char == '{') {  /* '}' */
					ttok = parse_matched_pair(cd, '{', '}', &ttoklen, P_FIRSTCLOSE);
				} else if (peek_char == '(') {  /* ) */
					/* XXX - push and pop the `(' as a delimiter for use by the
					 * command-oriented-history code.  This way newlines
					 * appearing in the $(...) string get added to the history
					 * literally rather than causing a possibly incorrect `;' to
					 * be added. ) */
					push_delimiter(dstack, peek_char);
					ttok = parse_matched_pair(cd, '(', ')', &ttoklen, 0);
					pop_delimiter(dstack);
				} else {
					ttok = parse_matched_pair(cd, '[', ']', &ttoklen, 0);
				}

				if (ttok == &matched_pair_error)
					return -1;  /* Bail immediately. */

				RESIZE_MALLOCED_BUFFER (token, token_index, ttoklen + 2,
						token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
				token[token_index++] = character;
				token[token_index++] = peek_char;
				strcpy(token + token_index, ttok);
				token_index += ttoklen;
				free(ttok);
				dollar_present = 1;
				all_digit_token = 0;
				goto next_character;
			} else if (character == '$' && (peek_char == '\'' || peek_char == '"')) {
				int first_line;

				first_line = line_number;
				push_delimiter(dstack, peek_char);
				ttok = parse_matched_pair(peek_char, peek_char, peek_char,
						&ttoklen, (peek_char == '\'') ? P_ALLOWESC : 0);
				pop_delimiter(dstack);
				if (ttok == &matched_pair_error)
					return -1;

				if (peek_char == '\'') {
					ttrans = ansiexpand (ttok, 0, ttoklen - 1, &ttranslen);
					free(ttok);
					/* Insert the single quotes and correctly quote any embedded
					 * single quotes (allowed because P_ALLOWESC was passed to
					 * parse_matched_pair). */
					ttok = sh_single_quote(ttrans);
					free(ttrans);
					ttrans = ttok;
					ttranslen = strlen(ttrans);
				} else {
					/* Try to locale-expand the converted string. */
					/* TODO: Implement this function. Is in locale.c in bash.
					 *ttrans = localeexpand(ttok, 0, ttoklen - 1, first_line, &ttranslen);
					 */
					free(ttok);

					/* Add the double quotes back */
					ttok = malloc(ttranslen + 3);
					ttok[0] = '"';
					strcpy(ttok + 1, ttrans);
					ttok[ttranslen + 1] = '"';
					ttok[ttranslen += 2] = '\0';
					free(ttrans);
					ttrans = ttok;
				}

				RESIZE_MALLOCED_BUFFER (token, token_index, ttranslen + 2,
						token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
				strcpy(token + token_index, ttrans);
				token_index += ttranslen;
				free(ttrans);
				quoted = 1;
				all_digit_token = 0;
				goto next_character;
			}
			/* This could eventually be extended to recognize all of the
			 * shell's single-character parameter expansions, and set
			 * flags. */
			else if (character == '$' && peek_char == '$') {
				ttok = malloc(3);
				ttok[0] = ttok[1] = '$';
				ttok[2] = '\0';
				RESIZE_MALLOCED_BUFFER (token, token_index, 3,
						token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
				strcpy(token + token_index, ttok);
				token_index += 2;
				dollar_present = 1;
				all_digit_token = 0;
				free(ttok);
				goto next_character;
			} else {
				shell_ungetc(peek_char);
			}
		}
#if defined (ARRAY_VARS)
		/* Identify possible array subscript assignment; match [...] */
		else if (character == '[' && token_index > 0 &&
		         assignment_acceptable(last_read_token) &&
		         token_is_ident(token, token_index)) {
			ttok = parse_matched_pair(cd, '[', ']', &ttoklen, 0);
			if (ttok == &matched_pair_error)
				return -1;  /* Bail immediately. */
			RESIZE_MALLOCED_BUFFER(token, token_index, ttoklen + 2,
					token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
			token[token_index++] = character;
			strcpy(token + token_index, ttok);
			token_index += ttoklen;
			free(ttok);
			all_digit_token = 0;
			goto next_character;
		} else if (character == '=' && token_index > 0 &&
		           token_is_assignment(token, token_index)) {
			peek_char = shell_getc(1);
			if (peek_char == '(') {  /* ) */
				ttok = parse_compound_assignment(&ttoklen);
				RESIZE_MALLOCED_BUFFER (token, token_index, ttoklen + 4,
						token_buffer_size, TOKEN_DEFAULT_GROW_SIZE);
				token[token_index++] = '=';
				token[token_index++] = '(';
				if (ttok) {
					strcpy(token + token_index, ttok);
					token_index += ttoklen;
				}
				token[token_index++] = ')';
				free(ttok);
				all_digit_token = 0;
				goto next_character;
			} else {
				shell_ungetc(peek_char);
			}
		}
#endif  /* ARRAY_VARS */

		/* When not parsing a multi-character word construct, shell meta-
		 * characters break words. */
		/* TODO: FIX THIS ISSUE by adding this functionality.
		if (shellbreak(character)) {
			shell_ungetc(character);
			goto got_token;
		}
		*/

got_character:

		all_digit_token &= DIGIT(character);
		dollar_present |= character == '$';

		if (character == CTLESC || character == CTLNUL)
			token[token_index++] = CTLESC;

		token[token_index++] = character;

		RESIZE_MALLOCED_BUFFER(token, token_index, 1, token_buffer_size,
				TOKEN_DEFAULT_GROW_SIZE);

next_character:

		if (character == '\n' && SHOULD_PROMPT())
			prompt_again();

		/* We want to remove quoted newlines (that is, a \<newline> pair)
		 * unless we are within single quotes or pass_next_character is set
		 * (the shell equivalent of literal-next). */
		cd = current_delimiter(dstack);
		character = shell_getc(cd != '\'' && pass_next_character == 0);

	} /* end for (;;) */

got_token:

	token[token_index] = '\0';

	/* Check to see what thing we should return.  If the last_read_token
	 * is a `<', or a `&', or the character which ended this token is a
	 * '>' or '<', then, and ONLY then, is this input token a NUMBER.
	 * Otherwise, it is just a word, and should be returned as such. */
	if (all_digit_token && (character == '<' || character == '>' ||
	    last_read_token == LESS_AND || last_read_token == GREATER_AND)) {
		if (legal_number(token, &lvalue) && (int)lvalue == lvalue)
			yylval.number = lvalue;
		else
			yylval.number = -1;
	}

	/* Check for special case tokens. */
	result = (last_shell_getc_is_singlebyte) ? special_case_tokens(token) : -1;
	if (result >= 0)
		return result;

#if defined (ALIAS)
	/* Posix.2 does not allow reserved words to be aliased, so check for
	 * all of them, including special cases, before expanding the current
	 * token as an alias. 
	 *
	 * This is a stupid rule. Lets ignore it.
	if (posixly_correct)
		CHECK_FOR_RESERVED_WORD(token);
	*/

	/* Aliases are expanded iff EXPAND_ALIASES is non-zero, and quoting
	 * inhibits alias expansion. */
	if (expanded_aliases && quoted == 0) {
		result = alias_expand_token(token);
		if (result == RE_READ_TOKEN)
			return RE_READ_TOKEN;
		else if (result == NO_EXPANSION)
			parser_state &= ~PST_ALEXPNEXT;
	}

	/* If not in Posix.2 mode, check for reserved words after alias
	 * expansion. 
	 *
	 * Let's ignore this as well for now. */
	//if (posix_correct == 0)
#endif /* ALIAS */
	//	CHECK_FOR_RESERVED_WORD (token);

	the_word = malloc(sizeof(struct word_desc_t));
	the_word->word = malloc(1 + token_index);
	the_word->flags = 0;
	strcpy(the_word->word, token);
	if (dollar_present)
		the_word->flags |= W_HASDOLLAR;
	if (quoted)
		the_word->flags |= W_QUOTED;

	/* A word is an assignment if it appears at the beginning of a simple
	 * command, or after another assignment word.  This is
	 * context-dependent, so it cannot be handled in the grammar. */
	if (assignment(token, (parser_state & PST_COMPASSIGN) != 0)) {
		the_word->flags |= W_ASSIGNMENT;
		/* Don't perform word splitting on assignment statements. */
		if (assignment_acceptable(last_read_token) ||
		    (parser_state & PST_COMPASSIGN) != 0)
			the_word->flags |= W_NOSPLIT;
	}

	yylval.word = the_word;

	if ((the_word->flags & (W_ASSIGNMENT|W_NOSPLIT)) == (W_ASSIGNMENT|W_NOSPLIT))
		result = ASSIGNMENT_WORD;
	else
		result = WORD;

	switch (last_read_token) {
		case FUNCTION:
			parser_state |= PST_ALLOWOPNBRC;
			/* TODO: Do I need this: function_dstart = line_number; */
			break;
		case CASE:
		case SELECT:
		case FOR:
			if (word_top < MAX_CASE_NEST)
				word_top++;
			word_lineno[word_top] = line_number;
			break;
	}

	err_msg("DEBUG: End read_token_word()");

	return result;
}

static int
read_token(int type)
{
	err_msg("DEBUG: Begin read_token()");
	int character;  /* Current character. */
	int peek_char;  /* Look-ahead character. */
	int result;

	if (type == RESET) {
		reset_parser();
		return '\n';
	}

	if (token_to_read) {
		result = token_to_read;
		if (token_to_read == WORD || token_to_read == ASSIGNMENT_WORD) {
			yylval.word = word_desc_to_read;
			word_desc_to_read = NULL;
		}
		token_to_read = 0;
		return result;
	}

#ifdef COND_COMMAND
#endif

re_read_token:  /* Used to re_read an expanded alias expression. */

	/* Read a single word from input.  Start by skipping blanks. */
	while((character = shell_getc(1)) != EOF && whitespace(character))
		;

	if (character == EOF) {
		EOF_Reached = 1;
		return yacc_EOF;
	}

	/* Allow comments if interactive or not. */
	if (character == '#') {
		/* A comment. Discard until EOL or EOF, and then return a newline. */
		discard_until('\n');
		shell_getc(0);
		character = '\n'; /* This will take the next if statement and return. */
	}

	if (character == '\n') {
		/* If we're about to return an unquoted newline, we can go and
		 * collect the text of any pending here document. */
		if (need_here_doc)
			gather_here_documents();

#if defined (ALIAS)
			parser_state &= ~PST_ALEXPNEXT;
#endif

			return character;
	}

	/* Shell meta-characters. */
	if (shellmeta(character) && ((parser_state & PST_DBLPAREN) == 0)) {
#if defined (ALIAS)
		/* Turn off alias tokenization iff this character sequence would
		 * not leave us ready to read a command. */
		if (character == '<' || character == '>')
			parser_state &= ~PST_ALEXPNEXT;
#endif

		peek_char = shell_getc(1);
		if (character == peek_char) {
			switch (character) {
				case '<':
					/* If '<' then we could be at "<<" or at "<<-".  We have to
					 * look ahead one more character. */
					peek_char = shell_getc(1);
					if (peek_char == '-') {
						return LESS_LESS_MINUS;
					} else if (peek_char == '<') {
						return LESS_LESS_LESS;
					} else {
						shell_ungetc(peek_char);
						return LESS_LESS;
					}
				case '>':
					return GREATER_GREATER;
				case ';':
					parser_state |= PST_CASEPAT;
#if defined (ALIAS)
					parser_state &= ~PST_ALEXPNEXT;
#endif
					return SEMI_SEMI;
				case '&':
					return AND_AND;
				case '|':
					return OR_OR;
				/* TODO: Implement ARITH_FOR_COMMAND here if I need it later */
			}
		} else if (character == '<' && peek_char == '&') {
			return LESS_AND;
		} else if (character == '>' && peek_char == '&') {
			return GREATER_AND;
		} else if (character == '<' && peek_char == '>') {
			return LESS_GREATER;
		} else if (character == '>' && peek_char == '|') {
			return GREATER_BAR;
		} else if (peek_char == '>' && character == '&') {
			return AND_GREATER;
		}

		shell_ungetc(peek_char);

		/* If we look like we are reading the start of a function
		 * definition, then let the reader know about it so that we will do
		 * the right thing with `{'. */
		if (character == ')' && last_read_token == '(' &&
		    token_before_that == WORD) {
			parser_state |= PST_ALLOWOPNBRC;
#if defined (ALIAS)
			parser_state &= ~PST_ALEXPNEXT;
#endif
			/* TODO: What purpose is this: function_dstart = line_number; */
		}

		/* TODO: Implement code for case pattern lists if needed. */

		/* Check for the constructs which introduce process substitution. */
		if ((character != '>' && character != '<') || peek_char != '(')
			return character;
	} /* End Shell meta-characters. */

	/* Hack <&- (close stdin) case.  Also <&N- (dup and close). */
	if (character == '-' && (last_read_token == LESS_AND ||
	    last_read_token == GREATER_AND))
		return character;

	/* Okay, if we got this far, we have to read a word.  Read one, and
	 * then check it against the known ones. */
	result = read_token_word(character);
#if defined (ALIAS)
	if (result == RE_READ_TOKEN)
		goto re_read_token;
#endif

	err_msg("DEBUG: End read_token()");

	return result;
}

void
yyerror(char *s)
{
	//err_msg("yyerror: %s at line #%d:\n  '%s'", s, line_number, yytext);
	err_msg("yyerror: %s at line #%d", s, line_number);
}

int
yylex(void)
{
	if (interactive && (current_token == 0 || current_token == '\n'))
		prompt_again();

	two_tokens_ago = token_before_that;
	token_before_that = last_read_token;
	last_read_token = current_token;
	current_token = read_token(READ);

	return current_token;
}
