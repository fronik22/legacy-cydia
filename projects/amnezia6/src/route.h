#ifndef AMNEZIA6_ROUTE_H
#define AMNEZIA6_ROUTE_H

#include <stddef.h>
#include <stdint.h>

/* 1 present, 0 departed, -1 unknown. Does not modify routes. */
int a6_route_source_available(const char *address);

int a6_route_gateway(const char *endpoint, char *gateway, size_t cap);
int a6_route_up(const char *ifname, const char *endpoint, const char *gateway,
                const char *address, uint32_t mtu, int *host_added);
void a6_route_down(const char *ifname, const char *endpoint,
                   const char *gateway, int host_added);

#endif
