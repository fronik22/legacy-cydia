#include "tunnel.h"

#include "crypto.h"
#include "log.h"
#include "route.h"
#include "utun.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

const char *a6_state_name(a6_state_t state) {
    switch (state) {
    case A6_STATE_IDLE: return "idle";
    case A6_STATE_CONNECTING: return "connecting";
    case A6_STATE_CONNECTED: return "connected";
    case A6_STATE_ERROR: return "error";
    }
    return "unknown";
}

static void set_error(a6_tunnel_t *t, const char *text) {
    snprintf(t->error, sizeof t->error, "%s", text);
}

static int write_all(int fd, const uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n > 0) { off += (size_t)n; continue; }
        if (n < 0 && errno == EINTR) continue;
        return -1;
    }
    return 0;
}

static int resolve_endpoint(a6_tunnel_t *t) {
    char port[16];
    struct addrinfo hints, *res = NULL;
    snprintf(port, sizeof port, "%u", t->cfg.endpoint_port);
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    if (getaddrinfo(t->cfg.endpoint_host, port, &hints, &res) != 0 || !res) {
        set_error(t, "endpoint name resolution failed");
        return -1;
    }
    int ok = inet_ntop(AF_INET, &((struct sockaddr_in *)res->ai_addr)->sin_addr,
                       t->endpoint_ip, sizeof t->endpoint_ip) != NULL;
    freeaddrinfo(res);
    return ok ? 0 : -1;
}

static int open_udp(a6_tunnel_t *t) {
    struct sockaddr_in peer;
    memset(&peer, 0, sizeof peer);
    peer.sin_len = sizeof peer;
    peer.sin_family = AF_INET;
    peer.sin_port = htons(t->cfg.endpoint_port);
    if (inet_pton(AF_INET, t->endpoint_ip, &peer.sin_addr) != 1) return -1;
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd >= 0) {
        int rcvbuf = 1 << 20;
        setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof rcvbuf);
        if (connect(fd, (struct sockaddr *)&peer, sizeof peer) == 0) {
            struct sockaddr_in source;
            socklen_t len = sizeof source;
            if (getsockname(fd, (struct sockaddr *)&source, &len) == 0 &&
                inet_ntop(AF_INET, &source.sin_addr, t->source_ip, sizeof t->source_ip)) return fd;
        }
        close(fd);
    }
    snprintf(t->error, sizeof t->error, "Endpoint UDP socket failed: %s", strerror(errno));
    return -1;
}

static int send_packet(a6_tunnel_t *t, const uint8_t *packet, size_t len) {
    ssize_t n = send(t->udp_fd, packet, len, 0);
    if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
        return 0; /* drop, the tunnel must not block */
    if (n != (ssize_t)len) {
        int error = n < 0 ? errno : EIO;
        snprintf(t->error, sizeof t->error, "UDP send failed: %s (errno %d)", strerror(error), error);
        return -1;
    }
    return 0;
}

/* libc's cached CSPRNG avoids a /dev/urandom read for every packet timer reset. */
static uint32_t timer_seconds(a6_range range) {
    if (range.max <= range.min) return range.min;
    return range.min + (uint32_t)(((uint64_t)arc4random() * ((uint64_t)range.max - range.min + 1)) >> 32);
}
static uint64_t timer_deadline(uint64_t now, uint32_t seconds) {
    uint64_t delay = (uint64_t)seconds * 1000;
    return delay > UINT64_MAX - now ? UINT64_MAX : now + delay;
}
static void authenticated_traversal(a6_tunnel_t *t, uint64_t now, int sent) {
    if (sent) {t->keepalive_at_ms = 0;t->keepalive_pending_again = 0;}
    else t->new_handshake_at_ms = 0;
    t->persistent_keepalive_at_ms = t->cfg.persistent_keepalive.max ?
        timer_deadline(now, timer_seconds(t->cfg.persistent_keepalive)) : 0;
}
static void schedule_reply_keepalive(a6_tunnel_t *t, uint64_t now) {
    uint32_t seconds = t->cfg.keepalive_timeout.max ? timer_seconds(t->cfg.keepalive_timeout) : 10;
    t->keepalive_at_ms = timer_deadline(now, seconds);
}

static int send_obfuscation(a6_tunnel_t *t) {
    uint8_t buf[A6_MAX_DATAGRAM];
    int i;
    for (i = 0; i < A6_SIG_COUNT; ++i) {
        size_t len = 0;
        if (!t->cfg.signature_present[i]) continue;
        if (a6_signature_expand(t->cfg.signature[i], buf, sizeof buf, &len) != 0) {
            a6_log("I%d signature expansion failed", i + 1);
            continue;
        }
        if (len && send_packet(t, buf, len) != 0) return -1;
    }
    for (i = 0; i < (int)t->cfg.jc; ++i) {
        size_t len = t->cfg.jmax ? a6_random_range(t->cfg.jmin, t->cfg.jmax)
                                 : t->cfg.jmin;
        if (len > sizeof buf) len = sizeof buf;
        if (!len) continue;
        a6_random(buf, len);
        if (send_packet(t, buf, len) != 0) return -1;
    }
    return 0;
}

static void schedule_handshake(a6_tunnel_t *t) {
    uint32_t seconds = timer_seconds(t->cfg.rekey_timeout);
    if (seconds < 1) seconds = 1;
    uint64_t now = a6_now_ms();
    if (t->next_handshake_ms < now + 200) {
        t->next_handshake_ms = now + (uint64_t)seconds * 1000;
    }
}

static int send_handshake(a6_tunnel_t *t) {
    uint8_t packet[A6_MAX_DATAGRAM];
    size_t len = 0;
    uint64_t now = a6_now_ms();

    if (!t->handshake_attempts) {
    t->max_handshake_attempts = timer_seconds(t->cfg.max_handshake_attempts);
    if (!t->max_handshake_attempts) t->max_handshake_attempts = 18;
    }
    /* Failed sends also consume an attempt and wait for the retry deadline. */
    t->handshake_attempts++;
    schedule_handshake(t);
    if (send_obfuscation(t) != 0) {
        a6_log("sending obfuscation packets failed: %s", t->error);
        return -1;
    }
    if (a6_build_initiation(&t->session, packet, sizeof packet, &len) != 0) {
        a6_log("handshake initiation failed: %s", t->session.last_error);
        set_error(t, t->session.last_error);
        return -1;
    }
    if (send_packet(t, packet, len) != 0) {
        a6_log("handshake initiation send failed: %s", t->error);
        return -1;
    }
    now = a6_now_ms();
    t->last_initiation_ms = now;
    authenticated_traversal(t, now, 1);
    if (t->handshake_attempts == 1) {
        a6_log("handshake sent to %s:%u (attempt %u)",
               t->endpoint_ip, t->cfg.endpoint_port, t->handshake_attempts);
    }
    return 0;
}

static void update_rekey_deadlines(a6_tunnel_t *t, uint64_t now) {
    t->rekey_after_seconds = timer_seconds(t->cfg.rekey_after);
    t->reject_after_seconds = timer_seconds(t->cfg.reject_after);
    if (!t->rekey_after_seconds) t->rekey_after_seconds = 120;
    if (!t->reject_after_seconds) t->reject_after_seconds = 180;
    t->rekey_at_ms = now + (uint64_t)t->rekey_after_seconds * 1000;
    t->reject_at_ms = now + (uint64_t)t->reject_after_seconds * 1000;
}

static void cleanup(a6_tunnel_t *t) {
    if (t->dns_up) {
        a6_dns_down(&t->dns);
        t->dns_up = 0;
    }
    if (t->routes_up) {
        a6_route_down(t->ifname, t->endpoint_ip, t->gateway, t->host_route_added);
        t->routes_up = 0;
        t->host_route_added = 0;
    }
    if (t->utun_fd >= 0) {
        close(t->utun_fd);
        t->utun_fd = -1;
    }
    if (t->udp_fd >= 0) {
        close(t->udp_fd);
        t->udp_fd = -1;
    }
    t->iface_up = 0;
}

/* Keep the user's ON intent; expired keys and dead interfaces are never reused. */
static void reconnect_later(a6_tunnel_t *t, const char *reason) {
    if (reason != t->error) set_error(t, reason);
    if (!t->retry_delay_seconds) t->retry_delay_seconds = 1;
    uint64_t now = a6_now_ms();
    a6_log("%s; reconnecting in %us (source %s, gateway %s, last RX %llums ago, attempts %u)", t->error,
           t->retry_delay_seconds, t->source_ip, t->gateway,
           (unsigned long long)(now - t->last_rx_ms), (unsigned)t->handshake_attempts);
    cleanup(t);
    a6_session_wipe(&t->session);
    t->retry_pending = 1;
    t->retry_at_ms = now + (uint64_t)t->retry_delay_seconds * 1000;
    t->state = A6_STATE_CONNECTING;
}

void a6_tunnel_init(a6_tunnel_t *t) {
    memset(t, 0, sizeof *t);
    t->state = A6_STATE_IDLE;
    t->udp_fd = -1;
    t->utun_fd = -1;
}

int a6_tunnel_start(a6_tunnel_t *t, const a6_config_t *cfg,
                    char *err, size_t err_cap) {
    uint64_t now;

    if (err && err_cap) err[0] = 0;
    if (!t || !cfg) return -1;
    if (t->state != A6_STATE_IDLE) a6_tunnel_stop(t);

    t->cfg = *cfg;
    t->state = A6_STATE_CONNECTING;
    t->retry_pending = 0;
    if (!t->retry_delay_seconds) t->retry_delay_seconds = 1;
    t->error[0] = 0;
    t->udp_fd = -1;
    t->utun_fd = -1;
    t->routes_up = 0;
    t->dns_up = 0;
    t->handshake_attempts = 0;
    t->persistent_keepalive_at_ms = t->keepalive_at_ms = t->new_handshake_at_ms = 0;t->keepalive_pending_again = 0;
    t->tx_bytes = t->rx_bytes = 0;
    t->tx_packets = t->rx_packets = 0;
    a6_session_init(&t->session, &t->cfg);

    now = a6_now_ms();
    t->started_ms = now;
    t->last_rx_ms = now;
    t->last_tx_ms = now;
    t->next_handshake_ms = now;
    t->source_check_ms = now + 3000;
    t->rekey_at_ms = 0;
    t->reject_at_ms = now + 200000;

    if (resolve_endpoint(t) != 0) goto fail;

    t->utun_fd = a6_utun_open(t->ifname, sizeof t->ifname);
    if (t->utun_fd < 0) {
        set_error(t, "utun interface could not be created");
        goto fail;
    }

    if (a6_route_gateway(t->endpoint_ip, t->gateway, sizeof t->gateway) != 0) {
        set_error(t, "physical gateway lookup failed");
        goto fail;
    }

    if (a6_route_up(t->ifname, t->endpoint_ip, t->gateway,
                    t->cfg.address, t->cfg.mtu, &t->host_route_added) != 0) {
        set_error(t, "route setup failed");
        goto fail;
    }
    t->routes_up = 1;
    t->iface_up = 1;

    /* connect() chooses the source address: repair the endpoint route first. */
    t->udp_fd = open_udp(t);
    if (t->udp_fd < 0) goto fail;

    if (t->cfg.dns[0]) {
        if (a6_dns_up(&t->dns, t->ifname, t->cfg.address, t->cfg.dns) == 0) {
            t->dns_up = 1;
        } else {
            set_error(t, "requested tunnel DNS could not be installed");
            goto fail;
        }
    }

    a6_log("starting %s, %s -> %s:%u via %s (source %s)",
           t->ifname, t->cfg.address, t->endpoint_ip, t->cfg.endpoint_port,
           t->gateway, t->source_ip);

    if (send_handshake(t) != 0) goto fail;
    return 0;

fail:
    if (err && err_cap) snprintf(err, err_cap, "%s", t->error);
    a6_log("start failed: %s", t->error);
    reconnect_later(t, t->error);
    return 0; /* ON accepted; transient setup failure will be retried. */
}

void a6_tunnel_stop(a6_tunnel_t *t) {
    if (!t) return;
    if (t->state != A6_STATE_IDLE)
        a6_log("stopping tunnel (%s)", a6_state_name(t->state));
    cleanup(t);
    a6_session_wipe(&t->session);
    a6_config_wipe(&t->cfg);
    t->state = A6_STATE_IDLE;
    t->retry_pending = 0;
    t->retry_at_ms = 0;
    t->retry_delay_seconds = 0;
    t->source_ip[0] = 0;
    t->error[0] = 0;
    t->ifname[0] = 0;
    t->endpoint_ip[0] = 0;
    t->gateway[0] = 0;
    t->tx_bytes = t->rx_bytes = 0;
    t->tx_packets = t->rx_packets = 0;
}

int a6_tunnel_udp_fd(const a6_tunnel_t *t) {
    return t ? t->udp_fd : -1;
}

int a6_tunnel_utun_fd(const a6_tunnel_t *t) {
    return t ? t->utun_fd : -1;
}

void a6_tunnel_handle_udp(a6_tunnel_t *t) {
    uint8_t packet[A6_MAX_DATAGRAM];
    uint8_t inner[A6_MAX_DATAGRAM + 4];
    ssize_t got;
    int type;

    if (!t || t->udp_fd < 0) return;
    got = recv(t->udp_fd, packet, sizeof packet, 0);
    if (got <= 0) return;
    type = a6_packet_type(&t->cfg, packet, (size_t)got);

    if (type == 3) {
        /* A valid challenge supplies MAC2 for the next already-scheduled retry. */
        if (a6_consume_cookie(&t->session, packet, (size_t)got) == 0)
            a6_log("cookie challenge accepted; retry will use MAC2");
        return;
    }

    if (type == 2) {
        if (a6_consume_response(&t->session, packet, (size_t)got) == 0) {
            uint64_t now = a6_now_ms();
            /* A routine key renewal belongs to the existing connection. */
            if (t->state != A6_STATE_CONNECTED) t->connected_ms = now;
            t->state = A6_STATE_CONNECTED;
            t->retry_delay_seconds = 1;
            t->retry_pending = 0;
            t->last_rx_ms = now;
            t->last_tx_ms = now;
            t->handshake_attempts = 0;
            t->error[0] = 0;
            update_rekey_deadlines(t, now);
            authenticated_traversal(t, now, 0);
            a6_log("connected to %s:%u via %s",
                   t->endpoint_ip, t->cfg.endpoint_port, t->ifname);
        }
        return;
    }

    if (type == 4) {
        size_t ip_len = 0;
        if (a6_open_transport(&t->session, packet, (size_t)got,
                              inner + 4, sizeof inner - 4, &ip_len) != 0)
            return;
        t->last_rx_ms = a6_now_ms();
        authenticated_traversal(t, t->last_rx_ms, 0);
        if (ip_len == 0) return; /* keepalive */
        if (!t->keepalive_at_ms) schedule_reply_keepalive(t, t->last_rx_ms);
        else t->keepalive_pending_again = 1;
        t->rx_bytes += ip_len;
        t->rx_packets++;
        {
            uint32_t family = htonl(AF_INET);
            memcpy(inner, &family, 4);
        }
        if (write_all(t->utun_fd, inner, ip_len + 4) != 0)
            a6_log("utun write failed for an inbound packet");
    }
}

void a6_tunnel_handle_utun(a6_tunnel_t *t) {
    uint8_t framed[A6_MAX_DATAGRAM + 4];
    uint8_t packet[A6_MAX_DATAGRAM];
    ssize_t got;
    size_t len = 0;
    uint32_t family;

    if (!t || t->utun_fd < 0) return;
    /*
     * Always drain the interface: while the handshake is still in flight the
     * routes are already installed, so this fd can be readable. Leaving the
     * datagram queued would make poll() return immediately in a tight loop.
     */
    got = read(t->utun_fd, framed, sizeof framed);
    if (got <= 4) return;
    memcpy(&family, framed, 4);
    if (ntohl(family) != AF_INET) return;
    if (t->state != A6_STATE_CONNECTED) return;

    if (a6_build_transport(&t->session, framed + 4, (size_t)got - 4,
                           packet, sizeof packet, &len) != 0)
        return;
    if (send_packet(t, packet, len) != 0) { reconnect_later(t, t->error); return; }
    t->last_tx_ms = a6_now_ms();
    authenticated_traversal(t, t->last_tx_ms, 1);
    if (!t->new_handshake_at_ms) {
        uint32_t silence = t->cfg.keepalive_timeout.max ? t->cfg.keepalive_timeout.max : 10;
        uint32_t retry = t->cfg.rekey_timeout.max ? timer_seconds(t->cfg.rekey_timeout) : 5;
        t->new_handshake_at_ms = timer_deadline(timer_deadline(t->last_tx_ms, silence), retry);
    }
    t->tx_bytes += (uint64_t)got - 4;
    t->tx_packets++;
}

static int send_keepalive(a6_tunnel_t *t) {
    uint8_t packet[A6_MAX_DATAGRAM];
    size_t len = 0;
    if (!t->session.established) return -1;
    if (a6_build_transport(&t->session, NULL, 0, packet, sizeof packet, &len) != 0)
        return -1;
    if (send_packet(t, packet, len) != 0) return -1;
    t->last_tx_ms = a6_now_ms();
    authenticated_traversal(t, t->last_tx_ms, 1);
    return 0;
}

void a6_tunnel_timers(a6_tunnel_t *t) {
    uint64_t now;
    if (!t || t->state == A6_STATE_IDLE || t->state == A6_STATE_ERROR) return;
    now = a6_now_ms();

    if (t->retry_pending) {
        if (now >= t->retry_at_ms) {
            a6_config_t cfg = t->cfg;
            char error[192];
            t->retry_delay_seconds *= 2;
            if (t->retry_delay_seconds > 30) t->retry_delay_seconds = 30;
            t->retry_pending = 0;
            t->state = A6_STATE_IDLE; /* cleanup already ran; preserve retry backoff. */
            a6_tunnel_start(t, &cfg, error, sizeof error);
            a6_config_wipe(&cfg);
        }
        return;
    }
    if (now >= t->source_check_ms && t->source_ip[0]) {
        t->source_check_ms = now + 3000;
        if (a6_route_source_available(t->source_ip) == 0) {
            reconnect_later(t, "physical IPv4 address changed");
            return;
        }
    }
    if (t->state == A6_STATE_CONNECTING) {
        if ((t->handshake_attempts >= t->max_handshake_attempts &&
             now >= t->next_handshake_ms) || now >= t->reject_at_ms) {
            reconnect_later(t, "handshake timed out");
            return;
        }
        if (now >= t->next_handshake_ms && send_handshake(t) != 0)
            reconnect_later(t, t->error);
        return;
    }
    if (now >= t->reject_at_ms) {
        reconnect_later(t, "rekey timed out");
        return;
    }
    if (t->new_handshake_at_ms && now >= t->new_handshake_at_ms) {
        t->new_handshake_at_ms = 0;t->rekey_at_ms = now;
        if (!t->session.pending.active) t->handshake_attempts = 0;
    }
    /* Both a failed send and an exhausted attempt round must honor their deadline. */
    if (now >= t->rekey_at_ms && now >= t->next_handshake_ms) {
        if (t->session.pending.active &&
            t->handshake_attempts >= t->max_handshake_attempts) {
            t->session.pending.active = 0;
            t->handshake_attempts = 0;
            t->next_handshake_ms = now + 30000;
            a6_log("rekey unanswered; next attempt round in 30s");
        } else {
            if (!t->session.pending.active) t->handshake_attempts = 0;
            if (send_handshake(t) != 0) { reconnect_later(t, t->error); return; }
        }
    }
    if (t->keepalive_at_ms && now >= t->keepalive_at_ms) {
        int again = t->keepalive_pending_again;
        if (send_keepalive(t) != 0) {reconnect_later(t, t->error);return;}
        if (again) schedule_reply_keepalive(t, now);
    }
    if (t->cfg.persistent_keepalive.max && now >= t->persistent_keepalive_at_ms) {
        if (send_keepalive(t) != 0) reconnect_later(t, t->error);
    }
}

int a6_tunnel_timeout_ms(const a6_tunnel_t *t) {
    if (!t || t->state == A6_STATE_IDLE) return 500;
    if (t->retry_pending) {
        uint64_t now = a6_now_ms();
        uint64_t remaining = t->retry_at_ms > now ? t->retry_at_ms - now : 0;
        return remaining > 1000 ? 1000 : (int)remaining;
    }
    return 200;
}
