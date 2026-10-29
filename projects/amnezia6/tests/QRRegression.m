/* Temporary injected test only: never part of the application/package. */
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import "../app/A6QRScannerController.h"
#import "../app/A6ProfilesController.h"
static UINavigationController *navigation;
static id scanner;
static NSMutableDictionary *result;
static IMP frameIMP;
static volatile int realFrames;
static BOOL replay;
static dispatch_queue_t Queue(void){Ivar ivar=class_getInstanceVariable([scanner class],"_queue");return *(dispatch_queue_t *)((char *)(void *)scanner+ivar_getOffset(ivar));}
static AVCaptureSession *Session(void){return[scanner valueForKey:@"session"];}
static void Save(void){[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/tmp/a6-qr13/result.json" atomically:YES];}
static void CountFrame(id self,SEL cmd,id output,CMSampleBufferRef sample,id connection){if(!replay)__sync_add_and_fetch(&realFrames,1);((void(*)(id,SEL,id,CMSampleBufferRef,id))frameIMP)(self,cmd,output,sample,connection);}
static void Finish(void){
 [result setObject:[[scanner valueForKey:@"progress"]text]?:@""forKey:@"final_progress"];
 [result setObject:NSStringFromClass([navigation.topViewController class])forKey:@"final_controller"];
 [result setObject:@([navigation.topViewController isKindOfClass:NSClassFromString(@"A6ConfigController")])forKey:@"opened_review_editor"];
 [result setObject:@(![Session() isRunning])forKey:@"camera_stopped_after_completion"];
 [result setObject:@(realFrames)forKey:@"real_camera_callbacks"];
 [result setObject:@YES forKey:@"replay_used_public_synthetic_fixture"];
 [result setObject:@NO forKey:@"optical_animated_display_tested"];Save();
 method_setImplementation(class_getInstanceMethod(NSClassFromString(@"A6QRScannerController"),@selector(captureOutput:didOutputSampleBuffer:fromConnection:)),frameIMP);
 [navigation popToRootViewControllerAnimated:NO];[scanner release];scanner=nil;
}
static void Replay(int index){
 if(index==5){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Finish();});return;}
 int order[]={3,1,1,0,2};NSString *path=[NSString stringWithFormat:@"/tmp/a6-qr13/animated-%d.pgm",order[index]];
 FILE *file=fopen([path fileSystemRepresentation],"rb");int w=0,h=0,max=0;
 if(!file||fscanf(file,"P5 %d %d %d",&w,&h,&max)!=3||w<=0||h<=0||w>2048||h>2048||max!=255){if(file)fclose(file);[result setObject:@"fixture missing/invalid"forKey:@"error"];Save();return;}fgetc(file);
 unsigned char *gray=malloc(w*h);if(!gray||fread(gray,w,h,file)!=(size_t)h){if(gray)free(gray);fclose(file);[result setObject:@"fixture read failed"forKey:@"error"];Save();return;}fclose(file);
 CVPixelBufferRef pixels=NULL;CVReturn status=CVPixelBufferCreate(NULL,w,h,kCVPixelFormatType_32BGRA,NULL,&pixels);
 if(status!=kCVReturnSuccess){free(gray);[result setObject:@"CVPixelBufferCreate failed"forKey:@"error"];Save();return;}
 CVPixelBufferLockBaseAddress(pixels,0);unsigned char *base=CVPixelBufferGetBaseAddress(pixels);size_t stride=CVPixelBufferGetBytesPerRow(pixels);
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){unsigned char v=gray[(index&1)?(w-1-x)*w+y:y*w+x],*p=base+y*stride+x*4;p[0]=p[1]=p[2]=v;p[3]=255;}free(gray);CVPixelBufferUnlockBaseAddress(pixels,0);
 CMVideoFormatDescriptionRef format=NULL;CMSampleBufferRef sample=NULL;
 OSStatus description=CMVideoFormatDescriptionCreateForImageBuffer(NULL,pixels,&format);CMSampleTimingInfo timing={kCMTimeInvalid,kCMTimeInvalid,kCMTimeInvalid};
 OSStatus created=description?description:CMSampleBufferCreateForImageBuffer(NULL,pixels,YES,NULL,NULL,format,&timing,&sample);
 if(!created){
  id target=[scanner retain];dispatch_async(Queue(),^{replay=YES;[target captureOutput:nil didOutputSampleBuffer:sample fromConnection:nil];replay=NO;CFRelease(sample);[target release];
   dispatch_async(dispatch_get_main_queue(),^{[result setObject:[[scanner valueForKey:@"progress"]text]?:@""forKey:[NSString stringWithFormat:@"progress_%d",index]];Save();dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{Replay(index+1);});});
  });
 }else{[result setObject:@"CMSampleBuffer creation failed"forKey:@"error"];Save();}
 if(format)CFRelease(format);CVPixelBufferRelease(pixels);

}
static void Observe(int attempts){
 if(![Session() isRunning]||realFrames<2){
  if(attempts<15){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Observe(attempts+1);});return;}
  [result setObject:@"camera not running/authorized; replay skipped"forKey:@"error"];[result setObject:@(realFrames)forKey:@"real_camera_callbacks"];Save();return;
 }
 [result setObject:@YES forKey:@"native_camera_running"];
 [navigation popViewControllerAnimated:NO];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 [result setObject:@(![Session() isRunning])forKey:@"camera_stopped_on_navigation_exit"];
 [navigation pushViewController:scanner animated:NO];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
 [result setObject:@([Session() isRunning])forKey:@"camera_restarted_on_navigation_reentry"];
 [[NSNotificationCenter defaultCenter]postNotificationName:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
 [result setObject:@(![Session() isRunning])forKey:@"camera_stopped_on_resign_notification"];
 int before=realFrames;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
  [result setObject:@(realFrames-before)forKey:@"callbacks_after_stop"];
  [[NSNotificationCenter defaultCenter]postNotificationName:UIApplicationDidBecomeActiveNotification object:[UIApplication sharedApplication]];
  [result setObject:@([Session() isRunning])forKey:@"camera_restarted_on_active_notification"];Save();
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
   [[scanner valueForKey:@"output"]setSampleBufferDelegate:nil queue:NULL];dispatch_sync(Queue(),^{});
   [result setObject:@YES forKey:@"native_delegate_detached_before_serial_replay"];
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,300*NSEC_PER_MSEC),dispatch_get_main_queue(),^{Replay(0);});
  });
 });
 });
 });
}
__attribute__((constructor))static void Load(void){
 if(![[NSBundle mainBundle].bundleIdentifier isEqual:@"com.mak.amnezia6"])return;
 Dl_info image;if(!dladdr((void*)&Load,&image)||!dlopen(image.dli_fname,RTLD_LAZY|RTLD_LOCAL|RTLD_NODELETE))return;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  result=[NSMutableDictionary new];navigation=(id)[UIApplication sharedApplication].keyWindow.rootViewController;
  if(![navigation isKindOfClass:[UINavigationController class]]){[result setObject:@"navigation missing"forKey:@"error"];Save();return;}
  [navigation popToRootViewControllerAnimated:NO];id profiles=[[NSClassFromString(@"A6ProfilesController")alloc]init];[navigation pushViewController:profiles animated:NO];
  scanner=[[NSClassFromString(@"A6QRScannerController")alloc]initWithImporter:profiles];[profiles release];
  if(!scanner){[result setObject:@"scanner class missing"forKey:@"error"];Save();return;}
  frameIMP=method_setImplementation(class_getInstanceMethod([scanner class],@selector(captureOutput:didOutputSampleBuffer:fromConnection:)),(IMP)CountFrame);
  [navigation pushViewController:scanner animated:NO];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Observe(0);});
 });
}
