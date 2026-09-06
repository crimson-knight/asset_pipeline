# Android native navigation contract

Status: development implementation, not full Tier A certification. The current
proof is recorded in [the navigation checkpoint](android-navigation-proof-2026-09-05.md).

## Application ownership

Retain a `UI::NavigationStack` in application state and return it from the
Android application factory. `UI::NavigationLink` pushes its destination onto
the nearest enclosing stack. A link outside a stack is an error, not an inert
button. Use a view whose `accept` builds from current application state for a
dynamic screen; retaining a static label will retain its original text.

```crystal
require "asset_pipeline/ui/android/application"

home = UI::VStack.new
home << UI::Label.new("Home")
home << UI::NavigationLink.new("Details", UI::Label.new("Native details"))
navigation = UI::NavigationStack.new(home, "My application")
UI::Android::Application.configure { |_route| navigation }
```

`push`, `pop` and `pop_to_root` change Crystal-owned history. Native callbacks
schedule the host's existing deferred refresh. When changing navigation outside
a native callback, call `UI::Android::Application.invalidate` to synchronize Back
availability and schedule rendering. In particular, do not create a new stack
inside every factory invocation: that resets history on refresh.

The renderer produces a vertical native View container, a Material toolbar
(unless `shows_navigation_bar = false`), and the current screen. Toolbar Up pops
its enclosing stack. The toolbar's standard arrow has a localized Android Up
description and theme-derived tint. Links are native Material buttons with
the view's common properties; `:not_enabled` disables interaction.

## Host and Back contract

After `CrystalBridge.attachHost(this)`, create and retain
`NativeNavigation(this)` in an AppCompatActivity. After mounting each rendered
root, call `navigation.synchronize()`. Both the sample and generated Activity
do this, and both manifests opt in with `android:enableOnBackInvokedCallback="true"`.
The canonical bridge updates Back availability immediately after
callbacks and invalidations, independently of the delayed view refresh.

The lifecycle-owned AndroidX callback is enabled only when Crystal reports a
screen to pop. At root it is disabled, so Android owns the exit/background
behavior. This follows Android's [custom Back guidance](https://developer.android.com/guide/navigation/custom-back).
In-app navigation commits on Back, not on gesture progress. Cancelling a gesture
does not mutate history. This is not an interactive predictive in-app animation.
The keyboard keeps Android's normal first-Back dismissal behavior.

The deepest rendered eligible navigation stack receives system Back. If several
independent sibling stacks are present, the last rendered eligible one wins;
there is no implicit focus-based active-pane selection. Hidden navigation stacks
and their nested stacks do not participate. A navigation stack hidden only by
an arbitrary non-navigation ancestor is not yet excluded by this Crystal-side
visibility policy; omit such inactive branches from the view factory.

An outgoing screen cannot double-push through its old link before the deferred
refresh. Links and toolbar callbacks reject stale enclosing navigation branches.
Native callback IDs/references are owned by the rendered tree and released on
teardown; retained navigation contains Crystal views, never Activity/Context or
JNI handles. Queries/commits are main-looper-only. The new navigation C export
contains Crystal exceptions and returns -1 on failure, 0 at root, 1 on success;
Kotlin raises on failure rather than interpreting it as root.

## Explicit remaining limits

- Same-process recreation/reopening retains application history and any draft
  kept in Crystal state. Process death starts at the application's configured
  root; route serialization/restoration is not implemented here.
- This integrates `NavigationStack`/`NavigationLink`, not the separate
  `NavigationCoordinator` route model. That model needs an explicit Android host
  adapter if used by a consumer.
- No Fragment back stack, deep-link routing, transition animation, tab active
  pane selection, modal priority, unsaved-change interception, scroll/selection
  restoration or multi-Activity ownership is claimed.
- `large_title`, link `icon` and `shows_disclosure` do not yet affect native
  rendering. Link semantics are currently announced as a native button, not a
  custom accessibility link role. Full TalkBack/RTL/dark/tablet/device coverage
  remains a separate promotion gate.
- Generic user callback exception containment and partial-render failure
  cleanup predate this change and still need the wider JNI/render audit.

The CLI reference app has a second native details screen reading the counter's
state. Web and Android share the Crystal model code, not a synchronized database.
It deliberately restores saved data
but starts at the root after process death, rather than implying route recovery.
