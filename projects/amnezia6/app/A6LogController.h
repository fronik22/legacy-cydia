#import <UIKit/UIKit.h>

/* Read-only viewer for the daemon log. */
@interface A6LogController : UIViewController <UIAlertViewDelegate> {
    UITextView *_textView;
    NSTimer *_timer;
}
@end
