//
//  ReportDetailView.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import SwiftUI
import SwiftData
import PDFKit
import UIKit
import AVFoundation

struct ReportDetailView: View {
    let reportID: UUID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    private var lang: String { session.preferredLanguageCode }

    @State private var report: MedicalReport?
    @State private var errorMessage: String?
    @State private var isSpeaking = false
    @State private var speechSynth = AVSpeechSynthesizer()
    @State private var speechDelegate: SpeechDelegate?
    @FocusState private var titleIsFocused: Bool

    // --- Sharing State ---
    @State private var showingShareDialog = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []

    // --- Delete Confirmation State ---
    @State private var confirmingDelete = false

    var body: some View {
        Group {
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Editable Title + Speech button
                        HStack(alignment: .center, spacing: 8) {
                            TextField(L10n.string(.reportTitlePlaceholder, languageCode: lang), text: Binding(
                                get: { report.title },
                                set: { report.title = $0 }
                            ))
                            .font(.title)
                            .bold()
                            .focused($titleIsFocused)
                            .padding(.top)
                            .onSubmit {
                                saveTitle()
                            }

                            if let summary = report.summary, !summary.isEmpty {
                                Button {
                                    speak(summary: summary)
                                } label: {
                                    Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                                        .font(.title2)
                                }
                                .accessibilityLabel(isSpeaking ? L10n.string(.stopReadingSummary, languageCode: lang) : L10n.string(.readSummary, languageCode: lang))
                                .padding(.top)
                            }
                        }

                        HStack(spacing: 8) {
                            Text(report.createdAt, style: .date)
                                .foregroundStyle(.secondary)
                            if report.pageCount > 0 {
                                Text("• \(L10n.pageLabel(count: report.pageCount, languageCode: lang))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)

                        Divider()

                        if let summary = report.summary, !summary.isEmpty {
                            Text(L10n.string(.briefSummary, languageCode: lang))
                                .font(.title2)
                            SummaryFormattedView(summary: summary)
                                .font(.body)
                        }

                        Divider()
                        
                        Text(L10n.string(.scannedDocument, languageCode: lang))
                            .font(.title2)

                        makePDFView(from: report.pdfData)
                        
                        // Disclaimer below the scanned document
                        HStack {
                            Spacer()
                            Text(L10n.string(.aiDisclaimer, languageCode: lang))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            Spacer()
                        }
                    }
                    .padding()
                    .textSelection(.enabled)
                }
                .navigationTitle(L10n.string(.reportDetails, languageCode: lang))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Trash on the left
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                    // Share on the right
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingShareDialog = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .alert(L10n.string(.deleteReportTitle, languageCode: lang),
                       isPresented: $confirmingDelete,
                       actions: {
                           Button(L10n.string(.delete, languageCode: lang), role: .destructive) {
                               deleteReport(report)
                           }
                           Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {}
                       },
                       message: {
                           Text(L10n.string(.deleteReportMessage, languageCode: lang))
                       }
                )
                .confirmationDialog(L10n.string(.shareDialogTitle, languageCode: lang), isPresented: $showingShareDialog, titleVisibility: .visible) {
                    if let summary = report.summary, !summary.isEmpty {
                        Button(L10n.string(.shareSummary, languageCode: lang)) {
                            let summaryWithTitle = "\(report.title)\n\n\(summary)"
                            shareItems = [summaryWithTitle]
                            showingShareSheet = true
                        }
                    }
                    if let pdfData = report.pdfData {
                        Button(L10n.string(.shareScannedPDF, languageCode: lang)) {
                            let tempURL = saveDataToTemporaryFile(data: pdfData, fileName: "\(report.title).pdf")
                            if let tempURL {
                                shareItems = [tempURL]
                                showingShareSheet = true
                            } else {
                                errorMessage = L10n.string(.unablePreparePDFShare, languageCode: lang)
                            }
                        }
                    }
                    if let summary = report.summary, !summary.isEmpty, let pdfData = report.pdfData {
                        Button(L10n.string(.shareBoth, languageCode: lang)) {
                            let tempURL = saveDataToTemporaryFile(data: pdfData, fileName: "\(report.title).pdf")
                            if let tempURL {
                                let summaryWithTitle = "\(report.title)\n\n\(summary)"
                                shareItems = [summaryWithTitle, tempURL]
                                showingShareSheet = true
                            } else {
                                errorMessage = L10n.string(.unablePrepareDocumentShare, languageCode: lang)
                            }
                        }
                    }
                    Button(L10n.string(.cancel, languageCode: lang), role: .cancel) {}
                }
                .sheet(isPresented: $showingShareSheet) {
                    if !shareItems.isEmpty {
                        ShareSheet(activityItems: shareItems)
                    }
                }
                .alert(L10n.string(.error, languageCode: lang), isPresented: .constant(errorMessage != nil), actions: {
                    Button(L10n.string(.ok, languageCode: lang)) { errorMessage = nil }
                }, message: {
                    Text(errorMessage ?? "")
                })
                .onAppear {
                    let delegate = SpeechDelegate(isSpeaking: $isSpeaking)
                    speechSynth.delegate = delegate
                    speechDelegate = delegate
                }
                .onDisappear {
                    saveTitle()
                }

            } else if let errorMessage {
                ContentUnavailableView(
                    L10n.string(.reportNotFound, languageCode: lang),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView(L10n.string(.loading, languageCode: lang))
            }
        }
        .task {
            await loadReport()
        }
    }

    // MARK: - Editable Title Saving

    private func saveTitle() {
        guard report != nil else { return }
        do {
            try context.save()
        } catch {
            // Optionally, handle error or show message
        }
    }

    // MARK: - Speech

    private func speak(summary: String) {
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let utterance = AVSpeechUtterance(string: summary)
            let tag = AppLanguage.speechLanguageIdentifier(from: lang)
            if let v = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == tag })
                ?? AVSpeechSynthesisVoice(language: tag) {
                utterance.voice = v
            }
            utterance.rate = 0.42
            isSpeaking = true
            speechSynth.speak(utterance)
        }
    }

    class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
        @Binding var isSpeaking: Bool
        init(isSpeaking: Binding<Bool>) {
            self._isSpeaking = isSpeaking
        }
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            isSpeaking = false
        }
        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            isSpeaking = false
        }
    }

    // MARK: - Data Loading

    private func loadReport() async {
        do {
            let descriptor = FetchDescriptor<MedicalReport>(
                predicate: #Predicate { $0.id == reportID }
            )
            report = try context.fetch(descriptor).first
            if report == nil {
                errorMessage = L10n.string(.reportMayBeDeleted, languageCode: lang)
            }
        } catch {
            errorMessage = L10n.string(.failedLoadReport, languageCode: lang)
        }
    }

    // MARK: - Actions

    private func deleteReport(_ report: MedicalReport) {
        context.delete(report)
        try? context.save()
        dismiss()
    }

    // MARK: - PDF Rendering

    @ViewBuilder
    private func makePDFView(from data: Data?) -> some View {
        if let data,
           let pdfDocument = PDFDocument(data: data) {
            PDFKitView(document: pdfDocument)
                .frame(minHeight: 400)
        }
    }

    // MARK: - Utilities

    /// Saves data as a temporary file and returns its URL, or nil on failure.
    private func saveDataToTemporaryFile(data: Data, fileName: String) -> URL? {
        let sanitizedFileName = fileName.replacingOccurrences(of: "/", with: "-")
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(sanitizedFileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// Simple PDFKit wrapper for SwiftUI
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - ShareSheet UIViewControllerRepresentable

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

