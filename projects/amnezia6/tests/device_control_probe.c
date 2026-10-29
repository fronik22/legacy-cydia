#include "control.h"
#include <assert.h>
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
int main(void){
 assert(!geteuid());char directory[]="/var/tmp/a6-control-probe.XXXXXX",path[104];assert(mkdtemp(directory));snprintf(path,sizeof path,"%s/control.sock",directory);
 struct group *g=getgrnam("mobile");assert(g);gid_t gid=g->gr_gid;int fd=a6_control_open(path);assert(fd>=0);struct stat st;assert(!lstat(path,&st));assert(S_ISSOCK(st.st_mode)&&(st.st_mode&0777)==0660&&!st.st_uid&&st.st_gid==gid);
 a6_control_close(fd,path);assert(lstat(path,&st)<0);assert(!rmdir(directory));puts("Native control socket root:mobile0660 and cleanup passed");return 0;
}
