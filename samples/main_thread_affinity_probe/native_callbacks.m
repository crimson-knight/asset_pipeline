// Native callback paths for the main-thread affinity probe. Both helpers call
// back into Crystal the way an AppKit app does: synchronously from native code
// on the calling thread, and asynchronously through the main dispatch queue
// while the main run loop runs.
#import <Foundation/Foundation.h>
#include <stdatomic.h>

typedef void (*probe_callback_fn)(int index);

// Calls *callback* *count* times on the current thread, the way an AppKit
// target-action or delegate method calls into Crystal.
int probe_call_back_synchronously(probe_callback_fn callback, int count) {
    for (int index = 0; index < count; index++) {
        callback(index);
    }
    return count;
}

static atomic_int g_main_queue_callbacks_run = 0;

// Posts *count* callbacks to the main dispatch queue from a background GCD
// queue, then runs the current (main) run loop until every callback has run or
// *timeout_seconds* passes. Returns how many callbacks ran.
int probe_call_back_on_main_queue(probe_callback_fn callback, int count, double timeout_seconds) {
    atomic_store(&g_main_queue_callbacks_run, 0);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        for (int index = 0; index < count; index++) {
            dispatch_async(dispatch_get_main_queue(), ^{
                callback(index);
                atomic_fetch_add(&g_main_queue_callbacks_run, 1);
            });
        }
    });

    CFAbsoluteTime deadline = CFAbsoluteTimeGetCurrent() + timeout_seconds;
    while (atomic_load(&g_main_queue_callbacks_run) < count &&
           CFAbsoluteTimeGetCurrent() < deadline) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, true);
    }
    return atomic_load(&g_main_queue_callbacks_run);
}
