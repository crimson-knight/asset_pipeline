// APSKSurfaceFaceButtonStyle — the macOS ButtonStyle for a Button that
// carries a surface-craft face (UI::View#background_fill_color or
// #linear_gradient, or UI::Button#hovered_surface_style /
// #pressed_surface_style).
//
// Why a ButtonStyle: a face painted with `.background` outside the Button
// never learns that the Button is pressed, and the facade used to paint the
// surface-craft gradient BEHIND the opaque reactive background, square,
// because the corner radius was only applied to that background. Inside the
// style the face is drawn behind the padded label, clipped to the button's
// corner radius, gradient above the base color, and it swaps with the real
// interaction phase:
//
//   - pressed  (`configuration.isPressed`, or preview_state Pressed):
//              the pressed face, else the resting face darkened slightly;
//   - hovered  (pointer over the button, or preview_state Hover):
//              the hovered face, else the resting face with a faint tint;
//   - resting  otherwise, and always while the button is disabled.
//
// The Button keeps its own action, keyboard shortcut, focus, and
// accessibility; the style only draws.

#if os(macOS)
import SwiftUI

struct APSKSurfaceFaceButtonStyle: ButtonStyle {
    let restingSpec: String?
    let hoveredSpec: String?
    let pressedSpec: String?
    let previewState: String?
    let baseColor: Color?
    let cornerRadius: CGFloat
    let insets: EdgeInsets
    let minimumWidth: CGFloat?
    let minimumHeight: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        APSKSurfaceFaceButtonBody(configuration: configuration, style: self)
    }
}

/// The interaction phase a surface-faced button shows.
enum APSKSurfaceFacePhase: String {
    case resting
    case hovered
    case pressed

    /// A forced preview state wins; a disabled button always rests.
    static func resolve(previewState: String?, isEnabled: Bool, isPressed: Bool, isHovering: Bool) -> APSKSurfaceFacePhase {
        switch previewState {
        case "pressed": return .pressed
        case "hover": return .hovered
        default: break
        }
        guard isEnabled else { return .resting }
        if isPressed { return .pressed }
        return isHovering ? .hovered : .resting
    }
}

private struct APSKSurfaceFaceButtonBody: View {
    // Tints laid over the resting face when no hovered or pressed face is
    // set: the hover tint matches SurfaceCraft's own hover feedback.
    private static let hoverTint = Color.primary.opacity(0.035)
    private static let pressedShade = Color.black.opacity(0.1)

    let configuration: ButtonStyleConfiguration
    let style: APSKSurfaceFaceButtonStyle
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false

    private var phase: APSKSurfaceFacePhase {
        APSKSurfaceFacePhase.resolve(
            previewState: style.previewState,
            isEnabled: isEnabled,
            isPressed: configuration.isPressed,
            isHovering: isHovering
        )
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius)
        configuration.label
            .padding(style.insets)
            .frame(minWidth: style.minimumWidth, minHeight: style.minimumHeight)
            .background { face(shape: shape) }
            .contentShape(shape)
            .onHover { isHovering = $0 }
            #if DEBUG
            .accessibilityValue(Text(phase.rawValue))
            #endif
    }

    @ViewBuilder
    private func face(shape: RoundedRectangle) -> some View {
        switch phase {
        case .resting:
            restingFace
        case .hovered:
            if let hoveredSpec = style.hoveredSpec {
                faceView(hoveredSpec)
            } else {
                restingFace.overlay { shape.fill(Self.hoverTint) }
            }
        case .pressed:
            if let pressedSpec = style.pressedSpec {
                faceView(pressedSpec)
            } else {
                restingFace.overlay { shape.fill(Self.pressedShade) }
            }
        }
    }

    private var restingFace: AnyView {
        faceView(style.restingSpec)
    }

    private func faceView(_ spec: String?) -> AnyView {
        SurfaceCraftModifiers.face(spec: spec, baseColor: style.baseColor, cornerRadius: style.cornerRadius)
    }
}
#endif
