#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface NSObject (PerfSettingsTest)
- (NSArray*)specifiers;
- (id)propertyForKey:(NSString*)key;
- (id)readPreferenceValue:(id)specifier;
- (NSInteger)numberOfGroups;
- (NSInteger)rowsForGroup:(NSInteger)group;
@end
int main(void) {
 NSAutoreleasePool *pool=[NSAutoreleasePool new];
 NSBundle *bundle=[NSBundle bundleWithPath:@"/Library/PreferenceBundles/PerfOverlayPrefs.bundle"];
 NSError *error=nil;BOOL loaded=[bundle loadAndReturnError:&error];
 printf("bundleLoaded=%d error=%s\n",loaded,[[error description] UTF8String]?:"");
 if(!loaded)return 1;
 Class type=NSClassFromString(@"PerfOverlayPrefsController");id controller=[[type alloc]init];
 NSArray *specifiers=[controller specifiers];printf("specifierCount=%lu\n",(unsigned long)specifiers.count);
 NSInteger groups=[controller numberOfGroups];printf("groupCount=%ld\n",(long)groups);
 unsigned rows=0;for(NSInteger i=0;i<groups;i++)rows+=[controller rowsForGroup:i];printf("tableRows=%u\n",rows);
 unsigned values=0;
 for(id spec in specifiers){NSString *key=[spec propertyForKey:@"key"];if(key){id value=[controller readPreferenceValue:spec];printf("%s=%s\n",key.UTF8String,[[value description] UTF8String]?:"nil");if(value)values++;}}
 [controller release];[pool drain];return values==11&&rows==11?0:2;
}
