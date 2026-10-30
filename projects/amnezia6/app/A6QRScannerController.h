#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <dispatch/dispatch.h>
@class A6ProfilesController,A6QRParts;
struct quirc;
@interface A6QRScannerController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate> {
    A6ProfilesController *_importer;
    AVCaptureSession *_session;
    AVCaptureVideoDataOutput *_output;
    AVCaptureMetadataOutput *_metadataOutput;
    AVCaptureVideoPreviewLayer *_preview;
    UILabel *_progress;
    NSTimer *_timeout;
    A6QRParts *_parts;
    dispatch_queue_t _queue;
    struct quirc *_decoder;
    CFTimeInterval _lastFrame,_lastDiagnostic;
    NSMutableDictionary *_scanStats;
    NSUInteger _scanFrames,_diagnosticWrites;
    BOOL _visible,_finished;
}
- (id)initWithImporter:(A6ProfilesController *)importer;
@end
