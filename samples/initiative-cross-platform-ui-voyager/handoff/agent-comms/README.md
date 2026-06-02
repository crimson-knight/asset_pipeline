# Agent-comms — local notifications (the agent can reach you)

The Happy Coach vision starts with the agent being able to reach you. The Daily
Check-in reminder Toggle schedules a REAL recurring `UNUserNotificationCenter`
local notification via the kit's `UI::Notifications` facade — proven on iOS AND
watchOS against the system's actual pending queue (not a synthetic flag).

## iOS (commit a8e5bce4)
XCUITest `CheckInTests.testSaveSchedulesAndCancelsRealReminder` (iPhone 17 Pro,
iOS 26): Save with reminder on → status reads "scheduled" only because
`UI::Notifications.has_pending?("voyager-daily-checkin")` is genuinely true;
toggle off + Save → "off" only because `remove_pending` truly cleared it.

## watchOS
`objc_bridge.m` is a UIKit/AppKit bridge and is intentionally NOT compiled for
watchOS. A new portable `src/ui/native/notifications_bridge.m` (Foundation +
UserNotifications only) provides `ap_notifications_*` for the watch; it's compiled
into `libvoyagerwatch.a` and linked with `-framework UserNotifications`.

Verified on the watch sim (no XCUITest on watchOS) via the env-gated hook
`VOYAGER_WATCH_TEST_NOTIF=1` → `voyager_watch_test_notif()` drives the real
`:save_checkin` dispatch and logs the system pending count:

    VOYAGER_NOTIF_RESULT pending=1

i.e. the notification genuinely landed in watchOS `UNUserNotificationCenter`.

KEY platform difference found: on iOS, a request is tracked in the pending queue
even while authorization is NotDetermined; on watchOS it is NOT — authorization
is required first. Solution (and the right default for a low-friction coach):
PROVISIONAL authorization (`UNAuthorizationOptionProvisional`) — granted silently
with no permission dialog and no user tap, with quiet delivery to Notification
Center. `save_checkin` requests it before scheduling, so the reminder works on the
wrist with zero nag. `watchos-checkin-provisional-clean.png` shows the check-in
screen after a provisional-auth save — no permission prompt.
