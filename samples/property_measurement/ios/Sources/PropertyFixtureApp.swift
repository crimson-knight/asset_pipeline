import UIKit
import MapKit

private weak var fixture: PropertyFixtureController?

@_cdecl("ap_property_fixture_saved")
func saved(_ raw: UnsafePointer<CChar>) {
    let json = String(cString: raw)
    UserDefaults.standard.set(json, forKey: "saved-outline")
    UserDefaults.standard.synchronize()
    fixture?.receipt.text = "Outline saved on this device"
    fixture?.receipt.accessibilityValue = json
}

@_cdecl("ap_property_fixture_draft")
func draft(_ raw: UnsafePointer<CChar>) {
    fixture?.recordDraft(String(cString: raw))
}

@main
final class PropertyFixtureApp: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Exactly once, before any other Crystal export or String allocation.
        guard ap_property_fixture_runtime_init() == 1 else {
            fatalError("Property fixture runtime initialization failed")
        }
        if ProcessInfo.processInfo.arguments.contains("--fresh-fixture") {
            UserDefaults.standard.removeObject(forKey: "saved-outline")
        }
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = PropertyFixtureController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class PropertyFixtureController: UIViewController {
    let receipt = UILabel()
    var draft = ""
    private var editor: UIView?
    private let holder = UIView()
    private var refreshCount = 0
    func recordDraft(_ raw: String) {
        draft = raw
        if ProcessInfo.processInfo.arguments.contains("--refresh-on-draft") { render() }
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        fixture = self
        view.backgroundColor = .systemBackground
        view.tintColor = .link
        if ProcessInfo.processInfo.arguments.contains("--dark") { overrideUserInterfaceStyle = .dark }
        let refresh = UIButton(type: .system)
        refresh.setTitle("Refresh surrounding screen", for: .normal)
        refresh.accessibilityIdentifier = "fixture-refresh"
        refresh.addTarget(self, action: #selector(render), for: .touchUpInside)
        refresh.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        receipt.font = .preferredFont(forTextStyle: .footnote)
        receipt.numberOfLines = 0
        receipt.textColor = .label
        receipt.accessibilityIdentifier = "fixture-receipt"
        if let json = UserDefaults.standard.string(forKey: "saved-outline") {
            receipt.text = "Saved outline restored from this device"
            receipt.accessibilityValue = json
        } else { receipt.text = "Draw an approximate service area" }
        let stack = UIStackView(arrangedSubviews: [refresh, receipt, holder])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        render()
    }

    @objc private func render() {
        let saved = UserDefaults.standard.string(forKey: "saved-outline") ?? ""
        let raw = saved.withCString { ap_property_fixture_render($0)! }
        let next = Unmanaged<UIView>.fromOpaque(raw).takeUnretainedValue()
        let previous = editor
        if previous !== next {
            previous?.removeFromSuperview()
            holder.addSubview(next)
            next.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                next.leadingAnchor.constraint(equalTo: holder.leadingAnchor), next.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                next.topAnchor.constraint(equalTo: holder.topAnchor), next.bottomAnchor.constraint(equalTo: holder.bottomAnchor),
            ])
        }
        editor = next
        refreshCount += 1
        // Fixture-only inspectable receipt proves identity, camera and draft
        // retention; no production control is added to the reusable primitive.
        if refreshCount > 1 {
            let map = descendants(next).compactMap { $0 as? MKMapView }.first
            let overlayIDs = map?.overlays.map { String(describing: ObjectIdentifier($0 as AnyObject)) }.sorted().joined(separator: ",") ?? ""
            receipt.accessibilityValue = "same-native-view=\(previous === next);camera=\(map?.centerCoordinate.latitude ?? 0),\(map?.centerCoordinate.longitude ?? 0);overlays=\(overlayIDs);draft=\(draft)"
        }
    }
    private func descendants(_ root: UIView) -> [UIView] { [root] + root.subviews.flatMap(descendants) }
}
