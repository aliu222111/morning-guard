import SwiftUI

// These match the Color("Name") references throughout the app.
// Add these as named colors in Assets.xcassets,
// or use this extension for SwiftUI previews and testing.

extension Color {
    // Warm sunrise orange — primary accent
    static let sunrise    = Color(red: 0.88, green: 0.47, blue: 0.19)
    // Deep warm brown — primary text
    static let warmBrown  = Color(red: 0.47, green: 0.28, blue: 0.12)
    // Muted golden tan — secondary text
    static let warmTan    = Color(red: 0.69, green: 0.47, blue: 0.25)
    // Pale blush — top gradient
    static let dawnPink   = Color(red: 0.99, green: 0.93, blue: 0.84)
    // Warm cream — bottom gradient / background
    static let morningCream = Color(red: 1.0, green: 0.98, blue: 0.96)
    // Muted gold — card background tint
    static let cardGold   = Color(red: 0.98, green: 0.84, blue: 0.63)
    // Active pill green
    static let pillGreen  = Color(red: 0.87, green: 0.96, blue: 0.87)
    static let pillGreenText = Color(red: 0.18, green: 0.55, blue: 0.18)
}
