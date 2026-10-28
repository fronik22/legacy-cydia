#ifdef __OBJC__
#import <UIKit/UIKit.h>
@interface LSLegacyJSONSerialization : NSObject
+ (id)JSONObjectWithData:(NSData *)data options:(NSJSONReadingOptions)options error:(NSError **)error;
+ (NSData *)dataWithJSONObject:(id)object options:(NSJSONWritingOptions)options error:(NSError **)error;
@end
#define NSJSONSerialization LSLegacyJSONSerialization
NSString *LSUUIDString(void);
void LSSetMinimumScale(UILabel *label,CGFloat scale);
NSHTTPURLResponse *LSLegacyHTTPResponse(NSURL *url, NSInteger status, NSString *version, NSDictionary *headers);
@interface LSLegacyInputAlert : UIAlertView
@end
@interface UIViewController (LSLegacyPresentation)
- (void)ls_presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)ls_dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
@end
#endif
