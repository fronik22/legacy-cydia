/* Bounded UDP echo test only; does not install routes, DNS or a tunnel. */
#include <arpa/inet.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
int main(int argc,char**argv){if(argc!=3)return 2;struct sockaddr_in a={0};a.sin_len=sizeof a;a.sin_family=AF_INET;a.sin_port=htons(atoi(argv[2]));if(inet_pton(AF_INET,argv[1],&a.sin_addr)!=1)return 2;int fd=socket(AF_INET,SOCK_DGRAM,0);struct timeval timeout={3,0};setsockopt(fd,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof timeout);if(fd<0||connect(fd,(void*)&a,sizeof a))return 2;const char *q="amnezia7-direct-udp-probe";char reply[128];ssize_t n=send(fd,q,strlen(q),0);printf("sent=%ld error=%d\n",(long)n,errno);n=recv(fd,reply,sizeof reply,0);int ok=n==strlen(q)&&!memcmp(q,reply,n);printf("echo=%d bytes=%ld error=%d\n",ok,(long)n,errno);close(fd);return ok?0:1;}
