// ListViewFacade — SwiftUI `List { Section { ... } }` bridge.
//
// `UI::ListView` (§6 #25) is a vertical scroll of section-grouped rows.
// Crystal flattens its `Array(Section)` hierarchy into a flat
// `childViews` array. The facade slices it back into sections using
// the `sectionItemCounts` array; per-section headers / footers come
// from the parallel `sectionHeaders` / `sectionFooters` arrays.
//
// The `listStyle` override maps to SwiftUI's `.listStyle(...)`
// modifier. SwiftUI's `List` provides default separators, swipe
// actions, and platform-appropriate chrome (iOS plain/grouped/inset,
// macOS bordered list / sidebar). When `listStyle` is nil the facade
// falls back to `.automatic`.
//
// Phase 10D-final — per-row Mail-app row behavior. Three modifiers are
// applied per row using the absolute row index into the flat
// childViews array:
//   1. `.onTapGesture` when `rowTapTokens[absIdx] != 0` — fires the
//      whole-row tap callback (typically navigation to the editor).
//   2. `.swipeActions(edge: .leading, allowsFullSwipe: true)` when the
//      row has any leading actions per `leadingActionCounts`.
//   3. `.swipeActions(edge: .trailing, allowsFullSwipe: true)` when
//      the row has any trailing actions per `trailingActionCounts`.
//
// SwiftUI's full-swipe fires the FIRST action in the closure for that
// edge. Crystal-side, the trailing array is ordered
// `[delete, mark_done, share, edit]` so SwiftUI renders Delete as the
// outermost (closest to the swipe edge) full-swipe-primary tile, and
// the visual left→right order when fully revealed is
// `[edit, share, mark_done, delete]`.
//
// `.onMove(perform:)` is applied to the inner `ForEach` (SwiftUI
// requires it on the ForEach, not the List). When `moveToken != nil`
// the closure fires `CallbackBridge.fireString(token:value:)` with a
// `"from=N,to=M"` payload. Crystal-side, the string-channel callback
// parses this and dispatches `:move_row` with the absolute indices.
//
// Selection semantics: this facade currently uses SwiftUI's default
// (no programmatic selection binding). Wiring `selection_mode` would
// require a `Binding<Set<ID>>`-style state holder (see the
// `IntStorage` pattern used by ToggleButton). It is left as a
// follow-up; the Crystal side has no `selection_mode` property today
// (verified against `src/ui/views/list_view.cr`).

import SwiftUI
import Foundation

@objc(APSKListViewFacade)
public class ListViewFacade: NSObject {
    @objc public static func makeListView(
        childViews: [APSKPlatformView],
        overrides: ListViewOverrides
    ) -> APSKPlatformView {
        let counts = overrides.sectionItemCounts.map { $0.intValue }
        let headers = overrides.sectionHeaders
        let footers = overrides.sectionFooters

        // Pre-compute slice offsets per section so the ForEach builder
        // body is O(1) per row.
        var offsets: [Int] = []
        var acc = 0
        for c in counts {
            offsets.append(acc)
            acc += c
        }

        // SwiftUI `.listRowSeparator(.hidden)` is iOS 15 / macOS 13. When
        // the Crystal author explicitly disables separators we apply it
        // per-row; SwiftUI default (separators visible) is the nil-path.
        let hideSeparators: Bool = {
            guard let flag = overrides.showsSeparators else { return false }
            return !flag.boolValue
        }()

        // Pre-compute per-row leading/trailing action slice offsets so
        // `actionsForRow(...)` is O(1).
        let leadingCounts = overrides.leadingActionCounts.map { $0.intValue }
        let trailingCounts = overrides.trailingActionCounts.map { $0.intValue }
        var leadingOffsets: [Int] = []
        var leadingAcc = 0
        for c in leadingCounts {
            leadingOffsets.append(leadingAcc)
            leadingAcc += c
        }
        var trailingOffsets: [Int] = []
        var trailingAcc = 0
        for c in trailingCounts {
            trailingOffsets.append(trailingAcc)
            trailingAcc += c
        }

        let moveToken: UInt64? = overrides.moveToken?.uint64Value
        let rowTapTokens = overrides.rowTapTokens

        // Phase 10D-polish A4 — default 16pt row inset (Mail-style).
        // nil → SwiftUI platform default; default 16pt populated by
        // the Crystal populator unless the consumer explicitly clears it.
        let insetH: CGFloat? = overrides.contentInsetHorizontal
            .map { CGFloat($0.doubleValue) }

        // Phase 10D-polish A3 — row-removal animation duration. 0.0
        // disables; default 0.4s. Wraps the inner ForEach in a
        // `withAnimation(.easeInOut(...))` via the `animation(_:value:)`
        // modifier so SwiftUI runs the removal transition on count change.
        let removalDuration: Double = overrides.rowRemovalDurationSeconds?
            .doubleValue ?? 0.4

        // Phase 10D-polish A2 — drag-handle visibility. Renders only when
        // `moveToken != nil` AND `showsDragHandle != false`. Default true.
        let showsDragHandle: Bool = (overrides.showsDragHandle?.boolValue ?? true)
            && (moveToken != nil)

        let list = List {
            ForEach(0..<counts.count, id: \.self) { sIdx in
                let header = sIdx < headers.count ? headers[sIdx] : ""
                let footer = sIdx < footers.count ? footers[sIdx] : ""
                let off = offsets[sIdx]
                let cnt = counts[sIdx]
                Section {
                    moveAwareForEach(
                        range: 0..<cnt,
                        offset: off,
                        moveToken: moveToken
                    ) { iIdx in
                        let absIdx = off + iIdx
                        rowBuilder(
                            view: childViews[absIdx],
                            absIdx: absIdx,
                            hideSeparator: hideSeparators,
                            rowTapTokens: rowTapTokens,
                            overrides: overrides,
                            leadingOffsets: leadingOffsets,
                            leadingCounts: leadingCounts,
                            trailingOffsets: trailingOffsets,
                            trailingCounts: trailingCounts,
                            insetHorizontal: insetH,
                            showsDragHandle: showsDragHandle,
                            removalDuration: removalDuration
                        )
                    }
                } header: {
                    if !header.isEmpty { Text(header) }
                } footer: {
                    if !footer.isEmpty { Text(footer) }
                }
            }
        }

        // Phase 10D-polish A3 — drive removal animation by binding the
        // `animation(_:value:)` modifier to the total childViews count,
        // so SwiftUI runs the easeInOut on every shrink (delete) event.
        let animated: AnyView = {
            if removalDuration > 0.0 {
                return AnyView(
                    list.animation(
                        .easeInOut(duration: removalDuration),
                        value: childViews.count
                    )
                )
            }
            return AnyView(list)
        }()

        let styled: AnyView = applyListStyle(animated, key: overrides.listStyle)
        let composed = CommonModifiers.apply(styled, overrides: overrides)
        return HostingHelpers.host(composed)
    }

    // Build a `ForEach` that conditionally honors `.onMove`. SwiftUI's
    // `.onMove(perform:)` is only honored when attached to a `ForEach`
    // inside a `List`; long-press-drag is the iOS 15+ default activator
    // (no EditButton wiring required).
    @ViewBuilder
    private static func moveAwareForEach<Content: View>(
        range: Range<Int>,
        offset: Int,
        moveToken: UInt64?,
        @ViewBuilder content: @escaping (Int) -> Content
    ) -> some View {
        if let token = moveToken {
            ForEach(range, id: \.self) { i in
                content(i)
            }
            .onMove { src, dst in
                guard let from = src.first else { return }
                // SwiftUI passes absolute-to-section indices already; we
                // forward the per-section indices plus the section
                // offset so the Crystal side gets absolute row indices.
                let absFrom = from + offset
                let absTo = dst + offset
                CallbackBridge.fireString(
                    token: token,
                    value: "from=\(absFrom),to=\(absTo)"
                )
            }
        } else {
            ForEach(range, id: \.self) { i in
                content(i)
            }
        }
    }

    // Build a single row with all the per-row modifiers (tap + leading
    // swipe + trailing swipe + separator-hide + drag handle + insets +
    // removal transition).
    @ViewBuilder
    private static func rowBuilder(
        view: APSKPlatformView,
        absIdx: Int,
        hideSeparator: Bool,
        rowTapTokens: [NSNumber],
        overrides: ListViewOverrides,
        leadingOffsets: [Int],
        leadingCounts: [Int],
        trailingOffsets: [Int],
        trailingCounts: [Int],
        insetHorizontal: CGFloat?,
        showsDragHandle: Bool,
        removalDuration: Double
    ) -> some View {
        let base = APSKHostedChild(view: view)

        let tapToken: UInt64 = {
            if absIdx < rowTapTokens.count {
                return rowTapTokens[absIdx].uint64Value
            }
            return 0
        }()

        let leadingCount = absIdx < leadingCounts.count ? leadingCounts[absIdx] : 0
        let leadingOffset = absIdx < leadingOffsets.count ? leadingOffsets[absIdx] : 0
        let trailingCount = absIdx < trailingCounts.count ? trailingCounts[absIdx] : 0
        let trailingOffset = absIdx < trailingOffsets.count ? trailingOffsets[absIdx] : 0

        // Phase 10D-polish A2 — drag affordance overlay. Render the
        // SF Symbol `line.3.horizontal` on the trailing edge when
        // `showsDragHandle` resolves true (moveToken != nil &&
        // overrides.showsDragHandle != false). The Image is rendered
        // inside an HStack with a Spacer so it sits on the trailing
        // edge without disrupting the hosted-child intrinsic layout.
        let baseWithDragHandle: AnyView = {
            if showsDragHandle {
                return AnyView(
                    HStack(spacing: 0) {
                        base
                        Spacer(minLength: 8)
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                            .accessibilityLabel("Reorder row")
                            .padding(.trailing, 4)
                            .frame(width: 24)
                    }
                )
            } else {
                return AnyView(base)
            }
        }()

        let withTap: AnyView = {
            if tapToken != 0 {
                return AnyView(
                    baseWithDragHandle.contentShape(Rectangle())
                        .onTapGesture {
                            CallbackBridge.fire(token: tapToken, value: 0.0)
                        }
                )
            } else {
                return AnyView(baseWithDragHandle)
            }
        }()

        let withLeading: AnyView = {
            if leadingCount > 0 {
                return AnyView(
                    withTap.swipeActions(edge: .leading, allowsFullSwipe: true) {
                        ForEach(0..<leadingCount, id: \.self) { i in
                            actionButton(
                                index: leadingOffset + i,
                                labels: overrides.leadingActionLabels,
                                icons: overrides.leadingActionIcons,
                                tokens: overrides.leadingActionTokens,
                                roles: overrides.leadingActionRoles,
                                tints: overrides.leadingActionTints,
                                labelStyles: overrides.leadingActionLabelStyles
                            )
                        }
                    }
                )
            } else {
                return withTap
            }
        }()

        let withTrailing: AnyView = {
            if trailingCount > 0 {
                return AnyView(
                    withLeading.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        ForEach(0..<trailingCount, id: \.self) { i in
                            actionButton(
                                index: trailingOffset + i,
                                labels: overrides.trailingActionLabels,
                                icons: overrides.trailingActionIcons,
                                tokens: overrides.trailingActionTokens,
                                roles: overrides.trailingActionRoles,
                                tints: overrides.trailingActionTints,
                                labelStyles: overrides.trailingActionLabelStyles
                            )
                        }
                    }
                )
            } else {
                return withLeading
            }
        }()

        // Phase 10D-polish A4 — apply 16pt (or override) horizontal
        // row inset via SwiftUI's `.listRowInsets(...)`. We honor any
        // explicit inset; nil means "use SwiftUI default."
        // Phase 10D-polish A3 — `.transition(...)` for row removal.
        // Asymmetric so inserts feel snappy but deletes collapse with
        // an opacity + leading-scale animation.
        let withInsets: AnyView = {
            if let insetH = insetHorizontal {
                if #available(iOS 15.0, macOS 12.0, *) {
                    return AnyView(
                        withTrailing.listRowInsets(EdgeInsets(
                            top: 8,
                            leading: insetH,
                            bottom: 8,
                            trailing: insetH
                        ))
                    )
                }
            }
            return AnyView(withTrailing)
        }()

        let withTransition: AnyView = {
            if removalDuration > 0.0 {
                if #available(iOS 15.0, macOS 12.0, *) {
                    return AnyView(
                        withInsets.transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(
                                    scale: 0.0, anchor: .leading
                                ))
                            )
                        )
                    )
                }
            }
            return withInsets
        }()

        if hideSeparator {
            if #available(iOS 15.0, macOS 13.0, *) {
                withTransition.listRowSeparator(.hidden)
            } else {
                withTransition
            }
        } else {
            withTransition
        }
    }

    /// Build a SwiftUI Button for one action tile inside a `.swipeActions`
    /// closure. Identical contract to `SwipeActionRowFacade.actionButton`
    /// (role + tint + icon + label), parameterized over the parallel
    /// flat arrays so a single helper services both edges.
    ///
    /// Phase 10D-polish A1 — Mail-style square-corner tiles. The owner
    /// reported that the previous chrome rendered with rounded / capsule
    /// corners. The fix is twofold:
    ///   1. Use `.tint(color)` (SwiftUI's documented swipe-tile tint API)
    ///      and rely on SwiftUI to paint the full-bleed rectangle. We do
    ///      NOT apply a custom `.buttonStyle` because that suppresses
    ///      SwiftUI's swipe-action tile chrome.
    ///   2. Render the label as a `Label(label, systemImage: icon)` with
    ///      a stacked vertical icon-above-text layout (Mail's idiom on
    ///      iOS 17+) so the tile reads at swipe-edge width.
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
                        swipeTileLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            } else if role == "cancel" {
                return AnyView(
                    Button(role: .cancel, action: action) {
                        swipeTileLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            } else {
                return AnyView(
                    Button(action: action) {
                        swipeTileLabel(label: label, icon: icon, style: labelStyle)
                    }
                )
            }
        }()

        // `.tint(color)` paints the SwiftUI swipe-action tile fill (full-
        // bleed, square corners — system chrome). For destructive, we
        // skip explicit tinting so SwiftUI's role-based red applies.
        if let color = colorFor(tintKey: tintKey) {
            button.tint(color)
        } else {
            button
        }
    }

    // Phase 10D-polish A1 — Mail-app tile layout. SwiftUI's swipe-action
    // tile sizes itself based on its label; using an icon-above-text
    // stack (matching iOS Mail) gives the tile the right tap target and
    // visual weight without forcing a custom .buttonStyle (which
    // suppresses the swipe-tile chrome).
    @ViewBuilder
    private static func swipeTileLabel(label: String, icon: String, style: String = "auto") -> some View {
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
                Label(label, systemImage: icon).labelStyle(.titleAndIcon)
            } else if !icon.isEmpty {
                Image(systemName: icon)
            } else {
                Text(label)
            }
        default:
            if !icon.isEmpty && !label.isEmpty {
                // Use SwiftUI Label so VoiceOver reads both icon + text
                // and Dynamic Type scales the stacked tile.
                Label(label, systemImage: icon)
                    .labelStyle(.titleAndIcon)
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

    // Map the Crystal `UI::ListStyle` enum (passed as a string by the
    // populator) to SwiftUI's `.listStyle(...)` modifier. Unknown /
    // nil keys fall back to `.automatic`, matching the SwiftUI default
    // for the host platform.
    private static func applyListStyle<L: View>(_ list: L, key: String?) -> AnyView {
        switch key {
        case "plain":
            return AnyView(list.listStyle(.plain))
        case "grouped":
            #if os(iOS)
            return AnyView(list.listStyle(.grouped))
            #else
            return AnyView(list.listStyle(.inset))
            #endif
        case "inset":
            return AnyView(list.listStyle(.inset))
        case "insetGrouped":
            #if os(iOS)
            return AnyView(list.listStyle(.insetGrouped))
            #else
            return AnyView(list.listStyle(.inset))
            #endif
        case "sidebar":
            return AnyView(list.listStyle(.sidebar))
        default:
            return AnyView(list.listStyle(.automatic))
        }
    }
}
