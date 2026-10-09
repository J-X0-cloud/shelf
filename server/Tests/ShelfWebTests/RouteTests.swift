import Foundation
import Hummingbird
import HummingbirdTesting
import ShelfKit
import XCTest
@testable import ShelfWeb

/// Captures mail instead of sending it.
actor MailOutbox: Mailer {
    private(set) var sent: [MailMessage] = []
    var failing = false

    func send(_ message: MailMessage) async throws {
        if failing { throw HTTPMailer.Failure.providerStatus(503) }
        sent.append(message)
    }

    func fail() { failing = true }
}

final class RouteTests: XCTestCase {
    private let demoKey = "SHELF-7F3A2C9E-41B8-4D"
    private let machineId = "6F9619FF-8B86-D011-B42D-00C04FC964FF"

    private func makeApp(
        outbox: MailOutbox = MailOutbox(),
        checkout: [LicenseTier: String] = [.personal: "https://pay.example.com/personal"]
    ) throws -> some ApplicationProtocol {
        let site = try ShelfSite(
            configuration: SiteFolder.configuration { $0.checkoutURLs = checkout },
            licenseStore: InMemoryLicenseStore.demo(),
            mailer: outbox
        )
        return Application(router: site.buildRouter())
    }

    private func json(_ object: [String: String]) -> ByteBuffer {
        ByteBuffer(bytes: try! JSONSerialization.data(withJSONObject: object))
    }

    private let jsonHeaders: HTTPFields = [.contentType: "application/json"]

    // MARK: Pages

    func testPagesAreServedAsHTML() async throws {
        try await makeApp().test(.router) { client in
            for path in ["/", "/features", "/pricing", "/changelog", "/support", "/support/"] {
                try await client.execute(uri: path, method: .get) { response in
                    XCTAssertEqual(response.status, .ok, path)
                    XCTAssertEqual(response.headers[.contentType], "text/html; charset=utf-8")
                    XCTAssertEqual(response.headers[.init("X-Content-Type-Options")!], "nosniff")
                    XCTAssertTrue(String(buffer: response.body).contains("<main id=\"main\">"), path)
                }
            }
        }
    }

    func testUnknownPagesGetTheNotFoundPage() async throws {
        try await makeApp().test(.router) { client in
            try await client.execute(uri: "/shelves-of-doom", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
                XCTAssertTrue(String(buffer: response.body).contains("Nothing on this shelf."))
            }
            try await client.execute(uri: "/api/nothing", method: .get) { response in
                XCTAssertEqual(response.status, .notFound)
                XCTAssertFalse(String(buffer: response.body).contains("<html"), "API paths don't get the HTML page")
            }
        }
    }

    func testStaticAssets() async throws {
        try await makeApp().test(.router) { client in
            try await client.execute(uri: "/css/macos.css", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertTrue(String(buffer: response.body).contains(".desk"))
            }
            try await client.execute(uri: "/fonts/inter-display-400.woff2", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.contentType], "font/woff2")
                XCTAssertEqual(response.headers[.cacheControl], "public, max-age=31536000")
            }
            try await client.execute(uri: "/../Package.swift", method: .get) { response in
                XCTAssertNotEqual(response.status, .ok)
            }
        }
    }

    func testAppcastAndHealth() async throws {
        try await makeApp().test(.router) { client in
            try await client.execute(uri: "/appcast.xml", method: .get) { response in
                XCTAssertEqual(response.status, .ok)
                XCTAssertEqual(response.headers[.contentType], "application/rss+xml; charset=utf-8")
                XCTAssertEqual(response.headers[.accessControlAllowOrigin], "*")
                XCTAssertTrue(String(buffer: response.body).contains("<sparkle:version>2.4.1</sparkle:version>"))
            }
            try await client.execute(uri: "/health", method: .get) { response in
                XCTAssertEqual(String(buffer: response.body), "ok")
            }
        }
    }

    // MARK: Checkout

    func testCheckoutRedirects() async throws {
        try await makeApp().test(.router) { client in
            try await client.execute(uri: "/api/checkout?plan=personal", method: .get) { response in
                XCTAssertEqual(response.status, .seeOther)
                XCTAssertEqual(response.headers[.location], "https://pay.example.com/personal")
            }
            try await client.execute(uri: "/api/checkout?plan=family", method: .get) { response in
                XCTAssertEqual(response.status, .temporaryRedirect)
                XCTAssertEqual(response.headers[.location], "/pricing")
            }
            try await client.execute(uri: "/api/checkout?plan=platinum", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
                XCTAssertEqual(String(buffer: response.body), #"{"error":"Unknown plan"}"#)
            }
            try await client.execute(uri: "/api/checkout?plan=team&seats=2", method: .get) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    // MARK: Licenses

    func testActivationAndDeactivation() async throws {
        try await makeApp().test(.router) { client in
            let body = ["key": demoKey.lowercased(), "machineId": machineId, "appVersion": "2.4.1"]
            try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: json(body)) { response in
                XCTAssertEqual(response.status, .ok)
                let activation = try JSONDecoder().decode(ActivationResponse.self, from: Data(response.body.readableBytesView))
                XCTAssertEqual(activation, ActivationResponse(tier: .personal, email: "priya@example.com", seatLimit: 3, activationsUsed: 1))
            }
            try await client.execute(uri: "/api/license/activate", method: .delete, headers: jsonHeaders, body: json(["key": demoKey, "machineId": machineId])) { response in
                XCTAssertEqual(response.status, .noContent)
            }
        }
    }

    func testActivationErrors() async throws {
        try await makeApp().test(.router) { client in
            let unknown = ["key": "SHELF-00000000-0000-00", "machineId": machineId, "appVersion": "2.4.1"]
            try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: json(unknown)) { response in
                XCTAssertEqual(response.status, .notFound)
                let error = try JSONDecoder().decode(APIErrorBody.self, from: Data(response.body.readableBytesView))
                XCTAssertEqual(error.reason, .notFound)
            }

            for mac in 0 ..< 3 {
                let body = ["key": demoKey, "machineId": UUID().uuidString, "appVersion": "2.4.1"]
                try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: json(body)) { response in
                    XCTAssertEqual(response.status, .ok, "Mac \(mac)")
                }
            }
            let fourth = ["key": demoKey, "machineId": UUID().uuidString, "appVersion": "2.4.1"]
            try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: json(fourth)) { response in
                XCTAssertEqual(response.status, .conflict)
                XCTAssertTrue(String(buffer: response.body).contains("seat-limit"))
            }

            let invalid: [[String: String]] = [
                ["key": demoKey, "machineId": "not-a-uuid", "appVersion": "2.4.1"],
                ["key": demoKey, "machineId": machineId, "appVersion": "2.4"],
                ["key": demoKey, "machineId": machineId],
                ["key": "short", "machineId": machineId, "appVersion": "2.4.1"],
            ]
            for body in invalid {
                try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: json(body)) { response in
                    XCTAssertEqual(response.status, .badRequest, "\(body)")
                }
            }
            try await client.execute(uri: "/api/license/activate", method: .post, headers: jsonHeaders, body: ByteBuffer(string: "{nope")) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
    }

    func testRecoveryNeverRevealsWhetherAnAddressBought() async throws {
        let outbox = MailOutbox()
        try await makeApp(outbox: outbox).test(.router) { client in
            for email in ["priya@example.com", "nobody@example.com"] {
                try await client.execute(uri: "/api/license/recover", method: .post, headers: jsonHeaders, body: json(["email": email])) { response in
                    XCTAssertEqual(response.status, .accepted)
                    XCTAssertEqual(String(buffer: response.body), #"{"status":"sent-if-found"}"#)
                }
            }
            try await client.execute(uri: "/api/license/recover", method: .post, headers: jsonHeaders, body: json(["email": "not an email"])) { response in
                XCTAssertEqual(response.status, .badRequest)
            }
        }
        let sent = await outbox.sent
        XCTAssertEqual(sent.map(\.to), ["priya@example.com"])
        XCTAssertTrue(sent[0].text.contains(demoKey))
    }

    func testRecoveryStillAnswers202WhenMailFails() async throws {
        let outbox = MailOutbox()
        await outbox.fail()
        try await makeApp(outbox: outbox).test(.router) { client in
            try await client.execute(uri: "/api/license/recover", method: .post, headers: jsonHeaders, body: json(["email": "priya@example.com"])) { response in
                XCTAssertEqual(response.status, .accepted)
            }
        }
    }
}
