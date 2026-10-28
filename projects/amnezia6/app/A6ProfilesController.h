#import <UIKit/UIKit.h>
@interface A6ProfilesController : UITableViewController <UIActionSheetDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UIPopoverControllerDelegate> {
    NSArray *_rows; BOOL _working; UIPopoverController *_popover;
}
- (void)importData:(NSData *)data name:(NSString *)name;
- (void)importURL:(NSURL *)url;
@end
