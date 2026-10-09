import Foundation
import IOKit
import OSLog
import ShelfKit

/// Talks to the license endpoints on shelfapp.com from Settings → License. Only the key, a hash
/// of the Mac's hardware UUID (hashed again on the server) and the app version are sent.
@MainActor
final class LicenseClient: ObservableObject {
    enum State: Equatable {
        case unlicensed
        case working
        case active(key: LicenseKey, details: ActivationResponse?)
        case failed(String)
    }

    static let baseURL = URL(string: "https://shelfapp.com")!
    private static let storedKey = "license.key"

    @Published private(set) var state: State = .unlicensed
    @Published private(set) var recoveryMessage: String?

    private let session: URLSession
    private let defaults: UserDefaults
    private let baseURL: URL
    private let logger = Logger(subsystem: "com.shelfapp.Shelf", category: "License")

    init(session: URLSession = .shared, defaults: UserDefaults = .standard, baseURL: URL = LicenseClient.baseURL) {
        self.session = session
        self.defaults = defaults
        self.baseURL = baseURL
        if let stored = defaults.string(forKey: Self.storedKey), let key = LicenseKey(stored) {
            state = .active(key: key, details: nil)
        }
    }

    var activeKey: LicenseKey? {
        if case let .active(key, _) = state { return key }
        return nil
    }

    func activate(_ input: String) async {
        guard let key = LicenseKey(input) else {
            state = .failed("That doesn't look like a Shelf license key.")
            return
        }
        guard let machineId = Self.platformUUID() else {
            state = .failed("Shelf couldn't read this Mac's hardware ID.")
            return
        }
        state = .working
        let body = ActivationRequest(key: key, machineId: machineId, appVersion: Self.appVersion)
        do {
            let (data, response) = try await send(body, method: "POST", path: "api/license/activate")
            switch response.statusCode {
            case 200:
                let details = try JSONDecoder().decode(ActivationResponse.self, from: data)
                defaults.set(key.rawValue, forKey: Self.storedKey)
                state = .active(key: key, details: details)
            default:
                let error = try? JSONDecoder().decode(APIErrorBody.self, from: data)
                state = .failed(error?.reason?.message ?? error?.error ?? "Activation failed (\(response.statusCode)).")
            }
        } catch {
            logger.error("Activation request failed: \(error.localizedDescription, privacy: .public)")
            state = .failed("Shelf couldn't reach the license server. Check your connection and try again.")
        }
    }

    /// Frees this Mac's seat. The key is forgotten locally even if the server can't be reached,
    /// and the seat can then be freed from the link in the receipt email.
    func deactivate() async {
        guard let key = activeKey else { return }
        state = .working
        if let machineId = Self.platformUUID() {
            let body = ActivationRequest(key: key, machineId: machineId, appVersion: nil)
            _ = try? await send(body, method: "DELETE", path: "api/license/activate")
        }
        defaults.removeObject(forKey: Self.storedKey)
        state = .unlicensed
    }

    /// Asks the server to email the keys bought with an address. The answer never says whether
    /// the address has a license.
    func recover(email: String) async {
        let request = RecoveryRequest(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        guard request.isValid else {
            recoveryMessage = "Enter a valid email address."
            return
        }
        do {
            let (_, response) = try await send(request, method: "POST", path: "api/license/recover")
            recoveryMessage = response.statusCode == 202
                ? "If that address bought Shelf, the keys are on their way."
                : "Something went wrong. Try again, or write to hello@shelfapp.com."
        } catch {
            recoveryMessage = "Shelf couldn't reach the license server."
        }
    }

    private func send<Body: Encodable>(_ body: Body, method: String, path: String) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 20
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (data, http)
    }

    static var appVersion: AppVersion? {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
            ?? AppVersion("2.4.1")
    }

    /// The Mac's IOPlatformUUID. The server only ever stores a hash of it.
    nonisolated static func platformUUID() -> UUID? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let property = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0),
              let value = property.takeRetainedValue() as? String
        else { return nil }
        return UUID(uuidString: value)
    }
}
