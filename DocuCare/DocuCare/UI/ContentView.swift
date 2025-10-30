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
    @Query private var reports: [MedicalReport]

    init() {
        let currentUser = SessionManager.shared.email.lowercased()
        _reports = Query(
            filter: #Predicate<MedicalReport> { $0.ownerEmail == currentUser },
            sort: \.createdAt, order: .reverse
        )
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

    // --- SEARCH FEATURE ---
    @FocusState private var searchFieldFocused: Bool // For search bar dismissal

    @State private var searchText: String = ""
    private let searchDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium // e.g., "Oct 12, 2025"
        return df
    }()

    // --- SEARCH FEATURE: Filtered reports ---
    private var filteredReports: [MedicalReport] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return reports }
        return reports.filter { report in
            let titleMatch = report.title.range(of: query, options: .caseInsensitive) != nil
            let dateString = searchDateFormatter.string(from: report.createdAt)
            let dateMatch = dateString.range(of: query, options: .caseInsensitive) != nil
            return titleMatch || dateMatch
        }
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }
    
    var body: some View {
        let mainContent = NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        searchBar
                        
                        ReportListSection(
                            filteredReports: filteredReports,
                            allReports: reports,
                            onDelete: delete,
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
                    // Fade starts about 55 above input bar, ends just above it
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: Color(.systemBackground).opacity(0.95), location: 0.6),
                            .init(color: Color(.systemBackground), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 55)
                    Color(.systemBackground)
                        .frame(height: 65)
                }
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

                chatInputBar
            }
            .navigationTitle("Reports")
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
                    Button("Log Out") {
                        session.logOut()
                    }
                }
            }
        }

        mainContent
            .applyImportConfirmationDialog(
                isPresented: $showingImportMenu,
                onScan: { showingScanner = true },
                onPhotos: { showingPhotoPicker = true },
                onFiles: { showingFilePicker = true }
            )
            .applyScanSheet(isPresented: $showingScanner, onScan: handleScan, onCancel: { showingScanner = false }, onFailure: { err in errorMessage = err.localizedDescription })
            .applyPhotosPicker(isPresented: $showingPhotoPicker, photoPickerItems: $photoPickerItems)
            .applyFilePickerSheet(isPresented: $showingFilePicker, onPick: handlePickedFiles)
            .applyProcessingOverlay(isProcessing: isProcessing)
            .applyErrorAlert(errorMessage: $errorMessage)
            .applyDetailSheet(selectedReport: $selectedReport)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background { appLock.lock() }
            }
            .onChange(of: photoPickerItems) { _, newItems in
                loadPickedPhotos(newItems)
            }
    }

    // MARK: - Extracted UI Sections

    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search by title or date", text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .focused($searchFieldFocused)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var scanButtonSection: some View {
        HStack {
            Spacer()
            Button {
                showingScanner = true
            } label: {
                Label("Scan a medical report or image", systemImage: "camera.viewfinder")
                    .font(.system(size: 18))
                    .padding(.horizontal, 15)
            }
            .padding(.top, 20)
            .buttonStyle(.borderedProminent)
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
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "cross.case.fill")
                                .foregroundStyle(.red)
                            Text(msg.answer)
                                .font(.body)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5)))
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
        HStack(spacing: 8) {
            TextField("Ask a question…", text: $inputText, axis: .vertical)
                .focused($inputIsFocused)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(Color.clear)
                .disableAutocorrection(true)
                .lineLimit(1...5)
                .disabled(isSendingPrompt)

            Button {
                sendPrompt()
            } label: {
                if isSendingPrompt {
                    ProgressView()
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingPrompt)
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.horizontal, 10)
        .ignoresSafeArea(edges: .bottom)
        .shadow(color: .black.opacity(0.07), radius: 8, y: 1)
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
                errorMessage = "Failed to load images from selection."
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
                errorMessage = "No supported images or PDFs found in selected files."
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
                let client = try GeminiClient(model: "gemini-2.0-flash")
                let questionPrompt = """
                You are a helpful, concise, and patient-friendly AI assistant for medical queries.
                Answer the user's prompt clearly and simply (avoiding going beyond 150 words), avoiding jargon if possible, and provide brief explanations when needed.
                Do not provide prescriptive or personalized medical advice or diagnoses. Do not use asterisks (*); use new lines to separate ideas.
                """

                let answer = try await client.AI_Response(text: currentQuestion, prompt: questionPrompt)

                guard !answer.isEmpty else { throw GeminiClient.ClientError.emptyOutput }
                chatMessages.append(ChatMessage(question: currentQuestion, answer: answer))
            } catch {
                chatMessages.append(ChatMessage(question: currentQuestion, answer: "Sorry, there was an error: \(error.localizedDescription)"))
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

                let client = try GeminiClient(model: "gemini-2.0-flash")
                let clipped = text.prefix(25_000)
                let summarizePrompt = """
                At the top, provide a patient-friendly, concrete, and non-generic 2-3 word title summarizing the report (do not include generic terms like 'Medical Report' or 'Summary'). 
                Then, after a blank line, provide a simple, concise, patient- and elderly-friendly summary in bullet points, with key findings and suggested diagnoses, 
                minimizing technical or biological terms, and briefly explaining the effects of any abnormalities (75-100 words).
                Separate each point on a new line; do not use any special symbol. Make the output 1.15 spaced. Do not use asterisks (*) anywhere in the output. 
                Do not give prescriptive treatment advice.
                """

                // Always send redacted images to the AI
                let imagesToSend: [UIImage]? = redactedImages
                let aiOutput = try await client.AI_Response(
                    text: String(clipped),
                    prompt: summarizePrompt,
                    images: imagesToSend
                )

                // ... rest unchanged ...
                let lines = aiOutput.components(separatedBy: .newlines)
                let titleIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? 0
                let title = lines[titleIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                let summaryStartIdx = lines[(titleIdx+1)...].firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? (titleIdx+1)
                let summary = lines[summaryStartIdx...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

                let report = MedicalReport(
                    title: title.isEmpty ? "Medical Report" : title,
                    ocrText: text,
                    summary: summary,
                    pdfData: pdf,
                    pageCount: images.count,
                    ownerEmail: session.email.lowercased() // Always store lowercased
                )
                context.insert(report)
                try? context.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }
    
    private var navigationBarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingImportMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isProcessing)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Log Out") {
                    session.logOut()
                }
            }
        }
    }

    // MARK: - List Row

    @ViewBuilder
    private func reportRow(for report: MedicalReport) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.title)
                    .font(.title2).bold()
                HStack(spacing: 8) {
                    Text(report.createdAt, style: .date)
                    if report.pageCount > 0 {
                        Text("• \(report.pageCount) page\(report.pageCount == 1 ? "" : "s")")
                    }
                }
                .font(.title3)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                selectedReport = SelectedReport(id: report.id)
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.accentColor)
                    .accessibilityLabel("Open Medical Summary")
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func delete(_ report: MedicalReport) {
        context.delete(report)
        try? context.save()
    }

    private func inferredTitle(from text: String) -> String {
        let firstLine = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "Medical Report"
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
    let onDelete: (MedicalReport) -> Void
    let onOpen: (MedicalReport) -> Void

    var body: some View {
        if filteredReports.isEmpty {
            ContentUnavailableView(
                "No reports found",
                systemImage: "doc.text.magnifyingglass",
                description: Text(
                    allReports.isEmpty
                    ? "Scan a medical report to get started."
                    : "Try a different search or scan a new report."
                ).font(.headline)
            )
            .padding(.top, 20)
        } else {
            let minHeight: CGFloat = {
                switch filteredReports.count {
                case 1: return 150
                case 2: return 225
                case 3: return 300
                default: return 375
                }
            }()
            List {
                ForEach(filteredReports) { report in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.title)
                                .font(.title2).bold()
                            HStack(spacing: 8) {
                                Text(report.createdAt, style: .date)
                                if report.pageCount > 0 {
                                    Text("• \(report.pageCount) page\(report.pageCount == 1 ? "" : "s")")
                                }
                            }
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            onOpen(report)
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color.accentColor)
                                .accessibilityLabel("Open Medical Summary")
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .swipeActions {
                        Button(role: .destructive) { onDelete(report) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden) // <--- hides the default background
            .background(Color.clear)          // <--- makes sure outer List is also clear
            .listRowBackground(Color.clear)   // <--- makes each row's background transparent
            .frame(minHeight: minHeight)
        }
    }
}

// MARK: - Modifier helpers

private extension View {
    func applyToolbar(_ toolbarContent: some ToolbarContent) -> some View {
        self.toolbar(content: { toolbarContent })
    }

    func applyImportConfirmationDialog(
        isPresented: Binding<Bool>,
        onScan: @escaping () -> Void,
        onPhotos: @escaping () -> Void,
        onFiles: @escaping () -> Void
    ) -> some View {
        self.confirmationDialog(
            "Import Report",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Take a picture", action: onScan)
            Button("Upload from Photos", action: onPhotos)
            Button("Upload from Files", action: onFiles)
            Button("Cancel", role: .cancel) {}
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

    func applyProcessingOverlay(isProcessing: Bool) -> some View {
        self.overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Processing…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    func applyErrorAlert(errorMessage: Binding<String?>) -> some View {
        self.alert("Error", isPresented: .constant(errorMessage.wrappedValue != nil), actions: {
            Button("OK") { errorMessage.wrappedValue = nil }
        }, message: { Text(errorMessage.wrappedValue ?? "") })
    }

    func applyDetailSheet(
        selectedReport: Binding<SelectedReport?>
    ) -> some View {
        self.sheet(item: selectedReport) { selected in
            ReportDetailView(reportID: selected.id)
        }
    }
}

struct Preview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
