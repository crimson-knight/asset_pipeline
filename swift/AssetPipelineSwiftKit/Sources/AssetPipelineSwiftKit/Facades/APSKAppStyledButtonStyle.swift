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
// feedback dim the fill along with the label.
//
// When the app set a font but no background, the style draws a default fill
// and padding so the control still reads as a button: a quiet neutral fill
// for default / bordered / tinted buttons, the accent (or brand) fill with a
// white label for prominent ones.

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

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let drawsDefaultChrome = fill == nil
        let shape = RoundedRectangle(cornerRadius: cornerRadius ?? (drawsDefaultChrome ? (isProminent ? 8 : 6) : 0))
        let insets = padding ?? (drawsDefaultChrome
            ? EdgeInsets(top: isProminent ? 6 : 4, leading: isProminent ? 14 : 10,
                         bottom: isProminent ? 6 : 4, trailing: isProminent ? 14 : 10)
            : EdgeInsets())

        // The app's own foreground is applied by ButtonFacade outside this
        // style and reaches the label through the environment; setting one
        // here would override it.
        let label: AnyView
        if usesDefaultForeground && isDestructive {
            label = AnyView(configuration.label.foregroundStyle(Color.red))
        } else if usesDefaultForeground && drawsDefaultChrome {
            label = AnyView(configuration.label.foregroundStyle(defaultForeground))
        } else {
            label = AnyView(configuration.label)
        }

        var body = AnyView(
            label
                .padding(insets)
                .frame(minWidth: minimumWidth, minHeight: minimumHeight)
                .background(shape.fill(fill ?? defaultFill))
                .clipShape(shape)
        )
        if let border = border {
            body = AnyView(body.overlay(shape.stroke(border.color, lineWidth: border.width)))
        }
        return body
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1.0) : 0.45)
            .accessibilityAddTraits(.isButton)
    }

    private var defaultFill: Color {
        if isProminent {
            return APSKRuntime.brandTint ?? Color.accentColor
        }
        return Color.primary.opacity(0.09)
    }

    private var defaultForeground: AnyShapeStyle {
        isProminent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary)
    }
}
#endif
