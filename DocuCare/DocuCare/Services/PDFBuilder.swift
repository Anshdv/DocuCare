//
//  PDFBuilder.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import UIKit
import PDFKit

enum PDFBuilder {
    static func makePDF(from images: [UIImage]) -> Data? {
        let pdf = PDFDocument()
        for (idx, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            pdf.insert(page, at: idx)
        }
        return pdf.dataRepresentation()
    }
}
