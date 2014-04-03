/****************************************************************************
 * Author: Gabriel Munoz
 * Date: March 1, 2004
 * File: errors.h
 * Description: This file contains the function prototypes for handling
 *   system call errors.
 ***************************************************************************/

#ifndef ERRORS_H
#define ERRORS_H

/* General error handling functions */
void err_ret(const char *fmt, ...);
void err_sys(const char *fmt, ...);
void err_dump(const char *fmt, ...);
void err_msg(const char *fmt, ...);
void err_quit(const char *fmt, ...);

/* Syscall error handlers */
void err_wait(int err);
void err_freopen(int err);
void err_exec(int err);
void err_fork(int err);
void err_pipe(int err);
void err_dup2(int err);
void err_close(int err);
void err_kill(int err);
void err_sigaction(void);
void err_sigsetops(void);
void err_sigprocmask(void);
void err_malloc(int err);
void err_chdir(int err);
void err_parse(void);
void err_sendmsg(int err);
void err_recvmsg(int err);
void err_inet_pton(int err);
void err_inet_ntop(int err);
void err_gethostname(int err);
void err_socket(int err);
void err_bind(int err);
void err_sendto(int err);
void err_recvfrom(int err);
void err_shmget(int err);
void err_shmat(int err);
void err_shmctl(int err);
void err_shmdt(int err);
void err_open(int err);
void err_write(int err);
void err_getsockname(int err);
void err_getaddrinfo(int err);
void err_fstat(int err);
void err_mmap(int err);
void err_fopen(int err);

/* Custom function error handlers */
void err_list_create(int err);
void err_dsh_cmd_send();
void err_dsh_send(int err);
void err_cmd_create(int err);

#endif
