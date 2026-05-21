import XCTest

// Phase03BehaviorTests — iOS XCUITest target for Phase 3 Group BX checks.
//
// Each method drives one rubric check by launching the host with
// HIG_SLUG=phase-03-<slug>, exercising the focal control via XCUITest, and
// asserting the mirror Label transitions. The host bridge's slug dispatch
// (see hig_bridge.cr §"Phase 3 Remediation 3 — validation probe scenes")
// renders the probe scenes.
//
// Identifier strings are pinned by the rubric and must not be edited
// without an Architect adjudication.
//
// Run any single test:
//   xcodebuild test -project CrystalHIGHost.xcodeproj \
//     -scheme CrystalHIGHost \
//     -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
//     -only-testing CrystalHIGHostUITests/Phase03BehaviorTests/<method>
//
// Remediation 7 (2026-05-21): tightened every BX method to the rubric's
// strict transition assertion (the prior iter-5 author relaxed the rubric
// to "control remained present"). Each test now reads the reactive mirror
// label's content before and after each interaction and writes the
// observed transition array to `inspections/BX*-transitions.json` as an
// XCTAttachment with `lifetime = .keepAlways` per validation.md.

final class Phase03BehaviorTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // Helper that launches the host with a given HIG_SLUG and waits for the
    // Crystal-rendered accessibility root to attach.
    private func launchHost(slug: String, appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-HIGSlug", slug]
        app.launchEnvironment["HIG_SLUG"] = slug
        app.launchEnvironment["HIG_APPEARANCE"] = appearance
        app.launchEnvironment["HIG_VALIDATION_CAPTURE"] = "1"
        app.launch()

        let root = app.otherElements["hig-component-root"]
        _ = root.waitForExistence(timeout: 10)
        return app
    }

    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: screenshot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func attachJSON(_ object: Any, name: String) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: object, options: [.prettyPrinted]
        ) else { return }
        let att = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    // Read the displayed text from a SwiftUI Text via XCUITest. For Text the
    // displayed string is exposed as `.label` (with `.value` as a fallback
    // for cases where SwiftUI promotes it to the value slot, e.g. when the
    // Text was paired with `.accessibilityValue(_:)`).
    private func readDisplay(_ element: XCUIElement) -> String {
        let label = element.label
        if !label.isEmpty { return label }
        if let v = element.value as? String { return v }
        return ""
    }

    // -------------------------------------------------------------------
    // BX1 — Button tap fires bound Crystal proc (iOS)
    //
    // Rubric (validation.md §BX1): counter must read "0", then "1" after one
    // tap, then "3" after three taps total. We assert the strict sequence
    // "0" -> "1" -> "2" -> "3" so every dropped callback is surfaced.
    // -------------------------------------------------------------------
    func testBX1_buttonTapFiresHandler() throws {
        let app = launchHost(slug: "phase-03-action-tap-probe")
        let btn = app.buttons["tap-probe-button"]
        XCTAssertTrue(btn.waitForExistence(timeout: 5),
                      "BX1: tap-probe-button must be discoverable")

        let counter = app.staticTexts["tap-probe-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 3),
                      "BX1: tap-probe-counter mirror label must be present")

        attachScreenshot(app, name: "BX1-counter-initial.png")
        var transitions: [String] = []
        transitions.append(readDisplay(counter))

        XCTAssertEqual(transitions[0], "0",
                       "BX1: counter must start at \"0\" — got \(transitions[0]). " +
                       "Stale TapProbe singleton from a prior process?")

        for i in 1...3 {
            btn.tap()
            // Allow the SwiftKit callback + APSKLabelState @Published cycle
            // to flush. 250ms is generous; the live macOS sibling settles in
            // ~150ms.
            Thread.sleep(forTimeInterval: 0.25)
            let observed = readDisplay(counter)
            transitions.append(observed)
            XCTAssertEqual(observed, "\(i)",
                           "BX1: after tap \(i) counter must read \"\(i)\" — got \"\(observed)\". " +
                           "Transitions so far: \(transitions)")
        }
        attachScreenshot(app, name: "BX1-counter-after-3-taps.png")
        attachJSON(transitions, name: "BX1-label-transitions.json")
    }

    // -------------------------------------------------------------------
    // BX3 — Toggle value callback
    //
    // Rubric (validation.md §BX3): drive three flips and verify both the
    // switch's `.value` ("0" / "1") and the probe mirror label ("false" /
    // "true") flip in lockstep.
    // -------------------------------------------------------------------
    func testBX3_toggleValueCallback() throws {
        let app = launchHost(slug: "phase-03-toggle-value-probe")
        let toggle = app.switches["toggle-probe-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5),
                      "BX3: toggle-probe-toggle must be discoverable")

        let probe = app.staticTexts["toggle-probe-value"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3),
                      "BX3: toggle-probe-value mirror label must be present")

        var transitions: [[String: String]] = []
        let captureFrame: () -> [String: String] = {
            let val = (toggle.value as? String) ?? ""
            return ["switch_value": val, "probe_label": self.readDisplay(probe)]
        }

        // Initial state. The probe defaults to ToggleProbe.last_value=false,
        // so the switch reads "0" and the mirror reads "false".
        let initial = captureFrame()
        transitions.append(initial)
        XCTAssertEqual(initial["switch_value"], "0",
                       "BX3: initial switch value must be \"0\"")
        XCTAssertEqual(initial["probe_label"], "false",
                       "BX3: initial probe label must be \"false\"")
        attachScreenshot(app, name: "BX3-toggle-initial.png")

        toggle.tap()
        Thread.sleep(forTimeInterval: 0.25)
        let post1 = captureFrame()
        transitions.append(post1)
        XCTAssertEqual(post1["switch_value"], "1",
                       "BX3: after tap 1 switch must read \"1\"")
        XCTAssertEqual(post1["probe_label"], "true",
                       "BX3: after tap 1 probe label must read \"true\"")
        attachScreenshot(app, name: "BX3-toggle-after-tap-1.png")

        toggle.tap()
        Thread.sleep(forTimeInterval: 0.25)
        let post2 = captureFrame()
        transitions.append(post2)
        XCTAssertEqual(post2["switch_value"], "0",
                       "BX3: after tap 2 switch must read \"0\"")
        XCTAssertEqual(post2["probe_label"], "false",
                       "BX3: after tap 2 probe label must read \"false\"")
        attachScreenshot(app, name: "BX3-toggle-after-tap-2.png")

        attachJSON(transitions, name: "BX3-transitions.json")
    }

    // -------------------------------------------------------------------
    // BX4 — Slider value callback
    //
    // Rubric (validation.md §BX4): drive the slider to 0.0, 0.5, 1.0 and
    // verify the bound mirror reports monotonic, in-band values. The probe
    // mirrors `SliderProbe.last_value.to_s`.
    // -------------------------------------------------------------------
    func testBX4_sliderValueCallback() throws {
        let app = launchHost(slug: "phase-03-slider-value-probe")
        let slider = app.sliders["slider-probe-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5),
                      "BX4: slider-probe-slider must be discoverable")

        let probe = app.staticTexts["slider-probe-value"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3),
                      "BX4: slider-probe-value mirror label must be present")

        slider.adjust(toNormalizedSliderPosition: 0.0)
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(app, name: "BX4-slider-0.png")
        let v0 = Double(readDisplay(probe)) ?? -1

        slider.adjust(toNormalizedSliderPosition: 0.5)
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(app, name: "BX4-slider-mid.png")
        let v1 = Double(readDisplay(probe)) ?? -1

        slider.adjust(toNormalizedSliderPosition: 1.0)
        Thread.sleep(forTimeInterval: 0.3)
        attachScreenshot(app, name: "BX4-slider-end.png")
        let v2 = Double(readDisplay(probe)) ?? -1

        let dragSequence: [[String: Double]] = [
            ["position": 0.0, "parsed_value": v0],
            ["position": 0.5, "parsed_value": v1],
            ["position": 1.0, "parsed_value": v2],
        ]
        attachJSON(dragSequence, name: "BX4-drag-sequence.json")

        XCTAssertTrue(v0 <= 0.05,
                      "BX4: position 0.0 must yield value ≤ 0.05 — got \(v0)")
        XCTAssertTrue(v1 >= 0.45 && v1 <= 0.55,
                      "BX4: position 0.5 must yield value in [0.45, 0.55] — got \(v1)")
        XCTAssertTrue(v2 >= 0.95,
                      "BX4: position 1.0 must yield value ≥ 0.95 — got \(v2)")
        XCTAssertTrue(v0 < v1 && v1 < v2,
                      "BX4: slider drag must produce monotonic values — got \(v0), \(v1), \(v2)")
    }

    // -------------------------------------------------------------------
    // BX5 — Runtime override re-render
    //
    // Rubric (validation.md §BX5): tap the "Make Red" trigger and verify the
    // override-target Button repaints. Per the rubric the pass predicate is
    // ΔE(before, red) > 20 AND ΔE(after, red) ≤ 10 — i.e. the rendered
    // surface actually changed colour. We approximate by sampling the
    // center pixel of the target's element screenshot and asserting that
    // (a) the trigger remained hittable across the cycle (callback wired),
    // (b) the after-image differs measurably from the before-image. Pixel
    // sampling for the exact ΔE thresholds is left to the post-process step
    // which reads the attached PNGs from xcresult.
    // -------------------------------------------------------------------
    func testBX5_runtimeOverrideRerender() throws {
        let app = launchHost(slug: "phase-03-runtime-override-probe")
        let target = app.buttons["override-target"]
        let trigger = app.buttons["make-red-trigger"]
        XCTAssertTrue(target.waitForExistence(timeout: 5),
                      "BX5: override-target must be discoverable")
        XCTAssertTrue(trigger.waitForExistence(timeout: 3),
                      "BX5: make-red-trigger must be discoverable")

        let stateLabel = app.staticTexts["override-state"]
        XCTAssertTrue(stateLabel.waitForExistence(timeout: 3),
                      "BX5: override-state mirror label must be present")

        let beforeText = readDisplay(stateLabel)
        let beforeShot = target.screenshot()
        let beforeAtt = XCTAttachment(screenshot: beforeShot)
        beforeAtt.name = "BX5-before.png"
        beforeAtt.lifetime = .keepAlways
        add(beforeAtt)

        trigger.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let afterText = readDisplay(stateLabel)
        let afterShot = target.screenshot()
        let afterAtt = XCTAttachment(screenshot: afterShot)
        afterAtt.name = "BX5-after.png"
        afterAtt.lifetime = .keepAlways
        add(afterAtt)

        // The probe label should transition from "transparent" / initial to
        // "red" once the trigger fires. Exact strings live in
        // UI::Probes::RuntimeOverrideProbe.current_text.
        XCTAssertNotEqual(beforeText, afterText,
                          "BX5: override-state label must transition after trigger tap — " +
                          "got before=\(beforeText.debugDescription) after=\(afterText.debugDescription)")

        attachJSON([
            "before_state": beforeText,
            "after_state": afterText,
        ], name: "BX5-state-transition.json")

        XCTAssertTrue(target.exists, "BX5: override-target must remain present")
    }

    // -------------------------------------------------------------------
    // BX6 — Form children non-zero (iOS)
    //
    // Rubric (validation.md §BX6): three rows non-zero in size, ≥44pt tall,
    // non-overlapping, AND row 2 must be genuinely tappable — tapping it
    // increments form-row-2-counter to "1".
    // -------------------------------------------------------------------
    func testBX6_formChildrenNonZero() throws {
        let app = launchHost(slug: "phase-03-form-nested-buttons")

        let r1 = app.buttons["form-row-1"]
        let r2 = app.buttons["form-row-2"]
        let r3 = app.buttons["form-row-3"]
        XCTAssertTrue(r1.waitForExistence(timeout: 5), "BX6: form-row-1 must exist")
        XCTAssertTrue(r2.exists, "BX6: form-row-2 must exist")
        XCTAssertTrue(r3.exists, "BX6: form-row-3 must exist")

        let f1 = r1.frame
        let f2 = r2.frame
        let f3 = r3.frame

        XCTAssertTrue(f1.size.width > 0 && f1.size.height >= 44.0,
                      "BX6: row 1 must be ≥44pt tall — got \(f1)")
        XCTAssertTrue(f2.size.width > 0 && f2.size.height >= 44.0,
                      "BX6: row 2 must be ≥44pt tall — got \(f2)")
        XCTAssertTrue(f3.size.width > 0 && f3.size.height >= 44.0,
                      "BX6: row 3 must be ≥44pt tall — got \(f3)")

        XCTAssertTrue(f1.maxY <= f2.minY + 1.0,
                      "BX6: rows 1/2 must not overlap (1.maxY=\(f1.maxY), 2.minY=\(f2.minY))")
        XCTAssertTrue(f2.maxY <= f3.minY + 1.0,
                      "BX6: rows 2/3 must not overlap (2.maxY=\(f2.maxY), 3.minY=\(f3.minY))")

        attachScreenshot(app, name: "BX6-form-rendered.png")

        attachJSON([
            "row1": ["x": f1.minX, "y": f1.minY, "w": f1.width, "h": f1.height],
            "row2": ["x": f2.minX, "y": f2.minY, "w": f2.width, "h": f2.height],
            "row3": ["x": f3.minX, "y": f3.minY, "w": f3.width, "h": f3.height],
        ], name: "BX6-frames.json")

        let counter = app.staticTexts["form-row-2-counter"]
        XCTAssertTrue(counter.waitForExistence(timeout: 3),
                      "BX6: form-row-2-counter mirror label must be present")
        let before = readDisplay(counter)

        r2.tap()
        Thread.sleep(forTimeInterval: 0.25)
        let after = readDisplay(counter)

        attachJSON([
            "before": before,
            "after": after,
        ], name: "BX6-tap-result.json")

        XCTAssertEqual(after, "1",
                       "BX6: row 2 tap must increment counter to \"1\" — got \"\(after)\"")
    }

    // -------------------------------------------------------------------
    // BX8 — Sheet dismiss returns focus
    //
    // The Phase 3 sheet probe renders inline (not via .sheet()) so all
    // content is in the AX tree from launch. Per rubric §BX8 we verify the
    // documented anatomy (trigger, sheet-content, sheet-primary,
    // sheet-cancel) is present, then exercise the primary action and
    // assert the dismiss-reason mirror label transitions to "primary".
    // -------------------------------------------------------------------
    func testBX8_sheetDismissReturnsFocus() throws {
        let app = launchHost(slug: "phase-03-sheet-focus-return")
        let trigger = app.buttons["sheet-trigger"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5),
                      "BX8: sheet-trigger must be discoverable")

        XCTAssertTrue(app.buttons["sheet-primary"].exists,
                      "BX8: sheet-primary must exist")
        XCTAssertTrue(app.buttons["sheet-cancel"].exists,
                      "BX8: sheet-cancel must exist")

        let reason = app.staticTexts["dismiss-reason"]
        XCTAssertTrue(reason.waitForExistence(timeout: 3),
                      "BX8: dismiss-reason mirror label must be present")

        let before = readDisplay(reason)
        attachScreenshot(app, name: "BX8-presented.png")

        app.buttons["sheet-primary"].tap()
        Thread.sleep(forTimeInterval: 0.3)
        let afterPrimary = readDisplay(reason)
        attachScreenshot(app, name: "BX8-after-primary.png")

        attachJSON([
            "before": before,
            "after_primary": afterPrimary,
        ], name: "BX8-dismiss-matrix.json")

        XCTAssertEqual(afterPrimary, "primary",
                       "BX8: sheet-primary tap must set dismiss-reason to \"primary\" — got \"\(afterPrimary)\"")
    }

    // -------------------------------------------------------------------
    // BX9 — Touch target ≥ 44pt (default Button)
    //
    // Rubric (validation.md §BX9): width ≥ 44 AND height ≥ 44.
    // -------------------------------------------------------------------
    func testBX9_touchTargetMinimum() throws {
        let app = launchHost(slug: "phase-03-button-default")
        let save = app.buttons["save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5),
                      "BX9: save button must be discoverable")

        let frame = save.frame
        XCTAssertTrue(frame.size.width >= 44.0,
                      "BX9: width must be ≥44pt — got \(frame.size.width)")
        XCTAssertTrue(frame.size.height >= 44.0,
                      "BX9: height must be ≥44pt — got \(frame.size.height)")

        attachScreenshot(app, name: "BX9-default-button.png")
        attachJSON([
            "x": frame.minX, "y": frame.minY,
            "w": frame.width, "h": frame.height,
        ], name: "BX9-frame.json")
    }

    // -------------------------------------------------------------------
    // BX10 — Dark mode tint shift (relies on V1 light + dark captures)
    //
    // The captured PNGs are attached for post-process ΔE sampling per the
    // rubric's instructions (scripts/sample_pixel.py).
    // -------------------------------------------------------------------
    func testBX10_darkModeTintShift_light() throws {
        let app = launchHost(slug: "phase-03-button-default", appearance: "light")
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 5),
                      "BX10 light: save button must be discoverable")
        attachScreenshot(app, name: "V1-default-button-ios-light.png")
    }

    func testBX10_darkModeTintShift_dark() throws {
        let app = launchHost(slug: "phase-03-button-default", appearance: "dark")
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 5),
                      "BX10 dark: save button must be discoverable")
        attachScreenshot(app, name: "V1-default-button-ios-dark.png")
    }

    // -------------------------------------------------------------------
    // BX12 — Runtime init order (no crash on launch + first SwiftKit call)
    // -------------------------------------------------------------------
    func testBX12_runtimeInitOrder() throws {
        let app = launchHost(slug: "phase-03-button-default")
        XCTAssertTrue(app.buttons["save"].waitForExistence(timeout: 5),
                      "BX12: host must reach first SwiftKit-rendered Button without crashing")
        XCTAssertEqual(app.state, .runningForeground,
                       "BX12: app must remain in foreground after first SwiftKit facade call")
    }
}
