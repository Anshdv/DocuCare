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

    @State private var report: MedicalReport?
    @State private var errorMessage: String?
    @State private var isSpeaking = false
    @State private var speechSynth = AVSpeechSynthesizer()
    @State private var speechDelegate: SpeechDelegate?
    @FocusState private var titleIsFocused: Bool

    var body: some View {
        Group {
            if let report {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Editable Title + Speech button
                        HStack(alignment: .center, spacing: 8) {
                            TextField("Report Title", text: Binding(
                                get: { report.title },
                                set: { newTitle in
                                    report.title = newTitle
                                }
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
                                .accessibilityLabel(isSpeaking ? "Stop Reading Summary" : "Read Summary")
                                .padding(.top)
                            }
                        }

                        HStack(spacing: 8) {
                            Text(report.createdAt, style: .date)
                                .foregroundStyle(.secondary)
                            if report.pageCount > 0 {
                                Text("• \(report.pageCount) page\(report.pageCount == 1 ? "" : "s")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)

                        Divider()

                        if let summary = report.summary, !summary.isEmpty {
                            Text("Brief Summary:")
                                .font(.title2)
                            Text(summary)
                        }

                        Divider()
                        
                        Text("Scanned Document")
                            .font(.title2)

                        makePDFView(from: report.pdfData)
                    }
                    .padding()
                }
                .navigationTitle("Report Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) {
                            deleteReport(report)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
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
                    "Report not found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("Loading…")
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
            utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Evan-enhanced")
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
                errorMessage = "The report may have been deleted."
            }
        } catch {
            errorMessage = "Failed to load the report."
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
