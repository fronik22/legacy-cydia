#ifndef AMNEZIA6_CRYPTO_H
#define AMNEZIA6_CRYPTO_H

#include <stddef.h>
#include <stdint.h>

#define A6_KEY_LEN 32
#define A6_TAG_LEN 16

int a6_random(void *out, size_t len);
void a6_random_u32(uint32_t *out);
uint32_t a6_random_range(uint32_t min, uint32_t max);

void a6_x25519_keypair(uint8_t public_key[32], const uint8_t private_key[32]);
int a6_x25519(uint8_t shared[32], const uint8_t private_key[32],
              const uint8_t public_key[32]);

void a6_aead_seal(uint8_t *ciphertext, uint8_t tag[16],
                  const uint8_t key[32], const uint8_t nonce[12],
                  const void *ad, size_t ad_len,
                  const void *plaintext, size_t plaintext_len);
int a6_aead_open(uint8_t *plaintext, const uint8_t key[32],
                 const uint8_t nonce[12],
                 const void *ad, size_t ad_len,
                 const uint8_t *ciphertext, size_t ciphertext_len,
                 const uint8_t tag[16]);

void a6_chacha20_xor(uint8_t *out, const uint8_t *in, size_t len,
                     const uint8_t key[32], const uint8_t nonce[12]);

void a6_wipe(void *data, size_t len);
int a6_constant_time_equal(const void *a, const void *b, size_t len);

/* Base64 */
int a6_base64_decode(const char *text, uint8_t *out, size_t cap, size_t *out_len);

/* Little-endian helpers */
uint32_t a6_load_le32(const uint8_t *p);
uint64_t a6_load_le64(const uint8_t *p);
void a6_store_le32(uint8_t *p, uint32_t v);
void a6_store_le64(uint8_t *p, uint64_t v);
uint32_t a6_load_be32(const uint8_t *p);
void a6_store_be32(uint8_t *p, uint32_t v);

#endif
