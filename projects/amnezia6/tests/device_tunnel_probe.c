/* Explicit root-only diagnostic; no profile-store writes, no daemon/control lock. */
#include "config.h"
#include "tunnel.h"
#include "../src/route.c"
#include <CoreFoundation/CoreFoundation.h>
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <net/if.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
static void route_snapshot(const char *host) {
 unsigned char buf[512]={0};struct a6_rt_msghdr *h=(void*)buf;struct sockaddr_in *dst=(void*)(buf+sizeof *h);
 dst->sin_len=sizeof *dst;dst->sin_family=AF_INET;if(inet_pton(AF_INET,host,&dst->sin_addr)!=1)return;
 h->rtm_msglen=sizeof *h+sizeof *dst;h->rtm_version=A6_RTM_VERSION;h->rtm_type=A6_RTM_GET;h->rtm_addrs=A6_RTA_DST;h->rtm_pid=getpid();h->rtm_seq=8371;
 int fd=route_socket();if(fd<0)return;ssize_t n=write(fd,buf,h->rtm_msglen)==h->rtm_msglen?route_reply(fd,buf,sizeof buf,8371,A6_RTM_GET):-1;close(fd);
 if(n<(ssize_t)sizeof *h){printf("endpoint_route read_failed=1\n");return;}
 char name[IF_NAMESIZE]={0};if_indextoname(h->rtm_index,name);printf("endpoint_route if=%s flags=%x errno=%d",name,h->rtm_flags,h->rtm_errno);
 unsigned char *q=buf+sizeof *h,*end=buf+n;
 for(int bit=0;bit<32&&q+2<=end;bit++)if(h->rtm_addrs&(1U<<bit)){struct sockaddr *a=(void*)q;size_t len=a->sa_len?a->sa_len:4;if(len>(size_t)(end-q))break;if((1U<<bit)==A6_RTA_GATEWAY){char text[64]={0};if(a->sa_family==AF_INET&&len>=sizeof(struct sockaddr_in))inet_ntop(AF_INET,&((struct sockaddr_in*)a)->sin_addr,text,sizeof text);printf(" gateway_family=%u gateway=%s",a->sa_family,text);}q+=round4(len);}
 puts("");
}
static volatile sig_atomic_t stopping;
static volatile int transfer_done;
static int http_status, dns_reply;
static char dns_server[64];
static int dns_snapshot_available;
static void stop_now(int s){(void)s;stopping=1;}
static int connect_bounded(int fd,struct sockaddr_in *a){
 int flags=fcntl(fd,F_GETFL,0);if(flags<0||fcntl(fd,F_SETFL,flags|O_NONBLOCK)<0)return -1;
 int n=connect(fd,(void*)a,sizeof *a);if(n&&errno!=EINPROGRESS)return -1;
 if(n){struct pollfd p={fd,POLLOUT,0};if(poll(&p,1,5000)<=0)return -1;int error=0;socklen_t len=sizeof error;if(getsockopt(fd,SOL_SOCKET,SO_ERROR,&error,&len)||error)return -1;}
 return fcntl(fd,F_SETFL,flags);
}
static void timeout_socket(int fd){struct timeval t={4,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&t,sizeof t);setsockopt(fd,SOL_SOCKET,SO_SNDTIMEO,&t,sizeof t);}
static void *transfer(void *arg){
 (void)arg;int fd=socket(AF_INET,SOCK_STREAM,0);struct sockaddr_in a={0};a.sin_len=sizeof a;a.sin_family=AF_INET;a.sin_port=htons(80);inet_pton(AF_INET,"1.1.1.1",&a.sin_addr);
 if(fd>=0){timeout_socket(fd);if(!connect_bounded(fd,&a)){const char *request="GET / HTTP/1.1\r\nHost: 1.1.1.1\r\nConnection: close\r\n\r\n";char reply[512]={0};if(write(fd,request,strlen(request))==(ssize_t)strlen(request)&&read(fd,reply,sizeof reply-1)>0)sscanf(reply,"HTTP/%*s %d",&http_status);}close(fd);}
 if(dns_server[0]){
  fd=socket(AF_INET,SOCK_DGRAM,0);a.sin_port=htons(53);inet_pton(AF_INET,dns_server,&a.sin_addr);
  if(fd>=0){timeout_socket(fd);if(!connect(fd,(void*)&a,sizeof a)){unsigned char q[]={0xa6,0x71,1,0,0,1,0,0,0,0,0,0,7,'e','x','a','m','p','l','e',3,'c','o','m',0,0,1,0,1},reply[512];if(send(fd,q,sizeof q,0)==sizeof q){ssize_t n=recv(fd,reply,sizeof reply,0);dns_reply=n>=12&&reply[0]==q[0]&&reply[1]==q[1]&&(reply[2]&0x80)&&!(reply[3]&15);}}close(fd);}
 }
 __sync_synchronize();transfer_done=1;return NULL;
}
static CFPropertyListRef dns_snapshot(void){
 void *h=dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration",RTLD_LAZY);if(!h)return NULL;
 void *(*create)(CFAllocatorRef,CFStringRef,void*,void*)=dlsym(h,"SCDynamicStoreCreate");CFPropertyListRef (*copy)(void*,CFStringRef)=dlsym(h,"SCDynamicStoreCopyValue");
 if(!create||!copy)return NULL;void *s=create(NULL,CFSTR("amnezia probe snapshot"),NULL,NULL);if(!s)return NULL;dns_snapshot_available++;CFPropertyListRef value=copy(s,CFSTR("State:/Network/Global/DNS"));CFRelease(s);return value;
}
int main(int argc,char **argv){
 if((argc!=2&&argc!=3)||geteuid()){fprintf(stderr,"usage: root device_tunnel_probe private-config-path\n");return 2;}
 double limit=argc==3?atof(argv[2]):40;if(limit<1||limit>40)return 2;
 signal(SIGTERM,stop_now);signal(SIGINT,stop_now);signal(SIGALRM,stop_now);signal(SIGPIPE,SIG_IGN);alarm(50);
 a6_config_t cfg;char error[256];if(a6_config_load(argv[1],&cfg,error,sizeof error)){fprintf(stderr,"config rejected: %s\n",error);return 2;}
 snprintf(dns_server,sizeof dns_server,"%s",cfg.dns);char before_gateway[64]={0},after_gateway[64]={0};int before_route=a6_route_gateway(cfg.endpoint_host,before_gateway,sizeof before_gateway);
 route_snapshot(cfg.endpoint_host);
 CFPropertyListRef before_dns=dns_snapshot();a6_tunnel_t t;a6_tunnel_init(&t);a6_tunnel_start(&t,&cfg,error,sizeof error);usleep(200000);route_snapshot(t.endpoint_ip);a6_config_wipe(&cfg);
 double started=CFAbsoluteTimeGetCurrent();int launched=0,connected=0;pthread_t thread;
 while(!stopping&&CFAbsoluteTimeGetCurrent()-started<limit){
  if(t.state==A6_STATE_CONNECTED){connected=1;if(!launched){launched=pthread_create(&thread,NULL,transfer,NULL)==0;if(!launched)break;}}
  if(launched&&transfer_done)break;
  struct pollfd p[2];int count=0,udp=-1,tun=-1;if(t.udp_fd>=0){udp=count;p[count++]=(struct pollfd){t.udp_fd,POLLIN,0};}if(t.utun_fd>=0){tun=count;p[count++]=(struct pollfd){t.utun_fd,POLLIN,0};}
  int wait=a6_tunnel_timeout_ms(&t);if(wait>1000)wait=1000;if(poll(p,count,wait)<0&&errno!=EINTR)break;
  if(udp>=0&&(p[udp].revents&POLLIN))a6_tunnel_handle_udp(&t);if(tun>=0&&(p[tun].revents&POLLIN))a6_tunnel_handle_utun(&t);a6_tunnel_timers(&t);
 }
 if(launched)pthread_join(thread,NULL);char interface[32];snprintf(interface,sizeof interface,"%s",t.ifname);
 printf("connected=%d http_status=%d dns_reply=%d tx_bytes=%llu rx_bytes=%llu tx_packets=%llu rx_packets=%llu attempts=%u error=%s\n",connected,http_status,dns_reply,(unsigned long long)t.tx_bytes,(unsigned long long)t.rx_bytes,(unsigned long long)t.tx_packets,(unsigned long long)t.rx_packets,t.handshake_attempts,t.error);
 a6_tunnel_stop(&t);alarm(0);usleep(500000);int after_route=a6_route_gateway("198.51.100.1",after_gateway,sizeof after_gateway);CFPropertyListRef after_dns=dns_snapshot();
 int dns_restored=dns_snapshot_available==2?((before_dns&&after_dns)?CFEqual(before_dns,after_dns):before_dns==after_dns):-1;int route_restored=before_route==after_route&&!strcmp(before_gateway,after_gateway);int gone=!interface[0]||!if_nametoindex(interface);
 printf("cleanup idle=%d interface_gone=%d default_gateway_restored=%d dns_snapshot_restored=%d\n",t.state==A6_STATE_IDLE,gone,route_restored,dns_restored);if(before_dns)CFRelease(before_dns);if(after_dns)CFRelease(after_dns);
 return connected&&http_status>=100&&dns_reply&&gone&&route_restored&&dns_restored?0:1;
}
