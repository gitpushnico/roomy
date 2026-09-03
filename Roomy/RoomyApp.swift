import AppKit

@main
enum RoomyMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let displayController = DisplayController()
    private(set) var statusItem: NSStatusItem?
    private var fallbackWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installStatusItem(autosaveName: "Roomy")
        scheduleVisibilityCheck(attempt: 1)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if hasUsableStatusItem {
            statusItem?.button?.performClick(nil)
        } else {
            showFallbackWindow()
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Must run synchronously — async work may not finish before exit.
        displayController.handleWillTerminate()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        displayController.refresh()
        rebuild(menu)
    }

    func installStatusItem(autosaveName: String = "Roomy") {
        UserDefaults.standard.set(true, forKey: "NSStatusItem Visible \(autosaveName)")
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(autosaveName)")

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "rectangle.expand.diagonal",
                accessibilityDescription: "Roomy"
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = "Roomy"
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        rebuild(menu)

        // Content first, then name + visibility. Reversed order leaves a 0-height
        // window at (0,0) on macOS 26 because Control Center restores a broken frame.
        item.autosaveName = autosaveName
        item.isVisible = true
        statusItem = item
    }

    var hasUsableStatusItem: Bool {
        guard let item = statusItem, item.isVisible, let window = item.button?.window else {
            return false
        }
        return window.frame.height >= 10 && window.frame.origin.y > 20
    }

    private func scheduleVisibilityCheck(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if self.hasUsableStatusItem {
                self.hideFallbackWindow()
                return
            }
            if attempt == 3, let existing = self.statusItem {
                NSStatusBar.system.removeStatusItem(existing)
                self.statusItem = nil
                self.installStatusItem(autosaveName: "RoomyMenu")
            }
            if attempt < 6 {
                self.scheduleVisibilityCheck(attempt: attempt + 1)
                return
            }
            self.showFallbackWindow()
        }
    }

    private func hideFallbackWindow() {
        fallbackWindow?.close()
        fallbackWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func showFallbackWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let fallbackWindow {
            fallbackWindow.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Roomy"
        window.isReleasedWhenClosed = false
        window.center()

        let hint = NSTextField(wrappingLabelWithString: "The menu bar icon is hidden. Enable Roomy in System Settings → Menu Bar, or use the buttons below.")
        hint.preferredMaxLayoutWidth = 280

        let restore = NSButton(title: "Restore original", target: self, action: #selector(restoreOriginal))
        restore.bezelStyle = .rounded
        restore.isEnabled = displayController.canRestoreOriginal || displayController.hasUnrestoredSession

        let quit = NSButton(title: "Quit Roomy", target: self, action: #selector(quitAndRestore))
        quit.bezelStyle = .rounded

        let stack = NSStackView(views: [hint, restore, quit])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            content.widthAnchor.constraint(equalToConstant: 320),
        ])

        window.contentView = content
        window.makeKeyAndOrderFront(nil)
        fallbackWindow = window
    }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        let title = NSMenuItem(title: "Roomy", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        menu.addItem(.separator())

        let restore = NSMenuItem(
            title: "Restore original",
            action: #selector(restoreOriginal),
            keyEquivalent: ""
        )
        restore.target = self
        restore.isEnabled = displayController.canRestoreOriginal || displayController.hasUnrestoredSession
        menu.addItem(restore)

        menu.addItem(.separator())

        let hiDPIModes = displayController.availableModes.filter { $0.isHiDPI }
        let nativeModes = displayController.availableModes.filter { !$0.isHiDPI }

        for mode in hiDPIModes {
            let item = NSMenuItem(
                title: displayController.label(for: mode),
                action: #selector(applyMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.id
            item.state = displayController.currentMode == mode ? .on : .off
            menu.addItem(item)
        }

        if !nativeModes.isEmpty {
            menu.addItem(.separator())

            let header = NSMenuItem(title: "More space, smaller text", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for mode in nativeModes {
                let item = NSMenuItem(
                    title: displayController.label(for: mode),
                    action: #selector(applyMode(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = mode.id
                item.state = displayController.currentMode == mode ? .on : .off
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Roomy",
            action: #selector(quitAndRestore),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func applyMode(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let mode = displayController.availableModes.first(where: { $0.id == id })
        else { return }
        displayController.apply(mode)
    }

    @objc private func restoreOriginal() {
        displayController.restoreOriginal()
    }

    @objc private func quitAndRestore() {
        displayController.quitAndRestore()
    }
}
