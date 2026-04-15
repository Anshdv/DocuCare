//
//  ContentView.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import SwiftUI
import SwiftData
import PDFKit
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appLock: AppLockManager

    @EnvironmentObject private var session: SessionManager
    @Query(sort: \MedicalReport.createdAt, order: .reverse) private var allReports: [MedicalReport]

    /// Filters in memory so account email changes (Profile) immediately affect the list.
    private var reports: [MedicalReport] {
        let owner = session.email.lowercased()
        return allReports.filter { $0.ownerEmail == owner }
    }

    @State private var selectedReport: SelectedReport? = nil
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // --- Chat State ---
    @State private var inputText: String = ""
    @State private var chatMessages: [ChatMessage] = []
    @State private var isSendingPrompt = false
    @FocusState private var inputIsFocused: Bool

    // --- New state for image inclusion prompt ---
    @State private var pendingScanImages: [UIImage]? = nil

    // --- More Menu ---
    @State private var showingImportMenu = false
    @State private var showingProfile = false

    // --- SEARCH FEATURE ---
    @FocusState private var searchFieldFocused: Bool // For search bar dismissal

    @State private var searchText: String = ""

    private var lang: String { session.effectiveLanguageCode() }

    private func formatReportDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: AppLanguage.localeIdentifier(from: lang))
        return df.string(from: date)
    }

    // --- SEARCH FEATURE: Filtered reports ---
    private var filteredReports: [MedicalReport] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return reports }
        return reports.filter { report in
            let titleMatch = report.title.range(of: query, options: .caseInsensitive) != nil
            let dateString = formatReportDate(report.createdAt)
            let dateMatch = dateString.range(of: query, options: .caseInsensitive) != nil
            return titleMatch || dateMatch
        }
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }
    
    // --- Deletion Confirmation State ---
    @State private var reportPendingDelete: MedicalReport?
    @State private var showingDeleteConfirmation = false

    @State private var reportLocalizationTask: Task<Void, Never>?

    var body: some View {
        let mainContent = NavigationStack {
            ZStack(alignment: .bottom) {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchBar
                        
                        ReportListSection(
                            filteredReports: filteredReports,
                            allReports: reports,
                            languageCode: lang,
                            listIdentity: session.localizationRevision,
                            onDelete: { report in
                                reportPendingDelete = report
                                showingDeleteConfirmation = true
                            },
                            onOpen: { report in selectedReport = SelectedReport(id: report.id) }
                        )
                        
                        scanButtonSection
                        chatHistorySection
                        Spacer(minLength: 80) // Prevents last message from hiding behind chat bar
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        inputIsFocused = false // Dismiss keyboard on tap outside
                        searchFieldFocused = false
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                // --- Bottom fade starts above textbox, fully black/opaque beneath ---
                VStack(spacing: 0) {
                    Spacer()
                    // Use a single smooth fade to avoid visible background banding near the chat bar.
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: AppTheme.backgroundBottom.opacity(0.55), location: 0.55),
                            .init(color: AppTheme.backgroundBottom, location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

                chatInputBar
            }
            .navigationTitle(L10n.string(.reports, languageCode: lang))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImportMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .disabled(isProcessing)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel(L10n.string(.profileTitle, languageCode: lang))
                }
            }
        }

        mainContent
            // App chrome is always light; without this, the nav title follows system dark mode (e.g. white text).
            .preferredColorScheme(.light)
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(isPresented: $showingProfile) {
                NavigationStack {
                    ProfileView()
                }
                .environmentObject(session)
            }
            .applyImportConfirmationDialog(
                languageCode: lang,
                isPresented: $showingImportMenu,
                onScan: { showingScanner = true },
                onPhotos: { showingPhotoPicker = true },
                onFiles: { showingFilePicker = true }
            )
            .applyScanSheet(isPresented: $showingScanner, onScan: handleScan, onCancel: { showingScanner = false }, onFailure: { err in errorMessage = err.localizedDescription })
            .applyPhotosPicker(isPresented: $showingPhotoPicker, photoPickerItems: $photoPickerItems)
            .applyFilePickerSheet(isPresented: $showingFilePicker, onPick: handlePickedFiles)
            .applyProcessingOverlay(isProcessing: isProcessing, languageCode: lang)
            .applyErrorAlert(errorMessage: $errorMessage, languageCode: lang)
            .applyDetailSheet(selectedReport: $selectedReport)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background { appLock.lock() }
            }
            .onChange(of: photoPickerItems) { _, newItems in
                loadPickedPhotos(newItems)
            }
            // --- ALERT for Swipe-to-Delete ---
            .onChange(of: session.preferredLanguageCode) { _, newCode in
                reportLocalizationTask?.cancel()
                reportLocalizationTask = Task { @MainActor in
                    let snapshot = reports.filter { $0.contentLanguageCode != newCode }
                    guard !snapshot.isEmpty else { return }
                    await ReportLocalizationChain.shared.synchronizeOwnedReports(snapshot, targetCode: newCode, modelContext: context)
                }
            }
            .alert(L10n.string(.deleteReportTitle, languageCode: lang),
                   isPresented: $showingDeleteConfirmation,
                   actions: {
                       Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                           if let report = reportPendingDelete {
                               actuallyDelete(report)
                           }
                           reportPendingDelete = nil
                       }
                       Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {
                           reportPendingDelete = nil
                       }
                   },
                   message: {
                       Text(L10n.string(.deleteReportMessage, languageCode: lang))
                   }
            )
    }

    // MARK: - Extracted UI Sections

    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)
            TextField(
                "",
                text: $searchText,
                prompt: Text(L10n.string(.searchPlaceholder, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9))
            )
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .foregroundStyle(AppTheme.softText)
                .focused($searchFieldFocused)
        }
        .padding(10)
        .appTextFieldStyle()
        .padding(.horizontal, 2)
        .id(session.localizationRevision)
    }

    @ViewBuilder
    private var scanButtonSection: some View {
        HStack {
            Spacer()
            Button {
                showingScanner = true
            } label: {
                Label(L10n.string(.scanMedicalReport, languageCode: lang), systemImage: "camera.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .padding(.horizontal, 15)
            }
            .padding(.top, 20)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isProcessing)
            Spacer()
        }
    }

    @ViewBuilder
    private var chatHistorySection: some View {
        if !chatMessages.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(chatMessages) { msg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "person.fill.questionmark")
                                .foregroundStyle(.blue)
                            Text(msg.question)
                                .font(.callout)
                                .foregroundStyle(AppTheme.softText)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.chipFill))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(.red)
                            Text(msg.answer)
                                .font(.body)
                                .foregroundStyle(AppTheme.softText)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.rowFill))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.trailing, 1)
        }
    }

    @ViewBuilder
    private var chatInputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "",
                text: $inputText,
                prompt: Text(L10n.string(.askQuestion, languageCode: lang))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.9)),
                axis: .vertical
            )
                .focused($inputIsFocused)
                .padding(.vertical, 12)
                .padding(.leading, 18)
                .padding(.trailing, 6)
                .background(Color.clear)
                .foregroundStyle(AppTheme.softText)
                .disableAutocorrection(true)
                .lineLimit(1...5)
                .disabled(isSendingPrompt)

            Button {
                sendPrompt()
            } label: {
                Group {
                    if isSendingPrompt {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .padding(.bottom, 4)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingPrompt)
        }
        .background(AppTheme.rowFill)
        .clipShape(Capsule())
        .padding(.horizontal, 10)
        .ignoresSafeArea(edges: .bottom)
        .shadow(color: .black.opacity(0.08), radius: 12, y: 3)
        .id(session.localizationRevision)
    }

    // MARK: - Photo Picker State and Handlers

    @State private var photoPickerItems: [PhotosPickerItem] = []

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isProcessing = true
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    images.append(uiImage)
                }
            }
            isProcessing = false
            if images.isEmpty {
                errorMessage = L10n.string(.failedLoadImages, languageCode: lang)
            } else {
                pendingScanImages = images
                processScan()
            }
        }
    }

    // MARK: - File Picker State and Handlers

    private func handlePickedFiles(urls: [URL]) {
        guard !urls.isEmpty else { return }
        var images: [UIImage] = []

        isProcessing = true
        Task {
            for url in urls {
                let type = UTType(filenameExtension: url.pathExtension)
                if type == .pdf {
                    if let pdfDoc = PDFDocument(url: url) {
                        for idx in 0..<pdfDoc.pageCount {
                            if let page = pdfDoc.page(at: idx) {
                                let pageImage = page.thumbnail(of: CGSize(width: 1200, height: 1550), for: .mediaBox)
                                images.append(pageImage)
                            }
                        }
                    }
                } else if type == .image,
                          let data = try? Data(contentsOf: url),
                          let img = UIImage(data: data) {
                    images.append(img)
                }
            }
            isProcessing = false
            if images.isEmpty {
                errorMessage = L10n.string(.noSupportedFiles, languageCode: lang)
            } else {
                pendingScanImages = images
                processScan()
            }
        }
    }

    // MARK: - Gemini Prompt Sending

    private func sendPrompt() {
        let trimmedPrompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        isSendingPrompt = true
        inputIsFocused = false
        let currentQuestion = trimmedPrompt

        Task {
            do {
                let client = try GeminiClient()
                let questionPrompt = GeminiPrompts.chatAssistantPrompt(appLanguageCode: lang)

                let answer = try await client.AI_Response(text: currentQuestion, prompt: questionPrompt)

                guard !answer.isEmpty else { throw GeminiClient.ClientError.emptyOutput }
                chatMessages.append(ChatMessage(question: currentQuestion, answer: answer))
            } catch {
                chatMessages.append(ChatMessage(question: currentQuestion, answer: L10n.chatError(error, languageCode: lang)))
            }
            isSendingPrompt = false
        }
    }

    // MARK: - Scan Actions

    private func handleScan(images: [UIImage]) {
        showingScanner = false
        guard !images.isEmpty else { return }
        pendingScanImages = images
        processScan()
    }
    
    private func redactPII(in images: [UIImage]) async -> [UIImage] {
        await withTaskGroup(of: UIImage?.self) { group in
            for image in images {
                group.addTask {
                    let ocrLines = try? await TextRecognizer.recognizeTextWithBoundingBoxes(from: image)
                    let piiRects = PIIRedactor.detectPIIBoundingBoxes(in: ocrLines ?? [])
                    if !piiRects.isEmpty {
                        return image.redacting(rects: piiRects)
                    } else {
                        return image
                    }
                }
            }
            var result: [UIImage] = []
            for await image in group {
                if let image = image {
                    result.append(image)
                }
            }
            return result
        }
    }

    private func processScan() {
        guard let images = pendingScanImages, !images.isEmpty else { return }
        isProcessing = true
        pendingScanImages = nil

        Task {
            do {
                let redactedImages = await redactPII(in: images)
                let pdf = PDFBuilder.makePDF(from: redactedImages)

                // OCR performed on redacted images (matches what user sees)
                let (text, _) = try await TextRecognizer.recognizeText(from: redactedImages)

                let client = try GeminiClient()
                let summarizePrompt = GeminiPrompts.summarizeMedicalReportPrompt(appLanguageCode: lang)

                // Always send redacted images to the AI (full OCR text—no client-side truncation; brevity is enforced in the prompt)
                let imagesToSend: [UIImage]? = redactedImages
                let aiOutput = try await client.AI_Response(
                    text: text,
                    prompt: summarizePrompt,
                    images: imagesToSend,
                    maxOutputTokens: GeminiClient.summarizeOutputTokenCeiling
                )

                // ... rest unchanged ...
                let lines = aiOutput.components(separatedBy: .newlines)
                let titleIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? 0
                let rawTitle = lines[titleIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let title = ReportTitleRules.clamp(rawTitle)
                let summaryStartIdx = lines[(titleIdx+1)...].firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? (titleIdx+1)
                let summary = lines[summaryStartIdx...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                let report = MedicalReport(
                    title: title.isEmpty ? L10n.string(.medicalReportFallback, languageCode: lang) : title,
                    ocrText: text,
                    summary: summary,
                    pdfData: pdf,
                    pageCount: images.count,
                    ownerEmail: session.email.lowercased(), // Always store lowercased
                    contentLanguageCode: lang
                )
                context.insert(report)
                try? context.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    // MARK: - Actions

    private func actuallyDelete(_ report: MedicalReport) {
        context.delete(report)
        try? context.save()
    }

    private func inferredTitle(from text: String) -> String {
        let firstLine = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? L10n.string(.medicalReportFallback, languageCode: lang)
        return String(firstLine.prefix(60))
    }
}

// MARK: - DocumentPicker for Files (Images, PDFs)
struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = [UTType.image, UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick([])
        }
    }
}

private struct SelectedReport: Identifiable, Equatable {
    let id: UUID
}

private struct ReportListSection: View {
    let filteredReports: [MedicalReport]
    let allReports: [MedicalReport]
    let languageCode: String
    /// Forces row text to refresh when language / report strings change.
    let listIdentity: UInt
    let onDelete: (MedicalReport) -> Void
    let onOpen: (MedicalReport) -> Void

    private func formatReportDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.locale = Locale(identifier: AppLanguage.localeIdentifier(from: languageCode))
        return df.string(from: date)
    }

    var body: some View {
        if filteredReports.isEmpty {
            ContentUnavailableView(
                L10n.string(.noReportsFound, languageCode: languageCode),
                systemImage: "doc.text.magnifyingglass",
                description: Text(
                    allReports.isEmpty
                    ? L10n.string(.emptyScanPrompt, languageCode: languageCode)
                    : L10n.string(.emptySearchPrompt, languageCode: languageCode)
                )
                .font(.headline)
                .foregroundStyle(AppTheme.secondaryText)
            )
            .foregroundStyle(AppTheme.softText)
            .padding(.top, 20)
        } else {
            List {
                ForEach(filteredReports) { report in
                    Button {
                        onOpen(report)
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(report.title)
                                    .id("\(report.id.uuidString)-\(report.title)-\(report.contentLanguageCode)-\(listIdentity)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.softText)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack(spacing: 8) {
                                    Text(formatReportDate(report.createdAt))
                                    if report.pageCount > 0 {
                                        Text("• \(L10n.pageLabel(count: report.pageCount, languageCode: languageCode))")
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText.opacity(0.85))
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 5, leading: 4, bottom: 5, trailing: 4))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(AppTheme.chipFill)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppTheme.cardStroke, lineWidth: 1)
                            )
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(report)
                        } label: {
                            Label(L10n.string(.delete, languageCode: languageCode), systemImage: "trash")
                        }
                    }
                    .accessibilityHint(L10n.string(.openMedicalSummary, languageCode: languageCode))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: CGFloat(min(380, max(120, filteredReports.count * 92))))
            .environment(\.defaultMinListRowHeight, 1)
            .id("\(languageCode)-\(listIdentity)")
        }
    }
}

// MARK: - Modifier helpers

private extension View {
    func applyToolbar(_ toolbarContent: some ToolbarContent) -> some View {
        self.toolbar(content: { toolbarContent })
    }

    func applyImportConfirmationDialog(
        languageCode: String,
        isPresented: Binding<Bool>,
        onScan: @escaping () -> Void,
        onPhotos: @escaping () -> Void,
        onFiles: @escaping () -> Void
    ) -> some View {
        self.confirmationDialog(
            L10n.string(.importReport, languageCode: languageCode),
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.string(.takePicture, languageCode: languageCode), action: onScan)
            Button(L10n.string(.uploadPhotos, languageCode: languageCode), action: onPhotos)
            Button(L10n.string(.uploadFiles, languageCode: languageCode), action: onFiles)
            Button(L10n.string(.cancel, languageCode: languageCode), role: .cancel) {}
        }
    }

    func applyScanSheet(
        isPresented: Binding<Bool>,
        onScan: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void,
        onFailure: @escaping (Error) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            DocumentScannerView(
                onScan: onScan,
                onCancel: onCancel,
                onFailure: onFailure
            )
            .ignoresSafeArea()
        }
    }

    func applyPhotosPicker(
        isPresented: Binding<Bool>,
        photoPickerItems: Binding<[PhotosPickerItem]>
    ) -> some View {
        self.photosPicker(
            isPresented: isPresented,
            selection: photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        )
    }

    func applyFilePickerSheet(
        isPresented: Binding<Bool>,
        onPick: @escaping ([URL]) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            DocumentPicker(onPick: onPick)
        }
    }

    func applyProcessingOverlay(isProcessing: Bool, languageCode: String) -> some View {
        self.overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView(L10n.string(.processing, languageCode: languageCode))
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    func applyErrorAlert(errorMessage: Binding<String?>, languageCode: String) -> some View {
        self.alert(L10n.string(.error, languageCode: languageCode), isPresented: .constant(errorMessage.wrappedValue != nil), actions: {
            Button(L10n.string(.ok, languageCode: languageCode)) { errorMessage.wrappedValue = nil }
        }, message: { Text(errorMessage.wrappedValue ?? "") })
    }

    func applyDetailSheet(
        selectedReport: Binding<SelectedReport?>
    ) -> some View {
        self.sheet(item: selectedReport) { selected in
            NavigationStack {
                ReportDetailView(reportID: selected.id)
            }
            .environmentObject(SessionManager.shared)
        }
    }
}

struct Preview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
