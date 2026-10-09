import Foundation

/// The licenses sold on shelfapp.com/pricing.
public enum LicenseTier: String, Codable, CaseIterable, Sendable {
    case personal
    case family
    case team

    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Macs each person may activate.
    public static let macsPerPerson = 3
}

/// A license key as typed or pasted by a person: whitespace trimmed, uppercased, and limited to
/// letters, digits and dashes.
public struct LicenseKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(_ input: String) {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        guard (8 ... 64).contains(normalized.count),
              normalized.unicodeScalars.allSatisfy(allowed.contains)
        else { return nil }
        rawValue = normalized
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let key = LicenseKey(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a license key")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }

    /// "SHELF-" followed by the first 18 characters of a random UUID.
    public static func generate() -> LicenseKey {
        LicenseKey("SHELF-" + UUID().uuidString.prefix(18))!
    }

    /// The key with the middle hidden, for showing in Settings: "SHELF-7F3A…41B8-4D".
    public var masked: String {
        guard rawValue.count > 14 else { return rawValue }
        return "\(rawValue.prefix(10))…\(rawValue.suffix(7))"
    }
}

/// A dotted three-part version such as "2.4.1".
public struct AppVersion: Comparable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init?(_ string: String) {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2])
        else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let version = AppVersion(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a version like 2.4.1")
        }
        self = version
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    /// "2.4.1" → "2.4", used on download buttons.
    public var minorString: String { "\(major).\(minor)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// Body of `POST /api/license/activate` and `DELETE /api/license/activate`, sent from Settings → License.
public struct ActivationRequest: Codable, Equatable, Sendable {
    public var key: LicenseKey
    /// The Mac's IOPlatformUUID. The server hashes it before storing anything.
    public var machineId: UUID
    /// Required when activating; not sent when deactivating.
    public var appVersion: AppVersion?

    public init(key: LicenseKey, machineId: UUID, appVersion: AppVersion?) {
        self.key = key
        self.machineId = machineId
        self.appVersion = appVersion
    }
}

/// A successful activation.
public struct ActivationResponse: Codable, Equatable, Sendable {
    public var tier: LicenseTier
    public var email: String
    public var seatLimit: Int
    public var activationsUsed: Int

    public init(tier: LicenseTier, email: String, seatLimit: Int, activationsUsed: Int) {
        self.tier = tier
        self.email = email
        self.seatLimit = seatLimit
        self.activationsUsed = activationsUsed
    }

    public var seatsDescription: String {
        "\(activationsUsed) of \(seatLimit) Macs"
    }
}

/// Why an activation was refused.
public enum ActivationFailure: String, Codable, Error, Sendable {
    case notFound = "not-found"
    case seatLimit = "seat-limit"

    public var message: String {
        switch self {
        case .notFound:
            "That license key wasn't recognised."
        case .seatLimit:
            "This license is active on the maximum number of Macs. Deactivate one from Settings → License."
        }
    }
}

/// The JSON error body the license endpoints return.
public struct APIErrorBody: Codable, Equatable, Sendable {
    public var error: String
    public var reason: ActivationFailure?

    public init(error: String, reason: ActivationFailure? = nil) {
        self.error = error
        self.reason = reason
    }
}

/// Body of `POST /api/license/recover`.
public struct RecoveryRequest: Codable, Equatable, Sendable {
    public var email: String

    public init(email: String) {
        self.email = email
    }

    /// A pragmatic check: one "@", a dotted domain, no spaces, at most 254 characters.
    public var isValid: Bool { EmailAddress.isValid(email) }
}

public enum EmailAddress {
    public static func isValid(_ address: String) -> Bool {
        guard address.count <= 254, !address.contains(where: \.isWhitespace) else { return false }
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[0].count <= 64 else { return false }
        let domain = parts[1]
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count >= 2 && labels.allSatisfy { !$0.isEmpty && !$0.hasPrefix("-") && !$0.hasSuffix("-") }
    }
}
