// ViewOverrides — the common @objc override carrier shared by every widget.
//
// Every field is nullable (`UIColor?`, `NSNumber?`, `String?`) and defaults
// to `nil`. A `nil` field means "the Crystal-side `UI::View` left this
// property at its type default — apply the SwiftUI default treatment."
// A non-nil field means the Crystal author explicitly set the property,
// so the corresponding modifier MUST be applied (see CommonModifiers.apply).
//
// All numeric fields are `NSNumber?` rather than `Double?` so they bridge
// cleanly to ObjC where `Double?` is not representable.
//
// This file is the sole owner of `APSKPlatformView`. HostingHelpers.swift
// imports the typealias from here; declaring it in two places is a
// duplicate-typealias error (see §5.5 / implementation.md line 701).

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
public typealias APSKPlatformView = UIView
public typealias APSKPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias APSKPlatformView = NSView
public typealias APSKPlatformColor = NSColor
#endif

@objc(APSKViewOverrides)
public class ViewOverrides: NSObject {
    @objc public var backgroundColor: APSKPlatformColor? = nil    // nil = SwiftUI default
    @objc public var foregroundColor: APSKPlatformColor? = nil
    @objc public var cornerRadius: NSNumber? = nil                 // pt
    @objc public var paddingTop: NSNumber? = nil
    @objc public var paddingLeading: NSNumber? = nil
    @objc public var paddingBottom: NSNumber? = nil
    @objc public var paddingTrailing: NSNumber? = nil
    @objc public var borderWidth: NSNumber? = nil                  // pt
    @objc public var borderColor: APSKPlatformColor? = nil
    @objc public var shadowRadius: NSNumber? = nil
    @objc public var shadowColor: APSKPlatformColor? = nil
    @objc public var shadowOffsetX: NSNumber? = nil
    @objc public var shadowOffsetY: NSNumber? = nil
    @objc public var opacity: NSNumber? = nil                      // 0..1; nil = 1
    @objc public var hidden: NSNumber? = nil                       // bool-as-int
    @objc public var minWidth: NSNumber? = nil
    @objc public var minHeight: NSNumber? = nil
    @objc public var maxWidth: NSNumber? = nil
    @objc public var maxHeight: NSNumber? = nil
    @objc public var accessibilityIdentifier: String? = nil
    // Renamed from `accessibilityLabel` to avoid colliding with the
    // `NSObject`-supplied `UIAccessibility.accessibilityLabel` selector on
    // iOS slices, which produced the iter-1 "setter conflicts with
    // superclass" compile error. The explicit `@objc(apskAccessibilityLabel)`
    // pins the Objective-C selector so the Crystal Populator addresses an
    // unambiguous setter (`setApskAccessibilityLabel:`).
    @objc(apskAccessibilityLabel) public var apskAccessibilityLabel: String? = nil

    // Phase 10B.2a iter 2 (Codex Finding 1) — five new accessibility
    // metadata slots threaded through from the Crystal-side `UI::View`
    // base. Each setter is renamed to `apsk*` to avoid collision with
    // the `NSObject`-supplied `UIAccessibility.*` properties on iOS
    // slices (same root cause as `apskAccessibilityLabel`). The Crystal
    // Populator addresses these via `setApskAccessibilityHint:` etc.
    //
    // CommonModifiers.apply reads these and emits the matching SwiftUI
    // accessibility modifier:
    //   apskAccessibilityHint       -> .accessibilityHint(Text(...))
    //   apskAccessibilityValue      -> .accessibilityValue(Text(...))
    //   apskAccessibilityRole       -> role-specific modifier (heading/image/...)
    //   apskAccessibilityTraitsMask -> .accessibilityAddTraits(...) bitmask
    //   apskAccessibilityIdentifier2 — duplicate of accessibilityIdentifier
    //                                  because the View-base `accessibility_identifier`
    //                                  is a SEPARATE Crystal property from `test_id`;
    //                                  the populator writes BOTH slots and the
    //                                  Crystal-side precedence rule (identifier wins
    //                                  over test_id) is enforced by the Populator
    //                                  emitting nil for the looser slot when
    //                                  identifier is set.
    @objc(apskAccessibilityHint) public var apskAccessibilityHint: String? = nil
    @objc(apskAccessibilityValue) public var apskAccessibilityValue: String? = nil
    // Role symbol stringified ("button", "heading", "image", "search",
    // "text", "link", ...). The Modifier reads this and dispatches to
    // the matching SwiftUI `.accessibilityAddTraits()` or
    // `.accessibilityRepresentation { ... }` form. Unmapped roles fall
    // through silently.
    @objc(apskAccessibilityRole) public var apskAccessibilityRole: String? = nil
    // UIAccessibilityTraits bitmask, raw `UInt64` boxed in NSNumber.
    // Crystal computes the OR of `accessibility_traits` + role-trait
    // and passes the composed mask. The Modifier maps known bits to
    // SwiftUI `AccessibilityTraits` and emits a single
    // `.accessibilityAddTraits(...)` call.
    @objc(apskAccessibilityTraitsMask) public var apskAccessibilityTraitsMask: NSNumber? = nil

    @objc public override init() { super.init() }
}
