# Agent-comms capabilities — notifications, voice, persistence

Three cross-platform system capabilities the kit ships so apps can reach the user,
talk to them, and remember their settings — authored once in Crystal, native on
macOS / iOS / watchOS. They were built and verified for the "Happy Coach" wrist
vision in the Voyager sample (`samples/initiative-cross-platform-ui-voyager`); see
that sample's `handoff/agent-comms/` for the proof artifacts.

| Capability | Module | macOS | iOS | watchOS | web / other |
|---|---|---|---|---|---|
| Local notifications | `UI::Notifications` | ✅ | ✅ | ✅ | inert (returns false / no-op) |
| Text-to-speech | `UI::Speech` | ✅ | ✅ | ✅ | inert |
| Persistent settings | `UI::Preferences` | ✅ | ✅ | ✅ | inert (returns the default) |

All three degrade **honestly** on targets without a native sink: getters return the
supplied default and side-effecting calls are no-ops — never a fake success.

## The portable-bridge pattern (how watchOS is supported)

`src/ui/native/objc_bridge.m` is a UIKit/AppKit *view* bridge and is deliberately
**not compiled for watchOS** (those frameworks don't exist there). But
`UserNotifications`, `AVFoundation`, and `Foundation`/`NSUserDefaults` all *do* exist
on watchOS. So each capability has a small **portable** translation unit that imports
only watch-available frameworks and is compiled into the watch app:

| Capability | watch TU | frameworks |
|---|---|---|
| Notifications | `src/ui/native/notifications_bridge.m` | Foundation + UserNotifications |
| Speech | `src/ui/native/speech_bridge.m` | Foundation + AVFoundation |
| Preferences | `src/ui/native/prefs_bridge.m` | Foundation |

macOS/iOS keep their copies of the same `ap_*` functions inside `objc_bridge.m`; the
watch build compiles the portable TU instead. The two are **never co-linked** (the
watch doesn't compile `objc_bridge.m`), so there is no duplicate-symbol conflict. A
watch app links the relevant frameworks (`-framework UserNotifications` /
`AVFoundation`; Foundation is implicit) — see the Voyager watch `project.yml` +
`build_crystal_lib.sh`.

## `UI::Notifications` — reach the user

```crystal
# Request authorization. provisional: true grants quietly with NO permission
# dialog / tap (notifications delivered silently to Notification Center) — ideal
# for low-friction agents and REQUIRED on watchOS, where a request is not tracked
# in the pending queue until authorized (unlike iOS, which tracks it while
# NotDetermined).
UI::Notifications.request_authorization(provisional: true)

UI::Notifications.schedule(UI::NotificationRequest.new(
  title: "Daily Check-in",
  body: "How are you feeling today?",
  identifier: "daily-checkin",   # stable id → re-schedule updates, remove cancels
  delay_seconds: 60.0, repeats: true, sound: true, thread_id: "coach",
))

UI::Notifications.has_pending?("daily-checkin")  # honest "did it land" signal
UI::Notifications.pending_count                  # count in the system queue
UI::Notifications.remove_pending("daily-checkin")

# Foreground delivery → your code (e.g. read the message aloud). Installs the
# native UNUserNotificationCenter delegate; the block runs when a notification is
# delivered while the app is open.
UI::Notifications.on_foreground { |body| UI::Speech.speak(body) }
```

Auth status: `authorization_status : NotificationAuthorizationStatus`
(`NotDetermined` / `Denied` / `Authorized` / `Provisional` / `Ephemeral` /
`Unsupported`). Pending requests are tracked independent of authorization (auth
gates *delivery*), so `pending_count` / `has_pending?` are valid functional-outcome
assertions even pre-auth on iOS.

## `UI::Speech` — talk to the user

```crystal
UI::Speech.speak("On it — I'll buzz your wrist at 9:45.")          # default voice
UI::Speech.speak(text, rate: 0.5, pitch: 1.0, volume: 1.0, language: "en-US")
UI::Speech.speaking?  # true while actively speaking (the runtime truth)
UI::Speech.stop       # cancel in-progress + queued speech
```

`speak` returns true when the utterance was *enqueued*; speech starts
asynchronously, so `speaking?` (queried after a beat / from a delegate-driven
runloop) is the authoritative "it is talking" signal. On iOS/watchOS an
`AVAudioSession` (playback / spoken-audio / duck-others) is activated automatically
before speaking. Dictation INPUT needs no API — the native `UI::TextField` opens the
system dictation controller on iOS/watchOS.

## `UI::Preferences` — remember settings

```crystal
UI::Preferences.set_bool("app.voice_on", true)
UI::Preferences.bool?("app.voice_on", default: true)   # default when key unset
UI::Preferences.set_int("app.daily_goal", 5)
UI::Preferences.int("app.daily_goal", default: 5)
UI::Preferences.set_double("app.rate", 0.5)
UI::Preferences.double("app.rate", default: 0.5)
UI::Preferences.clear_all                               # wipe the domain (test reset / restore defaults)
```

Backed by `NSUserDefaults`, so values survive relaunch. Read them when constructing
your state model (the literal defaults are the fallback) and write them when the
user changes a setting. Namespace keys per app.

## Verification notes (watchOS has no XCUITest)

The Voyager sample proves each capability against real system state, not flags:

* **iOS** — XCUITest drives the real control and asserts the OS-observed outcome
  (notification in the pending queue; preference surviving `terminate()` +
  `launch()`).
* **watchOS** — an env-gated hook in `ContentView.swift` (`VOYAGER_WATCH_TEST_*=1`)
  calls a `voyager_watch_*` C function that drives the real Crystal path and
  `NSLog`s a unique-token result; `simctl launch` + `log stream --predicate`
  captures it (e.g. `pending=1`, `speaking=1`, `counter=0`→`1` across relaunch).
  For async results (speech), the hook logs the state after a short delay.
```
