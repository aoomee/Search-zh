import Combine
import XCTest
@testable import Search

/// Idea 781: on a Mac whose helper macOS stops as it starts, Connect… pressed
/// again and again must leave the Settings row as it is.
@MainActor
final class ApplePasswordsRowTests: XCTestCase {
    private func titles(of apple: ApplePasswords) -> (AnyCancellable, () -> [String]) {
        var seen: [String] = []
        let watch = Publishers.CombineLatest3(apple.$state, apple.$trouble, apple.$connecting).sink {
            seen.append(ApplePasswords.title(state: $0, trouble: $1, connecting: $2))
        }
        return (watch, { seen })
    }

    func testRepeatedConnectOnAHelperKilledAtLaunchKeepsTheRowStill() async {
        let apple = ApplePasswords(makeLink: { KilledHelper() }, entitled: false)
        await apple.connect()
        let first = apple.trouble
        XCTAssertEqual(first, "Apple 密码辅助程序无法为当前版本的 Search 运行")
        XCTAssertFalse(apple.refused, "a copy without the entitlement may be tried again")
        let (watch, seen) = titles(of: apple)
        for _ in 0..<5 { await apple.connect() }
        try? await Task.sleep(nanoseconds: 50_000_000)
        watch.cancel()
        XCTAssertEqual(Set(seen()), [first!], "row titles seen: \(seen())")
    }

    func testAnEntitledCopyStoppedAtLaunchSaysSoAndIsNotRetried() async {
        var made = 0
        let apple = ApplePasswords(makeLink: { made += 1; return KilledHelper() }, entitled: true)
        await apple.connect()
        XCTAssertTrue(apple.refused)
        XCTAssertEqual(apple.state, .idle)
        XCTAssertEqual(apple.trouble, "此版本的 macOS 不允许 Search 使用 Apple 密码辅助程序")
        await apple.connect()
        XCTAssertEqual(made, 1)
    }

    func testASlowStartSaysConnectingAndAWorkingHelperIsNotRefused() async {
        let slow = SlowHelper()
        let apple = ApplePasswords(makeLink: { slow }, entitled: true)
        let (watch, seen) = titles(of: apple)
        Task { await apple.connect() }
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        XCTAssertEqual(apple.state, .starting)
        XCTAssertTrue(apple.connecting)
        XCTAssertEqual(seen().last, "正在连接…")
        slow.onEnd?()
        try? await Task.sleep(nanoseconds: 50_000_000)
        watch.cancel()
        XCTAssertFalse(apple.refused, "a helper that ran a while wasn't stopped by its launch constraint")
        XCTAssertFalse(apple.connecting)
    }

    /// Over a real pipe: a program killed by signal 9 as it starts, as macOS
    /// kills Apple's helper for a parent its launch constraint doesn't admit.
    @available(macOS 15.4, *)
    func testOverAPipeAProgramKilledAtLaunchIsRefusedQuietly() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("apw-killed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let program = folder.appendingPathComponent("helper")
        try "#!/bin/sh\nkill -9 $$\n".write(to: program, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)
        let apple = ApplePasswords(makeLink: { HelperLink(program: program) }, entitled: true)
        let (watch, seen) = titles(of: apple)
        await apple.connect()
        watch.cancel()
        XCTAssertTrue(apple.refused)
        XCTAssertFalse(seen().contains("正在连接…"), "row titles seen: \(seen())")
        XCTAssertEqual(apple.trouble, "此版本的 macOS 不允许 Search 使用 Apple 密码辅助程序")
    }
}

/// A helper macOS stops the instant it starts (a launch constraint): the
/// first message still goes into the pipe, then its output closes.
@MainActor
private final class KilledHelper: AppleLink {
    var onMessage: (([String: Any]) -> Void)?
    var onEnd: (() -> Void)?
    func start() throws { DispatchQueue.main.async { self.onEnd?() } }
    func send(_ message: [String: Any]) throws {}
    func stop() {}
}

/// A helper that runs but never answers.
@MainActor
private final class SlowHelper: AppleLink {
    var onMessage: (([String: Any]) -> Void)?
    var onEnd: (() -> Void)?
    func start() throws {}
    func send(_ message: [String: Any]) throws {}
    func stop() {}
}
