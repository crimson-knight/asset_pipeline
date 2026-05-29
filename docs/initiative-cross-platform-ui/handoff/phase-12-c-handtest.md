# Phase 12.C — V1 auto-dismiss hand-test guide

This is the hand-test playbook for verifying the Phase 12.C V1 fix on
the iPhone simulator. V1 = the action sheet auto-dismisses immediately
when a user taps a share-tile from the Voyager todos screen. The fix is
the cross-render reactive-presentation sweep (Path A) + explicit
dismissal API (Path B) shipped in commits `6a5e4d13` → `34a87c78` →
`9d681e29` on branch `phase-10-d-refocus`.

## Pre-flight

```bash
# Confirm you're on the iter-3 commit.
git rev-parse HEAD                 # expect 9d681e29 or descendant
git status --short                 # expect clean (the test_js fixture
                                   # may be modified by other processes;
                                   # not relevant)

# Confirm cliclick is installed (delivers host-pixel taps to the sim).
which cliclick                     # /opt/homebrew/bin/cliclick

# Confirm the simulator UUID. Adjust SIM if a different simulator is
# booted; see `xcrun simctl list devices booted` for the live list.
SIM=92DA97A0-5FEC-46BD-A525-8AFE2A4FDC21
xcrun simctl list devices | grep -i "$SIM"   # should show Booted
```

## Build + install Voyager.app with Phase 12.C in scope

The bridge changes in this phase touch `src/ui/native/native_view.cr`,
`src/ui/native/native_handle.cr`, `src/ui/native/swiftkit_bridge.cr`,
`src/ui/native/swiftkit_bridge.m`, both renderers, and the iOS bridge.
You MUST rebuild `libvoyager.a` AND xcodebuild the app — incremental
builds may miss the swiftkit_bridge.m change.

```bash
# 1. Rebuild the Swift static lib (includes the new
#    apsk_make_confirmation_dialog_reactive trampoline).
cd swift/AssetPipelineSwiftKit
swift build -c release \
  -Xswiftc -target -Xswiftc arm64-apple-ios16.0-simulator \
  -Xswiftc -sdk -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)"
# Output: .build/arm64-apple-ios-simulator/release/libAssetPipelineSwiftKit.a

# 2. Compile the new swiftkit_bridge.m + apsk_make_confirmation_dialog_reactive
#    is in the Voyager bridge build path; rebuilding libvoyager.a picks it up.
cd ../../samples/initiative-cross-platform-ui-voyager/ios
bash build_crystal_lib.sh simulator      # builds libvoyager.a

# 3. xcodebuild the .app. WIPE DerivedData first — incremental builds
#    routinely miss libvoyager.a changes.
rm -rf ~/Library/Developer/Xcode/DerivedData/VoyagerDemo-*
xcodegen generate
xcodebuild build -project VoyagerDemo.xcodeproj -scheme VoyagerDemo \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" \
  CODE_SIGNING_ALLOWED=NO

# 4. Reinstall.
APP=$(find ~/Library/Developer/Xcode/DerivedData/VoyagerDemo-* \
  -name VoyagerDemo.app -path '*/Debug-iphonesimulator/*' | sort -r | head -1)
xcrun simctl uninstall $SIM com.assetpipeline.voyager.VoyagerDemo
xcrun simctl install $SIM "$APP"
```

If xcodebuild fails: read the actual error. The most likely cause after
a deep-rebuild is a mismatched static-lib slice (simulator vs device).
`file "$APP/VoyagerDemo"` should show `arm64`.

## Launch with marker logging on

```bash
# In one terminal: stream APIC markers from the simulator.
xcrun simctl spawn $SIM log stream \
  --predicate 'eventMessage CONTAINS "[APIC:"' \
  --style compact

# In another terminal: launch the app on todos.
SIMCTL_CHILD_APIC_ENABLED=1 \
SIMCTL_CHILD_VOYAGER_ROOT_SLUG=voyager-todos \
  xcrun simctl launch $SIM com.assetpipeline.voyager.VoyagerDemo
```

On launch you should see:

```
[APIC:VoyagerApp:launched]
[APIC:VoyagerApp:heartbeat] count=1 elapsed_seconds=1
[APIC:VoyagerApp:heartbeat] count=2 elapsed_seconds=2
...
```

If you don't see any APIC markers, `APIC_ENABLED` didn't propagate.
Confirm with `xcrun simctl spawn $SIM launchctl getenv APIC_ENABLED`.

## V1 reproduction — share-tile auto-dismiss

The V1 scenario: left-swipe a todo row to reveal the Share tile, tap
Share, and confirm the action sheet stays open until the user taps an
action (Copy / Print / Cancel).

### Pre-fix behavior (the bug)

Before `6a5e4d13`: the share sheet appeared then immediately dismissed.
You'd see the Copy/Print/Cancel button stack flash on-screen for one
frame, then the sheet would close itself with no user input.

### Post-fix expected behavior

With `9d681e29` installed, the share sheet should:

1. **Appear and stay visible.** No auto-dismiss.
2. **Respond to taps.** Each of Copy / Print / Cancel should fire its
   handler and dismiss the sheet cleanly.
3. **Survive unrelated rerenders** — see the C1 stress test below.

### Step-by-step

1. Dismiss the notification permission alert (one-time).
2. Long-press the first todo row ("Buy groceries"). Drag left to reveal
   the trailing actions: `[Delete, Done, Share, Edit]`.
3. Tap **Share**. The action sheet should slide up from the bottom
   with "Copy to Clipboard", "Print This Todo", "Cancel".

**Expected markers (the APIC log stream should show)**:

```
[APIC:ConfirmationDialog:present] view=voyager-todos-share-sheet initial=true
```

The PASS signal is: the dialog stays presented. The FAIL signal is:
within the next 500ms you see

```
[APIC:ConfirmationDialog:platform-dismissed] view=voyager-todos-share-sheet
```

with no `binding-write-false` marker preceding it (that would be the
old tree-removal cause — V1 not fixed).

4. Tap **Copy to Clipboard**. The sheet should dismiss; you should see:

```
[APIC:ConfirmationDialog:binding-write-false] view=voyager-todos-share-sheet
[APIC:ConfirmationDialog:platform-dismissed] view=voyager-todos-share-sheet
```

in that order (binding-write-false → platform-dismissed). The Copy
action also writes to the system clipboard; paste into another app to
confirm.

5. Repeat the swipe-Share-tap-Cancel sequence twice more. Each iteration
   should produce the same marker pattern.

## C1 stress test — sheet survives unrelated rerenders

This is the test for Codex iter-1 BLOCKER 2 (now fixed). The share
sheet should remain presented even when an unrelated state change
causes a Rerender.

1. Swipe-Share on a row to open the action sheet.
2. WITHOUT dismissing it, tap a different row's checkbox (to toggle
   completion).
3. The action sheet should STILL be visible.

Expected: the `[APIC:Toggle:...]` markers for the checkbox toggle, but
NO `[APIC:ConfirmationDialog:platform-dismissed]` for the open share
sheet.

You should also see (proving the identity-aware sweep is firing):

```
[APIC:VoyagerApp:heartbeat] ...           # rerender happened
# (NO programmatic-dismiss-on-rerender for the share sheet)
```

If the share sheet closes when you toggle the checkbox, the sweep is
still over-aggressive — re-check `presentation_identity` propagation
in `ActionSheetWithWebFallback#accept`.

## V2 — overflow popover buttons don't crash

This isn't strictly Phase 12.C scope, but the iter-3 build exercises
the same SwiftKit reactive surface, so verify it doesn't regress.

1. Tap the `•••` overflow button in the toolbar.
2. The popover should anchor to the button and show:
   "Sort by deadline" / "Hide completed" / "Clear all completed".
3. Tap each one in turn. None should crash.

Expected markers per tap: `Popover:present` → action fires
(`Button:tap`) → `Popover:platform-dismissed`. No crash, no
SIGSEGV in the log stream.

## Pass / fail recording

Open `docs/initiative-cross-platform-ui/handoff/phase-12-c-handtest-results.md`
(create it) and record:

```markdown
# Phase 12.C hand-test results — <date>

Tester: <name>
Build: commit <sha>
Simulator: iPhone 17 Pro / iOS 26.5

## V1 — share-tile auto-dismiss

| Step | Expected | Observed | Pass? |
|---|---|---|---|
| 1. Swipe-Share row 1 | sheet appears + stays | ... | ☐ |
| 2. Tap Copy | binding-write-false → platform-dismissed | ... | ☐ |
| 3. Repeat (Print) | same | ... | ☐ |
| 4. Repeat (Cancel) | same | ... | ☐ |
| 5. C1 stress: rerender while open | no premature dismiss | ... | ☐ |

## V2 — overflow popover

| Step | Expected | Observed | Pass? |
|---|---|---|---|
| 1. Tap overflow | popover anchored | ... | ☐ |
| 2. Sort by deadline | no crash | ... | ☐ |
| 3. Hide completed | no crash | ... | ☐ |
| 4. Clear completed | no crash | ... | ☐ |

## Notes
<free-text observations>
```

Attach the full APIC marker log stream output for each step. If any
step fails, file a follow-up handoff with the marker timeline.

## Known limitations (Phase 12.D scope, not blocking V1)

Per `architecture/presentation-lifecycle-contract.md` §"Phase 12.C
iter-2 — open lifecycle hazards deferred to 12.D":

- **C5 ordering**: tap-Copy fires the Crystal handler and clears
  pending state before SwiftUI's dismiss animation finishes. Visible as
  a brief flash; not a correctness bug for V1 scope.
- **Dismiss-animation-complete before swap**: similar — the host swap
  can tear down the dialog's UIHostingView mid-animation.
- **Main-thread enforcement**: documented invariant, not yet asserted.

If you observe a Phase 12.D limitation but V1 + V2 themselves pass,
mark the test PASS-WITH-NOTES and log the limitation in the results.
