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

    /// True if the mode uses Retina (2× or better) rendering.
    /// False = native 1:1 pixels — more space, but smaller and less crisp text.
    var isHiDPI: Bool { pixelWidth >= width * 2 }

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
        // Native modes: just the resolution. The menu section header explains the tradeoff.
        if !mode.isHiDPI {
            return mode.sizeLabel
        }

        let hiDPI = availableModes.filter { $0.isHiDPI }.sorted { $0.width < $1.width }
        guard hiDPI.count > 1, let index = hiDPI.firstIndex(of: mode) else {
            return "Default — \(mode.sizeLabel)"
        }

        if index == hiDPI.count - 1 {
            return "Roomy — \(mode.sizeLabel)"
        }
        if index == hiDPI.count / 2 {
            return "Default — \(mode.sizeLabel)"
        }
        return mode.sizeLabel
    }

    func apply(_ mode: DisplayModeInfo) {
        let result = applyMode(mode.mode)
        if result == .success {
            refresh()
            hasUnrestoredSession = currentMode?.snapshot != originalSnapshot
        }
    }

    private func applyMode(_ mode: CGDisplayMode) -> CGError {
        var config: CGDisplayConfigRef?
        if CGBeginDisplayConfiguration(&config) == .success, let config {
            CGConfigureDisplayWithDisplayMode(config, displayID, mode, nil)
            let complete = CGCompleteDisplayConfiguration(config, .forSession)
            if complete == .success {
                return .success
            }
        }
        return CGDisplaySetDisplayMode(displayID, mode, nil)
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
            // Keep both HiDPI (Retina) and native (1:1 pixel) modes.
            // Use sizeLabel + HiDPI flag as the dedup key so a native and a HiDPI
            // mode at the same logical size are both kept.
            let key = "\(info.sizeLabel):\(info.isHiDPI)"
            if unique[key] == nil {
                unique[key] = info
            }
        }

        // HiDPI modes first (sorted by width ascending), then native modes.
        return unique.values.sorted {
            if $0.isHiDPI != $1.isHiDPI { return $0.isHiDPI }
            return $0.width < $1.width
        }
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
