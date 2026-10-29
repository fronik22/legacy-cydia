/* Real private Unix socket, mocked root ownership failures; no host network/config changes. */
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>
#include <grp.h>
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static struct group *test_group(const char *name);
static int test_chown(const char *path, uid_t uid, gid_t gid);
static int test_chmod(const char *path, mode_t mode);
static int test_listen(int fd, int n);
#define getgrnam test_group
#define chown test_chown
#define chmod test_chmod
#define listen test_listen
#include "../src/control.c"
#undef getgrnam
#undef chown
#undef chmod
#undef listen
static int missing_group, fail_chown, fail_chmod, fail_listen, ownership_calls;
static struct group *test_group(const char *name) {
 static struct group group; assert(!strcmp(name,"mobile"));group.gr_gid=getgid();
 return missing_group?NULL:&group;
}
static int test_chown(const char *path,uid_t uid,gid_t gid) {
 struct stat st;assert(!lstat(path,&st)&&S_ISSOCK(st.st_mode));assert((st.st_mode&0777)==0600);
 assert(!uid&&gid==getgid());ownership_calls++;if(fail_chown){errno=EPERM;return -1;}return 0;
}
static int test_chmod(const char *path,mode_t mode) {
 assert(mode==0660);if(fail_chmod){errno=EPERM;return -1;}return chmod(path,mode);
}
static int test_listen(int fd,int n){if(fail_listen){errno=EIO;return -1;}return listen(fd,n);}
int main(void){
 char directory[]="/tmp/a6-control.XXXXXX",path[104];assert(mkdtemp(directory));snprintf(path,sizeof path,"%s/control.sock",directory);struct stat st;
 missing_group=1;assert(a6_control_open(path)<0&&errno==ENOENT);assert(lstat(path,&st)<0&&ownership_calls==0);missing_group=0;
 fail_chown=1;assert(a6_control_open(path)<0&&errno==EPERM);assert(lstat(path,&st)<0);fail_chown=0;
 fail_chmod=1;assert(a6_control_open(path)<0&&errno==EPERM);assert(lstat(path,&st)<0);fail_chmod=0;
 fail_listen=1;assert(a6_control_open(path)<0&&errno==EIO);assert(lstat(path,&st)<0);fail_listen=0;
 int fd=a6_control_open(path);assert(fd>=0&&!lstat(path,&st)&&(st.st_mode&0777)==0660);
 int client=socket(AF_UNIX,SOCK_STREAM,0);assert(client>=0);struct sockaddr_un addr={0};addr.sun_family=AF_UNIX;snprintf(addr.sun_path,sizeof addr.sun_path,"%s",path);assert(!connect(client,(void*)&addr,sizeof addr));
 int accepted=a6_control_accept(fd);assert(accepted>=0);assert(write(client,"ping\n",5)==5);char text[16];assert(!a6_control_read(accepted,text,sizeof text)&&!strcmp(text,"ping"));
 close(client);close(accepted);a6_control_close(fd,path);assert(lstat(path,&st)<0);assert(!rmdir(directory));
 puts("Control socket private bind, root/mobile0660, missing group/ownership/mode/listen failure cleanup passed");
}
