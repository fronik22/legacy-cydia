#include "client.h"

#include "control.h"

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/un.h>
#include <unistd.h>

int a6_client_connect(const char *path) {
    struct sockaddr_un addr;
    struct timeval tv;
    int fd;

    if (!path) path = A6_CONTROL_DEFAULT_PATH;
    if (strlen(path) >= sizeof addr.sun_path) {
        errno = ENAMETOOLONG;
        return -1;
    }
    fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;

    memset(&addr, 0, sizeof addr);
    addr.sun_family = AF_UNIX;
    snprintf(addr.sun_path, sizeof addr.sun_path, "%s", path);

    int no_sigpipe = 1;
    (void)setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &no_sigpipe, sizeof no_sigpipe);
    tv.tv_sec = 5;
    tv.tv_usec = 0;
    (void)setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    (void)setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);

    if (connect(fd, (struct sockaddr *)&addr, sizeof addr) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

int a6_client_command(const char *path, const char *cmd, char *out, size_t cap) {
    char line[128];
    size_t off = 0;
    int fd, n;

    if (!cmd || !out || cap < 2) return -1;
    out[0] = 0;
    fd = a6_client_connect(path);
    if (fd < 0) return -1;

    n = snprintf(line, sizeof line, "%s\n", cmd);
    if (n < 0 || (size_t)n >= sizeof line) {
        close(fd);
        errno = EMSGSIZE;
        return -1;
    }
    if (write(fd, line, (size_t)n) != n) {
        close(fd);
        return -1;
    }
    for (;;) {
        ssize_t got = read(fd, out + off, cap - 1 - off);
        if (got > 0) {
            off += (size_t)got;
            if (off >= cap - 1) break;
            continue;
        }
        if (got < 0 && errno == EINTR) continue;
        if (got < 0) {
            int error = errno;
            close(fd);
            out[0] = 0;
            errno = error;
            return -1;
        }
        break;
    }
    close(fd);
    out[off] = 0;
    if (!off) { errno = ECONNRESET; return -1; }
    return 0;
}

int a6_client_reply_is_error(const char *reply) {
    return reply && !strncmp(reply, "ERR", 3);
}
