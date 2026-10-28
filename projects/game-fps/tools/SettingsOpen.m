#import <UIKit/UIKit.h>
#import <dlfcn.h>
static void Tables(UIView *v,NSMutableArray *a){if([v isKindOfClass:[UITableView class]])[a addObject:v];for(UIView *s in v.subviews)Tables(s,a);}
__attribute__((constructor))static void Open(void){
 if(![[NSBundle mainBundle].bundleIdentifier isEqual:@"com.apple.Preferences"])return;
 Dl_info im;if(!dladdr((void*)&Open,&im)||!dlopen(im.dli_fname,RTLD_LAZY|RTLD_LOCAL|RTLD_NODELETE))return;
 dispatch_async(dispatch_get_main_queue(),^{
  NSAutoreleasePool *pool=[NSAutoreleasePool new];NSMutableArray *tables=[NSMutableArray array];for(UIWindow *w in [UIApplication sharedApplication].windows)Tables(w,tables);
  NSMutableDictionary *result=[NSMutableDictionary dictionaryWithObject:@NO forKey:@"opened"];
  for(UITableView *t in tables){id<UITableViewDataSource>d=t.dataSource;id<UITableViewDelegate>delegate=t.delegate;if(!d||![delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)])continue;
   NSInteger sections=[d respondsToSelector:@selector(numberOfSectionsInTableView:)]?[d numberOfSectionsInTableView:t]:1;if(sections<0||sections>100)continue;
   for(NSInteger s=0;s<sections;s++){NSInteger rows=[d tableView:t numberOfRowsInSection:s];if(rows<0||rows>300)continue;
    for(NSInteger r=0;r<rows;r++){NSIndexPath *path=[NSIndexPath indexPathForRow:r inSection:s];UITableViewCell *cell=[d tableView:t cellForRowAtIndexPath:path];
     if(![cell.textLabel.text isEqual:@"Legacy Game FPS"])continue;
     result[@"tableController"]=NSStringFromClass([delegate class]);result[@"section"]=@(s);result[@"row"]=@(r);result[@"opened"]=@YES;
     [t scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
     if([delegate respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)]){path=[delegate tableView:t willSelectRowAtIndexPath:path];if(!path){result[@"opened"]=@NO;goto done;}}
     [t selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];[delegate tableView:t didSelectRowAtIndexPath:path];goto done;
    }
   }
  }
 done:
  [[NSJSONSerialization dataWithJSONObject:result options:0 error:NULL] writeToFile:@"/var/mobile/Library/Caches/gamefps-settings-ui.json" atomically:YES];[pool drain];
 });
}
