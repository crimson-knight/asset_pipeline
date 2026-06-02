// notifications_bridge.m — portable UNUserNotificationCenter bridge.
//
// WHY THIS FILE EXISTS (separate from objc_bridge.m):
//   objc_bridge.m is a UIKit/AppKit VIEW bridge — it imports AppKit/UIKit/
//   WebKit/MapKit, none of which exist on watchOS, so it is deliberately NOT
//   compiled for the watch (see samples/.../watchos/build_crystal_lib.sh).
//   But UserNotifications IS available on watchOS, and the agent-comms vision
//   needs the watch to schedule local notifications. This TU contains ONLY the
//   `ap_notifications_*` functions and imports ONLY Foundation +
//   UserNotifications, so it compiles cleanly for macOS, iOS, AND watchOS.
//
//   The macOS/iOS native builds keep their copies of these functions inside
//   objc_bridge.m and do NOT compile this file, so the symbols are never
//   co-linked (no duplicate-symbol error). The watch build compiles THIS file
//   (and not objc_bridge.m). The duplication is small and the functions are
//   stable; a future cleanup could make every Apple build compile this TU and
//   drop the objc_bridge.m copies — that touches ~8 build scripts and the
//   SystemAction permission path, so it is intentionally deferred.
//
// Compile (watchOS simulator):
//   clang -c src/ui/native/notifications_bridge.m -o notifications_bridge.o \
//     -arch arm64 -isysroot $(xcrun --sdk watchsimulator --show-sdk-path) \
//     -mwatchos-simulator-version-min=10.0 -fno-objc-arc

#include <stdlib.h>
#include <string.h>
#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

static NSString *ap_nb_string_from_cstr(const char *value) {
    if (!value || !value[0]) return nil;
    return [NSString stringWithUTF8String:value];
}

static UNUserNotificationCenter *ap_notifications_center(void) {
    Class center_class = NSClassFromString(@"UNUserNotificationCenter");
    if (!center_class) return nil;
    // +currentNotificationCenter THROWS (NSInternalInconsistencyException,
    // "bundleProxyForCurrentProcess is nil") in a process with no app bundle — e.g.
    // a bare CLI binary. Guard on the main bundle identifier so notifications
    // gracefully no-op there (every caller handles a nil center) instead of
    // aborting. (watchOS apps always have a bundle; harmless there.)
    if ([[NSBundle mainBundle] bundleIdentifier] == nil) return nil;
    return [UNUserNotificationCenter currentNotificationCenter];
}

long long ap_notifications_authorization_status(void) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return 5;

    __block long long status = 5;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        if (settings) {
            status = (long long)settings.authorizationStatus;
        }
        dispatch_semaphore_signal(sema);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(sema, timeout);
    return status;
}

int ap_notifications_request_authorization(int alert, int sound, int badge, int provisional) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return 0;

    UNAuthorizationOptions options = 0;
    if (alert) options |= UNAuthorizationOptionAlert;
    if (sound) options |= UNAuthorizationOptionSound;
    if (badge) options |= UNAuthorizationOptionBadge;
    // Provisional = quiet, no-prompt authorization (no permission dialog / tap).
    if (provisional) options |= UNAuthorizationOptionProvisional;

    __block BOOL granted = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [center requestAuthorizationWithOptions:options completionHandler:^(BOOL ok, NSError *error) {
        granted = (ok && error == nil);
        dispatch_semaphore_signal(sema);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(sema, timeout);
    return granted ? 1 : 0;
}

int ap_notifications_schedule_local(const char *identifier_cstr,
                                    const char *title_cstr,
                                    const char *subtitle_cstr,
                                    const char *body_cstr,
                                    double delay_seconds,
                                    int badge,
                                    int play_sound,
                                    int repeats,
                                    const char *thread_id_cstr) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return 0;

    NSString *title = ap_nb_string_from_cstr(title_cstr);
    NSString *body = ap_nb_string_from_cstr(body_cstr);
    if (!title || !body || !title.length || !body.length) return 0;

    NSString *identifier = ap_nb_string_from_cstr(identifier_cstr);
    if (!identifier || !identifier.length) {
        identifier = [NSString stringWithFormat:@"ui-notification-%f", CFAbsoluteTimeGetCurrent()];
    }

    NSString *subtitle = ap_nb_string_from_cstr(subtitle_cstr);
    NSString *thread_id = ap_nb_string_from_cstr(thread_id_cstr);

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.body = body;
    if (subtitle && subtitle.length) {
        content.subtitle = subtitle;
    }
    if (thread_id && thread_id.length) {
        content.threadIdentifier = thread_id;
    }
    if (badge >= 0) {
        content.badge = [NSNumber numberWithInt:badge];
    }
    if (play_sound) {
        content.sound = UNNotificationSound.defaultSound;
    }

    NSTimeInterval interval = delay_seconds > 0.0 ? delay_seconds : 0.25;
    if (repeats && interval < 60.0) {
        interval = 60.0;
    }

    UNTimeIntervalNotificationTrigger *trigger =
        [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:interval repeats:(BOOL)repeats];
    UNNotificationRequest *request =
        [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:trigger];

    __block BOOL scheduled = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
        scheduled = (error == nil);
        dispatch_semaphore_signal(sema);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(sema, timeout);
    [content release];
    return scheduled ? 1 : 0;
}

void ap_notifications_remove_pending(const char *identifier_cstr) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return;

    NSString *identifier = ap_nb_string_from_cstr(identifier_cstr);
    if (!identifier || !identifier.length) return;
    [center removePendingNotificationRequestsWithIdentifiers:@[identifier]];
}

void ap_notifications_remove_all_pending(void) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return;
    [center removeAllPendingNotificationRequests];
}

// See objc_bridge.m for the rationale: pending requests are tracked
// independently of authorization, so a count increase is an honest signal that
// a schedule landed — usable as a functional-outcome assertion.
int ap_notifications_pending_count(void) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return -1;

    __block int count = -1;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        count = requests ? (int)requests.count : 0;
        dispatch_semaphore_signal(sema);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(sema, timeout);
    return count;
}

int ap_notifications_has_pending(const char *identifier_cstr) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return -1;

    NSString *identifier = ap_nb_string_from_cstr(identifier_cstr);
    if (!identifier || !identifier.length) return 0;

    __block int found = 0;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [center getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
        for (UNNotificationRequest *req in requests) {
            if ([req.identifier isEqualToString:identifier]) { found = 1; break; }
        }
        dispatch_semaphore_signal(sema);
    }];

    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC));
    dispatch_semaphore_wait(sema, timeout);
    return found;
}

// ---- Foreground delivery → Crystal (the agent reaches you, with voice) ----
// Implemented in Crystal (src/ui/notifications.cr): routes the delivered body to
// the registered UI::Notifications.on_foreground handler.
extern void ap_on_foreground_notification(const char *body);

@interface APForegroundNotifDelegate : NSObject <UNUserNotificationCenterDelegate>
@end
@implementation APForegroundNotifDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSString *body = notification.request.content.body;
    if (body && body.length) ap_on_foreground_notification([body UTF8String]);
    if (@available(watchOS 7.0, iOS 14.0, macOS 11.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner |
                          UNNotificationPresentationOptionSound |
                          UNNotificationPresentationOptionList);
    } else {
        completionHandler(UNNotificationPresentationOptionSound);
    }
}
@end

static APForegroundNotifDelegate *g_fg_delegate = nil;
void ap_notifications_install_foreground_delegate(void) {
    UNUserNotificationCenter *center = ap_notifications_center();
    if (!center) return;
    if (!g_fg_delegate) g_fg_delegate = [[APForegroundNotifDelegate alloc] init];
    center.delegate = g_fg_delegate;
}
