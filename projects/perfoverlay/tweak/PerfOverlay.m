// PerfOverlay — FPS / CPU / RAM / GPU HUD for iOS 4–9.
// Injected into SpringBoard by Cydia Substrate. MRC, armv7-compatible.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "HUDLayout.h"
#import "CPUCounters.h"
#import "MetricPolicy.h"
#include <CoreFoundation/CoreFoundation.h>
#include <mach/mach.h>
#include <mach/host_info.h>
#include <mach/processor_info.h>
#include <mach/vm_statistics.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <math.h>

#ifndef PERF_LOG
#define PERF_LOG "/tmp/perfoverlay.log"
#endif
#define PERF_PREF_DOMAIN CFSTR("com.local.perfoverlay")
#define PERF_PREF_ENABLED CFSTR("Enabled")
#define PERF_TOGGLE_ON "com.local.perfoverlay.toggle.on"
#define PERF_TOGGLE_OFF "com.local.perfoverlay.toggle.off"
#define PERF_SETTINGS_CHANGED CFSTR("com.local.perfoverlay.settings")
#define PERF_NCSETTINGS_REGISTERED CFSTR("NCSettingsRegistered")
#define NCSETTINGS_DOMAIN CFSTR("com.jamied360.ncsettings")
#define NCSETTINGS_VISIBLE CFSTR("Visible")
#define NCSETTINGS_HIDDEN CFSTR("Hidden")
#define NCSETTINGS_TOGGLE_NAME CFSTR("PerfOverlay")

static void PLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(PERF_LOG, "a");
    if (f) {
        fprintf(f, "%s\n", [line UTF8String]);
        fclose(f);
    }
    [line release];
}

// The overlay defaults to visible when the preference does not exist yet.
static BOOL ReadEnabledPreference(void) {
    CFPreferencesAppSynchronize(PERF_PREF_DOMAIN);
    Boolean exists = false;
    Boolean value = CFPreferencesGetAppBooleanValue(PERF_PREF_ENABLED, PERF_PREF_DOMAIN, &exists);
    return exists ? (value ? YES : NO) : YES;
}

static void WriteEnabledPreference(BOOL enabled) {
    CFPreferencesSetAppValue(PERF_PREF_ENABLED, enabled ? kCFBooleanTrue : kCFBooleanFalse, PERF_PREF_DOMAIN);
    CFPreferencesAppSynchronize(PERF_PREF_DOMAIN);
}

static BOOL ArrayContainsString(CFArrayRef array, CFStringRef value) {
    if (!array || CFGetTypeID(array) != CFArrayGetTypeID()) return NO;
    CFIndex count = CFArrayGetCount(array);
    for (CFIndex i = 0; i < count; i++) {
        CFTypeRef item = CFArrayGetValueAtIndex(array, i);
        if (item && CFGetTypeID(item) == CFStringGetTypeID() &&
            CFStringCompare((CFStringRef)item, value, 0) == kCFCompareEqualTo) {
            return YES;
        }
    }
    return NO;
}

static void MarkNCSettingsRegistered(void) {
    CFPreferencesSetAppValue(PERF_NCSETTINGS_REGISTERED, kCFBooleanTrue, PERF_PREF_DOMAIN);
    CFPreferencesAppSynchronize(PERF_PREF_DOMAIN);
}

// Add the toggle to NCSettings' visible list exactly once. The marker lives in
// our own preference domain, so if the user later removes the toggle we never
// put it back behind their back.
static void RegisterWithNCSettingsIfNeeded(void) {
    if (!PerfLegacyNCSupported([[[UIDevice currentDevice] systemVersion] intValue])) return;
    BOOL ncsettings = [[NSFileManager defaultManager]
        fileExistsAtPath:@"/Library/WeeLoader/Plugins/NCSettings.bundle"];
    PLog(@"NCSettings registration check: bundle=%d", ncsettings);
    if (!ncsettings) return;

    CFPreferencesAppSynchronize(PERF_PREF_DOMAIN);
    Boolean registered = false;
    CFPreferencesGetAppBooleanValue(PERF_NCSETTINGS_REGISTERED, PERF_PREF_DOMAIN, &registered);
    PLog(@"NCSettings registration marker=%d", registered);
    if (registered) return;

    CFPreferencesAppSynchronize(NCSETTINGS_DOMAIN);
    CFPropertyListRef visibleRef = CFPreferencesCopyAppValue(NCSETTINGS_VISIBLE, NCSETTINGS_DOMAIN);
    CFPropertyListRef hiddenRef = CFPreferencesCopyAppValue(NCSETTINGS_HIDDEN, NCSETTINGS_DOMAIN);
    CFArrayRef visible = (visibleRef && CFGetTypeID(visibleRef) == CFArrayGetTypeID())
                             ? (CFArrayRef)visibleRef : NULL;
    CFArrayRef hidden = (hiddenRef && CFGetTypeID(hiddenRef) == CFArrayGetTypeID())
                            ? (CFArrayRef)hiddenRef : NULL;
    PLog(@"NCSettings registration visible=%ld hidden=%ld",
         visible ? (long)CFArrayGetCount(visible) : -1L,
         hidden ? (long)CFArrayGetCount(hidden) : -1L);

    if (!visible) {
        // On a fresh NCSettings install its preference file may not exist yet.
        // Do not replace a missing list with a one-item list; try again later.
        PLog(@"NCSettings has no Visible list yet; registration deferred");
        if (visibleRef) CFRelease(visibleRef);
        if (hiddenRef) CFRelease(hiddenRef);
        return;
    }

    if (ArrayContainsString(hidden, NCSETTINGS_TOGGLE_NAME)) {
        // The user already hid the toggle: remember that and respect it.
        MarkNCSettingsRegistered();
    } else if (!ArrayContainsString(visible, NCSETTINGS_TOGGLE_NAME)) {
        CFMutableArrayRef updated = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, visible);
        if (updated) {
            CFArrayInsertValueAtIndex(updated, 0, NCSETTINGS_TOGGLE_NAME);
            CFPreferencesSetAppValue(NCSETTINGS_VISIBLE, updated, NCSETTINGS_DOMAIN);
            if (CFPreferencesAppSynchronize(NCSETTINGS_DOMAIN)) {
                MarkNCSettingsRegistered();
                PLog(@"registered PerfOverlay in NCSettings Visible");
            } else {
                PLog(@"NCSettings registration write failed");
            }
            CFRelease(updated);
        }
    } else {
        MarkNCSettingsRegistered();
    }

    if (visibleRef) CFRelease(visibleRef);
    if (hiddenRef) CFRelease(hiddenRef);
}

// ---------------------------------------------------------------- IOKit (dlsym)
// The iOS 9.3 SDK has no IOKit headers, and current macOS headers are marked
// unavailable on iOS. These symbols are a stable C ABI; dlsym also lets the
// tweak degrade to "GPU n/a" instead of failing to load.
typedef mach_port_t io_object_t;
typedef mach_port_t io_iterator_t;
typedef char io_name_t[128];
typedef unsigned int IOOptionBits;

static CFMutableDictionaryRef (*pIOServiceMatching)(const char *);
static kern_return_t (*pIOServiceGetMatchingServices)(mach_port_t, CFDictionaryRef, io_iterator_t *);
static io_object_t (*pIOIteratorNext)(io_iterator_t);
static kern_return_t (*pIOObjectRelease)(io_object_t);
static kern_return_t (*pIOObjectGetClass)(io_object_t, io_name_t);
static CFTypeRef (*pIORegistryEntryCreateCFProperty)(io_object_t, CFStringRef, CFAllocatorRef, IOOptionBits);

static int gIOKitState = 0; // 0 = not tried, 1 = ready, -1 = unavailable
static char gGPUService[96] = {0};

static BOOL LoadIOKit(void) {
    if (gIOKitState != 0) return gIOKitState > 0;
    void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!h) {
        gIOKitState = -1;
        PLog(@"IOKit dlopen failed: %s", dlerror());
        return NO;
    }
    pIOServiceMatching = dlsym(h, "IOServiceMatching");
    pIOServiceGetMatchingServices = dlsym(h, "IOServiceGetMatchingServices");
    pIOIteratorNext = dlsym(h, "IOIteratorNext");
    pIOObjectRelease = dlsym(h, "IOObjectRelease");
    pIOObjectGetClass = dlsym(h, "IOObjectGetClass");
    pIORegistryEntryCreateCFProperty = dlsym(h, "IORegistryEntryCreateCFProperty");
    BOOL ok = pIOServiceMatching && pIOServiceGetMatchingServices && pIOIteratorNext &&
              pIOObjectRelease && pIOObjectGetClass && pIORegistryEntryCreateCFProperty;
    gIOKitState = ok ? 1 : -1;
    if (!ok) PLog(@"IOKit symbols missing");
    return ok;
}

static int PercentFromStats(CFDictionaryRef stats) {
    const char *keys[] = {"Device Utilization %", "Renderer Utilization %", "Tiler Utilization %", NULL};
    for (int i = 0; keys[i]; i++) {
        CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, keys[i], kCFStringEncodingUTF8);
        if (!key) continue;
        CFTypeRef value = CFDictionaryGetValue(stats, key);
        double raw = -1;
        if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
            if (!CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &raw)) raw = -1;
        }
        CFRelease(key);
        int percent=PerfMetricPercent(raw);
        if (percent >= 0) return percent;
    }
    return -1;
}

static int ReadGPUStatsForService(const char *serviceName, char *foundName, size_t foundSize) {
    io_iterator_t iter = 0;
    CFMutableDictionaryRef match = pIOServiceMatching(serviceName);
    if (!match) return -1;
    if (pIOServiceGetMatchingServices(0, match, &iter) != KERN_SUCCESS) return -1;
    int result = -1;
    io_object_t service;
    while ((service = pIOIteratorNext(iter))) {
        CFTypeRef stats = pIORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"),
                                                           kCFAllocatorDefault, 0);
        if (stats) {
            if (CFGetTypeID(stats) == CFDictionaryGetTypeID()) {
                result = PercentFromStats((CFDictionaryRef)stats);
                if (result >= 0 && foundName && foundSize) {
                    strncpy(foundName, serviceName, foundSize - 1);
                    foundName[foundSize - 1] = 0;
                }
            }
            CFRelease(stats);
        }
        pIOObjectRelease(service);
        if (result >= 0) break;
    }
    pIOObjectRelease(iter);
    return result;
}

static int DiscoverGPUService(char *name, size_t size) {
    // Known PowerVR class names, then a one-time scan for any SGX/GPU service.
    const char *known[] = {"SGXDriver543", "SGXDriver554", "SGXDriver", "AGXAccelerator", "IOAccelerator", "IOGPU", NULL};
    for (int i = 0; known[i]; i++) {
        if (ReadGPUStatsForService(known[i], name, size) >= 0) return 0;
    }
    io_iterator_t iter = 0;
    CFMutableDictionaryRef match = pIOServiceMatching("IOService");
    if (!match || pIOServiceGetMatchingServices(0, match, &iter) != KERN_SUCCESS) return -1;
    int found = -1;
    io_object_t service;
    while ((service = pIOIteratorNext(iter))) {
        io_name_t cls = "?";
        if (pIOObjectGetClass(service, cls) == KERN_SUCCESS) {
            NSString *c = [NSString stringWithUTF8String:cls];
            if ([c rangeOfString:@"SGX"].location != NSNotFound ||
                [c rangeOfString:@"GPU"].location != NSNotFound ||
                [c rangeOfString:@"Accelerator"].location != NSNotFound) {
                CFTypeRef stats = pIORegistryEntryCreateCFProperty(service, CFSTR("PerformanceStatistics"),
                                                                   kCFAllocatorDefault, 0);
                if (stats) {
                    if (CFGetTypeID(stats) == CFDictionaryGetTypeID() &&
                        PercentFromStats((CFDictionaryRef)stats) >= 0) {
                        strncpy(name, cls, size - 1);
                        name[size - 1] = 0;
                        found = 0;
                    }
                    CFRelease(stats);
                }
            }
        }
        pIOObjectRelease(service);
        if (found == 0) break;
    }
    pIOObjectRelease(iter);
    return found;
}

static int GPUUtilization(void) {
    if (!LoadIOKit()) return -1;
    if (gGPUService[0]) {
        int value = ReadGPUStatsForService(gGPUService, NULL, 0);
        if (value >= 0) return value;
        gGPUService[0] = 0; // driver changed or service went away
    }
    char name[96] = {0};
    if (DiscoverGPUService(name, sizeof(name)) == 0 && name[0]) {
        strncpy(gGPUService, name, sizeof(gGPUService) - 1);
        return ReadGPUStatsForService(gGPUService, NULL, 0);
    }
    return -1;
}

// ------------------------------------------------------- global frame counter
// QuartzCore's render server exposes the number of frames actually composited.
// Sampling it gives real system/game FPS, not just a 60 Hz display-link tick.
typedef uint32_t (*FrameCounterFn)(mach_port_t);
typedef kern_return_t (*BootstrapLookUpFn)(mach_port_t, const char *, mach_port_t *);

static FrameCounterFn pFrameCounter = NULL;
static mach_port_t gRenderServer = MACH_PORT_NULL;
static int gFrameCounterState = 0; // 0 = not tried, 1 = ready, -1 = unavailable

static BOOL LoadGlobalFrameCounter(void) {
    if (gFrameCounterState != 0) return gFrameCounterState > 0;
    void *quartz = dlopen("/System/Library/Frameworks/QuartzCore.framework/QuartzCore", RTLD_LAZY);
    if (quartz) pFrameCounter = dlsym(quartz, "CARenderServerGetFrameCounter");
    BootstrapLookUpFn lookup = dlsym(RTLD_DEFAULT, "bootstrap_look_up");
    mach_port_t bootstrap = MACH_PORT_NULL;
    task_get_bootstrap_port(mach_task_self(), &bootstrap);
    kern_return_t kr = KERN_FAILURE;
    if (lookup && bootstrap != MACH_PORT_NULL) {
        kr = lookup(bootstrap, "com.apple.CARenderServer", &gRenderServer);
    }
    BOOL ok = pFrameCounter && kr == KERN_SUCCESS && gRenderServer != MACH_PORT_NULL;
    gFrameCounterState = ok ? 1 : -1;
    PLog(@"global frame counter ready=%d sym=%p kr=%d port=%u", ok, pFrameCounter, kr, gRenderServer);
    return ok;
}

static BOOL ReadGlobalFrameCounter(uint32_t *value) {
    if (!LoadGlobalFrameCounter() || !value) return NO;
    *value = pFrameCounter(gRenderServer);
    return YES;
}

// ------------------------------------------------------------------- samplers
static uint32_t gPrevUser[16], gPrevSystem[16], gPrevNice[16], gPrevIdle[16];
static int gPrevCPUs = 0;

static double gCoreUsage[16];
static unsigned int gCoreCount;
static double CPUUsage(void) {
    natural_t count=0;processor_info_array_t info=NULL;mach_msg_type_number_t infoCount=0;
    if(host_processor_info(mach_host_self(),PROCESSOR_CPU_LOAD_INFO,&count,&info,&infoCount)!=KERN_SUCCESS){
        gPrevCPUs=0;gCoreCount=0;return -1;
    }
    unsigned int cores=MIN(count,16);BOOL ready=gPrevCPUs==(int)cores;
    uint64_t busy=0,total=0;
    for(unsigned int i=0;i<cores;i++) {
        processor_cpu_load_info_data_t *load=(processor_cpu_load_info_data_t*)info+i;
        PerfCPUTicks before={gPrevUser[i],gPrevSystem[i],gPrevNice[i],gPrevIdle[i]};
        PerfCPUTicks after={load->cpu_ticks[CPU_STATE_USER],load->cpu_ticks[CPU_STATE_SYSTEM],load->cpu_ticks[CPU_STATE_NICE],load->cpu_ticks[CPU_STATE_IDLE]};
        uint64_t b=0,t=0;double value=PerfCPUPercent(before,after,&b,&t);
        gCoreUsage[i]=ready?value:-1;busy+=b;total+=t;
        gPrevUser[i]=after.user;gPrevSystem[i]=after.system;gPrevNice[i]=after.nice;gPrevIdle[i]=after.idle;
    }
    gPrevCPUs=(int)cores;gCoreCount=cores;
    vm_deallocate(mach_task_self(),(vm_address_t)info,infoCount*sizeof(natural_t));
    return ready&&total?100.0*(double)busy/(double)total:-1;
}

static BOOL MemoryUsage(double *usedMB, double *totalMB) {
    vm_statistics_data_t vm;
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vm, &count) != KERN_SUCCESS) return NO;
    vm_size_t taskPage = 0;
    if(host_page_size(mach_host_self(), &taskPage)!=KERN_SUCCESS)return NO;
    // iOS7 A7 tasks use16KiB pages while HOST_VM_INFO counts4KiB kernel pages.
    vm_size_t *kernelPage=dlsym(RTLD_DEFAULT,"vm_kernel_page_size");
    uint64_t page=PerfMetricPageSize(kernelPage?*kernelPage:0,taskPage),used=0,total=0;
    size_t len=sizeof(total);
    if(sysctlbyname("hw.memsize",&total,&len,NULL,0)||!PerfMetricMemory(vm.active_count,vm.inactive_count,vm.wire_count,page,total,&used))return NO;
    if (usedMB) *usedMB = (double)used / 1048576.0;
    if (totalMB) *totalMB = (double)total / 1048576.0;
    return YES;
}

// -------------------------------------------------------------------- overlay
// Purely visual: touch hit-testing must fall through to SpringBoard/apps below.
@interface PerfOverlayWindow : UIWindow
@end
@implementation PerfOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event { return nil; }
@end

// SpringBoard reports the foreground interface, including status-bar-hidden games.
@interface UIApplication (PerfOverlayOrientation)
- (UIInterfaceOrientation)activeInterfaceOrientation;
@end

@interface PerfOverlay : NSObject {
    UIWindow *_window;
    UILabel *_label;
    UIView *_panel;
    UIInterfaceOrientation _orientation;
    CADisplayLink *_link;
    NSTimer *_timer;
    NSUInteger _frames;
    CFTimeInterval _fpsStart;
    double _fps;
    BOOL _fpsValid;
    uint32_t _lastFrameCounter;
    CFTimeInterval _lastFrameTime;
    BOOL _haveFrameCounter;
    BOOL _useGlobalFPS;
    BOOL _globalFPSTried;
    unsigned int _globalZeroTicks;
    double _cpu;
    BOOL _cpuValid;
    double _usedMB;
    double _totalMB;
    BOOL _ramValid;
    int _gpu;
    BOOL _overlayVisible;
    BOOL _showFPS,_showCPU,_showCores,_showRAM,_showGPU;
    int _corner;
    CGFloat _fontSize,_opacity;
    NSTimeInterval _sampleInterval;
}
+ (PerfOverlay *)shared;
- (void)start;
- (void)tick;
- (void)displayLinkFired:(CADisplayLink *)link;
- (void)applyEnabledPreference;
- (void)handleToggleNotification:(NSNumber *)enabled;
- (void)setOverlayVisible:(BOOL)visible;
- (void)startSampling;
- (void)stopSampling;
- (void)updateOrientation;
- (void)orientationChanged:(NSNotification *)notification;
- (void)reloadSettings;
- (void)layoutPanel;
@end

static void PerfOverlayToggleNotification(CFNotificationCenterRef center,
                                          void *observer,
                                          CFStringRef name,
                                          const void *object,
                                          CFDictionaryRef userInfo) {
    BOOL enabled = (CFStringCompare(name, CFSTR(PERF_TOGGLE_ON), 0) == kCFCompareEqualTo);
    [[PerfOverlay shared] performSelectorOnMainThread:@selector(handleToggleNotification:)
                                           withObject:[NSNumber numberWithBool:enabled]
                                        waitUntilDone:NO];
}

static void PerfOverlayOrientationNotification(CFNotificationCenterRef center,
                                              void *observer, CFStringRef name,
                                              const void *object, CFDictionaryRef userInfo) {
    [[PerfOverlay shared] performSelectorOnMainThread:@selector(updateOrientation)
                                           withObject:nil waitUntilDone:NO];
}

static BOOL BoolPreference(CFStringRef key,BOOL fallback) {
    Boolean exists=false;Boolean value=CFPreferencesGetAppBooleanValue(key,PERF_PREF_DOMAIN,&exists);
    return exists?(value?YES:NO):fallback;
}
static double NumberPreference(CFStringRef key,double fallback,double minimum,double maximum) {
    CFPropertyListRef value=CFPreferencesCopyAppValue(key,PERF_PREF_DOMAIN);double number=fallback;
    if(value){if(CFGetTypeID(value)==CFNumberGetTypeID())CFNumberGetValue((CFNumberRef)value,kCFNumberDoubleType,&number);CFRelease(value);}
    return isfinite(number)&&number>=minimum&&number<=maximum?number:fallback;
}
static void PerfOverlaySettingsNotification(CFNotificationCenterRef center,void *observer,
                                           CFStringRef name,const void *object,CFDictionaryRef userInfo) {
    [[PerfOverlay shared] performSelectorOnMainThread:@selector(reloadSettings) withObject:nil waitUntilDone:NO];
}

@implementation PerfOverlay

+ (PerfOverlay *)shared {
    static PerfOverlay *shared = nil;
    if (!shared) shared = [[PerfOverlay alloc] init];
    return shared;
}

- (id)init {
    if ((self = [super init])) {
        _cpu = -1.0;
        _gpu = -1;
        _fps = 0.0;
    }
    return self;
}

- (void)start {
    if (_window) return;
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
        PLog(@"not SpringBoard, skipping");
        return;
    }

    CGSize size = [[UIScreen mainScreen] bounds].size;
    // iOS 8+ may return oriented bounds; this window keeps fixed portrait coordinates.
    CGRect screen = CGRectMake(0, 0, MIN(size.width, size.height), MAX(size.width, size.height));
    _window = [[PerfOverlayWindow alloc] initWithFrame:screen];
    _window.windowLevel = UIWindowLevelStatusBar + 1.0;
    _window.backgroundColor = [UIColor clearColor];
    _window.opaque = NO;
    _window.userInteractionEnabled = NO;
    _window.hidden = YES;

    CGFloat panelWidth = 142.0;
    CGFloat panelHeight = 78.0;
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(10.0, 30.0, panelWidth, panelHeight)];
    panel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.55];
    panel.layer.cornerRadius = 6.0;
    panel.layer.borderWidth = 1.0;
    panel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    panel.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    panel.userInteractionEnabled = NO;
    [_window addSubview:panel];
    _panel = panel;
    [panel release];

    _label = [[UILabel alloc] initWithFrame:CGRectInset(panel.bounds, 8.0, 5.0)];
    _label.backgroundColor = [UIColor clearColor];
    _label.textColor = [UIColor colorWithRed:0.55 green:1.0 blue:0.55 alpha:1.0];
    UIFont *font = [UIFont fontWithName:@"Courier-Bold" size:12.0];
    if (!font) font = [UIFont boldSystemFontOfSize:12.0];
    _label.font = font;
    _label.numberOfLines = 0;
    _label.text = @"FPS  --\nCPU  --\nRAM  --\nGPU3D --";
    _label.userInteractionEnabled = NO;
    [panel addSubview:_label];

    Class displayLinkClass = NSClassFromString(@"CADisplayLink");
    if (displayLinkClass) {
        _link = [displayLinkClass displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
        _link.paused = YES;
        [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    } else {
        PLog(@"CADisplayLink unavailable");
    }

    CFNotificationCenterRef center = CFNotificationCenterGetDarwinNotifyCenter();
    CFNotificationCenterAddObserver(center, NULL, PerfOverlayToggleNotification,
                                    CFSTR(PERF_TOGGLE_ON), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, PerfOverlayToggleNotification,
                                    CFSTR(PERF_TOGGLE_OFF), NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChanged:)
        name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    CFNotificationCenterAddObserver(center, NULL, PerfOverlayOrientationNotification,
        CFSTR("com.apple.backboardd.orientation"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center,NULL,PerfOverlaySettingsNotification,
        PERF_SETTINGS_CHANGED,NULL,CFNotificationSuspensionBehaviorDeliverImmediately);
    [self reloadSettings];
    PLog(@"started pid=%d screen=%.0fx%.0f windowLevel=%.1f gpuService=%s visible=%d",
         getpid(), screen.size.width, screen.size.height, _window.windowLevel, gGPUService,
         _overlayVisible);
}

- (void)reloadSettings {
    CFPreferencesAppSynchronize(PERF_PREF_DOMAIN);
    _showFPS=BoolPreference(CFSTR("ShowFPS"),YES);
    _showCPU=BoolPreference(CFSTR("ShowCPU"),YES);
    _showCores=BoolPreference(CFSTR("ShowCores"),YES);
    _showRAM=BoolPreference(CFSTR("ShowRAM"),YES);
    _showGPU=BoolPreference(CFSTR("ShowGPU"),YES);
    _corner=(int)NumberPreference(CFSTR("Corner"),0,0,3);
    _fontSize=NumberPreference(CFSTR("FontSize"),12,8,20);
    _opacity=NumberPreference(CFSTR("Opacity"),0.55,0,1);
    _sampleInterval=NumberPreference(CFSTR("Interval"),1,0.5,5);
    UIFont *font=[UIFont fontWithName:@"Courier-Bold" size:_fontSize];
    _label.font=font?:[UIFont boldSystemFontOfSize:_fontSize];
    _panel.backgroundColor=[UIColor colorWithWhite:0 alpha:_opacity];
    [self stopSampling];
    [self setOverlayVisible:ReadEnabledPreference()];
    if(_overlayVisible)[self startSampling];
    [self layoutPanel];
    PLog(@"settings fps=%d cpu=%d cores=%d ram=%d gpu=%d corner=%d font=%.0f interval=%.1f",
        _showFPS,_showCPU,_showCores,_showRAM,_showGPU,_corner,_fontSize,_sampleInterval);
}

- (void)layoutPanel {
    NSArray *lines=[_label.text componentsSeparatedByString:@"\n"];
    CGFloat width=0;for(NSString *line in lines)width=MAX(width,[line sizeWithFont:_label.font].width);
    _panel.bounds=CGRectMake(0,0,ceil(MAX(142,width+16)),ceil(_label.font.lineHeight*lines.count+10));
    _label.frame=CGRectInset(_panel.bounds,8,5);
    int turns=_orientation==UIInterfaceOrientationLandscapeLeft?-1:
        (_orientation==UIInterfaceOrientationLandscapeRight?1:(_orientation==UIInterfaceOrientationPortraitUpsideDown?2:0));
    _panel.center=PerfHUDPanelCenter(_window.bounds.size,_panel.bounds.size,turns,_corner);
}

- (void)orientationChanged:(NSNotification *)notification {
    [self performSelectorOnMainThread:@selector(updateOrientation) withObject:nil waitUntilDone:NO];
}

- (void)updateOrientation {
    if (!_panel) return;
    UIApplication *app = [UIApplication sharedApplication];
    UIInterfaceOrientation orientation = [app respondsToSelector:@selector(activeInterfaceOrientation)]
        ? [app activeInterfaceOrientation] : app.statusBarOrientation;
    int turns;
    switch (orientation) {
        case UIInterfaceOrientationPortrait: turns = 0; break;
        case UIInterfaceOrientationPortraitUpsideDown: turns = 2; break;
        case UIInterfaceOrientationLandscapeLeft: turns = -1; break;
        case UIInterfaceOrientationLandscapeRight: turns = 1; break;
        default: return; // Keep the last valid interface during transitions.
    }
    if (_orientation == orientation) return;
    CGAffineTransform screenTransform = PerfHUDScreenTransform(_window.bounds.size, turns);

    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:_overlayVisible && _orientation ? 0.2 : 0.0];
    [UIView setAnimationBeginsFromCurrentState:YES];
    _panel.transform = CGAffineTransformMake(screenTransform.a, screenTransform.b,
                                            screenTransform.c, screenTransform.d, 0, 0);
    _panel.center = PerfHUDPanelCenter(_window.bounds.size,_panel.bounds.size,turns,_corner);
    [UIView commitAnimations];
    _orientation = orientation;
    PLog(@"HUD orientation=%ld", (long)orientation);
}

- (void)applyEnabledPreference {
    if (!_window) return;
    [self setOverlayVisible:ReadEnabledPreference()];
}

- (void)handleToggleNotification:(NSNumber *)enabled {
    if (!_window) return;
    BOOL visible = [enabled boolValue];
    // NCSettings normally writes this too; writing it here keeps the state
    // correct even if the widget process cannot write preferences.
    WriteEnabledPreference(visible);
    [self setOverlayVisible:visible];
}

- (void)setOverlayVisible:(BOOL)visible {
    if (!_window) return;
    if (_overlayVisible == visible && _window.hidden == !visible) return;

    _overlayVisible = visible;
    if (visible) [self updateOrientation];
    _window.hidden = !visible;
    if (visible) {
        // The frame counter and CPU ticks are stale after a pause. Start from
        // a fresh baseline instead of reporting the whole hidden interval.
        _frames = 0;
        _fpsStart = 0.0;
        _fpsValid = NO;
        _haveFrameCounter = NO;
        _globalZeroTicks = 0;
        [self startSampling];
    } else {
        [self stopSampling];
    }
    PLog(@"overlay %@", visible ? @"shown" : @"hidden");
}

- (void)startSampling {
    if (_link) _link.paused = !_showFPS || _useGlobalFPS;
    if (!_timer) {
        gPrevCPUs=0;
        _timer = [[NSTimer scheduledTimerWithTimeInterval:_sampleInterval target:self selector:@selector(tick)
                                                userInfo:nil repeats:YES] retain];
    }
    [self tick];
}

- (void)stopSampling {
    if (_link) _link.paused = YES;
    if (_timer) {
        [_timer invalidate];
        [_timer release];
        _timer = nil;
    }
    _frames = 0;
    _fpsStart = 0.0;
    _fpsValid = NO;
    _haveFrameCounter = NO;
    _globalZeroTicks = 0;
}

- (void)displayLinkFired:(CADisplayLink *)link {
    if (_useGlobalFPS) return;
    _frames++;
    if (_fpsStart == 0.0) _fpsStart = link.timestamp;
    CFTimeInterval elapsed = link.timestamp - _fpsStart;
    if (elapsed >= 1.0) {
        _fps = (double)_frames / elapsed;
        _frames = 0;
        _fpsStart = link.timestamp;
        _fpsValid = YES;
    }
}

- (void)tick {
    if (!_window) return;
    [self updateOrientation]; // Existing one-second sampler covers missed/older OS notifications.

    if (_showFPS && !_globalFPSTried) {
        _globalFPSTried = YES;
        _useGlobalFPS = LoadGlobalFrameCounter();
    }
    if (_link) _link.paused = !_showFPS || _useGlobalFPS;
    if (_showFPS && _useGlobalFPS) {
        uint32_t counter = 0;
        if (!ReadGlobalFrameCounter(&counter)) {
            // Only a real API/port failure may switch to the display link.
            // A transient counter value of zero is not such a failure.
            _useGlobalFPS = NO;
            _haveFrameCounter = NO;
            _fpsValid = NO;
            _frames = 0;
            _fpsStart = 0.0;
            PLog(@"global frame counter lost, falling back to display link");
        } else if (!_haveFrameCounter) {
            // The counter can be 0 before the render server presents its first
            // frame, or while it is restarting. Wait for a nonzero baseline;
            // never replace the real counter with a synthetic 60 Hz value.
            _globalZeroTicks++;
            if (_globalZeroTicks == 10) {
                PLog(@"global frame counter still zero; keeping global mode");
            }
            if (counter > 0) {
                _lastFrameCounter = counter;
                _lastFrameTime = CACurrentMediaTime();
                _haveFrameCounter = YES;
                _globalZeroTicks = 0;
            }
        } else if (counter == 0) {
            // Counter reset (render server restart). Rebaseline on the next
            // nonzero sample and report this tick as idle, not as 60 FPS.
            _haveFrameCounter = NO;
            _fps = 0.0;
            _fpsValid = YES;
            _globalZeroTicks = 0;
            PLog(@"global frame counter reset, rebaselining");
        } else {
            CFTimeInterval now = CACurrentMediaTime();
            if (now > _lastFrameTime) {
                uint32_t delta = counter - _lastFrameCounter; // unsigned wrap-safe
                double elapsed = now - _lastFrameTime;
                // A counter reset can look like a huge unsigned delta if it
                // happens without passing through zero. Treat impossible rates
                // as a new baseline instead of showing a bogus FPS spike.
                if (elapsed > 0.0 && (double)delta / elapsed <= 240.0) {
                    _fps = (double)delta / elapsed;
                    _fpsValid = YES;
                } else {
                    _fps = 0.0;
                    _fpsValid = YES;
                    PLog(@"global frame counter jump, rebaselining");
                }
            }
            _lastFrameCounter = counter;
            _lastFrameTime = now;
        }
    }

    double cpu = (_showCPU||_showCores)?CPUUsage():-1;
    _cpuValid=cpu>=0.0;
    if(_cpuValid)_cpu=cpu;

    double used = 0.0, total = 0.0;
    _ramValid=_showRAM && MemoryUsage(&used,&total);
    if (_ramValid) {
        _usedMB = used;
        _totalMB = total;
        _ramValid = YES;
    }

    int gpu = _showGPU?GPUUtilization():-1;
    _gpu = gpu;

    NSMutableArray *rows=[NSMutableArray array];
    if(_showFPS)[rows addObject:_fpsValid?(_fps<1?@"FPS  idle":[NSString stringWithFormat:@"FPS  %2.0f",_fps]):@"FPS  --"];
    if(_showCPU)[rows addObject:_cpuValid?[NSString stringWithFormat:@"CPU  %2.0f%%",_cpu]:@"CPU  --"];
    if(_showCores)for(unsigned int i=0;i<gCoreCount;i++)
        [rows addObject:gCoreUsage[i]>=0?[NSString stringWithFormat:@"CPU%u %2.0f%%",i+1,gCoreUsage[i]]:[NSString stringWithFormat:@"CPU%u --",i+1]];
    if(_showRAM)[rows addObject:_ramValid?[NSString stringWithFormat:@"RAM  %3.0f/%3.0fM",_usedMB,_totalMB]:@"RAM  --"];
    if(_showGPU)[rows addObject:_gpu>=0?[NSString stringWithFormat:@"GPU3D %2d%%",_gpu]:@"GPU3D n/a"];
    _panel.hidden=rows.count==0;
    _label.text=[rows componentsJoinedByString:@"\n"];
    [self layoutPanel];

    NSMutableArray *cores=[NSMutableArray array];
    if(_showCores)for(unsigned int i=0;i<gCoreCount;i++)[cores addObject:gCoreUsage[i]>=0?[NSString stringWithFormat:@"%.1f",gCoreUsage[i]]:@"--"];
    PLog(@"tick fps=%@ src=%@ cpu=%@ cores=%@ ram=%.0f/%.0f gpu=%d",
         _fpsValid ? [NSString stringWithFormat:@"%.1f", _fps] : @"--",
         _useGlobalFPS ? @"global" : @"displaylink",
         _cpuValid ? [NSString stringWithFormat:@"%.1f", _cpu] : @"--",
         [cores componentsJoinedByString:@","], _usedMB, _totalMB, _gpu);
}

@end

__attribute__((constructor)) static void PerfOverlayInit(void) {
    @autoreleasepool {
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if (![bundle isEqualToString:@"com.apple.springboard"]) return;
        FILE *fresh = fopen(PERF_LOG, "w");
        if (fresh) fclose(fresh);
        PLog(@"loaded into %@ pid=%d mainThread=%d", bundle, getpid(), (int)[NSThread isMainThread]);
        RegisterWithNCSettingsIfNeeded();
        // Wait for SpringBoard's run loop and initial UI to settle.
        [[PerfOverlay shared] performSelector:@selector(start) withObject:nil afterDelay:2.0];
    }
}
