# UI::DatePicker

A calendar-based date selection control. Renders as iOS's native `UIDatePicker` chrome (compact field that opens a calendar popover on tap), `NSDatePicker` on macOS, or a native picker on Android. Date / time / datetime modes are selectable via the `mode` property.

## Default experience

- **iOS:** SwiftUI `DatePicker(label, selection: ..., displayedComponents: .date)` — renders as the compact field that taps to reveal a calendar popover (iOS 14+ default). `mode == :time` switches to `.hourAndMinute`; `mode == :datetime` to `[.date, .hourAndMinute]`.
- **iPadOS:** identical to iOS.
- **macOS:** SwiftUI `DatePicker` on macOS renders as a stepper-styled textfield with a calendar-icon affordance. Date-only mode = simple field; datetime mode = field + time stepper.
- **web wide:** HTML `<input type="date" />` / `<input type="time" />` / `<input type="datetime-local" />`.
- **web narrow:** same as web wide (mobile browsers provide native date-pickers automatically).
- **Android:** Material `DatePicker` modal.

## Crystal API

```crystal
# Minimal invocation
picker = UI::DatePicker.new(UI::DatePickerMode::Date)
picker.label = "Deadline"
picker.on_change = ->(t : Time) { ... }
```

```crystal
# Realistic Voyager invocation
# samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:391-422
picker = UI::DatePicker.new(UI::DatePickerMode::Date)
picker.label = "Deadline"
picker.accessibility_label = "Todo deadline"
picker.test_id = "voyager-editor-sheet-deadline"
if !seed_deadline.empty?
  begin
    picker.selected_date = Time.parse_utc(seed_deadline, "%Y-%m-%d")
  rescue Time::Format::Error
    picker.selected_date = Time.utc
  end
else
  picker.selected_date = Time.utc
end
picker.on_change = ->(t : Time) {
  d2 = Voyager.dispatcher
  unless d2.nil?
    d2.current_form_state.update("deadline", t.to_utc.to_s("%Y-%m-%d"))
  end
  nil
}
body << picker.as(UI::View)
```

## Behavior contract

- **Callbacks:** `on_change : Proc(Time, Nil)?` — fires on every value change. iOS may fire multiple times during scrubbing.
- **Dismissal paths:** The popover dismisses on tap-outside or selecting a date (system-managed). The picker itself is inline.
- **Focus / keyboard:** Field is focusable via Tab; keyboard input opens the system date picker dropdown.
- **Reduced motion:** SwiftUI handles automatically.
- **Reactivity:** `selected_date` is NOT reactive today — setting it post-render does not push to the SwiftUI side. To change the displayed date after mount, mutate domain state + Rerender.

## Customization knobs

| Property | Type | Default | Effect |
|----------|------|---------|--------|
| `selected_date` | `Time` | `Time.utc` | Initial / current date. |
| `mode` | `DatePickerMode` | `Date` | `Date` / `Time` / `DateTime`. |
| `minimum_date` | `Time?` | `nil` | Earliest selectable date (inclusive). |
| `maximum_date` | `Time?` | `nil` | Latest selectable date (inclusive). |
| `label` | `String` | `""` | Caption shown alongside the picker. |
| `on_change` | `Proc(Time, Nil)?` | `nil` | Change handler. |

## Override path

**Public knobs cover mode + bounds + change handler.** No knob for the picker style itself today (`.compact`, `.graphical`, `.wheels`) — see backlog.

**Override paths:**

- **Picker style (compact vs graphical vs wheels):** the `:compact_date_picker_style`, `:graphical_date_picker_style`, `:wheel_date_picker_style` intents are in the catalog but unbacked — no `date_picker_style` property on `UI::DatePicker`. **Backlog item: `B-DATEPICKER-STYLE-PROPERTY`** — referenced in `docs/initiative-cross-platform-ui/handoff/phase-10-pre-2-close.md "new gaps surfaced"`.
- **Nilable / clearable state:** today the picker has no nil value; "no date" must be represented in app state. The Voyager pattern uses a sibling `Clear` button that resets the FormState entry to empty string (`samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:432-444`).
- **iOS class-init gap with `Time.local`:** `Time.local` segfaults on iOS due to `[[crystal-ios-class-init-gap]]`. Use `Time.utc` for seed values; date-only mode doesn't care about timezone. Backlog: `B-CRYSTAL-IOS-TIME-LOCAL` (covered by the broader iOS class-init gap remediation).
- **Date display year offset:** the Crystal-to-Swift epoch conversion path (`view.selected_date.to_unix.to_f64` → `Date(timeIntervalSince1970:)`) currently shows an incorrect year (`May 27, 3995` instead of `May 27, 2026` in the editor screenshot). **Backlog item: `B-DATEPICKER-EPOCH-CONVERSION`** — needs investigation of whether Crystal `to_unix` is returning the wrong base, or Swift is misinterpreting the Float64. Tracked in `docs/initiative-cross-platform-ui/architecture/intent-backlog.md`.

## Evidence

- **Canonical example:** `samples/initiative-cross-platform-ui-voyager/screens/todos_screen.cr:391-422`
- **Screenshot:** `docs/initiative-cross-platform-ui/handoff/phase-10-d-polish-screenshots/06_datepicker_deadline.png` (note: year display is off — backlog `B-DATEPICKER-EPOCH-CONVERSION`)
- **Spec coverage:** `spec/web/ui/views/date_picker_spec.cr`
