import Crypto
import Foundation
import ShelfKit

/// A sold license.
public struct License: Hashable, Sendable {
    public var key: LicenseKey
    public var email: String
    public var tier: LicenseTier
    /// Macs per person.
    public var seatLimit: Int
    /// Hashed machine IDs of the Macs the license is active on.
    public var activations: [String]

    public init(key: LicenseKey, email: String, tier: LicenseTier, seatLimit: Int = LicenseTier.macsPerPerson, activations: [String] = []) {
        self.key = key
        self.email = email
        self.tier = tier
        self.seatLimit = seatLimit
        self.activations = activations
    }
}

/// Storage for licenses. Swapped for the payment provider's API in production.
public protocol LicenseStore: Sendable {
    func license(forKey key: LicenseKey) async throws -> License?
    func licenses(forEmail email: String) async throws -> [License]
    func save(_ license: License) async throws
}

public actor InMemoryLicenseStore: LicenseStore {
    private var licenses: [LicenseKey: License]

    public init(_ seed: [License] = []) {
        licenses = Dictionary(seed.map { ($0.key, $0) }, uniquingKeysWith: { _, last in last })
    }

    public func license(forKey key: LicenseKey) -> License? {
        licenses[key]
    }

    public func licenses(forEmail email: String) -> [License] {
        licenses.values
            .filter { $0.email.caseInsensitiveCompare(email) == .orderedSame }
            .sorted { $0.key.rawValue < $1.key.rawValue }
    }

    public func save(_ license: License) {
        licenses[license.key] = license
    }
}

/// Activation, deactivation and recovery. Activation is serialised so two Macs racing for the
/// last seat can't both get it.
public actor LicenseService {
    private let store: any LicenseStore

    public init(store: any LicenseStore) {
        self.store = store
    }

    /// Machine identifiers are hashed before storage; the raw hardware UUID is never kept.
    public static func hashMachine(_ machineId: UUID) -> String {
        let digest = SHA256.hash(data: Data(machineId.uuidString.lowercased().utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    public func activate(key: LicenseKey, machineId: UUID) async throws -> Result<ActivationResponse, ActivationFailure> {
        guard var license = try await store.license(forKey: key) else { return .failure(.notFound) }

        let machine = Self.hashMachine(machineId)
        if !license.activations.contains(machine) {
            guard license.activations.count < license.seatLimit else { return .failure(.seatLimit) }
            license.activations.append(machine)
            try await store.save(license)
        }

        return .success(ActivationResponse(
            tier: license.tier,
            email: license.email,
            seatLimit: license.seatLimit,
            activationsUsed: license.activations.count
        ))
    }

    /// Frees the seat a Mac was using. Returns `false` when the key is unknown.
    public func deactivate(key: LicenseKey, machineId: UUID) async throws -> Bool {
        guard var license = try await store.license(forKey: key) else { return false }
        let machine = Self.hashMachine(machineId)
        license.activations.removeAll { $0 == machine }
        try await store.save(license)
        return true
    }

    /// Licenses bought with this address. Callers must only ever deliver the keys by email.
    public func recover(email: String) async throws -> [License] {
        try await store.licenses(forEmail: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// The email that carries recovered keys, or `nil` when there is nothing to send.
    public static func recoveryMessage(for licenses: [License], to email: String) -> MailMessage? {
        guard !licenses.isEmpty else { return nil }
        let lines = licenses.map { "\($0.tier.displayName): \($0.key)" }.joined(separator: "\n")
        let single = licenses.count == 1
        return MailMessage(
            to: email,
            subject: single ? "Your Shelf license key" : "Your Shelf license keys",
            text: """
            Here \(single ? "is the key" : "are the keys") for this address:

            \(lines)

            Paste a key into Settings → License on your Mac. Reply to this email if anything looks wrong.
            """
        )
    }
}

extension InMemoryLicenseStore {
    /// The license the local server starts with, so activation can be tried end to end.
    public static func demo() -> InMemoryLicenseStore {
        InMemoryLicenseStore([
            License(key: LicenseKey("SHELF-7F3A2C9E-41B8-4D")!, email: "priya@example.com", tier: .personal),
        ])
    }
}
