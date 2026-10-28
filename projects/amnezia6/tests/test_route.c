/* Mock kernel routing calls: these tests never change host routes. */
#define socket mock_socket
#define read mock_read
#define write mock_write
#define close mock_close
#define ioctl mock_ioctl
#define if_nametoindex mock_if_nametoindex
#define getifaddrs mock_getifaddrs
#define freeifaddrs mock_freeifaddrs
#include "../src/route.c"
#include <assert.h>

static unsigned char request[512];
static int existing_host, host_deletes, net_deletes, fail_network;
static int broadcast_next, broadcasts_ignored, nonstatic_host, fail_replacement, short_default;
static const char *default_gateway = "172.21.28.226";
static char existing_gateway[64] = "192.168.1.254";

int mock_socket(int domain, int type, int protocol) { return 999; }
int mock_close(int fd) { return 0; }
int mock_ioctl(int fd, unsigned long request, ...) { return 0; }
unsigned mock_if_nametoindex(const char *name) { return 10; }
int mock_getifaddrs(struct ifaddrs **out) {
    static struct ifaddrs a;
    static struct sockaddr_in ip, mask;
    memset(&a, 0, sizeof a); memset(&ip, 0, sizeof ip); memset(&mask, 0, sizeof mask);
    a.ifa_flags = IFF_UP; a.ifa_addr = (void *)&ip; a.ifa_netmask = (void *)&mask;
    ip.sin_family = mask.sin_family = AF_INET;
    inet_pton(AF_INET, "172.21.28.160", &ip.sin_addr);
    inet_pton(AF_INET, "255.255.255.0", &mask.sin_addr);
    *out = &a; return 0;
}
void mock_freeifaddrs(struct ifaddrs *a) {}
ssize_t mock_write(int fd, const void *buf, size_t n) {
    assert(n <= sizeof request); memcpy(request, buf, n); broadcast_next = 1; return n;
}
ssize_t mock_read(int fd, void *out, size_t cap) {
    if (broadcast_next) {
        struct a6_rt_msghdr other = {0};
        other.rtm_msglen = sizeof other; other.rtm_pid = getpid() + 1;
        memcpy(out, &other, sizeof other); broadcast_next = 0; broadcasts_ignored++;
        return sizeof other;
    }
    struct a6_rt_msghdr *h = (void *)request;
    struct sockaddr_in *destination = (void *)(request + sizeof *h);
    struct sockaddr_in *gw = destination + 1;
    if (h->rtm_type == A6_RTM_GET) {
        int is_default = destination->sin_addr.s_addr == 0;
        h->rtm_addrs = A6_RTA_DST | A6_RTA_GATEWAY;
        h->rtm_flags = is_default ? A6_RTF_GATEWAY : A6_RTF_HOST | (nonstatic_host ? 0 : A6_RTF_STATIC);
        memset(gw, 0, sizeof *gw); gw->sin_len = sizeof *gw; gw->sin_family = AF_INET;
        inet_pton(AF_INET, is_default ? default_gateway : existing_gateway, &gw->sin_addr);
        h->rtm_msglen = sizeof *h + sizeof *destination + sizeof *gw;
        if (short_default && is_default) {
            memmove((char *)destination + 4, gw, sizeof *gw);
            memset(destination, 0, 4); h->rtm_msglen = sizeof *h + 4 + sizeof *gw;
        }
    } else {
        int host = !!(h->rtm_flags & A6_RTF_HOST);
        h->rtm_errno = 0;
        if (h->rtm_type == A6_RTM_ADD) {
            if (host && existing_host) h->rtm_errno = EEXIST;
            else if (host && fail_replacement && gw->sin_addr.s_addr == inet_addr(default_gateway)) h->rtm_errno = ENETUNREACH;
            else if (!host && fail_network) h->rtm_errno = EEXIST;
            else if (host) { existing_host = 1; inet_ntop(AF_INET, &gw->sin_addr, existing_gateway, sizeof existing_gateway); }
        }
        if (h->rtm_type == A6_RTM_DELETE) {
            if (host) { assert(existing_host); existing_host = 0; host_deletes++; }
            else net_deletes++;
        }
    }
    assert(h->rtm_msglen <= cap); memcpy(out, request, h->rtm_msglen); return h->rtm_msglen;
}
int main(void) {
    const char *endpoint = "198.51.100.17"; int owned; char gateway[64];
    assert(a6_route_source_available("172.21.28.160") == 1);
    assert(a6_route_source_available("192.168.1.76") == 0);
    assert(sizeof(struct a6_rt_msghdr) == 92);
    short_default = 1;
    assert(a6_route_gateway(endpoint, gateway, sizeof gateway) == 0 && !strcmp(gateway, default_gateway));
    short_default = 0;
    existing_host = 1;
    assert(a6_route_gateway(endpoint, gateway, sizeof gateway) == 0);
    assert(!strcmp(gateway, default_gateway)); /* stale endpoint must NEVER select the old LAN */
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == 0);
    assert(owned == 1 && host_deletes == 1 && !strcmp(existing_gateway, default_gateway));
    a6_route_down("utun0", endpoint, default_gateway, owned);
    assert(!existing_host && host_deletes == 2 && net_deletes == 2);
    /* A valid pre-existing endpoint route remains foreign, including on rollback. */
    existing_host = 1; strcpy(existing_gateway, default_gateway);
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == 0 && !owned);
    a6_route_down("utun0", endpoint, default_gateway, owned);
    assert(existing_host && host_deletes == 2);
    fail_network = 1;
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == -1);
    assert(existing_host && host_deletes == 2); fail_network = 0;
    /* A different but reachable policy gateway must not be replaced. */
    strcpy(existing_gateway, "172.21.28.2");
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == -1);
    assert(existing_host && host_deletes == 2);
    strcpy(existing_gateway, "192.168.1.254"); nonstatic_host = 1;
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == -1);
    assert(existing_host && host_deletes == 2); nonstatic_host = 0;
    /* A failed replacement restores the old entry instead of discarding it. */
    fail_replacement = 1;
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == -1);
    assert(existing_host && !strcmp(existing_gateway, "192.168.1.254") && !owned);
    fail_replacement = 0; existing_host = 0;
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == 0 && owned);
    a6_route_down("utun0", endpoint, default_gateway, owned);
    fail_network = 1;
    assert(a6_route_up("utun0", endpoint, default_gateway, "10.55.0.5", 1280, &owned) == -1);
    assert(!existing_host && !owned);
    assert(broadcasts_ignored > 0);
    puts("Fresh gateway, stale static rescue, policy preservation, ownership and rollback passed");
}
