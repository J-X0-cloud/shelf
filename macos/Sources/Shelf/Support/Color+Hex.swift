import ShelfKit
import SwiftUI

extension Color {
    /// Creates a colour from "#RRGGBB" (the format Shelf stores Space and shelf colours in).
    /// Unreadable values fall back to Shelf's neutral grey.
    init(hex: String) {
        let color = HexColor(hex) ?? HexColor("#8B939C")!
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: 1)
    }

    /// Text colour that stays readable on top of `hex`.
    static func foreground(on hex: String) -> Color {
        (HexColor(hex)?.prefersLightForeground ?? true) ? .white : Color(hex: "#1B1916")
    }
}
