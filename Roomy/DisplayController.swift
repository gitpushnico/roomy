import AppKit
import CoreGraphics
import Foundation

struct DisplayModeInfo: Identifiable, Hashable {
    let id: String
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    let mode: CGDisplayMode

    var snapshot: ModeSnapshot {
        ModeSnapshot(
            width: width,
            height: height,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            refreshRate: refreshRate
        )
    }

    var sizeLabel: String {
        "\(width)×\(height)"
    }

    static func == (lhs: DisplayModeInfo, rhs: DisplayModeInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
final class DisplayController: ObservableObject {
    @Published private(set) var availableModes: [DisplayModeInfo] = []
    @Published private(set) var currentMode: DisplayModeInfo?
    @Published private(set) var originalSnapshot: ModeSnapshot?
    @Published private(set) var hasUnrestoredSession: Bool = false

    private let displayID: CGDirectDisplayID

    init(displayID: CGDirectDisplayID = CGMainDisplayID()) {
        self.displayID = displayID
        bootstrapSession()
        refresh()
    }

    var canRestoreOriginal: Bool {
        guard let originalSnapshot else { return false }
        guard let currentMode else { return true }
        return currentMode.snapshot != originalSnapshot
    }

    func label(for mode: DisplayModeInfo) -> String {
        let sorted = availableModes.sorted { $0.width < $1.width }
        guard sorted.count > 1, let index = sorted.firstIndex(of: mode) else {
            return "Default — \(mode.sizeLabel)"
        }

        if index == 0 {
            return "Larger Text — \(mode.sizeLabel)"
        }
        if index == sorted.count - 1 {
            return "More Space — \(mode.sizeLabel)"
        }
        if index == sorted.count / 2 {
            return "Default — \(mode.sizeLabel)"
        }
        return mode.sizeLabel
    }

    func apply(_ mode: DisplayModeInfo) {
        let result = CGDisplaySetDisplayMode(displayID, mode.mode, nil)
        if result == .success {
            currentMode = mode
            hasUnrestoredSession = currentMode?.snapshot != originalSnapshot
        }
    }

    func restoreOriginal() {
        guard let originalSnapshot else { return }
        guard let match = findMode(matching: originalSnapshot) else { return }
        apply(match)
        hasUnrestoredSession = false
    }

    func quitAndRestore() {
        restoreOriginal()
        SessionStore.clear()
        NSApplication.shared.terminate(nil)
    }

    func handleWillTerminate() {
        restoreOriginal()
        SessionStore.clear()
    }

    func refresh() {
        availableModes = enumerateModes()
        currentMode = currentDisplayMode()
    }

    private func bootstrapSession() {
        if let existing = SessionStore.load() {
            originalSnapshot = existing
            hasUnrestoredSession = true
            return
        }

        guard let current = currentDisplayMode() else { return }
        originalSnapshot = current.snapshot
        SessionStore.save(current.snapshot)
        hasUnrestoredSession = false
    }

    private func currentDisplayMode() -> DisplayModeInfo? {
        guard let mode = CGDisplayCopyDisplayMode(displayID) else { return nil }
        return makeInfo(from: mode)
    }

    private func enumerateModes() -> [DisplayModeInfo] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
        guard let modeList = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
            return []
        }

        var unique: [String: DisplayModeInfo] = [:]
        for mode in modeList {
            guard mode.isUsableForDesktopGUI() else { continue }
            let info = makeInfo(from: mode)
            // Keep Retina-style scaled modes (matches System Settings “Looks like”).
            guard info.pixelWidth >= info.width * 2 else { continue }
            if unique[info.sizeLabel] == nil {
                unique[info.sizeLabel] = info
            }
        }

        return unique.values.sorted { $0.width < $1.width }
    }

    private func findMode(matching snapshot: ModeSnapshot) -> DisplayModeInfo? {
        let modes = enumerateModes()
        if let exact = modes.first(where: { $0.snapshot == snapshot }) {
            return exact
        }
        return modes.first {
            $0.width == snapshot.width && $0.height == snapshot.height
        }
    }

    private func makeInfo(from mode: CGDisplayMode) -> DisplayModeInfo {
        let width = Int(mode.width)
        let height = Int(mode.height)
        let pixelWidth = Int(mode.pixelWidth)
        let pixelHeight = Int(mode.pixelHeight)
        let refreshRate = mode.refreshRate
        let id = "\(width)x\(height)@\(pixelWidth)x\(pixelHeight)@\(refreshRate)"
        return DisplayModeInfo(
            id: id,
            width: width,
            height: height,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            refreshRate: refreshRate,
            mode: mode
        )
    }
}
