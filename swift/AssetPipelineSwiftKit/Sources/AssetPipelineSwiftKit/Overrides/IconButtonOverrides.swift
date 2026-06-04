// IconButtonOverrides — per-IconButton overrides above ViewOverrides.

import Foundation

@objc(APSKIconButtonOverrides)
public class IconButtonOverrides: ViewOverrides {
    @objc public var iconSize: NSNumber? = nil
    @objc public var disabled: NSNumber? = nil
    @objc public var label: String? = nil
    // nil/true = standard platform button chrome. false = `.buttonStyle(.plain)`
    // for a bare, chrome-free tappable icon.
    @objc public var bordered: NSNumber? = nil

    @objc public override init() { super.init() }
}
