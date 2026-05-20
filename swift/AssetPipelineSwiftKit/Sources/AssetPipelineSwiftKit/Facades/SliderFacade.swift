// SliderFacade — SwiftUI Slider(value:in:) bridge.

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
        let storage = DoubleStorage(initial: value, token: actionToken)

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
