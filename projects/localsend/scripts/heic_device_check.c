#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv){
    if(argc!=4){fprintf(stderr,"usage: check module.dylib input.heic output.jpg\n");return 2;}
    void *module=dlopen(argv[1],RTLD_NOW|RTLD_LOCAL);
    if(!module){fprintf(stderr,"dlopen: %s\n",dlerror());return 3;}
    CGImageRef (*decode)(const char *,char *,size_t)=dlsym(module,"LSDecodeHEIC");
    if(!decode){fprintf(stderr,"decoder export missing\n");return 4;}
    char message[512]={0};CGImageRef image=decode(argv[2],message,sizeof(message));
    if(!image){fprintf(stderr,"decode: %s\n",message);return 1;}
    size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image);
    CFURLRef url=CFURLCreateFromFileSystemRepresentation(NULL,(const UInt8 *)argv[3],strlen(argv[3]),false);
    CGImageDestinationRef output=CGImageDestinationCreateWithURL(url,CFSTR("public.jpeg"),1,NULL);
    Boolean ok=false;if(output){CGImageDestinationAddImage(output,image,NULL);ok=CGImageDestinationFinalize(output);CFRelease(output);}
    CFRelease(url);CGImageRelease(image);dlclose(module);
    printf("%s HEIC to JPEG %zu x %zu\n",ok?"PASS":"FAIL",width,height);return ok?0:5;
}
