import SwiftUI

struct Theme {
    let colorScheme: ColorScheme
    
    var tokens: Tokens.Type { Tokens.self }
    
    // Computed logic can go here if we need distinct themes per mode beyond asset catalog
}

struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = Theme(colorScheme: .light)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
