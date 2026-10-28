#import "LSMediaPicker.h"
#import "LSDesign.h"
#import "LSLocalization.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface LSMediaPicker ()
@property(nonatomic,strong) ALAssetsLibrary *library;
@property(nonatomic,strong) ALAssetsGroup *group;
@property(nonatomic,strong) NSMutableArray *groups;
@property(nonatomic,strong) NSMutableArray *assets;
@property(nonatomic,strong) NSMutableDictionary *selectedAssets;
@property(nonatomic,strong) NSMutableArray *selectedURLs;
@property(nonatomic,copy) NSString *documents;
@property(nonatomic,copy) void (^selection)(NSArray *);
@property(nonatomic,assign) BOOL dark;
@property(nonatomic,assign) NSInteger accent;
@property(nonatomic,assign) BOOL animations;
@property(nonatomic,assign) BOOL exporting;
@property(atomic,assign) BOOL cancelled;
@property(nonatomic,strong) UIBarButtonItem *selectAllButton;
@property(nonatomic,strong) UILabel *status;
@end
@implementation LSMediaPicker
- (id)initWithDocuments:(NSString *)documents dark:(BOOL)dark accent:(NSInteger)accent animations:(BOOL)animations selection:(void (^)(NSArray *))selection {
    self=[super initWithStyle:UITableViewStylePlain];
    if(self){self.documents=documents;self.dark=dark;self.accent=accent;self.animations=animations;self.selection=selection;self.library=[ALAssetsLibrary new];self.groups=[NSMutableArray array];self.assets=[NSMutableArray array];self.selectedAssets=[NSMutableDictionary dictionary];self.selectedURLs=[NSMutableArray array];}
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=self.group?[self.group valueForProperty:ALAssetsGroupPropertyName]:LSL(@"Фото и видео");
    self.tableView.backgroundColor=LSBackground(self.dark);self.tableView.separatorStyle=self.group?UITableViewCellSeparatorStyleNone:UITableViewCellSeparatorStyleSingleLine;
    if(self.navigationController.viewControllers.count==1)self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:LSL(@"Отмена") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleDone target:self action:@selector(finishSelection)];
    self.selectAllButton=[[UIBarButtonItem alloc] initWithTitle:LSL(@"Выбрать все") style:UIBarButtonItemStylePlain target:self action:@selector(selectAll)];
    UIBarButtonItem *cancel=[[UIBarButtonItem alloc] initWithTitle:LSL(@"Отмена") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.toolbarItems=self.group?@[cancel,[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],self.selectAllButton]:@[cancel];
    self.status=[[UILabel alloc] initWithFrame:CGRectMake(0,0,self.tableView.bounds.size.width,44)];self.status.autoresizingMask=UIViewAutoresizingFlexibleWidth;self.status.textAlignment=NSTextAlignmentCenter;self.status.font=[UIFont systemFontOfSize:13];self.status.textColor=LSTextColor(self.dark);self.status.backgroundColor=LSBackground(self.dark);self.status.numberOfLines=2;self.status.text=LSL(@"Загрузка…");self.tableView.tableHeaderView=self.status;
    [self updateSelection];
    __weak LSMediaPicker *weakSelf=self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        LSMediaPicker *picker=weakSelf;if(!picker)return;
        if(picker.group){
            NSMutableArray *assets=[NSMutableArray array];
            [picker.group enumerateAssetsUsingBlock:^(ALAsset *asset,NSUInteger index,BOOL *stop){if(asset && ([ [asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypePhoto] || [[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]))[assets addObject:asset];}];
            dispatch_async(dispatch_get_main_queue(),^{picker.assets=assets;picker.status.text=assets.count?@"":LSL(@"Нет фото и видео");[picker updateSelection];[picker.tableView reloadData];});
        }else{
            [picker.library enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group,BOOL *stop){
                if(group){[group setAssetsFilter:[ALAssetsFilter allAssets]];dispatch_async(dispatch_get_main_queue(),^{[picker.groups addObject:group];[picker.tableView reloadData];});}
                else dispatch_async(dispatch_get_main_queue(),^{picker.status.text=picker.groups.count?LSL(@"Откройте альбом и отметьте файлы"):LSL(@"Нет фото и видео");});
            }failureBlock:^(NSError *error){dispatch_async(dispatch_get_main_queue(),^{picker.status.text=error.code==ALAssetsLibraryAccessGloballyDeniedError?LSL(@"Для доступа к фото включите геолокацию в Настройках."):error.localizedDescription;});}];
        }
    });
}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self.navigationController setToolbarHidden:self.group==nil animated:NO];[self updateSelection];[self.tableView reloadData];}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad || orientation!=UIInterfaceOrientationPortraitUpsideDown;}
- (BOOL)shouldAutorotate {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad?UIInterfaceOrientationMaskAll:UIInterfaceOrientationMaskAllButUpsideDown;}
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {[super didRotateFromInterfaceOrientation:orientation];[self.tableView reloadData];}
- (NSUInteger)columns {return MAX(3,(NSUInteger)(self.tableView.bounds.size.width/100));}
- (void)updateSelection {
    self.navigationItem.rightBarButtonItem.title=[NSString stringWithFormat:LSL(@"Добавить (%lu)"),(unsigned long)self.selectedURLs.count];self.navigationItem.rightBarButtonItem.enabled=self.selectedURLs.count>0 && !self.exporting;
    BOOL all=self.assets.count>0;for(ALAsset *asset in self.assets)if(!self.selectedAssets[asset.defaultRepresentation.url]){all=NO;break;}
    self.selectAllButton.title=all?LSL(@"Снять выделение"):LSL(@"Выбрать все");self.selectAllButton.enabled=self.assets.count>0 && !self.exporting;
}
- (void)openGroup:(ALAssetsGroup *)group {
    LSMediaPicker *child=[[LSMediaPicker alloc] initWithDocuments:self.documents dark:self.dark accent:self.accent animations:self.animations selection:self.selection];child.library=self.library;child.group=group;child.selectedAssets=self.selectedAssets;child.selectedURLs=self.selectedURLs;[self.navigationController pushViewController:child animated:self.animations];
}
- (void)toggleAssetAtIndex:(NSUInteger)index {
    if(self.exporting || index>=self.assets.count)return;
    ALAsset *asset=self.assets[index];NSURL *url=asset.defaultRepresentation.url;if(!url)return;
    if(self.selectedAssets[url]){[self.selectedAssets removeObjectForKey:url];[self.selectedURLs removeObject:url];}else{self.selectedAssets[url]=asset;[self.selectedURLs addObject:url];}
    [self updateSelection];[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index/self.columns inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
}
- (void)tapAsset:(UIButton *)button {[self toggleAssetAtIndex:button.tag];}
- (void)selectAll {
    if(self.exporting)return;
    BOOL all=self.assets.count>0;for(ALAsset *asset in self.assets)if(!self.selectedAssets[asset.defaultRepresentation.url]){all=NO;break;}
    for(ALAsset *asset in self.assets){NSURL *url=asset.defaultRepresentation.url;if(!url)continue;if(all){[self.selectedAssets removeObjectForKey:url];[self.selectedURLs removeObject:url];}else if(!self.selectedAssets[url]){self.selectedAssets[url]=asset;[self.selectedURLs addObject:url];}}
    [self updateSelection];[self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return self.group?(self.assets.count+self.columns-1)/self.columns:self.groups.count;}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {return self.group?floor(tableView.bounds.size.width/self.columns):64;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:self.group?@"MediaGrid":@"MediaAlbum"];
    if(!cell)cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:self.group?@"MediaGrid":@"MediaAlbum"];
    cell.backgroundColor=LSBackground(self.dark);cell.selectionStyle=UITableViewCellSelectionStyleNone;
    if(!self.group){ALAssetsGroup *group=self.groups[indexPath.row];cell.textLabel.text=[group valueForProperty:ALAssetsGroupPropertyName];cell.textLabel.textColor=LSTextColor(self.dark);cell.detailTextLabel.text=[NSString stringWithFormat:@"%ld",(long)group.numberOfAssets];cell.detailTextLabel.textColor=[UIColor grayColor];CGImageRef poster=group.posterImage;cell.imageView.image=poster?[UIImage imageWithCGImage:poster]:nil;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;}
    for(UIView *view in [cell.contentView.subviews copy])[view removeFromSuperview];
    CGFloat width=floor(tableView.bounds.size.width/self.columns);
    for(NSUInteger col=0;col<self.columns;col++){
        NSUInteger index=indexPath.row*self.columns+col;if(index>=self.assets.count)break;ALAsset *asset=self.assets[index];BOOL selected=self.selectedAssets[asset.defaultRepresentation.url]!=nil;
        UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];button.tag=index;button.frame=CGRectMake(col*width+4,4,width-8,width-8);button.clipsToBounds=YES;button.layer.borderWidth=selected?3:0;button.layer.borderColor=LSAccent(self.accent).CGColor;
        CGImageRef thumb=asset.thumbnail;if(thumb)[button setImage:[UIImage imageWithCGImage:thumb] forState:UIControlStateNormal];button.imageView.contentMode=UIViewContentModeScaleAspectFill;[button addTarget:self action:@selector(tapAsset:) forControlEvents:UIControlEventTouchUpInside];
        BOOL video=[[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo];button.accessibilityLabel=[NSString stringWithFormat:@"%@ %lu",video?LSL(@"Видео"):LSL(@"Фото"),(unsigned long)index+1];button.accessibilityValue=selected?LSL(@"Выбрано"):LSL(@"Не выбрано");
        UILabel *badge=[[UILabel alloc] initWithFrame:CGRectMake(0,button.bounds.size.height-22,button.bounds.size.width,22)];badge.backgroundColor=[UIColor colorWithWhite:0 alpha:.6];badge.textColor=[UIColor whiteColor];badge.font=[UIFont boldSystemFontOfSize:13];badge.textAlignment=NSTextAlignmentRight;
        if(video){NSInteger seconds=[[asset valueForProperty:ALAssetPropertyDuration] integerValue];badge.text=[NSString stringWithFormat:@"%@ %ld:%02ld ",selected?@"✓":@"▶",(long)seconds/60,(long)seconds%60];}else badge.text=selected?@"✓ ":@"○ ";[button addSubview:badge];[cell.contentView addSubview:button];
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {if(!self.group && !self.exporting)[self openGroup:self.groups[indexPath.row]];}
- (void)close {self.cancelled=YES;[self ls_dismissViewControllerAnimated:self.animations completion:nil];}
- (void)finishSelection {
    if(self.exporting || !self.selectedURLs.count)return;
    self.exporting=YES;self.tableView.userInteractionEnabled=NO;self.navigationItem.hidesBackButton=YES;[self updateSelection];
    NSArray *urls=[self.selectedURLs copy];NSDictionary *assets=[self.selectedAssets copy];NSString *batch=[@"Media-" stringByAppendingString:LSUUIDString()];NSString *folder=[self.documents stringByAppendingPathComponent:batch];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSMutableArray *names=[NSMutableArray array],*failures=[NSMutableArray array];NSError *directoryError=nil;BOOL created=[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:&directoryError];
        for(NSUInteger index=0;created && index<urls.count && !self.cancelled;index++){@autoreleasepool{
            ALAssetRepresentation *representation=[assets[urls[index]] defaultRepresentation];NSString *name=[representation respondsToSelector:@selector(filename)]?representation.filename.lastPathComponent:nil;
            if(!name.length || [@[@".",@".."] containsObject:name]){NSString *ext=representation.UTI.length?CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)representation.UTI,kUTTagClassFilenameExtension)):nil;name=[NSString stringWithFormat:@"Media-%04lu.%@",(unsigned long)index+1,ext.length?ext:@"bin"];}
            NSString *destination=[folder stringByAppendingPathComponent:name];if([[NSFileManager defaultManager] fileExistsAtPath:destination]){name=[NSString stringWithFormat:@"%@-%@",LSUUIDString(),name];destination=[folder stringByAppendingPathComponent:name];}
            dispatch_async(dispatch_get_main_queue(),^{self.status.text=[NSString stringWithFormat:LSL(@"Подготовка %lu/%lu"),(unsigned long)index+1,(unsigned long)urls.count];});
            NSError *error=nil;FILE *output=representation.size>0?fopen(destination.fileSystemRepresentation,"wb"):NULL;uint8_t *buffer=output?malloc(256*1024):NULL;long long offset=0;NSTimeInterval lastProgress=0;
            while(buffer && offset<representation.size && !self.cancelled){NSUInteger wanted=(NSUInteger)MIN((long long)(256*1024),representation.size-offset);NSUInteger got=[representation getBytes:buffer fromOffset:offset length:wanted error:&error];if(error || !got || got>wanted || fwrite(buffer,1,got,output)!=got)break;offset+=got;NSTimeInterval now=[NSDate timeIntervalSinceReferenceDate];if(now-lastProgress>=1){lastProgress=now;double fraction=(double)offset/representation.size;dispatch_async(dispatch_get_main_queue(),^{self.status.text=[NSString stringWithFormat:LSL(@"Подготовка %lu/%lu: %.0f%%"),(unsigned long)index+1,(unsigned long)urls.count,fraction*100];});}}
            free(buffer);BOOL closed=output && fclose(output)==0;BOOL ok=closed && offset==representation.size && !error && !self.cancelled;
            if(ok)[names addObject:[batch stringByAppendingPathComponent:name]];else{[[NSFileManager defaultManager] removeItemAtPath:destination error:nil];[failures addObject:name];}
        }}
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.cancelled){if(created)[[NSFileManager defaultManager] removeItemAtPath:folder error:nil];return;}
            if(!names.count && created)[[NSFileManager defaultManager] removeItemAtPath:folder error:nil];
            void (^selection)(NSArray *)=self.selection;
            [self ls_dismissViewControllerAnimated:self.animations completion:^{
                if(names.count && selection)selection(names);
                if(directoryError || failures.count)[[[UIAlertView alloc] initWithTitle:LSL(@"Не удалось подготовить файлы") message:directoryError.localizedDescription?:[failures componentsJoinedByString:@"\n"] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
            }];
        });
    });
}
@end
