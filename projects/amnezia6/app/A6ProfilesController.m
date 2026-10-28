#import "A6ProfilesController.h"
#import "A6Profiles.h"
#import "A6ConfigController.h"
#import "A6Import.h"
#import "A6QR.h"
#import <dispatch/dispatch.h>
@interface A6FilesController : UITableViewController {
    NSString *_directory; NSArray *_items; A6ProfilesController *_importer;
}
- (id)initWithDirectory:(NSString *)directory importer:(A6ProfilesController *)importer;
@end
@interface A6ProfilesController ()
- (void)showError:(NSString *)error;
- (void)addTapped:(id)sender;
- (void)pickImage:(UIImagePickerControllerSourceType)source;
@end
@implementation A6ProfilesController
- (id)init {if((self=[super initWithStyle:UITableViewStyleGrouped]))self.title=@"Серверы";return self;}
- (void)dealloc {[_rows release];[_popover release];[super dealloc];}
- (void)viewDidLoad {
    [super viewDidLoad];self.navigationItem.rightBarButtonItem=[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped:)]autorelease];self.navigationItem.leftBarButtonItem=nil;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];[_rows release];_rows=[[[A6Profiles shared]profiles]retain];[self.tableView reloadData];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    return [[A6Profiles shared]loadError]?:@"Нажмите сервер для выбора. Если VPN включён, он переподключится. Кнопка справа — изменить имя и настройки. Смахните неактивный профиль для удаления.";
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return [_rows count];}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"profile"];
    if(!cell)cell=[[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"profile"]autorelease];
    NSDictionary *row=[_rows objectAtIndex:path.row];BOOL active=[[row objectForKey:@"id"]isEqual:[[A6Profiles shared]activeIdentifier]];
    cell.textLabel.text=[NSString stringWithFormat:@"%@%@",active?@"✓ ":@"",[row objectForKey:@"name"]];cell.detailTextLabel.text=[row objectForKey:@"endpoint"];
    cell.accessoryType=UITableViewCellAccessoryDetailDisclosureButton;cell.selectionStyle=UITableViewCellSelectionStyleBlue;return cell;
}
- (void)tableView:(UITableView *)table accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)path {
    if(_working)return;A6ConfigController *editor=[[A6ConfigController alloc]initWithIdentifier:[[_rows objectAtIndex:path.row]objectForKey:@"id"]config:nil name:nil];[self.navigationController pushViewController:editor animated:YES];[editor release];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];if(_working)return;
    NSString *identifier=[[[_rows objectAtIndex:path.row]objectForKey:@"id"]copy];_working=YES;self.navigationItem.rightBarButtonItem.enabled=NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];NSString *error=nil;BOOL ok=[[A6Profiles shared]activate:identifier error:&error];
        dispatch_async(dispatch_get_main_queue(),^{_working=NO;self.navigationItem.rightBarButtonItem.enabled=YES;if(!ok)[self showError:error];[self viewWillAppear:NO];});[identifier release];[pool drain];
    });
}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)path {return !_working&&![[[_rows objectAtIndex:path.row]objectForKey:@"id"]isEqual:[[A6Profiles shared]activeIdentifier]];}
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    if(style!=UITableViewCellEditingStyleDelete||_working)return;NSString *error=nil;
    if(![[A6Profiles shared]remove:[[_rows objectAtIndex:path.row]objectForKey:@"id"]error:&error])[self showError:error];[self viewWillAppear:NO];
}
- (void)showError:(NSString *)error {UIAlertView *alert=[[UIAlertView alloc]initWithTitle:@"Amnezia6" message:error?:@"Операция не выполнена" delegate:nil cancelButtonTitle:@"Закрыть" otherButtonTitles:nil];[alert show];[alert release];}
- (void)addTapped:(id)sender {
    if(_working)return;UIActionSheet *sheet=[[UIActionSheet alloc]initWithTitle:@"Добавить сервер" delegate:self cancelButtonTitle:@"Отмена" destructiveButtonTitle:nil otherButtonTitles:@"Из буфера обмена",@"Из файла",@"QR — камера",@"QR — изображение",@"Ввести вручную",nil];
    [sheet showFromBarButtonItem:self.navigationItem.rightBarButtonItem animated:YES];[sheet release];
}
- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if(index==0){NSString *text=[UIPasteboard generalPasteboard].string;[self importData:[text dataUsingEncoding:NSUTF8StringEncoding]name:nil];}
    else if(index==1){A6FilesController *files=[[A6FilesController alloc]initWithDirectory:nil importer:self];[self.navigationController pushViewController:files animated:YES];[files release];}
    else if(index==2)[self pickImage:UIImagePickerControllerSourceTypeCamera];
    else if(index==3)[self pickImage:UIImagePickerControllerSourceTypePhotoLibrary];
    else if(index==4){A6ConfigController *editor=[[A6ConfigController alloc]initWithIdentifier:nil config:nil name:nil];[self.navigationController pushViewController:editor animated:YES];[editor release];}
}
- (void)importData:(NSData *)data name:(NSString *)name {
    if(_working)return;_working=YES;self.navigationItem.rightBarButtonItem.enabled=NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];NSString *error=nil;NSString *text=A6ImportConfig(data,&error);
        dispatch_async(dispatch_get_main_queue(),^{_working=NO;self.navigationItem.rightBarButtonItem.enabled=YES;
            if(!text){[self showError:error];return;}
            [self.navigationController popToViewController:self animated:NO];
            A6ConfigController *editor=[[A6ConfigController alloc]initWithIdentifier:nil config:text name:name];[self.navigationController pushViewController:editor animated:YES];[editor release];
        });[pool drain];
    });
}
- (void)importURL:(NSURL *)url {
    if([url isFileURL]) {
        NSString *path=[url path];NSDictionary *attrs=[[NSFileManager defaultManager]attributesOfItemAtPath:path error:NULL];
        if(![[attrs objectForKey:NSFileType]isEqual:NSFileTypeRegular]||[[attrs objectForKey:NSFileSize]unsignedLongLongValue]>768*1024){[self showError:@"Нужен обычный файл профиля до 768 КБ"];return;}
        NSData *data=[NSData dataWithContentsOfFile:path];[self importData:data name:[[path lastPathComponent]stringByDeletingPathExtension]];
    }else if([[[url scheme]lowercaseString]isEqual:@"vpn"])[self importData:[[url absoluteString]dataUsingEncoding:NSUTF8StringEncoding]name:nil];
    else [self showError:@"Поддерживаются файлы WireGuard/AmneziaWG и ссылки vpn://"];
}
- (void)pickImage:(UIImagePickerControllerSourceType)source {
    if(![UIImagePickerController isSourceTypeAvailable:source]){[self showError:@"Источник изображения недоступен"];return;}
    UIImagePickerController *picker=[[UIImagePickerController alloc]init];picker.sourceType=source;picker.delegate=self;picker.allowsEditing=NO;
    if(UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad&&source==UIImagePickerControllerSourceTypePhotoLibrary){
        [_popover release];_popover=[[UIPopoverController alloc]initWithContentViewController:picker];_popover.delegate=self;
        [_popover presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }else[self presentModalViewController:picker animated:YES];[picker release];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    if(_popover){[_popover dismissPopoverAnimated:YES];[_popover release];_popover=nil;}else[self dismissModalViewControllerAnimated:YES];
}
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popover {[_popover autorelease];_popover=nil;}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *image=[info objectForKey:UIImagePickerControllerOriginalImage];[self imagePickerControllerDidCancel:picker];
    if(_working)return;_working=YES;self.navigationItem.rightBarButtonItem.enabled=NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];NSString *error=nil;NSString *text=A6DecodeQR(image,&error);
        dispatch_async(dispatch_get_main_queue(),^{_working=NO;self.navigationItem.rightBarButtonItem.enabled=YES;
            if(text)[self importData:[text dataUsingEncoding:NSUTF8StringEncoding]name:nil];else[self showError:error];
        });[pool drain];
    });
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UIInterfaceOrientationMaskAll;}
@end

@implementation A6FilesController
- (id)initWithDirectory:(NSString *)directory importer:(A6ProfilesController *)importer {
    if((self=[super initWithStyle:UITableViewStylePlain])){_directory=[directory copy];_importer=importer;self.title=directory?[directory lastPathComponent]:@"Файлы";}return self;
}
- (void)dealloc {[_directory release];[_items release];[super dealloc];}
- (void)viewDidLoad {
    [super viewDidLoad];NSMutableArray *items=[NSMutableArray array];NSFileManager *fm=[NSFileManager defaultManager];
    if(!_directory){
        NSString *imports=@"/var/mobile/Documents/Amnezia6";[fm createDirectoryAtPath:imports withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0700]forKey:NSFilePosixPermissions]error:NULL];
        for(NSString *path in[NSArray arrayWithObjects:imports,[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Inbox"],@"/var/mobile/Documents",@"/var/mobile/Media/Downloads",nil])
            if([fm fileExistsAtPath:path]&&![items containsObject:path])[items addObject:path];
    }else for(NSString *name in[[fm contentsOfDirectoryAtPath:_directory error:NULL]sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]){
        if([name hasPrefix:@"."])continue;NSString *path=[_directory stringByAppendingPathComponent:name];NSDictionary *attrs=[fm attributesOfItemAtPath:path error:NULL];NSString *type=[attrs objectForKey:NSFileType];
        BOOL folder=[type isEqual:NSFileTypeDirectory];BOOL file=[type isEqual:NSFileTypeRegular];
        if(folder||(file&&[[NSArray arrayWithObjects:@"conf",@"wg",@"vpn",@"txt",@"json",nil]containsObject:[[name pathExtension]lowercaseString]]))[items addObject:path];
    }
    _items=[items copy];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return [_items count];}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {return @"Можно открыть .conf или .vpn из другого приложения через «Открыть в Amnezia6». Для прямого выбора скопируйте файл в Documents/Amnezia6.";}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"file"];if(!cell)cell=[[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"file"]autorelease];
    NSString *file=[_items objectAtIndex:path.row];BOOL dir=NO;[[NSFileManager defaultManager]fileExistsAtPath:file isDirectory:&dir];
    cell.textLabel.text=[file lastPathComponent];cell.detailTextLabel.text=_directory?nil:file;cell.accessoryType=dir?UITableViewCellAccessoryDisclosureIndicator:UITableViewCellAccessoryNone;return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path {
    [table deselectRowAtIndexPath:path animated:YES];NSString *file=[_items objectAtIndex:path.row];BOOL dir=NO;[[NSFileManager defaultManager]fileExistsAtPath:file isDirectory:&dir];
    if(dir){A6FilesController *next=[[A6FilesController alloc]initWithDirectory:file importer:_importer];[self.navigationController pushViewController:next animated:YES];[next release];}
    else [_importer importURL:[NSURL fileURLWithPath:file]];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {return YES;}
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {return UIInterfaceOrientationMaskAll;}
@end
