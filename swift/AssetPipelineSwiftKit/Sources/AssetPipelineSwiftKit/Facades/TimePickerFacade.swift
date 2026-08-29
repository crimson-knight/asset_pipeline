// TimePickerFacade — SwiftUI DatePicker(displayedComponents: .hourAndMinute).
//
// Crystal exposes a separate widget; on Swift we emit the same DatePicker
// with .hourAndMinute components. The `shows24Hour` override is a hint
// the Swift side currently ignores because SwiftUI inherits the user's
// system 24h preference automatically.

import SwiftUI
import Foundation

// watchOS: ENABLED (Phase D Bucket-2 P2 port, 2026-06-02). Same DatePicker
// (.hourAndMinute) the DatePicker facade uses — available on watchOS 10+, no styles
// to gate. Straight un-gate. See watch-facade-bucket-audit.md.
@objc(APSKTimePickerFacade)
public class TimePickerFacade: NSObject {
    @objc public static func makeTimePicker(
        label: String,
        initialEpoch: Double,
        overrides: TimePickerOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = DateStorage(initial: Date(timeIntervalSince1970: initialEpoch), token: actionToken)

        var content: AnyView = AnyView(
            DatePicker(label,
                       selection: storage.binding,
                       displayedComponents: .hourAndMinute)
        )

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(DateHost(storage: storage, content: content))
    }
}
