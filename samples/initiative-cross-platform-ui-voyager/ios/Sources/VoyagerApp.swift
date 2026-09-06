import SwiftUI
import UIKit
import AssetPipelineSwiftKit

// SwiftUI @main entry for the Voyager Phase 6.10 navigable demo.
//
// Unlike Cascade (which renders ONE slug from a launch arg), Voyager
// owns a NavigationCoordinator-driven app: the initial slug comes from
// VOYAGER_ROOT_SLUG / -VoyagerRoot launch arg (default "voyager-sign-in"),
// and SwiftUI re-renders whenever the Crystal-side coordinator notifies
// a route change via the C-callable route-changed callback wired in
// VoyagerBridge.

@main
struct VoyagerApp: App {
    @UIApplicationDelegateAdaptor(VoyagerAppDelegate.self) var delegate

    var rootSlug: String {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-VoyagerRoot"), i + 1 < args.count {
            return args[i + 1]
        }
        return ProcessInfo.processInfo.environment["VOYAGER_ROOT_SLUG"] ?? "voyager-sign-in"
    }

    var body: some Scene {
        WindowGroup {
            if let launch = nativeReconcileBenchmarkLaunch {
                NativeReconcileBenchmarkView(launch: launch)
                    .preferredColorScheme(preferredScheme)
            } else {
                ContentView(initialSlug: rootSlug)
                    .preferredColorScheme(preferredScheme)
            }
        }
    }

    /// A strictly opt-in device-harness path. Keeping it at the scene boundary
    /// means ordinary user launches preserve their normal navigation/UI state.
    private var nativeReconcileBenchmarkLaunch: NativeReconcileBenchmarkLaunch? {
        guard let raw = ProcessInfo.processInfo.environment["VOYAGER_NATIVE_RECONCILE_BENCH_FRAMES"],
              let frames = Int(raw), frames > 0 else {
            return nil
        }
        let environment = ProcessInfo.processInfo.environment
        return NativeReconcileBenchmarkLaunch(
            frames: frames,
            commitMode: environment["VOYAGER_NATIVE_RECONCILE_COMMIT_MODE"] ?? "dirty-label-commit",
            launchNonce: environment["VOYAGER_NATIVE_RECONCILE_LAUNCH_NONCE"],
            runID: environment["VOYAGER_NATIVE_RECONCILE_RUN_ID"]
        )
    }

    private var preferredScheme: ColorScheme? {
        // Capture/test runs pin the appearance via VOYAGER_APPEARANCE for
        // deterministic light/dark screenshots. With no override, FOLLOW THE
        // SYSTEM (return nil) — the asset_pipeline facades use dynamic semantic
        // colors (.foregroundStyle(.primary), materials) that adapt to dark
        // automatically, so a real user's Dark Mode is honoured.
        let env = ProcessInfo.processInfo.environment
        switch env["VOYAGER_APPEARANCE"] ?? env["HIG_APPEARANCE"] {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil
        }
    }
}

final class VoyagerAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Phase 12.A — interaction-contracts launch marker. The harness
        // smoke test asserts this marker arrives within 5s of launch,
        // which proves the harness end-to-end (Crystal-side spec +
        // simctl spawn log stream + NSLog bridge).
        // Emission is gated by ENV["APIC_ENABLED"]=="1"; production
        // launches see no overhead.
        InteractionContracts.emit(
            widget: "VoyagerApp",
            event: "launched",
            viewID: nil,
            kv: ["bundle": Bundle.main.bundleIdentifier ?? "unknown"]
        )
        // Start a once-per-second heartbeat marker so interaction
        // contracts can assert "the main runloop is still alive after
        // the tap I just delivered." Covers Codex BLOCKER 3 (crash
        // detection beyond simctl listapps) and CONCERN 9 (hung-but-
        // alive state).
        if InteractionContracts.enabled {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                InteractionContracts.emit(
                    widget: "VoyagerApp",
                    event: "heartbeat",
                    viewID: nil,
                    kv: ["tick": "\(Int(Date().timeIntervalSince1970))"]
                )
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let cfg = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        cfg.delegateClass = VoyagerSceneDelegate.self
        return cfg
    }
}

final class VoyagerSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let env = ProcessInfo.processInfo.environment
        // Only PIN the window appearance when a capture/test explicitly sets it;
        // otherwise leave .unspecified so the window follows the system (real
        // users' Dark Mode is honoured).
        let pinned = env["VOYAGER_APPEARANCE"] ?? env["HIG_APPEARANCE"]
        let style: UIUserInterfaceStyle
        switch pinned {
        case "dark":  style = .dark
        case "light": style = .light
        default:      style = .unspecified
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            for w in ws.windows {
                w.overrideUserInterfaceStyle = style
            }
        }
    }
}
