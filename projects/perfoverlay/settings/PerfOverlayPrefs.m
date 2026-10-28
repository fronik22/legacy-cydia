#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#include <notify.h>

@interface PSSpecifier : NSObject
- (id)propertyForKey:(NSString *)key;
@end
@interface PSListController : UIViewController
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (void)setSpecifiers:(NSArray *)specifiers;
@end
@interface PerfOverlayPrefsController : PSListController {
    NSArray *_perfSpecifiers;
}
@end
@implementation PerfOverlayPrefsController
- (NSArray *)specifiers {
    if(!_perfSpecifiers){
        _perfSpecifiers=[[self loadSpecifiersFromPlistName:@"Root" target:self] retain];
        [super setSpecifiers:_perfSpecifiers];
    }
    return _perfSpecifiers;
}
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key=[specifier propertyForKey:@"key"];
    CFPreferencesAppSynchronize(CFSTR("com.local.perfoverlay"));
    id value=(id)CFPreferencesCopyAppValue((CFStringRef)key,CFSTR("com.local.perfoverlay"));
    return [value autorelease]?:[specifier propertyForKey:@"default"];
}
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key=[specifier propertyForKey:@"key"];
    CFPreferencesSetAppValue((CFStringRef)key,(CFPropertyListRef)value,CFSTR("com.local.perfoverlay"));
    CFPreferencesAppSynchronize(CFSTR("com.local.perfoverlay"));
    notify_post("com.local.perfoverlay.settings");
}
- (void)dealloc {[_perfSpecifiers release];[super dealloc];}
@end
