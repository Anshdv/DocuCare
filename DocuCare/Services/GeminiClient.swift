//
//  GeminiClient.swift
//  DocuCare
//
//  Created by Ansh D on 8/14/25.
//

import Foundation
import Network
import UIKit

struct GeminiClient {
    // MARK: - Networking profile
    private enum ConnectivityProfile {
        case normal
        case lowQuality

        var maxAttempts: Int {
            switch self {
            case .normal:
                return 3
            case .lowQuality:
                return 5
            }
        }

        var maxBackoffSeconds: Double {
            switch self {
            case .normal:
                return 8.0
            case .lowQuality:
                return 20.0
            }
        }
    }

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
        case leakedAPIKey
        case rateLimited
        case serviceUnavailable
        case invalidResponse(status: Int, body: String)
        case emptyOutput
    }

    private struct APIErrorEnvelope: Decodable {
        struct APIError: Decodable {
            let code: Int?
            let message: String?
            let status: String?
        }
        let error: APIError?
    }

    // MARK: - Properties
    let apiKey: String
    let model: String

    /// Model id for `v1beta/models/{model}:generateContent`. Older ids (e.g. `gemini-2.0-flash`) may return 404 for new API keys.
    static let defaultModelID = "gemini-2.5-flash"

    /// High ceiling so the model is not cut off mid-summary (e.g. missing bullets). Concise length is enforced in `GeminiPrompts`, not by capping this.
    static let summarizeOutputTokenCeiling = 4096

    init(model: String = GeminiClient.defaultModelID) throws {
        let plistKey = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String
        let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        let resolvedKey = (envKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? envKey : plistKey
        let key = resolvedKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Guard common placeholder values so runtime errors are actionable.
        let placeholderValues = [
            "YOUR_GEMINI_API_KEY",
            "$(GEMINI_API_KEY)",
            "REPLACE_ME"
        ]
        guard !key.isEmpty, !placeholderValues.contains(key) else {
            throw ClientError.missingAPIKey
        }

        self.apiKey = key
        self.model = model
    }

    // MARK: - Conversation memory

    /// One turn in a multi-turn chat. `role` must alternate user → model → user → model …
    /// starting with `.user`; the final turn passed to `AI_Response(turns:…)` must be the
    /// new user message.
    struct ChatTurn {
        enum Role { case user, model }
        let role: Role
        let text: String

        init(role: Role, text: String) {
            self.role = role
            self.text = text
        }

        fileprivate var apiRole: String {
            switch role {
            case .user: return "user"
            case .model: return "model"
            }
        }
    }

    // MARK: - Public API
    /// If `images` is provided, all images will be sent alongside the text.
    /// `prompt` should already include any output-language instructions (see `GeminiPrompts`).
    func AI_Response(text: String, prompt: String, images: [UIImage]? = nil, maxOutputTokens: Int = 500) async throws -> String {
        try await AI_Response(
            turns: [ChatTurn(role: .user, text: text)],
            prompt: prompt,
            images: images,
            maxOutputTokens: maxOutputTokens
        )
    }

    /// Multi-turn variant — pass the full prior conversation followed by the new user turn so
    /// the model has memory of earlier questions and answers. Images are attached to the
    /// **last** user turn only.
    func AI_Response(turns: [ChatTurn], prompt: String, images: [UIImage]? = nil, maxOutputTokens: Int = 500) async throws -> String {
        guard let lastTurn = turns.last, lastTurn.role == .user else {
            throw ClientError.emptyOutput
        }

        let systemPrompt = prompt
        let system = Content(role: "system", parts: [Part(text: systemPrompt)])

        var contents: [Content] = []
        for (index, turn) in turns.enumerated() {
            var parts: [Part] = [Part(text: turn.text)]
            if index == turns.count - 1, let images = images {
                for image in images {
                    parts.append(Part(image: image))
                }
            }
            contents.append(Content(role: turn.apiRole, parts: parts))
        }

        let body = RequestBody(
            systemInstruction: system,
            contents: contents,
            generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: maxOutputTokens)
        )

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequestWithRetry(request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no response body>"
            print("Gemini API error: status=\(http.statusCode) body=\(bodyString)")
            if http.statusCode == 403,
               let decoded = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data),
               let status = decoded.error?.status,
               let message = decoded.error?.message,
               status == "PERMISSION_DENIED",
               message.localizedCaseInsensitiveContains("reported as leaked") {
                throw ClientError.leakedAPIKey
            }
            if http.statusCode == 429 {
                throw ClientError.rateLimited
            }
            if http.statusCode == 503 {
                throw ClientError.serviceUnavailable
            }
            throw ClientError.invalidResponse(status: http.statusCode, body: bodyString)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let candidate = decoded.candidates?.first else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no response body>"
            print("Gemini API empty output: \(bodyString)")
            throw ClientError.emptyOutput
        }

        // Concatenate all text parts just in case there are multiple.
        let textOut = candidate.content.parts.compactMap { $0.text }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textOut.isEmpty else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<no response body>"
            print("Gemini API output was empty. Response: \(bodyString)")
            throw ClientError.emptyOutput
        }
        return textOut
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let connectivityProfile = connectivityProfile()
        let maxAttempts = connectivityProfile.maxAttempts
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    let retriableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
                    if retriableStatusCodes.contains(http.statusCode), attempt < maxAttempts {
                        try await Task.sleep(nanoseconds: retryDelayNanoseconds(from: http, attempt: attempt, maxBackoffSeconds: connectivityProfile.maxBackoffSeconds))
                        continue
                    }
                }
                return (data, response)
            } catch {
                lastError = error
                let retriableNetworkError = (error as? URLError).map { [.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed].contains($0.code) } ?? false
                if retriableNetworkError, attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds(from: nil, attempt: attempt, maxBackoffSeconds: connectivityProfile.maxBackoffSeconds))
                    continue
                }
                throw error
            }
        }
        throw lastError ?? ClientError.serviceUnavailable
    }

    private func retryDelayNanoseconds(from response: HTTPURLResponse?, attempt: Int, maxBackoffSeconds: Double) -> UInt64 {
        if let retryAfter = response?.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(retryAfter), seconds > 0 {
            return UInt64(seconds * 1_000_000_000)
        }
        let seconds = min(pow(2.0, Double(attempt - 1)), maxBackoffSeconds)
        return UInt64(seconds * 1_000_000_000)
    }

    private func connectivityProfile() -> ConnectivityProfile {
        let monitor = NWPathMonitor()
        defer { monitor.cancel() }
        let queue = DispatchQueue(label: "DocuCare.GeminiClient.ConnectivityProbe")
        let semaphore = DispatchSemaphore(value: 0)
        var pathSnapshot: NWPath?

        monitor.pathUpdateHandler = { path in
            pathSnapshot = path
            semaphore.signal()
        }

        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 1.0)

        guard let path = pathSnapshot else {
            return .normal
        }

        if path.status != .satisfied || path.isConstrained || path.isExpensive {
            return .lowQuality
        }

        return .normal
    }
}

extension GeminiClient.ClientError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini API key is missing. Set GEMINI_API_KEY in your app config."
        case .leakedAPIKey:
            return "Gemini API key was flagged as leaked. Generate a new key and update GEMINI_API_KEY."
        case .rateLimited:
            return "Gemini API quota/rate limit reached. Try again shortly or increase your quota."
        case .serviceUnavailable:
            return "Gemini service is temporarily unavailable (503). Please try again."
        case .invalidResponse(let status, _):
            return "Gemini API request failed with status \(status)."
        case .emptyOutput:
            return "Gemini returned an empty response."
        }
    }
}

