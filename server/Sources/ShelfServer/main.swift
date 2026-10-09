import Foundation
import Hummingbird
import Logging
import ShelfWeb

/// Serves shelfapp.com: the product site, the changelog, the Sparkle appcast and the license API.
/// Configuration comes from the environment; see the README for the variables.
let configuration = SiteConfiguration.fromEnvironment()
var logger = Logger(label: "shelf.server")
logger.logLevel = ProcessInfo.processInfo.environment["LOG_LEVEL"].flatMap(Logger.Level.init(rawValue:)) ?? .info

do {
    let site = try ShelfSite(configuration: configuration)
    logger.info("Serving \(site.renderer.pages.count) pages from \(configuration.siteRoot) on port \(configuration.port)")
    try await site.buildApplication(logger: logger).runService()
} catch {
    logger.critical("Shelf server failed: \(error)")
    exit(1)
}
