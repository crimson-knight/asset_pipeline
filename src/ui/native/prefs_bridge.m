// prefs_bridge.m — portable NSUserDefaults (persistent settings) bridge.
//
// Same rationale as notifications_bridge.m / speech_bridge.m: objc_bridge.m can't
// compile on watchOS, but NSUserDefaults is plain Foundation (available
// everywhere). This TU imports ONLY Foundation, so it compiles for macOS, iOS,
// AND watchOS. The watch build compiles THIS file; macOS/iOS keep their copies in
// objc_bridge.m and don't compile this one (symbols never co-linked).
//
// Compile (watchOS simulator):
//   clang -c src/ui/native/prefs_bridge.m -o prefs_bridge.o \
//     -arch arm64 -isysroot $(xcrun --sdk watchsimulator --show-sdk-path) \
//     -mwatchos-simulator-version-min=10.0 -fno-objc-arc

#include <stdlib.h>
#include <string.h>
#import <Foundation/Foundation.h>

static NSString *ap_pb_key(const char *key) {
    if (!key || !key[0]) return nil;
    return [NSString stringWithUTF8String:key];
}

void ap_prefs_set_bool(const char *key, int value) {
    NSString *k = ap_pb_key(key);
    if (!k) return;
    [[NSUserDefaults standardUserDefaults] setBool:(value != 0) forKey:k];
}

int ap_prefs_get_bool(const char *key, int default_value) {
    NSString *k = ap_pb_key(key);
    if (!k) return default_value;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:k] == nil) return default_value; // unset → default
    return [d boolForKey:k] ? 1 : 0;
}

void ap_prefs_set_double(const char *key, double value) {
    NSString *k = ap_pb_key(key);
    if (!k) return;
    [[NSUserDefaults standardUserDefaults] setDouble:value forKey:k];
}

double ap_prefs_get_double(const char *key, double default_value) {
    NSString *k = ap_pb_key(key);
    if (!k) return default_value;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d objectForKey:k] == nil) return default_value; // unset → default
    return [d doubleForKey:k];
}

void ap_prefs_clear_all(void) {
    NSString *domain = [[NSBundle mainBundle] bundleIdentifier];
    if (domain) [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domain];
}
