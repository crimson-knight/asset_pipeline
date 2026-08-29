// SwipeActionRowFacade — SwiftUI `.swipeActions(edge:)` bridge.
//
// Phase 10D-refocus — replaces the Crystal-side `make_swipe_reveal_row`
// UIScrollView path with a SwiftUI `List { row.swipeActions(...) }`
// composition so the user gets the native iOS Mail-style swipe gesture:
// pan left/right, full-row-height tinted tile slides out, tap fires the
// Crystal action token through CallbackBridge.
//
// Why wrap a single row in a SwiftUI List:
//   `.swipeActions` is only honored when the receiver is a row inside
//   `SwiftUI.List`. Embedding the bridged content view in a single-row
//   `List` is the smallest harness that activates the modifier without
//   forcing the Crystal author to hoist their list construction into
//   `UI::ListView`. The list chrome (separators, default insets,
//   background) is stripped so the row visually matches whatever the
//   surrounding VStack expects.
//
// Why a separate facade rather than reusing ListViewFacade:
//   ListViewFacade is the cross-platform List binding. SwipeActionRow
//   is one row that participates in *its parent's* layout — putting
//   it under ListViewFacade would force every consumer to build their
//   list through SwiftUI's List harness too, which (a) breaks the
//   Crystal author's mental model (they want a stack of rows) and
//   (b) regresses the existing AppKit/InlineActionRow path for macOS.
//
// macOS:
//   SwiftUI on macOS supports `.swipeActions` only on iOS-style List
//   chrome. On macOS the intent registry routes `:swipe_actions` to
//   `UI::InlineActionRow` already (see `intent_bootstrap.cr`), so this
//   facade in practice only fires on iOS/iPadOS. We still emit the
//   List harness on macOS as a defensive fallback (a tap on the tile
//   buttons will still fire even without the swipe gesture).

import SwiftUI
import Foundation

// watchOS: this facade is not in the watch catalog subset and/or uses UIKit-only
// APIs (UIView/UIControl/SwiftUI-on-watch-unavailable). Gated off watchOS for the
// initial one-facade green compile; watch-native re-enable is a Phase 12 follow-up.
#if !os(watchOS)
@objc(APSKSwipeActionRowFacade)
public class SwipeActionRowFacade: NSObject {
    @objc public static func makeSwipeActionRow(
        contentView: APSKPlatformView,
        overrides: SwipeActionRowOverrides
    ) -> APSKPlatformView {
        let host = APSKSwipeActionRowHost(
            contentView: contentView,
            overrides: overrides
        )
        return HostingHelpers.host(host)
    }
}

private struct APSKSwipeActionRowHost: View {
    let contentView: APSKPlatformView
    let overrides: SwipeActionRowOverrides

    var body: some View {
        // Build the single hosted row. `APSKHostedChild` wraps the
        // Crystal-built UIView/NSView in a SwiftUI representable so it
        // composes inside SwiftUI's view tree.
        let row = APSKHostedChild(view: contentView)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                ForEach(0..<overrides.leadingLabels.count, id: \.self) { i in
                    Self.actionButton(
                        index: i,
                        labels: overrides.leadingLabels,
                        icons: overrides.leadingIcons,
                        tokens: overrides.leadingTokens,
                        roles: overrides.leadingRoles,
                        tints: overrides.leadingTints,
                        labelStyles: overrides.leadingLabelStyles
                    )
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                ForEach(0..<overrides.trailingLabels.count, id: \.self) { i in
                    Self.actionButton(
                        index: i,
                        labels: overrides.trailingLabels,
                        icons: overrides.trailingIcons,
                        tokens: overrides.trailingTokens,
                        roles: overrides.trailingRoles,
                        tints: overrides.trailingTints,
                        labelStyles: overrides.trailingLabelStyles
                    )
                }
            }

        // Wrap the row in a List so SwiftUI activates `.swipeActions`.
        // `.listStyle(.plain)` drops the grouped chrome; setting the
        // list background to clear so the host's parent stack owns
        // the background. The height pin uses
        // `UITableView.automaticDimension`-equivalent: the inner row's
        // intrinsic content size drives it, and the outer
        // `.frame(maxHeight:)` lets the List collapse to that size
        // (the .fixedSize(horizontal: false, vertical: true) on the
        // List in iOS 16+ produces a hug-vertical list).
        var listView: AnyView = AnyView(
            List {
                row
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.defaultMinListRowHeight, 0)
        )

        if let rw = overrides.rowWidth {
            listView = AnyView(listView.frame(width: CGFloat(rw.doubleValue)))
        }

        // Pin the list height to the content view's intrinsic content
        // size so the single-row list collapses to that height instead
        // of taking SwiftUI's default `.defaultMinListRowHeight` (which
        // is 44pt on iOS). We compute this from the content view's
        // intrinsicContentSize when it has one; otherwise we let the
        // list size itself naturally (which on iOS 16+ collapses to
        // the row's intrinsic size when wrapped in a fixed-size frame).
        //
        // The pragmatic fix: pin to a generous minimum (60pt) so the
        // row is comfortably tall even when the content is a single
        // small label. The actual UIHostingController inside the
        // Crystal renderer will let the parent VStack size it further.
        let intrinsicHeight = Self.intrinsicHeightFor(contentView: contentView)
        let pinned = listView.frame(height: intrinsicHeight)

        let common = CommonModifiers.apply(AnyView(pinned), overrides: overrides)
        return common
    }

    /// Build a SwiftUI Button for an action row tile.
    ///
    /// Roles:
    ///   - "destructive" → SwiftUI `.destructive` role → system red.
    ///   - "cancel" → `.cancel` role → system styling.
    ///   - other → no role (default tint).
    ///
    /// Tints map the Crystal-side semantic tint key to SwiftUI Color.
    /// Empty string → no explicit tint (role default wins).
    @ViewBuilder
    private static func actionButton(
        index i: Int,
        labels: [String],
        icons: [String],
        tokens: [NSNumber],
        roles: [String],
        tints: [String],
        labelStyles: [String] = []
    ) -> some View {
        let label = i < labels.count ? labels[i] : ""
        let icon = i < icons.count ? icons[i] : ""
        let token = i < tokens.count ? tokens[i].uint64Value : 0
        let role = i < roles.count ? roles[i] : ""
        let tintKey = i < tints.count ? tints[i] : ""
        let labelStyle = i < labelStyles.count ? labelStyles[i] : "auto"

        let action: () -> Void = {
            CallbackBridge.fire(token: token, value: 0.0)
        }

        let button: AnyView = {
            if role == "destructive" {
                return AnyView(
                    Button(role: .destructive, action: action) {
                        Self.buttonLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            } else if role == "cancel" {
                return AnyView(
                    Button(role: .cancel, action: action) {
                        Self.buttonLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            } else {
                return AnyView(
                    Button(action: action) {
                        Self.buttonLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            }
        }()

        if let color = Self.colorFor(tintKey: tintKey) {
            button.tint(color)
        } else {
            button
        }
    }

    // Phase 10D-polish iter 2 (B-LIST-SWIPE-LABEL-STYLE) — forced
    // styles override the auto inference. "icon" drops the title even
    // when both are set; "title" drops the icon; "title_and_icon"
    // forces the SwiftUI Label combination even when one side is
    // empty (no-op in that case).
    @ViewBuilder
    private static func buttonLabel(label: String, icon: String, style: String = "auto") -> some View {
        switch style {
        case "icon":
            if !icon.isEmpty {
                Image(systemName: icon)
                    .accessibilityLabel(Text(label))
            } else {
                Text(label)
            }
        case "title":
            Text(label)
        case "title_and_icon":
            if !icon.isEmpty && !label.isEmpty {
                Label(label, systemImage: icon)
            } else if !icon.isEmpty {
                Image(systemName: icon)
            } else {
                Text(label)
            }
        default:
            if !icon.isEmpty && !label.isEmpty {
                Label(label, systemImage: icon)
            } else if !icon.isEmpty {
                Image(systemName: icon)
            } else {
                Text(label)
            }
        }
    }

    private static func colorFor(tintKey: String) -> Color? {
        switch tintKey {
        case "blue":   return .blue
        case "green":  return .green
        case "orange": return .orange
        case "red":    return .red
        case "purple": return .purple
        case "yellow": return .yellow
        case "pink":   return .pink
        case "gray":   return .gray
        default:       return nil
        }
    }

    /// Resolve the row's intrinsic height so the single-row List can
    /// collapse to it. UIView.intrinsicContentSize returns CGSize with
    /// `UIView.noIntrinsicMetric` (-1) for ambiguous axes; we fall back
    /// to a 60pt floor for those cases.
    private static func intrinsicHeightFor(contentView: APSKPlatformView) -> CGFloat {
        #if canImport(UIKit)
        let size = contentView.intrinsicContentSize
        if size.height > 0 {
            // Add a small vertical pad (8pt) so labels sit comfortably
            // and the swipe tile has room to read at 44pt min target.
            return max(size.height + 16, 60)
        }
        return 60
        #else
        let size = contentView.intrinsicContentSize
        if size.height > 0 {
            return max(size.height + 16, 44)
        }
        return 44
        #endif
    }
}
#endif
