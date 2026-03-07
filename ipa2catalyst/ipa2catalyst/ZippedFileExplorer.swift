import SwiftUI

struct ZippedFileExplorer: View {
    let fileInfo: DroppedFileInfo
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.theme == .hacker ? 12 : 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.theme == .hacker ? "ANALYSIS_RESULTS" : "Analysis Results")
                    .font(themeManager.theme == .hacker ? .system(.headline, design: .monospaced) : .headline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)

                Text(themeManager.theme == .hacker ? "ALL_REQUIRED_OBJECTS_RESOLVED" : "All required paths are available now.")
                    .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.6) : .secondary)
            }

            VStack(spacing: 8) {
                resultRow(
                    title: themeManager.theme == .hacker ? "BUNDLE_PATH" : "App Bundle",
                    icon: "app.dashed",
                    url: fileInfo.app,
                    tint: .accentColor
                )

                resultRow(
                    title: themeManager.theme == .hacker ? "BINARY_ENTRY" : "Mach-O",
                    icon: "terminal.fill",
                    url: fileInfo.machO,
                    tint: .blue
                )

                resultRow(
                    title: themeManager.theme == .hacker ? "MANIFEST_XML" : "Info.plist",
                    icon: "list.bullet.rectangle.fill",
                    url: fileInfo.infoPlist,
                    tint: .orange
                )

                resultRow(
                    title: themeManager.theme == .hacker ? "TRUST_CHAIN" : "_CodeSignature",
                    icon: "checkmark.shield.fill",
                    url: fileInfo.codesig,
                    tint: .green
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultRow(
        title: String,
        icon: String,
        url: URL,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced).weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.6) : .secondary)

                Text(relativePath(for: url))
                    .font(themeManager.theme == .hacker ? .system(.callout, design: .monospaced) : .callout.monospaced())
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(themeBackground)
        .overlay(themeManager.theme == .hacker ? RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen.opacity(0.2), lineWidth: 1) : nil)
    }

    private var themeBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                themeManager.hackerGreen.opacity(0.05)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.background.opacity(0.55))
            }
        }
    }

    private func relativePath(for url: URL) -> String {
        let rootURL = fileInfo.app.deletingLastPathComponent().deletingLastPathComponent()
        let rootPath = rootURL.standardizedFileURL.path
        let fullPath = url.standardizedFileURL.path

        guard fullPath.hasPrefix(rootPath) else { return url.path }

        let relative = String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? url.lastPathComponent : relative
    }
}
