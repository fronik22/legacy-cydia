#import "YTLegacy.h"
#include <dlfcn.h>

SSLContextRef YTLegacyCreateTLSContext(void) {
    if (SSLCreateContext) return SSLCreateContext(kCFAllocatorDefault,kSSLClientSide,kSSLStreamType);
    OSStatus (*create)(Boolean,SSLContextRef *)=dlsym(RTLD_DEFAULT,"SSLNewContext");
    SSLContextRef context=NULL;
    return create && create(false,&context)==noErr ? context : NULL;
}
void YTLegacyReleaseTLSContext(SSLContextRef context) {
    if (!context) return;
    if (SSLCreateContext) CFRelease(context);
    else {
        OSStatus (*dispose)(SSLContextRef)=dlsym(RTLD_DEFAULT,"SSLDisposeContext");
        if (dispose) dispose(context);
    }
}
