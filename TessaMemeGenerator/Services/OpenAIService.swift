import UIKit

enum OpenAIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Add it to Config/Secrets.xcconfig."
        case .invalidResponse:
            return "Could not parse caption response."
        case .apiError(let message):
            return message
        }
    }
}

struct OpenAIService {
    private let apiKey: String

    init() throws {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !key.isEmpty,
              key != "sk-your-key-here" else {
            throw OpenAIServiceError.missingAPIKey
        }
        self.apiKey = key
    }

    func generateCaptions(for image: UIImage, steeringText: String) async throws -> [String] {
        let resized = resize(image: image, maxWidth: 1024)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else {
            throw OpenAIServiceError.invalidResponse
        }

        let base64 = jpegData.base64EncodedString()
        let prompt = buildPrompt(steeringText: steeringText)

        let body: [String: Any] = [
            "model": "gpt-4o",
            "response_format": ["type": "json_object"],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = String(data: data, encoding: .utf8) ?? "Request failed."
            throw OpenAIServiceError.apiError(message)
        }

        let apiResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else {
            throw OpenAIServiceError.invalidResponse
        }

        let result = try JSONDecoder().decode(CaptionResult.self, from: contentData)
        let captions = result.captions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !captions.isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        return captions
    }

    private func buildPrompt(steeringText: String) -> String {
        var prompt = """
        You are a witty meme caption writer. Analyze this image and its context.
        Generate exactly 4 short, funny, meme-style captions (max 15 words each, ALL CAPS).
        Return JSON only: {"captions": ["...", "...", "...", "..."]}.
        """

        let trimmed = steeringText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            prompt += "\nIncorporate this idea from the user: \(trimmed)"
        }

        return prompt
    }

    private func resize(image: UIImage, maxWidth: CGFloat) -> UIImage {
        guard image.size.width > maxWidth else { return image }

        let scale = maxWidth / image.size.width
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
