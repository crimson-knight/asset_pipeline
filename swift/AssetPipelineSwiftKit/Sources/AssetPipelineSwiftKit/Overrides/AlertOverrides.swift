// AlertOverrides — per-Alert overrides above ViewOverrides.
//
// Field semantics:
//   title              : alert title (positional on the facade, here for
//                        completeness when overrides flow externally).
//   message            : optional message body. nil/empty = title-only.
//   isPresented        : NSNumber bool. nil = false.
//   buttonLabels       : NSArray<NSString *> of button titles.
//   buttonStyles       : NSArray<NSString *> — "default" | "destructive" |
//                        "cancel". Parallel to buttonLabels.
//   buttonTokens       : NSArray<NSNumber *> of UInt64 action tokens
//                        (NSNumber boxes; cast back via .uint64Value).
//                        Parallel to buttonLabels.

import Foundation

@objc(APSKAlertOverrides)
public class AlertOverrides: ViewOverrides {
    @objc public var title: String? = nil
    @objc public var message: String? = nil
    @objc public var isPresented: NSNumber? = nil
    @objc public var buttonLabels: [String] = []
    @objc public var buttonStyles: [String] = []
    @objc public var buttonTokens: [NSNumber] = []

    @objc public override init() { super.init() }
}
