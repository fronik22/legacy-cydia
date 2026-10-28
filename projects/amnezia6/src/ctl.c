/*
 * amnezia6ctl — command line control for the Amnezia6 daemon.
 *
 *   amnezia6ctl status|start|stop|ping|config|log|version
 *
 * Set AMNEZIA6_SOCK to talk to a daemon on another socket path.
 */

#include "client.h"
#include "control.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int usage(void) {
    printf("usage: amnezia6ctl <status|start|stop|ping|config|version>\n"
           "       amnezia6ctl --socket <path> <command>\n"
           "environment: AMNEZIA6_SOCK overrides the socket path\n");
    return 0;
}

int main(int argc, char **argv) {
    const char *path = getenv("AMNEZIA6_SOCK");
    const char *cmd = NULL;
    char reply[8192];
    int i;

    if (!path) path = A6_CONTROL_DEFAULT_PATH;
    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--socket") && i + 1 < argc) {
            path = argv[++i];
        } else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help") ||
                   !strcmp(argv[i], "help")) {
            return usage();
        } else if (!cmd) {
            cmd = argv[i];
        } else {
            fprintf(stderr, "amnezia6ctl: unexpected argument '%s'\n", argv[i]);
            return 1;
        }
    }
    if (!cmd) cmd = "status";

    if (a6_client_command(path, cmd, reply, sizeof reply) != 0) {
        fprintf(stderr, "amnezia6ctl: cannot talk to %s: %s\n", path,
                strerror(errno));
        return 1;
    }
    fputs(reply, stdout);
    if (reply[0] && reply[strlen(reply) - 1] != '\n') fputc('\n', stdout);
    return a6_client_reply_is_error(reply) ? 2 : 0;
}
