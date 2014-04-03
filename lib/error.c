/****************************************************************************
 * Author: Gabriel Munoz
 * Date: March 1, 2004
 * File: error.c
 * Description: This file contains the implementation for system call
 *   error handling. The checking of errno and other global error
 *   constants are checked according to their respective man pages.
 ***************************************************************************/

#ifndef ERRORS_C
#define ERRORS_C

#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include "error.h"

#define MAXLINE    4096  /* Max text line length */

#define perrno(err) fprintf(stderr, "       errno is: %d\n", err);
#define pstrerror(err) fprintf(stderr, "       %s\n", strerror(err));

int daemon_proc;  /* set nonzero by daemon_init() */

static void err_doit(int, int, const char *, va_list);

/* Nonfatal error related to system call
 * Print message and return */

void err_ret(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	err_doit(1, LOG_INFO, fmt, ap);
	va_end(ap);
	return;
}

/* Fatal error related to system call
 * Print message and terminate */

void err_sys(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	err_doit(1, LOG_ERR, fmt, ap);
	va_end(ap);
	exit(1);
}

/* Fatal error related to system call
 * Print message, dump core, and terminate */

void err_dump(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	err_doit(1, LOG_ERR, fmt, ap);
	va_end(ap);
	abort();  /* dump core and terminate */
	exit(1);  /* shouldn't get here */
}

/* Nonfatal error unrelated to system call
 * Print message and return */

void err_msg(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	err_doit(0, LOG_INFO, fmt, ap);
	va_end(ap);
	return;
}

/* Fatal error unrelated to system call
 * Print message and terminate */

void err_quit(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	err_doit(0, LOG_ERR, fmt, ap);
	va_end(ap);
	exit(1);
}

/* Print message and return to caller
 * Caller specifies "errnoflag" and "level" */

static void err_doit(int errnoflag, int level, const char *fmt, va_list ap)
{
	int errno_save, n;
	char buf[MAXLINE + 1];

	memset(buf, 0, MAXLINE + 1);

	errno_save = errno;  /* value caller might want printed */
#ifdef	HAVE_VSNPRINTF
	vsnprintf(buf, MAXLINE, fmt, ap);  /* safe */
#else
	vsprintf(buf, fmt, ap);            /* not safe */
#endif
	n = strlen(buf);
	if (errnoflag)
		snprintf(buf + n, MAXLINE - n, ": %s", strerror(errno_save));
	strcat(buf, "\n");

	if (daemon_proc) {
		syslog(level, buf);
	} else {
		fflush(stdout);  /* in case stdout and stderr are the same */
		fputs(buf, stderr);
		fflush(stderr);
	}
	return;
}

void err_wait(int err)
{
	fprintf(stderr, "error: wait() family function caused an error\n");
	switch(err) {
		case ECHILD:
			fprintf(stderr, "       Child does not exist for this process\n");
			break;
		case EINVAL:
			fprintf(stderr, "       Invalid options\n");
			break;
		case EINTR:
			fprintf(stderr, "       Unblocked signal or SIGCHLD was caught while WNOHANG was not set\n");
			break;
		default:
			fprintf(stderr, "       wait family type error has occurred\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_freopen(int err)
{
	fprintf(stderr, "error: freopen() function caused an error\n");
	switch(err) {
		case EINVAL:
			fprintf(stderr, "       The mode provided to fopen, fdopen, or freopen was invalid.\n");
			break;
		case ENOMEM:
			fprintf(stderr, "       Not enough memory.\n");
			break;
		default:
			fprintf(stderr, "       freopen() unknown errno type encountered\n");
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_exec(int err)
{
	/* Numberic constants mentioned in the man page for execve(2) cannot
	 * be handled explicitly here because I have no idea where they are
	 * defined on this system. */
	fprintf(stderr, "error: exec family command failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_fork(int err)
{
	fprintf(stderr, "error: fork(2) system call failed\n");
	switch(err) {
		case EAGAIN:
			fprintf(stderr, "       fork cannot allocate sufficient memory to copy the parent's page\n");
			fprintf(stderr, "       tables and allocate a task structure for the child.\n");
			break;
		case ENOMEM:
			fprintf(stderr, "       fork failed to allocate the necessary kernel structures because\n");
			fprintf(stderr, "       memory is tight.\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_pipe(int err)
{
	fprintf(stderr, "PIPE FAILED: %d!\n", err);
	fflush(stderr);
}

void err_dup2(int err)
{
	fprintf(stderr, "DUP2 FAILED: %d!\n", err);
	fflush(stderr);
}

void err_close(int err)
{
	fprintf(stderr, "CLOSE FAILED: %d!\n", err);
	fflush(stderr);
}

void err_kill(int err)
{
	fprintf(stderr, "error: kill system call failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_sigaction(void)
{
	fprintf(stderr, "error: sigaction(2) failed\n");
	fflush(stderr);
}

void err_sigsetops(void)
{
	fprintf(stderr, "error: Failed to initialize the signal set\n");
	fflush(stderr);
}

void err_sigprocmask(void)
{
	fprintf(stderr, "error: Failed to block SIGCHLD\n");
	fflush(stderr);
}

void err_malloc(int err)
{
	fprintf(stderr, "error: malloc(3) failed to allocate memory - %d\n", err);
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_chdir(int err)
{
	fprintf(stderr, "error: chdir(2) failed to change directory - %d\n", err);
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_sendmsg(int err)
{
	fprintf(stderr, "error: sendmsg(2) syscall failed\n");
	switch (err) {
		case EACCES:
			fprintf(stderr, "       (For  Unix  domain  sockets,  which  are identified by pathname)\n");
			fprintf(stderr, "       Write permission is denied on the destination  socket  file,  or\n");
			fprintf(stderr, "       search  permission is denied for one of the directories the path\n");
			fprintf(stderr, "       prefix. (See path_resolution(2).)\n");
			break;
		case EAGAIN:
			fprintf(stderr, "       The socket is marked non-blocking and  the requested  operation\n");
			fprintf(stderr, "       would block.\n");
			break;
		case EBADF:
			fprintf(stderr, "       An invalid descriptor was specified.\n");
			break;
		case ECONNRESET:
			fprintf(stderr, "       Connection reset by peer.\n");
			break;
		case EDESTADDRREQ:
			fprintf(stderr, "       The socket is not connection-mode, and no peer address is set.\n");
			break;
		case EFAULT:
			fprintf(stderr, "       An invalid user space address was specified for a parameter.\n");
			break;
		case EINTR:
			fprintf(stderr, "       A signal occurred before any data was transmitted.\n");
			break;
		case EINVAL:
			fprintf(stderr, "       Invalid argument passed.\n");
			break;
		case EISCONN:
			fprintf(stderr, "       The connection-mode socket was connected already but a recipient\n");
			fprintf(stderr, "       was specified.  (Now either  this  error is  returned,  or  the\n");
			fprintf(stderr, "       recipient specification is ignored.)\n");
			break;
		case EMSGSIZE:
			fprintf(stderr, "       The  socket  type  requires that message be sent atomically, and\n");
			fprintf(stderr, "       the size of the message to be sent made this impossible.\n");
			break;
		case ENOBUFS:
			fprintf(stderr, "       The output queue for a network interface was full.  This  gener-\n");
			fprintf(stderr, "       ally  indicates  that the interface has stopped sending, but may\n");
			fprintf(stderr, "       be caused by transient congestion. (Normally,  this  does  not\n");
			fprintf(stderr, "       occur  in Linux. Packets are just silently dropped when a device\n");
			fprintf(stderr, "       queue overflows.)\n");
			break;
		case ENOMEM:
			fprintf(stderr, "       No memory available.\n");
			break;
		case ENOTCONN:
			fprintf(stderr, "       The socket is not connected, and no target has been given.\n");
			break;
		case ENOTSOCK:
			fprintf(stderr, "       The argument s is not a socket.\n");
			break;
		case EOPNOTSUPP:
			fprintf(stderr, "       Some bit in the flags argument is inappropriate for  the  socket\n");
			fprintf(stderr, "       type.\n");
			break;
		case EPIPE:
			fprintf(stderr, "       The  local  end  has  been  shut  down  on a connection oriented\n");
			fprintf(stderr, "       socket.  In this case the process will also  receive  a  SIGPIPE\n");
			fprintf(stderr, "       unless MSG_NOSIGNAL is set.\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_recvmsg(int err)
{
	fprintf(stderr, "error: recvmsg(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_inet_pton(int err)
{
	fprintf(stderr, "error: inet_pton(3) syscall failed\n");
	switch (err) {
		/* errno may not be set, in this case it is a special error */
		case 0:
			fprintf(stderr, "       Source host does not contain a character string representing\n");
			fprintf(stderr, "       a valid network address in the specified address family\n");
			break;
		case EAFNOSUPPORT:
			fprintf(stderr, "       Domain does not contain a valid address family\n");
			perrno(err);
			pstrerror(err);
			break;
		default:
			perrno(err);
			pstrerror(err);
			break;
	}
	fflush(stderr);
}

void err_sendto(int err)
{
	fprintf(stderr, "error: sendto(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_shmget(int err)
{
	fprintf(stderr, "error: shmget(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_shmat(int err)
{
	fprintf(stderr, "error: shmat(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_shmctl(int err)
{
	fprintf(stderr, "error: shmctl(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_shmdt(int err)
{
	fprintf(stderr, "error: shmdt(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_recvfrom(int err)
{
	fprintf(stderr, "error: recvfrom(2) syscall failed\n");
	switch (err) {
		case EAGAIN:
			fprintf(stderr, "       The  socket  is  marked  non-blocking  and the receive operation\n");
			fprintf(stderr, "       would block, or a receive timeout had been set and  the  timeout\n");
			fprintf(stderr, "       expired before data was received.\n");
			break;
		case EBADF:
			fprintf(stderr, "       The argument s is an invalid descriptor.\n");
			break;
		case ECONNREFUSED:
			fprintf(stderr, "       A remote host refused to allow the network connection (typically\n");
			fprintf(stderr, "       because it is not running the requested service).\n");
			break;
		case EFAULT:
			fprintf(stderr, "       The  receive  was interrupted by delivery of a signal before any\n");
			fprintf(stderr, "       data were available.\n");
			break;
		case EINVAL:
			fprintf(stderr, "       Invalid argument passed.\n");
			break;
		case ENOMEM:
			fprintf(stderr, "       The socket is associated with a connection-oriented protocol and\n");
			fprintf(stderr, "       has not been connected (see connect(2) and accept(2)).\n");
			break;
		case ENOTSOCK:
			fprintf(stderr, "       The argument s does not refer to a socket.\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_inet_ntop(int err)
{
	fprintf(stderr, "error: inet_ntop(3) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_gethostname(int err)
{
	fprintf(stderr, "error: gethostname(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_socket(int err)
{
	fprintf(stderr, "error: socket(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_bind(int err)
{
	fprintf(stderr, "error: bind(2) syscall failed\n");
	switch (err) {
		case EACCES:
			fprintf(stderr, "The address is protected, and the user is not the super-user.\n");
			fprintf(stderr, "If domain is AF_UNIX: Search  permission  is denied on a component\n");
			fprintf(stderr, "of the path prefix. (See also path_resolution(2).)\n");
			break;
		case EBADF:
			fprintf(stderr, "sockfd is not a valid descriptor.\n");
			break;
		case EINVAL:
			fprintf(stderr, "The socket is already bound to an address.\n");
			fprintf(stderr, "If domain is AF_UNIX: The addrlen is wrong, or the socket was not\n");
			fprintf(stderr, "in the AF_UNIX  family.\n");
			break;
		case ENOTSOCK:
			fprintf(stderr, "Argument is a descriptor for a file, not a socket.\n");
			break;
		case EFAULT:
			fprintf(stderr, "If domain is AF_UNIX: my_addr points outside the user's accessible\n");
			fprintf(stderr, "address space.\n");
			break;
		case ELOOP:
			fprintf(stderr, "If domain is AF_UNIX: Too many symbolic links were encountered in\n");
			fprintf(stderr, "resolving my_addr.\n");
			break;
		case ENAMETOOLONG:
			fprintf(stderr, "If domain is AF_UNIX: `struct sockaddr' is too long.\n");
			break;
		case ENOENT:
			fprintf(stderr, "If domain is AF_UNIX: The file does not exist.\n");
			break;
		case ENOMEM:
			fprintf(stderr, "If domain is AF_UNIX: Insufficient kernel memory was available.\n");
			break;
		case ENOTDIR:
			fprintf(stderr, "If domain is AF_UNIX: A component of the path prefix is not a\n");
			fprintf(stderr, "directory.\n");
			break;
		case EROFS:
			fprintf(stderr, "If domain is AF_UNIX: The socket inode would reside on a\n");
			fprintf(stderr, "read-only file system.\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_open(int err)
{
	fprintf(stderr, "error: open(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_write(int err)
{
	fprintf(stderr, "error: write(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_getsockname(int err)
{
	fprintf(stderr, "error: getsockname(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_getaddrinfo(int err)
{
	fprintf(stderr, "error: getaddrinfo(3) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_fstat(int err)
{
	fprintf(stderr, "error: fstat(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_mmap(int err)
{
	fprintf(stderr, "error: mmap(2) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_fopen(int err)
{
	fprintf(stderr, "error: mmap(3) syscall failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_parse(void)
{
	fprintf(stderr, "error: Internal parse() function failed\n");
	fflush(stderr);
}

void err_list_create(int err)
{
	fprintf(stderr, "error: list_create function call failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_dsh_cmd_send()
{
	fprintf(stderr, "error: dsh_cmd_send function call failed\n");
}

void err_dsh_send(int err)
{
	fprintf(stderr, "error: dsh_send() function call failed\n");
	switch(err) {
#ifndef __OpenBSD__
		case ECANCELED:
			fprintf(stderr, "       Send operation was cancelled.\n");
			break;
#endif
		case ETIMEDOUT:
			fprintf(stderr, "       Send operation timed out waiting for reply.\n");
			break;
	}
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

void err_cmd_create(int err)
{
	fprintf(stderr, "error: cmd_create() function call failed\n");
	perrno(err);
	pstrerror(err);
	fflush(stderr);
}

#endif
