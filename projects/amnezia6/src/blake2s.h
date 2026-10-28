#ifndef AMNEZIA6_BLAKE2S_H
#define AMNEZIA6_BLAKE2S_H

#include <stddef.h>
#include <stdint.h>

#define A6_BLAKE2S_BLOCK 64
#define A6_BLAKE2S_DIGEST 32

typedef struct {
    uint32_t h[8];
    uint32_t t[2];
    uint8_t buf[A6_BLAKE2S_BLOCK];
    size_t buflen;
    size_t outlen;
} a6_blake2s_ctx;

void a6_blake2s_init(a6_blake2s_ctx *ctx, const void *key, size_t keylen,
                     size_t outlen);
void a6_blake2s_update(a6_blake2s_ctx *ctx, const void *data, size_t len);
void a6_blake2s_final(a6_blake2s_ctx *ctx, uint8_t *out);

void a6_blake2s(uint8_t out[32], const void *data, size_t len);
void a6_blake2s_keyed(uint8_t *out, size_t outlen,
                      const void *key, size_t keylen,
                      const void *data, size_t len);
void a6_hmac_blake2s(uint8_t out[32], const void *key, size_t keylen,
                     const void *data, size_t len);

#endif
