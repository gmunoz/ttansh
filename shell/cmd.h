#ifndef _CMD_H
#define _CMD_H

#include "redirect.h"

struct element_t {
	char *word;
	struct redirect_t *redirect;
};

/* Possible values for the `flags' field of a WORD_DESC. */
#define W_HASDOLLAR 0x0001  /* Dollar sign present. */
#define W_QUOTED  0x0002  /* Some form of quote character is present. */
#define W_ASSIGNMENT  0x0004  /* This word is a variable assignment. */
#define W_GLOBEXP 0x0008  /* This word is the result of a glob expansion. */
#define W_NOSPLIT 0x0010  /* Do not perform word splitting on this word. */
#define W_NOGLOB  0x0020  /* Do not perform globbing on this word. */
#define W_NOSPLIT2  0x0040  /* Don't split word except for $@ expansion. */
#define W_TILDEEXP  0x0080  /* Tilde expand this assignment word */
#define W_DOLLARAT  0x0100  /* $@ and its special handling */
#define W_DOLLARSTAR  0x0200  /* $* and its special handling */
#define W_NOCOMSUB  0x0400  /* Don't perform command substitution on this word */

struct word_desc_t {
	char *word;  /* Zero terminated string. */
	int flags;   /* Flags associated with this word. */
};

/* Definition of the delimiter stack.  Needed by parse.y and bashhist.c. */
struct dstack {
	/* DELIMITERS is a stack of the nested delimiters that we have
	 * encountered so far. */
	char *delimiters;
	/* Offset into the stack of delimiters. */
	int delimiter_depth;
	/* How many slots are allocated to DELIMITERS. */
	int delimiter_space;
};

/* A linked-list of expr_t structs to form an intermediate
 * representation of the parsed abstract syntax tree. */
struct expr_t {
	unsigned long type;     /* History of the type of expression. operator? */
	struct list_t *exec;    /* Holds a list of words. */
	struct list_t *redirects;
	struct expr_t *next;    /* Next expression in the same scope. */
};

struct expr_t *cmd_create();
void           cmd_destroy(void *cmd);
int            cmd_gen_expr(struct expr_t *cmd);
struct expr_t *cmd_pipe(struct expr_t *lhs, struct expr_t *rhs);
void           cmd_to_char(struct expr_t *cmd, char **args);
int            cmd_do_internal(struct expr_t *cmd);
struct expr_t *cmd_last(struct expr_t *expr);
void           cmd_append(struct expr_t *lhs, struct expr_t *rhs);
void           cmd_print(struct expr_t *cmd);

/* Declare the type integer constants */
#define CMD_NONE             0x0        /* Default is invalid command */
#define CMD                  0x1        /* command */
#define CMD_BIT              0
#define CMD_SIMPLE           0x2        /* simple_command */
#define CMD_SIMPLE_BIT       1
#define CMD_SHELL            0x4        /* shell_command */
#define CMD_SHELL_BIT        2
#define CMD_FOR              0x8        /* for_command */
#define CMD_FOR_BIT          3
#define CMD_ARITH_FOR        0x10       /* arith_for_command */
#define CMD_ARITH_FOR_BIT    4
#define CMD_SELECT           0x20       /* select_command */
#define CMD_SELECT_BIT       5
#define CMD_CASE             0x40       /* case_command */
#define CMD_CASE_BIT         6
#define CMD_IF               0x80       /* if_command */
#define CMD_IF_BIT           7
#define CMD_GROUP            0x100      /* group_command */
#define CMD_GROUP_BIT        8
#define CMD_ARITH            0x200      /* arith_command */
#define CMD_ARITH_BIT        9
#define CMD_COND             0x400      /* cond_command */
#define CMD_COND_BIT         10
#define CMD_INTERNAL         0x800      /* internal command */
#define CMD_INTERNAL_BIT     11
#define CMD_BACGROUND        0x1000     /* background command */
#define CMD_BACKGROUND_BIT   12
#define PIPE_INPUT           0x2000     /* reading input from a pipe */
#define PIPE_INPUT_BIT       13
#define PIPE_OUTPUT          0x4000     /* writing output to a pipe */
#define PIPE_OUTPUT_BIT      14
#define CMD_ELSE             0x8000     /* else block */
#define CMD_ELSE_BIT         15
#define CMD_ELSE_IF          0x10000    /* else if block */
#define CMD_ELSE_IF_BIT      16
#define CMD_START_BLOCK      0x20000    /* start of block */
#define CMD_START_BLOCK_BIT  17
#define CMD_END_BLOCK        0x40000    /* end of block */
#define CMD_END_BLOCK_BIT    18
#define CMD_IN               0x80000    /* in operator */
#define CMD_IN_BIT           19
#define CMD_WHILE            0x100000   /* while expression */
#define CMD_WHILE_BIT        20
#define CMD_UNTIL            0x200000   /* until expression */
#define CMD_UNTIL_BIT        21
#define CMD_FUNCTION         0x400000   /* function block start */
#define CMD_FUNCTION_BIT     22
#define CMD_END_FUNCTION     0x800000   /* function block end */
#define CMD_END_FUNCTION_BIT 23
#define CMD_SUBSHELL         0x1000000  /* subshell command */
#define CMD_SUBSHELL_BIT     24

#define cmd_input_filename(cmd) \
	(((struct redirect_t *)list_peek(cmd->redirects))->input_filename)
#define cmd_output_filename(cmd) \
	(((struct redirect_t *)list_peek(cmd->redirects))->output_filename)
#define cmd_concat_filename(cmd) \
	(((struct redirect_t *)list_peek(cmd->redirects))->concat_filename)

#define cmd_set_type(cmd,flags)   (cmd->type |= flags)
#define CHECK_FLAG(flags,bit)     ((flags) & (1 << (bit)))

#define cmd_is_cmd(cmd)          (CHECK_FLAG(cmd->type, CMD_BIT))
#define cmd_is_simple(cmd)       (CHECK_FLAG(cmd->type, CMD_SIMPLE_BIT))
#define cmd_is_shell(cmd)        (CHECK_FLAG(cmd->type, CMD_SHELL_BIT))
#define cmd_is_for(cmd)          (CHECK_FLAG(cmd->type, CMD_FOR_BIT))
#define cmd_is_arith_for(cmd)    (CHECK_FLAG(cmd->type, CMD_ARITH_FOR_BIT))
#define cmd_is_select(cmd)       (CHECK_FLAG(cmd->type, CMD_SELECT_BIT))
#define cmd_is_case(cmd)         (CHECK_FLAG(cmd->type, CMD_CASE_BIT))
#define cmd_is_if(cmd)           (CHECK_FLAG(cmd->type, CMD_IF_BIT))
#define cmd_is_group(cmd)        (CHECK_FLAG(cmd->type, CMD_GROUP_BIT))
#define cmd_is_arith(cmd)        (CHECK_FLAG(cmd->type, CMD_ARITH_BIT))
#define cmd_is_cond(cmd)         (CHECK_FLAG(cmd->type, CMD_COND_BIT))
#define cmd_is_internal(cmd)     (CHECK_FLAG(cmd->type, CMD_INTERNAL_BIT))
#define cmd_is_background(cmd)   (CHECK_FLAG(cmd->type, CMD_BACKGROUND_BIT))
#define cmd_is_input_pipe(cmd)   (CHECK_FLAG(cmd->type, PIPE_INPUT_BIT))
#define cmd_is_output_pipe(cmd)  (CHECK_FLAG(cmd->type, PIPE_OUTPUT_BIT))
#define cmd_is_else(cmd)         (CHECK_FLAG(cmd->type, CMD_ELSE_BIT))
#define cmd_is_else_if(cmd)      (CHECK_FLAG(cmd->type, CMD_ELSE_IF_BIT))
#define cmd_is_sentinel(cmd)     (CHECK_FLAG(cmd->type, CMD_SENTINEL_BIT))
#define cmd_is_start_block(cmd)  (CHECK_FLAG(cmd->type, CMD_START_BLOCK_BIT))
#define cmd_is_end_block(cmd)    (CHECK_FLAG(cmd->type, CMD_END_BLOCK_BIT))
#define cmd_is_in(cmd)           (CHECK_FLAG(cmd->type, CMD_IN_BIT))
#define cmd_is_while(cmd)        (CHECK_FLAG(cmd->type, CMD_WHILE_BIT))
#define cmd_is_until(cmd)        (CHECK_FLAG(cmd->type, CMD_UNTIL_BIT))
#define cmd_is_function(cmd)     (CHECK_FLAG(cmd->type, CMD_FUNCTION_BIT))
#define cmd_is_end_function(cmd) (CHECK_FLAG(cmd->type, CMD_END_FUNCTION_BIT))
#define cmd_is_subshell(cmd)     (CHECK_FLAG(cmd->type, CMD_SUBSHELL_BIT))

/* FIXME: The following three functions are not correct. */
#define cmd_is_input_redir(cmd) \
	(CHECK_FLAG(cmd->type, REDIRECT_INPUT_BIT))
#define cmd_is_output_redir(cmd) \
	(CHECK_FLAG(cmd->type, REDIRECT_OUTPUT_BIT))
#define cmd_is_concat_redir(cmd) \
	(CHECK_FLAG(cmd->type, REDIRECT_CONCAT_BIT))

/* Creates a new command for a block if command. Sets the if command
 * 'if_expr' to the given if expression, and the 'body' to the given
 * body of the if expression. */
#define cmd_create_block(cmd, type) \
	cmd = cmd_create(); \
	if (!cmd) { \
		err_msg("error: [yyparse] Unable to create block command."); \
		YYABORT; \
	} \
	cmd_set_type(cmd, type);

#define cmd_mark_block(expr) \
	cmd_set_type(expr, CMD_START_BLOCK); \
	cmd_set_type(cmd_last(expr), CMD_END_BLOCK);

#define cmd_mark_function(expr) \
	cmd_set_type(expr, CMD_FUNCTION); \
	cmd_set_type(cmd_last(expr), CMD_END_FUNCTION);

#endif
