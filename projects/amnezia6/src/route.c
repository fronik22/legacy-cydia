/*
 * IPv4 interface and route setup for iOS.
 *
 * The PF_ROUTE message layout follows the approach used by Senko's
 * awg_pfroute.c (GPLv2), adapted for Amnezia6. The iOS SDK does not
 * ship <net/route.h>, so the ABI structures are defined here.
 */

#include "route.h"

#include <arpa/inet.h>
#include <errno.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/sockio.h>
#include <sys/time.h>
#include <unistd.h>

#ifndef AF_ROUTE
#define AF_ROUTE 17
#endif
#ifndef AF_LINK
#define AF_LINK 18
#endif

#define A6_RTM_VERSION 5
#define A6_RTM_ADD 1
#define A6_RTM_DELETE 2
#define A6_RTM_GET 4
#define A6_RTA_DST 0x1
#define A6_RTA_GATEWAY 0x2
#define A6_RTA_NETMASK 0x4
#define A6_RTF_UP 0x1
#define A6_RTF_GATEWAY 0x2
#define A6_RTF_HOST 0x4
#define A6_RTF_STATIC 0x800

struct a6_rt_metrics {
    unsigned int values[14];
};

struct a6_rt_msghdr {
    unsigned short rtm_msglen;
    unsigned char rtm_version;
    unsigned char rtm_type;
    unsigned short rtm_index;
    int rtm_flags;
    int rtm_addrs;
    int rtm_pid;
    int rtm_seq;
    int rtm_errno;
    int rtm_use;
    unsigned int rtm_inits;
    struct a6_rt_metrics rtm_rmx;
};

static size_t round4(size_t n) {
    return (n + 3) & ~(size_t)3;
}

static int route_socket(void) {
    int fd = socket(AF_ROUTE, SOCK_RAW, 0);
    struct timeval timeout = {2, 0};
    if (fd >= 0) setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof timeout);
    return fd;
}

/* Routing sockets also receive configd broadcasts while interfaces change. */
static ssize_t route_reply(int fd, void *buf, size_t cap, int seq, int type) {
    for (;;) {
        ssize_t got = read(fd, buf, cap);
        if (got < 0 && errno == EINTR) continue;
        if (got < (ssize_t)sizeof(struct a6_rt_msghdr)) return -1;
        struct a6_rt_msghdr *hdr = buf;
        if (hdr->rtm_pid == getpid() && hdr->rtm_seq == seq && hdr->rtm_type == type)
            return got;
    }
}

static int route_get_gateway(const char *destination, char *gateway, size_t cap, int *static_host) {
    uint8_t buf[512];
    struct a6_rt_msghdr *hdr = (struct a6_rt_msghdr *)buf;
    struct sockaddr_in *dst = (struct sockaddr_in *)(buf + sizeof *hdr);
    int fd;
    ssize_t got;
    const uint8_t *p;
    const uint8_t *end;
    int bit, found_gateway = 0, exact_destination = 0;
    struct in_addr requested;
    if (static_host) *static_host = 0;

    memset(buf, 0, sizeof buf);
    dst->sin_len = sizeof *dst;
    dst->sin_family = AF_INET;
    if (inet_pton(AF_INET, destination, &dst->sin_addr) != 1) return -1;
    requested = dst->sin_addr;
    hdr->rtm_msglen = (unsigned short)(sizeof *hdr + sizeof *dst);
    hdr->rtm_version = A6_RTM_VERSION;
    hdr->rtm_type = A6_RTM_GET;
    hdr->rtm_addrs = A6_RTA_DST;
    hdr->rtm_pid = getpid();
    hdr->rtm_seq = 1;

    fd = route_socket();
    if (fd < 0) return -1;
    if (write(fd, buf, hdr->rtm_msglen) != hdr->rtm_msglen) {
        close(fd);
        return -1;
    }
    got = route_reply(fd, buf, sizeof buf, 1, A6_RTM_GET);
    close(fd);
    if (got < (ssize_t)sizeof *hdr) return -1;
    hdr = (struct a6_rt_msghdr *)buf;
    if (hdr->rtm_errno || hdr->rtm_msglen > (unsigned)got) return -1;

    p = buf + sizeof *hdr;
    end = buf + hdr->rtm_msglen;
    for (bit = 0; bit < 32 && p < end; ++bit) {
        const struct sockaddr *sa = (const struct sockaddr *)p;
        size_t len;
        if (!(hdr->rtm_addrs & (1U << bit))) continue;
        if (end - p < 2) return -1;
        /* Darwin routing sockaddrs keep 32-bit padding on arm64 too. */
        len = sa->sa_len ? sa->sa_len : 4;
        if (len > (size_t)(end - p)) return -1;
        if ((1U << bit) == A6_RTA_DST && sa->sa_family == AF_INET &&
            len >= sizeof(struct sockaddr_in))
            exact_destination = ((const struct sockaddr_in *)sa)->sin_addr.s_addr == requested.s_addr;
        if ((1U << bit) == A6_RTA_GATEWAY) {
            if (sa->sa_family != AF_INET || len < sizeof(struct sockaddr_in))
                return -1;
            found_gateway = inet_ntop(AF_INET, &((const struct sockaddr_in *)sa)->sin_addr,
                                      gateway, (socklen_t)cap) != NULL;
        }
        p += round4(len);
    }
    if (static_host) *static_host = exact_destination &&
        (hdr->rtm_flags & (A6_RTF_HOST | A6_RTF_STATIC)) == (A6_RTF_HOST | A6_RTF_STATIC);
    return found_gateway ? 0 : -1;
}

/* A gateway from a departed LAN must not pin the endpoint to that LAN. */
static int gateway_on_link(const char *gateway) {
    struct in_addr gw;
    struct ifaddrs *list = NULL;
    int reachable = 0;
    if (inet_pton(AF_INET, gateway, &gw) != 1 || getifaddrs(&list) != 0) return -1;
    for (struct ifaddrs *p = list; p; p = p->ifa_next) {
        if (!p->ifa_addr || !p->ifa_netmask || p->ifa_addr->sa_family != AF_INET ||
            !(p->ifa_flags & IFF_UP) || (p->ifa_flags & (IFF_POINTOPOINT | IFF_LOOPBACK))) continue;
        uint32_t ip = ((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr;
        uint32_t mask = ((struct sockaddr_in *)p->ifa_netmask)->sin_addr.s_addr;
        if (mask && (gw.s_addr & mask) == (ip & mask)) { reachable = 1; break; }
    }
    freeifaddrs(list);
    return reachable;
}

static int route_write(int type, int flags, int addrs,
                       const void *dst, size_t dst_len,
                       const void *gw, size_t gw_len,
                       const void *mask, size_t mask_len) {
    uint8_t buf[512];
    struct a6_rt_msghdr *hdr = (struct a6_rt_msghdr *)buf;
    uint8_t *p = buf + sizeof *hdr;
    int fd;
    ssize_t got;

    memset(buf, 0, sizeof buf);
    if (dst_len) { memcpy(p, dst, dst_len); p += dst_len; }
    if (gw_len) { memcpy(p, gw, gw_len); p += gw_len; }
    if (mask_len) { memcpy(p, mask, mask_len); p += mask_len; }
    hdr->rtm_msglen = (unsigned short)(p - buf);
    hdr->rtm_version = A6_RTM_VERSION;
    hdr->rtm_type = (unsigned char)type;
    hdr->rtm_flags = flags;
    hdr->rtm_addrs = addrs;
    hdr->rtm_pid = getpid();
    hdr->rtm_seq = 3;

    fd = route_socket();
    if (fd < 0) return -1;
    if (write(fd, buf, hdr->rtm_msglen) != hdr->rtm_msglen) {
        close(fd);
        return -1;
    }
    got = route_reply(fd, buf, sizeof buf, 3, type);
    close(fd);
    if (got < (ssize_t)sizeof *hdr) return -1;
    errno = ((struct a6_rt_msghdr *)buf)->rtm_errno;
    return errno ? -1 : 0;
}

static int route_host(int add, const char *destination, const char *gateway) {
    struct sockaddr_in dst, gw;
    memset(&dst, 0, sizeof dst);
    memset(&gw, 0, sizeof gw);
    dst.sin_len = sizeof dst;
    dst.sin_family = AF_INET;
    gw.sin_len = sizeof gw;
    gw.sin_family = AF_INET;
    if (inet_pton(AF_INET, destination, &dst.sin_addr) != 1 ||
        inet_pton(AF_INET, gateway, &gw.sin_addr) != 1)
        return -1;
    return route_write(add ? A6_RTM_ADD : A6_RTM_DELETE,
                       A6_RTF_UP | A6_RTF_GATEWAY | A6_RTF_HOST | A6_RTF_STATIC,
                       A6_RTA_DST | A6_RTA_GATEWAY,
                       &dst, sizeof dst, &gw, sizeof gw, NULL, 0);
}

static int route_net_if(int add, const char *network, const char *netmask,
                        const char *ifname) {
    struct sockaddr_in dst, mask;
    uint8_t gw[8];
    unsigned int index = if_nametoindex(ifname);
    if (!index || index > 0xffff) return -1;
    memset(&dst, 0, sizeof dst);
    memset(&mask, 0, sizeof mask);
    memset(gw, 0, sizeof gw);
    dst.sin_len = sizeof dst;
    dst.sin_family = AF_INET;
    mask.sin_len = sizeof mask;
    mask.sin_family = AF_INET;
    if (inet_pton(AF_INET, network, &dst.sin_addr) != 1 ||
        inet_pton(AF_INET, netmask, &mask.sin_addr) != 1)
        return -1;
    gw[0] = 8;
    gw[1] = AF_LINK;
    gw[2] = (uint8_t)index;
    gw[3] = (uint8_t)(index >> 8);
    return route_write(add ? A6_RTM_ADD : A6_RTM_DELETE,
                       A6_RTF_UP | A6_RTF_STATIC,
                       A6_RTA_DST | A6_RTA_GATEWAY | A6_RTA_NETMASK,
                       &dst, sizeof dst, gw, sizeof gw, &mask, sizeof mask);
}

static int set_addr4(int fd, const char *ifname, const char *ip, unsigned long req) {
    struct ifreq ifr;
    struct sockaddr_in *sin;
    memset(&ifr, 0, sizeof ifr);
    snprintf(ifr.ifr_name, sizeof ifr.ifr_name, "%s", ifname);
    sin = (struct sockaddr_in *)&ifr.ifr_addr;
    sin->sin_len = sizeof *sin;
    sin->sin_family = AF_INET;
    if (inet_pton(AF_INET, ip, &sin->sin_addr) != 1) return -1;
    return ioctl(fd, req, &ifr);
}

static int interface_up(const char *ifname, const char *address, uint32_t mtu) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    int ok;
    struct ifreq ifr;
    if (fd < 0) return -1;
    ok = set_addr4(fd, ifname, address, SIOCSIFADDR) == 0 &&
         set_addr4(fd, ifname, address, SIOCSIFDSTADDR) == 0;
    if (ok) {
        memset(&ifr, 0, sizeof ifr);
        snprintf(ifr.ifr_name, sizeof ifr.ifr_name, "%s", ifname);
        ((struct sockaddr_in *)&ifr.ifr_addr)->sin_len = sizeof(struct sockaddr_in);
        ((struct sockaddr_in *)&ifr.ifr_addr)->sin_family = AF_INET;
        ((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr = htonl(0xffffffffU);
        ok = ioctl(fd, SIOCSIFNETMASK, &ifr) == 0;
    }
    if (ok) {
        memset(&ifr, 0, sizeof ifr);
        snprintf(ifr.ifr_name, sizeof ifr.ifr_name, "%s", ifname);
        ok = ioctl(fd, SIOCGIFFLAGS, &ifr) == 0;
        if (ok) {
            ifr.ifr_flags |= IFF_UP | IFF_RUNNING;
            ok = ioctl(fd, SIOCSIFFLAGS, &ifr) == 0;
        }
    }
    if (ok) {
        memset(&ifr, 0, sizeof ifr);
        snprintf(ifr.ifr_name, sizeof ifr.ifr_name, "%s", ifname);
        ifr.ifr_mtu = (int)mtu;
        ok = ioctl(fd, SIOCSIFMTU, &ifr) == 0;
    }
    close(fd);
    return ok ? 0 : -1;
}

static void interface_down(const char *ifname) {
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    struct ifreq ifr;
    if (fd < 0) return;
    memset(&ifr, 0, sizeof ifr);
    snprintf(ifr.ifr_name, sizeof ifr.ifr_name, "%s", ifname);
    if (ioctl(fd, SIOCGIFFLAGS, &ifr) == 0) {
        ifr.ifr_flags &= (short)~IFF_UP;
        (void)ioctl(fd, SIOCSIFFLAGS, &ifr);
    }
    close(fd);
}

int a6_route_source_available(const char *address) {
    struct in_addr source;
    struct ifaddrs *list = NULL;
    int found = 0;
    if (inet_pton(AF_INET, address, &source) != 1 || getifaddrs(&list) != 0) return -1;
    for (struct ifaddrs *p = list; p; p = p->ifa_next) {
        if (p->ifa_addr && p->ifa_addr->sa_family == AF_INET && (p->ifa_flags & IFF_UP) &&
            ((struct sockaddr_in *)p->ifa_addr)->sin_addr.s_addr == source.s_addr) {
            found = 1;
            break;
        }
    }
    freeifaddrs(list);
    return found;
}

int a6_route_gateway(const char *endpoint, char *gateway, size_t cap) {
    /* The endpoint may retain a static host route from a previous Wi-Fi LAN. */
    return route_get_gateway("0.0.0.0", gateway, cap, NULL);
}

int a6_route_up(const char *ifname, const char *endpoint, const char *gateway,
                const char *address, uint32_t mtu, int *host_added) {
    int first_added = 0;
    *host_added = 0;
    if (interface_up(ifname, address, mtu) != 0) return -1;
    if (route_host(1, endpoint, gateway) == 0) {
        *host_added = 1;
    } else {
        char existing_gateway[64];
        int static_host = 0;
        if (errno != EEXIST ||
            route_get_gateway(endpoint, existing_gateway, sizeof existing_gateway, &static_host) != 0) goto fail;
        if (strcmp(existing_gateway, gateway) != 0) {
            /* Preserve live foreign routes; rescue only an exact, unusable static host route. */
            if (!static_host || gateway_on_link(existing_gateway) != 0 ||
                gateway_on_link(gateway) != 1 ||
                route_host(0, endpoint, existing_gateway) != 0) goto fail;
            if (route_host(1, endpoint, gateway) != 0) {
                (void)route_host(1, endpoint, existing_gateway);
                goto fail;
            }
            *host_added = 1;
        }
    }
    if (route_net_if(1, "0.0.0.0", "128.0.0.0", ifname) != 0) goto fail;
    first_added = 1;
    if (route_net_if(1, "128.0.0.0", "128.0.0.0", ifname) != 0) goto fail;
    return 0;

fail:
    if (first_added) (void)route_net_if(0, "0.0.0.0", "128.0.0.0", ifname);
    if (*host_added) (void)route_host(0, endpoint, gateway);
    *host_added = 0;
    interface_down(ifname);
    return -1;
}

void a6_route_down(const char *ifname, const char *endpoint,
                   const char *gateway, int host_added) {
    (void)route_net_if(0, "128.0.0.0", "128.0.0.0", ifname);
    (void)route_net_if(0, "0.0.0.0", "128.0.0.0", ifname);
    if (host_added) (void)route_host(0, endpoint, gateway);
    interface_down(ifname);
}
