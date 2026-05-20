// CallbackBridge — the one-direction Swift → Crystal action dispatch surface.
//
// At runtime the Swift companion is statically linked into the Crystal-driven
// host binary. Crystal exports a single `@convention(c)` trampoline function,
// `ap_swiftkit_invoke_action(token: UInt64, value: Double)`. During app
// startup Crystal calls `APSKRuntime.initialize(actionTrampoline:)` once,
// passing the address of that trampoline. Subsequent UI events (Button tap,
// Toggle change, Slider drag-end) fire `CallbackBridge.fire(token:value:)`
// which calls the trampoline, which routes through the Crystal-side
// `UI::CallbackRegistry` to the original `Proc`.
//
// `token == 0` means "no callback wired" — every call site checks. This
// matches the Crystal-side convention (token 0 is never handed out by
// `register_action`).

import Foundation

/// Pointer to the Crystal-side trampoline. Set once at startup by
/// `APSKRuntime.initializeWithActionTrampoline:`. Stored as an optional
/// so the package can be loaded before Crystal initialization (the spec
/// helper exercises this path).
private var actionTrampoline: (@convention(c) (UInt64, Double) -> Void)? = nil

@objc(APSKRuntime)
public class APSKRuntime: NSObject {
    /// Called by Crystal once, immediately after `GC.init` and before any
    /// facade is invoked. Passes a C function pointer to
    /// `ap_swiftkit_invoke_action` (Crystal-exported `fun`).
    ///
    /// `trampoline` is treated as `UnsafeRawPointer` to keep the ObjC
    /// surface free of Swift-only types; the unsafeBitCast restores the
    /// expected `@convention(c)` signature on the Swift side.
    @objc public static func initialize(actionTrampoline trampoline: UnsafeRawPointer) {
        actionTrampoline = unsafeBitCast(
            trampoline,
            to: (@convention(c) (UInt64, Double) -> Void).self
        )
    }

    /// Test-only hook. Lets `CallbackBridgeTests.swift` install a Swift
    /// closure in place of the Crystal trampoline so the round-trip can
    /// be exercised without linking against libcrystal.
    @objc public static func _installTestTrampoline(
        _ trampoline: @convention(c) (UInt64, Double) -> Void
    ) {
        actionTrampoline = trampoline
    }

    /// Returns true once `initialize(actionTrampoline:)` has been called.
    /// Used by the runtime spec to confirm wiring.
    @objc public static var isActionTrampolineInstalled: Bool {
        actionTrampoline != nil
    }
}

enum CallbackBridge {
    /// Fire the registered Crystal trampoline. `token == 0` is a no-op
    /// (matches the Crystal-side "no callback wired" convention). If the
    /// trampoline has not been installed yet, the call is silently dropped
    /// rather than crashing — first-launch race protection.
    static func fire(token: UInt64, value: Double) {
        guard token != 0 else { return }
        actionTrampoline?(token, value)
    }
}
