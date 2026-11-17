//
//  GeminiRequest.swift
//  AIExpenseTracker
//
//  Created by Ajay on 17/11/26.
//

//
//  GeminiRequest.swift
//  AIExpenseTracker
//
import Foundation

// MARK: - Request Models
struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let generationConfig: GenerationConfig
}

struct GeminiContent: Encodable {
    let parts: [GeminiPart]
}

struct GeminiPart: Encodable {
    var text: String?
    var inlineData: InlineData?
}

struct InlineData: Encodable {
    let mimeType: String
    let data: String // Base64 image string
}

struct GenerationConfig: Encodable {
    let responseMimeType: String
    let responseSchema: GeminiSchema?
    let temperature: Double?
}

/// Minimal OpenAPI-style schema so Gemini is forced to return exact keys/types.
final class GeminiSchema: Encodable {
    let type: String
    let description: String?
    let properties: [String: GeminiSchema]?
    let required: [String]?

    init(type: String,
         description: String? = nil,
         properties: [String: GeminiSchema]? = nil,
         required: [String]? = nil) {
        self.type = type
        self.description = description
        self.properties = properties
        self.required = required
    }

    static let expense = GeminiSchema(
        type: "OBJECT",
        properties: [
            "merchantName":   GeminiSchema(type: "STRING"),
            "date":           GeminiSchema(type: "STRING", description: "YYYY-MM-DD if possible"),
            "totalAmount":    GeminiSchema(type: "NUMBER"),
            "taxAmount":      GeminiSchema(type: "NUMBER", description: "0 if no tax shown"),
            "category":       GeminiSchema(type: "STRING", description: "Food, Travel, Shopping, Utilities, Entertainment, Health, Other"),
            "isSubscription": GeminiSchema(type: "BOOLEAN")
        ],
        required: ["merchantName", "date", "totalAmount", "taxAmount", "category", "isSubscription"]
    )
}

// MARK: - Response Models
struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
    let promptFeedback: PromptFeedback?
}

struct PromptFeedback: Decodable {
    let blockReason: String?
}

struct Candidate: Decodable {
    let content: ResponseContent?
    let finishReason: String?
}

struct ResponseContent: Decodable {
    let parts: [ResponsePart]?
}

struct ResponsePart: Decodable {
    let text: String?
}

struct GeminiErrorEnvelope: Decodable {
    struct Body: Decodable { let code: Int?; let message: String?; let status: String? }
    let error: Body
}
