import Foundation
import ShelfKit

/// Everything the server reads from its environment. Unset values fall back to safe defaults, so
/// a fresh checkout runs with no configuration at all.
public struct SiteConfiguration: Sendable {
    /// Port to listen on. Railway and most hosts set `PORT`.
    public var port: Int
    public var host: String
    /// Canonical URL used in metadata and appcast links (`SITE_URL`).
    public var siteURL: String
    /// Host for signed `Shelf-<version>.dmg` builds (`DOWNLOAD_BASE_URL`).
    public var downloadBaseURL: String
    /// Hosted checkout links per license (`CHECKOUT_URL_PERSONAL`, `_FAMILY`, `_TEAM`).
    public var checkoutURLs: [LicenseTier: String]
    /// Transactional email for key recovery (`MAIL_API_URL`, `MAIL_API_KEY`). Logged when unset.
    public var mailAPIURL: String?
    public var mailAPIKey: String?
    /// Folder holding `templates/` and `public/` (`SITE_ROOT`).
    public var siteRoot: String

    public init(
        port: Int = 8080,
        host: String = "0.0.0.0",
        siteURL: String = "https://shelfapp.com",
        downloadBaseURL: String = "https://downloads.shelfapp.com",
        checkoutURLs: [LicenseTier: String] = [:],
        mailAPIURL: String? = nil,
        mailAPIKey: String? = nil,
        siteRoot: String = "site"
    ) {
        self.port = port
        self.host = host
        self.siteURL = SiteConfiguration.trimmingSlash(siteURL)
        self.downloadBaseURL = SiteConfiguration.trimmingSlash(downloadBaseURL)
        self.checkoutURLs = checkoutURLs
        self.mailAPIURL = mailAPIURL
        self.mailAPIKey = mailAPIKey
        self.siteRoot = siteRoot
    }

    /// Reads the configuration from environment variables. Empty strings count as unset.
    public static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> SiteConfiguration {
        func value(_ name: String) -> String? {
            guard let raw = environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            return raw
        }

        var checkout: [LicenseTier: String] = [:]
        for tier in LicenseTier.allCases {
            if let url = value("CHECKOUT_URL_\(tier.rawValue.uppercased())") {
                checkout[tier] = url
            }
        }

        let defaults = SiteConfiguration()
        return SiteConfiguration(
            port: value("PORT").flatMap(Int.init) ?? defaults.port,
            host: value("HOST") ?? defaults.host,
            siteURL: value("SITE_URL") ?? defaults.siteURL,
            downloadBaseURL: value("DOWNLOAD_BASE_URL") ?? defaults.downloadBaseURL,
            checkoutURLs: checkout,
            mailAPIURL: value("MAIL_API_URL"),
            mailAPIKey: value("MAIL_API_KEY"),
            siteRoot: value("SITE_ROOT") ?? defaults.siteRoot
        )
    }

    private static func trimmingSlash(_ url: String) -> String {
        url.hasSuffix("/") ? String(url.dropLast()) : url
    }
}
