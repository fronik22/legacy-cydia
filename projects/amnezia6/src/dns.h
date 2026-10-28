#ifndef AMNEZIA6_DNS_H
#define AMNEZIA6_DNS_H

typedef struct {
    void *store;
    int active;
    char service[64];
} a6_dns_t;

int a6_dns_up(a6_dns_t *dns, const char *ifname, const char *address,
              const char *server);
void a6_dns_down(a6_dns_t *dns);

#endif
