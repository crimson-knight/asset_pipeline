// PickerOverrides — per-Picker overrides above ViewOverrides.
//
// pickerStyle : "menu" | "wheel" | "segmented" | "inline" | "navigationlink"
//                — maps to the matching SwiftUI `.pickerStyle(...)` value.
//                nil = `.menu` (SwiftUI's contextual default).
// fillHorizontal : true when the Crystal view is `fill_horizontal`; the
//                facade lets the picker take the width its container
//                offers instead of hugging its widest option.

import Foundation

@objc(APSKPickerOverrides)
public class PickerOverrides: ViewOverrides {
    @objc public var pickerStyle: String? = nil
    @objc public var surfaceCraftSwatchSpec: String? = nil
    @objc public var fillHorizontal: NSNumber? = nil

    @objc public override init() { super.init() }
}
