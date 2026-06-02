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

## Cohesion loop — the agent buzzes your wrist AND reads it aloud

The payoff that ties both primitives together: when a notification is DELIVERED
while the app is foregrounded, the app reads it aloud. Native
UNUserNotificationCenterDelegate (`willPresentNotification`) → C trampoline
`ap_on_foreground_notification` → Crystal `UI::Notifications.on_foreground` handler
→ `UI::Speech.speak(body)`. Registered once in shared `HostBootstrap.build`, so it
works on macOS, iOS, and the wrist with no per-platform code.

Verified on the watch sim via `VOYAGER_WATCH_TEST_FG=1` → `voyager_watch_test_fg_speak()`
schedules a 3s notification; when it fires to the foregrounded app the delegate
speaks it, and after delivery:

    VOYAGER_FG_SPEAK_RESULT speaking=1

i.e. the agent's notification arrived AND the synthesizer is actively reading it
on the wrist. iOS regression-checked: CheckInTests + AgentChatNavTests all pass
after adding the delegate + on_foreground registration.

## Voice control in the flagship screen (mute/unmute the agent)

A beautiful, in-context speaker control in the Agent Chat header (not a buried
setting) lets the user silence the agent's spoken replies. The glyph + label
reflect live state (`speaker.wave.2.fill` "Mute agent voice" ↔ `speaker.slash.fill`
"Unmute agent voice"); it gates `UI::Speech` in AgentChatController. The header
reflows for the wrist: the live "· N" count is dropped on the narrow watch column
(the growing bubbles already show reactivity there) so the title + control fit on
one line. See `ios-agent-chat-voice-control.png` (Agent · 3 + speaker) and
`watchos-agent-chat-voice-control.png` (Agent + speaker, uncramped).

Verified:
- iOS XCUITest `VoiceToggleTests.testVoiceToggleFlipsState` — tapping the control
  flips its accessibility label Mute→Unmute→Mute (state mutated + screen rebuilt).
- watchOS real-path gate (`VOYAGER_WATCH_TEST_GATE=1`): drive a real agent reply
  through the controller muted then unmuted →
  `VOYAGER_GATE_RESULT muted_speaking=0` and `unmuted_speaking=1` — the toggle
  genuinely gates speech (the agent is silent when muted, speaks when not).

## Persistence — settings survive relaunch (UI::Preferences)

New kit capability `UI::Preferences` (NSUserDefaults on Apple; portable
`src/ui/native/prefs_bridge.m` for watchOS — Foundation only). Voyager persists the
voice mute pref + check-in settings (mood/goal/reminder/focus): `State.new` reads
them on launch (literal property defaults are the fallback), the voice toggle and
Save check-in write them. `VOYAGER_RESET_PREFS=1` clears the domain before
`State.new` so UI tests start from known defaults.

Verified:
- iOS XCUITest `VoiceToggleTests.testVoicePreferencePersistsAcrossRelaunch` — mute
  the agent, terminate + relaunch, the control comes back MUTED (read back in
  State.new). CheckInTests + VoiceToggleTests all pass with VOYAGER_RESET_PREFS.
- watchOS (`VOYAGER_WATCH_TEST_PREFS=1`): a counter pref grows across relaunches —
  `VOYAGER_PREFS_RESULT counter=0` then `counter=1` — proving NSUserDefaults
  persisted across launches on the wrist.
