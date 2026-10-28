#import <UIKit/UIKit.h>
#include <notify.h>
@interface PSSpecifier:NSObject
-(id)propertyForKey:(NSString*)key;
@end
@interface PSListController:UIViewController
-(NSArray*)loadSpecifiersFromPlistName:(NSString*)name target:(id)target;
-(void)setSpecifiers:(NSArray*)specifiers;
@end
@interface LegacyGameFPSPrefs:PSListController{NSArray*_items;}
@end
@implementation LegacyGameFPSPrefs
-(NSArray*)specifiers{if(!_items){_items=[[self loadSpecifiersFromPlistName:@"Root" target:self]retain];[super setSpecifiers:_items];}return _items;}
-(NSString*)path:(PSSpecifier*)s{return[[s propertyForKey:@"defaults"]isEqual:@"com.local.perfoverlay"]?@"/var/mobile/Library/Preferences/com.local.perfoverlay.plist":@"/var/mobile/Library/Preferences/com.local.legacygamefps.plist";}
-(id)readPreferenceValue:(PSSpecifier*)s{id v=[[NSDictionary dictionaryWithContentsOfFile:[self path:s]]objectForKey:[s propertyForKey:@"key"]];return[[s propertyForKey:@"validValues"]containsObject:v]?v:[s propertyForKey:@"default"];}
-(void)setPreferenceValue:(id)v specifier:(PSSpecifier*)s{if(![[s propertyForKey:@"validValues"]containsObject:v])return;NSDictionary*old=[NSDictionary dictionaryWithContentsOfFile:[self path:s]];NSMutableDictionary*d=old?[NSMutableDictionary dictionaryWithDictionary:old]:[NSMutableDictionary dictionary];d[[s propertyForKey:@"key"]]=v;if([d writeToFile:[self path:s]atomically:YES])notify_post([[s propertyForKey:@"defaults"]isEqual:@"com.local.perfoverlay"]?"com.local.perfoverlay.settings":"com.local.legacygamefps.changed");}
-(void)dealloc{[_items release];[super dealloc];}
@end
