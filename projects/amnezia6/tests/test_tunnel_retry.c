/* Run real tunnel timers with a deterministic clock and no host network changes. */
#define a6_now_ms mock_now
#define send mock_send
#define recv mock_recv
#define read mock_read
#define write mock_write
#define arc4random mock_arc4random
#define socket mock_socket
#define connect mock_connect
#define getsockname mock_getsockname
#define setsockopt mock_setsockopt
#define close mock_close
#define a6_utun_open mock_utun_open
#define a6_route_gateway mock_gateway
#define a6_route_up mock_route_up
#define a6_route_down mock_route_down
#define a6_route_source_available mock_source_available
#define a6_dns_up mock_dns_up
#define a6_dns_down mock_dns_down
#define a6_build_initiation mock_initiation
#define a6_packet_type mock_packet_type
#define a6_consume_response mock_response
#define a6_consume_cookie mock_cookie
#include "../src/tunnel.c"
#include <assert.h>
static uint64_t clock_ms=100000;
static uint8_t incoming[A6_MAX_DATAGRAM];static size_t incoming_len=4;static int tx_ready,rng_calls;
uint32_t mock_arc4random(void){return (++rng_calls&1)?0:UINT32_MAX;}
static int sent,opened,route_ready,fail_send,fail_route,source_present=1,packet_kind=2,cookies,fail_dns;
uint64_t mock_now(void){return clock_ms;}
int mock_socket(int domain,int type,int protocol){opened++;return 100;}
int mock_connect(int fd,const struct sockaddr*a,socklen_t n){assert(route_ready);return 0;}
int mock_getsockname(int fd,struct sockaddr*a,socklen_t*n){struct sockaddr_in*p=(void*)a;memset(p,0,sizeof*p);p->sin_family=AF_INET;inet_pton(AF_INET,"172.21.28.160",&p->sin_addr);return 0;}
int mock_setsockopt(int fd,int level,int opt,const void*value,socklen_t n){return 0;}
int mock_close(int fd){return 0;}
ssize_t mock_send(int fd,const void*p,size_t n,int flags){sent++;if(fail_send){errno=EADDRNOTAVAIL;return -1;}return n;}
ssize_t mock_recv(int fd,void*p,size_t n,int flags){assert(incoming_len<=n);memcpy(p,incoming,incoming_len);return incoming_len;}
ssize_t mock_write(int fd,const void*p,size_t n){return n;}
ssize_t mock_read(int fd,void*p,size_t n){if(!tx_ready)return 0;tx_ready=0;assert(n>=24);memset(p,0,24);uint32_t family=htonl(AF_INET);memcpy(p,&family,4);((uint8_t*)p)[4]=0x45;((uint8_t*)p)[7]=20;return 24;}
int mock_utun_open(char*name,size_t cap){snprintf(name,cap,"utun0");return 101;}
int mock_gateway(const char*endpoint,char*gw,size_t cap){snprintf(gw,cap,"172.21.28.226");return 0;}
int mock_route_up(const char*i,const char*e,const char*g,const char*a,uint32_t mtu,int*owned){route_ready=!fail_route;*owned=route_ready;return fail_route?-1:0;}
void mock_route_down(const char*i,const char*e,const char*g,int owned){route_ready=0;}
int mock_source_available(const char*address){return source_present;}
int mock_dns_up(a6_dns_t*d,const char*i,const char*a,const char*s){return fail_dns?-1:0;}
void mock_dns_down(a6_dns_t*d){}
int mock_initiation(a6_session_t*s,uint8_t*out,size_t cap,size_t*n){s->pending.active=1;memset(out,0,8);*n=8;return 0;}
int mock_packet_type(const a6_config_t*c,const uint8_t*p,size_t n){return packet_kind;}
int mock_cookie(a6_session_t*s,const uint8_t*p,size_t n){cookies++;return 0;}
int mock_response(a6_session_t*s,const uint8_t*p,size_t n){s->pending.active=0;s->established=1;return 0;}
static void start(a6_tunnel_t*t){a6_config_t cfg={0};cfg.mtu=1280;cfg.rekey_after.min=cfg.rekey_after.max=120;cfg.reject_after.min=cfg.reject_after.max=180;cfg.rekey_timeout.min=cfg.rekey_timeout.max=5;cfg.max_handshake_attempts.min=cfg.max_handshake_attempts.max=18;strcpy(cfg.endpoint_host,"192.0.2.10");cfg.endpoint_port=443;strcpy(cfg.address,"10.55.0.5");cfg.jc=0;for(int i=0;i<4;i++)cfg.h[i].min=cfg.h[i].max=i+1;cfg.persistent_keepalive.min=cfg.persistent_keepalive.max=0;a6_tunnel_init(t);char error[192];assert(a6_tunnel_start(t,&cfg,error,sizeof error)==0);}
static void online(a6_tunnel_t*t){a6_tunnel_handle_udp(t);assert(t->state==A6_STATE_CONNECTED);}
static void keepalive_test(void){
 a6_tunnel_t t;clock_ms=100000;packet_kind=2;start(&t);online(&t);
 t.cfg.persistent_keepalive.min=25;t.cfg.persistent_keepalive.max=35;t.cfg.keepalive_timeout.min=t.cfg.keepalive_timeout.max=2;
 for(int i=0;i<100;i++){authenticated_traversal(&t,clock_ms,0);assert(t.persistent_keepalive_at_ms>=clock_ms+25000&&t.persistent_keepalive_at_ms<=clock_ms+35000);}
 assert(timer_deadline(UINT64_MAX-1,65535)==UINT64_MAX);
 t.cfg.persistent_keepalive.max=25;int calls=rng_calls;authenticated_traversal(&t,clock_ms,0);assert(rng_calls==calls&&t.persistent_keepalive_at_ms==clock_ms+25000);t.cfg.persistent_keepalive.max=35;
 t.cfg.max_handshake_attempts.min=15;t.cfg.max_handshake_attempts.max=20;
 for(int i=0;i<10;i++){t.handshake_attempts=0;assert(!send_handshake(&t));assert(t.max_handshake_attempts>=15&&t.max_handshake_attempts<=20);uint32_t limit=t.max_handshake_attempts;assert(!send_handshake(&t)&&t.max_handshake_attempts==limit);}t.session.pending.active=0;
 a6_session_t peer;a6_session_init(&peer,&t.cfg);peer.established=1;peer.remote_index=t.session.local_index;
 uint8_t ip[20]={0x45};ip[3]=20;packet_kind=4;
 assert(!a6_build_transport(&peer,ip,sizeof ip,incoming,sizeof incoming,&incoming_len));clock_ms+=100;a6_tunnel_handle_udp(&t);
 assert(t.keepalive_at_ms==clock_ms+2000);uint64_t reply=t.keepalive_at_ms,persistent=t.persistent_keepalive_at_ms;
 assert(!a6_build_transport(&peer,ip,sizeof ip,incoming,sizeof incoming,&incoming_len));incoming[incoming_len-1]^=1;clock_ms+=100;a6_tunnel_handle_udp(&t);assert(t.keepalive_at_ms==reply&&t.persistent_keepalive_at_ms==persistent);
 incoming[incoming_len-1]^=1;clock_ms+=100;a6_tunnel_handle_udp(&t);assert(t.persistent_keepalive_at_ms>=clock_ms+25000&&t.keepalive_pending_again);
 persistent=t.persistent_keepalive_at_ms;clock_ms+=100;a6_tunnel_handle_udp(&t);assert(t.persistent_keepalive_at_ms==persistent&&t.keepalive_at_ms==reply); /* Replay is not authenticated traversal. */
 assert(!send_keepalive(&t)&&!t.keepalive_at_ms&&!t.keepalive_pending_again);
 t.cfg.content_padding_addition.min=10;t.cfg.content_padding_addition.max=100;
 assert(!a6_build_transport(&peer,NULL,0,incoming,sizeof incoming,&incoming_len)&&incoming_len>32);clock_ms+=100;a6_tunnel_handle_udp(&t);assert(!t.keepalive_at_ms&&t.persistent_keepalive_at_ms>=clock_ms+25000);
 assert(!a6_build_transport(&peer,ip,sizeof ip,incoming,sizeof incoming,&incoming_len));clock_ms+=100;a6_tunnel_handle_udp(&t);assert(t.keepalive_at_ms==clock_ms+2000);
 int before=sent;clock_ms=t.keepalive_at_ms-1;a6_tunnel_timers(&t);assert(sent==before);clock_ms++;a6_tunnel_timers(&t);assert(sent==before+1&&!t.keepalive_at_ms);
 t.keepalive_at_ms=clock_ms+2000;t.keepalive_pending_again=1;tx_ready=1;a6_tunnel_handle_utun(&t);assert(!t.keepalive_at_ms&&!t.keepalive_pending_again&&t.new_handshake_at_ms==clock_ms+7000);
 assert(!a6_build_transport(&peer,NULL,0,incoming,sizeof incoming,&incoming_len));clock_ms++;a6_tunnel_handle_udp(&t);assert(!t.new_handshake_at_ms&&!t.keepalive_at_ms);
 tx_ready=1;a6_tunnel_handle_utun(&t);before=sent;clock_ms=t.new_handshake_at_ms;a6_tunnel_timers(&t);assert(sent==before+1&&t.session.pending.active);packet_kind=2;online(&t);
 t.cfg.persistent_keepalive.min=t.cfg.persistent_keepalive.max=0;authenticated_traversal(&t,clock_ms,0);before=sent;clock_ms+=200;a6_tunnel_timers(&t);assert(!t.persistent_keepalive_at_ms&&sent==before);
 a6_tunnel_stop(&t);a6_session_wipe(&peer);incoming_len=4;packet_kind=2;puts("Keepalive ranges/off/scalars, fast RNG, overflow, authenticated TX/RX, bad tag/replay, padded empty RX, delayed reply/cancel and silence retry passed");
}
int main(void){
 keepalive_test();
 a6_tunnel_t t;start(&t);online(&t);int before=sent;
 uint64_t first_connected=t.connected_ms;
 packet_kind=3;uint64_t retry_deadline=t.next_handshake_ms;a6_tunnel_handle_udp(&t);assert(cookies==1&&sent==before&&t.next_handshake_ms==retry_deadline&&t.connected_ms==first_connected);packet_kind=2;
 t.rx_bytes=123456789;t.tx_bytes=98765;
 clock_ms=t.rekey_at_ms;a6_tunnel_timers(&t);online(&t);
 assert(t.connected_ms==first_connected&&t.rekey_at_ms>clock_ms);
 assert(t.rx_bytes==123456789&&t.tx_bytes==98765); /* rekey preserves the session display */
 before=sent;
 clock_ms=t.rekey_at_ms;fail_send=1;a6_tunnel_timers(&t);
 assert(t.retry_pending&&t.state==A6_STATE_CONNECTING&&!t.session.established&&t.udp_fd==-1&&!t.routes_up);
 assert(strstr(t.error,"errno"));int at_failure=sent;assert(at_failure==before+1);
 for(int i=0;i<100;i++)a6_tunnel_timers(&t);assert(sent==at_failure); /* no5Hz retry flood */
 fail_send=0;clock_ms=t.retry_at_ms;a6_tunnel_timers(&t);assert(!t.retry_pending&&t.udp_fd>=0&&sent==at_failure+1);online(&t);assert(t.retry_delay_seconds==1);
 assert(t.connected_ms==clock_ms&&t.connected_ms>first_connected&&t.rx_bytes==0&&t.tx_bytes==0);
 /* Expired keys are wiped; retry after a missing rekey response succeeds. */
 clock_ms=t.reject_at_ms;a6_tunnel_timers(&t);assert(t.retry_pending&&!t.session.established&&t.state==A6_STATE_CONNECTING);
 clock_ms=t.retry_at_ms;a6_tunnel_timers(&t);online(&t);
 /* Losing the UDP source address rebinds to the new physical network. */
 source_present=0;clock_ms=t.source_check_ms;a6_tunnel_timers(&t);assert(t.retry_pending&&strstr(t.error,"IPv4"));source_present=1;
 clock_ms=t.retry_at_ms;a6_tunnel_timers(&t);online(&t);
 /* An exhausted rekey round waits30seconds, even with pending.active cleared. */
 clock_ms=t.rekey_at_ms;t.session.pending.active=1;t.handshake_attempts=t.max_handshake_attempts;t.next_handshake_ms=clock_ms;
 before=sent;a6_tunnel_timers(&t);assert(!t.session.pending.active&&t.next_handshake_ms==clock_ms+30000);
 for(int i=0;i<20;i++){clock_ms+=200;a6_tunnel_timers(&t);}assert(sent==before);
 clock_ms=t.next_handshake_ms;a6_tunnel_timers(&t);assert(sent==before+1);
 /* Initial interface failure backs off1,2,4,8,16,30seconds without a user retry. */
 a6_tunnel_stop(&t);fail_route=1;start(&t);assert(t.retry_pending&&t.retry_delay_seconds==1);
 unsigned delays[]={2,4,8,16,30,30};
 for(size_t i=0;i<sizeof delays/sizeof delays[0];i++){clock_ms=t.retry_at_ms;a6_tunnel_timers(&t);assert(t.retry_pending&&t.retry_delay_seconds==delays[i]);}
 /* OFF is final: no future timer may recreate the tunnel. */
 before=opened;a6_tunnel_stop(&t);clock_ms+=1000000;a6_tunnel_timers(&t);assert(t.state==A6_STATE_IDLE&&!t.retry_pending&&opened==before);
 fail_route=0;start(&t);t.handshake_attempts=t.max_handshake_attempts;clock_ms=t.next_handshake_ms;a6_tunnel_timers(&t);assert(t.retry_pending&&strstr(t.error,"handshake"));a6_tunnel_stop(&t);
 /* Requested DNS failure must never send a handshake or claim connected. */
 fail_dns=1;start(&t);a6_config_t cfg=t.cfg;a6_tunnel_stop(&t);strcpy(cfg.dns,"192.0.2.53");
 before=sent;char error[192];
 assert(!a6_tunnel_start(&t,&cfg,error,sizeof error));
 assert(t.retry_pending&&t.state==A6_STATE_CONNECTING&&strstr(t.error,"DNS"));
 assert(sent==before&&!t.routes_up&&t.utun_fd==-1&&t.udp_fd==-1);
 fail_dns=0;clock_ms=t.retry_at_ms;a6_tunnel_timers(&t);online(&t);assert(t.dns_up);a6_tunnel_stop(&t);
 puts("Connection timer survives rekey, resets on reconnect; retry, key expiry, source rebinding, backoff and OFF cancellation passed");
}
