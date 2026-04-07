//
//  PIIRedactor.swift
//  DocuCare
//

import Foundation
import UIKit

/// Client-side PII redaction for scanned report images before OCR/AI.
/// Goals: redact labeled identifiers and strong PII patterns; avoid blacking clinical phrases like disease duration ("for 2 years").
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let normalized = normalizeForMatching(trimmed)

        if matchesNormalizedHighConfidence(normalized) { return true }
        if matchesOriginalTextPatterns(trimmed) { return true }
        if matchesLabeledNameOrPersonFields(normalized) { return true }

        return false
    }

    /// Lowercase + strip characters that break regex while keeping letters, digits, and common separators.
    private static func normalizeForMatching(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9@._%+\\-:/.,;()' ]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Normalized line matching (emails, IDs, labeled ages, etc.)

    private static func matchesNormalizedHighConfidence(_ normalized: String) -> Bool {
        let patterns: [String] = [
            // Email
            #"[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}"#,
            // US phone (digits preserved in normalized)
            #"(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#,
            // SSN
            #"\d{3}[- ]?\d{2}[- ]?\d{4}"#,
            // Labeled DOB / birth date (not every calendar date on the page)
            #"(?:^|\s)(?:dob|d\.o\.b\.?|date\s+of\s+birth|birth\s*date|birthdate)\s*[:\-]?\s*(?:\d{1,2}[- /.]\d{1,2}[- /.]\d{2,4}|\d{4}[- /.]\d{1,2}[- /.]\d{1,2})"#,
            // Date immediately after DOB-style label (month names)
            #"(?:dob|d\.o\.b\.?|date\s+of\s+birth|birth\s*date)\s*[:\-]?\s*(?:\d{1,2}[- /.](?:jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*[- /.]\d{2,4})"#,
            // MRN / account / member id style (require keyword; avoid bare "id")
            #"(?:mrn|medical\s+record(?:\s+no\.?)?|patient\s*id|pat\s*id|account\s*(?:no\.?|#)?|member\s*(?:id|#|no\.?)?|insurance\s*(?:id|#|no\.?)?|group\s*(?:id|#|no\.?)?|policy\s*(?:#|no\.?)?)\s*[:\#\-]?\s*[a-z0-9][a-z0-9\-]{3,}"#,
            // Policy / group numbers often labeled
            #"(?:policy|group)\s*(?:#|no\.?|number)?\s*[:\-]?\s*[a-z0-9]{6,}"#,
            // Age when explicitly labeled (avoid bare "N years" — catches disease duration)
            #"\bage\s*[:\-]?\s*\d{1,3}(?:\s*(?:years?|yrs?|y\.?|yo|y/o|y\.o\.))?\b"#,
            #"(?:^|\s)aged\s+\d{1,3}(?:\s*years?)?\b"#,
            #"(?:patient|pt)\s*age\s*[:\-]?\s*\d{1,3}"#,
            // Strong shorthand demographics (short lines typical on forms)
            #"\b\d{1,3}\s*(?:yo|y/o|y\.o\.)\b"#,
            // Sex / gender when labeled
            #"(?:^|\s)(?:sex|gender)\s*[:\-]?\s*(?:male|female|m|f|non[\s\-]?binary|nb)\b"#,
            // Titles + surname (normalized)
            #"(?:^|\s)(?:mr|mrs|ms|miss|dr|prof)\.?\s+[a-z][a-z'\-]{1,40}(?:\s+[a-z][a-z'\-]{1,40}){0,3}\b"#,
        ]

        return patterns.contains { patternMatches($0, in: normalized) }
    }

    /// Names and roles after explicit labels (normalized lowercase).
    private static func matchesLabeledNameOrPersonFields(_ normalized: String) -> Bool {
        let patterns: [String] = [
            // Patient / name / subject lines
            #"(?:^|\s)(?:patient|patient\s*name|pt\.?|pt\s*name|subject|recipient|beneficiary|insured)\s*[:\-]\s*[a-z][a-z'\-]{1,40}(?:\s+[a-z][a-z'\-]{1,40}){0,4}"#,
            #"(?:^|\s)(?:name|full\s*name)\s*[:\-]\s*[a-z][a-z'\-]{1,40}(?:\s+[a-z][a-z'\-]{1,40}){0,4}"#,
            // Providers & signers
            #"(?:^|\s)(?:physician|doctor|provider|attending|referring|ordering|rendering|prescriber|signed\s*by|ordering\s*physician|treating\s*physician)\s*[:\-]\s*[a-z][a-z'\-]{1,40}(?:\s+[a-z][a-z'\-]{1,40}){0,4}"#,
            #"(?:^|\s)(?:dictated\s*by|transcribed\s*by|approved\s*by)\s*[:\-]\s*[a-z][a-z'\-]{1,40}(?:\s+[a-z][a-z'\-]{1,40}){0,4}"#,
        ]
        return patterns.contains { patternMatches($0, in: normalized) }
    }

    // MARK: - Original casing / structure (catches header names OCR kept as Title Case)

    private static func matchesOriginalTextPatterns(_ text: String) -> Bool {
        let patterns: [String] = [
            // Title + one or more capitalized name tokens (avoid matching "Dr. in" etc. by requiring length)
            #"\b(?:Dr|Mr|Mrs|Ms|Miss|Prof)\.?\s+[A-Z][a-z]{1,}(?:\s+[A-Z][a-z]{1,}){0,3}\b"#,
            // Last, First (title case)
            #"\b[A-Z][a-z]{1,}'?[A-Za-z]*,\s*[A-Z][a-z]{1,}(?:\s+[A-Z][a-z]{1,})?\b"#,
            // Form headers often use ALL CAPS (require longer surname token to skip "WBC, RBC"-style lines)
            #"\b[A-Z]{4,}(?:'[A-Z]+)?,\s*[A-Z]{2,}(?:\s+[A-Z]{2,}){0,2}\b"#,
            // Labeled with value starting with capital (header blocks)
            #"(?i)\b(?:Patient|Pt|Name|Physician|Doctor|Provider|Signed\s*by)\s*[:\-]\s*[A-Z][^\n:]{1,80}"#,
        ]
        return patterns.contains { patternMatches($0, in: text) }
    }

    private static func patternMatches(_ pattern: String, in string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return false }
        let range = NSRange(location: 0, length: string.utf16.count)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}

// MARK: - CGRect Normalization

extension CGRect {
    /// Converts a Vision/normalized rect (origin: bottom-left, unit coordinates) to UIKit (origin: top-left, pixels)
    func denormalized(for imageSize: CGSize) -> CGRect {
        let x = self.origin.x * imageSize.width
        let height = self.size.height * imageSize.height
        let y = (1.0 - self.origin.y - self.size.height) * imageSize.height
        let width = self.size.width * imageSize.width
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - UIImage Redaction

extension UIImage {
    /// If input rects are in normalized coordinates, this denormalizes for you and applies redaction.
    func redacting(normalizedRects rects: [CGRect]) -> UIImage {
        let upright = self.withFixedOrientation()
        let pixelRects = rects.map { $0.denormalized(for: upright.size) }
        return upright.redacting(rects: pixelRects)
    }

    /// Redacts given rectangles (in pixel/image coordinates) on an upright image.
    func redacting(rects: [CGRect]) -> UIImage {
        let upright = self.withFixedOrientation()

        // Debug: check for obviously wrong input
        for rect in rects {
            if rect.origin.x < 0 || rect.origin.y < 0 || rect.maxX > upright.size.width || rect.maxY > upright.size.height {
                print("Warning: redacting out-of-bounds rect: \(rect) on image size \(upright.size)")
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = upright.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: upright.size, format: format)
        return renderer.image { ctx in
            upright.draw(at: .zero)
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            for rect in rects {
                ctx.cgContext.fill(rect)
            }
        }
    }

    /// Returns a new image oriented with .up (no rotation). If already .up, returns self.
    func withFixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
