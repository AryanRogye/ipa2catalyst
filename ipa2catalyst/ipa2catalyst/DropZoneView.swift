import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isTargeted = false
    @State private var droppedFile: URL?
    @State private var analyzedFileInfo: DroppedFileInfo?
    @State private var isProcessingDrop = false
    @State private var isConverting = false
    @State private var errorState: DropZoneErrorState?
    @State private var conversionStatus = ConversionStatus()

    let dropAnalayzer = DropFileAnalyzer()
    let unzipService = UnzipService()

    var body: some View {
        HStack(spacing: 16) {
            dropPane
                .frame(width: 320)

            infoPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.theme == .hacker ? themeManager.hackerDark : Color.clear)
    }

    private var dropPane: some View {
        contentStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .background(dropPaneBackground)
            .overlay(dropPaneBorder)
            .contentShape(RoundedRectangle(cornerRadius: themeManager.theme == .hacker ? 8 : 16, style: .continuous))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: handleDrop)
            .animation(.spring(duration: 0.3), value: isTargeted)
            .animation(.default, value: isProcessingDrop)
            .animation(.spring, value: droppedFile)
            .alert(themeManager.theme == .hacker ? "SYSTEM ERROR" : "Drop Error", isPresented: alertIsPresented, presenting: errorState) { _ in
                Button("OK") { errorState = nil }
            } message: { errorState in
                Text(errorState.message)
            }
    }

    private var infoPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            infoPaneHeader
            
            infoPaneContent

            if let errorState {
                errorBanner(errorState)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(infoPaneBackground)
        .overlay(infoPaneBorder)
    }
    
    private var infoPaneHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.theme == .hacker ? "[ SYSTEM_LOG ]" : "Info")
                    .font(themeManager.theme == .hacker ? .system(.headline, design: .monospaced) : .headline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)

                Text(infoSubtitleText)
                    .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.6) : .secondary)
            }

            Spacer()

            if let analyzedFileInfo {
                revealButton(for: analyzedFileInfo)
            }
        }
    }
    
    @ViewBuilder
    private func revealButton(for info: DroppedFileInfo) -> some View {
        if themeManager.theme == .hacker {
            Button(action: { openDirectory(info.app) }) {
                Label("REVEAL_BUNDLE", systemImage: "folder")
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.hackerGreen.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen, lineWidth: 1))
                    .foregroundStyle(themeManager.hackerGreen)
            }
            .buttonStyle(.plain)
            .disabled(isProcessingDrop)
        } else {
            Button(action: { openDirectory(info.app) }) {
                Label("Reveal App", systemImage: "folder")
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessingDrop)
        }
    }
    
    private var infoPaneContent: some View {
        ScrollView {
            Group {
                if let analyzedFileInfo {
                    VStack(alignment: .leading, spacing: 14) {
                        ZippedFileExplorer(fileInfo: analyzedFileInfo)
                        conversionPanel
                    }
                } else {
                    infoPlaceholder
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var contentStack: some View {
        VStack(spacing: themeManager.theme == .hacker ? 20 : 16) {
            ZStack {
                Image(systemName: isProcessingDrop ? 
                      (themeManager.theme == .hacker ? "terminal.fill" : "arrow.clockwise.circle.fill") : 
                      (themeManager.theme == .hacker ? "network" : "square.and.arrow.down.on.square.fill"))
                    .symbolRenderingMode(themeManager.theme == .hacker ? .monochrome : .hierarchical)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : (isTargeted ? Color.accentColor : .secondary))
                    .font(.system(size: themeManager.theme == .hacker ? 44 : 38, weight: .regular))
                    .symbolEffect(.bounce, value: isTargeted)
                    .symbolEffect(.variableColor.iterative, value: isProcessingDrop)
                
                if themeManager.theme == .hacker && isTargeted {
                    Circle()
                        .stroke(themeManager.hackerGreen, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isTargeted ? 1.2 : 1.0)
                        .opacity(isTargeted ? 0.5 : 0)
                }
            }

            VStack(spacing: themeManager.theme == .hacker ? 8 : 6) {
                Text(themeManager.theme == .hacker ? titleText.uppercased() : titleText)
                    .font(themeManager.theme == .hacker ? .system(.headline, design: .monospaced) : .headline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)

                Text(subtitleText)
                    .font(themeManager.theme == .hacker ? .system(.subheadline, design: .monospaced) : .subheadline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.7) : .secondary)
                    .multilineTextAlignment(.center)
            }

            if let file = droppedFile {
                fileInfoTag(file: file)
            }

            if droppedFile != nil {
                actionRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func fileInfoTag(file: URL) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.zipper")
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .secondary)
            Text(file.lastPathComponent)
                .font(themeManager.theme == .hacker ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, themeManager.theme == .hacker ? 8 : 6)
        .background(fileInfoBackground)
        .overlay(Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen.opacity(0.3), lineWidth: 1)
            }
        })
        .transition(.scale.combined(with: .opacity))
    }

    private var fileInfoBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                themeManager.hackerGreen.opacity(0.1)
            } else {
                Capsule().fill(.quaternary.opacity(0.5))
            }
        }
    }

    private var actionRow: some View {
        Group {
            if themeManager.theme == .hacker {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        hackerButton(
                            label: isProcessingDrop ? "ANALYZING..." : "ANALYZE_IPA",
                            icon: "magnifyingglass",
                            primary: true,
                            action: analyzeDroppedFile,
                            disabled: isBusy || droppedFile == nil
                        )

                        if analyzedFileInfo != nil {
                            hackerButton(
                                label: isConverting ? "CONVERTING..." : "PATCH_BINARY",
                                icon: "gearshape.2",
                                primary: true,
                                action: convertAnalyzedApp,
                                disabled: isBusy
                            )
                        }
                    }
                    
                    HStack(spacing: 10) {
                        hackerButton(
                            label: "CLEAR_BUFFER",
                            icon: "trash",
                            primary: false,
                            action: clearState,
                            disabled: isBusy
                        )
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button(action: analyzeDroppedFile) {
                        Label(isProcessingDrop ? "Analyzing..." : "Analyze", systemImage: "magnifyingglass")
                            .frame(minWidth: 110)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isBusy || droppedFile == nil)

                    if analyzedFileInfo != nil {
                        Button(action: convertAnalyzedApp) {
                            Label(isConverting ? "Converting..." : "Convert", systemImage: "gearshape.2")
                                .frame(minWidth: 110)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isBusy)
                    }

                    Button("Clear") { clearState() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(isBusy)
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func clearState() {
        withAnimation {
            droppedFile = nil
            analyzedFileInfo = nil
            errorState = nil
            conversionStatus = ConversionStatus()
        }
    }
    
    private func hackerButton(label: String, icon: String, primary: Bool, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minWidth: 140)
                .background(primary ? themeManager.hackerGreen : Color.clear)
                .foregroundStyle(primary ? themeManager.hackerDark : themeManager.hackerGreen)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen, lineWidth: 1))
                .opacity(disabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var dropPaneBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                hackerDropPaneBackground
            } else {
                regularDropPaneBackground
            }
        }
    }
    
    private var hackerDropPaneBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(themeManager.hackerDark)
                .shadow(color: themeManager.hackerGreen.opacity(0.1), radius: 10, y: 0)

            if isTargeted {
                themeManager.hackerGreen.opacity(0.05)
            }
            
            Canvas { context, size in
                let step: CGFloat = 20
                for x in stride(from: 0, through: size.width, by: step) {
                    context.stroke(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(themeManager.hackerGreen.opacity(0.03)))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(themeManager.hackerGreen.opacity(0.03)))
                }
            }
        }
    }
    
    private var regularDropPaneBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, y: 4)

            if isTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.05))
            }
        }
    }

    private var dropPaneBorder: some View {
        Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isTargeted ? themeManager.hackerGreen : themeManager.hackerBorder,
                        lineWidth: isTargeted ? 2 : 1
                    )
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.primary.opacity(0.1),
                        style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [6, 4])
                    )
            }
        }
    }

    private var infoPaneBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(themeManager.hackerDark.opacity(0.8))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: 10, y: 4)
            }
        }
    }

    private var infoPaneBorder: some View {
        Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(themeManager.hackerBorder, lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var infoPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(themeManager.theme == .hacker ? "AWAITING_DATA_STREAM" : "Waiting for analysis", 
                  systemImage: themeManager.theme == .hacker ? "bolt.horizontal.fill" : "sparkle.magnifyingglass")
                .font(themeManager.theme == .hacker ? .system(.callout, design: .monospaced).weight(.semibold) : .callout.weight(.semibold))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .secondary)

            Text(themeManager.theme == .hacker ? 
                 "Feed .ipa or .zip archive to the input buffer. Initiate analysis to resolve Mach-O architecture and entitlement trees." :
                 "Drop an `.ipa` or `.zip` on the left, then choose Analyze. The app bundle, Mach-O, Info.plist, and _CodeSignature will appear here.")
                .font(themeManager.theme == .hacker ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.6) : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let droppedFile {
                Divider()
                    .background(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.2) : Color.gray.opacity(0.2))
                detailTag(label: themeManager.theme == .hacker ? "SOURCE_URI" : "Loaded Archive", value: droppedFile.lastPathComponent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(infoPlaceholderBackground)
        .overlay(Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen.opacity(0.1), lineWidth: 1)
            }
        })
    }

    private var infoPlaceholderBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                themeManager.hackerGreen.opacity(0.03)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background.opacity(0.45))
            }
        }
    }

    private var conversionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            conversionPanelHeader

            VStack(spacing: themeManager.theme == .hacker ? 10 : 8) {
                statusRow(title: themeManager.theme == .hacker ? "ENTITLEMENT_GENERATION" : "Entitlements", state: conversionStatus.createdEntitlements)
                statusRow(title: themeManager.theme == .hacker ? "PLIST_PATCHING" : "Plist Modified", state: conversionStatus.modifiedPlist)
                statusRow(title: themeManager.theme == .hacker ? "BINARY_STAMPING" : "Binary Patched", state: conversionStatus.patchedBinary)
                statusRow(title: themeManager.theme == .hacker ? "CODE_SIG_FLUSH" : "Code Signature Removed", state: conversionStatus.removedCodeSig)
                countRow(title: themeManager.theme == .hacker ? "MACHO_COLLECTION" : "Mach-Os Collected", count: conversionStatus.collectingMachOsCount, done: conversionStatus.doneCollectingMachos)
                progressRow(title: themeManager.theme == .hacker ? "ARCH_PATCHING" : "Mach-Os Stamped", current: conversionStatus.stampingCurrent, total: conversionStatus.stampingTotal, done: conversionStatus.doneStamping)
                countRow(title: themeManager.theme == .hacker ? "DYLIB_EXTRACTION" : "Libraries Collected", count: conversionStatus.libCollectingCount, done: conversionStatus.libCollectionDone)
                progressRow(title: themeManager.theme == .hacker ? "DYLIB_SIGNING" : "Libraries Signed", current: conversionStatus.libSigningCurrent, total: conversionStatus.libSigningTotal, done: conversionStatus.libSigningDone)
                countRow(title: themeManager.theme == .hacker ? "BUNDLE_COLLECTION" : "Bundles Collected", count: conversionStatus.bundleCollectingCount, done: conversionStatus.bundleCollectionDone)
                progressRow(title: themeManager.theme == .hacker ? "BUNDLE_SIGNING" : "Bundles Signed", current: conversionStatus.bundleSigningCurrent, total: conversionStatus.bundleSigningTotal, done: conversionStatus.bundleSigningDone)
                statusRow(title: themeManager.theme == .hacker ? "FINAL_BUNDLE_SIGN" : "App Signed", state: conversionStatus.signedApp)
            }
        }
        .padding(14)
        .background(conversionPanelBackground)
        .overlay(Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 4).stroke(themeManager.hackerGreen.opacity(0.1), lineWidth: 1)
            }
        })
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    private var conversionPanelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(themeManager.theme == .hacker ? "CONVERSION_SEQUENCE" : "Conversion")
                    .font(themeManager.theme == .hacker ? .system(.headline, design: .monospaced) : .headline)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
                Text(conversionSubtitleText)
                    .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.5) : .secondary)
            }

            Spacer()

            if conversionStatus.signedApp {
                conversionSuccessIndicator
            } else if isConverting {
                ProgressView()
                    .tint(themeManager.theme == .hacker ? themeManager.hackerGreen : .accentColor)
                    .controlSize(.small)
            }
        }
    }
    
    @ViewBuilder
    private var conversionSuccessIndicator: some View {
        if themeManager.theme == .hacker {
            Text("SUCCESS")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(themeManager.hackerGreen)
        } else {
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    private var conversionPanelBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                themeManager.hackerGreen.opacity(0.03)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.background.opacity(0.45))
            }
        }
    }

    private func statusRow(title: String, state: Bool) -> some View {
        HStack {
            Text(title)
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced).weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.7) : .secondary)
            Spacer()
            if themeManager.theme == .hacker {
                Text(state ? "[ DONE ]" : "[ .... ]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(state ? themeManager.hackerGreen : themeManager.hackerGreen.opacity(0.3))
            } else {
                Image(systemName: state ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(state ? .green : .secondary.opacity(0.5))
            }
        }
    }

    private func countRow(title: String, count: Int, done: Bool) -> some View {
        HStack {
            Text(title)
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced).weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.7) : .secondary)
            Spacer()
            Text(themeManager.theme == .hacker ? String(format: "%03d", count) : "\(count)")
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption.monospacedDigit())
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
            if themeManager.theme == .hacker {
                Text(done ? "[ OK ]" : "[ .. ]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(done ? themeManager.hackerGreen : themeManager.hackerGreen.opacity(0.3))
            } else {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? .green : .secondary.opacity(0.5))
            }
        }
    }

    private func progressRow(title: String, current: Int, total: Int, done: Bool) -> some View {
        HStack {
            Text(title)
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced).weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.7) : .secondary)
            Spacer()
            Text(total > 0 ? "\(current)/\(total)" : "\(current)")
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption.monospacedDigit())
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
            if themeManager.theme == .hacker {
                Text(done ? "[ OK ]" : "[ .. ]")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(done ? themeManager.hackerGreen : themeManager.hackerGreen.opacity(0.3))
            } else {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? .green : .secondary.opacity(0.5))
            }
        }
    }

    private func detailTag(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced).weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen.opacity(0.6) : .secondary)
            Text(value)
                .font(themeManager.theme == .hacker ? .system(.callout, design: .monospaced) : .callout.monospaced())
                .foregroundStyle(themeManager.theme == .hacker ? themeManager.hackerGreen : .primary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private var subtitleText: String {
        if isProcessingDrop {
            return themeManager.theme == .hacker ? "Executing pre-flight checks on archive..." : "Please wait while the archive is being prepared"
        }
        if isConverting {
            return themeManager.theme == .hacker ? "Applying patches to executable segments..." : "Converting the app. Review live progress on the right."
        }
        if analyzedFileInfo != nil {
            return themeManager.theme == .hacker ? "Archive parsed successfully. Ready for injection." : "Analysis complete. Review the info panel."
        }
        if droppedFile != nil {
            return themeManager.theme == .hacker ? "Payload loaded into primary buffer." : "File loaded. Review it, then choose Analyze"
        }
        return themeManager.theme == .hacker ? "Waiting for .ipa or .zip payload..." : "Drag and drop a .ipa or .zip file here"
    }

    private var titleText: String {
        if isProcessingDrop {
            return "Processing..."
        }
        if isConverting {
            return "Injecting..."
        }
        if analyzedFileInfo != nil {
            return themeManager.theme == .hacker ? "Status: Ready" : "Analysis ready"
        }
        if droppedFile != nil {
            return themeManager.theme == .hacker ? "Buffer: Loaded" : "File loaded"
        }
        return themeManager.theme == .hacker ? "System Idle" : "Drop file to analyze"
    }

    private var infoSubtitleText: String {
        if isProcessingDrop {
            return themeManager.theme == .hacker ? "Resolving bundle identifiers and binary headers" : "Resolving the app bundle and required files"
        }
        if isConverting {
            return themeManager.theme == .hacker ? "Live kernel conversion output" : "Live conversion progress"
        }
        if analyzedFileInfo != nil {
            return themeManager.theme == .hacker ? "Bundle metadata extracted successfully" : "Primary bundle paths resolved"
        }
        return themeManager.theme == .hacker ? "System logs awaiting input" : "Analysis details will appear here"
    }

    private var conversionSubtitleText: String {
        if isConverting {
            return themeManager.theme == .hacker ? "Running ipa2catalyst.core.pipeline" : "Processing callbacks from ipa2catalystConversion.convert"
        }
        if conversionStatus.signedApp {
            return themeManager.theme == .hacker ? "Sequence terminated: Clean exit" : "Conversion callbacks completed"
        }
        return themeManager.theme == .hacker ? "Execute sequence to begin patching" : "Press Convert to run the conversion pipeline"
    }

    private var isBusy: Bool {
        isProcessingDrop || isConverting
    }

    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { errorState != nil },
            set: { isPresented in
                if !isPresented {
                    errorState = nil
                }
            }
        )
    }

    private func errorBanner(_ errorState: DropZoneErrorState) -> some View {
        HStack(spacing: 6) {
            Image(systemName: themeManager.theme == .hacker ? "exclamationmark.terminal.fill" : "exclamationmark.triangle.fill")
            Text(themeManager.theme == .hacker ? errorState.message.uppercased() : errorState.message)
        }
        .font(themeManager.theme == .hacker ? .system(.caption, design: .monospaced) : .caption)
        .foregroundStyle(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, themeManager.theme == .hacker ? 8 : 6)
        .background(errorBannerBackground)
        .overlay(Group {
            if themeManager.theme == .hacker {
                RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.5), lineWidth: 1)
            }
        })
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var errorBannerBackground: some View {
        Group {
            if themeManager.theme == .hacker {
                Color.red.opacity(0.1)
            } else {
                Capsule().fill(.red.opacity(0.1))
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !isBusy else { return false }

        isProcessingDrop = true
        isTargeted = false
        errorState = nil
        analyzedFileInfo = nil
        conversionStatus = ConversionStatus()

        Task {
            do {
                let result = try await dropAnalayzer.handleInitialDrop(providers: providers)

                await MainActor.run {
                    withAnimation {
                        isProcessingDrop = false
                        guard result.0, let fileURL = result.1 else { return }
                        droppedFile = fileURL
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isProcessingDrop = false
                        errorState = DropZoneErrorState(error: error)
                    }
                }
            }
        }

        return true
    }

    private func analyzeDroppedFile() {
        guard !isBusy, let droppedFile else { return }

        isProcessingDrop = true
        errorState = nil
        analyzedFileInfo = nil
        conversionStatus = ConversionStatus()

        Task {
            do {
                guard let analyzedFileInfo = try await unzipService.unzip(file: droppedFile) else {
                    throw DropZoneUIError.analysisIncomplete
                }

                await MainActor.run {
                    withAnimation {
                        isProcessingDrop = false
                        self.analyzedFileInfo = analyzedFileInfo
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        isProcessingDrop = false
                        errorState = DropZoneErrorState(error: error)
                    }
                }
            }
        }
    }

    private func convertAnalyzedApp() {
        guard !isBusy, let analyzedFileInfo else { return }

        isConverting = true
        errorState = nil
        conversionStatus = ConversionStatus()

        let converter = ipa2catalystConversion(info: analyzedFileInfo)

        Task {
            do {
                try await converter.convert(
                    createdEntitlements: { value in
                        Task { @MainActor in conversionStatus.createdEntitlements = value }
                    },
                    modifiedPlist: { value in
                        Task { @MainActor in conversionStatus.modifiedPlist = value }
                    },
                    patchedBinary: { value in
                        Task { @MainActor in conversionStatus.patchedBinary = value }
                    },
                    removedCodeSig: { value in
                        Task { @MainActor in conversionStatus.removedCodeSig = value }
                    },
                    collectingMachOs: { count in
                        Task { @MainActor in conversionStatus.collectingMachOsCount = count }
                    },
                    doneCollectingMachos: { value in
                        Task { @MainActor in conversionStatus.doneCollectingMachos = value }
                    },
                    stampingProgress: { current, total in
                        Task { @MainActor in
                            conversionStatus.stampingCurrent = current
                            conversionStatus.stampingTotal = total
                        }
                    },
                    doneStamping: { value in
                        Task { @MainActor in conversionStatus.doneStamping = value }
                    },
                    libCollecting: { count in
                        Task { @MainActor in conversionStatus.libCollectingCount = count }
                    },
                    libCollectionDone: { value in
                        Task { @MainActor in conversionStatus.libCollectionDone = value }
                    },
                    libSigningProgress: { current, total in
                        Task { @MainActor in
                            conversionStatus.libSigningCurrent = current
                            conversionStatus.libSigningTotal = total
                        }
                    },
                    libSigningDone: { value in
                        Task { @MainActor in conversionStatus.libSigningDone = value }
                    },
                    bundleCollecting: { count in
                        Task { @MainActor in conversionStatus.bundleCollectingCount = count }
                    },
                    bundleCollectionDone: { value in
                        Task { @MainActor in conversionStatus.bundleCollectionDone = value }
                    },
                    bundleSigningProg: { current, total in
                        Task { @MainActor in
                            conversionStatus.bundleSigningCurrent = current
                            conversionStatus.bundleSigningTotal = total
                        }
                    },
                    bundleSigningDone: { value in
                        Task { @MainActor in conversionStatus.bundleSigningDone = value }
                    },
                    signedApp: { value in
                        Task { @MainActor in conversionStatus.signedApp = value }
                    }
                )

                await MainActor.run {
                    isConverting = false
                }
            } catch {
                await MainActor.run {
                    isConverting = false
                    errorState = DropZoneErrorState(error: error)
                }
            }
        }
    }

    private func openDirectory(_ directory: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}

private enum DropZoneUIError: Error {
    case analysisIncomplete
}

private struct ConversionStatus {
    var createdEntitlements = false
    var modifiedPlist = false
    var patchedBinary = false
    var removedCodeSig = false

    var collectingMachOsCount = 0
    var doneCollectingMachos = false
    var stampingCurrent = 0
    var stampingTotal = 0
    var doneStamping = false

    var libCollectingCount = 0
    var libCollectionDone = false
    var libSigningCurrent = 0
    var libSigningTotal = 0
    var libSigningDone = false

    var bundleCollectingCount = 0
    var bundleCollectionDone = false
    var bundleSigningCurrent = 0
    var bundleSigningTotal = 0
    var bundleSigningDone = false

    var signedApp = false
}

private struct DropZoneErrorState: Identifiable {
    let id = UUID()
    let message: String

    init(error: Error) {
        if let error = error as? DropFileAnalyzerError {
            switch error {
            case .onlyOneFileCanBeDropped:
                message = "Only one file can be analyzed at a time"
            case .errorRenamingIpaExtension:
                message = "Failed to process IPA file extension"
            case .isNotAnIpaOrZipFile:
                message = "Unsupported file type. Please use .ipa or .zip"
            }
            return
        }

        if let error = error as? DropZoneUIError {
            switch error {
            case .analysisIncomplete:
                message = "Analysis finished, but the required app files could not be resolved."
            }
            return
        }

        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            message = "The archive could not be opened. Check that the file is valid and try again."
            return
        }

        message = error.localizedDescription
    }
}
