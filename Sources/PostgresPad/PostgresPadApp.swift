import AppKit
import SwiftUI

@main
struct PostgresPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ServerStore()

    var body: some Scene {
        WindowGroup("PostgresPad") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
    }
}

/// Makes the app behave like a regular foreground app even when launched
/// from the command line via `swift run` (no app bundle).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
