// NCSettings toggle for PerfOverlay.
// Loaded by NCSettings from /var/mobile/Library/NCSettings/Toggles/PerfOverlay.
// The SpringBoard tweak listens for the two Darwin notifications below.

#import <Foundation/Foundation.h>
#include <notify.h>
#include <stdarg.h>
#include <stdio.h>

#define PREF_DOMAIN CFSTR("com.local.perfoverlay")
#define PREF_KEY CFSTR("Enabled")
#define TOGGLE_ON "com.local.perfoverlay.toggle.on"
#define TOGGLE_OFF "com.local.perfoverlay.toggle.off"
#define TOGGLE_LOG "/tmp/perf-toggle.log"

static void TLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    FILE *f = fopen(TOGGLE_LOG, "a");
    if (f) {
        fprintf(f, "%s\n", [line UTF8String]);
        fclose(f);
    }
    [line release];
}

static BOOL ReadEnabled(void) {
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    Boolean exists = false;
    Boolean value = CFPreferencesGetAppBooleanValue(PREF_KEY, PREF_DOMAIN, &exists);
    return exists ? (value ? YES : NO) : YES;
}

static void WriteEnabled(BOOL enabled) {
    CFPreferencesSetAppValue(PREF_KEY, enabled ? kCFBooleanTrue : kCFBooleanFalse, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);
}

// NCSettings' settings pane dlcloses a toggle after asking for its name, then
// uses the returned string. A compile-time @"literal" would live in the
// unloaded dylib and become a dangling pointer, so allocate these strings in
// Foundation instead. They are intentionally retained for the process life.
static NSString *DurableString(const char *text) {
    return [[NSString alloc] initWithUTF8String:text];
}

void load(void) {
    TLog(@"load");
}

void unload(void) {
    TLog(@"unload");
}

BOOL isCapable(void) {
    TLog(@"isCapable");
    return YES;
}

BOOL isEnabled(void) {
    BOOL enabled = ReadEnabled();
    TLog(@"isEnabled -> %d", enabled);
    return enabled;
}

NSString *localizedName(void) {
    TLog(@"localizedName");
    return DurableString("HUD");
}

NSString *localizedMessageForState(BOOL enabled) {
    TLog(@"localizedMessageForState(%d)", enabled);
    return DurableString(enabled ? "HUD on" : "HUD off");
}

NSString *graphicNameForState(BOOL enabled) {
    TLog(@"graphicNameForState(%d)", enabled);
    // NCSettings builds "<toggle folder>/<graphic name>.png". The folder name
    // already identifies PerfOverlay, so the graphic name is just the state.
    return DurableString(enabled ? "on" : "off");
}

void setState(BOOL enabled) {
    TLog(@"setState(%d)", enabled);
    // SpringBoard also writes the preference when it receives the notification,
    // so the toggle still works if this process cannot write the plist.
    WriteEnabled(enabled);
    notify_post(enabled ? TOGGLE_ON : TOGGLE_OFF);
}
