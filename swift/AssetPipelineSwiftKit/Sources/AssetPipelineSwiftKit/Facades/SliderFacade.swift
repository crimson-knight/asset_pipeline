// SliderFacade — SwiftUI Slider(value:in:) bridge.
//
// Phase 3 Remediation 4: `makeReactiveSlider` writes the underlying
// `DoubleStorage` pointer through `outState` so Crystal can later mutate
// `storage.value` via `apsk_slider_set_value`.

import SwiftUI
import Foundation

@objc(APSKSliderFacade)
public class SliderFacade: NSObject {
    @objc public static func makeSlider(
        value: Double,
        minimum: Double,
        maximum: Double,
        overrides: SliderOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        return makeReactiveSlider(
            value: value, minimum: minimum, maximum: maximum,
            overrides: overrides, actionToken: actionToken, outState: nil
        )
    }

    @objc public static func makeReactiveSlider(
        value: Double,
        minimum: Double,
        maximum: Double,
        overrides: SliderOverrides,
        actionToken: UInt64,
        outState: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
    ) -> APSKPlatformView {
        let storage = DoubleStorage(initial: value, token: actionToken)

        if let outState = outState {
            outState.pointee = Unmanaged.passRetained(storage).toOpaque()
        }

        let slider: AnyView
        if let step = overrides.step, step.doubleValue > 0 {
            slider = AnyView(
                Slider(value: storage.binding, in: minimum...maximum, step: step.doubleValue)
            )
        } else {
            slider = AnyView(Slider(value: storage.binding, in: minimum...maximum))
        }

        var content: AnyView = slider
        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(DoubleHost(storage: storage, content: content))
    }
}

struct DoubleHost<Content: View>: View {
    @ObservedObject var storage: DoubleStorage
    let content: Content
    var body: some View { content }
}
