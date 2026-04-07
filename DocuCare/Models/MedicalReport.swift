//
//  MedicalReport.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import Foundation
import SwiftData

@Model
final class MedicalReport {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var title: String
    var ocrText: String
    var summary: String?
    var pdfData: Data?
    var pageCount: Int
    var ownerEmail: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        ocrText: String,
        summary: String? = nil,
        pdfData: Data? = nil,
        pageCount: Int = 0,
        ownerEmail: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.ocrText = ocrText
        self.summary = summary
        self.pdfData = pdfData
        self.pageCount = pageCount
        self.ownerEmail = ownerEmail
    }
}

// MARK: - AI-generated title rules

enum ReportTitleRules {
    /// Applied only to the first-line title from Gemini after a scan—not to user-edited titles in the UI.
    static let maxWords = 3

    static func clamp(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.count <= maxWords { return trimmed }
        return words.prefix(maxWords).joined(separator: " ")
    }
}
