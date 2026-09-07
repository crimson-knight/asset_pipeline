# Android host tick contract

Status: development implementation, proven by the `tick-contract` fixture in
the `make test-android` class list (`AndroidTickContractTest`) and the
`TickPolicyTest` JVM suite.

## What the application gets

An application that has parked work (a boot fetch, a poll, a countdown) needs
a main-thread entry point that is not a touch. The iOS host provides a timer
callout; the Android host provides the same thing through the application
module:

```crystal
require "asset_pipeline/ui/android/application"

UI::Android::Application.on_tick(1000) do
  app.run_one_unit_of_parked_work
  UI::Android::Application.invalidate if app.render_owed?
end
```

`on_tick(interval_ms, &handler)` registers one handler per process, before the
first render (top-level code runs during library load). The host reads the
interval when the surface enters the foreground and schedules nothing when no
handler is registered.

## Host semantics

- **Main looper, foreground only.** Ticks run on the Android main looper while
  the session is in the foreground. Background, detach, close and any boundary
  failure stop them; nothing is queued for a backgrounded surface, so a return
  to the foreground does not replay the ticks it missed.
- **First tick right after the first render.** `foregroundHost` posts the
  first tick behind the host's own first render, so the first frame is on
  screen when parked work begins. Later ticks follow `TickPolicy.nextDelay`:
  the interval minus the time the previous tick consumed, never less than 16
  ms, so a slow tick shortens the next delay instead of queuing a burst.
- **Never overlapping.** A tick that blocks (a fetch) cannot be re-entered by
  the next one.
- **A tick never re-renders by itself.** The handler calls `invalidate` when a
  re-render is owed; that requests the host's ordinary deferred refresh, which
  still defers while a focused editor has a composing span. A clock does not
  replace the field someone is typing into.
- **Failure is contained and terminal.** A handler that raises is logged by
  type only and the session becomes terminal, the same as a failed callback.
  Handlers that do network work must return results, not raise.

## Boundary

`crystal_android_host_tick_interval` and `crystal_android_host_tick` are the
two exports; `CrystalBridge.tickIntervalNative` and `tickNative` are their JNI
entry points, counted by the JNI guard. `CrystalBridge.debugTickCount()` reports
ticks dispatched since the library loaded, for tests.

## What the fixture proves

`tick-contract` renders two counters: ticks the bridge received and times the
fixture was built. The device test asserts that the tick count advances
without a touch, that each tick's `invalidate` lands one render (within one
for the refresh in flight), that a surface moved to the CREATED state receives
no ticks for 2.5 s, and that the next tick follows resume without a replay.
The sample host registers its handler for every fixture and re-renders only
while `tick-contract` is on screen, so the other fixtures see ticks but no
extra renders.

## Not proven here

Ticks while a dialog or sheet window holds focus, tick-driven work on a
physical device (the shell application proves that separately), and any
interval other than one second.
