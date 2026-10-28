#include "crypto.h"

#include "monocypher.h"

#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

static int g_urandom = -1;

static int ensure_random(void) {
    if (g_urandom >= 0) return 0;
    g_urandom = open("/dev/urandom", O_RDONLY);
    return g_urandom >= 0 ? 0 : -1;
}

int a6_random(void *out, size_t len) {
    uint8_t *p = (uint8_t *)out;
    size_t off = 0;

    if (ensure_random() == 0) {
        while (off < len) {
            ssize_t n = read(g_urandom, p + off, len - off);
            if (n > 0) {
                off += (size_t)n;
                continue;
            }
            if (n < 0 && errno == EINTR) continue;
            break;
        }
        if (off == len) return 0;
    }

    /* Extremely unlikely fallback: never leave the caller with zero bytes. */
    {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        uint32_t x = (uint32_t)tv.tv_sec ^ (uint32_t)tv.tv_usec ^
                     ((uint32_t)getpid() << 16) ^ 0x9e3779b9u;
        while (off < len) {
            x ^= x << 13; x ^= x >> 17; x ^= x << 5;
            p[off++] = (uint8_t)x;
        }
    }
    return 0;
}

void a6_random_u32(uint32_t *out) {
    uint8_t b[4];
    uint32_t v;
    a6_random(b, sizeof b);
    v = a6_load_le32(b);
    *out = v ? v : 1;
}

uint32_t a6_random_range(uint32_t min, uint32_t max) {
    uint32_t r;
    uint64_t span;
    if (max <= min) return min;
    span = (uint64_t)max - min + 1;
    a6_random_u32(&r);
    return min + (uint32_t)(r % span);
}

void a6_x25519_keypair(uint8_t public_key[32], const uint8_t private_key[32]) {
    crypto_x25519_public_key(public_key, private_key);
}

int a6_x25519(uint8_t shared[32], const uint8_t private_key[32],
              const uint8_t public_key[32]) {
    static const uint8_t zero[32] = {0};
    crypto_x25519(shared, private_key, public_key);
    return a6_constant_time_equal(shared, zero, 32) ? -1 : 0;
}

static void poly1305_pad16(crypto_poly1305_ctx *ctx, size_t len) {
    static const uint8_t zero[16] = {0};
    size_t rem = len & 15;
    if (rem) crypto_poly1305_update(ctx, zero, 16 - rem);
}

static void poly1305_sizes(crypto_poly1305_ctx *ctx, size_t ad_len, size_t len) {
    uint8_t sizes[16];
    a6_store_le64(sizes, (uint64_t)ad_len);
    a6_store_le64(sizes + 8, (uint64_t)len);
    crypto_poly1305_update(ctx, sizes, sizeof sizes);
}

void a6_aead_seal(uint8_t *ciphertext, uint8_t tag[16],
                  const uint8_t key[32], const uint8_t nonce[12],
                  const void *ad, size_t ad_len,
                  const void *plaintext, size_t plaintext_len) {
    uint8_t poly_key[64];
    static const uint8_t zero[64] = {0};
    crypto_poly1305_ctx poly;

    crypto_chacha20_ietf(poly_key, zero, sizeof poly_key, key, nonce, 0);
    crypto_chacha20_ietf(ciphertext, (const uint8_t *)plaintext, plaintext_len,
                         key, nonce, 1);

    crypto_poly1305_init(&poly, poly_key);
    crypto_poly1305_update(&poly, (const uint8_t *)ad, ad_len);
    poly1305_pad16(&poly, ad_len);
    crypto_poly1305_update(&poly, ciphertext, plaintext_len);
    poly1305_pad16(&poly, plaintext_len);
    poly1305_sizes(&poly, ad_len, plaintext_len);
    crypto_poly1305_final(&poly, tag);

    a6_wipe(poly_key, sizeof poly_key);
}

int a6_aead_open(uint8_t *plaintext, const uint8_t key[32],
                 const uint8_t nonce[12],
                 const void *ad, size_t ad_len,
                 const uint8_t *ciphertext, size_t ciphertext_len,
                 const uint8_t tag[16]) {
    uint8_t poly_key[64];
    uint8_t real_tag[16];
    static const uint8_t zero[64] = {0};
    crypto_poly1305_ctx poly;
    int bad;

    crypto_chacha20_ietf(poly_key, zero, sizeof poly_key, key, nonce, 0);
    crypto_poly1305_init(&poly, poly_key);
    crypto_poly1305_update(&poly, (const uint8_t *)ad, ad_len);
    poly1305_pad16(&poly, ad_len);
    crypto_poly1305_update(&poly, ciphertext, ciphertext_len);
    poly1305_pad16(&poly, ciphertext_len);
    poly1305_sizes(&poly, ad_len, ciphertext_len);
    crypto_poly1305_final(&poly, real_tag);

    bad = !a6_constant_time_equal(real_tag, tag, 16);
    if (!bad)
        crypto_chacha20_ietf(plaintext, ciphertext, ciphertext_len,
                             key, nonce, 1);

    a6_wipe(poly_key, sizeof poly_key);
    a6_wipe(real_tag, sizeof real_tag);
    return bad ? -1 : 0;
}

void a6_chacha20_xor(uint8_t *out, const uint8_t *in, size_t len,
                     const uint8_t key[32], const uint8_t nonce[12]) {
    crypto_chacha20_ietf(out, in, len, key, nonce, 0);
}

void a6_wipe(void *data, size_t len) {
    crypto_wipe(data, len);
}

int a6_constant_time_equal(const void *a, const void *b, size_t len) {
    const uint8_t *x = (const uint8_t *)a;
    const uint8_t *y = (const uint8_t *)b;
    uint8_t diff = 0;
    size_t i;
    for (i = 0; i < len; ++i) diff |= (uint8_t)(x[i] ^ y[i]);
    return diff == 0;
}

static int b64_value(unsigned char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}

int a6_base64_decode(const char *text, uint8_t *out, size_t cap, size_t *out_len) {
    uint32_t acc = 0;
    int bits = 0;
    size_t n = 0;
    const unsigned char *p = (const unsigned char *)text;

    for (; *p; ++p) {
        int v;
        if (*p == '=' || *p == '\r' || *p == '\n' || *p == ' ' || *p == '\t')
            continue;
        v = b64_value(*p);
        if (v < 0) return -1;
        acc = (acc << 6) | (uint32_t)v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            if (n >= cap) return -1;
            out[n++] = (uint8_t)(acc >> bits);
            acc &= (1u << bits) - 1u;
        }
    }
    *out_len = n;
    return 0;
}

uint32_t a6_load_le32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

uint64_t a6_load_le64(const uint8_t *p) {
    return (uint64_t)a6_load_le32(p) | ((uint64_t)a6_load_le32(p + 4) << 32);
}

void a6_store_le32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)v;
    p[1] = (uint8_t)(v >> 8);
    p[2] = (uint8_t)(v >> 16);
    p[3] = (uint8_t)(v >> 24);
}

void a6_store_le64(uint8_t *p, uint64_t v) {
    a6_store_le32(p, (uint32_t)v);
    a6_store_le32(p + 4, (uint32_t)(v >> 32));
}

uint32_t a6_load_be32(const uint8_t *p) {
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) |
           ((uint32_t)p[2] << 8) | (uint32_t)p[3];
}

void a6_store_be32(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v >> 24);
    p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8);
    p[3] = (uint8_t)v;
}
