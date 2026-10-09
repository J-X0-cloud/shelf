import XCTest
@testable import ShelfKit

final class FolderChangeDetectorTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    func testOnlyNewFinishedFilesAreReported() {
        let existing = Fixtures.file("old.pdf")
        var detector = FolderChangeDetector(existing: [existing])

        let reported = detector.update(with: [
            existing,
            Fixtures.file("menu-proof.pdf"),
            Fixtures.file("video.mov.crdownload"),
            Fixtures.file("archive.zip.download"),
            Fixtures.file(".DS_Store"),
            Fixtures.file("~$contract.docx"),
        ], at: start)

        XCTAssertEqual(reported.map(\.lastPathComponent), ["menu-proof.pdf"])
    }

    func testAFinishedDownloadIsReportedUnderItsFinalName() {
        var detector = FolderChangeDetector(existing: [])
        XCTAssertTrue(detector.update(with: [Fixtures.file("cup-shoot-01.jpg.crdownload")], at: start).isEmpty)
        XCTAssertEqual(
            detector.update(with: [Fixtures.file("cup-shoot-01.jpg")], at: start.addingTimeInterval(2)).map(\.lastPathComponent),
            ["cup-shoot-01.jpg"]
        )
    }

    func testICloudCanReportTheSameFileOnlyOnce() {
        var detector = FolderChangeDetector(existing: [])
        let file = Fixtures.file("contract.pages", in: "/Users/test/Library/Mobile Documents/com~apple~CloudDocs")

        XCTAssertEqual(detector.update(with: [file], at: start).count, 1)
        // iCloud briefly swaps the file for its placeholder and back while it finishes.
        XCTAssertTrue(detector.update(with: [Fixtures.file(".contract.pages.icloud")], at: start.addingTimeInterval(1)).isEmpty)
        XCTAssertTrue(detector.update(with: [file], at: start.addingTimeInterval(3)).isEmpty)
        // Long after, a genuinely new copy with the same name counts again.
        _ = detector.update(with: [], at: start.addingTimeInterval(60))
        XCTAssertEqual(detector.update(with: [file], at: start.addingTimeInterval(120)).count, 1)
    }
}

final class DockStackTests: XCTestCase {
    func testPlanSkipsLinksAndDisambiguatesNames() {
        let a = Fixtures.item("Brief.pdf", in: "/Users/test/Desktop")
        let b = Fixtures.item("brief.pdf", in: "/Users/test/Clients")
        let link = ShelfItem(url: URL(string: "https://shelfapp.com")!)

        let plan = DockStackPlan(items: [a, link, b])

        XCTAssertEqual(plan.links.count, 2)
        XCTAssertEqual(plan.links[0].name, "Brief.pdf")
        XCTAssertEqual(plan.links[1].name, "\(b.id.uuidString.prefix(4)) brief.pdf")
    }

    func testFolderMirrorsThePlanAndLeavesOtherFilesAlone() throws {
        let root = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let stack = DockStackFolder(folder: root.appendingPathComponent("Dock Stack"))
        let note = root.appendingPathComponent("notes.txt")
        let brief = root.appendingPathComponent("Brief.pdf")
        try Data().write(to: note)
        try Data().write(to: brief)

        try stack.apply(DockStackPlan(items: [ShelfItem(url: note), ShelfItem(url: brief)]))
        XCTAssertEqual(stack.currentLinks(), ["notes.txt": note.path, "Brief.pdf": brief.path])

        try Data("keep".utf8).write(to: stack.folder.appendingPathComponent("README"))
        try stack.apply(DockStackPlan(items: [ShelfItem(url: brief)]))

        XCTAssertEqual(stack.currentLinks(), ["Brief.pdf": brief.path])
        XCTAssertTrue(FileManager.default.fileExists(atPath: stack.folder.appendingPathComponent("README").path))
    }
}

final class LicensingTests: XCTestCase {
    func testKeysAreNormalisedAndValidated() {
        XCTAssertEqual(LicenseKey("  shelf-7f3a2c9e-41b8-4d\n")?.rawValue, "SHELF-7F3A2C9E-41B8-4D")
        XCTAssertNil(LicenseKey("short"))
        XCTAssertNil(LicenseKey("SHELF 7F3A 2C9E"))
        XCTAssertNil(LicenseKey(String(repeating: "A", count: 65)))
        XCTAssertEqual(LicenseKey("SHELF-7F3A2C9E-41B8-4D")?.masked, "SHELF-7F3A…41B8-4D")
    }

    func testGeneratedKeysAreValidAndUnique() {
        let keys = (0 ..< 50).map { _ in LicenseKey.generate() }
        XCTAssertEqual(Set(keys).count, 50)
        XCTAssertTrue(keys.allSatisfy { $0.rawValue.hasPrefix("SHELF-") && $0.rawValue.count == 24 })
    }

    func testVersionsParseAndCompare() {
        XCTAssertEqual(AppVersion("2.4.1"), AppVersion(major: 2, minor: 4, patch: 1))
        XCTAssertNil(AppVersion("2.4"))
        XCTAssertNil(AppVersion("2.4.x"))
        XCTAssertNil(AppVersion("2..1"))
        XCTAssertLessThan(AppVersion("2.3.2")!, AppVersion("2.4.0")!)
        XCTAssertLessThan(AppVersion("2.9.0")!, AppVersion("2.10.0")!)
        XCTAssertEqual(AppVersion("2.4.1")?.minorString, "2.4")
    }

    func testActivationRequestsDecodeTheWireFormat() throws {
        let json = #"{"key":"shelf-7f3a2c9e-41b8-4d","machineId":"6F9619FF-8B86-D011-B42D-00C04FC964FF","appVersion":"2.4.1"}"#
        let request = try JSONDecoder().decode(ActivationRequest.self, from: Data(json.utf8))
        XCTAssertEqual(request.key.rawValue, "SHELF-7F3A2C9E-41B8-4D")
        XCTAssertEqual(request.appVersion, AppVersion("2.4.1"))

        let bad = #"{"key":"x","machineId":"6F9619FF-8B86-D011-B42D-00C04FC964FF"}"#
        XCTAssertThrowsError(try JSONDecoder().decode(ActivationRequest.self, from: Data(bad.utf8)))

        let encoded = try JSONEncoder().encode(request)
        XCTAssertEqual(try JSONDecoder().decode(ActivationRequest.self, from: encoded), request)
    }

    func testEmailValidation() {
        XCTAssertTrue(RecoveryRequest(email: "priya@example.com").isValid)
        XCTAssertTrue(EmailAddress.isValid("a.b+shelf@studio.co.uk"))
        XCTAssertFalse(EmailAddress.isValid("priya@example"))
        XCTAssertFalse(EmailAddress.isValid("priya example@x.com"))
        XCTAssertFalse(EmailAddress.isValid("@example.com"))
        XCTAssertFalse(EmailAddress.isValid("a@b@example.com"))
        XCTAssertFalse(EmailAddress.isValid("a@.example.com"))
    }

    func testTierNamesAndFailureMessages() {
        XCTAssertEqual(LicenseTier.family.displayName, "Family")
        XCTAssertEqual(ActivationFailure(rawValue: "seat-limit"), .seatLimit)
        XCTAssertTrue(ActivationFailure.notFound.message.contains("wasn't recognised"))
        XCTAssertEqual(ActivationResponse(tier: .personal, email: "a@b.co", seatLimit: 3, activationsUsed: 1).seatsDescription, "1 of 3 Macs")
    }
}

final class HexColorTests: XCTestCase {
    func testParsingAndFormatting() {
        XCTAssertEqual(HexColor("#E4572E")?.description, "#E4572E")
        XCTAssertEqual(HexColor("e4572e")?.description, "#E4572E")
        XCTAssertEqual(HexColor("#fff")?.description, "#FFFFFF")
        XCTAssertEqual(HexColor("#08090a")?.description, "#08090A")
        XCTAssertNil(HexColor("#E4572"))
        XCTAssertNil(HexColor("orange"))
    }

    func testForegroundContrast() {
        XCTAssertTrue(HexColor("#1C2420")!.prefersLightForeground)
        XCTAssertTrue(HexColor("#C7431D")!.prefersLightForeground)
        XCTAssertFalse(HexColor("#E9B44C")!.prefersLightForeground)
        XCTAssertFalse(HexColor("#FFFDF9")!.prefersLightForeground)
    }
}
