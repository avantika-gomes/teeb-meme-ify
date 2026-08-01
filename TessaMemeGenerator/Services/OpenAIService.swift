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

/// Ambient context handed to the model alongside the photo.
///
/// Deliberately derived without GPS. Blind testing showed that reverse-geocoded placemarks
/// ("Lincoln Square, New York, NY") pushed the model into name-dropping the neighborhood, which
/// scored worse than supplying no location at all. Day, time, and city are cheap, permission-free,
/// and offered to the model as strictly optional colour.
struct CaptionContext {
    let capturedAt: Date
    let cityName: String?

    static func forPhoto(capturedAt: Date) -> CaptionContext {
        CaptionContext(capturedAt: capturedAt, cityName: currentCityName())
    }

    /// The device time zone doubles as a coarse city hint: "America/New_York" becomes "New York".
    private static func currentCityName() -> String? {
        guard let component = TimeZone.current.identifier.split(separator: "/").last else {
            return nil
        }
        let city = component.replacingOccurrences(of: "_", with: " ")
        return city.isEmpty ? nil : city
    }

    var promptLine: String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"

        var line = "\(formatter.string(from: capturedAt)) \(timeOfDay)"
        if let cityName {
            line += ", \(cityName)"
        }
        return line
    }

    private var timeOfDay: String {
        switch Calendar.current.component(.hour, from: capturedAt) {
        case 5..<9: return "early morning"
        case 9..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "late night"
        }
    }
}

/// The two prompts that won blind head-to-head testing. They favour different photos — the
/// candidate-scoring style tends to win busy scenes, the self-roast style tends to win portraits —
/// so the app runs both and mixes the results.
enum CaptionStyle: CaseIterable {
    case bestOfTwelve
    case drySelfRoast

    private static let optionalContext = """
    OPTIONAL CONTEXT: the line below may give the day, time of day, and city. Using it is optional. \
    If the time of day, the place, or the city makes a caption funnier or wittier, work it in. \
    If it adds nothing, ignore it.
    """

    var template: String {
        switch self {
        case .bestOfTwelve:
            return """
            Generate twelve witty candidate meme captions for this photo. Range widely — different angles, \
            different kinds of funny. Do not self-censor at this stage.

            Then score each candidate from 1 to 10 on:
            - SURPRISE: would a reader expect this caption, or does it land sideways?
            - SPECIFICITY: is it anchored to this exact photo?
            - SURVIVAL: penalize heavily if the caption would work just as well on a different photo.

            Return the four highest scoring captions, in "captions".

            RULES for all candidates:
            - Max 15 words each. ALL CAPS.
            - No puns or wordplay. No hashtags, no emojis.

            \(Self.optionalContext)

            Return JSON only:
            {"candidates": [{"text": "...", "surprise": 0, "specificity": 0, "survival": 0}], \
            "captions": ["...", "...", "...", "..."]}
            """

        case .drySelfRoast:
            return """
            You write meme captions for people roasting themselves — dry, sarcastic, unexpectedly sharp.

            READ THE IMAGE FIRST. What's actually happening? The joke lives in the specific moment, \
            not a template.

            VOICE:
            - Self-deprecating. The person in the photo (or their inner monologue) is the punchline.
            - Sarcastic but warm — like texting your group chat, not performing for strangers.
            - Wit from observation. If you can swap the photo and the caption still works, it's too generic.

            BANNED:
            - Puns and wordplay
            - Tired meme formats used lazily ("nobody:", "when you see it", "it be like that")
            - Explaining the joke
            - Hashtags, emojis

            \(Self.optionalContext)

            4 captions. Max 15 words each. ALL CAPS.
            Return JSON only: {"captions": ["...", "...", "...", "..."]}
            """
        }
    }
}

struct OpenAIService {
    /// Captions kept from each style. Both styles run, so the user sees twice this many.
    static let captionsPerStyle = 3

    private let apiKey: String

    init() throws {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !key.isEmpty,
              key != "sk-your-key-here" else {
            throw OpenAIServiceError.missingAPIKey
        }
        self.apiKey = key
    }

    /// Emits captions as each style lands rather than waiting for both.
    ///
    /// The self-roast style returns in roughly two seconds while the candidate-scoring style takes
    /// three times as long, because it writes far more tokens before it answers. Yielding the fast
    /// result immediately means the user is reading captions while the slower one is still running.
    /// Each element is the full list so far, and captions are only ever appended, so rows never
    /// reorder under the user's finger.
    func captionStream(
        for image: UIImage,
        steeringText: String,
        context: CaptionContext
    ) -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let work = Task {
                let resized = resize(image: image, maxWidth: 1024)
                guard let jpegData = resized.jpegData(compressionQuality: 0.8) else {
                    continuation.finish()
                    return
                }

                let base64 = jpegData.base64EncodedString()
                let key = apiKey
                let target = Self.captionsPerStyle * CaptionStyle.allCases.count

                var shown: [String] = []
                var seen = Set<String>()
                var pool: [String] = []

                func append(_ caption: String) -> Bool {
                    let cleaned = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                    let identity = cleaned.uppercased().filter { $0.isLetter || $0.isNumber }
                    guard !identity.isEmpty, !seen.contains(identity) else { return false }
                    seen.insert(identity)
                    shown.append(cleaned)
                    return true
                }

                await withTaskGroup(of: [String]?.self) { group in
                    for style in CaptionStyle.allCases {
                        group.addTask {
                            try? await requestCaptions(
                                style: style,
                                base64: base64,
                                steeringText: steeringText,
                                context: context,
                                apiKey: key
                            )
                        }
                    }

                    for await captions in group {
                        guard let captions, !Task.isCancelled else { continue }
                        pool.append(contentsOf: captions)

                        var takenFromStyle = 0
                        for caption in captions where takenFromStyle < Self.captionsPerStyle {
                            if append(caption) { takenFromStyle += 1 }
                        }

                        if !shown.isEmpty {
                            continuation.yield(shown)
                        }
                    }
                }

                // If a style failed, top up from whatever the survivor had left over.
                if shown.count < target {
                    var backfilled = false
                    for caption in pool where shown.count < target {
                        if append(caption) { backfilled = true }
                    }
                    if backfilled {
                        continuation.yield(shown)
                    }
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in work.cancel() }
        }
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

private func buildPrompt(
    style: CaptionStyle,
    steeringText: String,
    context: CaptionContext
) -> String {
    var prompt = style.template

    if let line = context.promptLine {
        prompt += "\n\nContext: \(line)"
    }

    // Stated as an override rather than a suggestion. The scoring style ranks candidates on
    // surprise and specificity, neither of which rewards following the steer, so a milder phrasing
    // let steered candidates get scored out of the final four.
    let trimmed = steeringText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        prompt += """


        USER STEER — HIGHEST PRIORITY: \(trimmed)
        Every caption you return must build on this. It outranks the selection criteria above: a \
        caption that ignores it cannot be returned, however good it is otherwise.
        """
    }

    return prompt
}

private func requestCaptions(
    style: CaptionStyle,
    base64: String,
    steeringText: String,
    context: CaptionContext,
    apiKey: String
) async throws -> [String] {
    let prompt = buildPrompt(style: style, steeringText: steeringText, context: context)

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

    // The candidate-scoring style also returns a `candidates` array; the decoder ignores it.
    let result = try JSONDecoder().decode(CaptionResult.self, from: contentData)
    let captions = result.captions
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    guard !captions.isEmpty else {
        throw OpenAIServiceError.invalidResponse
    }
    return captions
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
