# Android host viewport contract

Status: development implementation, proven by the `viewport-contract` fixture
in the `make test-android` class list (`AndroidViewportContractTest`) and the
`ViewportPolicyTest` JVM suite.

## What the application gets

Views that size against the screen (a full-width card, a column of copy that
wraps at the edge, a surface that spans the height) need the rectangle they
are laid out in and the parts of the system bars they must keep clear of. The
iOS host passes the screen size and the safe-area insets through setters; the
Android host reports one record through the application module:

```crystal
require "asset_pipeline/ui/android/application"

UI::Android::Application.on_viewport do |viewport|
  App::Metrics.width = viewport.width          # dp, the same scale as iOS points
  App::Metrics.height = viewport.height
  App::Metrics.top_inset = viewport.top_inset
  App::Metrics.bottom_inset = viewport.bottom_inset
  UI::Android::Application.invalidate if UI::Android::Application.mounted?
end
```

`UI::Android::Viewport` carries `width`, `height`, the four insets and the
display density, all in dp except the density, and `content_width` and
`content_height` with the insets spent. `Application.viewport` holds the last
report (`nil` before the first) for code that reads it when it builds.

## Host semantics

- **Before every render.** `NativeScreenHost.render` measures and reports
  before Crystal builds the tree, so the first frame of a fresh or recreated
  host, a rotation included, is laid out with the numbers it will draw at.
- **On every change.** The container and the mount carry a layout listener;
  when their geometry produces a different report it is handed to Crystal
  again. Crystal calls the `on_viewport` handler only when the record differs
  from the last one.
- **A report never re-renders by itself.** The handler calls `invalidate` when
  a tree is already mounted (`Application.mounted?`), which asks for the host's
  ordinary deferred refresh. Before the first render the values are simply in
  place for it.
- **What the numbers are.** The width is the mount's laid-out width, the width
  the tree gets. The height is the container's frame less the bars the
  container's own padding keeps clear. The insets are the system bars and the
  display cutout that overlap the container beyond what its padding keeps
  clear: a host that pads by the bars, as the reference host and the CLI's
  generated activity do, reports zero insets and the bar-free height; an
  edge-to-edge host reports the bars and the whole height, the way iOS does.
- **The keyboard changes nothing.** Padding beyond the bars, the keyboard's
  included, is not counted, so a focused editor is never replaced because the
  keyboard opened.
- **Before the first layout** the window's bounds stand in for the container,
  with the bars kept clear. A host that lays the mount out narrower than the
  window (the reference host's card) sees one corrective report after its
  first layout, which the fixture's device test bounds to one refresh.
- **Failure is contained and terminal.** A handler that raises is logged by
  type only and the session becomes terminal, the same as a failed callback.

## Boundary

`crystal_android_host_viewport` is the export (1 changed, 0 unchanged, -1 a
contained failure); `CrystalBridge.viewportNative` is its JNI entry point,
counted by the JNI guard, and `CrystalBridge.reportViewport` delivers a
`ViewportPolicy.Report` for a foreground session only. `ViewportPolicy` is
the arithmetic (frame, window, bars, padding and mount width in; dp out),
pinned by the JVM suite. `NativeScreenHost.lastViewport` is the last report,
for tests.

## Label wrap width

`UI::Label#preferred_max_layout_width` is now read on Android as the label's
maximum width: the `TextView` measures up to it and wraps there, which is what
UIKit does with `preferredMaxLayoutWidth` for a multi-line label. An explicit
`maximum_width` still wins.

## What the fixture proves

`viewport-contract` prints the last report to one decimal, a bar sized
exactly to the content column and a label told to wrap at it, plus a render
count. The device test measures the sample host's mount and container itself
and asserts that the printed width is the mount's width and the printed
height the container's inner height, that every inset is zero for this padded
host, that the settled report took at most one refresh, that the bar is the
column to the pixel, that the label wraps within the column, and that a host
rotated to landscape reports a wider viewport.

## Not proven here

An edge-to-edge host's nonzero insets on a device (the policy test covers the
arithmetic), display cutouts, multi-window resizing without recreation, and a
viewport change while a sheet or dialog window holds focus.
