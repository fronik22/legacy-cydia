#ifndef AMNEZIA6_CONTROL_H
#define AMNEZIA6_CONTROL_H

#include <stddef.h>

#define A6_CONTROL_PATH "/var/tmp/amnezia6d.sock"
#define A6_CONFIG_PATH "/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf"
#define A6_LOG_PATH "/var/log/amnezia6d.log"
#define A6_VERSION "1.3.4"

int a6_control_open(const char *path);
void a6_control_close(int fd, const char *path);
int a6_control_accept(int listen_fd);
int a6_control_read(int fd, char *buf, size_t cap);
int a6_control_write(int fd, const void *buf, size_t len);
int a6_control_reply(int fd, const char *fmt, ...);

/* Read at most `want` trailing bytes of a file into a malloc'd buffer. */
char *a6_read_file_tail(const char *path, size_t want, size_t *len_out);
int a6_truncate_file(const char *path);

#endif
