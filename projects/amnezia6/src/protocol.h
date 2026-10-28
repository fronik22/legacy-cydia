#ifndef AMNEZIA6_PROTOCOL_H
#define AMNEZIA6_PROTOCOL_H

#include "config.h"

#include <stddef.h>
#include <stdint.h>

#define A6_INIT_LEN 148
#define A6_RESP_LEN 92
#define A6_COOKIE_LEN 64
#define A6_TRANSPORT_HDR_LEN 16
#define A6_MAX_DATAGRAM 2048

typedef struct {
    uint8_t chain_key[32];
    uint8_t hash[32];
    uint8_t ephemeral_private[32];
    uint8_t ephemeral_public[32];
    uint32_t local_index;
    uint8_t mac1[16];
    uint64_t created_ms;
    int cookie_consumed;
    int active;
} a6_pending_t;

typedef struct {
    const a6_config_t *cfg;
    a6_pending_t pending;

    uint8_t send_key[32];
    uint8_t recv_key[32];
    uint32_t local_index;
    uint32_t remote_index;
    uint64_t send_counter;
    uint64_t recv_max;
    uint64_t recv_bitmap;
    int have_recv;
    int established;
    uint64_t established_ms;
    uint8_t cookie[16];
    uint64_t cookie_ms;
    int have_cookie;
    size_t udp_window;

    uint32_t handshake_attempts;
    uint64_t last_initiation_ms;
    char last_error[160];
} a6_session_t;

void a6_session_init(a6_session_t *s, const a6_config_t *cfg);
void a6_session_wipe(a6_session_t *s);

int a6_packet_type(const a6_config_t *cfg, const uint8_t *packet, size_t len);

int a6_build_initiation(a6_session_t *s, uint8_t *out, size_t cap,
                        size_t *out_len);
int a6_consume_response(a6_session_t *s, const uint8_t *packet, size_t len);
int a6_consume_cookie(a6_session_t *s, const uint8_t *packet, size_t len);

int a6_build_transport(a6_session_t *s, const uint8_t *ip, size_t ip_len,
                       uint8_t *out, size_t cap, size_t *out_len);
int a6_open_transport(a6_session_t *s, const uint8_t *packet, size_t len,
                      uint8_t *ip, size_t cap, size_t *ip_len);

uint64_t a6_now_ms(void);

/* Expand an AmneziaWG I1..I5 signature description. */
int a6_signature_expand(const char *spec, uint8_t *out, size_t cap,
                        size_t *out_len);

#endif
