import SwiftUI

/// Symbol + color faces for cards and tiles. The symbol alone distinguishes every face,
/// so color is never the only cue (REQ-AX-03).
enum Faces {
    static let all: [(symbol: String, name: LocalizedStringResource)] = [
        ("star.fill", "Star"), ("heart.fill", "Heart"), ("moon.fill", "Moon"),
        ("sun.max.fill", "Sun"), ("leaf.fill", "Leaf"), ("flame.fill", "Flame"),
        ("drop.fill", "Drop"), ("bolt.fill", "Bolt"), ("cloud.fill", "Cloud"),
        ("snowflake", "Snowflake"), ("pawprint.fill", "Paw"), ("fish.fill", "Fish"),
        ("bird.fill", "Bird"), ("tortoise.fill", "Tortoise"), ("hare.fill", "Hare"),
        ("crown.fill", "Crown"), ("bell.fill", "Bell"), ("key.fill", "Key"),
    ]

    /// Okabe–Ito palette minus black and yellow (yellow fails contrast on light cards).
    static let colors: [Color] = [
        Color(red: 0.90, green: 0.62, blue: 0.00), Color(red: 0.34, green: 0.71, blue: 0.91),
        Color(red: 0.00, green: 0.62, blue: 0.45),
        Color(red: 0.00, green: 0.45, blue: 0.70), Color(red: 0.84, green: 0.37, blue: 0.00),
        Color(red: 0.80, green: 0.47, blue: 0.65),
    ]

    static func symbol(_ i: Int) -> String { all[i % all.count].symbol }
    static func name(_ i: Int) -> String { String(localized: all[i % all.count].name) }
    static func color(_ i: Int) -> Color { colors[i % colors.count] }
}
