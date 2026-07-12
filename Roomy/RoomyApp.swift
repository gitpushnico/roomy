import AppKit
import SwiftUI

@main
struct RoomyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Roomy", systemImage: "rectangle.expand.diagonal") {
            RoomyMenu(controller: appDelegate.displayController)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct RoomyMenu: View {
    @ObservedObject var controller: DisplayController

    var body: some View {
        Text("Roomy")
        Text("Big Desk Energy")

        Divider()

        Button("Restore original") {
            controller.restoreOriginal()
        }
        .disabled(!controller.canRestoreOriginal && !controller.hasUnrestoredSession)

        Divider()

        ForEach(controller.availableModes) { mode in
            Button {
                controller.apply(mode)
            } label: {
                if controller.currentMode == mode {
                    Text("✓ \(controller.label(for: mode))")
                } else {
                    Text(controller.label(for: mode))
                }
            }
        }

        Divider()

        Button("Quit Roomy") {
            controller.quitAndRestore()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let displayController = DisplayController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Must run synchronously — async work may not finish before exit.
        displayController.handleWillTerminate()
    }
}
