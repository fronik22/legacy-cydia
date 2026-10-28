/*
 * netprobe3 — end-to-end probe for the Amnezia6 tunnel on a jailbroken iPad.
 *
 * Checks, in order:
 *   1. the resolver configuration the system actually uses (res_9_ninit)
 *   2. DNS through the system resolver
 *   3. a full blocking HTTP/1.0 GET of a larger object (exercises MTU / transport)
 *   4. raw DNS against 10.55.0.1 inside the tunnel
 *
 * Build:
 *   clang -target armv7-apple-ios6.0 -isysroot <sdk> -O2 -o netprobe3 netprobe3.c
 */
#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>

typedef void *(*sc_create_fn)(CFAllocatorRef, CFStringRef, void *, void *);
typedef CFPropertyListRef (*sc_copy_fn)(void *, CFStringRef);

static double now_ms(void) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

static void describe_cf(CFTypeRef v, const char *indent) {
    if (!v) {
        printf("%s(null)\n", indent);
        return;
    }
    if (CFGetTypeID(v) == CFStringGetTypeID()) {
        char buf[256];
        CFStringGetCString((CFStringRef)v, buf, sizeof buf, kCFStringEncodingUTF8);
        printf("%s%s\n", indent, buf);
        return;
    }
    if (CFGetTypeID(v) == CFArrayGetTypeID()) {
        CFIndex i, n = CFArrayGetCount((CFArrayRef)v);
        for (i = 0; i < n; ++i)
            describe_cf(CFArrayGetValueAtIndex((CFArrayRef)v, i), indent);
        return;
    }
    if (CFGetTypeID(v) == CFDictionaryGetTypeID()) {
        CFIndex i, n = CFDictionaryGetCount((CFDictionaryRef)v);
        const void **keys = malloc(sizeof(void *) * (size_t)(n ? n : 1));
        const void **vals = malloc(sizeof(void *) * (size_t)(n ? n : 1));
        CFDictionaryGetKeysAndValues((CFDictionaryRef)v, keys, vals);
        for (i = 0; i < n; ++i) {
            char kb[256] = "?";
            if (CFGetTypeID(keys[i]) == CFStringGetTypeID())
                CFStringGetCString((CFStringRef)keys[i], kb, sizeof kb,
                                   kCFStringEncodingUTF8);
            printf("%s%s:\n", indent, kb);
            describe_cf(vals[i], "      ");
        }
        free(keys);
        free(vals);
        return;
    }
    if (CFGetTypeID(v) == CFNumberGetTypeID()) {
        int i = 0;
        CFNumberGetValue((CFNumberRef)v, kCFNumberIntType, &i);
        printf("%s%d\n", indent, i);
        return;
    }
    if (CFGetTypeID(v) == CFBooleanGetTypeID()) {
        printf("%s%s\n", indent, CFBooleanGetValue((CFBooleanRef)v) ? "true" : "false");
        return;
    }
    printf("%s<type %lu>\n", indent, (unsigned long)CFGetTypeID(v));
}

static void show_resolver(void) {
    static const char *keys[] = {
        "State:/Network/Global/DNS",
        "State:/Network/Global/IPv4",
        "State:/Network/Service/com.mak.amnezia6/DNS",
        "State:/Network/Service/com.mak.amnezia6/IPv4",
    };
    void *h = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/"
                     "SystemConfiguration", RTLD_LAZY);
    sc_create_fn create;
    sc_copy_fn copy;
    void *store;
    unsigned i;

    printf("-- dynamic store --\n");
    if (!h) {
        printf("SystemConfiguration: %s\n", dlerror());
        return;
    }
    create = (sc_create_fn)dlsym(h, "SCDynamicStoreCreate");
    copy = (sc_copy_fn)dlsym(h, "SCDynamicStoreCopyValue");
    if (!create || !copy) {
        printf("SCDynamicStore symbols missing\n");
        return;
    }
    store = create(NULL, CFSTR("netprobe3"), NULL, NULL);
    if (!store) {
        printf("store create failed\n");
        return;
    }
    for (i = 0; i < sizeof keys / sizeof keys[0]; ++i) {
        CFStringRef k = CFStringCreateWithCString(NULL, keys[i], kCFStringEncodingUTF8);
        CFPropertyListRef v = copy(store, k);
        printf("%s:\n", keys[i]);
        describe_cf(v, "    ");
        if (v) CFRelease(v);
        CFRelease(k);
    }
    CFRelease((CFTypeRef)store);
}

static int connect_host(const char *name, int port, char *ip_out, size_t ip_cap,
                        double *elapsed) {
    struct addrinfo hints, *res = NULL;
    char portstr[16];
    int fd = -1;
    double t0 = now_ms();

    snprintf(portstr, sizeof portstr, "%d", port);
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo(name, portstr, &hints, &res) != 0 || !res) {
        if (elapsed) *elapsed = now_ms() - t0;
        return -1;
    }
    if (ip_out) {
        inet_ntop(AF_INET,
                  &((struct sockaddr_in *)res->ai_addr)->sin_addr, ip_out, ip_cap);
    }
    fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd >= 0 && connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
        close(fd);
        fd = -1;
    }
    freeaddrinfo(res);
    if (elapsed) *elapsed = now_ms() - t0;
    return fd;
}

static void http_get(const char *host, const char *path, int expect_min) {
    char ip[INET_ADDRSTRLEN] = "-";
    double ms = 0;
    int fd = connect_host(host, 80, ip, sizeof ip, &ms);
    char req[512];
    char buf[8192];
    size_t total = 0;
    int status = -1;
    double t0;

    if (fd < 0) {
        printf("http %s -> connect failed errno=%d (%s) (%.0f ms)\n", host, errno,
               strerror(errno), ms);
        return;
    }
    printf("http %s (%s) -> connected (%.0f ms)\n", host, ip, ms);
    snprintf(req, sizeof req,
             "GET %s HTTP/1.0\r\nHost: %s\r\nUser-Agent: amnezia6-probe\r\n"
             "Connection: close\r\n\r\n",
             path, host);
    if (write(fd, req, strlen(req)) != (ssize_t)strlen(req)) {
        printf("  write failed errno=%d\n", errno);
        close(fd);
        return;
    }
    t0 = now_ms();
    for (;;) {
        ssize_t n = read(fd, buf, sizeof buf);
        if (n > 0) {
            if (total == 0 && (size_t)n > 5 && !strncmp(buf, "HTTP/", 5)) {
                status = atoi(buf + 9);
            }
            total += (size_t)n;
            if (total > (size_t)expect_min + 65536) break;
            continue;
        }
        if (n < 0 && errno == EINTR) continue;
        break;
    }
    close(fd);
    printf("  status=%d body_bytes=%lu time=%.0f ms -> %s\n", status,
           (unsigned long)total, now_ms() - t0,
           (status == 200 && total > 100) ? "PASS" : "CHECK");
}

static void udp_dns_probe(const char *server, const char *qname,
                          const char *qtype_name, unsigned short qtype) {
    unsigned char q[512];
    unsigned char a[512];
    struct sockaddr_in sin;
    struct timeval tv;
    double t0;
    int fd, n;
    size_t off = 12;
    const char *p;
    int ancount;

    memset(&sin, 0, sizeof sin);
    sin.sin_len = sizeof sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons(53);
    if (inet_pton(AF_INET, server, &sin.sin_addr) != 1) {
        printf("udp dns %s: bad address\n", server);
        return;
    }
    memset(q, 0, sizeof q);
    q[0] = 0x12;
    q[1] = 0x34;
    q[2] = 0x01;
    q[5] = 0x01;
    for (p = qname; *p;) {
        const char *dot = strchr(p, '.');
        size_t len = dot ? (size_t)(dot - p) : strlen(p);
        q[off++] = (unsigned char)len;
        memcpy(q + off, p, len);
        off += len;
        if (!dot) break;
        p = dot + 1;
    }
    q[off++] = 0;
    q[off++] = (unsigned char)(qtype >> 8);
    q[off++] = (unsigned char)(qtype & 0xff);
    q[off++] = 0;
    q[off++] = 1;

    fd = socket(AF_INET, SOCK_DGRAM, 0);
    tv.tv_sec = 4;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    t0 = now_ms();
    sendto(fd, q, off, 0, (struct sockaddr *)&sin, sizeof sin);
    n = (int)recv(fd, a, sizeof a, 0);
    printf("udp dns %s (%s) -> recv=%d errno=%d (%.0f ms)", server, qtype_name, n,
           errno, now_ms() - t0);
    if (n >= 12) {
        ancount = (a[6] << 8) | a[7];
        printf(" ancount=%d", ancount);
        if (qtype == 1 && ancount > 0) {
            size_t i;
            for (i = 12; i + 16 <= (size_t)n; ++i) {
                if (a[i] == 0xc0 && a[i + 1] == 0x0c && a[i + 2] == 0x00 &&
                    a[i + 3] == 0x01) {
                    char ip[INET_ADDRSTRLEN];
                    struct in_addr in;
                    memcpy(&in, a + i + 12, 4);
                    inet_ntop(AF_INET, &in, ip, sizeof ip);
                    printf(" first=%s", ip);
                    break;
                }
            }
        }
    }
    printf("\n");
    close(fd);
}

int main(void) {
    int i;
    printf("== netprobe3 ==\n");
    show_resolver();

    printf("-- system resolver --\n");
    for (i = 0; i < 3; ++i) {
        char ip[INET_ADDRSTRLEN] = "-";
        double ms = 0;
        int fd = connect_host("example.com", 80, ip, sizeof ip, &ms);
        printf("example.com -> %s (%s) %.0f ms\n", fd >= 0 ? "ok" : "fail", ip, ms);
        if (fd >= 0) close(fd);
    }

    printf("-- in-tunnel dns --\n");
    udp_dns_probe("10.55.0.1", "example.com", "A", 1);
    udp_dns_probe("10.55.0.1", "ya.ru", "A", 1);

    printf("-- http through tunnel --\n");
    http_get("example.com", "/", 1000);
    http_get("info.cern.ch", "/", 1000);

    printf("== done ==\n");
    return 0;
}
