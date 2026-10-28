#import "A6LogController.h"

#import "A6Daemon.h"

@interface A6LogController ()
- (void)reload;
- (void)timerFired:(NSTimer *)timer;
- (void)clearTapped:(id)sender;
@end

@implementation A6LogController

- (id)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) self.title = @"Журнал";
    return self;
}

- (void)dealloc {
    [_timer invalidate];
    [_timer release];
    [_textView release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor whiteColor];

    _textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    _textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _textView.editable = NO;
    _textView.font = [UIFont fontWithName:@"Courier" size:10.0];
    _textView.textColor = [UIColor darkTextColor];
    _textView.backgroundColor = [UIColor whiteColor];
    _textView.text = @"";
    [self.view addSubview:_textView];

    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithTitle:@"Очистить"
                                          style:UIBarButtonItemStyleBordered
                                         target:self
                                         action:@selector(clearTapped:)] autorelease];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [_timer invalidate];
    [_timer release];
    _timer = nil;
    [_textView release];
    _textView = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self reload];
    if (!_timer) {
        _timer = [[NSTimer scheduledTimerWithTimeInterval:2.0
                                                   target:self
                                                 selector:@selector(timerFired:)
                                                 userInfo:nil
                                                  repeats:YES] retain];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_timer invalidate];
    [_timer release];
    _timer = nil;
}

- (void)timerFired:(NSTimer *)timer {
    [self reload];
}

- (void)reload {
    NSString *text = [[A6Daemon shared] logContents];
    if (![text length]) text = @"Журнал пуст.\n";
    if (![text isEqualToString:_textView.text]) {
        _textView.text = text;
        [_textView scrollRangeToVisible:NSMakeRange([text length], 0)];
    }
}

- (void)clearTapped:(id)sender {
    UIAlertView *alert =
        [[UIAlertView alloc] initWithTitle:@"Очистить журнал?"
                                    message:@"Все записи демона будут удалены."
                                   delegate:self
                          cancelButtonTitle:@"Отмена"
                          otherButtonTitles:@"Очистить", nil];
    [alert show];
    [alert release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
    if (index == [alertView cancelButtonIndex]) return;
    [[A6Daemon shared] clearLogWithError:NULL];
    [self reload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
