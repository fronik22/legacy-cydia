#import <Foundation/Foundation.h>
#import <dlfcn.h>
int main(void) {
 NSAutoreleasePool *pool=[NSAutoreleasePool new];
 NSArray *libraries=[NSArray arrayWithObjects:@"/System/Library/Frameworks/UIKit.framework/UIKit",@"/System/Library/Frameworks/AssetsLibrary.framework/AssetsLibrary",@"/System/Library/Frameworks/AVFoundation.framework/AVFoundation",@"/System/Library/Frameworks/MediaPlayer.framework/MediaPlayer",@"/System/Library/Frameworks/AVKit.framework/AVKit",@"/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation",@"/usr/lib/libgcc_s.1.dylib",@"/usr/lib/libstdc++.6.dylib",@"/usr/lib/libc++.1.dylib",nil];
 NSMutableDictionary *loaded=[NSMutableDictionary dictionary];
 for(NSString *path in libraries) { void *handle=dlopen(path.UTF8String,RTLD_NOW|RTLD_LOCAL);[loaded setObject:handle?@"loaded":[NSString stringWithUTF8String:dlerror()?:"failed"] forKey:path]; }
 NSMutableDictionary *classes=[NSMutableDictionary dictionary];
 for(NSString *name in [NSArray arrayWithObjects:@"NSJSONSerialization",@"ALAssetsLibrary",@"AVPlayer",@"MPMoviePlayerController",@"UIFont",@"UIViewController",@"UIWebView",nil]) [classes setObject:[NSNumber numberWithBool:NSClassFromString(name)!=Nil] forKey:name];
 Class vc=NSClassFromString(@"UIViewController");
 NSDictionary *result=[NSDictionary dictionaryWithObjectsAndKeys:@(sizeof(void *)),@"pointerBytes",[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"],@"system",loaded,@"libraries",classes,@"classes",@([vc instancesRespondToSelector:NSSelectorFromString(@"setEdgesForExtendedLayout:")]),@"ios7ExtendedEdges",@([NSClassFromString(@"UINavigationController") instancesRespondToSelector:NSSelectorFromString(@"interactivePopGestureRecognizer")]),@"ios7InteractivePop",@(dlsym(RTLD_DEFAULT,"MobileInstallationInstall")!=NULL),@"mobileInstallationInstall",nil];
 NSData *json=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
 puts([[[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding]autorelease].UTF8String);[pool drain];return 0;
}
