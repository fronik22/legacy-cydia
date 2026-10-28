#import <UIKit/UIKit.h>

@class A6StatusReport;

@interface A6RootController : UITableViewController {
    A6StatusReport *_report;
    NSString *_version;
    NSString *_configuredEndpoint;
    UISwitch *_toggle;
    NSTimer *_refreshTimer;
    BOOL _reachable;
    BOOL _busy;
    BOOL _queryInFlight;
    NSUInteger _stateGeneration;
    BOOL _switchNeedsSync;
}

@end
