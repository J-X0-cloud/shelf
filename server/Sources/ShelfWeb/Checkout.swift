import Foundation
import ShelfKit

/// The plans on the pricing page. Prices are USD, one-time; Team is per seat with a minimum.
public struct Plan: Sendable, Equatable {
    public var tier: LicenseTier
    public var price: Int
    public var minSeats: Int?

    public static let personal = Plan(tier: .personal, price: 19)
    public static let family = Plan(tier: .family, price: 39)
    public static let team = Plan(tier: .team, price: 14, minSeats: 5)

    public static let all: [Plan] = [.personal, .family, .team]

    public static func forTier(_ tier: LicenseTier) -> Plan {
        all.first { $0.tier == tier }!
    }

    /// "$19".
    public var formattedPrice: String { "$\(price)" }
}

/// Turns `/api/checkout?plan=team&seats=8` into the hosted checkout URL.
public struct Checkout: Sendable {
    public static let maxSeats = 500

    public enum Destination: Equatable, Sendable {
        /// Hand off to the payment provider.
        case hosted(URL)
        /// No checkout configured for the plan: send the buyer back to the pricing page.
        case pricingPage
    }

    public enum Failure: Error, Equatable {
        case unknownPlan
        case invalidSeats
    }

    private let checkoutURLs: [LicenseTier: String]

    public init(checkoutURLs: [LicenseTier: String]) {
        self.checkoutURLs = checkoutURLs
    }

    public func destination(plan planName: String?, seats seatsText: String?) throws -> Destination {
        guard let planName, let tier = LicenseTier(rawValue: planName) else { throw Failure.unknownPlan }
        let plan = Plan.forTier(tier)

        var seats: Int?
        if let seatsText {
            guard let value = Int(seatsText), (plan.minSeats ?? 1) ... Self.maxSeats ~= value else {
                throw Failure.invalidSeats
            }
            seats = value
        }

        guard let base = checkoutURLs[tier], var components = URLComponents(string: base), components.scheme != nil else {
            return .pricingPage
        }
        if let minSeats = plan.minSeats {
            var query = components.queryItems ?? []
            query.removeAll { $0.name == "quantity" }
            query.append(URLQueryItem(name: "quantity", value: String(seats ?? minSeats)))
            components.queryItems = query
        }
        guard let url = components.url else { return .pricingPage }
        return .hosted(url)
    }
}
