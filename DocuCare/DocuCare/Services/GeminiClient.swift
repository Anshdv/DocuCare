//
//  GeminiClient.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import Foundation
import UIKit

struct GeminiClient {
    // MARK: - Types
    struct Part: Codable {
        let text: String?
        let inlineData: InlineData?

        struct InlineData: Codable {
            let mimeType: String
            let data: String
        }

        // For text part
        init(text: String) {
            self.text = text
            self.inlineData = nil
        }

        // For image part
        init(image: UIImage) {
            self.text = nil
            // We'll use JPEG for broad compatibility
            let jpegData = image.jpegData(compressionQuality: 0.9)!
            self.inlineData = InlineData(
                mimeType: "image/jpeg",
                data: jpegData.base64EncodedString()
            )
        }
    }

    struct Content: Codable {
        let role: String?
        let parts: [Part]
    }
    struct GenerationConfig: Codable {
        let temperature: Double?
        let maxOutputTokens: Int?
    }
    struct RequestBody: Codable {
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }
    struct ResponseBody: Codable {
        struct Candidate: Codable {
            let content: Content
        }
        let candidates: [Candidate]?
    }

    enum ClientError: Error {
        case missingAPIKey
        case invalidResponse
        case emptyOutput
    }

    // MARK: - Properties
    let apiKey: String
    let model: String

    init(model: String = "gemini-2.0-flash") throws {
        self.apiKey = "AIzaSyAkLyVMlk1uJsezC8kE1NhtoxFoTOVb_9g"
        self.model = "gemini-2.0-flash"
    }

    // MARK: - Public API
    /// If `images` is provided, all images will be sent alongside the text.
    func AI_Response(text: String, prompt: String, images: [UIImage]? = nil) async throws -> String {
        let systemPrompt = prompt

        let system = Content(role: "system", parts: [Part(text: systemPrompt)])
        var userParts: [Part] = [Part(text: text)]
        if let images = images {
            for image in images {
                userParts.append(Part(image: image))
            }
        }
        let user = Content(role: "user", parts: userParts)

        let body = RequestBody(
            systemInstruction: system,
            contents: [user],
            generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 500)
        )

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let candidate = decoded.candidates?.first else { throw ClientError.emptyOutput }

        // Concatenate all text parts just in case there are multiple.
        let textOut = candidate.content.parts.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textOut.isEmpty else { throw ClientError.emptyOutput }
        return textOut
    }
}

