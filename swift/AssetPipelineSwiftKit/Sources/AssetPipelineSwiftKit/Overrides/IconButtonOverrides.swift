// IconButtonOverrides — per-IconButton overrides above ViewOverrides.

import Foundation

@objc(APSKIconButtonOverrides)
public class IconButtonOverrides: ViewOverrides {
    @objc public var iconSize: NSNumber? = nil
    // Explicit non-square icon dimensions. When both are set they override iconSize
    // and the image is cover-cropped (.fill contentMode) into the exact W×H frame.
    @objc public var iconWidth: NSNumber? = nil
    @objc public var iconHeight: NSNumber? = nil
    @objc public var disabled: NSNumber? = nil
    @objc public var label: String? = nil
    // nil/true = standard platform button chrome. false = `.buttonStyle(.plain)`
    // for a bare, chrome-free tappable icon.
    @objc public var bordered: NSNumber? = nil

    @objc public override init() { super.init() }
}
