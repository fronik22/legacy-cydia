#include "../src/config.h"
#include "../src/crypto.h"
#include "../src/protocol.h"

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static int open_endpoint(const a6_config_t *cfg) {
    char port[16];
    struct addrinfo hints, *res = NULL;
    int fd = -1;
    snprintf(port, sizeof port, "%u", cfg->endpoint_port);
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;
    if (getaddrinfo(cfg->endpoint_host, port, &hints, &res) != 0 || !res) {
        perror("getaddrinfo");
        return -1;
    }
    fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd >= 0 && connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    return fd;
}

static void send_obfuscation(int fd, const a6_config_t *cfg) {
    uint8_t buf[A6_MAX_DATAGRAM];
    int i;
    for (i = 0; i < 5; ++i) {
        size_t len = 0;
        if (!cfg->signature_present[i]) continue;
        if (a6_signature_expand(cfg->signature[i], buf, sizeof buf, &len) != 0) {
            printf("signature I%d failed\n", i + 1);
            continue;
        }
        printf("I%d len=%zu send=%zd\n", i + 1, len, send(fd, buf, len, 0));
    }
    for (i = 0; i < (int)cfg->jc; ++i) {
        size_t len = a6_random_range(cfg->jmin, cfg->jmax);
        a6_random(buf, len);
        send(fd, buf, len, 0);
    }
}

static unsigned short ip_checksum(const uint8_t *p, size_t n) {
    uint32_t sum = 0;
    size_t i;
    for (i = 0; i + 1 < n; i += 2) sum += ((uint16_t)p[i] << 8) | p[i + 1];
    if (i < n) sum += (uint16_t)p[i] << 8;
    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return (unsigned short)~sum;
}

static size_t build_dns_query(uint8_t *out) {
    size_t n = 12;
    out[0] = 0x12; out[1] = 0x34; out[2] = 0x01; out[3] = 0x00;
    out[4] = 0; out[5] = 1; out[6] = 0; out[7] = 0; out[8] = 0; out[9] = 0;
    out[10] = 0; out[11] = 0;
    memcpy(out + n, "\x07""example""\x03""com", 12); n += 12;
    out[n++] = 0;
    out[n++] = 0; out[n++] = 1;
    out[n++] = 0; out[n++] = 1;
    return n;
}

static size_t build_dns_packet(uint8_t *out, size_t cap) {
    uint8_t dns[128];
    size_t dnslen = build_dns_query(dns);
    size_t total = 20 + 8 + dnslen;
    uint8_t *ip = out;
    uint8_t *udp = out + 20;
    if (total > cap) return 0;
    memset(ip, 0, 20);
    ip[0] = 0x45;
    ip[2] = (uint8_t)(total >> 8); ip[3] = (uint8_t)total;
    ip[4] = 0x12; ip[5] = 0x34;
    ip[8] = 64;
    ip[9] = 17;
    inet_pton(AF_INET, "10.55.0.5", ip + 12);
    inet_pton(AF_INET, "10.55.0.1", ip + 16);
    {
        unsigned short c = ip_checksum(ip, 20);
        ip[10] = (uint8_t)(c >> 8); ip[11] = (uint8_t)c;
    }
    udp[0] = 0x9c; udp[1] = 0x40; /* 40000 */
    udp[2] = 0; udp[3] = 53;
    udp[4] = (uint8_t)((8 + dnslen) >> 8); udp[5] = (uint8_t)(8 + dnslen);
    udp[6] = 0; udp[7] = 0;
    memcpy(udp + 8, dns, dnslen);
    return total;
}

int main(int argc, char **argv) {
    const char *path = argc > 1 ? argv[1] : NULL;
    if (!path) { fprintf(stderr, "usage: test_handshake CONFIG\n"); return 1; }
    a6_config_t cfg;
    a6_session_t session;
    char err[256] = {0};
    uint8_t buf[A6_MAX_DATAGRAM];
    uint8_t inner[A6_MAX_DATAGRAM];
    int fd;
    size_t len = 0;
    int i;

    if (a6_config_load(path, &cfg, err, sizeof err) != 0) {
        printf("config error: %s\n", err);
        return 1;
    }
    printf("config ok: endpoint=%s:%u mtu=%u hp=%d s=%u,%u,%u,%u jc=%u\n",
           cfg.endpoint_host, cfg.endpoint_port, cfg.mtu, cfg.has_header_protection,
           cfg.s[0], cfg.s[1], cfg.s[2], cfg.s[3], cfg.jc);

    fd = open_endpoint(&cfg);
    if (fd < 0) { perror("udp"); return 1; }

    a6_session_init(&session, &cfg);
    send_obfuscation(fd, &cfg);

    if (a6_build_initiation(&session, buf, sizeof buf, &len) != 0) {
        printf("build init failed: %s\n", session.last_error);
        return 1;
    }
    printf("init len=%zu send=%zd\n", len, send(fd, buf, len, 0));

    uint64_t retry_at = a6_now_ms() + 5000;
    for (i = 0; i < 200; ++i) {
        if (a6_now_ms() >= retry_at) {
            retry_at = a6_now_ms() + 5000;
            send_obfuscation(fd, &cfg);
            if (a6_build_initiation(&session, buf, sizeof buf, &len) == 0)
                send(fd, buf, len, 0);
        }
        struct pollfd pfd = { fd, POLLIN, 0 };
        int pr = poll(&pfd, 1, 100);
        ssize_t got;
        int type;
        if (pr <= 0) continue;
        got = recv(fd, buf, sizeof buf, 0);
        if (got <= 0) continue;
        type = a6_packet_type(&cfg, buf, (size_t)got);
        printf("rx len=%zd type=%d\n", got, type);
        if (type == 3) {
            printf("cookie challenge %s\n", a6_consume_cookie(&session, buf, (size_t)got) == 0 ? "accepted" : "rejected");
        }
        if (type == 2) {
            if (a6_consume_response(&session, buf, (size_t)got) == 0) {
                printf("HANDSHAKE OK remote_index=%u local_index=%u\n",
                       session.remote_index, session.local_index);
                break;
            }
            printf("response rejected: %s\n", session.last_error);
        }
    }
    if (!session.established) {
        printf("HANDSHAKE FAILED: %s\n", session.last_error);
        return 1;
    }

    /* Keepalive. */
    if (a6_build_transport(&session, NULL, 0, buf, sizeof buf, &len) == 0)
        printf("keepalive send=%zd len=%zu\n", send(fd, buf, len, 0), len);

    /* A real DNS query through the tunnel. */
    {
        size_t iplen = build_dns_packet(inner, sizeof inner);
        if (a6_build_transport(&session, inner, iplen, buf, sizeof buf, &len) != 0) {
            printf("dns transport build failed: %s\n", session.last_error);
            return 1;
        }
        printf("dns packet send=%zd len=%zu\n", send(fd, buf, len, 0), len);
    }

    int answered = 0;
    for (i = 0; i < 50; ++i) {
        struct pollfd pfd = { fd, POLLIN, 0 };
        int pr = poll(&pfd, 1, 100);
        ssize_t got;
        size_t inner_len = 0;
        if (pr <= 0) continue;
        got = recv(fd, buf, sizeof buf, 0);
        if (got <= 0) continue;
        if (a6_packet_type(&cfg, buf, (size_t)got) != 4) continue;
        if (a6_open_transport(&session, buf, (size_t)got, inner, sizeof inner, &inner_len) != 0)
            continue;
        printf("inner len=%zu version=%d proto=%d\n", inner_len,
               inner_len ? inner[0] >> 4 : 0, inner_len > 9 ? inner[9] : -1);
        if (inner_len > 28 && inner[9] == 17) {
            size_t dns_off = 20 + 8;
            printf("dns answer count=%d\n",
                   inner_len > dns_off + 7 ? (inner[dns_off + 6] << 8) | inner[dns_off + 7] : -1);
            answered = inner_len > dns_off + 7 && (inner[dns_off + 6] || inner[dns_off + 7]);
            break;
        }
    }

    a6_session_wipe(&session);
    a6_config_wipe(&cfg);
    close(fd);
    return answered ? 0 : 1;
}
