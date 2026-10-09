import Foundation

/// A deliberately small template language for the site's HTML. Templates are compiled once at
/// startup, and anything unknown is an error rather than an empty string, so a typo in a page
/// fails the tests instead of shipping.
///
/// - `{{name}}`: a value from the context, HTML-escaped
/// - `{{{name}}}`: a value inserted as-is (for HTML the server built itself)
/// - `{{> name}}`: another template (a partial), rendered with the same context
/// - `{{icon name [size] [stroke]}}`: one of the site's line icons as inline SVG
/// - `{{current /path}}`: ` aria-current="page"` when rendering that path
public struct Template: Sendable, Equatable {
    enum Node: Sendable, Equatable {
        case text(String)
        case value(String, escaped: Bool)
        case partial(String)
        case icon(Icon.Name, size: Double, stroke: Double)
        case current(String)
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        case unclosedTag(name: String, line: Int)
        case emptyTag(name: String, line: Int)
        case unknownIcon(String, template: String)
        case badIconArgument(String, template: String)
        case missingValue(String, template: String)
        case missingPartial(String, template: String)
        case recursivePartial(String)

        public var description: String {
            switch self {
            case let .unclosedTag(name, line): "\(name):\(line): a {{ tag is never closed"
            case let .emptyTag(name, line): "\(name):\(line): empty {{ }} tag"
            case let .unknownIcon(icon, template): "\(template): unknown icon \"\(icon)\""
            case let .badIconArgument(argument, template): "\(template): icon size or stroke \"\(argument)\" isn't a number"
            case let .missingValue(key, template): "\(template): no value for {{\(key)}}"
            case let .missingPartial(partial, template): "\(template): no partial named \"\(partial)\""
            case let .recursivePartial(partial): "partial \"\(partial)\" includes itself"
            }
        }
    }

    public let name: String
    let nodes: [Node]

    public init(name: String, source: String) throws {
        self.name = name
        nodes = try Template.parse(source, name: name)
    }

    /// Values available while rendering, plus the partials and the current path.
    public struct Context: Sendable {
        public var values: [String: String]
        public var partials: [String: Template]
        public var currentPath: String

        public init(values: [String: String] = [:], partials: [String: Template] = [:], currentPath: String = "/") {
            self.values = values
            self.partials = partials
            self.currentPath = currentPath
        }
    }

    public func render(_ context: Context) throws -> String {
        var output = ""
        try render(into: &output, context: context, stack: [name])
        return output
    }

    private func render(into output: inout String, context: Context, stack: [String]) throws {
        for node in nodes {
            switch node {
            case let .text(text):
                output += text
            case let .value(key, escaped):
                guard let value = context.values[key] else { throw Error.missingValue(key, template: name) }
                output += escaped ? HTML.escape(value) : value
            case let .partial(partialName):
                guard !stack.contains(partialName) else { throw Error.recursivePartial(partialName) }
                guard let partial = context.partials[partialName] else { throw Error.missingPartial(partialName, template: name) }
                try partial.render(into: &output, context: context, stack: stack + [partialName])
            case let .icon(icon, size, stroke):
                output += Icon.svg(icon, size: size, strokeWidth: stroke)
            case let .current(path):
                if context.currentPath == path { output += #" aria-current="page""# }
            }
        }
    }

    // MARK: Parsing

    private static func parse(_ source: String, name: String) throws -> [Node] {
        var nodes: [Node] = []
        var rest = source[...]

        while let open = rest.range(of: "{{") {
            if open.lowerBound > rest.startIndex {
                nodes.append(.text(String(rest[..<open.lowerBound])))
            }
            let line = source[..<open.lowerBound].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }

            let isRaw = rest[open.upperBound...].hasPrefix("{")
            let closing = isRaw ? "}}}" : "}}"
            let bodyStart = isRaw ? rest.index(after: open.upperBound) : open.upperBound
            guard let close = rest[bodyStart...].range(of: closing) else {
                throw Error.unclosedTag(name: name, line: line)
            }
            let body = rest[bodyStart ..< close.lowerBound].trimmingCharacters(in: .whitespaces)
            guard !body.isEmpty else { throw Error.emptyTag(name: name, line: line) }

            nodes.append(try node(for: body, raw: isRaw, template: name))
            rest = rest[close.upperBound...]
        }
        if !rest.isEmpty {
            nodes.append(.text(String(rest)))
        }
        return merged(nodes)
    }

    private static func node(for body: String, raw: Bool, template: String) throws -> Node {
        if raw { return .value(body, escaped: false) }
        if body.hasPrefix(">") {
            return .partial(body.dropFirst().trimmingCharacters(in: .whitespaces))
        }
        let words = body.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        switch words.first {
        case "icon":
            guard words.count >= 2, let icon = Icon.Name(rawValue: words[1]) else {
                throw Error.unknownIcon(words.dropFirst().first ?? "", template: template)
            }
            let numbers = try words.dropFirst(2).map { word -> Double in
                guard let number = Double(word) else { throw Error.badIconArgument(word, template: template) }
                return number
            }
            return .icon(icon, size: numbers.first ?? 20, stroke: numbers.dropFirst().first ?? 1.7)
        case "current":
            return .current(words.dropFirst().first ?? "/")
        default:
            return .value(body, escaped: true)
        }
    }

    /// Joins neighbouring text nodes so rendering appends fewer, larger strings.
    private static func merged(_ nodes: [Node]) -> [Node] {
        var result: [Node] = []
        for node in nodes {
            if case let .text(next) = node, case let .text(previous)? = result.last {
                result[result.count - 1] = .text(previous + next)
            } else {
                result.append(node)
            }
        }
        return result
    }
}
