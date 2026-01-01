import SwiftUI
import UIKit

// MARK: - Digital Agency Design System (DADS) Tokens
// Mapping DADS roles to existing app assets to keep current visuals intact.

enum DADS {
    enum Colors {
        static let background = Tokens.Color.bg
        static let surface = Tokens.Color.cardBG
        static let border = Tokens.Color.stroke
        static let textPrimary = Tokens.Color.textPrimary
        static let textSecondary = Tokens.Color.textSecondary
        static let danger = Tokens.Color.dangerRed
    }

    enum Gradients {
        static let lecture = Tokens.Gradients.lecture
        static let meeting = Tokens.Gradients.meeting
        static let ai = Tokens.Gradients.ai
        static let brandX = Tokens.Gradients.brandX
    }

    enum Typography {
        static func brandTitle() -> Font { Tokens.Typography.brandTitle() }
        static func brandDate() -> Font { Tokens.Typography.brandDate() }
        static func screenTitle() -> Font { Tokens.Typography.screenTitle() }
        static func sectionTitle() -> Font { Tokens.Typography.sectionTitle() }
        static func body() -> Font { Tokens.Typography.body() }
        static func caption() -> Font { Tokens.Typography.caption() }
        static func dateCaps() -> Font { Tokens.Typography.dateCaps() }
        static func button() -> Font { Tokens.Typography.button() }
        static func tabLabel() -> Font { Tokens.Typography.tabLabel() }
        static func headline() -> Font { Tokens.Typography.headline() }
        static func primaryTitle() -> Font { Tokens.Typography.primaryTitle() }
        static func subtitle() -> Font { Tokens.Typography.subtitle() }
        static func modePill() -> Font { Tokens.Typography.modePill() }
    }

    enum Spacing {
        static let horizontalPadding = Tokens.Spacing.screenHorizontal
        static let cardPadding = Tokens.Spacing.cardContent
        static let sectionSpacing = Tokens.Spacing.lg
        static let itemSpacing = Tokens.Spacing.xs
        static let tabBarHeight = Tokens.Spacing.tabBarHeight
        static let tabBarBottomPadding: CGFloat = 0
    }

    enum Radius {
        static let card = Tokens.Radius.card
        static let pill = Tokens.Radius.pill
        static let tabBarPill = Tokens.Radius.tabBarPill
        static let small = Tokens.Radius.small
        static let circle = Tokens.Radius.circle
    }

    enum Shadows {
        typealias Config = Tokens.Shadows.Config

        static func card(for scheme: ColorScheme) -> Config {
            Tokens.Shadows.card(for: scheme)
        }

        static func primaryButton(for scheme: ColorScheme) -> Config {
            Tokens.Shadows.primaryButton(for: scheme)
        }

        static func glow(color: SwiftUI.Color, for scheme: ColorScheme) -> Config {
            Tokens.Shadows.glow(color: color, for: scheme)
        }
    }

    enum Blur {
        static func tabBar(for scheme: ColorScheme) -> UIBlurEffect.Style {
            Tokens.Blur.tabBar(for: scheme)
        }

        static func card(for scheme: ColorScheme) -> UIBlurEffect.Style {
            Tokens.Blur.card(for: scheme)
        }
    }
}
