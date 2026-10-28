#include "log.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static FILE *g_log;

void a6_log_open(const char *path) {
    if (g_log) return;
    g_log = path ? fopen(path, "a") : NULL;
    if (g_log) setvbuf(g_log, NULL, _IOLBF, 0);
}

void a6_log_close(void) {
    if (g_log) {
        fclose(g_log);
        g_log = NULL;
    }
}

void a6_log(const char *fmt, ...) {
    char when[32];
    time_t now = time(NULL);
    struct tm tmv;
    va_list ap;
    FILE *out = g_log ? g_log : stderr;

    localtime_r(&now, &tmv);
    strftime(when, sizeof when, "%Y-%m-%d %H:%M:%S", &tmv);
    fprintf(out, "%s amnezia6d: ", when);
    va_start(ap, fmt);
    vfprintf(out, fmt, ap);
    va_end(ap);
    fputc('\n', out);
    fflush(out);
}
