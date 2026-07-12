#!/usr/bin/env swift
import CoreGraphics
import Foundation

func modeTuple(_ mode: CGDisplayMode) -> (Int, Int, Int, Int, Double) {
    (
        Int(mode.width),
        Int(mode.height),
        Int(mode.pixelWidth),
        Int(mode.pixelHeight),
        mode.refreshRate
    )
}

func describe(_ mode: CGDisplayMode) -> String {
    let t = modeTuple(mode)
    return "\(t.0)×\(t.1) (\(t.2)×\(t.3)px @ \(t.4)Hz)"
}

let displayID = CGMainDisplayID()
guard let original = CGDisplayCopyDisplayMode(displayID) else {
    fputs("FAIL: could not read current mode\n", stderr)
    exit(1)
}

let options = [kCGDisplayShowDuplicateLowResolutionModes: kCFBooleanTrue] as CFDictionary
guard let rawModes = CGDisplayCopyAllDisplayModes(displayID, options) as? [CGDisplayMode] else {
    fputs("FAIL: could not enumerate modes\n", stderr)
    exit(1)
}

var unique: [String: CGDisplayMode] = [:]
for mode in rawModes where mode.isUsableForDesktopGUI() {
    let key = "\(mode.width)x\(mode.height)"
    if let existing = unique[key] {
        let existingHiDPI = existing.pixelWidth >= existing.width * 2
        let candidateHiDPI = mode.pixelWidth >= mode.width * 2
        if candidateHiDPI && !existingHiDPI {
            unique[key] = mode
        }
    } else {
        unique[key] = mode
    }
}

let modes = unique.values.sorted { $0.width < $1.width }
print("Current: \(describe(original))")
print("Usable modes: \(modes.count)")
for mode in modes {
    print("  - \(describe(mode))")
}

guard modes.count >= 2 else {
    print("SKIP: need at least 2 modes to smoke-test apply/restore")
    exit(0)
}

let originalTuple = modeTuple(original)
guard let alternate = modes.first(where: {
    modeTuple($0) != originalTuple
}) else {
    print("SKIP: no alternate mode found")
    exit(0)
}

print("Applying alternate: \(describe(alternate))")
var result = CGDisplaySetDisplayMode(displayID, alternate, nil)
guard result == .success else {
    fputs("FAIL: apply alternate failed (\(result.rawValue))\n", stderr)
    exit(1)
}

Thread.sleep(forTimeInterval: 0.4)

guard let mid = CGDisplayCopyDisplayMode(displayID), modeTuple(mid).0 == Int(alternate.width) else {
    fputs("FAIL: alternate mode did not stick\n", stderr)
    _ = CGDisplaySetDisplayMode(displayID, original, nil)
    exit(1)
}

print("Restoring original: \(describe(original))")
result = CGDisplaySetDisplayMode(displayID, original, nil)
guard result == .success else {
    fputs("FAIL: restore failed (\(result.rawValue))\n", stderr)
    exit(1)
}

Thread.sleep(forTimeInterval: 0.4)

guard let after = CGDisplayCopyDisplayMode(displayID), modeTuple(after).0 == originalTuple.0, modeTuple(after).1 == originalTuple.1 else {
    fputs("FAIL: original mode not restored\n", stderr)
    exit(1)
}

// Session JSON round-trip
struct ModeSnapshot: Codable, Equatable {
    var width: Int
    var height: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var refreshRate: Double
}

let snapshot = ModeSnapshot(
    width: originalTuple.0,
    height: originalTuple.1,
    pixelWidth: originalTuple.2,
    pixelHeight: originalTuple.3,
    refreshRate: originalTuple.4
)
let dir = FileManager.default.temporaryDirectory.appendingPathComponent("RoomySmoke", isDirectory: true)
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let url = dir.appendingPathComponent("session.json")
let data = try JSONEncoder().encode(snapshot)
try data.write(to: url)
let loaded = try JSONDecoder().decode(ModeSnapshot.self, from: Data(contentsOf: url))
guard loaded == snapshot else {
    fputs("FAIL: session round-trip mismatch\n", stderr)
    exit(1)
}
try? FileManager.default.removeItem(at: dir)

print("OK: apply/restore + session round-trip")
