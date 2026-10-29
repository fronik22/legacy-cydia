#import "A6RootController.h"

#import "A6ConfigController.h"
#import "A6Daemon.h"
#import "A6LogController.h"
#import "A6ProfilesController.h"
#import "A6Profiles.h"

#import <QuartzCore/QuartzCore.h>

#import <dispatch/dispatch.h>

enum {
    A6SectionConnection = 0,
    A6SectionTunnel = 1,
    A6SectionService = 2,
    A6SectionCount = 3
};

/* Old UISwitch versions track touches inside a child gesture recognizer. */
static BOOL A6SwitchTracking(UIView *view) {
    if ([view isKindOfClass:[UIControl class]] && [(UIControl *)view isTracking]) return YES;
    for (UIGestureRecognizer *gesture in view.gestureRecognizers)
        if (gesture.numberOfTouches) return YES;
    for (UIView *child in view.subviews)
        if (A6SwitchTracking(child)) return YES;
    return NO;
}

static UIImage *A6DotImage(UIColor *color) {
    UIImage *image;
    UIGraphicsBeginImageContext(CGSizeMake(12.0, 12.0));
    [color setFill];
    CGContextFillEllipseInRect(UIGraphicsGetCurrentContext(),
                               CGRectMake(0.0, 0.0, 12.0, 12.0));
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@interface A6RootController ()
- (void)refreshAsync;
- (void)applyReport:(A6StatusReport *)report;
- (void)updateCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)toggleChanged:(UISwitch *)sender;
- (void)refreshTapped:(id)sender;
@end

@implementation A6RootController

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self) {
        self.title = @"Amnezia6";
        _reachable = NO;
        _busy = NO;
        _queryInFlight = NO;
        _toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
        [_toggle addTarget:self
                      action:@selector(toggleChanged:)
            forControlEvents:UIControlEventValueChanged];
        _toggle.enabled = NO;
        _report = [[A6StatusReport alloc] init];
        _report.status = A6StatusUnavailable;
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(profileChanged:)
            name:@"A6ProfilesDidChange" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [_refreshTimer invalidate];
    [_refreshTimer release];
    [_report release];
    [_version release];
    [_configuredEndpoint release];
    [_toggle release];
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
        initWithTitle:@"Серверы" style:UIBarButtonItemStylePlain
        target:self action:@selector(profilesTapped:)] autorelease];

    self.navigationItem.rightBarButtonItem =
        [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                       target:self
                                                       action:@selector(refreshTapped:)]
            autorelease];

    {
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0,
                                                                 self.tableView.bounds.size.width,
                                                                 92.0)];
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Icon.png"]];
        UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(88.0, 20.0, 216.0, 28.0)];
        UILabel *tagline = [[UILabel alloc] initWithFrame:CGRectMake(88.0, 48.0, 216.0, 20.0)];

        header.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        icon.frame = CGRectMake(19.0, 18.0, 57.0, 57.0);
        icon.layer.cornerRadius = 10.0;
        icon.layer.masksToBounds = YES;

        name.backgroundColor = [UIColor clearColor];
        name.font = [UIFont boldSystemFontOfSize:22.0];
        name.text = @"Amnezia6";
        name.textColor = [UIColor darkTextColor];
        name.shadowColor = [UIColor whiteColor];
        name.shadowOffset = CGSizeMake(0.0, 1.0);

        tagline.backgroundColor = [UIColor clearColor];
        tagline.font = [UIFont systemFontOfSize:13.0];
        tagline.text = @"AmneziaWG для iOS 4–7";
        tagline.textColor = [UIColor grayColor];

        [header addSubview:icon];
        [header addSubview:name];
        [header addSubview:tagline];
        [icon release];
        [name release];
        [tagline release];
        self.tableView.tableHeaderView = header;
        [header release];
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [_refreshTimer invalidate];
    [_refreshTimer release];
    _refreshTimer = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [A6Profiles shared];
    [_configuredEndpoint release];
    _configuredEndpoint = [[[A6Daemon shared] configuredEndpoint] copy];
    [self refreshAsync];
    if (!_refreshTimer) {
        _refreshTimer = [[NSTimer scheduledTimerWithTimeInterval:1.5
                                                          target:self
                                                        selector:@selector(refreshTimerFired:)
                                                        userInfo:nil
                                                         repeats:YES] retain];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_refreshTimer invalidate];
    [_refreshTimer release];
    _refreshTimer = nil;
}

- (void)refreshTimerFired:(NSTimer *)timer {
    [self refreshAsync];
}

- (void)refreshTapped:(id)sender {
    [self refreshAsync];
}

- (void)profilesTapped:(id)sender {
    if (_busy) return;
    A6ProfilesController *controller = [[A6ProfilesController alloc] init];
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
}

- (void)profileChanged:(NSNotification *)note {
    _stateGeneration++;
    [_configuredEndpoint release];
    _configuredEndpoint = [[[A6Daemon shared] configuredEndpoint] copy];
    [self refreshAsync];
}

- (void)refreshAsync {
    if (_queryInFlight || _busy || A6SwitchTracking(_toggle)) return;
    _queryInFlight = YES;
    NSUInteger generation = _stateGeneration;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        A6Daemon *daemon = [A6Daemon shared];
        A6StatusReport *report = [[daemon statusReport] retain];
        NSString *version = [daemon versionString];
        dispatch_async(dispatch_get_main_queue(), ^{
            _queryInFlight = NO;
            if (generation != _stateGeneration) {
                [report release];
                [self refreshAsync];
                return;
            }
            _reachable = (report.status != A6StatusUnavailable);
            if (version) {
                [_version release];
                _version = [version copy];
            }
            [self applyReport:report];
            [report release];
        });
    });
}

- (void)applyReport:(A6StatusReport *)report {
    /* A poll must not reset an in-progress switch gesture or command. */
    if (_busy || A6SwitchTracking(_toggle)) return;
    BOOL stateChanged = _report.status != report.status;
    [_report release];
    _report = [report retain];
    BOOL enabled = _reachable && !_busy;
    if (_toggle.enabled != enabled) _toggle.enabled = enabled;
    if (stateChanged || _switchNeedsSync) {
        BOOL on = report.status == A6StatusConnected || report.status == A6StatusConnecting;
        if (_toggle.on != on) _toggle.on = on;
        _switchNeedsSync = NO;
        [self.tableView reloadData];
    } else {
        /* Keep the switch attached and preserve its gesture/animation during polling. */
        for (NSIndexPath *path in [self.tableView indexPathsForVisibleRows]) {
            if (path.section == A6SectionConnection && path.row == 0) continue;
            [self updateCell:[self.tableView cellForRowAtIndexPath:path] atIndexPath:path];
        }
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    if (_busy) return;
    _stateGeneration++;
    BOOL wantConnected = sender.on;
    _busy = YES;
    sender.enabled = NO;
    [self.tableView reloadData];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *error = nil;
        BOOL ok = wantConnected ? [[A6Daemon shared] startWithError:&error]
                                : [[A6Daemon shared] stopWithError:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            _busy = NO;
            _switchNeedsSync = YES;
            if (!ok) {
                UIAlertView *alert = [[UIAlertView alloc]
                    initWithTitle:(wantConnected ? @"Не удалось подключиться" : @"Не удалось отключиться")
                    message:(error ? error : @"Неизвестная ошибка") delegate:nil
                    cancelButtonTitle:@"Закрыть" otherButtonTitles:nil];
                [alert show];
                [alert release];
            }
            [self refreshAsync];
        });
        [pool drain];
    });
}

#pragma mark - Status text

- (NSString *)statusTitle {
    if (_busy) return @"Подождите…";
    switch (_report.status) {
    case A6StatusConnected: return @"Подключено";
    case A6StatusConnecting: return @"Подключение…";
    case A6StatusError: return @"Ошибка";
    case A6StatusIdle: return @"Отключено";
    default: return @"Нет связи с демоном";
    }
}

- (NSString *)statusDetail {
    switch (_report.status) {
    case A6StatusConnected:
        return @"Весь IPv4-трафик идёт через туннель.";
    case A6StatusConnecting:
        return [ _report.errorText length] ? [NSString stringWithFormat:@"%@ Повторное подключение автоматически…", _report.errorText]
                                          : @"Ожидание рукопожатия с сервером.";
    case A6StatusError:
        return (_report.errorText && [_report.errorText length])
                   ? _report.errorText
                   : @"Туннель остановлен из-за ошибки.";
    case A6StatusIdle:
        return @"Туннель не поднят.";
    default:
        return @"Служба amnezia6d не отвечает. Проверьте установку пакета.";
    }
}

- (UIColor *)statusColor {
    switch (_report.status) {
    case A6StatusConnected: return [UIColor colorWithRed:0.20 green:0.68 blue:0.24 alpha:1.0];
    case A6StatusConnecting: return [UIColor colorWithRed:0.95 green:0.60 blue:0.10 alpha:1.0];
    case A6StatusError: return [UIColor colorWithRed:0.82 green:0.18 blue:0.16 alpha:1.0];
    case A6StatusIdle: return [UIColor colorWithRed:0.55 green:0.55 blue:0.57 alpha:1.0];
    default: return [UIColor colorWithRed:0.45 green:0.45 blue:0.47 alpha:1.0];
    }
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return A6SectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
    case A6SectionConnection: return 2;
    case A6SectionTunnel: return 5;
    default: return 3;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
    case A6SectionConnection: return @"Подключение";
    case A6SectionTunnel: return @"Туннель";
    default: return @"Сервис";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == A6SectionConnection && !_reachable) {
        return @"Демон не запущен. Установите пакет com.mak.amnezia6 или запустите "
               @"/usr/libexec/amnezia6/amnezia6d.";
    }
    if (section == A6SectionTunnel) {
        NSString *state = [self statusDetail];
        return state;
    }
    if (section == A6SectionService) {
        return @"Туннель защищает только IPv4. IPv6 не защищён. Kill switch отсутствует. "
               @"Ключи хранятся в /var/mobile/Library/Preferences/Amnezia6/amnezia6.conf с правами 0600.";
    }
    return nil;
}

- (UITableViewCell *)cellWithIdentifier:(NSString *)identifier {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:identifier] autorelease];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = indexPath.section == A6SectionConnection ? @"connection"
        : indexPath.section == A6SectionTunnel ? @"tunnel"
        : indexPath.row < 2 ? @"service" : @"version";
    UITableViewCell *cell = [self cellWithIdentifier:identifier];
    [self updateCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)updateCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    NSInteger section = [indexPath section];
    NSInteger row = [indexPath row];

    if (section == A6SectionConnection) {
        if (row == 0) {
            cell.textLabel.text = @"VPN";
            cell.detailTextLabel.text = @"";
            cell.imageView.image = A6DotImage([self statusColor]);
            cell.accessoryView = _toggle;
        } else {
            cell.textLabel.text = @"Состояние";
            cell.detailTextLabel.text = [self statusTitle];
            cell.imageView.image = nil;
            cell.accessoryView = nil;
            cell.detailTextLabel.textColor =
                (_report.status == A6StatusConnected) ? [self statusColor]
                                                      : [UIColor grayColor];
        }
        return;
    }

    if (section == A6SectionTunnel) {
        BOOL live = (_report.status == A6StatusConnected);
        NSString *dash = @"—";
        cell.accessoryView = nil;
        cell.detailTextLabel.textColor = live ? [UIColor darkTextColor] : [UIColor grayColor];
        switch (row) {
        case 0:
            cell.textLabel.text = @"Адрес";
            cell.detailTextLabel.text = live && [_report.address length] ? _report.address : dash;
            break;
        case 1:
            cell.textLabel.text = @"Сервер";
            cell.detailTextLabel.text = live && [_report.endpoint length] && ![_report.endpoint isEqualToString:@"-"]
                ? _report.endpoint : ([_configuredEndpoint length] ? _configuredEndpoint : dash);
            break;
        case 2:
            cell.textLabel.text = @"Интерфейс";
            cell.detailTextLabel.text = live && [_report.ifname length] ? _report.ifname : dash;
            break;
        case 3:
            cell.textLabel.text = @"Время";
            cell.detailTextLabel.text =
                live ? A6FormatDuration(_report.uptime) : dash;
            break;
        default:
            cell.textLabel.text = @"Трафик";
            cell.detailTextLabel.text =
                live ? [NSString stringWithFormat:@"↓ %@  ↑ %@",
                                                  A6FormatBytes(_report.rxBytes),
                                                  A6FormatBytes(_report.txBytes)]
                     : dash;
            break;
        }
        return;
    }

    if (row == 0 || row == 1) {
        cell.textLabel.text = (row == 0) ? @"Журнал" : @"Конфигурация";
        cell.detailTextLabel.text = @"";
        cell.imageView.image = nil;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        return;
    }

    {
        cell.textLabel.text = @"Версия демона";
        cell.detailTextLabel.text = _version ? _version : @"—";
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.imageView.image = nil;
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if ([indexPath section] != A6SectionService) return;
    if ([indexPath row] == 0) {
        A6LogController *controller = [[A6LogController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
    } else if ([indexPath row] == 1) {
        A6ConfigController *controller = [[A6ConfigController alloc] init];
        [self.navigationController pushViewController:controller animated:YES];
        [controller release];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

@end
