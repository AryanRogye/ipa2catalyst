import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case regular = "Regular"
    case hacker = "Hacker"
}

class ThemeManager: ObservableObject {
    @Published var theme: AppTheme {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
        }
    }
    
    static let shared = ThemeManager()
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.hacker.rawValue
        self.theme = AppTheme(rawValue: savedTheme) ?? .hacker
    }
    
    // Hacker Colors
    let hackerGreen = Color(red: 0, green: 0.9, blue: 0.1)
    let hackerDark = Color(red: 0.05, green: 0.05, blue: 0.05)
    let hackerBorder = Color(red: 0, green: 0.5, blue: 0.1).opacity(0.4)
}
