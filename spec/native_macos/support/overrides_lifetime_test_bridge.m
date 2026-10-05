#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdint.h>

// --- Overrides lifetime harness -------------------------------------------
//
// Counts the live instances of `APSK*Overrides` classes. Tracking installs a
// `+new` on a class (the selector every `apsk_*_overrides_new` allocator
// sends) that records each instance in a weak hash table, so an instance
// leaves the count only when the runtime deallocates it.
//
// Compiled with `-fno-objc-arc`, like the bridges it exercises.

static NSHashTable *ap_spec_tracked_overrides = nil;
static IMP ap_spec_inherited_new = NULL;

static id ap_spec_tracking_new(Class cls, SEL selector) {
    id instance = ((id (*)(Class, SEL))ap_spec_inherited_new)(cls, selector);
    if (instance != nil) [ap_spec_tracked_overrides addObject:instance];
    return instance;
}

// Starts counting the live instances of `class_name`. Returns 1 when the
// class is tracked (now or already), 0 when the class does not exist or
// defines its own `+new`.
int32_t ap_spec_overrides_track(const char *class_name) {
    Class cls = objc_getClass(class_name);
    if (cls == nil) return 0;
    if (ap_spec_tracked_overrides == nil) {
        ap_spec_tracked_overrides = [[NSHashTable weakObjectsHashTable] retain];
        ap_spec_inherited_new = method_getImplementation(
            class_getClassMethod([NSObject class], @selector(new)));
    }
    Method inherited = class_getClassMethod(cls, @selector(new));
    if (method_getImplementation(inherited) == (IMP)ap_spec_tracking_new) return 1;
    BOOL added = class_addMethod(object_getClass(cls), @selector(new),
                                 (IMP)ap_spec_tracking_new,
                                 method_getTypeEncoding(inherited));
    return added ? 1 : 0;
}

// The number of tracked instances the runtime has not deallocated yet.
int64_t ap_spec_overrides_live_count(void) {
    if (ap_spec_tracked_overrides == nil) return 0;
    int64_t count = 0;
    @autoreleasepool {
        // `allObjects` holds each survivor until this pool drains, so the
        // count never keeps one alive past this call.
        count = (int64_t)[[ap_spec_tracked_overrides allObjects] count];
    }
    return count;
}
