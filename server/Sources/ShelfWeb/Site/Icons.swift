import Foundation

/// The site's 24px line icons (the same set the old React `Icon` component drew). Colour follows
/// `currentColor`; size and stroke width are set per use from templates with `{{icon name size stroke}}`.
public enum Icon {
    public enum Name: String, CaseIterable, Sendable {
        case shelves, spaces, rules, stash, key, lock, bolt, display, dock, search
        case check, arrow, down, sync, link, eye, plus, mail, book, wand, star
    }

    /// Inline SVG for an icon, hidden from assistive technology (icons sit next to text that says the same).
    public static func svg(_ name: Name, size: Double = 20, strokeWidth: Double = 1.7) -> String {
        let size = format(size)
        return #"<svg width="\#(size)" height="\#(size)" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="\#(format(strokeWidth))" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">\#(shapes(name))</svg>"#
    }

    /// "2" rather than "2.0", "1.7" stays "1.7".
    static func format(_ number: Double) -> String {
        number.rounded() == number ? String(Int(number)) : String(number)
    }

    static func shapes(_ name: Name) -> String {
        switch name {
        case .shelves: #"<path d="M3 9h18M3 19h18"></path><rect x="5" y="4" width="4" height="5" rx="1"></rect><rect x="11" y="3" width="3" height="6" rx="1"></rect><rect x="6" y="13" width="6" height="6" rx="1"></rect><rect x="15" y="15" width="4" height="4" rx="1"></rect>"#
        case .spaces: #"<rect x="3" y="4" width="8" height="7" rx="2"></rect><rect x="13" y="4" width="8" height="7" rx="2"></rect><rect x="3" y="13" width="8" height="7" rx="2"></rect><rect x="13" y="13" width="8" height="7" rx="2"></rect>"#
        case .rules: #"<path d="M4 6h10M4 12h7M4 18h10"></path><path d="m16 10 4 2-4 2"></path>"#
        case .stash: #"<path d="M4 7h16l-1.5 11a2 2 0 0 1-2 1.7h-9a2 2 0 0 1-2-1.7Z"></path><path d="M9 11h6"></path><path d="M8 4h8"></path>"#
        case .key: #"<rect x="2.5" y="6" width="19" height="12" rx="2.5"></rect><path d="M6.5 10h.01M10 10h.01M13.5 10h.01M17 10h.01M7 14h10"></path>"#
        case .lock: #"<rect x="4.5" y="10.5" width="15" height="10" rx="2.5"></rect><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"></path>"#
        case .bolt: #"<path d="M13 2 4.5 13.5H11l-1 8.5 8.5-11.5H12Z"></path>"#
        case .display: #"<rect x="2.5" y="4" width="13" height="10" rx="1.5"></rect><rect x="17.5" y="7" width="4" height="9" rx="1"></rect><path d="M6 18h6M9 14v4"></path>"#
        case .dock: #"<rect x="3" y="15" width="18" height="5" rx="2"></rect><rect x="6" y="11" width="4" height="4" rx="1"></rect><rect x="14" y="11" width="4" height="4" rx="1"></rect><path d="M12 4v5M9.5 6.5 12 9l2.5-2.5"></path>"#
        case .search: #"<circle cx="11" cy="11" r="6.5"></circle><path d="m20 20-4.2-4.2"></path>"#
        case .check: #"<path d="m5 12.5 4.5 4.5L19 7.5"></path>"#
        case .arrow: #"<path d="M5 12h14M13 6l6 6-6 6"></path>"#
        case .down: #"<path d="M12 4v12M6.5 10.5 12 16l5.5-5.5M5 20h14"></path>"#
        case .sync: #"<path d="M20 11a8 8 0 0 0-14.3-4.3L4 8.5"></path><path d="M4 4v4.5h4.5"></path><path d="M4 13a8 8 0 0 0 14.3 4.3L20 15.5"></path><path d="M20 20v-4.5h-4.5"></path>"#
        case .link: #"<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"></path><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"></path>"#
        case .eye: #"<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"></path><circle cx="12" cy="12" r="2.8"></circle>"#
        case .plus: #"<path d="M12 5v14M5 12h14"></path>"#
        case .mail: #"<rect x="3" y="5" width="18" height="14" rx="2.5"></rect><path d="m4 7 8 6 8-6"></path>"#
        case .book: #"<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5Z"></path><path d="M4 20.5A2.5 2.5 0 0 0 6.5 23H20v-5"></path>"#
        case .wand: #"<path d="m4 20 11-11M14 4v3M19 9h3M17.5 5.5l2-2M9 4l.8 1.7L11.5 6.5 9.8 7.3 9 9l-.8-1.7L6.5 6.5l1.7-.8Z"></path>"#
        case .star: #"<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9Z"></path>"#
        }
    }
}
