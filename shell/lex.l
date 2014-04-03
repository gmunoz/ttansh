%{
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "cmd.h"
#include "parser.h"

void yyerror(char *s);
static int lineno = 1;  /* For better yyerror reporting */
%}

%%

if          { return IF; }
then        { return THEN; }
else        { return ELSE; }
else\ if    { return ELIF; }
fi          { return FI; }
case        { return CASE; }
esac        { return ESAC; }
for|foreach { return FOR; }
select      { return SELECT; }
while       { return WHILE; }
until       { return UNTIL; }
do          { return DO; }
done        { return DONE; }
function    { return FUNCTION; }
in          { return IN; }
!           { return BANG; }

cd|exit|set {
	yylval.word = (char *)strdup(yytext);
	return INTERNAL_COMMAND;
}

([0-9]+|([0-9]*\.[0-9]+)([eE][-+]?[0-9]+)?) {
	yylval.number = atof(yytext);
	return NUMBER;
}

[A-Za-z\-][A-Za-z0-9]* {
	/* TODO: Check that the word matched isn't in our symbol table. If it
	 * is, then it is an ASSIGNMENT_WORD??? */
	yylval.word = (char *)strdup(yytext);
	return WORD;
}

=        { return EQUALS; }
\n       { lineno++; return NEWLINE; }
-        { return MINUS; }
\{       { return LEFT_CURLY; }
\}       { return RIGHT_CURLY; }
\(       { return LEFT_PARENTH; }
\)       { return RIGHT_PARENTH; }
\<       { return LESSER; }
\>       { return GREATER; }
\|       { return PIPE; }
&        { return AMPERSAND; }
;        { return SEMICOLON; }
&&       { return AND_AND; }
\|\|     { return OR_OR; }
;;       { return SEMI_SEMI; }
\<\<     { return LESS_LESS; }
\>\>     { return GREATER_GREATER; }
\<&      { return LESS_GREATER; }
\>&      { return GREATER_AND; }
&\>      { return AND_GREATER; }
\<\<-    { return LESS_LESS_MINUS; }
\>\|     { return GREATER_BAR; }
\<\<\<   { return LESS_LESS_LESS; }

[ \t.]+  /* Ignore whitespace */

%%

/*
 * Override for portability.
 */
void yyerror(char *s)
{
	fprintf(stderr, "yyerror: %s at line #%d:\n  '%s'\n", s, lineno, yytext);
}
