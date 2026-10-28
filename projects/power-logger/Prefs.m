#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#include <notify.h>
@interface PSSpecifier:NSObject
-(id)propertyForKey:(NSString*)key;-(void)setProperty:(id)value forKey:(NSString*)key;
@end
@interface PSListController:UIViewController
-(NSArray*)loadSpecifiersFromPlistName:(NSString*)name target:(id)target;-(void)setSpecifiers:(NSArray*)specifiers;-(void)reloadSpecifiers;
@end
@interface LegacyPowerPrefs:PSListController{NSArray*_powerSpecifiers;}
@end
@implementation LegacyPowerPrefs
-(NSArray*)specifiers{
 if(!_powerSpecifiers){
  _powerSpecifiers=[[self loadSpecifiersFromPlistName:@"Root"target:self]retain];
  NSData*data=[NSData dataWithContentsOfFile:@"/var/mobile/Library/Logs/LegacyPower/status.json"];
  NSDictionary*d=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL]:nil;
  NSString*status=@"Logger has no status yet.";
  if([d isKindOfClass:[NSDictionary class]]){
   double age=[[NSDate date]timeIntervalSince1970]-[[d objectForKey:@"updated_epoch"]doubleValue];
   NSString*error=[d objectForKey:@"error"]?:@"";
   status=[NSString stringWithFormat:@"Last report: %@ • %@ • %.0fs ago\n%@\nLogs: /var/mobile/Library/Logs/LegacyPower/\nCPU is load, not per-app watts. USB charging prevents a battery-drain comparison.",[[d objectForKey:@"enabled"]boolValue]?@"Recording":@"Off",[d objectForKey:@"segment"]?:@"",MAX(0,age),error];
  }
  for(PSSpecifier*s in _powerSpecifiers)if([[s propertyForKey:@"id"]isEqual:@"Status"])[s setProperty:status forKey:@"footerText"];
  [super setSpecifiers:_powerSpecifiers];
 }return _powerSpecifiers;
}
-(id)readPreferenceValue:(PSSpecifier*)s{
 CFPreferencesAppSynchronize(CFSTR("com.local.legacypower"));id v=(id)CFPreferencesCopyAppValue((CFStringRef)[s propertyForKey:@"key"],CFSTR("com.local.legacypower"));return[v autorelease]?:[s propertyForKey:@"default"];
}
-(void)setPreferenceValue:(id)v specifier:(PSSpecifier*)s{
 NSString*k=[s propertyForKey:@"key"];if(![[NSArray arrayWithObjects:@"Enabled",@"Interval",@"Segment",nil]containsObject:k])return;
 CFPreferencesSetAppValue((CFStringRef)k,(CFPropertyListRef)v,CFSTR("com.local.legacypower"));CFPreferencesAppSynchronize(CFSTR("com.local.legacypower"));notify_post("com.local.legacypower.changed");
 [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshStatus) object:nil];
 [self performSelector:@selector(refreshStatus)withObject:nil afterDelay:.6];
}
-(void)refreshStatus{[_powerSpecifiers release];_powerSpecifiers=nil;[self reloadSpecifiers];}
-(void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];[self refreshStatus];}
-(void)dealloc{[_powerSpecifiers release];[super dealloc];}
@end
