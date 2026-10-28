#include "blake2s.h"

#include <string.h>

static const uint32_t k_iv[8] = {
    0x6a09e667u, 0xbb67ae85u, 0x3c6ef372u, 0xa54ff53au,
    0x510e527fu, 0x9b05688cu, 0x1f83d9abu, 0x5be0cd19u
};

static const uint8_t k_sigma[10][16] = {
    { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15 },
    {14,10, 4, 8, 9,15,13, 6, 1,12, 0, 2,11, 7, 5, 3 },
    {11, 8,12, 0, 5, 2,15,13,10,14, 3, 6, 7, 1, 9, 4 },
    { 7, 9, 3, 1,13,12,11,14, 2, 6, 5,10, 4, 0,15, 8 },
    { 9, 0, 5, 7, 2, 4,10,15,14, 1,11,12, 6, 8, 3,13 },
    { 2,12, 6,10, 0,11, 8, 3, 4,13, 7, 5,15,14, 1, 9 },
    {12, 5, 1,15,14,13, 4,10, 0, 7, 6, 3, 9, 2, 8,11 },
    {13,11, 7,14,12, 1, 3, 9, 5, 0,15, 4, 8, 6, 2,10 },
    { 6,15,14, 9,11, 3, 0, 8,12, 2,13, 7, 1, 4,10, 5 },
    {10, 2, 8, 4, 7, 6, 1, 5,15,11, 9,14, 3,12,13, 0 }
};

static uint32_t load32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static void store32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
}

static uint32_t rotr32(uint32_t v, unsigned n) {
    return (v >> n) | (v << (32 - n));
}

#define G(a, b, c, d, x, y) do { \
    v[a] = v[a] + v[b] + (x); \
    v[d] = rotr32(v[d] ^ v[a], 16); \
    v[c] = v[c] + v[d]; \
    v[b] = rotr32(v[b] ^ v[c], 12); \
    v[a] = v[a] + v[b] + (y); \
    v[d] = rotr32(v[d] ^ v[a], 8); \
    v[c] = v[c] + v[d]; \
    v[b] = rotr32(v[b] ^ v[c], 7); \
} while (0)

static void compress(a6_blake2s_ctx *ctx, const uint8_t block[64], int last) {
    uint32_t v[16];
    uint32_t m[16];
    unsigned i, r;

    for (i = 0; i < 8; ++i) {
        v[i] = ctx->h[i];
        v[i + 8] = k_iv[i];
    }
    v[12] ^= ctx->t[0];
    v[13] ^= ctx->t[1];
    if (last) v[14] = ~v[14];
    for (i = 0; i < 16; ++i) m[i] = load32(block + i * 4);

    for (r = 0; r < 10; ++r) {
        const uint8_t *s = k_sigma[r];
        G(0, 4,  8, 12, m[s[0]],  m[s[1]]);
        G(1, 5,  9, 13, m[s[2]],  m[s[3]]);
        G(2, 6, 10, 14, m[s[4]],  m[s[5]]);
        G(3, 7, 11, 15, m[s[6]],  m[s[7]]);
        G(0, 5, 10, 15, m[s[8]],  m[s[9]]);
        G(1, 6, 11, 12, m[s[10]], m[s[11]]);
        G(2, 7,  8, 13, m[s[12]], m[s[13]]);
        G(3, 4,  9, 14, m[s[14]], m[s[15]]);
    }

    for (i = 0; i < 8; ++i) ctx->h[i] ^= v[i] ^ v[i + 8];
}

#undef G

void a6_blake2s_init(a6_blake2s_ctx *ctx, const void *key, size_t keylen,
                     size_t outlen) {
    unsigned i;
    memset(ctx, 0, sizeof *ctx);
    ctx->outlen = outlen ? outlen : 32;
    for (i = 0; i < 8; ++i) ctx->h[i] = k_iv[i];
    ctx->h[0] ^= 0x01010000u ^ ((uint32_t)keylen << 8) ^ (uint32_t)ctx->outlen;
    if (keylen) {
        memset(ctx->buf, 0, sizeof ctx->buf);
        memcpy(ctx->buf, key, keylen);
        ctx->buflen = 64;
    }
}

void a6_blake2s_update(a6_blake2s_ctx *ctx, const void *data, size_t len) {
    const uint8_t *p = (const uint8_t *)data;

    if (len == 0) return;

    if (ctx->buflen == 64) {
        ctx->t[0] += 64;
        if (ctx->t[0] < 64) ctx->t[1]++;
        compress(ctx, ctx->buf, 0);
        ctx->buflen = 0;
    }

    while (len > 64) {
        ctx->t[0] += 64;
        if (ctx->t[0] < 64) ctx->t[1]++;
        compress(ctx, p, 0);
        p += 64;
        len -= 64;
    }

    memcpy(ctx->buf + ctx->buflen, p, len);
    ctx->buflen += len;
}

void a6_blake2s_final(a6_blake2s_ctx *ctx, uint8_t *out) {
    unsigned i;

    ctx->t[0] += (uint32_t)ctx->buflen;
    if (ctx->t[0] < ctx->buflen) ctx->t[1]++;
    memset(ctx->buf + ctx->buflen, 0, 64 - ctx->buflen);
    compress(ctx, ctx->buf, 1);

    for (i = 0; i < ctx->outlen; ++i)
        out[i] = (uint8_t)(ctx->h[i / 4] >> (8 * (i % 4)));
}

void a6_blake2s(uint8_t out[32], const void *data, size_t len) {
    a6_blake2s_ctx ctx;
    a6_blake2s_init(&ctx, NULL, 0, 32);
    a6_blake2s_update(&ctx, data, len);
    a6_blake2s_final(&ctx, out);
}

void a6_blake2s_keyed(uint8_t *out, size_t outlen,
                      const void *key, size_t keylen,
                      const void *data, size_t len) {
    a6_blake2s_ctx ctx;
    a6_blake2s_init(&ctx, key, keylen, outlen);
    a6_blake2s_update(&ctx, data, len);
    a6_blake2s_final(&ctx, out);
}

void a6_hmac_blake2s(uint8_t out[32], const void *key, size_t keylen,
                     const void *data, size_t len) {
    uint8_t k[64];
    uint8_t pad[64];
    uint8_t inner[32];
    a6_blake2s_ctx ctx;
    unsigned i;

    memset(k, 0, sizeof k);
    if (keylen > sizeof k) {
        a6_blake2s(k, key, keylen);
    } else if (keylen) {
        memcpy(k, key, keylen);
    }

    for (i = 0; i < sizeof k; ++i) pad[i] = (uint8_t)(k[i] ^ 0x36);
    a6_blake2s_init(&ctx, NULL, 0, 32);
    a6_blake2s_update(&ctx, pad, sizeof pad);
    a6_blake2s_update(&ctx, data, len);
    a6_blake2s_final(&ctx, inner);

    for (i = 0; i < sizeof k; ++i) pad[i] = (uint8_t)(k[i] ^ 0x5c);
    a6_blake2s_init(&ctx, NULL, 0, 32);
    a6_blake2s_update(&ctx, pad, sizeof pad);
    a6_blake2s_update(&ctx, inner, sizeof inner);
    a6_blake2s_final(&ctx, out);

    memset(k, 0, sizeof k);
    memset(pad, 0, sizeof pad);
    memset(inner, 0, sizeof inner);
}
