# Android native layout contract

Development implementation; not a declaration of complete Tier A Android support.
The canonical renderer uses Android Views, not an HTML/WebView layout engine.

## Dimensions and bounds

Shared logical dimensions are dp. Conversion uses the actual View's current
display density and rounds once, after multiplication. Text remains sp through
the separate text bridge. A missing bound stays unspecified; zero is a real
size. Matching minimum/maximum values pin an axis exactly. A minimum alone
sets the widget's native minimum. Distinct or maximum-only bounds measure the
real widget inside a lightweight owned FrameLayout.

Bounds must be finite and between 0 and 1,000,000 dp, with minimum no greater
than maximum. Conversion must fit Android's 30-bit measurement size. Invalid
layout input fails through the checked native render boundary; it is not
silently converted to a negative or overflowing size.

An Android parent's EXACTLY allocation takes precedence for the **outer slot**.
If that slot exceeds a child's maximum, the actual widget stays bounded and is
centered inside the slot. In particular, a weighted or cross-axis Fill child
does not return unused outer space to siblings. This is an explicit native
layout policy, not CSS max-width/flexbox equivalence. Android defines this
parent/child constraint in its [MeasureSpec contract](https://developer.android.com/reference/android/view/View.MeasureSpec).

The wrapper leaves the real widget's identity, callbacks and accessibility
content intact. It does not retain Views in a global lookup table. Hidden
widgets have hidden wrappers so they consume neither a slot nor a stack gap.
Both wrapper and widget are tracked for ordinary teardown and partial-render
failure cleanup.

## Stacks and flexible space

| Shared view/property | Native behavior |
| --- | --- |
| VStack Leading/Center/Trailing | START/center/END across the horizontal axis; START/END follow resolved RTL direction |
| HStack Top/Center/Bottom | Top/center/bottom across the vertical axis |
| HStack `fill_equally` | Equal outer cells, with at most one pixel of rounding difference; pinned/bounded content remains centered within its cell |
| Stack Fill | Stretch unpinned cross-axis dimensions; exact pins remain exact |
| ZStack | Native child draw order; all six alignments; Fill stretches only unpinned dimensions |
| `fill_horizontal` / `grow!` | Flexible width in HStack, cross-axis filling in VStack |
| Spacer | Flexible native weight along its linear parent's axis, with fractional dp minimum and zero cross-axis size |
| Spacer outside a linear parent | Nonflexible native minimum on both axes |

Default native layout weights divide additional space among weighted children;
they do not make intrinsically different children equal in total width. See
[LinearLayout.LayoutParams](https://developer.android.com/reference/android/widget/LinearLayout.LayoutParams).
The [equal-width implementation checkpoint](android-equal-width-proof-2026-09-06.md)
adds an explicit equal-cell path. A content-sized row first finds its natural
largest-cell width, then allocates equal zero-basis weighted cells within the
parent's resolved width. Exact and AT_MOST constraints still win. Only visible
children consume cells or gaps; an empty row is valid. A Spacer receives one
cell, with its minimum contributing to natural sizing. Fixed-size content is
centered and clipped if its cell cannot contain the pin; unpinned content fills
the cell, with existing maximum-bounds wrappers still bounding actual widgets.

HStack spacing now uses owned start/end margins, avoiding older Android's RTL
divider-placement error. VStack keeps its native middle-divider spacing.
The new cells have no semantic identity or callbacks of their own. The original
widget owns events and shared metadata, and its normal attachment/teardown
checks remain in force. This is not arbitrary Android LayoutParams/margin
composition, CSS flexbox or a constraint solver. Baseline alignment, logical
padding-direction parity and the broader promotion matrix remain separate work.

## Scroll containers

Vertical-only maps to ScrollView; horizontal-only to HorizontalScrollView.
Two-axis scrolling uses an outer ScrollView containing a HorizontalScrollView,
which contains the shared content. Neither axis enabled maps to FrameLayout.
Each native scroll container has one direct child, as required by
[Android ScrollView](https://developer.android.com/reference/android/widget/ScrollView).

`shows_indicators` controls actual native axis indicators. Nonzero `frame_width`
and `frame_height` pin the viewport in dp. `fill_vertical` ignores frame_height
and gives a ScrollView a flexible vertical weight in its enclosing VStack.
Explicit shared minimum/maximum height bounds still apply. The parent must
offer bounded space for flexible fill to have useful slack to consume.

Programmatic `scroll_to_end` / `at_bottom?`, a virtualized list, simultaneous
diagonal scrolling and generalized nested-scroll handoff remain outside this
layout contract. The later [view-state contract](android-view-state.md) now
provides bounded scroll-offset restoration across full-tree replacement; it
does not imply those other scroll capabilities. Actual axis gestures and
callback reachability remain separate device gates, not inferred from
programmatic scrollTo calls.

## Validation

The host structure suite is `spec/web/ui/android_layout_fixture_spec.cr`.
`LayoutPolicyTest` is compiled by both sample and generated hosts and its report
is mandatory. `AndroidLayoutContractTest` measures native widgets across
density, direction, light/night contexts and available widths, then separately
uses real gestures and a Crystal action. `scripts/run_android_smoke.sh` includes
these tests. The failure matrix exercises bounded callback-bearing widgets
before deliberate errors.

Context-based wide measurements are not a physical tablet/emulator screenshot
matrix, TalkBack proof, or API/ABI runtime compatibility proof. Full focus,
selection, screen-state restoration, accessibility and remaining Tier A views
remain governed by the [implementation plan](ANDROID_COMPILE_TARGET_IMPLEMENTATION_PLAN.md).

The rectangle a screen is laid out in, and the system-bar insets it must keep
clear of, reach the application through the [host viewport](android-viewport.md).

## A root that fills the screen

A tree whose root has `fill_screen!` (`root_fill`) lays its own flexible rows
out against the height it is given: the demo shell is a header row, a page
that scrolls in the middle and a tab bar pinned under it. UIKit pins such a
root to the screen and stretches the scroll view because it has no intrinsic
size. A LinearLayout gives the leftover height only to a weighted child, and
only when its own height is exact, which the host's scrolling container never
gives (it measures its content without a bound), so the page took its content
height and pushed the bar off the bottom of every screen. `NativeScreenHost`
now reads the root's prepared fill before mounting it (`NativeLayout.fillsVertically`)
and, after every layout pass, gives a filling root the container's bar-free
height as an explicit pixel height (`MountPolicy.rootHeight`, with a JVM
test): a scrolling container measures its child with no height bound whatever
the child's params say, and an explicit pixel height on the child is the one
spec that stays exact under it. Any other root keeps its content height and
the container scrolls it. The page's
`UI::ScrollView` must ask to fill vertically (`fill_vertical`), which the
UIKit and web renderers ignore. Fixture `layout-fill-screen`; the layout
contract test checks the mount, the root, the pinned bar and the scrolling page.

A `UI::Divider` is its `thickness` across the axis it separates and spans the
other (`orientation`), as the SwiftUI Divider does. A plain View measured as
wrap-content takes whatever its parent offers, so before this the rule drew
nothing in an unbounded column and, in an exact one, took every leftover pixel
and starved the page beside a pinned tab bar.
