#import "A6ConfigController.h"

#import "A6Daemon.h"
#import "A6Profiles.h"

#import <dispatch/dispatch.h>

@interface A6ConfigController ()
- (void)keyboardWillShow:(NSNotification *)note;
- (void)keyboardWillHide:(NSNotification *)note;
- (CGFloat)keyboardHeightFromNote:(NSNotification *)note;
- (void)saveTapped:(id)sender;
@end

@implementation A6ConfigController

- (id)init { return [self initWithIdentifier:[[A6Profiles shared]activeIdentifier]config:nil name:nil]; }
- (id)initWithIdentifier:(NSString *)identifier config:(NSString *)config name:(NSString *)name {
    if((self=[super initWithNibName:nil bundle:nil])) {
        _identifier=[identifier copy];NSDictionary *row=[[A6Profiles shared]profile:identifier];
        _initialConfig=[(config?:[row objectForKey:@"config"]?:@"[Interface]\nPrivateKey = \nAddress = \nDNS = \n\n[Peer]\nPublicKey = \nEndpoint = \nAllowedIPs = 0.0.0.0/0\n")copy];
        _initialName=[(name?:[row objectForKey:@"name"])copy];self.title=identifier?@"Профиль":@"Новый профиль";
    }return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_textView release];
    [_pathLabel release]; [_nameField release];
    [_identifier release]; [_initialConfig release]; [_initialName release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor whiteColor];

    _nameField=[[UITextField alloc]initWithFrame:CGRectMake(8,8,self.view.bounds.size.width-16,36)];
    _nameField.autoresizingMask=UIViewAutoresizingFlexibleWidth;_nameField.borderStyle=UITextBorderStyleRoundedRect;
    _nameField.placeholder=@"Название сервера";_nameField.text=_initialName;_nameField.autocorrectionType=UITextAutocorrectionTypeNo;
    [self.view addSubview:_nameField];
    _pathLabel = [[UILabel alloc] initWithFrame:CGRectMake(8.0, 46.0,
                                                           self.view.bounds.size.width - 16.0,
                                                           20.0)];
    _pathLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _pathLabel.font = [UIFont systemFontOfSize:11.0];
    _pathLabel.textColor = [UIColor grayColor];
    _pathLabel.textAlignment = (NSTextAlignment)UITextAlignmentCenter;
    _pathLabel.lineBreakMode = (NSLineBreakMode)UILineBreakModeMiddleTruncation;
    _pathLabel.text = @"Сохранение активного профиля переподключает VPN";
    [self.view addSubview:_pathLabel];

    _textView = [[UITextView alloc] initWithFrame:CGRectMake(0.0, 68.0,
                                                             self.view.bounds.size.width,
                                                             self.view.bounds.size.height - 68.0)];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.font = [UIFont fontWithName:@"Courier" size:10.0];
    _textView.textColor = [UIColor darkTextColor];
    _textView.keyboardType = UIKeyboardTypeASCIICapable;
    _textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _textView.autocorrectionType = UITextAutocorrectionTypeNo;
    _textView.text = _initialConfig;
    _textView.delegate = self;
    [self.view addSubview:_textView];

    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:@"Сохранить"
                                          style:UIBarButtonItemStyleDone
                                         target:self
                                         action:@selector(saveTapped:)] autorelease];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [_textView release];
    _textView = nil;
    [_pathLabel release];
    _pathLabel = nil;
    [_nameField release]; _nameField=nil;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_textView resignFirstResponder]; [_nameField resignFirstResponder];
}

- (CGFloat)keyboardHeightFromNote:(NSNotification *)note {
    NSValue *value = [[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect rect;
    if (!value) value = [[note userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey];
    if (!value) return 0.0;
    rect = [value CGRectValue];
    rect = [self.view convertRect:rect fromView:nil];
    return MAX(0.0, self.view.bounds.size.height - rect.origin.y);
}

- (void)keyboardWillShow:(NSNotification *)note {
    CGFloat height = [self keyboardHeightFromNote:note];
    CGRect frame = _textView.frame;
    frame.size.height = self.view.bounds.size.height - 68.0 - height;
    if (frame.size.height < 60.0) frame.size.height = 60.0;
    _textView.frame = frame;
}

- (void)keyboardWillHide:(NSNotification *)note {
    CGRect frame = _textView.frame;
    frame.size.height = self.view.bounds.size.height - 68.0;
    _textView.frame = frame;
}

- (void)saveTapped:(id)sender {
    if(_saving)return;_saving=YES;self.navigationItem.rightBarButtonItem.enabled=NO;
    [_textView resignFirstResponder];[_nameField resignFirstResponder];
    NSString *text=[_textView.text copy],*name=[_nameField.text copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
        NSAutoreleasePool *pool=[NSAutoreleasePool new];NSString *error=nil;
        NSString *identifier=[[[A6Profiles shared]saveName:name config:text identifier:_identifier error:&error]copy];
        dispatch_async(dispatch_get_main_queue(),^{
            _saving=NO;self.navigationItem.rightBarButtonItem.enabled=YES;
            if(identifier)[self.navigationController popViewControllerAnimated:YES];
            else {UIAlertView *alert=[[UIAlertView alloc]initWithTitle:@"Не удалось сохранить" message:error delegate:nil cancelButtonTitle:@"Закрыть" otherButtonTitles:nil];[alert show];[alert release];}
            [identifier release];
        });[text release];[name release];[pool drain];
    });
}

- (void)textViewDidChange:(UITextView *)textView {
    /* Reserved for future validation feedback. */
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
