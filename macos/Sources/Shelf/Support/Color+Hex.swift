import SwiftUI

extension Color {
    /// Creates a colour from "#RRGGBB" (the format Shelf stores Space and shelf colours in).
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: digits).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum ShelfPalette {
    /// Colours offered when creating a Space or shelf.
    static let choices = ["#E4572E", "#5E9C7E", "#E9B44C", "#7FA7D9", "#8A5CD6", "#3F7BD0", "#C7431D", "#8B939C"]
}
