import Foundation
import HTTPTypes
import Hummingbird
import Logging
import ShelfKit

/// Everything a request needs, built once at startup.
public struct ShelfSite: Sendable {
    public let configuration: SiteConfiguration
    public let renderer: SiteRenderer
    public let appcast: String
    public let checkout: Checkout
    public let licenses: LicenseService
    public let mailer: any Mailer

    public init(
        configuration: SiteConfiguration,
        licenseStore: any LicenseStore = InMemoryLicenseStore.demo(),
        mailer: (any Mailer)? = nil,
        releases: [Release] = Releases.all
    ) throws {
        self.configuration = configuration
        renderer = try SiteRenderer(siteRoot: configuration.siteRoot, configuration: configuration, releases: releases)
        appcast = Appcast(siteURL: configuration.siteURL, downloadBaseURL: configuration.downloadBaseURL).render(releases)
        checkout = Checkout(checkoutURLs: configuration.checkoutURLs)
        licenses = LicenseService(store: licenseStore)
        self.mailer = mailer ?? configuration.makeMailer()
    }
}

extension ShelfSite {
    /// Largest JSON body the license endpoints accept.
    static let maxBodySize = 16 * 1024

    public func buildRouter() -> Router<BasicRequestContext> {
        let router = Router()
        router.add(middleware: NotFoundPageMiddleware(page: renderer.notFound))
        router.add(middleware: SecurityHeadersMiddleware())
        router.add(middleware: FileMiddleware(
            "\(configuration.siteRoot)/public",
            cacheControl: .init([
                (MediaType(type: .font), [.public, .maxAge(31_536_000)]),
                (MediaType(type: .image), [.public, .maxAge(86_400)]),
                (MediaType(type: .text, subType: "css"), [.public, .maxAge(3_600)]),
            ]),
            searchForIndexHtml: false
        ))

        router.get("/health") { _, _ in "ok" }

        for page in renderer.pages.values {
            router.get(RouterPath(page.path)) { _, _ in
                HTMLResponse.page(page.html)
            }
        }

        router.get("/appcast.xml") { _, _ in
            Response(
                status: .ok,
                headers: [
                    .contentType: "application/rss+xml; charset=utf-8",
                    .cacheControl: "public, max-age=300, s-maxage=3600",
                    .accessControlAllowOrigin: "*",
                ],
                body: .init(byteBuffer: ByteBuffer(string: appcast))
            )
        }

        router.get("/api/checkout") { request, _ in
            checkoutResponse(for: request)
        }

        router.post("/api/license/activate") { request, context in
            try await activate(request, context: context)
        }

        router.delete("/api/license/activate") { request, context in
            try await deactivate(request, context: context)
        }

        router.post("/api/license/recover") { request, context in
            try await recover(request, context: context)
        }

        return router
    }

    // MARK: Checkout

    /// Sends the buyer to the hosted checkout for a plan. Team checkouts carry a seat count (5 minimum).
    func checkoutResponse(for request: Request) -> Response {
        let query = request.uri.queryParameters
        do {
            switch try checkout.destination(plan: query["plan"].map(String.init), seats: query["seats"].map(String.init)) {
            case let .hosted(url):
                return Response(status: .seeOther, headers: [.location: url.absoluteString])
            case .pricingPage:
                return Response(status: .temporaryRedirect, headers: [.location: "/pricing"])
            }
        } catch Checkout.Failure.invalidSeats {
            return JSONResponse.make(APIErrorBody(error: "Team licenses need between 5 and \(Checkout.maxSeats) seats."), status: .badRequest)
        } catch {
            return JSONResponse.make(APIErrorBody(error: "Unknown plan"), status: .badRequest)
        }
    }

    // MARK: Licenses

    /// Called by the macOS app from Settings → License.
    func activate(_ request: Request, context: BasicRequestContext) async throws -> Response {
        guard let body = try await JSONResponse.decode(ActivationRequest.self, from: request),
              body.appVersion != nil
        else {
            return JSONResponse.make(APIErrorBody(error: "Invalid request"), status: .badRequest)
        }

        switch try await licenses.activate(key: body.key, machineId: body.machineId) {
        case let .success(activation):
            context.logger.info("license activated", metadata: ["tier": "\(activation.tier.rawValue)"])
            return JSONResponse.make(activation, status: .ok)
        case let .failure(reason):
            return JSONResponse.make(
                APIErrorBody(error: reason.message, reason: reason),
                status: reason == .notFound ? .notFound : .conflict
            )
        }
    }

    func deactivate(_ request: Request, context: BasicRequestContext) async throws -> Response {
        guard let body = try await JSONResponse.decode(ActivationRequest.self, from: request) else {
            return JSONResponse.make(APIErrorBody(error: "Invalid request"), status: .badRequest)
        }
        guard try await licenses.deactivate(key: body.key, machineId: body.machineId) else {
            return JSONResponse.make(APIErrorBody(error: "Not found"), status: .notFound)
        }
        return Response(status: .noContent)
    }

    /// Settings → License → Recover. Always answers 202 for a valid address so the endpoint can't
    /// be used to check whether someone bought Shelf; keys only ever go out by email.
    func recover(_ request: Request, context: BasicRequestContext) async throws -> Response {
        guard let body = try await JSONResponse.decode(RecoveryRequest.self, from: request), body.isValid else {
            return JSONResponse.make(APIErrorBody(error: "Enter a valid email address."), status: .badRequest)
        }

        let found = try await licenses.recover(email: body.email)
        if let message = LicenseService.recoveryMessage(for: found, to: body.email) {
            do {
                try await mailer.send(message)
            } catch {
                // Still 202: a different answer would reveal that the address has a license.
                context.logger.error("license recovery email failed: \(error)")
            }
        }
        return JSONResponse.make(["status": "sent-if-found"], status: .accepted)
    }
}

// MARK: - Responses

enum HTMLResponse {
    static func page(_ html: String, status: HTTPResponse.Status = .ok) -> Response {
        Response(
            status: status,
            headers: [
                .contentType: "text/html; charset=utf-8",
                .cacheControl: "public, max-age=300",
            ],
            body: .init(byteBuffer: ByteBuffer(string: html))
        )
    }
}

enum JSONResponse {
    static func make(_ value: some Encodable, status: HTTPResponse.Status) -> Response {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(value)) ?? Data(#"{"error":"Internal error"}"#.utf8)
        return Response(
            status: status,
            headers: [.contentType: "application/json; charset=utf-8", .cacheControl: "no-store"],
            body: .init(byteBuffer: ByteBuffer(bytes: data))
        )
    }

    /// Decodes a JSON body, or returns `nil` when the body is missing, too large or the wrong shape.
    static func decode<T: Decodable>(_ type: T.Type, from request: Request) async throws -> T? {
        var request = request
        guard let buffer = try? await request.collectBody(upTo: ShelfSite.maxBodySize) else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(buffer.readableBytesView))
    }
}

// MARK: - Middleware

/// Renders the site's 404 page for unknown paths, instead of an empty response.
struct NotFoundPageMiddleware<Context: RequestContext>: RouterMiddleware {
    let page: SiteRenderer.Page

    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        do {
            let response = try await next(request, context)
            guard response.status == .notFound, request.method == .get, !request.uri.path.hasPrefix("/api/") else {
                return response
            }
            return HTMLResponse.page(page.html, status: .notFound)
        } catch let error as HTTPError where error.status == .notFound {
            guard request.method == .get || request.method == .head, !request.uri.path.hasPrefix("/api/") else { throw error }
            return HTMLResponse.page(page.html, status: .notFound)
        }
    }
}

/// Conservative defaults for a static marketing site with a small JSON API.
struct SecurityHeadersMiddleware<Context: RequestContext>: RouterMiddleware {
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        var response = try await next(request, context)
        response.headers[.xContentTypeOptions] = "nosniff"
        response.headers[.referrerPolicy] = "strict-origin-when-cross-origin"
        if response.headers[.xFrameOptions] == nil {
            response.headers[.xFrameOptions] = "SAMEORIGIN"
        }
        return response
    }
}

extension HTTPField.Name {
    static let xContentTypeOptions = Self("X-Content-Type-Options")!
    static let xFrameOptions = Self("X-Frame-Options")!
    static let referrerPolicy = Self("Referrer-Policy")!
}

// MARK: - Application

extension ShelfSite {
    /// The configured application, ready for `runService()`.
    public func buildApplication(logger: Logger? = nil) -> some ApplicationProtocol {
        var logger = logger ?? Logger(label: "shelf.server")
        if logger.logLevel > .info { logger.logLevel = .info }
        return Application(
            router: buildRouter(),
            configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "Shelf"),
            logger: logger
        )
    }
}
