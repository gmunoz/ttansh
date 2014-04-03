/***********************************************************************
 * Author: Gabriel Munoz
 * Date: March 1, 2004
 * File: tansh.c
 * Description: This code uses the lexical analyzer `lex' to parse
 *   commands entered by the user, and executes them as a normal shell
 *   would. Starting code was provided by Dr. Tan, although most, but
 *   not necessarily all, code was re-written to handle our own list
 *   data structure. This shell is fully functional for the requirements
 *   of the lab (see DESIGN for specific requirements). It does not
 *   implement more advanced shell behavior, such as 1) environment
 *   modification, 2) logical operators (&&, ||, etc.), 3) basic
 *   programming constructs (if, for, while), 4) script file
 *   interpretation. It will support basic operations such as 1)
 *   backgrounding, 2) input/output redirection, 3) arbitrary number of
 *   commands, 4) piping (with arbitrary number of pipes). All errors
 *   are checked for and handled as well as possible. A shell should
 *   never exit on a user, unless explicitly asked to through the
 *   internal command `exit'.
 **********************************************************************/

#ifndef TANSH_C
#define TANSH_C

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <errno.h>
#include <signal.h>
#include <setjmp.h>
#include <sys/wait.h>
#include "tansh.h"
#include "cmd.h"
#include "list.h"
#include "error.h"

/* Forward declarations for all static functions in this file. */
static int try_jump(void);
static void sigchld_handler(int signal);
static void sigint_handler(int signal);
static void cleanup(list_t *cmd_list);
static int do_tansh(FILE *file);

/* Global variables to this file - used for command state */
static sigjmp_buf jmpbuf;
static volatile sig_atomic_t jmpok = 0;

void parse(FILE *file);

int test_main(int argc, char *argv[])
{
	FILE *file = NULL;
	if (argc == 2) {
		file = fopen(argv[1], "r");
		if (!file)
			fprintf(stderr, "test_bash: main: unable to fopen '%s'\n", argv[1]);
	}
	if (file) {
		fprintf(stderr, "parsing file\n");
		parse(file);
		fclose(file);
	} else {
		fprintf(stderr, "parsing command line\n");
		while (1)
			parse(NULL);
	}

	return 0;
}

/*
 * Jump to the starting point for this application (just before the
 * read-eval-print loop). If it is not a valid point to jump, then
 * return -1, else do the jump and return nothing.
 */
static int try_jump(void)
{
	if (jmpok == 0)
		return -1;
	siglongjmp(jmpbuf, 1);
}

/*
 * Handle exit signals from child processes
 */
static void sigchld_handler(int signal)
{
	/* Perform a non-blocking wait. Do not perform any error handling
	 * because this wait is not guaranteed to actually release the
	 * resources of a child, as it may have already been released by the
	 * parent. This will prevent zombie processes from persisting from
	 * commands that return from the background. */
	waitpid(-1, NULL, WNOHANG);
}

/*
 * Handle <CTRL + C> events from the user. The shell should never exit
 * abnormally, unless a serious error has occurred. This event should
 * signal the SIGINT event to the current shell command, if any.
 * Otherwise, just print the shell prompt and enter the parsing routine.
 */
static void sigint_handler(int signal)
{
	try_jump();
}

/*
 * Release all data structures from memory.
 */
static void cleanup(list_t *cmd_list)
{
	list_destroy(cmd_list);
}

/*
 * The main shell function
 */ 
int main(int argc, char *argv[])
{
	test_main(argc, argv);
	return 0;

	/* Set up the signal handler for SIGCHLD (when a child is terminated,
	 * stopped, or continued */
	struct sigaction act_sigchld;
	act_sigchld.sa_handler = sigchld_handler;
	if (sigemptyset(&act_sigchld.sa_mask) == -1) {
		err_sigsetops();
		return -1;
	}
	/* We're only interested in children that have terminated, not ones
	 * which have been stopped (eg user pressing control-Z at terminal) */
	act_sigchld.sa_flags = SA_NOCLDSTOP;
	if (sigaction(SIGCHLD, &act_sigchld, NULL) == -1) {
		err_sigaction();
		return -1;
	}

	/* Set up a signal handler for SIGINT <CTRL + C> */
	struct sigaction act_sigint;
	act_sigint.sa_handler = sigint_handler;
	if (sigemptyset(&act_sigint.sa_mask) == -1) {
		err_sigsetops();
		return -1;
	}
	act_sigint.sa_flags = 0;  /* No special options */
	if (sigaction(SIGINT, &act_sigint, NULL) == -1) {
		err_sigaction();
		return -1;
	}

	/* Check for input files. Use the file as input if it exists, other
	 * wise assume interactive processing (interactive shell). */
	if (argc == 1) {
		do_tansh(NULL);
	} else {  /* Process command-line arguments as if they are files */
		int i = 1;
		while (i < argc) {
			FILE *file = NULL;
			file = fopen(argv[i], "r");
			if (file == NULL) {
				err_fopen(errno);
				err_msg("tansh: warning: Invalid file '%s'.", argv[i]);
			} else {  /* No error occured and it is a valid file */
				do_tansh(file);
				fclose(file);
			}
			i++;
		}
	}

	return 0;
}

static int do_tansh(FILE *file)
{
	int n;
	list_t *cmd_list = NULL;  /* Holds list of commands that are parsed */
	sigset_t intmask;         /* For signal handler setting/unsetting */
	while (1) {
		/* Save stack context and set jump point for use later */
		if (sigsetjmp(jmpbuf, 1) == 1)
			printf("\n");  /* Reset shell prompt to next line */
		jmpok = 1;

		/* Print the shell prompt if interactive, or set the 'finished'
		 * switch to properly parse and execute the 'file' once. */
		if (!file)
			printf("$ ");

		/* Re-initialize the `cmd_list' list to store complex command(s) */
		if ((cmd_list = list_create(cmd_destroy)) == NULL) {
			err_malloc(0);
			return -1;
		}

		/* Block SIGCHLD signals while we get the next line of input via
		 * yylex()/yyparse(). These functions are not signal safe! */
		if ((sigemptyset(&intmask) == -1) ||
				(sigaddset(&intmask, SIGCHLD) == -1)) {
			err_sigsetops();
			return -1;
		} else if (sigprocmask(SIG_BLOCK, &intmask, NULL) == -1) {
			err_sigprocmask();
			return -1;
		}

		//parse(cmd_list, file);

		/* Unblock SIGCHLD signals now that we are past non-signal safe
		 * functions. */
		if (sigprocmask(SIG_UNBLOCK, &intmask, NULL) == -1) {
			err_sigprocmask();
			cleanup(cmd_list);
			return -1;
		}

		/* Do the command if at least one command exists (not zero), and
		 * parse() didn't return and error condition (not null). */
		if (cmd_list == NULL) {
			err_parse();
		} else if (list_size(cmd_list) != 0) {
#ifndef NDEBUG
			int i = 0;
			list_node_t *node = NULL;
			list_foreach(cmd_list, node) {
				err_msg("Command # %d", i);
				cmd_print(list_key(node));
				i++;
			}
#endif
			n = do_command(cmd_list, NULL);
			if (n == -1)
				err_msg("do_tansh: warning: Critical shell command execution error.");
			else if (n == 1)
				err_msg("do_tansh: warning: Invalid internal command.");
		}

		list_destroy(cmd_list);
	}

	return 0;
}

/* 
 * Do the command
 * 1) Base case - empty list
 * 2) Else, shift first element off the top of the list
 *   3) Set up a pipe (if necessary)
 *   4) Execute the command in a fork'ed process
 *   5) Recurse on do_command with the shifted list
 *
 * Return Value:
 *   Returns 0 on success, -1 on critical command exec[ution] error, or
 *   1 on invalid internal command.
 */
int do_command(list_t *cmd_list, int *fd_in)
{
	if (list_size(cmd_list) == 0) {  /* Base case - empty list */
		return 0;
	} else {  /* Recursive case */
		int ret;  /* Stores a return value, not meaningful beyond that */
		int i;
		int fd_out[2];
		pid_t child_id;
		FILE *file;

		/* Remove the first element */
		struct expr_t *cmd = list_shift(cmd_list);

		/* Check if internal command and execute if it is an internal cmd */
		/* FIXME: Internal commands should be better integrated into the
		 * rest of the commands so they will work in pipes, redirection. */
		if (cmd_is_internal(cmd)) {
			if (cmd_do_internal(cmd) == 0) {
				cmd_destroy(cmd);
				do_command(cmd_list, NULL);
				return 0;
			} else {
				cmd_destroy(cmd);
				return 1;
			}
		}

		/* Set up piping, if required */
		if (cmd_is_output_pipe(cmd) && pipe(fd_out) == -1)
			err_pipe(errno);

		/* Execute the command in a forked process */
		/* Fork a child process */
		child_id = fork();
		if (child_id == -1)
			err_fork(errno);

		if (child_id == 0) {  /* This is a child */
			/* Check for input redirection */
			/* TODO: Perhaps all redirection handling code should be handled
			 * internal to the redirection file. */
			/* FIXME: There can be > 1 redirections. Make a function to handle
			 * the generic redirection list. */
			if (cmd_is_input_redir(cmd)) {
				file = freopen(cmd_input_filename(cmd), "r", stdin);
				if (!file)
					err_freopen(errno);
			}

			/* Check for output redirection */
			/* FIXME: There can be > 1 redirections. Make a function to handle
			 * the generic redirection list. */
			if (cmd_is_output_redir(cmd)) {
				file = freopen(cmd_output_filename(cmd), "w+", stdout);
				if (!file)
					err_freopen(errno);
			}

			/* Check for output concatenation */
			/* FIXME: There can be > 1 redirections. Make a function to handle
			 * the generic redirection list. */
			if (cmd_is_concat_redir(cmd)) {
				file = freopen(cmd_concat_filename(cmd), "a", stdout);
				if (!file)
					err_freopen(errno);
			}

			if (!cmd_is_input_pipe(cmd) && cmd_is_output_pipe(cmd)) {
				/* Open a pipe to write to stdout. This is executed if
				 * there is a pipe in the command and it only needs to
				 * direct is stdout to the write end of the pipe. */
				ret = dup2(fd_out[1], STDOUT_FILENO);
				if (ret == -1) {
					err_dup2(errno);
					return -1;
				}

				ret = close(fd_out[0]);
				if (ret == -1) {
					err_close(errno);
					return -1;
				}
			} else if (cmd_is_input_pipe(cmd) && !cmd_is_output_pipe(cmd)) {
				/* Open a pipe to read from stdin. This is run if there
				 * is a pipe in the command and it only needs to direct
				 * the read end of the pipe to its stdin. */
				ret = dup2(fd_in[0], STDIN_FILENO);
				if (ret == -1) {
					err_dup2(errno);
					return -1;
				}

				ret = close(fd_in[1]);
				if (ret == -1) {
					err_close(errno);
					return -1;
				}
			} else if (cmd_is_input_pipe(cmd) && cmd_is_output_pipe(cmd)) {
				/* Open a pipe to read from stdin, and open a pipe to
				 * write to stdout. This is executed only if there is a
				 * pipe and the command is in the middle of a pipeline,
				 * therefore requiring 2 pipe file descriptors. */
				ret = dup2(fd_in[0], STDIN_FILENO);
				if (ret == -1) {
					err_dup2(errno);
					return -1;
				}

				ret = dup2(fd_out[1], STDOUT_FILENO);
				if (ret == -1) {
					err_dup2(errno);
					return -1;
				}

				ret = close(fd_in[1]);
				if (ret == -1) {
					err_close(errno);
					err_msg("warning: [do_command] Unable to close fd_in[1]) in child.");
					return -1;
				}
				ret = close(fd_out[0]);
				if (ret == -1) {
					err_close(errno);
					err_msg("warning: [do_command] Unable to close fd_out[0] in child.");
					return -1;
				}
			}

			/* Convert list of commands and argument(s) to char array */
			char *args[list_size(cmd->exec) + 1];
			cmd_to_char(cmd, args);

			/* Execute the command that we parsed out of our struct */
			execvp(args[0], args);
			err_exec(errno);
			err_msg("tansh: `%s' failed to exec", args[0]);

			exit(-1);  /* This line only executes if execvp fails */
		} /* Parent will continue after this conditional */

		/* Close appropriate pipe file descriptors in the parent */
		if (cmd_is_input_pipe(cmd)) {
			for (i = 0; i < 2; i++) {
				ret = close(fd_in[i]);
				if (ret == -1) {
					err_close(errno);
					err_msg("warning: [do_command] Unable to close fd_in[%d] in parent.", i);
					return -1;
				}
			}
		}

		/* TODO: Write a generic function to block given signals. */
		/* Wait for the child process to complete, if it is necessary.
		 * NOTE: the wait(2) family of functions is *not* signal safe
		 * when used without WNOHANG, so block the SIGCHLD signal for
		 * possible waits here. This does contradict the POSIX standard
		 * regarding wait(2), but I had the errors report exactly this
		 * problem. */
		sigset_t intmask;
		if (sigemptyset(&intmask) == -1 || sigaddset(&intmask, SIGCHLD) == -1)
			err_sigsetops();
		else if (sigprocmask(SIG_BLOCK, &intmask, NULL) == -1)
			err_sigprocmask();

		if (!cmd_is_background(cmd) && !cmd_is_output_pipe(cmd))
			waitpid(child_id, NULL, 0);

		/* Unblock SIGCHLD signals now that we are past non-signal safe
		 * functions. */
		if (sigprocmask(SIG_UNBLOCK, &intmask, NULL) == -1)
			err_sigprocmask();

		/* Recurse on the rest of the list */
		do_command(cmd_list, fd_out);

		/* Wait for zombie processes when using pipes. Do not perform
		 * error handling as the processes are not guaranteed to be
		 * zombie processes. So, wait for any process, and do not hang. */
		if (cmd_is_input_pipe(cmd) || cmd_is_output_pipe(cmd));
			waitpid(child_id, NULL, WNOHANG);
		
		/* Destroy remaining command that was being processed. */
		cmd_destroy(cmd);
	}

	return 0;
}

#endif
