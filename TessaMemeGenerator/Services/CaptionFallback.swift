import Foundation

enum CaptionFallback {
    static func generate(steeringText: String) -> [String] {
        let trimmed = steeringText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            return [
                "\(trimmed.uppercased())",
                "WHEN \(trimmed.uppercased()) HITS DIFFERENT",
                "ME TRYING TO \(trimmed.uppercased())",
                "NOBODY: ... ME: \(trimmed.uppercased())"
            ]
        }

        return [
            "WHEN YOU SEE IT",
            "ME RIGHT NOW",
            "IT BE LIKE THAT SOMETIMES",
            "NOBODY: ... ABSOLUTELY NOBODY:"
        ]
    }
}
