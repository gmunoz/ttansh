#ifndef REDIRECT_C
#define REDIRECT_C

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include "error.h"
#include "redirect.h"

struct redirect_t *redirect_create()
{
	int i;
	struct redirect_t *redir;

	if ((redir = malloc(sizeof(struct redirect_t))) == NULL) {
		err_malloc(errno);
		return NULL;
	}

	redir->type = REDIRECT_NONE;
	redir->input_fd = -1;
	redir->output_fd = -1;
	redir->fd[0] = STDIN;
	redir->fd[1] = STDOUT;
	redir->fd[2] = STDERR;
	for (i = 3; i < NUM_FDS; i++)
		redir->fd[i] = -1;

	redir->input_filename = NULL;
	redir->output_filename = NULL;
	redir->concat_filename = NULL;

	return redir;
}

void redirect_destroy(void *redirect)
{
	if (!redirect)
		return;

	if (((struct redirect_t *)redirect)->input_filename)
		free(((struct redirect_t *)redirect)->input_filename);
	if (((struct redirect_t *)redirect)->output_filename)
		free(((struct redirect_t *)redirect)->output_filename);
	if (((struct redirect_t *)redirect)->concat_filename)
		free(((struct redirect_t *)redirect)->concat_filename);
	free(redirect);
}

void redirect_print(struct redirect_t *redir)
{
	if (!redir)
		return;

/* TODO: Fix the redirection type detection to use the bit flags. */
	err_msg("  + redirect:");
	switch (redir->type) {
		case REDIRECT_NONE:
			err_msg("      -> type [%d]: no redirect info", redir->type);
			break;
		case REDIRECT_OUTPUT:
			err_msg("      -> type [%d]: output redirection", redir->type);
			break;
		case REDIRECT_INPUT:
			err_msg("      -> type [%d]: input redirection", redir->type);
			break;
		default:
			err_msg("      -> type [%d]: NOT of a registered type!", redir->type);
			break;
	}
	err_msg("      -> filename: %s", redir->input_filename);
	err_msg("      -> filename: %s", redir->output_filename);
	err_msg("      -> filename: %s", redir->concat_filename);
}

#endif
