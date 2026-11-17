//
//  AIExpenseService.swift
//  AIExpenseTracker
//
//  Created by Ajay on 17/11/26.
//
//
//  AIExpenseService.swift
//  AIExpenseTracker
//
//
//  AIExpenseService.swift
//  AIExpenseTracker
//
import UIKit

enum ExpenseServiceError: LocalizedError {
    case missingKey
    case imageEncoding
    case api(status: Int, message: String)
    case blocked(String)
    case emptyResponse
    case badJSON(String)
    case network(URLError)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "API key not set. Paste your key in Secrets.swift."
        case .imageEncoding:
            return "Could not encode the selected image."
        case .api(let status, let message):
            return "Gemini error \(status): \(message)"
        case .blocked(let reason):
            return "Request blocked by Gemini (\(reason))."
        case .emptyResponse:
            return "Gemini returned an empty response."
        case .badJSON(let raw):
            return "Could not parse Gemini output: \(raw.prefix(200))"
        case .network(let e):
            if e.code == .timedOut {
                return "Network timed out reaching Google. Check VPN/Wi-Fi, then try again."
            }
            return "Network error: \(e.localizedDescription)"
        }
    }
}

final class AIExpenseService {

    // Tried in order. If one is overloaded (503/429) or missing (404), the next is used.
    private let models = ["gemini-3.8-flash", "gemini-3.7-flash", "gemini-flash-latest"]

    private func endpoint(for model: String) -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    // Ephemeral session: no stale cache/connection reuse, fails fast instead of hanging.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func extractExpense(from image: UIImage) async throws -> ExpenseReceipt {
        let apiKey = Secrets.geminiAPIKey
        guard !apiKey.isEmpty, apiKey != "PASTE_YOUR_NEW_KEY_HERE" else {
            throw ExpenseServiceError.missingKey
        }

        // 1. Resize + compress
        guard let jpeg = resizeImage(image).jpegData(compressionQuality: 0.6) else {
            throw ExpenseServiceError.imageEncoding
        }

        // 2. Request body
        let prompt = """
        Analyze this receipt or invoice. Extract the merchant name, date, total amount, \
        tax amount (0 if none), an expense category, and whether it looks like a recurring subscription.
        """
        let body = GeminiRequest(
            contents: [
                GeminiContent(parts: [
                    GeminiPart(text: prompt, inlineData: nil),
                    GeminiPart(text: nil, inlineData: InlineData(mimeType: "image/jpeg",
                                                                data: jpeg.base64EncodedString()))
                ])
            ],
            generationConfig: GenerationConfig(responseMimeType: "application/json",
                                               responseSchema: .expense,
                                               temperature: 0)
        )

        let bodyData = try JSONEncoder().encode(body)
        var lastError: Error = URLError(.unknown)

        for model in models {
            var request = URLRequest(url: endpoint(for: model))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            request.assumesHTTP3Capable = false
            request.httpBody = bodyData

            let attemptsPerModel = 2
            for attempt in 1...attemptsPerModel {
                do {
                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

                    if http.statusCode == 200 {
                        print("✅ Success with \(model)")
                        return try parse(data)
                    }

                    let message = (try? JSONDecoder().decode(GeminiErrorEnvelope.self, from: data))?.error.message
                        ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                    let err = ExpenseServiceError.api(status: http.statusCode, message: message)
                    print("⚠️ \(model) HTTP \(http.statusCode): \(message)")
                    lastError = err

                    switch http.statusCode {
                    case 503, 429, 500, 502, 504:
                        break                      // retry, then fall through to next model
                    case 404:
                        break                      // model not available -> next model
                    default:
                        throw err                  // 400/401/403: retrying or switching won't help
                    }
                } catch let urlError as URLError {
                    print("⚠️ \(model) URLError \(urlError.code.rawValue)")
                    lastError = ExpenseServiceError.network(urlError)
                    let retryable: [URLError.Code] = [.timedOut, .networkConnectionLost, .cannotConnectToHost]
                    if !retryable.contains(urlError.code) { throw lastError }
                }

                // Skip waiting on 404 (retrying the same missing model is pointless)
                if case .api(let status, _)? = lastError as? ExpenseServiceError, status == 404 { break }
                if attempt < attemptsPerModel {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                }
            }
        }
        throw lastError
    }

    // MARK: - Parsing
    private func parse(_ data: Data) throws -> ExpenseReceipt {
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)

        if let reason = decoded.promptFeedback?.blockReason { throw ExpenseServiceError.blocked(reason) }

        guard var text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
              !text.isEmpty else { throw ExpenseServiceError.emptyResponse }

        // Safety net in case the model wraps JSON in ``` fences
        text = text.replacingOccurrences(of: "```json", with: "")
                   .replacingOccurrences(of: "```", with: "")
                   .trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            return try JSONDecoder().decode(ExpenseReceipt.self, from: Data(text.utf8))
        } catch {
            throw ExpenseServiceError.badJSON(text)
        }
    }

    // MARK: - Image resize (keeps aspect ratio, never upscales)
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat = 1280) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
