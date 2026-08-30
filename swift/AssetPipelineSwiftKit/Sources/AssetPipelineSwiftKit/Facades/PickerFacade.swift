// PickerFacade — SwiftUI Picker(...) with configurable picker style.

import SwiftUI
import Foundation
#if os(iOS)
import UIKit
#endif

// watchOS: ENABLED (Phase D Bucket-2 P1 port, 2026-06-02). SwiftUI `Picker` is
// watch-native; `.wheel`/`.inline`/`.navigationLink` styles are valid on watchOS,
// but `.menu` (MenuPickerStyle) and `.segmented` (SegmentedPickerStyle) are both
// `@available(watchOS, unavailable)` and are gated off there (unknown keys fall
// through to the default wheel-style picker). See watch-facade-bucket-audit.md.
@objc(APSKPickerFacade)
public class PickerFacade: NSObject {
    @objc public static func makePicker(
        label: String,
        options: [String],
        selectedIndex: Int,
        overrides: PickerOverrides,
        actionToken: UInt64
    ) -> APSKPlatformView {
        let storage = IntStorage(initial: selectedIndex, token: actionToken)

        var content: AnyView = AnyView(
            Picker(label, selection: storage.binding) {
                ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                    Text(opt).tag(idx)
                }
            }
        )

        switch overrides.pickerStyle {
        #if os(iOS)
        case "input":
            content = AnyView(InputPicker(storage: storage, label: label, options: options,
                                          color: overrides.foregroundColor).frame(height: 28))
        #endif
        #if !os(watchOS)
        // MenuPickerStyle + SegmentedPickerStyle are @available(watchOS, unavailable).
        case "menu":
            content = AnyView(content.pickerStyle(.menu))
        case "segmented":
            content = AnyView(content.pickerStyle(.segmented))
        #endif
        case "wheel":
            #if canImport(UIKit)
            content = AnyView(content.pickerStyle(.wheel))
            #endif
        case "inline":
            content = AnyView(content.pickerStyle(.inline))
        case "navigationlink":
            #if canImport(UIKit)
            content = AnyView(content.pickerStyle(.navigationLink))
            #endif
        default: break
        }

        content = CommonModifiers.apply(content, overrides: overrides)
        return HostingHelpers.host(IntHost(storage: storage, content: content))
    }
}

#if os(iOS)
/// The selection surface is a field; its wheel belongs in the input area,
/// never in the scrolling form. Selection shares the ordinary native field
/// navigation order, including City -> State -> ZIP.
private struct InputPicker: UIViewRepresentable {
    @ObservedObject var storage: IntStorage
    let label: String
    let options: [String]
    let color: UIColor?

    func makeCoordinator() -> Coordinator { Coordinator(storage: storage, options: options) }
    func makeUIView(context: Context) -> UITextField {
        let field = SelectionField()
        let coordinator = context.coordinator
        coordinator.field = field
        field.delegate = coordinator
        field.tintColor = .clear
        field.textColor = color ?? .label
        field.font = .systemFont(ofSize: 17)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let wheel = UIPickerView()
        wheel.dataSource = coordinator
        wheel.delegate = coordinator
        wheel.accessibilityIdentifier = "keyboard.picker"
        field.inputView = wheel
        let arrow = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrow.tintColor = color ?? .secondaryLabel
        field.rightView = arrow
        field.rightViewMode = .always
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let previous = UIBarButtonItem(image: UIImage(systemName: "chevron.up"), primaryAction: UIAction { [weak field] _ in
            if let field { _ = NativeTextInputFocusNavigator.move(from: field, by: -1) }
        })
        previous.accessibilityIdentifier = "keyboard.previous"
        previous.accessibilityLabel = "Previous field"
        let next = UIBarButtonItem(image: UIImage(systemName: "chevron.down"), primaryAction: UIAction { [weak field] _ in
            if let field { _ = NativeTextInputFocusNavigator.move(from: field, by: 1) }
        })
        next.accessibilityIdentifier = "keyboard.next"
        next.accessibilityLabel = "Next field"
        let done = UIBarButtonItem(title: "Done", primaryAction: UIAction { [weak field] _ in field?.resignFirstResponder() })
        done.accessibilityIdentifier = "keyboard.done"
        toolbar.items = [previous, next, UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), done]
        field.inputAccessoryView = toolbar
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.storage = storage
        context.coordinator.options = options
        field.accessibilityLabel = label
        let index = storage.binding.wrappedValue
        field.text = options.indices.contains(index) ? options[index] : ""
        if let wheel = field.inputView as? UIPickerView, options.indices.contains(index) {
            wheel.selectRow(index, inComponent: 0, animated: false)
        }
    }
    final class SelectionField: UITextField {
        override func caretRect(for position: UITextPosition) -> CGRect { .zero }
        override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    }
    final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
        var storage: IntStorage
        var options: [String]
        weak var field: UITextField?
        init(storage: IntStorage, options: [String]) { self.storage = storage; self.options = options }
        func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
        func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { options.count }
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { options[row] }
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            field?.text = options[row]
            storage.binding.wrappedValue = row
        }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { false }
    }
}
#endif
