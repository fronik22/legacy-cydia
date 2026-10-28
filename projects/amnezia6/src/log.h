#ifndef AMNEZIA6_LOG_H
#define AMNEZIA6_LOG_H

#include <stddef.h>

void a6_log_open(const char *path);
void a6_log_close(void);
void a6_log(const char *fmt, ...);

#endif
