#ifndef LOG_STORE_H
#define LOG_STORE_H
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
static int LPAppend(const char*base,const void*bytes,size_t size,size_t limit,unsigned files){
 if(!size||size>limit||files<2||files>20){errno=EINVAL;return-1;}
 int fd=open(base,O_WRONLY|O_CREAT|O_APPEND|O_NOFOLLOW,0640);if(fd<0)return-1;
 struct stat st;if(fstat(fd,&st)||!S_ISREG(st.st_mode)){close(fd);errno=EINVAL;return-1;}
 if((uint64_t)st.st_size+size>limit){
  close(fd);char from[1024],to[1024];
  snprintf(to,sizeof to,"%s.%u",base,files-1);if(unlink(to)&&errno!=ENOENT)return-1;
  for(unsigned i=files-1;i>1;i--){snprintf(from,sizeof from,"%s.%u",base,i-1);snprintf(to,sizeof to,"%s.%u",base,i);if(rename(from,to)&&errno!=ENOENT)return-1;}
  snprintf(to,sizeof to,"%s.1",base);if(rename(base,to))return-1;
  fd=open(base,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW,0640);if(fd<0)return-1;
 }
 size_t at=0;while(at<size){ssize_t n=write(fd,(const char*)bytes+at,size-at);if(n<0&&errno==EINTR)continue;if(n<=0){close(fd);return-1;}at+=n;}
 return close(fd);
}
#endif
