#include "control.h"

#include <errno.h>
#include <grp.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

int a6_control_open(const char *path) {
    struct sockaddr_un addr;
    int fd;
    struct group *mobile;
    mode_t mask;
    int result, saved_errno;

    if (!path || strlen(path) >= sizeof addr.sun_path) return -1;
    mobile = getgrnam("mobile");
    if (!mobile) { errno = ENOENT; return -1; }
    unlink(path);
    fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof addr.sun_path, "%s", path);
    mask = umask(0177);
    result = bind(fd, (struct sockaddr *)&addr, sizeof addr);
    saved_errno = errno;
    umask(mask);
    if (result != 0) { close(fd); errno = saved_errno; return -1; }
    if (chown(path, 0, mobile->gr_gid) != 0 || chmod(path, 0660) != 0 || listen(fd, 8) != 0) {
        saved_errno = errno;
        close(fd);
        unlink(path);
        errno = saved_errno;
        return -1;
    }
    return fd;
}

void a6_control_close(int fd, const char *path) {
    if (fd >= 0) close(fd);
    if (path) unlink(path);
}

int a6_control_accept(int listen_fd) {
    int fd = accept(listen_fd, NULL, NULL);
    struct timeval tv;
    if (fd < 0) return -1;
    tv.tv_sec = 3;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
    return fd;
}

int a6_control_read(int fd, char *buf, size_t cap) {
    ssize_t n;
    size_t end;
    if (!buf || cap < 2) return -1;
    n = read(fd, buf, cap - 1);
    if (n <= 0) return -1;
    buf[n] = 0;
    end = strlen(buf);
    while (end && (buf[end - 1] == '\n' || buf[end - 1] == '\r' ||
                   buf[end - 1] == ' ' || buf[end - 1] == '\t'))
        buf[--end] = 0;
    return 0;
}

int a6_control_write(int fd, const void *buf, size_t len) {
    const char *p = buf;
    size_t off = 0;
    while (off < len) {
        ssize_t w = write(fd, p + off, len - off);
        if (w > 0) { off += (size_t)w; continue; }
        if (w < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

int a6_control_reply(int fd, const char *fmt, ...) {
    char buf[2048];
    va_list ap;
    int n;

    va_start(ap, fmt);
    n = vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    if (n < 0) return -1;
    if ((size_t)n >= sizeof buf) n = (int)sizeof buf - 1;
    return a6_control_write(fd, buf, (size_t)n);
}

char *a6_read_file_tail(const char *path, size_t want, size_t *len_out) {
    FILE *f;
    long size;
    char *buf;

    if (len_out) *len_out = 0;
    if (!path || want == 0) return NULL;
    f = fopen(path, "r");
    if (!f) return NULL;
    if (fseek(f, 0, SEEK_END) != 0 || (size = ftell(f)) < 0) {
        fclose(f);
        return NULL;
    }
    if ((size_t)size > want) {
        if (fseek(f, size - (long)want, SEEK_SET) != 0) {
            fclose(f);
            return NULL;
        }
        size = (long)want;
    } else if (fseek(f, 0, SEEK_SET) != 0) {
        fclose(f);
        return NULL;
    }
    buf = malloc((size_t)size + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    size = (long)fread(buf, 1, (size_t)size, f);
    fclose(f);
    if (size < 0) {
        free(buf);
        return NULL;
    }
    buf[size] = 0;
    if (len_out) *len_out = (size_t)size;
    return buf;
}

int a6_truncate_file(const char *path) {
    FILE *f = fopen(path, "w");
    if (!f) return -1;
    fclose(f);
    return 0;
}
