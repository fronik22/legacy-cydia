#include "../src/config.h"
#include "../src/protocol.h"
#include "../src/crypto.h"
#include "../src/blake2s.h"
#include "cookie_vector.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static const char conf[]="[Interface]\nPrivateKey=AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=\nAddress=10.0.0.2\nContentPaddingAddition=10-20\n[Peer]\nPublicKey=AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI=\nEndpoint=192.0.2.1:443\n";
static void config_test(void){a6_config_t c;char error[256],text[4096];assert(!a6_config_parse(conf,strlen(conf),&c,error,sizeof error));assert(c.content_padding_addition.min==10&&c.content_padding_addition.max==20);
 const char*bad[]={"ContentPaddingAddition=20-10","ContentPaddingAddition=-1","ContentPaddingAddition=65536","S1=4294967295","Jmax=9000","H1=2"};
 for(unsigned i=0;i<sizeof bad/sizeof bad[0];i++){snprintf(text,sizeof text,"[Interface]\n%s\n%s",bad[i],conf+12);assert(a6_config_parse(text,strlen(text),&c,error,sizeof error));}
 snprintf(text,sizeof text,"%s\n[Peer]\nEndpoint=192.0.2.2:443\n",conf);assert(a6_config_parse(text,strlen(text),&c,error,sizeof error));
 char longline[8192];size_t size=strlen(conf);memcpy(longline,conf,size);longline[size++]='#';memset(longline+size,'A',5000);size+=5000;longline[size++]='\n';assert(a6_config_parse(longline,size,&c,error,sizeof error));
 memcpy(text,conf,strlen(conf));text[strlen(conf)]=0;text[strlen(conf)+1]='x';assert(a6_config_parse(text,strlen(conf)+2,&c,error,sizeof error));

}
static void cookie_test(int protect){a6_config_t cfg;char why[256];assert(!a6_config_parse(conf,strlen(conf),&cfg,why,sizeof why));
 if(protect){cfg.has_header_protection=1;memset(cfg.header_protection_key,0x55,32);for(int i=0;i<4;i++)cfg.s[i]=12;}
 a6_session_t s;a6_session_init(&s,&cfg);s.pending.active=1;s.pending.created_ms=a6_now_ms();s.pending.local_index=0x12345678;for(int i=0;i<16;i++)s.pending.mac1[i]=i;
 unsigned char packet[128]={0},saved[128];size_t off=cfg.s[2],n=off+64;memcpy(packet+off,cookie_vector,64);
 if(protect){for(unsigned i=0;i<off;i++)packet[i]=0x23+i;a6_chacha20_xor(packet+off,packet+off,64,cfg.header_protection_key,packet);}
 memcpy(saved,packet,n);assert(a6_consume_cookie(&s,packet,n-1));packet[n-1]^=1;assert(a6_consume_cookie(&s,packet,n));assert(!s.have_cookie);memcpy(packet,saved,n);
 if(!protect)for(size_t i=0;i<n;i++)for(int bit=0;bit<8;bit++){memcpy(packet,saved,n);packet[i]^=1<<bit;assert(a6_consume_cookie(&s,packet,n));assert(!s.have_cookie);}memcpy(packet,saved,n);
 s.pending.local_index^=1;assert(a6_consume_cookie(&s,packet,n));s.pending.local_index^=1;
 assert(!a6_consume_cookie(&s,packet,n));for(int i=0;i<16;i++)assert(s.cookie[i]==0xa0+i);assert(s.have_cookie);assert(a6_consume_cookie(&s,packet,n));
 unsigned char init[2048],msg[148],expected[16];size_t length;assert(!a6_build_initiation(&s,init,sizeof init,&length));memcpy(msg,init+cfg.s[0],148);
 if(protect)a6_chacha20_xor(msg,msg,148,cfg.header_protection_key,init);
 a6_blake2s_keyed(expected,16,s.cookie,16,msg,132);assert(!memcmp(expected,msg+132,16));
 assert(a6_consume_cookie(&s,saved,n)); /* previous sender/MAC1 cannot be reused */
 s.cookie_ms=a6_now_ms()-120001;assert(!a6_build_initiation(&s,init,sizeof init,&length));memcpy(msg,init+cfg.s[0],148);if(protect)a6_chacha20_xor(msg,msg,148,cfg.header_protection_key,init);
 for(int i=132;i<148;i++)assert(!msg[i]);assert(!s.have_cookie);
 s.pending.created_ms=a6_now_ms()-180001;assert(a6_consume_cookie(&s,saved,n));a6_session_wipe(&s);a6_config_wipe(&cfg);
}
static void padding_test(void){a6_config_t c;char why[256];assert(!a6_config_parse(conf,strlen(conf),&c,why,sizeof why));a6_session_t tx,rx;a6_session_init(&tx,&c);a6_session_init(&rx,&c);tx.established=rx.established=1;tx.remote_index=rx.local_index=7;memset(tx.send_key,4,32);memset(rx.recv_key,4,32);
 unsigned char ip[1280]={0x45},wire[2048],out[2048];size_t length,got;ip[3]=100;
 for(int i=0;i<200;i++){assert(!a6_build_transport(&tx,ip,100,wire,sizeof wire,&length));assert(length>=142&&length<=152);assert(!a6_open_transport(&rx,wire,length,out,sizeof out,&got)&&got==100&&!memcmp(ip,out,100));assert(a6_open_transport(&rx,wire,length,out,sizeof out,&got));}
 c.content_padding_addition.min=c.content_padding_addition.max=65535;assert(!a6_build_transport(&tx,ip,100,wire,sizeof wire,&length));assert(length==500);
 ip[2]=5;ip[3]=0;assert(!a6_build_transport(&tx,ip,1280,wire,sizeof wire,&length));assert(length==1312);assert(a6_build_transport(&tx,ip,1280,wire,200,&length));
 c.content_padding_addition.min=c.content_padding_addition.max=0;c.random_trailers=1;assert(!a6_build_transport(&tx,ip,100,wire,sizeof wire,&length));assert(length<=1312);a6_session_wipe(&tx);a6_session_wipe(&rx);
}
int main(void){config_test();cookie_test(0);cookie_test(1);padding_test();puts("Independent cookie vector, MAC2, expiry/replay/bounds, protected challenges, padding ranges/MTU and transport passed");}
