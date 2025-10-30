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
