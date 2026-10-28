#include "config.h"
#include "control.h"
#include "log.h"
#include "protocol.h"
#include "tunnel.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

static volatile sig_atomic_t g_stop;

static void on_signal(int sig) {
    (void)sig;
    g_stop = 1;
}

static void status_text(const a6_tunnel_t *t, char *out, size_t cap) {
    uint64_t uptime = 0;
    char endpoint[96];
    const char *ifname = t->ifname[0] ? t->ifname : "-";
    const char *address = t->cfg.address[0] ? t->cfg.address : "-";
    if (t->state == A6_STATE_CONNECTED && t->connected_ms)
        uptime = (a6_now_ms() - t->connected_ms) / 1000;
    if (t->endpoint_ip[0])
        snprintf(endpoint, sizeof endpoint, "%s:%u", t->endpoint_ip,
                 t->cfg.endpoint_port);
    else
        snprintf(endpoint, sizeof endpoint, "-");
    snprintf(out, cap,
             "state=%s\n"
             "uptime=%llu\n"
             "tx=%llu\n"
             "rx=%llu\n"
             "tx_packets=%llu\n"
             "rx_packets=%llu\n"
             "endpoint=%s\n"
             "ifname=%s\n"
             "address=%s\n"
             "mtu=%u\n"
             "source=%s\n"
             "retry_in=%llu\n"
             "handshake_attempts=%u\n"
             "error=%s\n",
             a6_state_name(t->state),
             (unsigned long long)uptime,
             (unsigned long long)t->tx_bytes,
             (unsigned long long)t->rx_bytes,
             (unsigned long long)t->tx_packets,
             (unsigned long long)t->rx_packets,
             endpoint, ifname, address, (unsigned)t->cfg.mtu, t->source_ip,
             (unsigned long long)(t->retry_pending && t->retry_at_ms > a6_now_ms()
                 ? (t->retry_at_ms - a6_now_ms() + 999) / 1000 : 0),
             (unsigned)t->handshake_attempts, t->error);
}

static void handle_control(int listen_fd, a6_tunnel_t *tunnel,
                           const char *config_path, const char *log_path) {
    char cmd[256];
    int fd = a6_control_accept(listen_fd);
    if (fd < 0) return;
    if (a6_control_read(fd, cmd, sizeof cmd) != 0) {
        close(fd);
        return;
    }

    if (!strcmp(cmd, "start") &&
        (tunnel->state == A6_STATE_CONNECTED || tunnel->state == A6_STATE_CONNECTING)) {
        a6_control_reply(fd, "OK\n");
    } else if (!strcmp(cmd, "start")) {
        a6_config_t cfg;
        char err[256];
        char start_err[192];
        memset(&cfg, 0, sizeof cfg);
        if (tunnel->state != A6_STATE_IDLE) a6_tunnel_stop(tunnel);
        if (a6_config_load(config_path, &cfg, err, sizeof err) != 0) {
            a6_log("start rejected: %s", err);
            a6_control_reply(fd, "ERR %s\n", err);
        } else {
            if (a6_tunnel_start(tunnel, &cfg, start_err, sizeof start_err) != 0) {
                a6_log("start failed: %s", start_err);
                a6_control_reply(fd, "ERR %s\n", start_err);
            } else {
                a6_log("start accepted");
                a6_control_reply(fd, "OK\n");
            }
            a6_config_wipe(&cfg);
        }
    } else if (!strcmp(cmd, "stop")) {
        a6_tunnel_stop(tunnel);
        a6_log("stop accepted");
        a6_control_reply(fd, "OK\n");
    } else if (!strcmp(cmd, "status")) {
        char status[1024];
        status_text(tunnel, status, sizeof status);
        a6_control_reply(fd, "%s", status);
    } else if (!strcmp(cmd, "ping")) {
        a6_control_reply(fd, "PONG\n");
    } else if (!strcmp(cmd, "version")) {
        a6_control_reply(fd, "OK amnezia6d/%s protocol/1\n", A6_VERSION);
    } else if (!strcmp(cmd, "log")) {
        size_t len = 0;
        char *tail = a6_read_file_tail(log_path, 8192, &len);
        if (tail) {
            a6_control_write(fd, tail, len);
            free(tail);
        }
    } else if (!strcmp(cmd, "logclear")) {
        if (a6_truncate_file(log_path) != 0)
            a6_control_reply(fd, "ERR cannot truncate %s\n", log_path);
        else {
            a6_log("log cleared from the control socket");
            a6_control_reply(fd, "OK\n");
        }
    } else if (!strcmp(cmd, "config")) {
        struct stat st;
        int present = stat(config_path, &st) == 0;
        a6_control_reply(fd, "OK path=%s present=%d size=%lu\n", config_path, present,
                         present ? (unsigned long)st.st_size : 0UL);
    } else {
        a6_control_reply(fd, "ERR unknown command\n");
    }
    close(fd);
}

int main(int argc, char **argv) {
    const char *config_path = A6_CONFIG_PATH;
    const char *socket_path = A6_CONTROL_PATH;
    const char *log_path = A6_LOG_PATH;
    int lock_fd = -1;
    int ctl_fd = -1;
    a6_tunnel_t tunnel;
    int i;
    int detach = 0;

    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--daemonize")) detach = 1;
        else if (!strcmp(argv[i], "--config") && i + 1 < argc) config_path = argv[++i];
        else if (!strcmp(argv[i], "--socket") && i + 1 < argc) socket_path = argv[++i];
        else if (!strcmp(argv[i], "--log") && i + 1 < argc) log_path = argv[++i];
    }

    if (detach) {
        pid_t child = fork();
        if (child < 0) return 1;
        if (child > 0) return 0;
        if (setsid() < 0) return 1;
        int null_fd = open("/dev/null", O_RDWR);
        if (null_fd < 0) return 1;
        for (i = 0; i < 3; ++i) {
            if (dup2(null_fd, i) < 0) return 1;
        }
        if (null_fd > 2) close(null_fd);
    }

    a6_log_open(log_path);
    a6_log("daemon starting (pid %d)", (int)getpid());

    lock_fd = open("/var/run/amnezia6d.lock", O_CREAT | O_RDWR, 0600);
    if (lock_fd >= 0 && flock(lock_fd, LOCK_EX | LOCK_NB) != 0) {
        a6_log("another daemon instance is already running");
        a6_log_close();
        return 1;
    }
    if (lock_fd >= 0) {
        char pid[32];
        int n = snprintf(pid, sizeof pid, "%d\n", (int)getpid());
        ftruncate(lock_fd, 0);
        (void)write(lock_fd, pid, (size_t)n);
    }

    signal(SIGPIPE, SIG_IGN);
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);

    ctl_fd = a6_control_open(socket_path);
    if (ctl_fd < 0) {
        a6_log("control socket %s could not be created", socket_path);
        if (lock_fd >= 0) close(lock_fd);
        a6_log_close();
        return 1;
    }
    a6_log("control socket %s", socket_path);

    a6_tunnel_init(&tunnel);

    while (!g_stop) {
        struct pollfd pfd[3];
        nfds_t count = 0;
        int timeout = a6_tunnel_timeout_ms(&tunnel);
        int udp_slot = -1, utun_slot = -1;

        pfd[count].fd = ctl_fd;
        pfd[count].events = POLLIN;
        pfd[count].revents = 0;
        count++;

        if (a6_tunnel_udp_fd(&tunnel) >= 0) {
            udp_slot = (int)count;
            pfd[count].fd = a6_tunnel_udp_fd(&tunnel);
            pfd[count].events = POLLIN;
            pfd[count].revents = 0;
            count++;
        }
        if (a6_tunnel_utun_fd(&tunnel) >= 0) {
            utun_slot = (int)count;
            pfd[count].fd = a6_tunnel_utun_fd(&tunnel);
            pfd[count].events = POLLIN;
            pfd[count].revents = 0;
            count++;
        }

        if (poll(pfd, count, timeout) < 0) {
            if (errno == EINTR) continue;
            a6_log("poll failed: %s", strerror(errno));
            break;
        }

        if (pfd[0].revents & POLLIN) {
            handle_control(ctl_fd, &tunnel, config_path, log_path);
            continue; /* start/stop can replace descriptors from this poll. */
        }
        if (udp_slot >= 0 && (pfd[udp_slot].revents & POLLIN))
            a6_tunnel_handle_udp(&tunnel);
        if (utun_slot >= 0 && (pfd[utun_slot].revents & POLLIN))
            a6_tunnel_handle_utun(&tunnel);
        a6_tunnel_timers(&tunnel);
    }

    a6_log("daemon shutting down");
    a6_tunnel_stop(&tunnel);
    a6_control_close(ctl_fd, socket_path);
    if (lock_fd >= 0) close(lock_fd);
    a6_log_close();
    return 0;
}
