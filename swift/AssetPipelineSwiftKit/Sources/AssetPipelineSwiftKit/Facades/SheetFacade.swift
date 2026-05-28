// SheetFacade — SwiftUI .sheet(isPresented:) bridge.
//
// Crystal hands ONE child: the sheet content. The facade renders an
// invisible 1x1 host that owns the .sheet modifier; the modifier's
// `isPresented` binding starts at the overrides value and is owned by
// a published-state object so Crystal-side mutations of
// `UI::Sheet#is_presented` reach SwiftUI without rebuilding the tree.
//
// Phase 3 Remediation 10 adds the reactive variant:
//   makeReactiveSheet(..., outState:)
// which retains an `APSKSheetState : ObservableObject` and writes the
// +1 pointer through `outState`. Crystal stores it on
// `NativeHandle#state_handle` + `UI::Sheet#swiftkit_state_handle` so
// `sheet.is_presented = true` dispatches into
// `apsk_sheet_set_presented`, which flips the published `isPresented`
// on the main queue. SwiftUI observes via `@ObservedObject` on
// SheetHost and the `.sheet(...)` modifier presents / dismisses.
//
// The legacy `makeSheet(...)` ABI is preserved as a shim that calls the
// reactive entry with `outState = nil` so renderers / consumers that
// haven't been migrated keep working.
//
// onDismiss closure fires `CallbackBridge.fire(token:value:)` for the
// dismiss-token Crystal allocated. The Crystal-side handler
// distinguishes button-driven dismissals (which already wrote the
// reason via Probe) from interactive (swipe) dismissals via an
// explicit-flag pattern — see DismissProbe.
//
// Default behavior (no overrides):
//   - SwiftUI default presentation detents.
//   - System drag indicator visible at the top of the sheet.
//   - Brand tint cascade flows into sheet content automatically.

import SwiftUI
import Foundation

@objc(APSKSheetFacade)
public class SheetFacade: NSObject {
    @objc public static func makeSheet(
        childViews: [APSKPlatformView],
        overrides: SheetOverrides,
        dismissToken: UInt64
    ) -> APSKPlatformView {
        return makeReactiveSheet(
            childViews: childViews,
            overrides: overrides,
            dismissToken: dismissToken,
            outState: nil
        )
    }

    @objc public static func makeReactiveSheet(
        childViews: [APSKPlatformView],
        overrides: SheetOverrides,
        dismissToken: UInt64,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        let initialPresented = overrides.isPresented?.boolValue ?? false
        let state = APSKSheetState(isPresented: initialPresented)
        // Phase 12.B — interaction-contracts marker metadata. Used by
        // apsk_sheet_set_presented for write-side markers and by
        // SheetHost.onDisappear for the host-teardown probe.
        state.apicViewID = overrides.accessibilityIdentifier
        // Phase 12.A — emit present marker if sheet starts already-presented.
        if initialPresented {
            InteractionContracts.emit(
                widget: "Sheet",
                event: "present",
                viewID: overrides.accessibilityIdentifier,
                kv: ["initial": "true"]
            )
        }

        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(state).toOpaque()
        }

        let sheetChild: APSKPlatformView? = childViews.first
        return HostingHelpers.host(
            SheetHost(
                state: state,
                child: sheetChild,
                overrides: overrides,
                dismissToken: dismissToken
            )
        )
    }

    fileprivate static func applyDetents(
        _ v: AnyView, overrides: SheetOverrides
    ) -> AnyView {
        guard !overrides.detents.isEmpty else { return v }
        if #available(iOS 16.0, macOS 13.0, *) {
            #if canImport(UIKit)
            let detents: [PresentationDetent] = overrides.detents.compactMap { name in
                switch name {
                case "small":  return .height(160)
                case "medium": return .medium
                case "large":  return .large
                default:       return nil
                }
            }
            if !detents.isEmpty {
                return AnyView(v.presentationDetents(Set(detents)))
            }
            #endif
        }
        return v
    }

    // Phase 5 v2 — applies `.presentationBackground(<SwiftUI Material>)`
    // to the sheet body using the resolved AppleSemantic from overrides.
    // Default key is "sheet" → .thickMaterial; "system_resolved" or nil
    // returns the body unchanged. iOS 16.4+ / macOS 13.3+ availability
    // floor matches A1 spike compile-verification.
    //
    // Phase 5 v2 Rem1 — iOS 26+ / macOS 26+ Liquid Glass path: per
    // architecture doc lines 117 + 119-120, the 26+ SDKs swap the pre-26
    // `.presentationBackground(<Material>)` for `.glassEffect()`. Shape
    // choice: `.glassEffect()` is a content-view modifier (not a
    // presentation-modifier), so on 26+ we wrap the sheet body view itself
    // with `.glassEffect()` rather than chaining `.presentationBackground`.
    // This mirrors the GlassBackgroundFacade.swift:64-70 reference pattern.
    // SystemResolved still suppresses (no modifier on either branch).
    // Phase 10D-polish iter 2 (B-SHEET-INTERACTIVE-DISMISS-DISABLED) —
    // when overrides.interactiveDismissDisabled is true, apply the
    // SwiftUI modifier that blocks user drag-to-dismiss. The modifier
    // is iOS 15+ / macOS 12+ so no availability guard is needed for our
    // platform floor.
    fileprivate static func applyInteractiveDismissDisabled(
        _ v: AnyView, overrides: SheetOverrides
    ) -> AnyView {
        guard overrides.interactiveDismissDisabled?.boolValue == true else { return v }
        return AnyView(v.interactiveDismissDisabled(true))
    }

    fileprivate static func applyPresentationBackground(
        _ v: AnyView, overrides: SheetOverrides
    ) -> AnyView {
        let key: String = overrides.materialSemantic ?? "sheet"
        if MaterialSemanticResolver.shouldSkipModifier(key) { return v }
        if #available(iOS 26.0, macOS 26.0, *) {
            return AnyView(v.glassEffect())
        }
        if #available(iOS 16.4, macOS 13.3, *) {
            if let mat = MaterialSemanticResolver.material(for: key) {
                return AnyView(v.presentationBackground(mat))
            }
        }
        return v
    }
}

// SheetHost owns the @ObservedObject reference to the published
// presentation state. Building the .sheet(...) binding INSIDE the body
// (not pre-built outside) means SwiftUI re-evaluates the modifier whenever
// `state.isPresented` changes — that is what drives present/dismiss when
// Crystal flips the value via `apsk_sheet_set_presented`.
private struct SheetHost: View {
    @ObservedObject var state: APSKSheetState
    let child: APSKPlatformView?
    let overrides: SheetOverrides
    let dismissToken: UInt64

    var body: some View {
        var sheetBody: AnyView
        if let child = child {
            sheetBody = AnyView(APSKHostedChild(view: child))
        } else {
            sheetBody = AnyView(EmptyView())
        }

        // Phase 12.B — host-teardown probe (Codex CONCERN 4 fix). The
        // .onAppear emits a `host-mounted` marker; .onDisappear emits a
        // `host-disappeared` marker with `intentional=true/false`. The
        // intentional flag is set by Crystal-side `apsk_sheet_set_presented(0)`
        // path; if the host disappears with intentional=false, that's a
        // Rerender-driven teardown — the V1 root-cause class.
        sheetBody = AnyView(
            sheetBody
                .onAppear {
                    InteractionContracts.emit(
                        widget: "Sheet",
                        event: "host-mounted",
                        viewID: overrides.accessibilityIdentifier,
                        kv: [:]
                    )
                }
                .onDisappear {
                    // Phase 12.B Codex review-v2 BLOCKER 5 fix — use
                    // state.isPresented as the discriminator instead of
                    // the apicIntentionalDismiss flag (which depended on
                    // unspecified .onDismiss vs .onDisappear ordering).
                    //
                    // At onDisappear time:
                    //   - Binding-driven dismiss: state.isPresented is
                    //     false (SwiftUI flipped it before animating out).
                    //   - Programmatic dismiss via apsk_sheet_set_presented(false):
                    //     state.isPresented is false (Crystal flipped it).
                    //   - Tree-removal teardown (host removed from parent's
                    //     body): state.isPresented is still true; nothing
                    //     flipped it. This is V1's hypothetical root-cause
                    //     class when a Rerender churns the parent without
                    //     touching the Sheet's BoolStorage.
                    let cause: String =
                        self.state.isPresented ? "tree-removal" : "binding-dismiss"
                    let intentional = self.state.apicIntentionalDismiss
                    InteractionContracts.emit(
                        widget: "Sheet",
                        event: "host-disappeared",
                        viewID: overrides.accessibilityIdentifier,
                        kv: [
                            "cause": cause,
                            "intentional": intentional ? "true" : "false",
                            "state_is_presented": self.state.isPresented ? "true" : "false",
                        ]
                    )
                    // Reset the flag so a subsequent re-present starts clean.
                    self.state.apicIntentionalDismiss = false
                }
        )

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .sheet(isPresented: $state.isPresented, onDismiss: {
                    // Phase 12.B — mark this dismissal as intentional so the
                    // upcoming SheetHost.onDisappear (the host-teardown probe)
                    // can distinguish binding-driven dismissal from Rerender
                    // host teardown. Both the programmatic dismiss
                    // (apsk_sheet_set_presented(false)) and the user swipe-
                    // down path flow through onDismiss before onDisappear.
                    self.state.apicIntentionalDismiss = true
                    // Phase 12.A — interaction-contracts markers.
                    InteractionContracts.emit(
                        widget: "Sheet",
                        event: "dismiss-token-fire",
                        viewID: overrides.accessibilityIdentifier,
                        kv: ["token": String(dismissToken)]
                    )
                    // Always fire the dismiss-token callback. Crystal-side
                    // explicit-flag (DismissProbe.handle_dismiss) decides
                    // whether to record "swipe" or honour a previously
                    // marked explicit reason.
                    CallbackBridge.fire(token: dismissToken, value: 0.0)
                    InteractionContracts.emit(
                        widget: "Sheet",
                        event: "platform-dismissed",
                        viewID: overrides.accessibilityIdentifier,
                        kv: [:]
                    )
                }) {
                    // Phase 5 v2: apply .presentationBackground(Material)
                    // (iOS 16.4+ / macOS 13.3+) inside the sheet body so
                    // the presented modal carries the resolved material.
                    // applyDetents stays in the chain for sheet sizing.
                    SheetFacade.applyInteractiveDismissDisabled(
                        SheetFacade.applyPresentationBackground(
                            SheetFacade.applyDetents(sheetBody, overrides: overrides),
                            overrides: overrides
                        ),
                        overrides: overrides
                    )
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return content
    }
}
