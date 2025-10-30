//
//  TextRecognizer.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import Foundation
import Vision
import UIKit

enum TextRecognizer {
    static func recognizeText(from images: [UIImage]) async throws -> (text: String, perPage: [String]) {
        var allText: [String] = []
        var perPage: [String] = []

        for img in images {
            let pageText = try await recognizeSingle(image: img)
            perPage.append(pageText)
            allText.append(pageText)
        }
        return (allText.joined(separator: "\n\n— Page Break —\n\n"), perPage)
    }

    private static func recognizeSingle(image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err = err { cont.resume(throwing: err); return }
                let lines = (req.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                cont.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cg)
            do { try handler.perform([request]) } catch { cont.resume(throwing: error) }
        }
    }

    // Returns all recognized lines and their bounding boxes (in image coordinates) for a single image.
    static func recognizeTextWithBoundingBoxes(from image: UIImage) async throws -> [(text: String, boundingBox: CGRect)] {
        guard let cg = image.cgImage else { return [] }
        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { req, err in
                if let err = err { cont.resume(throwing: err); return }
                guard let results = req.results as? [VNRecognizedTextObservation], !results.isEmpty else {
                    cont.resume(returning: [])
                    return
                }
                var resultsWithBoxes: [(String, CGRect)] = []
                for obs in results {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    // obs.boundingBox is in normalized coordinates (0,0) bottom-left, (1,1) top-right
                    let normRect = obs.boundingBox
                    let imgW = CGFloat(cg.width)
                    let imgH = CGFloat(cg.height)
                    // Transform to pixel/image coordinates (UIKit: origin at top-left)
                    let imageRect = CGRect(
                        x: normRect.origin.x * imgW,
                        y: (1 - normRect.origin.y - normRect.size.height) * imgH,
                        width: normRect.size.width * imgW,
                        height: normRect.size.height * imgH
                    )
                    resultsWithBoxes.append((candidate.string, imageRect))
                }
                cont.resume(returning: resultsWithBoxes)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cg)
            do { try handler.perform([request]) } catch { cont.resume(throwing: error) }
        }
    }
}
