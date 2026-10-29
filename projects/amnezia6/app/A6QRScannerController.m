#import "A6QRScannerController.h"
#import "A6ProfilesController.h"
#import "A6QRParts.h"
#import "A6Import.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#include "quirc.h"
#include "qr_frame.h"
@interface A6QRScannerController ()
- (void)startCamera;
- (void)stopCamera;
@end
@implementation A6QRScannerController
- (id)initWithImporter:(A6ProfilesController *)importer {
    if((self=[super init])){_importer=importer;self.title=@"Сканировать QR";_parts=[A6QRParts new];_queue=dispatch_queue_create("com.mak.amnezia6.qr",NULL);_decoder=quirc_new();}return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];[self stopCamera];
    dispatch_sync(_queue,^{});if(_decoder)quirc_destroy(_decoder);dispatch_release(_queue);
    [_output release];[_session release];[_preview release];[_progress release];[_parts release];[super dealloc];
}
- (void)loadView {
    self.view=[[[UIView alloc]initWithFrame:[[UIScreen mainScreen]applicationFrame]]autorelease];self.view.backgroundColor=[UIColor blackColor];
    _progress=[[UILabel alloc]initWithFrame:CGRectMake(10,10,self.view.bounds.size.width-20,85)];_progress.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    _progress.backgroundColor=[UIColor colorWithWhite:0 alpha:0.75];_progress.textColor=[UIColor whiteColor];_progress.textAlignment=NSTextAlignmentCenter;_progress.numberOfLines=4;_progress.font=[UIFont systemFontOfSize:16];
    _progress.text=@"Наведите камеру на QR.\nДержите динамический код в кадре до сбора всех частей.\n0 / ?";[self.view addSubview:_progress];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(stopCamera) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(startCamera) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)viewDidAppear:(BOOL)animated {[super viewDidAppear:animated];_visible=YES;[self startCamera];}
- (void)viewWillDisappear:(BOOL)animated {_visible=NO;[self stopCamera];[_parts reset];[super viewWillDisappear:animated];}
- (void)expireParts {if([_parts expireAtTime:CACurrentMediaTime()])_progress.text=@"Время сборки QR истекло. Сканируйте заново.\n0 / ?";}
- (void)stopCamera {[_timeout invalidate];[_timeout release];_timeout=nil;[_parts reset];[_output setSampleBufferDelegate:nil queue:NULL];[_session stopRunning];}
- (void)startCamera {
    if(!_visible||_finished||[UIApplication sharedApplication].applicationState!=UIApplicationStateActive)return;
    if(!_decoder){_progress.text=@"Недостаточно памяти для камеры";return;}
    if([AVCaptureDevice respondsToSelector:@selector(authorizationStatusForMediaType:)]){
        AVAuthorizationStatus status=[AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if(status==AVAuthorizationStatusDenied||status==AVAuthorizationStatusRestricted){_progress.text=@"Разрешите доступ к камере в Настройках → Конфиденциальность → Камера.";return;}
        if(status==AVAuthorizationStatusNotDetermined){
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted){dispatch_async(dispatch_get_main_queue(),^{if(granted)[self startCamera];else _progress.text=@"Доступ к камере запрещён";});}];return;
        }
    }
    if(!_session){
        AVCaptureDevice *device=[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];NSError *error=nil;
        AVCaptureDeviceInput *input=device?[AVCaptureDeviceInput deviceInputWithDevice:device error:&error]:nil;
        _session=[AVCaptureSession new];
        if([_session canSetSessionPreset:AVCaptureSessionPreset1280x720])_session.sessionPreset=AVCaptureSessionPreset1280x720;
        else _session.sessionPreset=AVCaptureSessionPresetHigh;
        _output=[AVCaptureVideoDataOutput new];_output.alwaysDiscardsLateVideoFrames=YES;
        _output.videoSettings=[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        if(!input||![_session canAddInput:input]||![_session canAddOutput:_output]){
            _progress.text=@"Камера недоступна. Закройте сканер и попробуйте снова.";[_session release];_session=nil;[_output release];_output=nil;return;
        }
        [_session addInput:input];[_session addOutput:_output];
        _preview=[[AVCaptureVideoPreviewLayer alloc]initWithSession:_session];_preview.videoGravity=AVLayerVideoGravityResizeAspect;
        _preview.frame=self.view.bounds;if([_preview isOrientationSupported])_preview.orientation=(AVCaptureVideoOrientation)self.interfaceOrientation;[self.view.layer insertSublayer:_preview atIndex:0];
    }
    [_output setSampleBufferDelegate:self queue:_queue];[_session startRunning];
    if(!_timeout)_timeout=[[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(expireParts) userInfo:nil repeats:YES]retain];
}
- (void)receiveText:(NSString *)text {
    if(!_visible||_finished||![_session isRunning])return;
    NSString *error=nil;NSData *data=[_parts consume:text atTime:CACurrentMediaTime() error:&error];
    if(data){NSString *config=A6ImportConfig(data,&error);if(config){_finished=YES;[self stopCamera];[_importer importData:[config dataUsingEncoding:NSUTF8StringEncoding]name:nil];return;}}
    _progress.text=error?:[NSString stringWithFormat:@"Получено %lu / %lu\nДержите код в кадре до завершения.",(unsigned long)[_parts received],(unsigned long)[_parts total]];
}
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sample fromConnection:(AVCaptureConnection *)connection {
    CFTimeInterval now=CACurrentMediaTime();if(now-_lastFrame<0.15)return;_lastFrame=now;
    NSAutoreleasePool *pool=[NSAutoreleasePool new];CVPixelBufferRef pixels=CMSampleBufferGetImageBuffer(sample);
    if(pixels&&CVPixelBufferLockBaseAddress(pixels,kCVPixelBufferLock_ReadOnly)==kCVReturnSuccess){
        char text[QUIRC_MAX_PAYLOAD+1];
        int n=a6_qr_decode_frame(_decoder,CVPixelBufferGetBaseAddress(pixels),(int)CVPixelBufferGetWidth(pixels),(int)CVPixelBufferGetHeight(pixels),CVPixelBufferGetBytesPerRow(pixels),4,text,sizeof text);
        CVPixelBufferUnlockBaseAddress(pixels,kCVPixelBufferLock_ReadOnly);
        if(n>0){NSString *value=[[[NSString alloc]initWithBytes:text length:n encoding:NSUTF8StringEncoding]autorelease];if(value)[self performSelectorOnMainThread:@selector(receiveText:) withObject:value waitUntilDone:NO];}
        memset(text,0,sizeof text);
    }
    [pool drain];
}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {[super didRotateFromInterfaceOrientation:orientation];_preview.frame=self.view.bounds;if([_preview isOrientationSupported])_preview.orientation=(AVCaptureVideoOrientation)self.interfaceOrientation;}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UIInterfaceOrientationMaskAll;}
@end
