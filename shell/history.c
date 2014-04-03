#ifndef HISTORY_C
#define HISTORY_C

#include "history.h"

/* Do pre-processing on LINE. If PRINT_CHANGES is non-zero, then print
 * the results of expanding the line if there were any changes. If there
 * is an error, return NULL, otherwise the expanded line is returned. If
 * ADDIT is non-zero the line is added to the history list after history
 * expansion. ADDIT is just a suggestion; REMEMBER_ON_HISTORY can veto,
 * and does. Right now this does history expansion. */
char *
pre_process_line (char *line, int print_changes, int addit)
{
	return line;
}

#endif
