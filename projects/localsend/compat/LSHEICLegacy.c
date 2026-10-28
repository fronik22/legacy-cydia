#include "LSHEICDecoder.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
CGImageRef LSDecodeHEIC(const char *path,char *error,size_t errorSize) {
    static void *library;
    CFBundleRef bundle=CFBundleGetMainBundle();
    CFStringRef name=kCFCoreFoundationVersionNumber<793.0?CFSTR("LSHEIC4"):CFSTR("LSHEIC");
    CFURLRef url=CFBundleCopyResourceURL(bundle,name,CFSTR("dylib"),NULL);
    if(url){char file[4096];if(CFURLGetFileSystemRepresentation(url,true,(UInt8 *)file,sizeof(file)))library=library?:dlopen(file,RTLD_LAZY|RTLD_LOCAL);CFRelease(url);}
    CGImageRef (*decode)(const char *,char *,size_t)=library?dlsym(library,"LSDecodeHEIC"):NULL;
    if(decode)return decode(path,error,errorSize);
    if(error&&errorSize)snprintf(error,errorSize,"HEIC decoder unavailable; the original file is retained");
    return NULL;
}
