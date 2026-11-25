// APSKAppStyledButtonStyle — a macOS button that draws the styling the app
// set instead of the system bezel.
//
// On macOS the system button styles (`.automatic`, `.bordered`,
// `.borderedProminent`) draw an AppKit push-button bezel that keeps the
// control font and treats a foreground color as a tint: a Crystal
// `button.font = UI::Font.new(size: 24, weight: :bold)` rendered at 13pt, and
// a filled button showed a gray bezel inside the app's fill. When the app sets
// a background or a font on a button whose style is not borderless,
// ButtonFacade renders it with this style: the label in the app's font and
// foreground, the app's padding / background / corner radius / border around
// it (applied by ButtonFacade outside the style), and pressed / disabled
// feedback by opacity.
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
    /// True when the app set no background, so the style draws its own fill.
    let drawsDefaultChrome: Bool
    /// True when the app set no foreground color.
    let usesDefaultForeground: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1.0) : 0.45)
            .contentShape(Rectangle())
        if drawsDefaultChrome {
            // The app's own foreground is applied by ButtonFacade outside this
            // style; setting one here would override it.
            let tinted: AnyView = usesDefaultForeground
                ? AnyView(label.foregroundStyle(defaultForeground))
                : AnyView(label)
            return AnyView(
                tinted
                    .padding(.vertical, isProminent ? 6 : 4)
                    .padding(.horizontal, isProminent ? 14 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: isProminent ? 8 : 6)
                            .fill(defaultFill.opacity(configuration.isPressed ? 0.8 : 1.0))
                    )
                    .accessibilityAddTraits(.isButton)
            )
        }
        return AnyView(label.accessibilityAddTraits(.isButton))
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
