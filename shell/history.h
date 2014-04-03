#ifndef HISTORY_H
#define HISTORY_H

/* Non-zero means to remember lines typed to the shell on the history
 * list.  This is different than the user-controlled behaviour; this
 * becomes zero when we read lines from a file, for example. */
int remember_on_history = 1;

/* The number of lines that Bash has added to this history session.  The
 * difference between the number of the top element in the history list
 * (offset from history_base) and the number of lines in the history
 * file. Appending this session's history to the history file resets
 * this to 0. */
int history_lines_this_session;

/* The number of lines that Bash has read from the history file. */
int history_lines_in_file;

char *pre_process_line (char *line, int print_changes, int addit);

#endif
