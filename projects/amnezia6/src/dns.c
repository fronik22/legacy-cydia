/*
 * Push the tunnel DNS server into the iOS dynamic store.
 *
 * SCDynamicStore is public on macOS but marked unavailable in the iOS SDK.
 * iOS still exports the symbols, so resolve them at runtime instead of
 * declaring or linking the unavailable API directly.
 */

#include "dns.h"

#include "log.h"

#include <CoreFoundation/CoreFoundation.h>

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

typedef void *(*create_fn)(CFAllocatorRef, CFStringRef, void *, void *);
typedef Boolean (*set_fn)(void *, CFStringRef, CFPropertyListRef);
typedef Boolean (*remove_fn)(void *, CFStringRef);

typedef struct {
    void *handle;
    create_fn create;
    set_fn set;
    remove_fn remove;
} sc_api_t;

static sc_api_t g_sc;
static int g_sc_loaded;

static int load_sc(void) {
    if (g_sc_loaded) return g_sc.create && g_sc.set && g_sc.remove ? 0 : -1;
    g_sc_loaded = 1;
    g_sc.handle = dlopen("/System/Library/Frameworks/SystemConfiguration.framework/SystemConfiguration",
                         RTLD_LAZY);
    if (!g_sc.handle) {
        a6_log("SystemConfiguration could not be loaded: %s", dlerror());
        return -1;
    }
    g_sc.create = (create_fn)dlsym(g_sc.handle, "SCDynamicStoreCreate");
    g_sc.set = (set_fn)dlsym(g_sc.handle, "SCDynamicStoreAddTemporaryValue");
    g_sc.remove = (remove_fn)dlsym(g_sc.handle, "SCDynamicStoreRemoveValue");
    if (!g_sc.create || !g_sc.set || !g_sc.remove) {
        a6_log("SCDynamicStore symbols are not available");
        return -1;
    }
    return 0;
}

static CFStringRef cfstr(const char *s) {
    return CFStringCreateWithCString(NULL, s, kCFStringEncodingUTF8);
}

static int set_value(void *store, const char *key, CFPropertyListRef value) {
    CFStringRef k = cfstr(key);
    Boolean ok;
    if (!k) return -1;
    ok = value ? g_sc.set(store, k, value) : g_sc.remove(store, k);
    CFRelease(k);
    return ok ? 0 : -1;
}

static CFArrayRef one_string_array(const char *value) {
    CFStringRef s = cfstr(value);
    CFArrayRef a;
    if (!s) return NULL;
    a = CFArrayCreate(NULL, (const void **)&s, 1, &kCFTypeArrayCallBacks);
    CFRelease(s);
    return a;
}

static CFMutableDictionaryRef dns_dict(const char *ifname, const char *server) {
    CFMutableDictionaryRef d = CFDictionaryCreateMutable(NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFArrayRef addrs = one_string_array(server);
    CFStringRef iface = cfstr(ifname);
    if (!d || !addrs || !iface) {
        if (d) CFRelease(d);
        if (addrs) CFRelease(addrs);
        if (iface) CFRelease(iface);
        return NULL;
    }
    CFDictionarySetValue(d, CFSTR("ServerAddresses"), addrs);
    CFDictionarySetValue(d, CFSTR("InterfaceName"), iface);
    CFRelease(addrs);
    CFRelease(iface);
    return d;
}

static CFMutableDictionaryRef ipv4_dict(const char *ifname, const char *address) {
    CFMutableDictionaryRef d = CFDictionaryCreateMutable(NULL, 0,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFArrayRef addrs = one_string_array(address);
    CFStringRef iface = cfstr(ifname);
    CFStringRef router = cfstr(address);
    CFNumberRef one = NULL;
    int v = 1;
    if (!d || !addrs || !iface || !router) goto fail;
    one = CFNumberCreate(NULL, kCFNumberIntType, &v);
    if (!one) goto fail;
    CFDictionarySetValue(d, CFSTR("Addresses"), addrs);
    CFDictionarySetValue(d, CFSTR("DestAddresses"), addrs);
    CFDictionarySetValue(d, CFSTR("InterfaceName"), iface);
    CFDictionarySetValue(d, CFSTR("OverridePrimary"), one);
    CFDictionarySetValue(d, CFSTR("Router"), router);
    CFRelease(addrs);
    CFRelease(iface);
    CFRelease(router);
    CFRelease(one);
    return d;

fail:
    if (d) CFRelease(d);
    if (addrs) CFRelease(addrs);
    if (iface) CFRelease(iface);
    if (router) CFRelease(router);
    if (one) CFRelease(one);
    return NULL;
}

int a6_dns_up(a6_dns_t *dns, const char *ifname, const char *address,
              const char *server) {
    CFMutableDictionaryRef sdns = NULL, sipv4 = NULL;
    char key[160];
    int ok = -1;

    if (!dns || !ifname || !address || !server) return -1;
    memset(dns, 0, sizeof *dns);
    snprintf(dns->service, sizeof dns->service, "com.mak.amnezia6");
    if (load_sc() != 0) return -1;
    dns->store = g_sc.create(NULL, CFSTR("amnezia6d"), NULL, NULL);
    if (!dns->store) {
        a6_log("SCDynamicStoreCreate failed");
        return -1;
    }

    sdns = dns_dict(ifname, server);
    sipv4 = ipv4_dict(ifname, address);
    if (!sdns || !sipv4) goto done;

    /* configd derives global state; temporary keys also vanish on a crash. */

    snprintf(key, sizeof key, "State:/Network/Service/%s/DNS", dns->service);
    if (set_value(dns->store, key, sdns) != 0) goto done;
    snprintf(key, sizeof key, "State:/Network/Service/%s/IPv4", dns->service);
    if (set_value(dns->store, key, sipv4) != 0) goto done;

    dns->active = 1;
    ok = 0;

done:
    if (sdns) CFRelease(sdns);
    if (sipv4) CFRelease(sipv4);
    if (ok != 0) a6_dns_down(dns);
    return ok;
}

void a6_dns_down(a6_dns_t *dns) {
    char key[160];
    if (!dns) return;
    if (dns->store) {
        snprintf(key, sizeof key, "State:/Network/Service/%s/DNS", dns->service);
        (void)set_value(dns->store, key, NULL);
        snprintf(key, sizeof key, "State:/Network/Service/%s/IPv4", dns->service);
        (void)set_value(dns->store, key, NULL);
        CFRelease((CFTypeRef)dns->store);
    }
    memset(dns, 0, sizeof *dns);
}
