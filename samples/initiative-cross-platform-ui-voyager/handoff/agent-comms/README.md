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

## Voice — the agent speaks (UI::Speech / AVSpeechSynthesizer)

The OUTPUT half of a wrist voice conversation (dictation input is native to the
compose TextField). `UI::Speech.speak(text)` reads the agent's reply aloud via
AVSpeechSynthesizer, cohesively on macOS / iOS / watchOS. The AgentChatController
calls it after appending the agent's reply, so on every Send the agent talks back.

- macOS / iOS: `ap_speech_*` in objc_bridge.m (AVFoundation already linked).
- watchOS: portable `src/ui/native/speech_bridge.m` (Foundation + AVFoundation),
  compiled into libvoyagerwatch.a, linked with `-framework AVFoundation`. Activates
  an AVAudioSession (playback, spoken-audio, duck-others) — required on watchOS.

Verified on the watch sim via `VOYAGER_WATCH_TEST_SPEAK=1` → `voyager_watch_test_speak()`
speaks, then `voyager_watch_speaking()` is logged after a beat (speech is async):

    VOYAGER_SPEAK_RESULT speaking=1

i.e. AVSpeechSynthesizer is ACTIVELY speaking on the watch — honest runtime proof,
not just "enqueued". iOS builds clean and the AgentChat send path (which now calls
speak) passes AgentChatNavTests with no regression; macOS objc_bridge.m compiles.
