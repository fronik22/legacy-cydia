/* Exercise the actual send error path without changing any routes. */
#define send mock_send
#define a6_route_down mock_route_down
#include "../src/tunnel.c"
#include <assert.h>
static int route_cleanups;
void mock_route_down(const char *iface, const char *endpoint, const char *gateway, int owned) { route_cleanups++; }
ssize_t mock_send(int fd, const void *data, size_t len, int flags) {
    errno = EADDRNOTAVAIL;
    return -1;
}
int main(void) {
    a6_tunnel_t t;
    a6_tunnel_init(&t);
    uint8_t packet[8] = {0};
    assert(send_packet(&t, packet, sizeof packet) == -1);
    assert(strstr(t.error, strerror(EADDRNOTAVAIL)) && strstr(t.error, "errno"));
    t.cfg.jc = 1; t.cfg.jmin = t.cfg.jmax = 16;
    assert(send_handshake(&t) == -1 && strlen(t.error));
    assert(t.handshake_attempts == 1 && t.next_handshake_ms > a6_now_ms());
    strcpy(t.cfg.endpoint_host, "192.0.2.10"); t.cfg.endpoint_port = 443;
    assert(resolve_endpoint(&t) == 0 && !strcmp(t.endpoint_ip, "192.0.2.10"));
    t.routes_up = 1; t.host_route_added = 1;
    cleanup(&t); cleanup(&t);
    assert(route_cleanups == 1 && !t.routes_up && !t.host_route_added);
    puts("UDP send failure preserves a nonempty actionable status error");
}
