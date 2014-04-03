#ifndef CMD_C
#define CMD_C

#include <stdlib.h>
#include <errno.h>
#include "error.h"
#include "cmd.h"
#include "list.h"

/***********************************************************************
 * Allocates, initializes, and returns a command structure. The
 * structure remains empty, and needs to be filled in.
 *
 * Parameters:
 *   None.
 *
 * Return value:
 *   Returns a pointer to a command structure that has been initialized
 *   with sane, default values. On error, NULL is returned.
 **********************************************************************/
struct expr_t *cmd_create()
{
	struct expr_t *cmd;

	cmd = malloc(sizeof(struct expr_t));
	if (!cmd) {
		err_malloc(errno);
		return NULL;
	}

	cmd->exec = list_create(free);
	if (!cmd->exec) {
		err_list_create(errno);
		free(cmd);
		return NULL;
	}

	cmd->type = CMD_NONE;
	cmd->redirects = NULL;
	cmd->next = NULL;

	return cmd;
}

/***********************************************************************
 * Destroys the given command structure. All dynamically allocated
 * memory contained in the command structure is released, including the
 * container for the command structure itself. The resulting command
 * structure after this method is invoked may be used again in creating
 * a command and no memory leaks will result.
 *
 * Parameters:
 *   cmd: The command structure to destroy from memory.
 *
 * Return value:
 *   None.
 **********************************************************************/
void cmd_destroy(void *cmd)
{
	if (!cmd) {  /* Base case - NULL expression */
		return;
	} else {  /* Recursive case */
		cmd_destroy(((struct expr_t *)cmd)->next);
		list_destroy(((struct expr_t *)cmd)->exec);
		list_destroy(((struct expr_t *)cmd)->redirects);
		free(cmd);
	}
}

int cmd_gen_expr(struct expr_t *cmd)
{
	int ret = 0;

	switch (cmd->type) {
		case CMD_NONE:
			break;
		case CMD:
			break;
		case CMD_SIMPLE:
			ret = gen_cmd_simple(cmd);
			break;
		default:
			err_msg("error: [cmd_gen_expr] Not a valid command type. No implementation.");
			ret = -1;
			break;
	}

	return ret;
}

/*
 * Takes two command structures and merges them into a single command
 * structure that relate to each other by a pipe '|'. The full command
 * was parsed as `lhs | rhs', so the pipeline is setup with the output
 * of 'lhs' going into the input of the 'rhs'.
 *
 * Parameters:
 *   lhs: The command whose output serves as input to the 'rhs'.
 *   rhs: The command that takes as input from 'lhs'.
 *
 * Return Value:
 *   Returns -1 on error or 0 on success.
 */
struct expr_t *cmd_pipe(struct expr_t *lhs, struct expr_t *rhs)
{
	/* Operator precedence dictates the left-hand-side to be evaluated
	 * before the right-hand-side. */
	lhs->type |= PIPE_OUTPUT;
	rhs->type |= PIPE_INPUT;
	lhs->next = rhs;

	return lhs;
}

void cmd_to_char(struct expr_t *cmd, char **args)
{
  int i = 0;
  list_node_t *node = NULL;
  list_foreach(cmd->exec, node) {
    args[i] = (char *)list_key(node);
    i++;
  }
  args[i] = NULL;
}

int cmd_do_internal(struct expr_t *cmd)
{
	return 0;
}

static void cmd_print_recursive(struct expr_t *cmd, int scope,
		int cmd_num, int block_num)
{
	if (!cmd)  /* base case is a null command */
		return;

	char buf[(scope * 2) + 1];
	int i;

	if (cmd_is_start_block(cmd) || cmd_is_function(cmd)) {
		scope++;
		block_num = cmd_num;
		cmd_num = 0;
	}

	for (i = 0; i < (scope * 2); i++)
		buf[i] = ' ';
	buf[i] = '\0';

	err_msg("%s+ scope %d command #%d:", buf, scope, cmd_num);
	err_msg("%s  - type [%d]:", buf, cmd->type);
	if (cmd->type == CMD_NONE)
		err_msg("%s      NOT of a registered type!", buf);
	if (cmd_is_cmd(cmd))
		err_msg("%s      command", buf);
	if (cmd_is_simple(cmd))
		err_msg("%s      simple_command", buf);
	if (cmd_is_shell(cmd))
		err_msg("%s      shell_command", buf);
	if (cmd_is_for(cmd))
		err_msg("%s      for_command", buf);
	if (cmd_is_arith_for(cmd))
		err_msg("%s      arith_for_command", buf);
	if (cmd_is_select(cmd))
		err_msg("%s      select_command", buf);
	if (cmd_is_case(cmd))
		err_msg("%s      case_command", buf);
	if (cmd_is_if(cmd))
		err_msg("%s      if_command", buf);
	if (cmd_is_group(cmd))
		err_msg("%s      group_command", buf);
	if (cmd_is_arith(cmd))
		err_msg("%s      arith_command", buf);
	if (cmd_is_cond(cmd))
		err_msg("%s      cond_command", buf);
	if (cmd_is_internal(cmd))
		err_msg("%s      internal_command", buf);
	if (cmd_is_background(cmd))
		err_msg("%s      background_command", buf);
	if (cmd_is_subshell(cmd))
		err_msg("%s      subshell expression", buf);
	if (cmd_is_input_pipe(cmd))
		err_msg("%s      input pipe", buf);
	if (cmd_is_output_pipe(cmd))
		err_msg("%s      output pipe", buf);
	if (cmd_is_else(cmd))
		err_msg("%s      else expression", buf);
	if (cmd_is_else_if(cmd))
		err_msg("%s      else if expression", buf);
	if (cmd_is_while(cmd))
		err_msg("%s      while expression", buf);
	if (cmd_is_until(cmd))
		err_msg("%s      until expression", buf);
	if (cmd_is_in(cmd))
		err_msg("%s      in operator", buf);
	if (cmd_is_start_block(cmd))
		err_msg("%s      start block", buf);
	if (cmd_is_end_block(cmd))
		err_msg("%s      end block", buf);
	if (cmd_is_function(cmd))
		err_msg("%s      start function block", buf);
	if (cmd_is_end_function(cmd))
		err_msg("%s      end function block", buf);

	err_msg("%s  - exec list:", buf);
	i = 0;
	list_node_t *node;
	list_foreach(cmd->exec, node) {
		err_msg("%s      [%d] => %s", buf, i++, (char *)list_key(node)); 
	}

	if (cmd->redirects) {
		list_foreach(cmd->redirects, node) {
			redirect_print((struct redirect_t *)list_key(node));
		}
	} else {
		err_msg("%s  - No redirections", buf);
	}

	if (cmd_is_end_block(cmd) || cmd_is_end_function(cmd)) {
		scope--;
		cmd_num = block_num - 1;
	}

	cmd_print_recursive(cmd->next, scope, ++cmd_num, block_num);
}

/*
 * Returns the last expression in the given list of expressions 'expr'.
 */
struct expr_t *cmd_last(struct expr_t *expr)
{
	struct expr_t *e;
	for (e = expr; e->next; e = e->next)
		;
	return e;
}

/*
 * Appends the right hand side (rhs) to the end of the left hand side
 * (lhs). Recall that the rhs and lhs are expression structures, which
 * are linked lists. So, this function traverses 'lhs' to until it finds
 * a NULL next element, and places rhs on this element.
 *
 * NOTE: The number of expressions to traverse has no limit. It will be
 * however long a block (compound_list) is in the shell code.
 *
 * Parameters:
 *   lhs: The expression to traverse until a NULL element is found for
 *     storing the 'rhs'.
 *   rhs: The expression to store onto the 'lhs'.
 *
 * Return Value:
 *   None.
 */
void cmd_append(struct expr_t *lhs, struct expr_t *rhs)
{
	cmd_last(lhs)->next = rhs;
}

/*
 * Prints the given command structure. Used primarily for debugging.
 */
void cmd_print(struct expr_t *cmd)
{
	cmd_print_recursive(cmd, 0, 0, 0);
}

#endif
