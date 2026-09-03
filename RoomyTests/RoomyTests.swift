import XCTest
@testable import Roomy

final class SessionStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoomyTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        SessionStore.directoryOverride = tempDir
    }

    override func tearDown() {
        SessionStore.directoryOverride = nil
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testSnapshotRoundTrip() throws {
        let snapshot = ModeSnapshot(
            width: 1470,
            height: 956,
            pixelWidth: 2940,
            pixelHeight: 1912,
            refreshRate: 60
        )
        SessionStore.save(snapshot)
        XCTAssertTrue(SessionStore.hasPendingSession)
        XCTAssertEqual(SessionStore.load(), snapshot)
        SessionStore.clear()
        XCTAssertNil(SessionStore.load())
        XCTAssertFalse(SessionStore.hasPendingSession)
    }
}

@MainActor
final class StatusItemTests: XCTestCase {
    func testInstallsVisibleStatusItem() {
        let delegate = AppDelegate()
        delegate.installStatusItem()

        guard let item = delegate.statusItem else {
            XCTFail("AppKit NSStatusItem must be installed. SwiftUI MenuBarExtra stays invisible on macOS 26.")
            return
        }

        XCTAssertTrue(item.isVisible, "Status item must be visible so the accessory app has an entry point")
        XCTAssertNotNil(item.menu)
        XCTAssertNotNil(item.button?.image)
        XCTAssertEqual(item.autosaveName, "Roomy")
        XCTAssertGreaterThanOrEqual(item.menu?.items.count ?? 0, 5)
    }
}

final class DisplayModeSortTests: XCTestCase {
    func testEqualWidthTallerModeSortsAfter() {
        XCTAssertTrue(
            DisplayModeSort.byIncreasingSpace(width: 1710, height: 1068, width: 1710, height: 1112)
        )
        XCTAssertFalse(
            DisplayModeSort.byIncreasingSpace(width: 1710, height: 1112, width: 1710, height: 1068)
        )
    }

    func testWiderModeSortsAfterRegardlessOfHeight() {
        XCTAssertTrue(
            DisplayModeSort.byIncreasingSpace(width: 1470, height: 956, width: 1710, height: 1068)
        )
    }
}
