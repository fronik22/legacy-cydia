// Compiled only with --diagnostics; the release has no command reader.
#import "compat/LSLegacy.h"
#import "LSReceiver.h"
#import <QuartzCore/QuartzCore.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <unistd.h>
// Synthetic exporters exercise partial reads, read failure and cancellation without user media.
@interface LSFixtureRepresentation:NSObject
@property(nonatomic,strong) NSData *bytes;
@property(nonatomic,assign) NSInteger mode;
@property(nonatomic,copy) NSString *filename;
- (NSString *)UTI;
- (NSURL *)url;
- (long long)size;
- (NSUInteger)getBytes:(uint8_t *)buffer fromOffset:(long long)offset length:(NSUInteger)length error:(NSError **)error;
@end
@implementation LSFixtureRepresentation
- (NSString *)UTI {return [self.filename.pathExtension isEqual:@"mov"]?@"com.apple.quicktime-movie":@"public.jpeg";}
- (NSURL *)url {return [NSURL URLWithString:[@"fixture://" stringByAppendingString:self.filename]];}
- (long long)size {return self.bytes.length;}
- (NSUInteger)getBytes:(uint8_t *)buffer fromOffset:(long long)offset length:(NSUInteger)length error:(NSError **)error {
    if(self.mode==1){if(error)*error=[NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];return 0;}
    if(self.mode==2)usleep(250000);
    NSUInteger n=MIN((NSUInteger)32768,MIN(length,self.bytes.length-(NSUInteger)offset));memcpy(buffer,(const uint8_t *)self.bytes.bytes+offset,n);return n;
}
@end
@interface LSFixtureAsset:NSObject
@property(nonatomic,strong) LSFixtureRepresentation *representation;
- (id)defaultRepresentation;
- (id)valueForProperty:(NSString *)property;
- (CGImageRef)thumbnail;
@end
@implementation LSFixtureAsset
- (id)defaultRepresentation {return self.representation;}
- (id)valueForProperty:(NSString *)property {if([property isEqual:ALAssetPropertyType])return [self.representation.filename.pathExtension isEqual:@"mov"]?ALAssetTypeVideo:ALAssetTypePhoto;return @0;}
- (CGImageRef)thumbnail {return NULL;}
@end
@interface LSUIDiagnostics : NSObject
@property(nonatomic,weak) id app;
@property(nonatomic,strong) NSTimer *timer;
@end
static UIView *LSFindView(UIView *view,Class type) {if([view isKindOfClass:type])return view;for(UIView *child in view.subviews){UIView *found=LSFindView(child,type);if(found)return found;}return nil;}
@implementation LSUIDiagnostics
- (void)tick {
    NSString *folder=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
    NSString *input=[folder stringByAppendingPathComponent:@".compat-command.plist"];
    NSDictionary *command=[NSDictionary dictionaryWithContentsOfFile:input];if(!command)return;
    [[NSFileManager defaultManager] removeItemAtPath:input error:nil];
    id app=self.app;UIWindow *window=[app valueForKey:@"window"];NSString *action=command[@"action"];
    NSMutableDictionary *result=[NSMutableDictionary dictionaryWithObject:command[@"id"]?:@"" forKey:@"id"];
    @try {
        if([action isEqual:@"tab"]){[app setValue:command[@"tab"] forKey:@"activeTab"];[app performSelector:@selector(layoutInterface)];}
        else if([action isEqual:@"text-prompt"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];button.tag=1;[app performSelector:@selector(selectSource:) withObject:button];}
        else if([action isEqual:@"input"]){UIAlertView *alert=nil;for(UIWindow *w in [UIApplication sharedApplication].windows){alert=(id)LSFindView(w,[UIAlertView class]);if(alert)break;}if(!alert)[NSException raise:@"MissingAlert" format:@"No input alert"];UITextField *field=[alert textFieldAtIndex:0];field.text=command[@"text"];[[alert delegate] alertView:alert clickedButtonAtIndex:1];[alert dismissWithClickedButtonIndex:1 animated:NO];}
        else if([action isEqual:@"alert-dismiss"]){for(UIWindow *w in [UIApplication sharedApplication].windows){UIAlertView *alert=(id)LSFindView(w,[UIAlertView class]);if(alert){[alert dismissWithClickedButtonIndex:0 animated:NO];break;}}}
        else if([action isEqual:@"file-picker"])[app performSelector:@selector(chooseFile)];
        else if([action hasPrefix:@"files-"]){
            UINavigationController *nav=(id)window.rootViewController.modalViewController;id picker=nav.topViewController;
            if([action isEqual:@"files-directory"])[picker performSelector:@selector(openDirectory:) withObject:command[@"path"]];
            else if([action isEqual:@"files-toggle"]){NSArray *entries=[picker valueForKey:@"entries"];NSUInteger row=NSNotFound;for(NSUInteger i=0;i<entries.count;i++)if([entries[i][@"name"] isEqual:command[@"name"]]){row=i;break;}if(row==NSNotFound)[NSException raise:@"MissingFile" format:@"%@",command[@"name"]];[picker tableView:[picker tableView] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];}
            else if([action isEqual:@"files-done"])[picker performSelector:@selector(finishSelection)];
            else if([action isEqual:@"files-root"])[nav popToRootViewControllerAnimated:NO];
            if([picker respondsToSelector:@selector(updateSelection)])result[@"pickerSelected"]=@([[picker valueForKey:@"selectedURLs"] count]);
        }
        else if([action isEqual:@"clear"])[app performSelector:@selector(clearSelection)];
        else if([action isEqual:@"rotate"])[[UIDevice currentDevice] setValue:command[@"orientation"] forKey:@"orientation"];
        else if([action isEqual:@"send-selection"]){[app performSelector:@selector(addPeer:) withObject:command[@"peer"]];[[app valueForKey:@"hostField"] setText:command[@"peer"][@"ip"]];[app performSelector:@selector(sendSelected)];}

        else if([action isEqual:@"media-picker"])[app performSelector:@selector(choosePhoto)];
        else if([action hasPrefix:@"media-"]){
            UINavigationController *nav=(id)window.rootViewController.modalViewController;id picker=nav.topViewController;
            if([action isEqual:@"media-fixture"]){
                NSData *bytes=[NSData dataWithContentsOfFile:[folder stringByAppendingPathComponent:@".compat-media-fixture.bin"]];if(!bytes.length)[NSException raise:@"MissingFixture" format:@"No fixture"];
                NSMutableArray *assets=[NSMutableArray array];NSMutableDictionary *selected=[NSMutableDictionary dictionary];NSMutableArray *urls=[NSMutableArray array];
                for(NSUInteger i=0;i<2;i++){LSFixtureRepresentation *rep=[LSFixtureRepresentation new];rep.bytes=bytes;rep.filename=i?@"Fixture-B.mov":@"Fixture-A.jpg";rep.mode=[command[@"mode"] isEqual:@"slow"]?2:([command[@"mode"] isEqual:@"fail"] && i==1?1:0);LSFixtureAsset *asset=[LSFixtureAsset new];asset.representation=rep;[assets addObject:asset];selected[rep.url]=asset;[urls addObject:rep.url];}
                [picker setValue:assets forKey:@"assets"];[picker setValue:[NSNull null] forKey:@"group"];[picker setValue:selected forKey:@"selectedAssets"];[picker setValue:urls forKey:@"selectedURLs"];[picker performSelector:@selector(updateSelection)];[[picker tableView] reloadData];
            }
            else if([action isEqual:@"media-album"]){NSArray *groups=[picker valueForKey:@"groups"];[picker performSelector:@selector(openGroup:) withObject:groups[[command[@"index"] unsignedIntegerValue]]];}
            else if([action isEqual:@"media-toggle"]){UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];button.tag=[command[@"index"] integerValue];[picker performSelector:@selector(tapAsset:) withObject:button];}
            else if([action isEqual:@"media-all"])[picker performSelector:@selector(selectAll)];
            else if([action isEqual:@"media-done"])[picker performSelector:@selector(finishSelection)];
            else if([action isEqual:@"media-cancel"])[picker performSelector:@selector(close)];
            else if([action isEqual:@"media-back"])[nav popViewControllerAnimated:NO];
            else if([action isEqual:@"media-reference"]){
                ALAsset *asset=[picker valueForKey:@"assets"][[command[@"index"] unsignedIntegerValue]];ALAssetRepresentation *representation=asset.defaultRepresentation;
                if(representation.size<=0 || representation.size>1024*1024)[NSException raise:@"ReferenceSize" format:@"Synthetic fixture only"];
                NSMutableData *bytes=[NSMutableData dataWithLength:(NSUInteger)representation.size];NSError *error=nil;NSUInteger read=[representation getBytes:bytes.mutableBytes fromOffset:0 length:bytes.length error:&error];if(error || read!=bytes.length)[NSException raise:@"ReferenceRead" format:@"Read failed"];
                [bytes writeToFile:[folder stringByAppendingPathComponent:@".compat-media-reference.bin"] atomically:YES];
            }
        }
        else if([action isEqual:@"dismiss"])[window.rootViewController ls_dismissViewControllerAnimated:NO completion:nil];
        else if([action isEqual:@"accept"])[app performSelector:@selector(acceptReceive)];
        else if([action isEqual:@"reject"])[app performSelector:@selector(rejectReceive)];
        else if([action isEqual:@"close-receive"])[app performSelector:@selector(closeReceive)];
        else if([action isEqual:@"send"]){[app performSelector:@selector(addPeer:) withObject:command[@"peer"]];[app performSelector:@selector(sendFile:toHost:) withObject:command[@"file"] withObject:command[@"peer"][@"ip"]];}
        else if([action isEqual:@"alias-prompt"])[app performSelector:@selector(editAlias)];
        LSReceiver *receiver=[app valueForKey:@"receiver"];
        result[@"ready"]=@(receiver.ready);result[@"info"]=[receiver deviceInfo];
        result[@"idiom"]=@(UI_USER_INTERFACE_IDIOM());result[@"screenScale"]=@([UIScreen mainScreen].scale);
        id media=[(UINavigationController *)window.rootViewController.modalViewController topViewController];
        if([media isKindOfClass:NSClassFromString(@"LSMediaPicker")]){
            NSArray *groups=[media valueForKey:@"groups"],*assets=[media valueForKey:@"assets"];result[@"mediaGroupCount"]=@(groups.count);result[@"mediaSelected"]=@([[media valueForKey:@"selectedURLs"] count]);result[@"mediaExporting"]=[media valueForKey:@"exporting"];result[@"mediaStatus"]=[[media valueForKey:@"status"] text]?:@"";
            result[@"mediaAssetCount"]=@(assets.count);NSMutableArray *items=[NSMutableArray array];if([command[@"inspectMedia"] boolValue])for(ALAsset *asset in assets){ALAssetRepresentation *rep=asset.defaultRepresentation;[items addObject:@{@"type":[asset valueForProperty:ALAssetPropertyType]?:@"",@"size":@(rep.size),@"uti":rep.UTI?:@""}];}result[@"mediaItems"]=items;
            result[@"mediaFrame"]=NSStringFromCGRect([[media view] bounds]);
        }
        result[@"rootFrame"]=NSStringFromCGRect(window.rootViewController.view.frame);
        result[@"contentFrame"]=NSStringFromCGRect([[app valueForKey:@"content"] frame]);
        result[@"status"]=[[app valueForKey:@"statusLabel"] text]?:@"";
        result[@"phase"]=[app valueForKey:@"receiveState"][@"phase"]?:@"";
        result[@"selectedFiles"]=[app valueForKey:@"selectedFiles"]?:@[];
        result[@"sending"]=[app valueForKey:@"sending"];
        result[@"orientation"]=@([UIApplication sharedApplication].statusBarOrientation);
        result[@"selectedFile"]=[app valueForKey:@"selectedFile"]?:@"";
        result[@"photoResults"]=[app valueForKey:@"photoResults"]?:@{};
        result[@"history"]=[app valueForKey:@"history"]?:@[];
        result[@"modal"]=NSStringFromClass([window.rootViewController.modalViewController class])?:@"";
        if([command[@"screenshot"] boolValue]){UIGraphicsBeginImageContextWithOptions(window.bounds.size,NO,[command[@"renderScale"] doubleValue]);for(UIWindow *w in [UIApplication sharedApplication].windows){CGContextRef c=UIGraphicsGetCurrentContext();CGContextSaveGState(c);CGContextTranslateCTM(c,w.frame.origin.x-window.frame.origin.x,w.frame.origin.y-window.frame.origin.y);[w.layer renderInContext:c];CGContextRestoreGState(c);}[UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext()) writeToFile:[folder stringByAppendingPathComponent:@".compat-screen.png"] atomically:YES];UIGraphicsEndImageContext();}
    } @catch(NSException *error){result[@"exception"]=error.description;}
    [result writeToFile:[folder stringByAppendingPathComponent:@".compat-result.plist"] atomically:YES];
    [UIApplication sharedApplication].idleTimerDisabled=YES;
}
@end
void LSStartDiagnostics(id app) {
    LSUIDiagnostics *test=[LSUIDiagnostics new];test.app=app;
    test.timer=[NSTimer scheduledTimerWithTimeInterval:.2 target:test selector:@selector(tick) userInfo:nil repeats:YES];
    [UIApplication sharedApplication].idleTimerDisabled=YES;
}
