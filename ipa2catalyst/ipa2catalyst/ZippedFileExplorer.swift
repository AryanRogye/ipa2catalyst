import SwiftUI

struct ZippedFileExplorer: View {
    let fileInfo: DroppedFileInfo
    
    let hackerGreen = Color(red: 0, green: 0.9, blue: 0.1)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ANALYSIS_RESULTS")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(hackerGreen)

                Text("ALL_REQUIRED_OBJECTS_RESOLVED")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(hackerGreen.opacity(0.6))
            }

            VStack(spacing: 8) {
                resultRow(
                    title: "BUNDLE_PATH",
                    icon: "app.dashed",
                    url: fileInfo.app
                )

                resultRow(
                    title: "BINARY_ENTRY",
                    icon: "terminal.fill",
                    url: fileInfo.machO
                )

                resultRow(
                    title: "MANIFEST_XML",
                    icon: "list.bullet.rectangle.fill",
                    url: fileInfo.infoPlist
                )

                resultRow(
                    title: "TRUST_CHAIN",
                    icon: "checkmark.shield.fill",
                    url: fileInfo.codesig
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resultRow(
        title: String,
        icon: String,
        url: URL
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(hackerGreen)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(hackerGreen.opacity(0.6))

                Text(relativePath(for: url))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(hackerGreen)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(hackerGreen.opacity(0.05))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen.opacity(0.2), lineWidth: 1))
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

#Preview {
    let base = URL(fileURLWithPath: "/tmp/example/Payload/MyApp.app")
    let info = DroppedFileInfo(
        codesig: base.appendingPathComponent("_CodeSignature"),
        app: base,
        machO: base.appendingPathComponent("MyApp"),
        infoPlist: base.appendingPathComponent("Info.plist")
    )

    ZippedFileExplorer(fileInfo: info)
        .frame(width: 500)
        .padding()
        .background(Color.black)
}
