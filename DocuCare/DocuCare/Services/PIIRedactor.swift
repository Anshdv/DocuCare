//
//  PIIRedactor.swift
//  DocuCare
//

import Foundation
import UIKit

enum PIIRedactor {
    static func detectPIIBoundingBoxes(in lines: [(text: String, boundingBox: CGRect)]) -> [CGRect] {
        var rects: [CGRect] = []
        for (text, rect) in lines {
            if containsPII(text: text) {
                rects.append(rect)
            }
        }
        return rects
    }
    
    static func containsPII(text: String) -> Bool {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9@._%+\\-:/.,;() ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let patterns: [String] = [
            // Email addresses
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            // Date of Birth
            #"(0?[1-9]|1[012])[- /.](0?[1-9]|[12][0-9]|3[01])[- /.](19|20)?\d\d"#,
            #"(0?[1-9]|[12][0-9]|3[01])[- /.](0?[1-9]|1[012])[- /.](19|20)?\d\d"#,
            #"(0?[1-9]|[12][0-9]|3[01])[- /.](jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec|january|february|march|april|may|june|july|august|september|october|november|december)[- /.](19|20)?\d\d"#,
            // SSN
            #"\d{3}[- ]?\d{2}[- ]?\d{4}"#,
            // Insurance Policy/ID
            #"(policy|member|insurance|id)[:\s]*[a-z0-9]{6,}"#,
            // Name titles and fields
            #"mr|ms|mrs|dr|miss|prof\.?\s+[a-z]+"#,
            #"(name|patient name|pat name)[:\s]"#,
            // Age
            #"age\s*[:\-]?\s*\d{1,3}(\s*(years?|yrs?|y))?"#,
            #"\d{1,3}\s*(years?|yrs?|y)?\s*age"#,
            #"\d{1,3}\s*(years?|yrs?|y)\b"#,
            // Colon sex/gender
            #":\s*(male|female|m|f)\b"#,
            #"(sex|gender)\s*[:\-]?\s*(male|female|m|f)"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: normalized.utf16.count)
                if regex.firstMatch(in: normalized, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - UIImage Redaction

extension UIImage {
    func redacting(rects: [CGRect]) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: self.size, format: format)
        return renderer.image { ctx in
            self.draw(at: .zero)
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            for rect in rects {
                ctx.cgContext.fill(rect)
            }
        }
    }
}
