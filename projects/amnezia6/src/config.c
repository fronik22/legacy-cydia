#include "config.h"

#include "crypto.h"
#include "protocol.h"

#include <arpa/inet.h>
#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static void set_error(char *err, size_t cap, const char *text) {
    if (err && cap) snprintf(err, cap, "%s", text);
}

static char *trim(char *s) {
    char *end;
    while (*s && isspace((unsigned char)*s)) s++;
    end = s + strlen(s);
    while (end > s && isspace((unsigned char)end[-1])) --end;
    *end = 0;
    return s;
}

static int parse_u32(const char *s, uint32_t *out) {
    char *end = NULL;
    unsigned long v;
    if (!s || !*s || !isdigit((unsigned char)*s)) return -1;
    errno = 0;
    v = strtoul(s, &end, 10);
    if (errno || !end || *end || v > 0xffffffffUL) return -1;
    *out = (uint32_t)v;
    return 0;
}

static int parse_range(const char *s, a6_range *out) {
    const char *dash = strchr(s, '-');
    uint32_t a = 0, b = 0;
    char left[32];
    size_t n;
    if (!dash) {
        if (parse_u32(s, &a) != 0) return -1;
        out->min = out->max = a;
        return 0;
    }
    n = (size_t)(dash - s);
    if (n == 0 || n >= sizeof left) return -1;
    memcpy(left, s, n);
    left[n] = 0;
    if (parse_u32(trim(left), &a) != 0 || parse_u32(trim((char *)dash + 1), &b) != 0)
        return -1;
    if (a > b) return -1;
    out->min = a;
    out->max = b;
    return 0;
}

static int parse_bool(const char *s, int *out) {
    if (!strcasecmp(s, "on") || !strcasecmp(s, "yes") ||
        !strcasecmp(s, "true") || !strcmp(s, "1")) {
        *out = 1;
        return 0;
    }
    if (!strcasecmp(s, "off") || !strcasecmp(s, "no") ||
        !strcasecmp(s, "false") || !strcmp(s, "0")) {
        *out = 0;
        return 0;
    }
    return -1;
}

static int parse_key32(const char *s, uint8_t out[32]) {
    size_t n = 0;
    if (a6_base64_decode(s, out, 32, &n) != 0 || n != 32) return -1;
    return 0;
}

static int parse_ipv4(const char *s, char *out, size_t cap) {
    const char *slash;
    size_t n = strcspn(s, "/,");
    struct in_addr a;
    char tmp[64];
    if (n == 0 || n >= sizeof tmp) return -1;
    memcpy(tmp, s, n);
    tmp[n] = 0;
    if (inet_pton(AF_INET, trim(tmp), &a) != 1) return -1;
    if (strlen(tmp) >= cap) return -1;
    snprintf(out, cap, "%s", tmp);
    (void)slash;
    return 0;
}

/* Keep every requested resolver; cfg->dns is a canonical comma-separated list. */
static int parse_dns(const char *value, char *out, size_t capacity) {
    size_t used = strlen(out);const char *p = value;
    while (*p && isspace((unsigned char)*p)) p++;
    if (!*p) return -1;
    for (;;) {
        char token[INET_ADDRSTRLEN];struct in_addr address;size_t n = 0;
        while (p[n] && p[n] != ',' && !isspace((unsigned char)p[n])) n++;
        if (!n || n >= sizeof token) return -1;
        memcpy(token, p, n);token[n] = 0;
        if (inet_pton(AF_INET, token, &address) != 1 || used + n + (used != 0) >= capacity) return -1;
        if (used) out[used++] = ',';
        memcpy(out + used, token, n);used += n;out[used] = 0;p += n;
        while (*p && isspace((unsigned char)*p)) p++;
        if (!*p) return 0;
        if (*p == ',') {p++;while (*p && isspace((unsigned char)*p)) p++;if (!*p) return -1;}
    }
}

static int parse_endpoint(const char *s, char *host, size_t host_cap,
                          uint16_t *port) {
    const char *colon = strrchr(s, ':');
    char h[128];
    size_t n;
    uint32_t p;
    if (!colon || colon == s) return -1;
    n = (size_t)(colon - s);
    if (n >= sizeof h || n >= host_cap) return -1;
    memcpy(h, s, n);
    h[n] = 0;
    if (h[0] == '[' && h[n - 1] == ']') {
        memmove(h, h + 1, n - 2);
        h[n - 2] = 0;
    }
    if (parse_u32(colon + 1, &p) != 0 || p == 0 || p > 65535) return -1;
    snprintf(host, host_cap, "%s", h);
    *port = (uint16_t)p;
    return 0;
}

static void config_defaults(a6_config_t *cfg) {
    memset(cfg, 0, sizeof *cfg);
    cfg->mtu = 1280;
    cfg->persistent_keepalive.min = cfg->persistent_keepalive.max = 25;
    cfg->h[0].min = cfg->h[0].max = 1;
    cfg->h[1].min = cfg->h[1].max = 2;
    cfg->h[2].min = cfg->h[2].max = 3;
    cfg->h[3].min = cfg->h[3].max = 4;
    cfg->rekey_after.min = cfg->rekey_after.max = 120;
    cfg->rekey_timeout.min = cfg->rekey_timeout.max = 5;
    cfg->reject_after.min = cfg->reject_after.max = 180;
    cfg->keepalive_timeout.min = cfg->keepalive_timeout.max = 10;
    cfg->max_handshake_attempts.min = cfg->max_handshake_attempts.max = 18;
}

static int apply_interface(a6_config_t *cfg, const char *key, const char *val,
                           char *err, size_t err_cap) {
    if (!strcasecmp(key, "PrivateKey")) {
        if (parse_key32(val, cfg->private_key) != 0) {
            set_error(err, err_cap, "PrivateKey is not a 32-byte base64 key");
            return -1;
        }
    } else if (!strcasecmp(key, "Address")) {
        if (strchr(val, ':') || strchr(val, ',')) {
            set_error(err, err_cap, "only one IPv4 tunnel Address is supported; IPv6 is not protected");
            return -1;
        }
        if (parse_ipv4(val, cfg->address, sizeof cfg->address) != 0) {
            set_error(err, err_cap, "Address is not an IPv4 address");
            return -1;
        }
    } else if (!strcasecmp(key, "DNS")) {
        if (strchr(val, '$')) {
            set_error(err, err_cap, "unresolved DNS placeholder; import the Amnezia bundle with dns1/dns2 or enter IPv4 DNS values");
            return -1;
        }
        if (strchr(val, ':')) {
            set_error(err, err_cap, "IPv6 DNS is unsupported; use an IPv4 DNS address");
            return -1;
        }
        if (parse_dns(val, cfg->dns, sizeof cfg->dns) != 0) {
            set_error(err, err_cap, "DNS must be an IPv4 address list (comma or space separated, up to 63 characters)");
            return -1;
        }
    } else if (!strcasecmp(key, "MTU")) {
        if (parse_u32(val, &cfg->mtu) != 0 || cfg->mtu < 576 || cfg->mtu > 9000) {
            set_error(err, err_cap, "MTU is invalid");
            return -1;
        }
    } else if (!strcasecmp(key, "Jc")) {
        if (parse_u32(val, &cfg->jc) != 0 || cfg->jc > 128) {
            set_error(err, err_cap, "Jc is invalid");
            return -1;
        }
    } else if (!strcasecmp(key, "Jmin")) {
        if (parse_u32(val, &cfg->jmin) != 0) { set_error(err, err_cap, "Jmin is invalid"); return -1; }
    } else if (!strcasecmp(key, "Jmax")) {
        if (parse_u32(val, &cfg->jmax) != 0) { set_error(err, err_cap, "Jmax is invalid"); return -1; }
    } else if (!strcasecmp(key, "S1")) {
        if (parse_u32(val, &cfg->s[0]) != 0) { set_error(err, err_cap, "S1 is invalid"); return -1; }
    } else if (!strcasecmp(key, "S2")) {
        if (parse_u32(val, &cfg->s[1]) != 0) { set_error(err, err_cap, "S2 is invalid"); return -1; }
    } else if (!strcasecmp(key, "S3")) {
        if (parse_u32(val, &cfg->s[2]) != 0) { set_error(err, err_cap, "S3 is invalid"); return -1; }
    } else if (!strcasecmp(key, "S4")) {
        if (parse_u32(val, &cfg->s[3]) != 0) { set_error(err, err_cap, "S4 is invalid"); return -1; }
    } else if (!strcasecmp(key, "H1")) {
        if (parse_range(val, &cfg->h[0]) != 0) { set_error(err, err_cap, "H1 is invalid"); return -1; }
    } else if (!strcasecmp(key, "H2")) {
        if (parse_range(val, &cfg->h[1]) != 0) { set_error(err, err_cap, "H2 is invalid"); return -1; }
    } else if (!strcasecmp(key, "H3")) {
        if (parse_range(val, &cfg->h[2]) != 0) { set_error(err, err_cap, "H3 is invalid"); return -1; }
    } else if (!strcasecmp(key, "H4")) {
        if (parse_range(val, &cfg->h[3]) != 0) { set_error(err, err_cap, "H4 is invalid"); return -1; }
    } else if (!strcasecmp(key, "HeaderProtectionKey")) {
        if (parse_key32(val, cfg->header_protection_key) != 0) {
            set_error(err, err_cap, "HeaderProtectionKey is not a 32-byte base64 key");
            return -1;
        }
        cfg->has_header_protection = 1;
    } else if (!strcasecmp(key, "ContentPaddingAddition")) {
        if (parse_range(val, &cfg->content_padding_addition) != 0 ||
            cfg->content_padding_addition.max > 65535) {
            set_error(err, err_cap, "ContentPaddingAddition is invalid");
            return -1;
        }
    } else if (!strcasecmp(key, "RandomTrailers")) {
        if (parse_bool(val, &cfg->random_trailers) != 0) {
            set_error(err, err_cap, "RandomTrailers must be on or off");
            return -1;
        }
    } else if (!strcasecmp(key, "DisableCookies")) {
        if (parse_bool(val, &cfg->disable_cookies) != 0) {
            set_error(err, err_cap, "DisableCookies must be on or off");
            return -1;
        }
    } else if (!strcasecmp(key, "RekeyAfterTime")) {
        if (parse_range(val, &cfg->rekey_after) != 0) { set_error(err, err_cap, "RekeyAfterTime is invalid"); return -1; }
    } else if (!strcasecmp(key, "RekeyTimeout")) {
        if (parse_range(val, &cfg->rekey_timeout) != 0) { set_error(err, err_cap, "RekeyTimeout is invalid"); return -1; }
    } else if (!strcasecmp(key, "RejectAfterTime")) {
        if (parse_range(val, &cfg->reject_after) != 0) { set_error(err, err_cap, "RejectAfterTime is invalid"); return -1; }
    } else if (!strcasecmp(key, "KeepaliveTimeout")) {
        if (parse_range(val, &cfg->keepalive_timeout) != 0) { set_error(err, err_cap, "KeepaliveTimeout is invalid"); return -1; }
    } else if (!strcasecmp(key, "MaxHandshakeAttempts")) {
        if (parse_range(val, &cfg->max_handshake_attempts) != 0) { set_error(err, err_cap, "MaxHandshakeAttempts is invalid"); return -1; }
    } else if (key[0] == 'I' && key[1] >= '1' && key[1] <= '5' && key[2] == 0) {
        int idx = key[1] - '1';
        if (strlen(val) >= sizeof cfg->signature[idx]) {
            set_error(err, err_cap, "I packet signature is too long");
            return -1;
        }
        snprintf(cfg->signature[idx], sizeof cfg->signature[idx], "%s", val);
        cfg->signature_present[idx] = 1;
    }
    return 0;
}

static int apply_peer(a6_config_t *cfg, const char *key, const char *val,
                      char *err, size_t err_cap) {
    if (!strcasecmp(key, "PublicKey")) {
        if (parse_key32(val, cfg->peer_public_key) != 0) {
            set_error(err, err_cap, "peer PublicKey is not a 32-byte base64 key");
            return -1;
        }
    } else if (!strcasecmp(key, "PresharedKey")) {
        if (parse_key32(val, cfg->preshared_key) != 0) {
            set_error(err, err_cap, "PresharedKey is not a 32-byte base64 key");
            return -1;
        }
        cfg->has_preshared_key = 1;
    } else if (!strcasecmp(key, "Endpoint")) {
        if (strchr(val, ':') != strrchr(val, ':')) {
            set_error(err, err_cap, "IPv6 Endpoint is unsupported; use an IPv4 host or hostname");
            return -1;
        }
        if (parse_endpoint(val, cfg->endpoint_host, sizeof cfg->endpoint_host,
                           &cfg->endpoint_port) != 0) {
            set_error(err, err_cap, "Endpoint is invalid");
            return -1;
        }
    } else if (!strcasecmp(key, "AllowedIPs")) {
        char copy[512], *remaining, *part; int ipv4_default = 0;
        if (strlen(val) >= sizeof copy) { set_error(err, err_cap, "AllowedIPs is too long"); return -1; }
        snprintf(copy, sizeof copy, "%s", val); remaining = copy;
        while ((part = strsep(&remaining, ",")) != NULL) {
            part = trim(part);
            if (!strcmp(part, "0.0.0.0/0")) ipv4_default = 1;
            else if (strcmp(part, "::/0")) {
                set_error(err, err_cap, "split routes are unsupported; AllowedIPs must include only full defaults");
                return -1;
            }
        }
        /* Common dual-default exports remain usable; this engine tunnels IPv4 only. */
        if (!ipv4_default) { set_error(err, err_cap, "AllowedIPs needs 0.0.0.0/0; IPv6 is not protected"); return -1; }
    } else if (!strcasecmp(key, "PersistentKeepalive")) {
        if (!strcasecmp(val, "off")) cfg->persistent_keepalive.min = cfg->persistent_keepalive.max = 0;
        else if (parse_range(val, &cfg->persistent_keepalive) != 0 || cfg->persistent_keepalive.max > 65535) {
            set_error(err, err_cap, "PersistentKeepalive must be off, 0, or an ordered seconds range up to 65535");
            return -1;
        }
    }
    return 0;
}

static int config_read(FILE *f, a6_config_t *cfg, char *err, size_t err_cap) {
    char line[4096];
    int section = 0; /* 0 none, 1 interface, 2 peer */
    int peers = 0;
    int ok = -1;
    static const uint8_t zero[32] = {0};

    if (err && err_cap) err[0] = 0;
    if (!f || !cfg) {
        set_error(err, err_cap, "no config path");
        return -1;
    }
    config_defaults(cfg);
    /* Check every value first so incomplete templates cannot fail one field at a time. */
    while (fgets(line, sizeof line, f)) {
        char *s = trim(line), *eq;
        if (!*s || *s == '#' || *s == ';') continue;
        eq = strchr(s, '=');
        if (eq && strchr(eq + 1, '$')) {set_error(err, err_cap, "unresolved template placeholder; export a complete client profile");goto done;}
    }
    if (ferror(f) || fseek(f, 0, SEEK_SET)) {set_error(err, err_cap, "cannot preflight configuration");goto done;}

    while (fgets(line, sizeof line, f)) {
        if (!strchr(line, '\n') && !feof(f)) {
            set_error(err, err_cap, "configuration line is too long"); goto done;
        }
        char *s = trim(line);
        char *eq;
        char *key;
        char *val;
        if (!*s || *s == '#' || *s == ';') continue;
        if (*s == '[') {
            if (!strcasecmp(s, "[Interface]")) section = 1;
            else if (!strcasecmp(s, "[Peer]")) {
                if (++peers > 1) { set_error(err, err_cap, "one Peer per profile is supported"); goto done; }
                section = 2;
            }
            else section = 0;
            continue;
        }
        eq = strchr(s, '=');
        if (!eq) continue;
        *eq = 0;
        key = trim(s);
        val = trim(eq + 1);
        if (section == 1) {
            if (apply_interface(cfg, key, val, err, err_cap) != 0) goto done;
        } else if (section == 2) {
            if (apply_peer(cfg, key, val, err, err_cap) != 0) goto done;
        }
    }

    if (memcmp(cfg->private_key, zero, 32) == 0) {
        set_error(err, err_cap, "PrivateKey is missing");
        goto done;
    }
    if (memcmp(cfg->peer_public_key, zero, 32) == 0) {
        set_error(err, err_cap, "peer PublicKey is missing");
        goto done;
    }
    if (!cfg->address[0]) {
        set_error(err, err_cap, "Address is missing");
        goto done;
    }
    if (!cfg->endpoint_host[0] || !cfg->endpoint_port) {
        set_error(err, err_cap, "Endpoint is missing");
        goto done;
    }
    if (cfg->jmin > cfg->jmax || cfg->jmax > A6_MAX_DATAGRAM) {
        set_error(err, err_cap, "Jmin is greater than Jmax");
        goto done;
    }
    static const size_t fixed[4] = {A6_INIT_LEN, A6_RESP_LEN, A6_COOKIE_LEN, 32};
    for (int i = 0; i < 4; i++) {
        if (cfg->s[i] > A6_MAX_DATAGRAM - fixed[i]) {
            set_error(err, err_cap, "S1-S4 exceed the supported datagram size"); goto done;
        }
        for (int j = 0; j < i; j++)
            if (cfg->h[i].min <= cfg->h[j].max && cfg->h[j].min <= cfg->h[i].max) {
                set_error(err, err_cap, "H1-H4 ranges overlap"); goto done;
            }
    }
    if (cfg->mtu > A6_MAX_DATAGRAM - cfg->s[3] - 32) {
        set_error(err, err_cap, "MTU and S4 exceed the supported datagram size"); goto done;
    }
    if (cfg->has_header_protection) {
        int i;
        for (i = 0; i < 4; ++i) {
            if (cfg->s[i] < 12) {
                set_error(err, err_cap, "HeaderProtectionKey needs S1-S4 of at least 12");
                goto done;
            }
        }
    }

    for (int i = 0; i < A6_SIG_COUNT; i++) if (cfg->signature_present[i]) {
        uint8_t packet[A6_MAX_DATAGRAM];size_t size = 0;
        int invalid = a6_signature_expand(cfg->signature[i], packet, sizeof packet, &size);
        a6_wipe(packet, sizeof packet);
        if (invalid) {set_error(err, err_cap, "I1-I5 signature syntax or expanded size is unsupported");goto done;}
    }
    a6_x25519_keypair(cfg->public_key, cfg->private_key);
    ok = 0;

done:
    if (ok != 0) a6_config_wipe(cfg);
    return ok;
}

int a6_config_load(const char *path, a6_config_t *cfg, char *err, size_t err_cap) {
    FILE *f = path ? fopen(path, "r") : NULL;
    if (!f) { set_error(err, err_cap, "cannot open config file"); return -1; }
    int result = config_read(f, cfg, err, err_cap);
    fclose(f);
    return result;
}

int a6_config_parse(const char *text, size_t len, a6_config_t *cfg, char *err, size_t err_cap) {
    if (!text || !len || len > 131072 || memchr(text, 0, len)) {
        set_error(err, err_cap, "configuration is empty, too large or contains NUL"); return -1;
    }
    /* tmpfile is private and unlinked, and exists on the iOS4 libc. */
    FILE *f = tmpfile();
    if (!f) { set_error(err, err_cap, "cannot validate configuration"); return -1; }
    int result = -1;
    if (fwrite(text, 1, len, f) == len && fseek(f, 0, SEEK_SET) == 0)
        result = config_read(f, cfg, err, err_cap);
    else set_error(err, err_cap, "configuration validation I/O failed");
    fclose(f);
    return result;
}

void a6_config_wipe(a6_config_t *cfg) {
    if (cfg) a6_wipe(cfg, sizeof *cfg);
}
