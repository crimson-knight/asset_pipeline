# Voyager cross-platform cohesion gallery

`voyager-cohesion-gallery.png` — the same Crystal `UI::Screen` definitions rendered
natively on **macOS (AppKit)**, **iOS (UIKit)**, and **watchOS (WatchKit)** from one
source tree, captured on real simulators and the macOS offscreen host.

Three rows, each a single `UI::Screen` rendered three ways:
1. **Agent Chat** (`AgentChatScreen`) — the conversation surface.
2. **Todos** (`TodosScreen`) — adaptive header (SF-Symbol icon toolbar on macOS/iOS,
   stacked text buttons on the watch) + list.
3. **Daily Check-in** (`CheckInScreen`) — the control showcase: Slider / Stepper / Picker
   / Toggle, each rendered as the platform's NATIVE widget (UISlider/UIStepper/UISwitch +
   menu picker on iOS; NSSlider/NSStepper/NSCheckbox + NSPopUpButton on macOS; SwiftUI
   control facades on the watch) from one Crystal API.

What it demonstrates:

- **One screen, three platforms.** Each row is a single `UI::Screen` walked by three
  different platform renderers — no per-platform layout fork.
- **Whole-design adaptation, not just resizing.** The shared screens reflow to each
  canvas through reusable kit primitives:
  - `DeviceMetrics#adaptive_content_width` — the content column clamps from a 460–480pt
    desktop width down to the watch's ~140pt.
  - `DeviceMetrics#compact_canvas?` — the todos header *reflows*: a horizontal SF-Symbol
    icon toolbar on macOS/iOS, a stacked column of full-width text buttons on the watch.
  - `UI::View#fill_horizontal` — the compose field / title grow to fill, so rows never
    over-constrain or clip.
- **Per-platform idiom + appearance.** Icon toolbar where there's room, readable stacked
  text on the wrist; each platform shown in its natural appearance (watch dark, macOS/iOS
  light — the same screens adapt to the system appearance too).

## Dark mode

`voyager-dark-mode-cohesion.png` — the same `Voyager::AgentChatScreen` in DARK appearance
on all three platforms (macOS `VOYAGER_APPEARANCE=dark`, iOS sim in dark, watchOS dark by
default — it's dark-first / OLED). Demonstrates that appearance adaptation is cohesive too:
semantic colors resolve to a consistent dark palette everywhere, with no per-platform color
forks. (watchOS has no light/dark toggle — `simctl ui appearance` is unsupported there — so
the watch is shown in its natural dark appearance; macOS + iOS adapt to match.)

Regenerate from the per-platform captures under each target's
`handoff/phase-c-evidence/` with the ImageMagick `montage`/`convert` commands recorded in
the commit that introduced this gallery.

## macOS window-resize adaptation

`macos-adaptive-resize.png` — the SAME `TodosScreen` in a narrow vs wide macOS window. The
macOS renderer derives its size class + adaptive widths from the live window content rect, so
resizing the window reflows the design itself, not just the chrome: at a narrow width the
header reflows to a stacked column (`compact_canvas?`) and the content column tightens; at a
wide width the header is an SF-Symbol toolbar (`regular`). This is the within-platform
counterpart to the cross-platform cohesion gallery — the "whole design adapts, not just the
window" north star, demonstrated on a single platform via two capture widths.
