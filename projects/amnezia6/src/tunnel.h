#ifndef AMNEZIA6_TUNNEL_H
#define AMNEZIA6_TUNNEL_H

#include "config.h"
#include "dns.h"
#include "protocol.h"

#include <stddef.h>
#include <stdint.h>

typedef enum {
    A6_STATE_IDLE = 0,
    A6_STATE_CONNECTING = 1,
    A6_STATE_CONNECTED = 2,
    A6_STATE_ERROR = 3
} a6_state_t;

typedef struct {
    a6_config_t cfg;
    a6_session_t session;
    a6_dns_t dns;
    a6_state_t state;

    int udp_fd;
    int utun_fd;
    char ifname[32];
    char endpoint_ip[64];
    char gateway[64];
    char source_ip[64];
    int retry_pending;
    unsigned retry_delay_seconds;
    uint64_t retry_at_ms;
    uint64_t source_check_ms;

    int routes_up;
    int host_route_added;
    int dns_up;
    int iface_up;

    uint64_t started_ms;
    uint64_t connected_ms;
    uint64_t last_rx_ms;
    uint64_t last_tx_ms;
    uint64_t last_initiation_ms;
    uint64_t next_handshake_ms;
    uint64_t rekey_at_ms;
    uint64_t reject_at_ms;
    uint64_t persistent_keepalive_at_ms, keepalive_at_ms, new_handshake_at_ms;
    int keepalive_pending_again;

    uint32_t handshake_attempts, max_handshake_attempts;
    uint32_t rekey_after_seconds;
    uint32_t reject_after_seconds;

    uint64_t tx_bytes;
    uint64_t rx_bytes;
    uint64_t tx_packets;
    uint64_t rx_packets;

    char error[192];
} a6_tunnel_t;

void a6_tunnel_init(a6_tunnel_t *t);
int a6_tunnel_start(a6_tunnel_t *t, const a6_config_t *cfg,
                    char *err, size_t err_cap);
void a6_tunnel_stop(a6_tunnel_t *t);

int a6_tunnel_udp_fd(const a6_tunnel_t *t);
int a6_tunnel_utun_fd(const a6_tunnel_t *t);

void a6_tunnel_handle_udp(a6_tunnel_t *t);
void a6_tunnel_handle_utun(a6_tunnel_t *t);
void a6_tunnel_timers(a6_tunnel_t *t);
int a6_tunnel_timeout_ms(const a6_tunnel_t *t);

const char *a6_state_name(a6_state_t state);

#endif
