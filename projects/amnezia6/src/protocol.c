#include "protocol.h"

#include "blake2s.h"
#include "crypto.h"
#include "monocypher.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include <mach/mach_time.h>
#include <pthread.h>

static const uint8_t k_construction[] = "Noise_IKpsk2_25519_ChaChaPoly_BLAKE2s";
static const uint8_t k_identifier[] = "WireGuard v1 zx2c4 Jason@zx2c4.com";
static const uint8_t k_mac1_label[] = "mac1----";

static void set_error(a6_session_t *s, const char *text) {
    if (s) snprintf(s->last_error, sizeof s->last_error, "%s", text);
}

static mach_timebase_info_data_t timebase;
static pthread_once_t timebase_once = PTHREAD_ONCE_INIT;
static void init_timebase(void) { mach_timebase_info(&timebase); }

uint64_t a6_now_ms(void) {
    pthread_once(&timebase_once, init_timebase);
    return (uint64_t)((long double)mach_absolute_time() * timebase.numer / timebase.denom / 1000000.0L);
}

static void handshake_nonce(uint64_t counter, uint8_t nonce[12]) {
    memset(nonce, 0, 12);
    a6_store_le64(nonce + 4, counter);
}

static void kdf2(const uint8_t chain_key[32], const void *input, size_t input_len,
                 uint8_t out1[32], uint8_t out2[32]) {
    uint8_t temp[32];
    uint8_t part[33];
    a6_hmac_blake2s(temp, chain_key, 32, input, input_len);
    part[0] = 1;
    a6_hmac_blake2s(out1, temp, 32, part, 1);
    memcpy(part, out1, 32);
    part[32] = 2;
    a6_hmac_blake2s(out2, temp, 32, part, 33);
    a6_wipe(temp, sizeof temp);
    a6_wipe(part, sizeof part);
}

static void kdf3(const uint8_t chain_key[32], const void *input, size_t input_len,
                 uint8_t out1[32], uint8_t out2[32], uint8_t out3[32]) {
    uint8_t temp[32];
    uint8_t part[33];
    a6_hmac_blake2s(temp, chain_key, 32, input, input_len);
    part[0] = 1;
    a6_hmac_blake2s(out1, temp, 32, part, 1);
    memcpy(part, out1, 32);
    part[32] = 2;
    a6_hmac_blake2s(out2, temp, 32, part, 33);
    memcpy(part, out2, 32);
    part[32] = 3;
    a6_hmac_blake2s(out3, temp, 32, part, 33);
    a6_wipe(temp, sizeof temp);
    a6_wipe(part, sizeof part);
}

static void mix_hash(uint8_t hash[32], const void *input, size_t len) {
    uint8_t buf[32 + 128];
    if (len > sizeof buf - 32) return;
    memcpy(buf, hash, 32);
    memcpy(buf + 32, input, len);
    a6_blake2s(hash, buf, 32 + len);
}

static void mix_key(uint8_t chain_key[32], const void *input, size_t len,
                    uint8_t key[32]) {
    uint8_t next[32];
    kdf2(chain_key, input, len, next, key);
    memcpy(chain_key, next, 32);
    a6_wipe(next, sizeof next);
}

static void seal_and_hash(uint8_t hash[32], const uint8_t key[32],
                          const void *plain, size_t plain_len, uint8_t *out) {
    uint8_t nonce[12];
    handshake_nonce(0, nonce);
    a6_aead_seal(out, out + plain_len, key, nonce, hash, 32, plain, plain_len);
    mix_hash(hash, out, plain_len + A6_TAG_LEN);
}

static int open_and_hash(uint8_t hash[32], const uint8_t key[32],
                         const uint8_t *ciphertext, size_t ciphertext_len,
                         uint8_t *out) {
    uint8_t nonce[12];
    int r;
    if (ciphertext_len < A6_TAG_LEN) return -1;
    handshake_nonce(0, nonce);
    r = a6_aead_open(out, key, nonce, hash, 32, ciphertext,
                     ciphertext_len - A6_TAG_LEN, ciphertext + ciphertext_len - A6_TAG_LEN);
    if (r == 0) mix_hash(hash, ciphertext, ciphertext_len);
    return r;
}

static void make_tai64n(uint8_t out[12]) {
    struct timeval tv;
    uint64_t seconds;
    uint32_t nanos;
    gettimeofday(&tv, NULL);
    seconds = (uint64_t)tv.tv_sec + 0x400000000000000aULL;
    nanos = (uint32_t)tv.tv_usec * 1000U;
    out[0] = (uint8_t)(seconds >> 56);
    out[1] = (uint8_t)(seconds >> 48);
    out[2] = (uint8_t)(seconds >> 40);
    out[3] = (uint8_t)(seconds >> 32);
    out[4] = (uint8_t)(seconds >> 24);
    out[5] = (uint8_t)(seconds >> 16);
    out[6] = (uint8_t)(seconds >> 8);
    out[7] = (uint8_t)seconds;
    out[8] = (uint8_t)(nanos >> 24);
    out[9] = (uint8_t)(nanos >> 16);
    out[10] = (uint8_t)(nanos >> 8);
    out[11] = (uint8_t)nanos;
}

static void header_protect(const a6_config_t *cfg, uint8_t *fixed, size_t len,
                           const uint8_t *prefix) {
    if (!cfg->has_header_protection) return;
    a6_chacha20_xor(fixed, fixed, len, cfg->header_protection_key, prefix);
}

static uint32_t header_keystream(const a6_config_t *cfg, const uint8_t *packet) {
    uint8_t zero[4] = {0, 0, 0, 0};
    uint8_t stream[4];
    if (!cfg->has_header_protection) return 0;
    a6_chacha20_xor(stream, zero, sizeof stream, cfg->header_protection_key, packet);
    return a6_load_le32(stream);
}

int a6_packet_type(const a6_config_t *cfg, const uint8_t *packet, size_t len) {
    static const size_t fixed_len[4] = { A6_INIT_LEN, A6_RESP_LEN, A6_COOKIE_LEN,
                                         A6_TRANSPORT_HDR_LEN };
    uint32_t stream = 0;
    int i;

    if (!cfg || !packet || len < 4) return 0;
    if (cfg->has_header_protection) {
        if (len < 12) return 0;
        stream = header_keystream(cfg, packet);
    }

    for (i = 0; i < 4; ++i) {
        size_t off = cfg->s[i];
        uint32_t type;
        if (len < off + fixed_len[i]) continue;
        if (i == 3 && len < off + A6_TRANSPORT_HDR_LEN + A6_TAG_LEN) continue;
        type = a6_load_le32(packet + off) ^ stream;
        if (type >= cfg->h[i].min && type <= cfg->h[i].max) return i + 1;
    }
    return 0;
}

static int make_mac1(const uint8_t peer_public[32], const uint8_t *msg,
                     size_t msg_len, uint8_t out[16]) {
    uint8_t key_input[8 + 32];
    uint8_t key[32];
    memcpy(key_input, k_mac1_label, 8);
    memcpy(key_input + 8, peer_public, 32);
    a6_blake2s(key, key_input, sizeof key_input);
    a6_blake2s_keyed(out, 16, key, sizeof key, msg, msg_len);
    a6_wipe(key, sizeof key);
    a6_wipe(key_input, sizeof key_input);
    return 0;
}

void a6_session_init(a6_session_t *s, const a6_config_t *cfg) {
    memset(s, 0, sizeof *s);
    s->cfg = cfg;
    s->udp_window = 500;
}

void a6_session_wipe(a6_session_t *s) {
    if (s) a6_wipe(s, sizeof *s);
}

static size_t trailer_length(a6_session_t *s, size_t packet_size, size_t cap) {
    if (!s->cfg->random_trailers || packet_size >= cap) return 0;
    size_t window = s->udp_window < cap ? s->udp_window : cap;
    return packet_size < window ? a6_random_range(0, (uint32_t)(window - packet_size - 1)) : 0;
}

int a6_build_initiation(a6_session_t *s, uint8_t *out, size_t cap,
                        size_t *out_len) {
    const a6_config_t *cfg;
    a6_pending_t *p;
    size_t offset, trailer, need;
    uint8_t *msg;
    uint8_t key[32];
    uint8_t shared[32];
    uint8_t timestamp[12];

    if (!s || !s->cfg || !out || !out_len) return -1;
    cfg = s->cfg;
    p = &s->pending;
    offset = cfg->s[0];
    trailer = trailer_length(s, offset + A6_INIT_LEN, cap);
    need = offset + A6_INIT_LEN + trailer;
    if (need > cap) {
        set_error(s, "initiation does not fit in the MTU");
        return -1;
    }

    memset(p, 0, sizeof *p);
    p->active = 1;
    p->created_ms = a6_now_ms();
    a6_random(out, offset);
    msg = out + offset;

    a6_blake2s(p->chain_key, k_construction, sizeof k_construction - 1);
    memcpy(p->hash, p->chain_key, 32);
    mix_hash(p->hash, k_identifier, sizeof k_identifier - 1);
    mix_hash(p->hash, cfg->peer_public_key, 32);

    a6_random(p->ephemeral_private, 32);
    a6_x25519_keypair(p->ephemeral_public, p->ephemeral_private);
    a6_random_u32(&p->local_index);

    a6_store_le32(msg, a6_random_range(cfg->h[0].min, cfg->h[0].max));
    a6_store_le32(msg + 4, p->local_index);
    memcpy(msg + 8, p->ephemeral_public, 32);

    mix_key(p->chain_key, p->ephemeral_public, 32, key);
    mix_hash(p->hash, p->ephemeral_public, 32);

    if (a6_x25519(shared, p->ephemeral_private, cfg->peer_public_key) != 0) {
        set_error(s, "peer public key is not a valid curve point");
        return -1;
    }
    mix_key(p->chain_key, shared, 32, key);

    seal_and_hash(p->hash, key, cfg->public_key, 32, msg + 40);

    if (a6_x25519(shared, cfg->private_key, cfg->peer_public_key) != 0) {
        set_error(s, "static shared secret is invalid");
        return -1;
    }
    mix_key(p->chain_key, shared, 32, key);
    make_tai64n(timestamp);
    seal_and_hash(p->hash, key, timestamp, sizeof timestamp, msg + 88);

    make_mac1(cfg->peer_public_key, msg, 116, msg + 116);
    memcpy(p->mac1, msg + 116, 16);
    if (s->have_cookie && p->created_ms >= s->cookie_ms &&
        p->created_ms - s->cookie_ms < 120000)
        a6_blake2s_keyed(msg + 132, 16, s->cookie, 16, msg, 132);
    else {
        memset(msg + 132, 0, 16);
        a6_wipe(s->cookie, 16); s->have_cookie = 0;
    }
    header_protect(cfg, msg, A6_INIT_LEN, out);
    if (trailer) a6_random(msg + A6_INIT_LEN, trailer);

    *out_len = need;
    a6_wipe(key, sizeof key);
    a6_wipe(shared, sizeof shared);
    a6_wipe(timestamp, sizeof timestamp);
    return 0;
}

int a6_consume_response(a6_session_t *s, const uint8_t *packet, size_t len) {
    const a6_config_t *cfg;
    a6_pending_t *p;
    size_t offset;
    uint8_t msg[A6_RESP_LEN];
    uint8_t key[32];
    uint8_t hash_key[32];
    uint8_t shared[32];
    uint8_t psk[32];
    uint8_t mac[16];

    if (!s || !s->cfg || !packet) return -1;
    cfg = s->cfg;
    p = &s->pending;
    if (!p->active) return -1;
    if (a6_packet_type(cfg, packet, len) != 2) return -1;
    offset = cfg->s[1];
    if (len < offset + A6_RESP_LEN) return -1;
    memcpy(msg, packet + offset, A6_RESP_LEN);
    header_protect(cfg, msg, A6_RESP_LEN, packet);

    if (a6_load_le32(msg) < cfg->h[1].min ||
        a6_load_le32(msg) > cfg->h[1].max ||
        a6_load_le32(msg + 8) != p->local_index) {
        set_error(s, "response is not for our handshake");
        return -1;
    }

    make_mac1(cfg->public_key, msg, 60, mac);
    if (!a6_constant_time_equal(mac, msg + 60, 16)) {
        set_error(s, "response MAC1 is invalid");
        return -1;
    }

    memset(psk, 0, sizeof psk);
    if (cfg->has_preshared_key) memcpy(psk, cfg->preshared_key, 32);

    mix_key(p->chain_key, msg + 12, 32, key);
    mix_hash(p->hash, msg + 12, 32);
    if (a6_x25519(shared, p->ephemeral_private, msg + 12) != 0) {
        set_error(s, "response ephemeral key is invalid");
        return -1;
    }
    mix_key(p->chain_key, shared, 32, key);
    if (a6_x25519(shared, cfg->private_key, msg + 12) != 0) {
        set_error(s, "response static shared secret is invalid");
        return -1;
    }
    mix_key(p->chain_key, shared, 32, key);
    kdf3(p->chain_key, psk, 32, p->chain_key, hash_key, key);
    mix_hash(p->hash, hash_key, 32);

    if (open_and_hash(p->hash, key, msg + 44, 16, NULL) != 0) {
        set_error(s, "response authentication failed");
        return -1;
    }

    kdf2(p->chain_key, NULL, 0, s->send_key, s->recv_key);
    s->local_index = p->local_index;
    s->remote_index = a6_load_le32(msg + 4);
    s->send_counter = 0;
    s->recv_max = 0;
    s->recv_bitmap = 0;
    s->have_recv = 0;
    s->established = 1;
    s->established_ms = a6_now_ms();
    if (len > s->udp_window) s->udp_window = len;
    s->handshake_attempts = 0;
    s->last_error[0] = 0;
    p->active = 0;

    a6_wipe(key, sizeof key);
    a6_wipe(hash_key, sizeof hash_key);
    a6_wipe(shared, sizeof shared);
    a6_wipe(psk, sizeof psk);
    a6_wipe(msg, sizeof msg);
    a6_wipe(mac, sizeof mac);
    return 0;
}

/* WireGuard cookie generator semantics, adapted from MIT-licensed upstream cookie.go. */
int a6_consume_cookie(a6_session_t *s, const uint8_t *packet, size_t len) {
    uint8_t msg[A6_COOKIE_LEN], key_input[40], key[32], cookie[16];
    if (!s || !s->cfg || !packet || !s->pending.active || s->pending.cookie_consumed ||
        a6_packet_type(s->cfg, packet, len) != 3) return -1;
    uint64_t now = a6_now_ms();
    if (now < s->pending.created_ms || now - s->pending.created_ms >= 180000) return -1;
    size_t off = s->cfg->s[2];
    if (len < off + sizeof msg) return -1;
    memcpy(msg, packet + off, sizeof msg);
    header_protect(s->cfg, msg, sizeof msg, packet);
    if (a6_load_le32(msg + 4) != s->pending.local_index) return -1;
    memcpy(key_input, "cookie--", 8);
    memcpy(key_input + 8, s->cfg->peer_public_key, 32);
    a6_blake2s(key, key_input, sizeof key_input);
    int result = crypto_aead_unlock(cookie, msg + 48, key, msg + 8,
                                   s->pending.mac1, 16, msg + 32, 16);
    if (!result) {
        memcpy(s->cookie, cookie, 16); s->cookie_ms = now; s->have_cookie = 1;
        s->pending.cookie_consumed = 1;
    }
    a6_wipe(key, sizeof key); a6_wipe(key_input, sizeof key_input);
    a6_wipe(cookie, sizeof cookie); a6_wipe(msg, sizeof msg);
    return result;
}

static int replay_test(const a6_session_t *s, uint64_t counter) {
    uint64_t diff;
    if (!s->have_recv) return 0;
    if (counter > s->recv_max) return 0;
    diff = s->recv_max - counter;
    if (diff >= 64) return -1;
    return (s->recv_bitmap & (1ULL << diff)) ? -1 : 0;
}

static void replay_commit(a6_session_t *s, uint64_t counter) {
    if (!s->have_recv) {
        s->have_recv = 1;
        s->recv_max = counter;
        s->recv_bitmap = 1;
        return;
    }
    if (counter > s->recv_max) {
        uint64_t diff = counter - s->recv_max;
        if (diff >= 64) s->recv_bitmap = 0;
        else s->recv_bitmap <<= diff;
        s->recv_bitmap |= 1;
        s->recv_max = counter;
    } else {
        s->recv_bitmap |= 1ULL << (s->recv_max - counter);
    }
}

static size_t transport_padding(a6_session_t *s, size_t packet_size,
                                size_t ip_len, size_t limit) {
    const a6_config_t *cfg = s->cfg;
    if (packet_size > s->udp_window) s->udp_window = packet_size;
    size_t window = s->udp_window < limit ? s->udp_window : limit;
    size_t space = window > packet_size ? window - packet_size : 0;
    if (cfg->content_padding_addition.min || cfg->content_padding_addition.max) {
        size_t add = a6_random_range(cfg->content_padding_addition.min,
                                    cfg->content_padding_addition.max);
        return add < space ? add : space;
    }
    if (cfg->random_trailers) {
        return space ? a6_random_range(0, (uint32_t)(space - 1)) : 0;
    }
    size_t pad = (16 - (ip_len & 15)) & 15;
    return pad < limit - packet_size ? pad : limit - packet_size;
}

int a6_build_transport(a6_session_t *s, const uint8_t *ip, size_t ip_len,
                       uint8_t *out, size_t cap, size_t *out_len) {
    const a6_config_t *cfg;
    size_t offset, packet_size, pad, need;
    uint8_t *header;
    uint8_t nonce[12];
    uint8_t *plain;
    uint64_t counter;

    if (!s || !s->cfg || !out || !out_len) return -1;
    if (!s->established) {
        set_error(s, "tunnel is not established");
        return -1;
    }
    cfg = s->cfg;
    offset = cfg->s[3];
    size_t limit = cfg->mtu + offset + A6_TRANSPORT_HDR_LEN + A6_TAG_LEN;
    if (limit > cap) limit = cap;
    if (ip_len > cfg->mtu || offset + A6_TRANSPORT_HDR_LEN + A6_TAG_LEN > limit ||
        ip_len > limit - offset - A6_TRANSPORT_HDR_LEN - A6_TAG_LEN) return -1;
    packet_size = offset + A6_TRANSPORT_HDR_LEN + ip_len + A6_TAG_LEN;
    pad = transport_padding(s, packet_size, ip_len, limit);
    need = packet_size + pad;
    if (need > cap) {
        set_error(s, "transport packet does not fit in the MTU");
        return -1;
    }

    a6_random(out, offset);
    header = out + offset;
    counter = s->send_counter++;
    a6_store_le32(header, a6_random_range(cfg->h[3].min, cfg->h[3].max));
    a6_store_le32(header + 4, s->remote_index);
    a6_store_le64(header + 8, counter);

    plain = header + A6_TRANSPORT_HDR_LEN;
    if (ip_len) memcpy(plain, ip, ip_len);
    if (pad) memset(plain + ip_len, 0, pad);

    memset(nonce, 0, sizeof nonce);
    a6_store_le64(nonce + 4, counter);
    a6_aead_seal(plain, plain + ip_len + pad, s->send_key, nonce, NULL, 0,
                 plain, ip_len + pad);
    header_protect(cfg, header, A6_TRANSPORT_HDR_LEN, out);

    *out_len = need;
    a6_wipe(nonce, sizeof nonce);
    return 0;
}

int a6_open_transport(a6_session_t *s, const uint8_t *packet, size_t len,
                      uint8_t *ip, size_t cap, size_t *ip_len) {
    const a6_config_t *cfg;
    size_t offset, ct_len, inner_len;
    uint8_t header[A6_TRANSPORT_HDR_LEN];
    uint8_t nonce[12];
    uint64_t counter;
    uint32_t type;

    if (!s || !s->cfg || !packet || !ip || !ip_len) return -1;
    if (!s->established) return -1;
    if (a6_packet_type(s->cfg, packet, len) != 4) return -1;
    cfg = s->cfg;
    offset = cfg->s[3];
    if (len < offset + A6_TRANSPORT_HDR_LEN + A6_TAG_LEN) return -1;

    memcpy(header, packet + offset, sizeof header);
    header_protect(cfg, header, sizeof header, packet);
    type = a6_load_le32(header);
    if (type < cfg->h[3].min || type > cfg->h[3].max) return -1;
    if (a6_load_le32(header + 4) != s->local_index) return -1;
    counter = a6_load_le64(header + 8);
    if (replay_test(s, counter) != 0) return -1;

    ct_len = len - offset - A6_TRANSPORT_HDR_LEN - A6_TAG_LEN;
    if (ct_len > cap) return -1;
    memset(nonce, 0, sizeof nonce);
    a6_store_le64(nonce + 4, counter);
    if (a6_aead_open(ip, s->recv_key, nonce, NULL, 0,
                     packet + offset + A6_TRANSPORT_HDR_LEN, ct_len,
                     packet + len - A6_TAG_LEN) != 0)
        return -1;
    replay_commit(s, counter);
    if (len > s->udp_window) s->udp_window = len;

    if (ct_len == 0 || ip[0] == 0) {
        *ip_len = 0;
        return 0;
    }
    switch (ip[0] >> 4) {
    case 4:
        if (ct_len < 20) return -1;
        inner_len = ((size_t)ip[2] << 8) | ip[3];
        if (inner_len < 20 || inner_len > ct_len) return -1;
        break;
    case 6:
        if (ct_len < 40) return -1;
        inner_len = 40 + (((size_t)ip[4] << 8) | ip[5]);
        if (inner_len > ct_len) return -1;
        break;
    default:
        return -1;
    }
    *ip_len = inner_len;
    return 0;
}

static int parse_decimal(const char *start, const char *end, size_t *out) {
    size_t v = 0;
    if (start == end) return -1;
    while (start < end) {
        if (*start < '0' || *start > '9') return -1;
        if (v > (SIZE_MAX - 9) / 10) return -1;
        v = v * 10 + (size_t)(*start - '0');
        ++start;
    }
    *out = v;
    return 0;
}

static int append_hex(const char *hex, size_t len, uint8_t *out, size_t cap,
                      size_t *pos) {
    size_t i;
    if (len & 1) return -1;
    if (*pos + len / 2 > cap) return -1;
    for (i = 0; i < len; i += 2) {
        unsigned hi, lo;
        char a = hex[i], b = hex[i + 1];
        if (a >= '0' && a <= '9') hi = (unsigned)(a - '0');
        else if (a >= 'a' && a <= 'f') hi = (unsigned)(a - 'a' + 10);
        else if (a >= 'A' && a <= 'F') hi = (unsigned)(a - 'A' + 10);
        else return -1;
        if (b >= '0' && b <= '9') lo = (unsigned)(b - '0');
        else if (b >= 'a' && b <= 'f') lo = (unsigned)(b - 'a' + 10);
        else if (b >= 'A' && b <= 'F') lo = (unsigned)(b - 'A' + 10);
        else return -1;
        out[(*pos)++] = (uint8_t)((hi << 4) | lo);
    }
    return 0;
}

int a6_signature_expand(const char *spec, uint8_t *out, size_t cap,
                        size_t *out_len) {
    const char *p;
    size_t pos = 0;

    if (!spec || !out || !out_len) return -1;
    p = spec;
    while (*p) {
        const char *end;
        const char *body;
        while (*p == ' ' || *p == '\t') ++p;
        if (!*p) break;
        if (*p++ != '<') return -1;
        end = strchr(p, '>');
        if (!end) return -1;
        body = p;
        while (body < end && (*body == ' ' || *body == '\t')) ++body;
        if ((size_t)(end - body) >= 4 && memcmp(body, "b 0x", 4) == 0) {
            if (append_hex(body + 4, (size_t)(end - body - 4), out, cap, &pos) != 0)
                return -1;
        } else if ((size_t)(end - body) == 1 && body[0] == 't') {
            time_t now = time(NULL);
            uint32_t v = (uint32_t)now;
            if (pos + 4 > cap) return -1;
            a6_store_be32(out + pos, v);
            pos += 4;
        } else if ((size_t)(end - body) >= 2 &&
                   (memcmp(body, "r ", 2) == 0 || memcmp(body, "rd", 2) == 0 ||
                    memcmp(body, "rc", 2) == 0)) {
            int kind;
            const char *num = body + 2;
            size_t count;
            if (body[1] == ' ') kind = 1;
            else if (body[1] == 'd') kind = 2;
            else kind = 3;
            if (kind != 1) {
                if (*num == ' ') ++num;
            } else {
                while (*num == ' ') ++num;
            }
            if (parse_decimal(num, end, &count) != 0 || count > cap - pos)
                return -1;
            if (kind == 1) {
                a6_random(out + pos, count);
            } else {
                size_t i;
                static const char letters[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
                for (i = 0; i < count; ++i) {
                    uint32_t r;
                    a6_random_u32(&r);
                    if (kind == 2) out[pos + i] = (uint8_t)('0' + r % 10);
                    else out[pos + i] = (uint8_t)letters[r % (sizeof letters - 1)];
                }
            }
            pos += count;
        } else {
            return -1;
        }
        p = end + 1;
    }
    *out_len = pos;
    return 0;
}
