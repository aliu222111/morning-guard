import SwiftUI
import UIKit

// These match the Color("Name") references throughout the app.
// Add these as named colors in Assets.xcassets,
// or use this extension for SwiftUI previews and testing.

extension Color {
    // Warm sunrise orange — primary accent
    static let sunrise    = Color(red: 0.88, green: 0.47, blue: 0.19)
    // Deep warm brown — primary text
    static let warmBrown  = Color(red: 0.47, green: 0.28, blue: 0.12)
    // Muted golden tan — decorative / borders
    static let warmTan    = Color(red: 0.69, green: 0.47, blue: 0.25)

    // MARK: - Adaptive semantic tokens (light / dark)

    /// Card / surface fill. Light = white; dark = a warm espresso brown
    /// (not pure black) so the dark theme stays cozy.
    static let appCardFill = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.13, blue: 0.10, alpha: 1)
            : .white
    })

    /// Primary text. Light = deep warm brown; dark = warm cream.
    static let appPrimaryText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.92, blue: 0.85, alpha: 1)
            : UIColor(red: 0.47, green: 0.28, blue: 0.12, alpha: 1)
    })

    // Readable secondary text — adaptive.
    // Light = current dark brown; dark = a soft light warm gray.
    static let secondaryText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.78, green: 0.72, blue: 0.64, alpha: 1)
            : UIColor(red: 0.40, green: 0.30, blue: 0.20, alpha: 1)
    })
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

extension Font {
    /// A bundled custom font that scales with Dynamic Type by anchoring its
    /// fixed point size to the closest text style. Use everywhere instead of
    /// `.custom(name, size:)` so text grows for users with larger text settings.
    static func mg(_ name: String, _ size: CGFloat) -> Font {
        let style: Font.TextStyle
        switch size {
        case ..<13:  style = .caption2
        case ..<15:  style = .footnote
        case ..<17:  style = .subheadline
        case ..<20:  style = .body
        case ..<24:  style = .title3
        case ..<30:  style = .title2
        case ..<40:  style = .title
        default:     style = .largeTitle
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
