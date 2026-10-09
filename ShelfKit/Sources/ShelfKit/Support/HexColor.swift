import Foundation

/// An sRGB colour stored as "#RRGGBB", the format Shelf uses for Space and shelf colours.
public struct HexColor: Hashable, Sendable, CustomStringConvertible {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
    }

    /// Parses "#RRGGBB", "RRGGBB" or the short "#RGB". Returns `nil` for anything else.
    public init?(_ string: String) {
        var digits = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// "#E4572E".
    public var description: String {
        let components = [red, green, blue].map { Int(($0 * 255).rounded()) }
        return "#" + components.map { component in
            let hex = String(component, radix: 16, uppercase: true)
            return hex.count == 1 ? "0" + hex : hex
        }.joined()
    }

    /// WCAG relative luminance, 0 (black) to 1 (white).
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// Whether white text reads better than dark text on this colour (badges on file tiles, the
    /// active Space row in the menu).
    public var prefersLightForeground: Bool {
        let whiteContrast = 1.05 / (luminance + 0.05)
        let blackContrast = (luminance + 0.05) / 0.05
        return whiteContrast >= blackContrast
    }
}
