// DatePickerFacade — SwiftUI DatePicker(...) bridge.

import SwiftUI
import Foundation

// watchOS: ENABLED (Phase D Bucket-2 P2 port, 2026-06-02). SwiftUI `DatePicker`
// (with `displayedComponents:`) is available on watchOS 10+. The explicit
// `.graphical`/`.wheel`/`.compact` date-picker styles are not watchOS idioms
// (watchOS presents its own date UI), so the style switch is gated off there and
// the default DatePicker is used. See watch-facade-bucket-audit.md.
@objc(APSKDatePickerFacade)
public class DatePickerFacade: NSObject {
    @objc public static func makeDatePicker(
        label: String,
        initialEpoch: Double,
        overrides: DatePickerOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = DateStorage(initial: Date(timeIntervalSince1970: initialEpoch), token: actionToken)

        let components: DatePickerComponents
        switch overrides.datePickerMode {
        case "time":        components = .hourAndMinute
        case "datetime":    components = [.date, .hourAndMinute]
        default:            components = .date
        }

        var content: AnyView = AnyView(
            DatePicker(label, selection: storage.binding, displayedComponents: components)
        )

        // Phase 10D-polish iter 2 (B-DATEPICKER-STYLE-PROPERTY) — apply
        // the SwiftUI .datePickerStyle modifier when the Crystal-side
        // style is non-default. The .compact, .graphical, and .wheel
        // styles are iOS 14+ / macOS 10.15+ where present.
        // watchOS: these explicit styles are not watch idioms (watchOS presents its
        // own date UI), so the whole style switch is gated off — the default
        // DatePicker is used on watch.
        #if !os(watchOS)
        switch overrides.datePickerStyle {
        case "compact":
            #if canImport(UIKit)
            if #available(iOS 14.0, *) {
                content = AnyView(content.datePickerStyle(.compact))
            }
            #else
            content = AnyView(content.datePickerStyle(.compact))
            #endif
        case "graphical":
            content = AnyView(content.datePickerStyle(.graphical))
        case "wheels":
            #if canImport(UIKit)
            content = AnyView(content.datePickerStyle(.wheel))
            #endif
        default:
            break // "automatic" / nil — platform default
        }
        #endif

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(DateHost(storage: storage, content: content))
    }
}

struct DateHost<Content: View>: View {
    @ObservedObject var storage: DateStorage
    let content: Content
    var body: some View { content }
}
