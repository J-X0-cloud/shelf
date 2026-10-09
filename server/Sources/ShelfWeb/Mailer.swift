import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MailMessage: Codable, Equatable, Sendable {
    public var to: String
    public var subject: String
    public var text: String

    public init(to: String, subject: String, text: String) {
        self.to = to
        self.subject = subject
        self.text = text
    }
}

/// Transactional email. Logs in development; posts to the provider when an API key is set.
public protocol Mailer: Sendable {
    func send(_ message: MailMessage) async throws
}

public struct LoggingMailer: Mailer {
    private let logger: Logger

    public init(logger: Logger = Logger(label: "shelf.mail")) {
        self.logger = logger
    }

    public func send(_ message: MailMessage) async throws {
        // The body holds license keys, so only the envelope is logged.
        logger.info("mail to=\(message.to) subject=\"\(message.subject)\"")
    }
}

/// Posts `{ from, to, subject, text }` as JSON with a bearer token, which most transactional
/// providers accept directly or through a small adapter.
public struct HTTPMailer: Mailer {
    public enum Failure: Error, Equatable {
        case providerStatus(Int)
    }

    public static let sender = "Shelf <hello@shelfapp.com>"

    private let endpoint: URL
    private let apiKey: String
    private let session: URLSession

    public init(endpoint: URL, apiKey: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.session = session
    }

    struct Payload: Encodable {
        var from: String
        var to: String
        var subject: String
        var text: String
    }

    func request(for message: MailMessage) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(Payload(from: Self.sender, to: message.to, subject: message.subject, text: message.text))
        return request
    }

    public func send(_ message: MailMessage) async throws {
        let (_, response) = try await session.data(for: request(for: message))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200 ..< 300).contains(status) else { throw Failure.providerStatus(status) }
    }
}

extension SiteConfiguration {
    /// The provider mailer when both mail settings are present, otherwise the logging one.
    public func makeMailer() -> any Mailer {
        guard let mailAPIURL, let mailAPIKey, let endpoint = URL(string: mailAPIURL) else { return LoggingMailer() }
        return HTTPMailer(endpoint: endpoint, apiKey: mailAPIKey)
    }
}
