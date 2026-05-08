import Foundation

struct RecognizedPage: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var title: String
    var lines: [RecognizedLine]
    var source: RecognitionSource

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String = "Распознавание",
        lines: [RecognizedLine],
        source: RecognitionSource
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.lines = lines
        self.source = source
    }

    var plainText: String {
        lines
            .filter(\.isEnabled)
            .sorted { $0.index < $1.index }
            .map(\.text)
            .joined(separator: "\n")
    }

    var preview: String {
        let text = plainText.replacingOccurrences(of: "\n", with: " ")
        if text.count <= 90 {
            return text.isEmpty ? "Без текста" : text
        }
        return String(text.prefix(90)) + "..."
    }
}

enum RecognitionSource: String, Codable, Hashable {
    case pageScan
    case singleLine
    case history
}
