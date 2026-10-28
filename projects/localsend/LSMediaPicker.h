#import <UIKit/UIKit.h>
@interface LSMediaPicker : UITableViewController
- (id)initWithDocuments:(NSString *)documents dark:(BOOL)dark accent:(NSInteger)accent animations:(BOOL)animations selection:(void (^)(NSArray *names))selection;
@end
