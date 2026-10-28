#ifndef AMNEZIA6_CLIENT_H
#define AMNEZIA6_CLIENT_H

#include <stddef.h>

/*
 * Client side of the daemon control protocol.
 *
 * The protocol is line oriented: one command word followed by "\n", then the
 * daemon writes its reply and closes the connection. Replies beginning with
 * "ERR" indicate failure.
 */

#define A6_CONTROL_DEFAULT_PATH "/var/tmp/amnezia6d.sock"

/* Connect to the control socket. Returns a file descriptor or -1. */
int a6_client_connect(const char *path);

/* Send `cmd` and read the full reply. Returns 0 on success, -1 on I/O error. */
int a6_client_command(const char *path, const char *cmd, char *out, size_t cap);

/* 1 when the reply is an "ERR ..." reply. */
int a6_client_reply_is_error(const char *reply);

#endif
