#ifndef REDIRECT_H
#define REDIRECT_H

struct redirect_t {
	int type;
	int input_fd;
	int output_fd;
	int fd[10];
	char *input_filename;
	char *output_filename;
	char *concat_filename;
};

#define REDIRECT_NONE        0x0
#define REDIRECT_INPUT       0x1  /* < */
#define REDIRECT_INPUT_BIT   0
#define REDIRECT_OUTPUT      0x2  /* > */
#define REDIRECT_OUTPUT_BIT  1
#define REDIRECT_CONCAT      0x4  /* >> */
#define REDIRECT_CONCAT_BIT  2

#define STDIN                0
#define STDOUT               1
#define STDERR               2

#define NUM_FDS              10

struct redirect_t *redirect_create();
void               redirect_destroy(void *redirect);
void               redirect_print(struct redirect_t *redir);

#endif
