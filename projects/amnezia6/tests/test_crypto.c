#include "../src/blake2s.h"
#include "../src/crypto.h"

#include <stdio.h>
#include <string.h>

static int fails;

static void hex(const uint8_t *p, size_t n, char *out) {
    static const char d[] = "0123456789abcdef";
    size_t i;
    for (i = 0; i < n; ++i) {
        out[i * 2] = d[p[i] >> 4];
        out[i * 2 + 1] = d[p[i] & 15];
    }
    out[n * 2] = 0;
}

static void check_hex(const char *name, const uint8_t *got, size_t n, const char *want) {
    char buf[256];
    hex(got, n, buf);
    if (strcmp(buf, want) != 0) {
        printf("FAIL %s\n  got  %s\n  want %s\n", name, buf, want);
        fails++;
    } else {
        printf("ok   %s\n", name);
    }
}

static void check_int(const char *name, int got, int want) {
    if (got != want) {
        printf("FAIL %s got=%d want=%d\n", name, got, want);
        fails++;
    } else {
        printf("ok   %s\n", name);
    }
}

static void from_hex(uint8_t *out, const char *s) {
    size_t i;
    for (i = 0; s[i] && s[i + 1]; i += 2) {
        unsigned v;
        sscanf(s + i, "%2x", &v);
        out[i / 2] = (uint8_t)v;
    }
}

int main(void) {
    uint8_t out[64];
    uint8_t key[32];
    uint8_t nonce[12];
    uint8_t ct[64], pt[64], tag[16];
    size_t b64len = 0;

    a6_blake2s(out, "", 0);
    check_hex("blake2s empty", out, 32,
              "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9");

    a6_blake2s(out, "abc", 3);
    check_hex("blake2s abc", out, 32,
              "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982");

    for (int i = 0; i < 32; ++i) key[i] = (uint8_t)i;
    a6_blake2s_keyed(out, 32, key, 32, "abc", 3);
    check_hex("blake2s keyed", out, 32,
              "a281f725754969a702f6fe36fc591b7def866e4b70173ece402fc01c064d6b65");

    a6_blake2s_keyed(out, 16, key, 32, "abc", 3);
    check_hex("blake2s keyed16", out, 16, "61ba5f165c194692e09d12520cc4c74a");

    a6_hmac_blake2s(out, "key", 3, "The quick brown fox jumps over the lazy dog", 43);
    check_hex("hmac blake2s", out, 32,
              "f93215bb90d4af4c3061cd932fb169fb8bb8a91d0b4022baea1271e1323cd9a0");

    {
        uint8_t s[32], u[32], sh[32];
        from_hex(s, "a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4");
        from_hex(u, "e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c");
        a6_x25519(sh, s, u);
        check_hex("x25519 rfc7748", sh, 32,
                  "c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552");
    }

    memset(key, 0x11, sizeof key);
    memset(nonce, 0x22, sizeof nonce);
    memset(pt, 0x33, sizeof pt);
    a6_aead_seal(ct, tag, key, nonce, "ad", 2, pt, sizeof pt);
    memset(pt, 0, sizeof pt);
    check_int("aead roundtrip", a6_aead_open(pt, key, nonce, "ad", 2, ct, sizeof ct, tag), 0);
    check_int("aead plaintext", memcmp(pt, "\x33\x33\x33\x33", 4), 0);
    tag[0] ^= 1;
    check_int("aead rejects tamper", a6_aead_open(pt, key, nonce, "ad", 2, ct, sizeof ct, tag), -1);

    check_int("base64 decode",
              a6_base64_decode("AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=",
                               out, sizeof out, &b64len), 0);
    check_int("base64 length", (int)b64len, 32);
    check_int("base64 bytes", memcmp(out, key, 0), 0);

    printf(fails ? "\n%d FAILURE(S)\n" : "\nall crypto tests passed\n", fails);
    return fails ? 1 : 0;
}
