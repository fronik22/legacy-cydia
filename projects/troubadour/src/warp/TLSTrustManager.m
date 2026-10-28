//
//  TLSTrustManager.m
//  YouTube
//

#import "TLSTrustManager.h"
#import "YTHttp.h"
#import "DebugLog.h"
#import <Security/Security.h>
#import <dlfcn.h>

@interface TLSTrustManager ()
@property (nonatomic, strong) NSArray *anchors; // array of id (SecCertificateRef)
@end

@implementation TLSTrustManager

+ (instancetype)sharedManager {
    static TLSTrustManager *mgr = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ mgr = [[TLSTrustManager alloc] init]; });
    return mgr;
}

- (id)init {
    self = [super init];
    if (self) {
        [self loadAnchors];
    }
    return self;
}

- (void)loadAnchors {
    NSMutableArray *certs = [NSMutableArray array];

    // Certs/ folder is copied verbatim into the app bundle by the Makefile.
    NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"cer" inDirectory:@"Certs"];
    if (paths.count == 0) {
        // Fallback: flat resource root (in case the bundler flattened it)
        paths = [[NSBundle mainBundle] pathsForResourcesOfType:@"cer" inDirectory:nil];
    }

    for (NSString *path in paths) {
        NSData *der = [NSData dataWithContentsOfFile:path];
        if (!der) continue;
        SecCertificateRef cert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)der);
        if (cert) {
            [certs addObject:(__bridge_transfer id)cert];
        }
    }

    _anchors = certs;
    DLog(@"[TLSTrust] loaded %lu modern root anchors", (unsigned long)certs.count);
}

- (BOOL)hasModernRoots { return self.anchors.count > 0; }
- (NSUInteger)rootCount { return self.anchors.count; }

- (BOOL)evaluateServerTrust:(SecTrustRef)serverTrust forHost:(NSString *)host {
    return serverTrust && [host length] && YTServerTrustIsValid(serverTrust, host);
}

- (BOOL)handleAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
                        forConnection:(NSURLConnection *)connection {
    NSString *method = challenge.protectionSpace.authenticationMethod;
    /*
     * Troubadour: константа и класс — по имени, а не ссылкой.
     *
     * Сетевые классы Foundation на iOS 7 переехали из CFNetwork, и прямая
     * ссылка привязывает бинарник к одной из библиотек: на другой части
     * систем приложение не запускается вовсе («Symbol not found»). Так же
     * сделано во всём приложении — см. YTNetworkClass в src/net/YTHttp.h.
     * Значение константы совпадает с её именем.
     */
    if (![method isEqualToString:@"NSURLAuthenticationMethodServerTrust"]) {
        return NO; // not ours — let default handling proceed
    }

    SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
    NSString *host = challenge.protectionSpace.host;
    if (![self evaluateServerTrust:serverTrust forHost:host]) {
        [challenge.sender cancelAuthenticationChallenge:challenge];
        return YES;
    }

    // Only supply a credential after chain and hostname verification.
    NSURLCredential *cred = [NSClassFromString(@"NSURLCredential") credentialForTrust:serverTrust];
    [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
    return YES;
}

@end
