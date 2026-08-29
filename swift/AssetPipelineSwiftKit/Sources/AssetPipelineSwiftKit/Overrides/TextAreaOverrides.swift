// TextAreaOverrides — per-TextArea overrides above ViewOverrides.

import Foundation

@objc(APSKTextAreaOverrides)
public class TextAreaOverrides: ViewOverrides {
    @objc public var editable: NSNumber? = nil
    @objc public var scrollable: NSNumber? = nil
    @objc public var lineLimit: NSNumber? = nil
    // Font: point size, raw Font.Weight intValue, custom family / PostScript
    // name. nil = SwiftUI default. Mirrors LabelOverrides / ButtonOverrides.
    @objc public var fontSize: NSNumber? = nil
    @objc public var fontWeight: NSNumber? = nil
    @objc public var fontFamily: String? = nil

    @objc public override init() { super.init() }
}
