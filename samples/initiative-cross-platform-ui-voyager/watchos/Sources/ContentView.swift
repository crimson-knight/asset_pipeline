import SwiftUI

// ContentView — renders a vertical gallery of asset_pipeline SwiftKit facades on
// watchOS by calling each facade's `make*` entry point and embedding the returned
// `APSKWatchHostView.content` (the facade's SwiftUI body). This is the SAME SwiftUI
// the Crystal UI::WatchKit::Renderer would compose; here we drive it from Swift so
// the catalog can be PROVEN to render on a real watch while the Crystal cross-compile
// is blocked on the toolchain fix.
//
// actionToken 0 is used throughout: with no Crystal callback registry wired,
// CallbackBridge.fire(token: 0, …) is a no-op — fine for a render demo.
struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Wordmark (styled Label facade)
                facade(LabelFacade.makeLabel(text: "Voyager", overrides: titleOverrides()))
                facade(LabelFacade.makeLabel(
                    text: "asset_pipeline on the wrist",
                    overrides: LabelOverrides()))

                Divider()

                // Button facade
                facade(ButtonFacade.makeButton(
                    label: "Sign in",
                    overrides: ButtonOverrides(),
                    actionToken: 0))

                // Toggle facade (SwiftUI Toggle path on watch — no UISwitch)
                facade(ToggleFacade.makeToggle(
                    label: "Notifications",
                    isOn: true,
                    overrides: ToggleOverrides(),
                    actionToken: 0))

                // Slider facade (Digital Crown on watch)
                facade(SliderFacade.makeSlider(
                    value: 0.6, minimum: 0, maximum: 1,
                    overrides: SliderOverrides(),
                    actionToken: 0))

                // Stepper facade
                facade(StepperFacade.makeStepper(
                    label: "Count",
                    value: 2, minimum: 0, maximum: 10,
                    overrides: StepperOverrides(),
                    actionToken: 0))
            }
            .padding()
        }
    }

    // Embed a facade's boundary-node content (the SwiftUI body) into this view tree.
    @ViewBuilder
    private func facade(_ box: APSKWatchHostView) -> some View {
        box.content
    }

    private func titleOverrides() -> LabelOverrides {
        let o = LabelOverrides()
        o.fontSize = NSNumber(value: 22.0)
        o.fontWeight = NSNumber(value: 700)
        return o
    }
}
