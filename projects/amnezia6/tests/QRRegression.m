/* Temporary injected test only: never part of the application/package. */
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#include <sys/stat.h>
#import "../app/A6QRScannerController.h"
#import "../app/A6ProfilesController.h"
@interface A6TestMetadataCode : NSObject {NSString *_value;}
- (id)initWithText:(NSString *)text;
- (NSString *)type;
- (NSString *)stringValue;
@end
@implementation A6TestMetadataCode
- (id)initWithText:(NSString *)text {if((self=[super init]))_value=[text copy];return self;}
- (void)dealloc {[_value release];[super dealloc];}
- (NSString *)type {return AVMetadataObjectTypeQRCode;}
- (NSString *)stringValue {return _value;}
@end
@interface A6QRScannerController (MetadataRegression)
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray *)objects fromConnection:(AVCaptureConnection *)connection;
@end
static UINavigationController *navigation;
static id scanner;
static NSMutableDictionary *result;
static IMP frameIMP;
static NSUncaughtExceptionHandler *priorException;
static volatile int realFrames;
static BOOL replay,dnsMode,physicalMode;
static dispatch_queue_t Queue(void){Ivar ivar=class_getInstanceVariable([scanner class],"_queue");return *(dispatch_queue_t *)((char *)(void *)scanner+ivar_getOffset(ivar));}
static AVCaptureSession *Session(void){return[scanner valueForKey:@"session"];}
static void Save(void){[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL]writeToFile:@"/tmp/a6-qr13/result.json" atomically:YES];}
static void TestException(NSException *exception){
 NSMutableArray *markers=[NSMutableArray array];for(NSString *marker in[NSArray arrayWithObjects:@"NaN",@"bounds",@"frame",@"orientation",@"constraint",@"index",@"subview",@"layer",@"navigation",@"transition",nil])if([[exception reason]rangeOfString:marker options:NSCaseInsensitiveSearch].location!=NSNotFound)[markers addObject:marker];
 [result setObject:markers forKey:@"exception_fixed_markers"];[result setObject:[exception name]forKey:@"exception_class"];Save();if(priorException)priorException(exception);
}
static void CountFrame(id self,SEL cmd,id output,CMSampleBufferRef sample,id connection){if(!replay)__sync_add_and_fetch(&realFrames,1);((void(*)(id,SEL,id,CMSampleBufferRef,id))frameIMP)(self,cmd,output,sample,connection);}
static void RejectCompletedProfile(void){
 id profiles=[[NSClassFromString(@"A6ProfilesController")alloc]init];[navigation pushViewController:profiles animated:NO];
 scanner=[[NSClassFromString(@"A6QRScannerController")alloc]initWithImporter:profiles];[profiles release];[navigation pushViewController:scanner animated:NO];
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
  A6TestMetadataCode *bad=[[[A6TestMetadataCode alloc]initWithText:@"public unsupported profile"]autorelease];
  [scanner captureOutput:nil didOutputMetadataObjects:[NSArray arrayWithObject:bad]fromConnection:nil];
  NSString *message=[[[scanner valueForKey:@"progress"]text]copy];
  A6TestMetadataCode *next=[[[A6TestMetadataCode alloc]initWithText:@"B8A"]autorelease];
  [scanner captureOutput:nil didOutputMetadataObjects:[NSArray arrayWithObject:next]fromConnection:nil];
  [scanner captureOutput:nil didOutputMetadataObjects:[NSArray arrayWithObjects:next,next,nil]fromConnection:nil];
  [result setObject:@([message rangeOfString:@"Назад"].location!=NSNotFound&&[message isEqual:[[scanner valueForKey:@"progress"]text]])forKey:@"rejected_profile_error_is_sticky"];[message release];
  [result setObject:@(![Session() isRunning])forKey:@"camera_stopped_on_rejected_profile"];
  [result setObject:@(navigation.topViewController==scanner)forKey:@"rejected_profile_no_review"];
  NSString *path=@"/var/mobile/Library/Preferences/Amnezia6/qr-last-scan.plist";
  NSDictionary *stats=[NSDictionary dictionaryWithContentsOfFile:path];struct stat info;
  NSSet *allowed=[NSSet setWithObjects:@"app_version",@"decoded_frames",@"last_frame",@"status",@"part",@"duplicate",@"conflict",@"complete",@"invalid_compression",@"profile_rejected",@"invalid_frame",@"static",nil];BOOL keysOK=YES;for(id key in stats)if(![allowed containsObject:key])keysOK=NO;
  NSSet *frameKeys=[NSSet setWithObjects:@"event",@"string_length",@"count",@"index",@"part_length",@"received",nil];for(id key in[stats objectForKey:@"last_frame"])if(![frameKeys containsObject:key])keysOK=NO;
  [result setObject:@([[stats objectForKey:@"app_version"]isEqual:@"1.3.3"])forKey:@"diagnostic_app_version_correct"];
  [result setObject:@(keysOK&&[[stats objectForKey:@"status"]isEqual:@"profile_rejected"]&&[stats count]<20&&[[stats description]rangeOfString:@"public unsupported profile"].location==NSNotFound)forKey:@"private_bounded_diagnostic_codes_only"];
  [result setObject:@(!stat([path fileSystemRepresentation],&info)&&(info.st_mode&0777)==0600&&info.st_size<8192)forKey:@"diagnostic_mode0600_and_small"];Save();NSSetUncaughtExceptionHandler(priorException);
  [navigation popToRootViewControllerAnimated:NO];[scanner release];scanner=nil;
 });
}
static void Finish(void){
 [result setObject:[[scanner valueForKey:@"progress"]text]?:@""forKey:@"final_progress"];
 [result setObject:NSStringFromClass([navigation.topViewController class])forKey:@"final_controller"];
 [result setObject:@([navigation.topViewController isKindOfClass:NSClassFromString(@"A6ConfigController")])forKey:@"opened_review_editor"];
 [result setObject:@(![Session() isRunning])forKey:@"camera_stopped_after_completion"];
 [result setObject:@(realFrames)forKey:@"real_camera_callbacks"];
 if(dnsMode&&[navigation.topViewController isKindOfClass:NSClassFromString(@"A6ConfigController")]){
  NSString *text=[navigation.topViewController valueForKey:@"initialConfig"];
  [result setObject:@([text rangeOfString:@"DNS = 192.0.2.53, 198.51.100.53"].location!=NSNotFound&&[text rangeOfString:@"$"].location==NSNotFound)forKey:@"two_part_official_dns_template_both_resolvers_in_review"];
  [result setObject:@([text rangeOfString:@"PersistentKeepalive = 25-35"].location!=NSNotFound&&[text rangeOfString:@"KeepaliveTimeout = 5-15"].location!=NSNotFound&&[text rangeOfString:@"HeaderProtectionKey ="].location!=NSNotFound&&[text rangeOfString:@"MaxHandshakeAttempts = 15-20"].location!=NSNotFound)forKey:@"full_awg31_template_in_review"];
 }
 [result setObject:@YES forKey:@"replay_used_public_synthetic_fixture"];
 [result setObject:@NO forKey:@"optical_animated_display_tested"];Save();
 method_setImplementation(class_getInstanceMethod(NSClassFromString(@"A6QRScannerController"),@selector(captureOutput:didOutputSampleBuffer:fromConnection:)),frameIMP);
 [navigation popToRootViewControllerAnimated:NO];[scanner release];scanner=nil;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{RejectCompletedProfile();});
}
static void Replay(int index){
 if(index==(dnsMode?3:5)){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Finish();});return;}
 int order[]={3,1,1,0,2};if(dnsMode){order[0]=1;order[1]=1;order[2]=0;}
 if((index==1||index==3)&&[scanner valueForKey:@"metadataOutput"]){
  NSString *text=[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"/tmp/a6-qr13/animated-%d.txt",order[index]]encoding:NSUTF8StringEncoding error:NULL];
  if(![text length]){[result setObject:@"native callback fixture missing"forKey:@"error"];Save();return;}
  A6TestMetadataCode *object=[[[A6TestMetadataCode alloc]initWithText:text]autorelease];
  [scanner captureOutput:nil didOutputMetadataObjects:[NSArray arrayWithObject:object]fromConnection:nil];
  [result setObject:[[scanner valueForKey:@"progress"]text]?:@""forKey:[NSString stringWithFormat:@"progress_%d",index]];
  [result setObject:@YES forKey:@"native_metadata_callback_assembler_checked"];Save();
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{Replay(index+1);});return;
 }
 NSString *path=[NSString stringWithFormat:@"/tmp/a6-qr13/animated-%d.pgm",order[index]];
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
 if(physicalMode){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,10*NSEC_PER_SEC),dispatch_get_main_queue(),^{
   [result setObject:NSStringFromClass([navigation.topViewController class])forKey:@"physical_top_controller"];
   [result setObject:@([navigation.topViewController isKindOfClass:NSClassFromString(@"A6ConfigController")])forKey:@"actual_optical_import_review"];
   NSDictionary *stats=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/Amnezia6/qr-last-scan.plist"];
   [result setObject:@([[stats objectForKey:@"app_version"]isEqual:@"1.3.3"])forKey:@"new_version_scan_seen"];
   if([[stats objectForKey:@"app_version"]isEqual:@"1.3.3"]){[result setObject:[stats objectForKey:@"status"]?:@"unknown"forKey:@"physical_status"];[result setObject:[stats objectForKey:@"decoded_frames"]?:@0 forKey:@"physical_decoded_frames"];}
   [result setObject:@NO forKey:@"replay_used_public_synthetic_fixture"];Save();
   method_setImplementation(class_getInstanceMethod(NSClassFromString(@"A6QRScannerController"),@selector(captureOutput:didOutputSampleBuffer:fromConnection:)),frameIMP);
   NSSetUncaughtExceptionHandler(priorException);if(navigation.topViewController==scanner)[navigation popToRootViewControllerAnimated:NO];[scanner release];scanner=nil;
  });return;
 }

 if(realFrames<2&&[Session() isRunning]&&[scanner valueForKey:@"metadataOutput"]&&![[scanner valueForKey:@"output"]sampleBufferDelegate]){
  AVCaptureVideoDataOutput *video=[scanner valueForKey:@"output"];
  [result setObject:@(video.sampleBufferDelegate==nil)forKey:@"native_mode_disables_quirc_camera_delegate"];
  // Count physical frames only in this temporary diagnostic; production uses native QR output.
  [video setSampleBufferDelegate:scanner queue:Queue()];
 }
 if(![Session() isRunning]||realFrames<2){
  if(attempts<15){dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Observe(attempts+1);});return;}
  [result setObject:@"camera not running/authorized; replay skipped"forKey:@"error"];[result setObject:[[scanner valueForKey:@"progress"]text]?:@""forKey:@"diagnostic_progress"];[result setObject:@([UIApplication sharedApplication].applicationState)forKey:@"application_state"];[result setObject:@([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo])forKey:@"camera_authorization"];[result setObject:@([Session() isRunning])forKey:@"session_running"];[result setObject:@([[scanner valueForKey:@"visible"]boolValue])forKey:@"scanner_visible"];[result setObject:@([Session().outputs count])forKey:@"session_output_count"];[result setObject:@(realFrames)forKey:@"real_camera_callbacks"];Save();return;
 }
 [result setObject:@YES forKey:@"native_camera_running"];
 AVCaptureMetadataOutput *metadata=[scanner valueForKey:@"metadataOutput"];
 [result setObject:@(metadata&&[metadata.metadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]&&metadata.metadataObjectsDelegate==scanner)forKey:@"native_qr_metadata_configured"];
 AVCaptureDevice *device=[[[Session() inputs]objectAtIndex:0]device];
 [result setObject:@(device.focusMode)forKey:@"focus_mode"];
 [result setObject:@(device.position)forKey:@"camera_position"];
 [result setObject:Session().sessionPreset forKey:@"session_preset"];
 [result setObject:@([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])forKey:@"continuous_autofocus_supported"];
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
   [[scanner valueForKey:@"output"]setSampleBufferDelegate:nil queue:NULL];[[scanner valueForKey:@"metadataOutput"]setMetadataObjectsDelegate:nil queue:NULL];dispatch_sync(Queue(),^{});
   [result setObject:@YES forKey:@"native_delegate_detached_before_serial_replay"];
   if([scanner valueForKey:@"metadataOutput"]){
    A6TestMetadataCode *code=[[[A6TestMetadataCode alloc]initWithText:@"public-test"]autorelease];
    [scanner captureOutput:nil didOutputMetadataObjects:[NSArray arrayWithObjects:code,code,nil]fromConnection:nil];
    [result setObject:@([[[scanner valueForKey:@"parts"]valueForKey:@"received"]unsignedIntegerValue]==0&&[[[scanner valueForKey:@"progress"]text]isEqual:@"В кадре несколько QR. Оставьте один."])forKey:@"native_multiple_qr_rejected"];
   }
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
  physicalMode=[[NSFileManager defaultManager]fileExistsAtPath:@"/tmp/a6-qr13/physical-mode"];dnsMode=[[NSFileManager defaultManager]fileExistsAtPath:@"/tmp/a6-qr13/dns-mode"];result=[NSMutableDictionary new];navigation=(id)[UIApplication sharedApplication].keyWindow.rootViewController;
  if(![navigation isKindOfClass:[UINavigationController class]]){[result setObject:@"navigation missing"forKey:@"error"];Save();return;}
  priorException=NSGetUncaughtExceptionHandler();NSSetUncaughtExceptionHandler(TestException);[result setObject:@"before_navigation"forKey:@"phase"];Save();
  [navigation popToRootViewControllerAnimated:NO];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
   id profiles=[[NSClassFromString(@"A6ProfilesController")alloc]init];[navigation pushViewController:profiles animated:NO];[result setObject:@"profiles_presented"forKey:@"phase"];Save();
   dispatch_after(dispatch_time(DISPATCH_TIME_NOW,500*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
    scanner=[[NSClassFromString(@"A6QRScannerController")alloc]initWithImporter:profiles];[profiles release];
    if(!scanner){[result setObject:@"scanner class missing"forKey:@"error"];Save();return;}
    frameIMP=method_setImplementation(class_getInstanceMethod([scanner class],@selector(captureOutput:didOutputSampleBuffer:fromConnection:)),(IMP)CountFrame);
    [navigation pushViewController:scanner animated:NO];[result setObject:@"scanner_presented"forKey:@"phase"];Save();dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{Observe(0);});
   });
  });
 });
}
