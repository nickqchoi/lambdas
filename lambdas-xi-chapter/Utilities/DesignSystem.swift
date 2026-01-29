//
//  DesignSystem.swift
//  lambdas-xi-chapter
//
//  Created by Antigravity on 25/01/2026.
//  Defines the centralized "Blue & White" theme values.
//

import SwiftUI

// MARK: - Images
extension Image {
    static let appLogo = Image("ChapterLogo")
}

// MARK: - Colors
extension Color {
    /// Primary Brand Blue (Action buttons, headers)
    static let appPrimary = Color(hex: "022FA2") // Brand Deep Blue
    
    /// Secondary Blue (Accents, active states)
    static let appSecondary = Color(hex: "5AC8FA")
    
    /// Main Background (Very Pale Blue)
    static let appBackground = Color(hex: "F0F4F8") // Soft Cloud
    
    /// Card Background (White)
    static let appCard = Color.white
    
    /// Primary Text (Dark Navy)
    static let appTextPrimary = Color(hex: "1A2B42")
    
    /// Secondary Text (Muted Blue-Gray)
    static let appTextSecondary = Color(hex: "5E6C84")
    
    /// Accent/Destructive
    static let appDestructive = Color(hex: "FF6B6B")
}

// MARK: - Layout Constants
struct DesignSystem {
    struct Radius {
        static let card: CGFloat = 20
        static let button: CGFloat = 14
        static let input: CGFloat = 12
    }
    
    struct Padding {
        static let standard: CGFloat = 20
        static let large: CGFloat = 32
        static let small: CGFloat = 12
    }
    
    struct Shadow {
        static let card = Color.black.opacity(0.05)
    }
}

// MARK: - View Modifiers
struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appCard)
            .cornerRadius(DesignSystem.Radius.card)
            .shadow(color: DesignSystem.Shadow.card, radius: 10, x: 0, y: 4)
    }
}

struct AppButtonStyle: ButtonStyle {
    let variant: Variant
    
    enum Variant {
        case primary
        case secondary
        case ghost
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(foreground(for: variant))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(background(for: variant))
            .cornerRadius(DesignSystem.Radius.button)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
    
    private func foreground(for variant: Variant) -> Color {
        switch variant {
        case .primary: return .white
        case .secondary: return .appPrimary
        case .ghost: return .appTextSecondary
        }
    }
    
    private func background(for variant: Variant) -> Color {
        switch variant {
        case .primary: return .appPrimary
        case .secondary: return .appPrimary.opacity(0.1)
        case .ghost: return .clear
        }
    }
}

// MARK: - Extensions
extension View {
    func appCardStyle() -> some View {
        modifier(AppCardStyle())
    }
    
    /// Standard large rounded header font
    func appHeaderFont() -> some View {
        self.font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundColor(.appTextPrimary)
    }
    
    /// Section header font
    func appSectionFont() -> some View {
        self.font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundColor(.appTextPrimary)
    }
}

// MARK: - Hex Color Helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
