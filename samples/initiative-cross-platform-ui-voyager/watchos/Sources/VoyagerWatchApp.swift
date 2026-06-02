import SwiftUI

// Voyager watchOS demo entry point. A single-target SwiftUI watch app (watchOS 10+,
// no separate WatchKit extension). See ContentView for the facade render harness.
@main
struct VoyagerWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
