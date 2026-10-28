#import "LSLocalization.h"
#import "LSFilesystemPicker.h"
#import "LSDesign.h"
@interface LSFilesystemPicker ()
@property(nonatomic,copy) NSString *directory;
@property(nonatomic,copy) NSString *documents;
@property(nonatomic,assign) BOOL dark;
@property(nonatomic,assign) NSInteger accent;
@property(nonatomic,assign) BOOL animations;
@property(nonatomic,copy) void (^selection)(NSArray *);
@property(nonatomic,strong) NSMutableArray *selectedURLs;
@property(nonatomic,strong) NSArray *entries;
@end
@implementation LSFilesystemPicker
- (id)initWithDirectory:(NSString *)directory documents:(NSString *)documents dark:(BOOL)dark accent:(NSInteger)accent animations:(BOOL)animations selection:(void (^)(NSArray *))selection {
    self=[super initWithStyle:UITableViewStylePlain];
    if(self){self.directory=[directory stringByStandardizingPath];self.documents=documents;self.dark=dark;self.accent=accent;self.animations=animations;self.selection=selection;self.entries=@[];self.selectedURLs=[NSMutableArray array];}
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=[self.directory isEqual:@"/"]?LSL(@"Файлы /"):self.directory.lastPathComponent;
    self.tableView.backgroundColor=LSBackground(self.dark);self.tableView.separatorColor=[LSTextColor(self.dark) colorWithAlphaComponent:.12];self.tableView.rowHeight=60;
    if(self.navigationController.viewControllers.count==1)self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:LSL(@"Отмена") style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:LSL(@"Добавить") style:UIBarButtonItemStyleDone target:self action:@selector(finishSelection)];
    [self updateSelection];
    UIBarButtonItem *space=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    self.toolbarItems=@[[[UIBarButtonItem alloc] initWithTitle:LSL(@"Корень") style:UIBarButtonItemStylePlain target:self action:@selector(openRoot)],space,[[UIBarButtonItem alloc] initWithTitle:LSL(@"Мои файлы") style:UIBarButtonItemStylePlain target:self action:@selector(openDocuments)],[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],[[UIBarButtonItem alloc] initWithTitle:LSL(@"Путь…") style:UIBarButtonItemStylePlain target:self action:@selector(enterPath)]];
    UILabel *path=[[UILabel alloc] initWithFrame:CGRectMake(0,0,self.tableView.bounds.size.width,36)];path.font=[UIFont systemFontOfSize:11];path.textColor=[UIColor grayColor];path.backgroundColor=LSBackground(self.dark);path.textAlignment=NSTextAlignmentCenter;path.lineBreakMode=NSLineBreakByTruncatingMiddle;path.text=self.directory;path.autoresizingMask=UIViewAutoresizingFlexibleWidth;self.tableView.tableHeaderView=path;
    UIActivityIndicatorView *spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:self.dark?UIActivityIndicatorViewStyleWhite:UIActivityIndicatorViewStyleGray];[spinner startAnimating];self.tableView.backgroundView=spinner;
    NSString *directory=self.directory;__weak LSFilesystemPicker *weakSelf=self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSFileManager *manager=[NSFileManager defaultManager];NSError *error=nil;NSArray *names=[manager contentsOfDirectoryAtPath:directory error:&error];NSMutableArray *items=[NSMutableArray array];
        // List this directory only, including dot files. No recursive scan or
        // restriction to the app's Documents folder; OS permissions still apply.
        for(NSString *name in names){NSString *path=[directory stringByAppendingPathComponent:name];BOOL folder=NO;[manager fileExistsAtPath:path isDirectory:&folder];NSDictionary *attributes=[manager attributesOfItemAtPath:path error:nil];NSString *type=attributes[NSFileType];if([type isEqual:NSFileTypeSymbolicLink])type=[manager attributesOfItemAtPath:[path stringByResolvingSymlinksInPath] error:nil][NSFileType];BOOL regular=[type isEqual:NSFileTypeRegular];
            [items addObject:@{@"name":name,@"path":path,@"folder":@(folder),@"size":attributes[NSFileSize]?:@0,@"readable":@([manager isReadableFileAtPath:path]),@"regular":@(regular)}];}
        [items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){if([a[@"folder"] boolValue]!=[b[@"folder"] boolValue])return [a[@"folder"] boolValue]?NSOrderedAscending:NSOrderedDescending;return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
        dispatch_async(dispatch_get_main_queue(),^{LSFilesystemPicker *picker=weakSelf;if(!picker)return;picker.entries=items;[picker.tableView reloadData];if(items.count){picker.tableView.backgroundView=nil;}else{UILabel *empty=[[UILabel alloc] init];empty.numberOfLines=0;empty.textAlignment=NSTextAlignmentCenter;empty.font=[UIFont systemFontOfSize:14];empty.textColor=LSTextColor(picker.dark);empty.backgroundColor=[UIColor clearColor];empty.text=error?[NSString stringWithFormat:LSL(@"Не удалось открыть папку\n%@\n\nДля защищённых папок нужны\nправа вне песочницы приложения."),error.localizedDescription]:LSL(@"Папка пуста");picker.tableView.backgroundView=empty;}});
    });
}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self.navigationController setToolbarHidden:NO animated:NO];[self updateSelection];[self.tableView reloadData];}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad || orientation!=UIInterfaceOrientationPortraitUpsideDown;}
- (BOOL)shouldAutorotate {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad?UIInterfaceOrientationMaskAll:UIInterfaceOrientationMaskAllButUpsideDown;}
- (void)updateSelection {self.navigationItem.rightBarButtonItem.title=[NSString stringWithFormat:LSL(@"Добавить (%lu)"),(unsigned long)self.selectedURLs.count];self.navigationItem.rightBarButtonItem.enabled=self.selectedURLs.count>0;}
- (void)finishSelection {
    if(!self.selectedURLs.count)return;
    NSArray *urls=[self.selectedURLs copy];void (^selection)(NSArray *)=self.selection;
    [self ls_dismissViewControllerAnimated:self.animations completion:^{if(selection)selection(urls);}];
}
- (void)close {[self ls_dismissViewControllerAnimated:self.animations completion:nil];}
- (void)openDirectory:(NSString *)path {
    path=[path stringByStandardizingPath];if([path isEqual:self.directory])return;
    LSFilesystemPicker *child=[[LSFilesystemPicker alloc] initWithDirectory:path documents:self.documents dark:self.dark accent:self.accent animations:self.animations selection:self.selection];child.selectedURLs=self.selectedURLs;[self.navigationController pushViewController:child animated:self.animations];
}
- (void)openRoot {[self.navigationController popToRootViewControllerAnimated:self.animations];}
- (void)openDocuments {[self openDirectory:self.documents];}
- (void)enterPath {UIAlertView *alert=[[LSLegacyInputAlert alloc] initWithTitle:LSL(@"Открыть путь") message:LSL(@"Абсолютный путь к папке") delegate:self cancelButtonTitle:LSL(@"Отмена") otherButtonTitles:LSL(@"Открыть"),nil];alert.alertViewStyle=UIAlertViewStylePlainTextInput;UITextField *field=[alert textFieldAtIndex:0];field.text=self.directory;field.autocorrectionType=UITextAutocorrectionTypeNo;field.autocapitalizationType=UITextAutocapitalizationTypeNone;[alert show];}
- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index {if(index!=1)return;NSString *path=[[[alert textFieldAtIndex:0] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];if([path hasPrefix:@"/"])[self openDirectory:path];}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return self.entries.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"FilesystemEntry"];
    if(!cell){cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"FilesystemEntry"];cell.textLabel.font=[UIFont systemFontOfSize:15];cell.detailTextLabel.font=[UIFont systemFontOfSize:12];cell.textLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.selectionStyle=UITableViewCellSelectionStyleNone;cell.backgroundColor=LSBackground(self.dark);cell.textLabel.textColor=LSTextColor(self.dark);cell.detailTextLabel.textColor=[UIColor grayColor];}
    NSDictionary *item=self.entries[indexPath.row];BOOL folder=[item[@"folder"] boolValue];cell.textLabel.text=item[@"name"];long long bytes=[item[@"size"] longLongValue];cell.detailTextLabel.text=![item[@"readable"] boolValue]?LSL(@"Нет доступа"):(folder?LSL(@"Папка"):(bytes<1024?[NSString stringWithFormat:LSL(@"%lld Б"),bytes]:[NSString stringWithFormat:@"%.1f %@",bytes/(bytes<1048576?1024.0:1048576.0),bytes<1048576?LSL(@"КБ"):LSL(@"МБ")]));cell.imageView.image=LSIcon(folder?@"folder":@"file",LSAccent(self.accent),25);cell.accessoryType=folder?UITableViewCellAccessoryDisclosureIndicator:([self.selectedURLs containsObject:[NSURL fileURLWithPath:[item[@"path"] stringByResolvingSymlinksInPath]]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone);return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item=self.entries[indexPath.row];
    if([item[@"folder"] boolValue]){[self openDirectory:item[@"path"]];return;}
    if(![item[@"regular"] boolValue]){[[[UIAlertView alloc] initWithTitle:LSL(@"Это не обычный файл") message:LSL(@"Системные объекты, сокеты и устройства отправлять нельзя.") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];return;}
    if(![item[@"readable"] boolValue]){[[[UIAlertView alloc] initWithTitle:LSL(@"Нет доступа к файлу") message:LSL(@"iOS не разрешает приложению читать этот файл. Для доступа к защищённым папкам нужны права вне песочницы.") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];return;}
    NSURL *url=[NSURL fileURLWithPath:[item[@"path"] stringByResolvingSymlinksInPath]];if([self.selectedURLs containsObject:url])[self.selectedURLs removeObject:url];else [self.selectedURLs addObject:url];[self updateSelection];[tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
}
@end
