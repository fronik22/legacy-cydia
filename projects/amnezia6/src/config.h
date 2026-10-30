#ifndef AMNEZIA6_CONFIG_H
#define AMNEZIA6_CONFIG_H

#include <stddef.h>
#include <stdint.h>

#define A6_SIG_COUNT 5
#define A6_SIG_MAX 2048

typedef struct {
    uint32_t min;
    uint32_t max;
} a6_range;

typedef struct {
    uint8_t private_key[32];
    uint8_t public_key[32];
    uint8_t peer_public_key[32];
    uint8_t preshared_key[32];
    int has_preshared_key;

    uint8_t header_protection_key[32];
    int has_header_protection;

    char address[64];
    char dns[64];
    char endpoint_host[128];
    uint16_t endpoint_port;
    uint32_t mtu;
    a6_range persistent_keepalive;

    uint32_t jc;
    uint32_t jmin;
    uint32_t jmax;
    uint32_t s[4];
    a6_range h[4];
    a6_range rekey_after;
    a6_range rekey_timeout;
    a6_range reject_after;
    a6_range keepalive_timeout;
    a6_range max_handshake_attempts;
    a6_range content_padding_addition;
    int random_trailers;
    int disable_cookies;

    char signature[A6_SIG_COUNT][A6_SIG_MAX];
    int signature_present[A6_SIG_COUNT];
} a6_config_t;

int a6_config_load(const char *path, a6_config_t *cfg,
                   char *err, size_t err_cap);
int a6_config_parse(const char *text, size_t len, a6_config_t *cfg,
                    char *err, size_t err_cap);
void a6_config_wipe(a6_config_t *cfg);

#endif
