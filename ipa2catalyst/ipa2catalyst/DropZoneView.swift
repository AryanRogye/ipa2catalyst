import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTargeted = false
    @State private var droppedFile: URL?
    @State private var analyzedFileInfo: DroppedFileInfo?
    @State private var isProcessingDrop = false
    @State private var isConverting = false
    @State private var errorState: DropZoneErrorState?
    @State private var conversionStatus = ConversionStatus()

    let hackerGreen = Color(red: 0, green: 0.9, blue: 0.1)
    let hackerDark = Color(red: 0.05, green: 0.05, blue: 0.05)
    let hackerBorder = Color(red: 0, green: 0.5, blue: 0.1).opacity(0.4)

    let dropAnalayzer = DropFileAnalyzer()
    let unzipService = UnzipService()

    var body: some View {
        HStack(spacing: 16) {
            dropPane
                .frame(width: 320)

            infoPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(hackerDark)
    }

    private var dropPane: some View {
        contentStack
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            .background(dropPaneBackground)
            .overlay(dropPaneBorder)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted, perform: handleDrop)
            .animation(.spring(duration: 0.3), value: isTargeted)
            .animation(.default, value: isProcessingDrop)
            .animation(.spring, value: droppedFile)
            .alert("SYSTEM ERROR", isPresented: alertIsPresented, presenting: errorState) { _ in
                Button("OK") { errorState = nil }
            } message: { errorState in
                Text(errorState.message)
            }
    }

    private var infoPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("[ SYSTEM_LOG ]")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(hackerGreen)

                    Text(infoSubtitleText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(hackerGreen.opacity(0.6))
                }

                Spacer()

                if let analyzedFileInfo {
                    Button(action: { openDirectory(analyzedFileInfo.app) }) {
                        Label("REVEAL_BUNDLE", systemImage: "folder")
                            .font(.system(.caption, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(hackerGreen.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen, lineWidth: 1))
                    .foregroundStyle(hackerGreen)
                    .disabled(isProcessingDrop)
                }
            }

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

            if let errorState {
                errorBanner(errorState)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(18)
        .background(infoPaneBackground)
        .overlay(infoPaneBorder)
    }

    private var contentStack: some View {
        VStack(spacing: 20) {
            ZStack {
                Image(systemName: isProcessingDrop ? "terminal.fill" : "network")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(hackerGreen)
                    .symbolEffect(.variableColor.iterative, value: isProcessingDrop)
                
                if isTargeted {
                    Circle()
                        .stroke(hackerGreen, lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isTargeted ? 1.2 : 1.0)
                        .opacity(isTargeted ? 0.5 : 0)
                }
            }

            VStack(spacing: 8) {
                Text(titleText.uppercased())
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(hackerGreen)

                Text(subtitleText)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(hackerGreen.opacity(0.7))
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
            Text(file.lastPathComponent)
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(hackerGreen.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen.opacity(0.3), lineWidth: 1))
        .foregroundStyle(hackerGreen)
        .transition(.scale.combined(with: .opacity))
    }

    private var actionRow: some View {
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
                    action: {
                        withAnimation {
                            droppedFile = nil
                            analyzedFileInfo = nil
                            errorState = nil
                            conversionStatus = ConversionStatus()
                        }
                    },
                    disabled: isBusy
                )
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .background(primary ? hackerGreen : Color.clear)
                .foregroundStyle(primary ? hackerDark : hackerGreen)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen, lineWidth: 1))
                .opacity(disabled ? 0.5 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var dropPaneBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hackerDark)
                .shadow(color: hackerGreen.opacity(0.1), radius: 10, y: 0)

            if isTargeted {
                hackerGreen.opacity(0.05)
            }
            
            // Grid effect
            Canvas { context, size in
                let step: CGFloat = 20
                for x in stride(from: 0, through: size.width, by: step) {
                    context.stroke(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(hackerGreen.opacity(0.03)))
                }
                for y in stride(from: 0, through: size.height, by: step) {
                    context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(hackerGreen.opacity(0.03)))
                }
            }
        }
    }

    private var dropPaneBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(
                isTargeted ? hackerGreen : hackerBorder,
                lineWidth: isTargeted ? 2 : 1
            )
    }

    private var infoPaneBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(hackerDark.opacity(0.8))
    }

    private var infoPaneBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(hackerBorder, lineWidth: 1)
    }

    private var infoPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AWAITING_DATA_STREAM", systemImage: "bolt.horizontal.fill")
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .foregroundStyle(hackerGreen)

            Text("Feed .ipa or .zip archive to the input buffer. Initiate analysis to resolve Mach-O architecture and entitlement trees.")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(hackerGreen.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            if let droppedFile {
                Divider()
                    .background(hackerGreen.opacity(0.2))
                detailTag(label: "SOURCE_URI", value: droppedFile.lastPathComponent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .background(hackerGreen.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen.opacity(0.1), lineWidth: 1))
    }

    private var conversionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONVERSION_SEQUENCE")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(hackerGreen)
                    Text(conversionSubtitleText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(hackerGreen.opacity(0.5))
                }

                Spacer()

                if conversionStatus.signedApp {
                    Text("SUCCESS")
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(hackerGreen)
                } else if isConverting {
                    ProgressView()
                        .tint(hackerGreen)
                        .controlSize(.small)
                }
            }

            VStack(spacing: 10) {
                statusRow(title: "ENTITLEMENT_GENERATION", state: conversionStatus.createdEntitlements)
                statusRow(title: "PLIST_PATCHING", state: conversionStatus.modifiedPlist)
                statusRow(title: "BINARY_STAMPING", state: conversionStatus.patchedBinary)
                statusRow(title: "CODE_SIG_FLUSH", state: conversionStatus.removedCodeSig)
                countRow(title: "MACHO_COLLECTION", count: conversionStatus.collectingMachOsCount, done: conversionStatus.doneCollectingMachos)
                progressRow(title: "ARCH_PATCHING", current: conversionStatus.stampingCurrent, total: conversionStatus.stampingTotal, done: conversionStatus.doneStamping)
                countRow(title: "DYLIB_EXTRACTION", count: conversionStatus.libCollectingCount, done: conversionStatus.libCollectionDone)
                progressRow(title: "DYLIB_SIGNING", current: conversionStatus.libSigningCurrent, total: conversionStatus.libSigningTotal, done: conversionStatus.libSigningDone)
                countRow(title: "BUNDLE_COLLECTION", count: conversionStatus.bundleCollectingCount, done: conversionStatus.bundleCollectionDone)
                progressRow(title: "BUNDLE_SIGNING", current: conversionStatus.bundleSigningCurrent, total: conversionStatus.bundleSigningTotal, done: conversionStatus.bundleSigningDone)
                statusRow(title: "FINAL_BUNDLE_SIGN", state: conversionStatus.signedApp)
            }
        }
        .padding(14)
        .background(hackerGreen.opacity(0.03))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hackerGreen.opacity(0.1), lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func statusRow(title: String, state: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(hackerGreen.opacity(0.7))
            Spacer()
            Text(state ? "[ DONE ]" : "[ .... ]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(state ? hackerGreen : hackerGreen.opacity(0.3))
        }
    }

    private func countRow(title: String, count: Int, done: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(hackerGreen.opacity(0.7))
            Spacer()
            Text(String(format: "%03d", count))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(hackerGreen)
            Text(done ? "[ OK ]" : "[ .. ]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(done ? hackerGreen : hackerGreen.opacity(0.3))
        }
    }

    private func progressRow(title: String, current: Int, total: Int, done: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(hackerGreen.opacity(0.7))
            Spacer()
            Text(total > 0 ? "\(current)/\(total)" : "\(current)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(hackerGreen)
            Text(done ? "[ OK ]" : "[ .. ]")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(done ? hackerGreen : hackerGreen.opacity(0.3))
        }
    }

    private func detailTag(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(hackerGreen.opacity(0.6))
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(hackerGreen)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private var subtitleText: String {
        if isProcessingDrop {
            return "Executing pre-flight checks on archive..."
        }
        if isConverting {
            return "Applying patches to executable segments..."
        }
        if analyzedFileInfo != nil {
            return "Archive parsed successfully. Ready for injection."
        }
        if droppedFile != nil {
            return "Payload loaded into primary buffer."
        }
        return "Waiting for .ipa or .zip payload..."
    }

    private var titleText: String {
        if isProcessingDrop {
            return "Processing..."
        }
        if isConverting {
            return "Injecting..."
        }
        if analyzedFileInfo != nil {
            return "Status: Ready"
        }
        if droppedFile != nil {
            return "Buffer: Loaded"
        }
        return "System Idle"
    }

    private var infoSubtitleText: String {
        if isProcessingDrop {
            return "Resolving bundle identifiers and binary headers"
        }
        if isConverting {
            return "Live kernel conversion output"
        }
        if analyzedFileInfo != nil {
            return "Bundle metadata extracted successfully"
        }
        return "System logs awaiting input"
    }

    private var conversionSubtitleText: String {
        if isConverting {
            return "Running ipa2catalyst.core.pipeline"
        }
        if conversionStatus.signedApp {
            return "Sequence terminated: Clean exit"
        }
        return "Execute sequence to begin patching"
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
            Image(systemName: "exclamationmark.terminal.fill")
            Text(errorState.message.uppercased())
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.5), lineWidth: 1))
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

#Preview {
    DropZoneView()
        .frame(width: 480, height: 300)
        .padding()
}
