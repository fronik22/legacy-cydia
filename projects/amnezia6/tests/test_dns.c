/* Exercise cleanup without changing the host's network configuration. */
#include "../src/dns.c"
#include <assert.h>

static CFMutableDictionaryRef values;
static int writes, fail_at;
static CFArrayRef last_servers;

static void *fake_create(CFAllocatorRef a, CFStringRef n, void *cb, void *ctx) {
    return (void *)CFRetain(values);
}
static Boolean fake_add(void *store, CFStringRef key, CFPropertyListRef value) {
    assert(value != NULL);
    assert(CFStringHasPrefix(key, CFSTR("State:/Network/Service/com.mak.amnezia6/")));
    if (CFStringHasSuffix(key, CFSTR("/DNS"))) {
        if (last_servers) CFRelease(last_servers);
        last_servers = CFRetain(CFDictionaryGetValue(value, CFSTR("ServerAddresses")));
    }
    if (++writes == fail_at) return false;
    CFDictionarySetValue(store, key, value);
    return true;
}
static Boolean fake_remove(void *store, CFStringRef key) {
    CFDictionaryRemoveValue(store, key);
    return true;
}
int main(void) {
    a6_dns_t dns;
    values = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks,
                                       &kCFTypeDictionaryValueCallBacks);
    g_sc_loaded = 1;
    g_sc.create = fake_create;
    g_sc.set = fake_add;
    g_sc.remove = fake_remove;
    assert(a6_dns_up(&dns, "utun0", "10.0.0.2", "10.0.0.1") == 0);
    assert(CFDictionaryGetCount(values) == 2);
    a6_dns_down(&dns);
    assert(CFDictionaryGetCount(values) == 0 && !dns.store);
    a6_dns_down(&dns);
    assert(a6_dns_up(&dns, "utun0", "10.0.0.2", "192.0.2.53,198.51.100.53") == 0);
    assert(CFArrayGetCount(last_servers) == 2);
    assert(CFEqual(CFArrayGetValueAtIndex(last_servers, 0), CFSTR("192.0.2.53")));
    assert(CFEqual(CFArrayGetValueAtIndex(last_servers, 1), CFSTR("198.51.100.53")));
    a6_dns_down(&dns);assert(CFDictionaryGetCount(values) == 0 && !dns.store);
    writes = 0; fail_at = 2;
    assert(a6_dns_up(&dns, "utun0", "10.0.0.2", "192.0.2.53,198.51.100.53") == -1);
    assert(CFArrayGetCount(last_servers) == 2);
    assert(CFDictionaryGetCount(values) == 0 && !dns.store);
    CFRelease(last_servers);CFRelease(values);
    puts("DNS cleanup and partial-failure tests passed");
    return 0;
}
