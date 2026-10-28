#include "../src/client.h"
#include <assert.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <unistd.h>

static void reply_case(const char *reply) {
    char path[96], output[32];
    snprintf(path, sizeof path, "/tmp/a6-reply-%d.sock", getpid());
    struct sockaddr_un address = {0}; address.sun_family = AF_UNIX; strcpy(address.sun_path, path);
    int server = socket(AF_UNIX, SOCK_STREAM, 0);
    assert(server >= 0 && !bind(server, (void *)&address, sizeof address) && !listen(server, 1));
    pid_t child = fork(); assert(child >= 0);
    if (!child) {
        int peer = accept(server, NULL, NULL); char command[64];
        assert(peer >= 0 && read(peer, command, sizeof command) > 0);
        if (reply) assert(write(peer, reply, strlen(reply)) == (ssize_t)strlen(reply));
        close(peer); close(server); _exit(0);
    }
    int result = a6_client_command(path, "start", output, sizeof output);
    if (reply) assert(result == 0 && !strcmp(output, reply));
    else assert(result == -1 && !output[0]);
    int status; assert(waitpid(child, &status, 0) == child && status == 0);
    close(server); unlink(path);
}
static void oversized_command(void) {
    char path[96], command[200], output[32];
    snprintf(path, sizeof path, "/tmp/a6-oversize-%d.sock", getpid());
    struct sockaddr_un address = {0}; address.sun_family = AF_UNIX; strcpy(address.sun_path, path);
    int server = socket(AF_UNIX, SOCK_STREAM, 0);
    assert(server >= 0 && !bind(server, (void *)&address, sizeof address) && !listen(server, 1));
    memset(command, 'x', sizeof command - 1); command[sizeof command - 1] = 0;
    assert(a6_client_command(path, command, output, sizeof output) == -1 && errno == EMSGSIZE);
    close(server); unlink(path);
}
int main(void) {
    reply_case(NULL); reply_case("OK\n"); oversized_command();
    char path[96];
    snprintf(path, sizeof path, "/tmp/a6-client-%d.sock", getpid());
    struct sockaddr_un address = {0};
    address.sun_family = AF_UNIX;
    strcpy(address.sun_path, path);
    int server = socket(AF_UNIX, SOCK_STREAM, 0);
    assert(server >= 0);
    assert(bind(server, (struct sockaddr *)&address, sizeof address) == 0);
    assert(listen(server, 1) == 0);
    pid_t child = fork();
    assert(child >= 0);
    if (child == 0) {
        int peer = accept(server, NULL, NULL);
        assert(peer >= 0);
        close(peer); close(server); _exit(0);
    }
    int client = a6_client_connect(path);
    assert(client >= 0);
    int result;
    assert(waitpid(child, &result, 0) == child && result == 0);
    signal(SIGPIPE, SIG_DFL);
    assert(write(client, "status\n", 7) == -1 && errno == EPIPE);
    close(client); close(server); unlink(path);
    puts("Daemon disconnect cannot deliver SIGPIPE to the app or SpringBoard");
    return 0;
}
