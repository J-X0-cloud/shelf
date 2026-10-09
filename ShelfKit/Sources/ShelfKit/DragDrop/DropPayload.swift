import Foundation

/// What arrived in a drop, reduced to the URLs Shelf can hold. Finder sends file URLs, browsers
/// send web URLs or plain text, and some apps send `.webloc` / `.url` bookmark files.
public struct DropPayload: Equatable, Sendable {
    public private(set) var urls: [URL]
    /// Entries that were dropped but can't go on a shelf (unsupported schemes, blank text).
    public private(set) var rejected: [String]

    public init(urls: [URL] = [], rejected: [String] = []) {
        self.urls = []
        self.rejected = rejected
        for url in urls {
            append(url)
        }
    }

    /// Schemes allowed for link items. Anything else (`javascript:`, `data:`, app-specific schemes)
    /// is refused so a shelf can never hold something that runs code when clicked.
    public static let linkSchemes: Set<String> = ["http", "https", "mailto", "ftp", "sftp", "smb", "afp", "vnc", "ssh"]

    public var isEmpty: Bool { urls.isEmpty }

    /// Adds a URL if Shelf can hold it, ignoring repeats.
    public mutating func append(_ url: URL) {
        guard let normalized = DropPayload.normalize(url) else {
            rejected.append(url.absoluteString)
            return
        }
        guard !urls.contains(where: { ShelfItem.sameTarget($0, normalized) }) else { return }
        urls.append(normalized)
    }

    /// Builds a payload from dropped text: one URL per line, or a bare domain such as
    /// "shelfapp.com/changelog", which becomes an https link.
    public static func fromText(_ text: String) -> DropPayload {
        var payload = DropPayload()
        for line in text.split(whereSeparator: \.isNewline) {
            let entry = line.trimmingCharacters(in: .whitespaces)
            guard !entry.isEmpty, !entry.hasPrefix("#") else { continue }
            if let url = url(fromTextEntry: entry) {
                payload.append(url)
            } else {
                payload.rejected.append(entry)
            }
        }
        return payload
    }

    /// Unwraps `.webloc` (property list) and `.url` (Windows INI) bookmark files into their link,
    /// so dropping a saved bookmark puts the page on the shelf rather than the file.
    public static func bookmarkTarget(fileName: String, contents: Data) -> URL? {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "webloc":
            guard let plist = try? PropertyListSerialization.propertyList(from: contents, format: nil) as? [String: Any],
                  let string = plist["URL"] as? String
            else { return nil }
            return URL(string: string).flatMap(normalize)
        case "url":
            guard let text = String(data: contents, encoding: .utf8) else { return nil }
            for line in text.split(whereSeparator: \.isNewline) where line.lowercased().hasPrefix("url=") {
                return URL(string: String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)).flatMap(normalize)
            }
            return nil
        default:
            return nil
        }
    }

    static func normalize(_ url: URL) -> URL? {
        if url.isFileURL {
            guard !url.path.isEmpty else { return nil }
            return url.standardizedFileURL
        }
        guard let scheme = url.scheme?.lowercased(), linkSchemes.contains(scheme) else { return nil }
        if scheme == "http" || scheme == "https" {
            guard let host = url.host, !host.isEmpty else { return nil }
        }
        return url
    }

    static func url(fromTextEntry entry: String) -> URL? {
        if entry.hasPrefix("/") || entry.hasPrefix("~/") {
            return URL(fileURLWithPath: (entry as NSString).expandingTildeInPath)
        }
        if let url = URL(string: entry), url.scheme != nil {
            return normalize(url)
        }
        // "example.com/path": a host with a dot and no spaces becomes an https link.
        guard !entry.contains(" "),
              let host = entry.split(separator: "/").first,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".")
        else { return nil }
        return URL(string: "https://\(entry)").flatMap(normalize)
    }
}
