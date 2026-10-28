#import "LSLegacy.h"
NSString *LSUUIDString(void) {
    CFUUIDRef uuid=CFUUIDCreate(NULL);
    NSString *value=CFBridgingRelease(CFUUIDCreateString(NULL,uuid));
    CFRelease(uuid);return value;
}
void LSSetMinimumScale(UILabel *label,CGFloat scale) {
    if([label respondsToSelector:@selector(setMinimumScaleFactor:)])label.minimumScaleFactor=scale;
    else label.minimumFontSize=label.font.pointSize*scale;
}
@implementation LSLegacyInputAlert {
    UITextField *_legacyField;
}
- (void)setAlertViewStyle:(UIAlertViewStyle)style {
    if([UIAlertView instancesRespondToSelector:@selector(setAlertViewStyle:)]){[super setAlertViewStyle:style];return;}
    if(!_legacyField){
        self.message=[(self.message?:@"") stringByAppendingString:@"\n\n"];
        _legacyField=[[UITextField alloc] initWithFrame:CGRectZero];
        _legacyField.borderStyle=UITextBorderStyleRoundedRect;
        _legacyField.backgroundColor=[UIColor whiteColor];
        _legacyField.autoresizingMask=UIViewAutoresizingFlexibleWidth;
        [self addSubview:_legacyField];
    }
}
- (UITextField *)textFieldAtIndex:(NSInteger)index {
    return _legacyField ? (index==0?_legacyField:nil) : [super textFieldAtIndex:index];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    if(_legacyField)_legacyField.frame=CGRectMake(14,self.bounds.size.height-88,self.bounds.size.width-28,30);
}
@end
@implementation UIViewController (LSLegacyPresentation)
- (void)ls_presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    if([self respondsToSelector:@selector(presentViewController:animated:completion:)]){[self presentViewController:controller animated:animated completion:completion];return;}
    [self presentModalViewController:controller animated:animated];
    if(completion)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,animated?350000000:0),dispatch_get_main_queue(),completion);
}
- (void)ls_dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    if([self respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]){[self dismissViewControllerAnimated:animated completion:completion];return;}
    [self dismissModalViewControllerAnimated:animated];
    if(completion)dispatch_after(dispatch_time(DISPATCH_TIME_NOW,animated?350000000:0),dispatch_get_main_queue(),completion);
}
@end
