import Foundation
import ShelfKit
import XCTest
@testable import ShelfWeb

final class ReleaseTests: XCTestCase {
    func testReleasesAreNewestFirstWithUniqueVersions() {
        let versions = Releases.all.map(\.version)
        XCTAssertEqual(versions, versions.sorted(by: >))
        XCTAssertEqual(Set(versions).count, versions.count)
        XCTAssertTrue(Releases.all.allSatisfy { $0.day != nil && !$0.changes.isEmpty })
    }

    func testFormatting() {
        let release = Releases.latest
        XCTAssertEqual(release.anchor, "v2-4-1")
        XCTAssertEqual(release.formattedDate, "Sep 22, 2026")
        XCTAssertEqual(release.formattedSize, "11.4 MB")
        XCTAssertEqual(release.downloadURL(base: "https://downloads.shelfapp.com"), "https://downloads.shelfapp.com/Shelf-2.4.1.dmg")
    }
}

final class AppcastTests: XCTestCase {
    private let appcast = Appcast(siteURL: "https://shelfapp.com", downloadBaseURL: "https://downloads.shelfapp.com")

    func testOnlyReleasesWithASizeArePublished() {
        let xml = appcast.render(Releases.all)
        XCTAssertEqual(xml.components(separatedBy: "<item>").count - 1, 2)
        XCTAssertTrue(xml.hasPrefix(#"<?xml version="1.0" encoding="utf-8"?>"#))
        XCTAssertTrue(xml.contains(#"<enclosure url="https://downloads.shelfapp.com/Shelf-2.4.1.dmg" length="11402388" type="application/octet-stream" />"#))
        XCTAssertTrue(xml.contains("<pubDate>Tue, 22 Sep 2026 16:00:00 GMT</pubDate>"))
        XCTAssertTrue(xml.contains("<sparkle:releaseNotesLink>https://shelfapp.com/changelog#v2-4-0</sparkle:releaseNotesLink>"))
        XCTAssertTrue(xml.contains("<sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>"))
        XCTAssertFalse(xml.contains("2.3.2"))
    }

    func testNotesAreEscapedAndCannotBreakOutOfCDATA() {
        let release = Release("9.9.9", date: "2026-10-01", summary: "Fixes <script> & ]]> tricks", size: 1, changes: [Change(.fixed, "A < B")])
        let notes = appcast.notes(release)
        XCTAssertEqual(notes, "<p>Fixes &lt;script&gt; &amp; ]]&gt; tricks</p><ul><li><strong>Fixed</strong> A &lt; B</li></ul>")
        XCTAssertFalse(appcast.render([release]).contains("tricks]]>"))
    }
}

final class LicenseServiceTests: XCTestCase {
    private let key = LicenseKey("SHELF-7F3A2C9E-41B8-4D")!
    private let macs = (0 ..< 4).map { _ in UUID() }

    private func service(seatLimit: Int = 3) -> LicenseService {
        LicenseService(store: InMemoryLicenseStore([
            License(key: key, email: "Priya@Example.com", tier: .personal, seatLimit: seatLimit),
        ]))
    }

    func testActivationCountsEachMacOnce() async throws {
        let service = service()
        let first = try await service.activate(key: key, machineId: macs[0]).get()
        let again = try await service.activate(key: key, machineId: macs[0]).get()
        XCTAssertEqual(first.activationsUsed, 1)
        XCTAssertEqual(again.activationsUsed, 1)
        XCTAssertEqual(first.tier, .personal)
    }

    func testSeatLimitAndDeactivation() async throws {
        let service = service()
        for mac in macs.prefix(3) {
            _ = try await service.activate(key: key, machineId: mac).get()
        }
        let fourth = try await service.activate(key: key, machineId: macs[3])
        XCTAssertEqual(fourth.failure, .seatLimit)

        let freed = try await service.deactivate(key: key, machineId: macs[0])
        XCTAssertTrue(freed)
        let retry = try await service.activate(key: key, machineId: macs[3]).get()
        XCTAssertEqual(retry.activationsUsed, 3)
    }

    func testUnknownKeys() async throws {
        let service = service()
        let missing = LicenseKey("SHELF-00000000-0000-00")!
        let result = try await service.activate(key: missing, machineId: macs[0])
        XCTAssertEqual(result.failure, .notFound)
        let deactivated = try await service.deactivate(key: missing, machineId: macs[0])
        XCTAssertFalse(deactivated)
    }

    func testRacingMacsCannotBothTakeTheLastSeat() async throws {
        let service = service(seatLimit: 1)
        let results = await withTaskGroup(of: Bool.self) { group in
            for mac in macs {
                group.addTask { (try? await service.activate(key: self.key, machineId: mac).get()) != nil }
            }
            return await group.reduce(into: [Bool]()) { $0.append($1) }
        }
        XCTAssertEqual(results.filter { $0 }.count, 1)
    }

    func testMachineIDsAreHashed() {
        let id = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!
        let hash = LicenseService.hashMachine(id)
        XCTAssertEqual(hash.count, 16)
        XCTAssertFalse(hash.contains("6f9619ff"))
        XCTAssertEqual(hash, LicenseService.hashMachine(id))
        XCTAssertNotEqual(hash, LicenseService.hashMachine(UUID()))
    }

    func testRecoveryMatchesEmailCaseInsensitively() async throws {
        let found = try await service().recover(email: " priya@example.COM ")
        XCTAssertEqual(found.map(\.key), [key])

        let message = try XCTUnwrap(LicenseService.recoveryMessage(for: found, to: "priya@example.com"))
        XCTAssertEqual(message.subject, "Your Shelf license key")
        XCTAssertTrue(message.text.contains("Personal: SHELF-7F3A2C9E-41B8-4D"))
        XCTAssertNil(LicenseService.recoveryMessage(for: [], to: "x@y.co"))
    }
}

final class CheckoutTests: XCTestCase {
    private let checkout = Checkout(checkoutURLs: [
        .personal: "https://pay.example.com/buy/personal",
        .team: "https://pay.example.com/buy/team?ref=site&quantity=1",
    ])

    func testHostedCheckouts() throws {
        XCTAssertEqual(try checkout.destination(plan: "personal", seats: nil), .hosted(URL(string: "https://pay.example.com/buy/personal")!))
        XCTAssertEqual(try checkout.destination(plan: "team", seats: nil), .hosted(URL(string: "https://pay.example.com/buy/team?ref=site&quantity=5")!))
        XCTAssertEqual(try checkout.destination(plan: "team", seats: "12"), .hosted(URL(string: "https://pay.example.com/buy/team?ref=site&quantity=12")!))
    }

    func testUnconfiguredPlansFallBackToPricing() throws {
        XCTAssertEqual(try checkout.destination(plan: "family", seats: nil), .pricingPage)
    }

    func testBadInput() {
        XCTAssertThrowsError(try checkout.destination(plan: nil, seats: nil)) { XCTAssertEqual($0 as? Checkout.Failure, .unknownPlan) }
        XCTAssertThrowsError(try checkout.destination(plan: "enterprise", seats: nil)) { XCTAssertEqual($0 as? Checkout.Failure, .unknownPlan) }
        XCTAssertThrowsError(try checkout.destination(plan: "team", seats: "4")) { XCTAssertEqual($0 as? Checkout.Failure, .invalidSeats) }
        XCTAssertThrowsError(try checkout.destination(plan: "team", seats: "501"))
        XCTAssertThrowsError(try checkout.destination(plan: "team", seats: "five"))
    }

    func testPlanPrices() {
        XCTAssertEqual(Plan.personal.formattedPrice, "$19")
        XCTAssertEqual(Plan.forTier(.team).minSeats, 5)
    }
}

final class ConfigurationTests: XCTestCase {
    func testEnvironmentParsing() {
        let configuration = SiteConfiguration.fromEnvironment([
            "PORT": "3000",
            "SITE_URL": "https://shelfapp.com/",
            "CHECKOUT_URL_TEAM": "https://pay.example.com/team",
            "CHECKOUT_URL_FAMILY": "  ",
            "MAIL_API_URL": "https://mail.example.com/send",
            "MAIL_API_KEY": "secret",
            "SITE_ROOT": "/app/site",
        ])
        XCTAssertEqual(configuration.port, 3000)
        XCTAssertEqual(configuration.siteURL, "https://shelfapp.com")
        XCTAssertEqual(configuration.checkoutURLs, [.team: "https://pay.example.com/team"])
        XCTAssertEqual(configuration.siteRoot, "/app/site")
        XCTAssertTrue(configuration.makeMailer() is HTTPMailer)
    }

    func testDefaults() {
        let configuration = SiteConfiguration.fromEnvironment([:])
        XCTAssertEqual(configuration.port, 8080)
        XCTAssertEqual(configuration.host, "0.0.0.0")
        XCTAssertEqual(configuration.downloadBaseURL, "https://downloads.shelfapp.com")
        XCTAssertTrue(configuration.makeMailer() is LoggingMailer)
    }

    func testMailRequestShape() throws {
        let mailer = HTTPMailer(endpoint: URL(string: "https://mail.example.com/send")!, apiKey: "k")
        let request = try mailer.request(for: MailMessage(to: "a@b.co", subject: "Hi", text: "Body"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer k")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]
        XCTAssertEqual(body?["from"], HTTPMailer.sender)
        XCTAssertEqual(body?["to"], "a@b.co")
    }
}

extension Result {
    var failure: Failure? {
        if case let .failure(error) = self { return error }
        return nil
    }
}
