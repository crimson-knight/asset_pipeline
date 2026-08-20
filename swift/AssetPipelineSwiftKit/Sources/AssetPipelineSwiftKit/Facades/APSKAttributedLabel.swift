import SwiftUI
#if canImport(UIKit)
import UIKit

// ═══════════════════════════════════════════════════════════════════════════
// THE LABEL THAT CAN BE LED TIGHTER THAN THE FACE'S OWN ADVANCE
// ═══════════════════════════════════════════════════════════════════════════
//
// SwiftUI's `Text` closes exactly one door and UIKit leaves it open.
// `.lineSpacing(_:)` ADDS points between lines and clamps at zero, so a line
// ratio ABOVE the face's own ~1.195 is expressible and one BELOW it is not —
// and `Text` does not honour an `NSParagraphStyle`, so there is no second way
// in. Every display ramp in the field asks for the direction that is closed:
// `.p-h1,.p-h2,.p-h3{line-height:1.06}`.
//
// MEASURED. A 28pt section heading wrapping onto two lines drew band tops at
// y872 and y971 — a 99px / 33.0pt advance, ratio 1.179 — where the stylesheet
// the same prospect is holding asks for 29.7pt. 3.3pt of extra air per gap on
// a section heading, 4.3pt on a 36pt hero, on every headline that wraps.
//
// A `UILabel` carrying an `NSAttributedString` whose paragraph style sets
// `lineHeightMultiple` honours a ratio below 1.0. This is that label, and it is
// deliberately NARROW: it is reached only when a caller asks for a ratio the
// SwiftUI path cannot draw (`LabelOverrides.lineHeightMultiple` below 1.0).
// Everything else keeps the `Text` path unchanged, so the blast radius of this
// file is the display roles and nothing else.
//
// WHY IT REPRODUCES THE MODIFIERS RATHER THAN COMPOSING THEM. A
// `UIViewRepresentable` is opaque to SwiftUI's text modifiers: `.foregroundStyle`,
// `.tracking` and `.multilineTextAlignment` all reach a SwiftUI `Text` and none
// of them reaches a hosted `UILabel`. So the four values that would otherwise be
// silently dropped — colour, alignment, tracking and line limit — are read off
// the same overrides object and applied to the attributed string here. Anything
// this file forgets is a value that draws as the platform default, which is the
// failure mode the whole `resolved_family` idea exists to stop; the fields it
// reads are listed in one place (`makeAttributes`) for that reason.
struct APSKAttributedLabel: UIViewRepresentable {
    let text: String
    let font: UIFont
    let color: UIColor
    let alignment: NSTextAlignment
    let lineHeightMultiple: CGFloat
    let tracking: CGFloat
    let numberOfLines: Int

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = numberOfLines
        // The hosting SwiftUI frame owns the width; the label must not fight it
        // in either direction, or a long headline is compressed to one line and
        // truncated instead of wrapping.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.numberOfLines = numberOfLines
        label.attributedText = NSAttributedString(string: text, attributes: makeAttributes())
    }

    // iOS 16+. Without this SwiftUI proposes a size from the label's intrinsic
    // content size, which for a wrapping label is its ONE-LINE ideal width — the
    // same under-reservation the SwiftUI path needs `.fixedSize(vertical:)` for.
    // Asking the label what it needs at the PROPOSED width is the UIKit
    // equivalent and is what makes a wrapped heading reserve its real height.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel,
                      context: Context) -> CGSize? {
        let width = proposal.width ?? label.intrinsicContentSize.width
        guard width > 0, width < .greatestFiniteMagnitude else { return nil }
        let fitted = label.sizeThatFits(CGSize(width: width,
                                               height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    private func makeAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        // BOTH BOUNDS, because `lineHeightMultiple` alone is a MINIMUM in some
        // layout paths and leaves the face's own advance in place. Pinning the
        // maximum to the same value is what makes the ratio the ratio.
        paragraph.lineHeightMultiple = lineHeightMultiple
        paragraph.maximumLineHeight = font.lineHeight * lineHeightMultiple
        // A line box shorter than the face's natural advance pushes the first
        // baseline UP and clips ascenders unless the whole run is nudged back
        // down by what was taken off it. This is that nudge, and without it a
        // tight heading loses the tops of its capitals.
        let shrink = font.lineHeight * (1.0 - lineHeightMultiple)

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .baselineOffset: shrink / 2.0,
        ]
        if tracking != 0 {
            attributes[.kern] = tracking
        }
        return attributes
    }
}
#endif
