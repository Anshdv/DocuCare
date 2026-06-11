import Foundation

/// One multiple-choice question generated for a daily health lesson.
///
/// Persisted indirectly: an array of these is JSON-encoded into `DailyLesson.questionsJSON`,
/// which avoids SwiftData's quirks with nested-collection attributes.
struct LessonQuestion: Codable, Identifiable, Hashable {
    let id: UUID
    let prompt: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String

    init(
        id: UUID = UUID(),
        prompt: String,
        choices: [String],
        correctIndex: Int,
        explanation: String
    ) {
        self.id = id
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.explanation = explanation
    }

    /// Defensive: clamp `correctIndex` into range to avoid crashes if Gemini ever returns an out-of-bounds value.
    var safeCorrectIndex: Int {
        guard !choices.isEmpty else { return 0 }
        return max(0, min(correctIndex, choices.count - 1))
    }
}

enum LessonQuestionCoder {
    static func encode(_ questions: [LessonQuestion]) -> String {
        guard let data = try? JSONEncoder().encode(questions),
              let str = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return str
    }

    static func decode(_ json: String) -> [LessonQuestion] {
        guard let data = json.data(using: .utf8),
              let questions = try? JSONDecoder().decode([LessonQuestion].self, from: data) else {
            return []
        }
        return questions
    }
}
