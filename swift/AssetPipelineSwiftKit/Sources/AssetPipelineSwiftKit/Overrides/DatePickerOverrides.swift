// DatePickerOverrides — per-DatePicker overrides above ViewOverrides.

import Foundation

@objc(APSKDatePickerOverrides)
public class DatePickerOverrides: ViewOverrides {
    @objc public var datePickerMode: String? = nil
    // Phase 10D-polish iter 2 (B-DATEPICKER-STYLE-PROPERTY).
    // "automatic" | "compact" | "graphical" | "wheels". nil = automatic.
    @objc public var datePickerStyle: String? = nil

    @objc public override init() { super.init() }
}
