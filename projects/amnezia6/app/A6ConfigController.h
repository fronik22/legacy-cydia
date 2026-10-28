#import <UIKit/UIKit.h>
@interface A6ConfigController : UIViewController <UITextViewDelegate> {
    UITextView *_textView; UILabel *_pathLabel; UITextField *_nameField;
    NSString *_identifier, *_initialConfig, *_initialName; BOOL _saving;
}
- (id)initWithIdentifier:(NSString *)identifier config:(NSString *)config name:(NSString *)name;
@end
