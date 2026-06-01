// PopoverFacade — SwiftUI .popover(isPresented:) bridge.
//
// macOS has rich popover support; iOS has limited popover behavior
// (most popovers degrade to sheets at compact size classes). SwiftUI
// handles this transparently — the `.popover` modifier defers to the
// runtime to pick the right presentation.
//
// Phase 10D-polish iter 2 (B-POPOVER-ANCHOR-VIEW) — when
// `overrides.anchorSourceView` is non-nil, the facade returns an
// invisible UIView that owns a UIPopoverPresentationController-backed
// presentation anchored to the source view. This is the only honest
// way to anchor a popover to a UIView that lives outside the SwiftUI
// host's coordinate space (SwiftUI's `.popover` modifier presents from
// its receiver, not from an arbitrary anchor).

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// watchOS: this facade is not in the watch catalog subset and/or uses UIKit-only
// APIs (UIView/UIControl/SwiftUI-on-watch-unavailable). Gated off watchOS for the
// initial one-facade green compile; watch-native re-enable is a Phase 12 follow-up.
#if !os(watchOS)
@objc(APSKPopoverFacade)
public class PopoverFacade: NSObject {
    @objc public static func makePopover(
        childViews: [APSKPlatformView],
        overrides: PopoverOverrides,
        dismissToken: UInt64
    ) -> APSKPlatformView {
        let isPresented = overrides.isPresented?.boolValue ?? false

        #if canImport(UIKit)
        // Phase 10D-polish iter 2 — UIKit-anchored path. When the
        // overrides carry a source UIView, present via
        // UIPopoverPresentationController so the bubble's arrow points
        // at the source. We return a hidden 1pt UIView host that
        // installs the popover at next-runloop on its window.
        if let anchorView = overrides.anchorSourceView as? UIView {
            return AnchoredPopoverHost(
                anchorView: anchorView,
                childViews: childViews,
                overrides: overrides,
                dismissToken: dismissToken,
                presented: isPresented
            )
        }
        #endif

        let storage = BoolStorage(initial: isPresented, token: dismissToken)
        // Phase 12.A — interaction-contracts marker tag.
        storage.markerWidget = "Popover"
        storage.viewID = overrides.accessibilityIdentifier
        if isPresented {
            InteractionContracts.emit(
                widget: "Popover",
                event: "present",
                viewID: storage.viewID,
                kv: ["initial": "true"]
            )
        }

        let body: AnyView
        if let first = childViews.first {
            body = AnyView(APSKHostedChild(view: first))
        } else {
            body = AnyView(EmptyView())
        }

        let arrow: Edge
        switch overrides.arrowEdge {
        case "top":      arrow = .top
        case "bottom":   arrow = .bottom
        case "leading":  arrow = .leading
        case "trailing": arrow = .trailing
        default:         arrow = .bottom
        }

        // Phase 5 v2 — resolve AppleSemantic key (default "popover")
        // for the popover body's .presentationBackground(<Material>)
        // (iOS 16.4+ / macOS 13.3+ per A1 spike).
        let materialKey: String = overrides.materialSemantic ?? "popover"

        var content: AnyView = AnyView(
            Color.clear
                .frame(width: 1, height: 1)
                .popover(isPresented: storage.binding, arrowEdge: arrow) {
                    let popoverBody = AnyView(
                        Group {
                            body
                        }
                        .frame(
                            minWidth: overrides.preferredWidth.map { CGFloat($0.doubleValue) },
                            minHeight: overrides.preferredHeight.map { CGFloat($0.doubleValue) }
                        )
                    )
                    // Phase 10D-polish — force popover chrome on iPhone
                    // compact size class instead of SwiftUI's default
                    // fallback to a full-screen sheet. iOS 16.4+ /
                    // macOS 13.3+ API; guard via #available.
                    if #available(iOS 16.4, macOS 13.3, *) {
                        Group {
                            PopoverFacade.applyPresentationBackground(popoverBody, key: materialKey)
                        }
                        .presentationCompactAdaptation(.popover)
                    } else {
                        PopoverFacade.applyPresentationBackground(popoverBody, key: materialKey)
                    }
                }
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(PopoverHost(storage: storage, content: content))
    }

    // Phase 5 v2 — applies `.presentationBackground(<SwiftUI Material>)`
    // to the popover body. Default key = "popover" → .regularMaterial;
    // "system_resolved" / nil returns the body unchanged.
    //
    // Phase 5 v2 Rem1 — iOS 26+ / macOS 26+ Liquid Glass path: per
    // architecture doc lines 117 + 119-120, the 26+ SDKs swap the pre-26
    // `.presentationBackground(<Material>)` for `.glassEffect()`. Shape
    // choice (same as SheetFacade): `.glassEffect()` is a content-view
    // modifier, so we wrap the popover body itself rather than chaining
    // `.presentationBackground`. Mirrors GlassBackgroundFacade.swift:64-70.
    fileprivate static func applyPresentationBackground(
        _ v: AnyView, key: String
    ) -> AnyView {
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

private struct PopoverHost<Content: View>: View {
    @ObservedObject var storage: BoolStorage
    let content: Content
    var body: some View { content }
}

#if canImport(UIKit)

// Phase 10D-polish iter 2 (B-POPOVER-ANCHOR-VIEW) — invisible UIView
// host that owns a UIPopoverPresentationController-backed popover
// anchored to an arbitrary source UIView.
//
// Why a UIView and not a UIViewController:
//   The Crystal renderer adds this returned view to its parent's
//   subview list. A UIViewController would not be added to the view
//   hierarchy directly. We get a containing view controller via
//   `next` walking after the host is in the window hierarchy.
//
// Lifecycle:
//   willMove(toWindow:) is the right hook to present the popover —
//   at that point we have a window, can find the closest containing
//   view controller, and the anchor source view is also in the
//   hierarchy with a valid frame.
//
// Dismissal:
//   UIPopoverPresentationController automatically dismisses on
//   outside-tap. We forward via the dismissToken so Crystal can clear
//   the state. The popover delegate is wired so dismissal also clears
//   our local presented flag.
@objc(APSKAnchoredPopoverHost)
final class AnchoredPopoverHost: UIView, UIPopoverPresentationControllerDelegate {
    private let anchorView: UIView
    private let childViews: [APSKPlatformView]
    private let overrides: PopoverOverrides
    private let dismissToken: UInt64
    private var hasPresentedOnce: Bool = false
    private var presentedController: UIViewController? = nil

    init(
        anchorView: UIView,
        childViews: [APSKPlatformView],
        overrides: PopoverOverrides,
        dismissToken: UInt64,
        presented: Bool
    ) {
        self.anchorView = anchorView
        self.childViews = childViews
        self.overrides = overrides
        self.dismissToken = dismissToken
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        self.isHidden = true
        self.isUserInteractionEnabled = false
        // The host must NOT consume layout space in the parent stack.
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: 0),
            self.heightAnchor.constraint(equalToConstant: 0),
        ])
        if presented {
            // Defer to next runloop so the view-hierarchy attachment
            // and window placement settle before we present.
            DispatchQueue.main.async { [weak self] in
                self?.presentIfNeeded()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Once we're in a window AND the override is_presented is true,
        // present. `hasPresentedOnce` guards against repeat presents
        // during render refreshes.
        if window != nil && !hasPresentedOnce {
            DispatchQueue.main.async { [weak self] in
                self?.presentIfNeeded()
            }
        }
    }

    private func presentIfNeeded() {
        guard !hasPresentedOnce else { return }
        guard let presenter = closestViewController() else { return }
        guard anchorView.window != nil else { return }
        hasPresentedOnce = true

        let content = UIViewController()
        content.view.backgroundColor = .clear

        // Embed the first child (the popover content). The Crystal
        // renderer hands the hosted SwiftUI content view (UIHostingView
        // for the menu_content VStack) as childViews.first.
        if let first = childViews.first {
            content.view.addSubview(first)
            first.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                first.topAnchor.constraint(equalTo: content.view.topAnchor),
                first.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
                first.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
                first.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
            ])
        }

        content.modalPresentationStyle = .popover

        // Preferred size: honor explicit width/height if set; otherwise
        // let the content's intrinsic size win.
        var preferred = CGSize(width: 280, height: 200)
        if let w = overrides.preferredWidth?.doubleValue { preferred.width = CGFloat(w) }
        if let h = overrides.preferredHeight?.doubleValue { preferred.height = CGFloat(h) }
        // If we have a child view with an intrinsic size, prefer it
        // when an explicit dimension was not provided.
        if let first = childViews.first {
            let intr = first.systemLayoutSizeFitting(
                UIView.layoutFittingCompressedSize
            )
            if overrides.preferredWidth == nil, intr.width > 0 {
                preferred.width = max(preferred.width, intr.width)
            }
            if overrides.preferredHeight == nil, intr.height > 0 {
                preferred.height = intr.height
            }
        }
        content.preferredContentSize = preferred

        guard let popPC = content.popoverPresentationController else { return }
        popPC.delegate = self
        popPC.sourceView = anchorView
        popPC.sourceRect = anchorView.bounds
        popPC.permittedArrowDirections = Self.arrowDirection(
            for: overrides.arrowEdge
        )

        presenter.present(content, animated: true, completion: nil)
        presentedController = content
        // Phase 12.B Codex review-v2 BLOCKER 2 fix — the anchored UIKit
        // popover path now emits the same [APIC:Popover:present] marker
        // the SwiftUI .popover path does, so V2 spec assertions land on
        // both paths uniformly.
        InteractionContracts.emit(
            widget: "Popover",
            event: "present",
            viewID: overrides.accessibilityIdentifier,
            kv: ["path": "anchored-uikit"]
        )
    }

    private func closestViewController() -> UIViewController? {
        // Walk up the responder chain from our host UIView. The first
        // UIViewController in the chain is the presenter.
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        // Fallback — climb from anchor view if we've not yet been
        // installed in a parent VC.
        responder = anchorView
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    private static func arrowDirection(
        for key: String?
    ) -> UIPopoverArrowDirection {
        switch key {
        case "top":      return .up
        case "bottom":   return .down
        case "leading":  return .left
        case "trailing": return .right
        default:         return .any
        }
    }

    // Force popover style even on iPhone (otherwise UIKit's adaptive
    // presentation reverts to a full-screen modal sheet in compact
    // size class).
    func adaptivePresentationStyle(
        for controller: UIPresentationController
    ) -> UIModalPresentationStyle {
        return .none
    }

    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        return .none
    }

    func popoverPresentationControllerDidDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) {
        // Phase 12.B Codex review-v2 BLOCKER 2 fix — anchored popover
        // emits dismiss-token-fire + platform-dismissed analogous to
        // BoolStorage.binding.set (token != 0).
        if dismissToken != 0 {
            InteractionContracts.emit(
                widget: "Popover",
                event: "dismiss-token-fire",
                viewID: overrides.accessibilityIdentifier,
                kv: ["token": String(dismissToken), "path": "anchored-uikit"]
            )
        }
        CallbackBridge.fire(token: dismissToken, value: 0.0)
        InteractionContracts.emit(
            widget: "Popover",
            event: "platform-dismissed",
            viewID: overrides.accessibilityIdentifier,
            kv: ["path": "anchored-uikit"]
        )
        presentedController = nil
    }
}

#endif
#endif
