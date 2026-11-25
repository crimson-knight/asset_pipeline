// APSKAppStyledButtonStyle — a macOS button that draws the styling the app
// set instead of the system bezel.
//
// On macOS the system button styles (`.automatic`, `.bordered`,
// `.borderedProminent`) draw an AppKit push-button bezel that keeps the
// control font and treats a foreground color as a tint: a Crystal
// `button.font = UI::Font.new(size: 24, weight: :bold)` rendered at 13pt, and
// a filled button showed a gray bezel inside the app's fill. When the app sets
// a background or a font on a button whose style is not borderless,
// ButtonFacade renders it with this style.
//
// The style draws the whole control INSIDE the button body: the label in the
// app's font and foreground, then the app's padding, fill, corner radius and
// border. Drawing them inside the body is what makes the whole fill clickable
// (a SwiftUI Button only hit-tests its own body) and lets pressed / disabled
// feedback dim the fill along with the label. The border is drawn inside the
// pill's edge (`strokeBorder`) and inside the same clip as the fill: a stroke
// laid over the clipped fill reached past the pill's outline at its left and
// right ends, and showed there as stray marks.
//
// When the app set a font but no background, the style draws a default fill
// and padding so the control still reads as a button: a quiet neutral fill
// for default / bordered / tinted buttons, the accent (or brand) fill with a
// white label for prominent ones.
//
// Interaction states: hover tints the fill, pressed dims the control, and
// keyboard focus draws an accent ring just outside the pill. Each follows live
// input, or the state an offscreen render names through
// APSKInteractionStatePreview.

#if os(macOS)
import SwiftUI

struct APSKAppStyledButtonStyle: ButtonStyle {
    /// True for `style: Prominent`.
    let isProminent: Bool
    /// The app's padding, or nil for the style's default padding.
    let padding: EdgeInsets?
    /// The app's fill, or nil for the style's default fill.
    let fill: Color?
    /// The app's corner radius, or nil for the style's default radius.
    let cornerRadius: CGFloat?
    /// The app's border width and color, or nil for no border.
    let border: (width: CGFloat, color: Color)?
    /// True when the app set no foreground color.
    let usesDefaultForeground: Bool
    /// The button's minimum size (UI::View minimum_width / minimum_height),
    /// so the fill covers the whole touch target, not only the label.
    let minimumWidth: CGFloat?
    let minimumHeight: CGFloat?
    /// True for `role: :destructive`; the default label color is red.
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        APSKAppStyledButtonBody(style: self, configuration: configuration)
    }
}

/// The drawn button. A separate view so it can observe hover, focus and the
/// previewed interaction state, which a ButtonStyle alone cannot hold.
private struct APSKAppStyledButtonBody: View {
    let style: APSKAppStyledButtonStyle
    let configuration: ButtonStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @ObservedObject private var interactionPreview = APSKInteractionStatePreview.shared
    @State private var isPointerOver = false

    /// Width of the focus ring drawn outside the pill.
    private let focusRingWidth: CGFloat = 3

    var body: some View {
        let drawsDefaultChrome = style.fill == nil
        // A padding or radius the app did not set falls back to the bezel's
        // proportions, so a button that set only a fill keeps room around its
        // label and rounded corners, as the system bezel gave it.
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius ?? (style.isProminent ? 8 : 6))
        let insets = style.padding ?? EdgeInsets(top: style.isProminent ? 6 : 4, leading: style.isProminent ? 14 : 10,
                                                 bottom: style.isProminent ? 6 : 4, trailing: style.isProminent ? 14 : 10)

        // The app's own foreground is applied by ButtonFacade outside this
        // style and reaches the label through the environment; setting one
        // here would override it.
        let label: AnyView
        if style.usesDefaultForeground && style.isDestructive {
            label = AnyView(configuration.label.foregroundStyle(Color.red))
        } else if style.usesDefaultForeground && drawsDefaultChrome {
            label = AnyView(configuration.label.foregroundStyle(defaultForeground))
        } else {
            label = AnyView(configuration.label)
        }

        // The border sits inside the same clip as the fill: a stroke drawn
        // over the clipped fill followed a slightly different outline near
        // the corners and showed beside the pill as stray marks.
        let borderColor = style.border?.color ?? Color.clear
        let borderWidth = style.border?.width ?? 0
        var body = AnyView(
            label
                .padding(insets)
                .frame(minWidth: style.minimumWidth, minHeight: style.minimumHeight)
                .background(shape.fill(style.fill ?? defaultFill))
                .overlay(shape.fill(Color.primary.opacity(showsHover ? 0.08 : 0)))
                .overlay(shape.strokeBorder(borderColor, lineWidth: borderWidth))
                .clipShape(shape)
        )
        if showsFocus {
            body = AnyView(body.overlay(
                shape.inset(by: -focusRingWidth)
                    .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: focusRingWidth)
            ))
        }
        return body
            .contentShape(shape)
            .opacity(isEnabled ? (showsPressed ? 0.75 : 1.0) : 0.45)
            .onHover { isPointerOver = $0 }
            .accessibilityAddTraits(.isButton)
    }

    private var previewedState: APSKPreviewedInteractionState { interactionPreview.previewedState }

    private var showsHover: Bool {
        isEnabled && (isPointerOver || previewedState == .hover)
    }

    private var showsPressed: Bool {
        configuration.isPressed || previewedState == .pressed
    }

    private var showsFocus: Bool {
        isEnabled && (isFocused || previewedState == .focused)
    }

    private var defaultFill: Color {
        if style.isProminent {
            return APSKRuntime.brandTint ?? Color.accentColor
        }
        return Color.primary.opacity(0.09)
    }

    private var defaultForeground: AnyShapeStyle {
        style.isProminent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary)
    }
}
#endif
