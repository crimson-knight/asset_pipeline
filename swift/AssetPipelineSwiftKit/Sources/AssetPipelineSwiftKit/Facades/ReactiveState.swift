// ReactiveState — ObservableObject containers that back Phase 3 Remediation 4
// reactive updates.
//
// Why these exist:
//   The facade Swift structs (LabelFacade, ButtonFacade, ToggleFacade,
//   SliderFacade) historically captured their input arguments by value at
//   `make...(...)` time. Once the SwiftUI body had been composed and handed
//   to a UIHostingController / NSHostingView, there was no path back from
//   Crystal-side state mutations to a SwiftUI re-render — the views were
//   frozen on first compose.
//
//   Remediation 4 introduces a published-state object per reactive widget,
//   passes a +1 retained opaque pointer to it back to Crystal, and exposes
//   `@_cdecl` mutator functions that update the `@Published` field. SwiftUI
//   observes the change via `@ObservedObject` on the facade host struct and
//   re-renders the affected subtree.
//
// Memory contract:
//   - Crystal owns the state pointer (acquired via `Unmanaged.passRetained`
//     inside the relevant `apsk_make_*` trampoline).
//   - Crystal must call `apsk_state_release` exactly once per state pointer
//     to drop the +1 retain. `NativeHandle#release!` does this automatically
//     when `state_handle` is set.
//   - The mutator functions take the state pointer as `UnsafeMutableRawPointer`,
//     reconstruct an unretained reference via `Unmanaged.fromOpaque`, and mutate
//     the `@Published` property on the main queue (SwiftUI publishes require
//     main-thread dispatch).
//
// Why not @StateObject:
//   `@StateObject` would have SwiftUI own the lifecycle of the state object,
//   which means the state pointer Crystal holds would dangle the moment the
//   SwiftUI body is recomposed. With `@ObservedObject` the Crystal side owns
//   the lifecycle — exactly the inverse split the bridge already establishes
//   for `APSKViewOverrides` / `APSK*Overrides` (Crystal allocates, Swift
//   reads, Crystal frees).

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Label

@objc(APSKLabelState)
public final class APSKLabelState: NSObject, ObservableObject {
    @Published public var text: String

    public init(text: String) {
        self.text = text
        super.init()
    }
}

// MARK: - Button

@objc(APSKButtonState)
public final class APSKButtonState: NSObject, ObservableObject {
    // The Crystal-side default for `UI::Button.background` is `nil` (no
    // background); only an explicitly-set background propagates here. Same
    // for `foregroundColor` (nil = SwiftUI accent) and `cornerRadius`
    // (nil = SwiftUI default for the resolved button style).
    @Published public var backgroundColor: APSKPlatformColor?
    @Published public var foregroundColor: APSKPlatformColor?
    @Published public var cornerRadius: NSNumber?

    // Phase 6.11 — reactive disabled. Seeded from `overrides.disabled`,
    // mutable at runtime through `apsk_button_set_disabled`. The host
    // applies `content.disabled(state.isDisabled)` instead of reading
    // the static `overrides.disabled` snapshot so Crystal can flip the
    // value after the SwiftUI Button has been mounted (e.g. the Voyager
    // Todo editor disables Save while the title is whitespace-only).
    @Published public var isDisabled: Bool

    public init(
        backgroundColor: APSKPlatformColor? = nil,
        foregroundColor: APSKPlatformColor? = nil,
        cornerRadius: NSNumber? = nil,
        isDisabled: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.isDisabled = isDisabled
        super.init()
    }
}

// MARK: - Toggle / Slider
//
// The Toggle and Slider facades already own an `ObservableObject` storage
// class (`BoolStorage`, `DoubleStorage` — see ValueStorage.swift) for their
// SwiftUI bindings. Remediation 4 reuses those types instead of allocating
// parallel state objects: the storage already carries the `@Published`
// value SwiftUI observes. Crystal-programmatic mutations route through
// `apsk_toggle_set_value` / `apsk_slider_set_value`, which set
// `storage.value = X` directly. Setting through the storage (rather than
// through the SwiftUI `Binding`) deliberately bypasses the change
// callback — Crystal initiated the mutation, so re-firing the proc back
// at Crystal would be a double-fire loop.

// MARK: - Sheet (Phase 3 Remediation 10)

@objc(APSKSheetState)
public final class APSKSheetState: NSObject, ObservableObject {
    @Published public var isPresented: Bool
    // Phase 12.B — interaction-contracts marker metadata. Set by SheetFacade
    // after construction so write-side mutations via apsk_sheet_set_presented
    // can emit binding-write-true / binding-write-false markers. Codex
    // Phase 12.A CONCERN 7 fix.
    public var apicViewID: String? = nil
    // True while the user has signaled an intentional dismiss (e.g. tapped
    // a button whose action returns ActionResult.pop). Used by
    // SheetHost.onDisappear to distinguish intentional dismiss from
    // host teardown during Rerender. Codex Phase 12.A CONCERN 4 fix —
    // the host-removal probe.
    public var apicIntentionalDismiss: Bool = false

    // Usability-bar motion (platform-capability-matrix.md §1, U1–U3).
    // The bounded present/dismiss animation resolved by SheetFacade from the
    // SheetOverrides motion fields + the baked MotionScale tokens. nil means
    // "no override resolved" (legacy callers / makeSheet shim) — in that case
    // apsk_sheet_set_presented still applies a SAFE library default so the
    // transition can never collapse to an instant snap (U1 floor).
    public var presentationAnimation: SwiftUI.Animation? = nil

    public init(isPresented: Bool) {
        self.isPresented = isPresented
        super.init()
    }
}

// MARK: - @_cdecl mutator functions
//
// Each mutator takes the opaque state pointer Crystal received from the
// matching `apsk_make_*` trampoline. The pointer is reconstituted as an
// `Unmanaged<...>` without bumping the retain count (`takeUnretainedValue`)
// because Crystal still owns the +1 retain.
//
// All mutations dispatch onto the main queue. SwiftUI's `@Published`
// machinery sends `objectWillChange` synchronously when the property
// setter runs, which then drives view diffing — both of those must happen
// on the main thread.
//
// Color mutators take r/g/b/a as Double (0..1). A NULL alpha sentinel of
// `nan` from Crystal is treated the same as a regular nil — Crystal calls
// the matching `apsk_*_clear_*` function instead of passing NaN.

private func apskMainAsync(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.async(execute: block)
    }
}

@_cdecl("apsk_label_set_text")
public func apskLabelSetText(
    _ stateHandle: UnsafeMutableRawPointer,
    _ cText: UnsafePointer<CChar>?
) {
    let state = Unmanaged<APSKLabelState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let newText = cText.map { String(cString: $0) } ?? ""
    apskMainAsync { state.text = newText }
}

@_cdecl("apsk_button_set_background_color")
public func apskButtonSetBackgroundColor(
    _ stateHandle: UnsafeMutableRawPointer,
    _ r: Double, _ g: Double, _ b: Double, _ a: Double
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let color = APSKPlatformColor(
        red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a)
    )
    apskMainAsync { state.backgroundColor = color }
}

@_cdecl("apsk_button_clear_background_color")
public func apskButtonClearBackgroundColor(
    _ stateHandle: UnsafeMutableRawPointer
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    apskMainAsync { state.backgroundColor = nil }
}

@_cdecl("apsk_button_set_foreground_color")
public func apskButtonSetForegroundColor(
    _ stateHandle: UnsafeMutableRawPointer,
    _ r: Double, _ g: Double, _ b: Double, _ a: Double
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let color = APSKPlatformColor(
        red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a)
    )
    apskMainAsync { state.foregroundColor = color }
}

@_cdecl("apsk_button_clear_foreground_color")
public func apskButtonClearForegroundColor(
    _ stateHandle: UnsafeMutableRawPointer
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    apskMainAsync { state.foregroundColor = nil }
}

@_cdecl("apsk_button_set_corner_radius")
public func apskButtonSetCornerRadius(
    _ stateHandle: UnsafeMutableRawPointer,
    _ value: Double
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let boxed = NSNumber(value: value)
    apskMainAsync { state.cornerRadius = boxed }
}

@_cdecl("apsk_button_clear_corner_radius")
public func apskButtonClearCornerRadius(
    _ stateHandle: UnsafeMutableRawPointer
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    apskMainAsync { state.cornerRadius = nil }
}

// Phase 6.11 — reactive disabled mutator. Crystal calls this when the
// `UI::Button#disabled=` setter runs on a Button whose state pointer
// has been captured (i.e., the Button has been rendered through
// `apsk_make_button_reactive`).
@_cdecl("apsk_button_set_disabled")
public func apskButtonSetDisabled(
    _ stateHandle: UnsafeMutableRawPointer,
    _ disabled: Int32
) {
    let state = Unmanaged<APSKButtonState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let newValue = (disabled != 0)
    apskMainAsync { state.isDisabled = newValue }
}

@_cdecl("apsk_toggle_set_value")
public func apskToggleSetValue(
    _ stateHandle: UnsafeMutableRawPointer,
    _ isOn: Int32
) {
    let state = Unmanaged<BoolStorage>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let newValue = (isOn != 0)
    apskMainAsync { state.setProgrammatically(newValue) }
}

@_cdecl("apsk_slider_set_value")
public func apskSliderSetValue(
    _ stateHandle: UnsafeMutableRawPointer,
    _ value: Double
) {
    let state = Unmanaged<DoubleStorage>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    apskMainAsync { state.setProgrammatically(value) }
}

@_cdecl("apsk_sheet_set_presented")
public func apskSheetSetPresented(
    _ stateHandle: UnsafeMutableRawPointer,
    _ isPresented: Int32
) {
    let state = Unmanaged<APSKSheetState>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let newValue = (isPresented != 0)
    apskMainAsync {
        let previousValue = state.isPresented
        // Usability bar U1: wrap the binding flip in `withAnimation` so the
        // .sheet present/dismiss is perceptible and bounded. A Crystal-pushed
        // true→true / false→false is a no-op below (previousValue == newValue),
        // but when it does change we drive a floored, bounded transition —
        // never an instant snap. `presentationAnimation` is resolved by
        // SheetFacade; the `?? .spring(...)` guard protects legacy `makeSheet`
        // callers that never set it.
        let animation = state.presentationAnimation
            ?? .spring(response: 0.240, dampingFraction: 0.86)
        withAnimation(animation) {
            state.isPresented = newValue
        }
        // Phase 12.B — Sheet write-side markers (Codex CONCERN 7 fix).
        // Emitted only when the value actually changes, so re-applying
        // an identical state doesn't spam the harness log.
        if previousValue != newValue {
            if newValue {
                InteractionContracts.emit(
                    widget: "Sheet",
                    event: "binding-write-true",
                    viewID: state.apicViewID,
                    kv: ["source": "crystal-push"]
                )
            } else {
                InteractionContracts.emit(
                    widget: "Sheet",
                    event: "binding-write-false",
                    viewID: state.apicViewID,
                    kv: ["source": "crystal-push"]
                )
            }
        }
    }
}

// Phase 12.C — programmatic presentation flip for ConfirmationDialog
// (Codex iter-1 BLOCKER 1 fix). ConfirmationDialog facades back the
// SwiftUI `.confirmationDialog(isPresented:)` modifier with a
// `BoolStorage`. Routing through `setProgrammatically(_:)` (NOT
// `binding.set`) means:
//   * `value` updates so SwiftUI's `.confirmationDialog` modifier sees
//     `isPresented = false` and animates the dismiss.
//   * APIC markers fire ("platform-dismissed" / "present" on transitions)
//     so the harness can correlate the binding flip with the host
//     teardown.
//   * `CallbackBridge.fire` does NOT fire — Crystal initiated the
//     mutation; re-firing would double-dispatch. (`binding.set` fires
//     the callback unconditionally; `setProgrammatically` does not.)
@_cdecl("apsk_confirmation_dialog_set_presented")
public func apskConfirmationDialogSetPresented(
    _ stateHandle: UnsafeMutableRawPointer,
    _ isPresented: Int32
) {
    let state = Unmanaged<BoolStorage>.fromOpaque(stateHandle)
        .takeUnretainedValue()
    let newValue = (isPresented != 0)
    apskMainAsync { state.setProgrammatically(newValue) }
}

// Release the +1 retain Crystal acquired when the state object was
// constructed inside the `apsk_make_*` trampoline. Calling this with a
// NULL pointer is a no-op so Crystal-side `NativeHandle#release!` can
// always invoke it unconditionally.
@_cdecl("apsk_state_release")
public func apskStateRelease(_ stateHandle: UnsafeMutableRawPointer?) {
    guard let handle = stateHandle else { return }
    // We don't know the concrete type, but the +1 retain is stored on the
    // object's reference count uniformly. Bridge through `AnyObject` —
    // `Unmanaged<AnyObject>` is what `passRetained(_: AnyObject)` on a
    // class instance gives us in the first place.
    Unmanaged<AnyObject>.fromOpaque(handle).release()
}
