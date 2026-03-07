import SwiftUI

struct ContentView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showSettings = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            DropZoneView()
                .frame(width: 968, height: 528)
            
            Button(action: { withAnimation { showSettings.toggle() } }) {
                Image(systemName: themeManager.theme == .hacker ? "command" : "gearshape")
                    .font(.title3)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .secondary)
                    .padding(16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showSettings {
                settingsOverlay
            }
        }
        .background(themeManager.theme == .hacker ? themeManager.hackerDark : Color(NSColor.windowBackgroundColor))
    }
    
    private var settingsOverlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(themeManager.theme == .hacker ? "[ SYSTEM_PREFERENCES ]" : "Settings")
                    .font(themeManager.theme == .hacker ? .system(.headline, design: .monospaced) : .headline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
                
                Spacer()
                
                Button(action: { withAnimation { showSettings = false } }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .background(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.3) : Color.gray.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 10) {
                Text(themeManager.theme == .hacker ? "UI_INTERFACE_THEME" : "Interface Theme")
                    .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.7) : .secondary)
                
                Picker("", selection: $themeManager.theme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.rawValue.uppercased())
                            .tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            Spacer()
            
            Text(themeManager.theme == .hacker ? "IPA2CATALYST_V0.1_STABLE" : "ipa2catalyst v0.1")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.4) : .secondary.opacity(0.5))
        }
        .padding(20)
        .frame(width: 280)
        .frame(maxHeight: .infinity)
        .background(themeManager.theme == .hacker ? themeManager.hackerDark.opacity(0.95) : Color(NSColor.windowBackgroundColor).opacity(0.95))
        .background(.ultraThinMaterial)
        .overlay(themeManager.theme == .hacker ? 
                 Rectangle().stroke(themeManager.hackerGreen.opacity(0.3), lineWidth: 1) : 
                 nil)
        .overlay(themeManager.theme == .regular ? 
                 Rectangle().stroke(Color.primary.opacity(0.1), lineWidth: 1) : 
                 nil)
        .transition(.move(edge: .trailing))
        .shadow(color: .black.opacity(0.3), radius: 20, x: -10)
    }
}
