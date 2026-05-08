import Foundation

struct RecognizedLine: Identifiable, Codable, Hashable {
    var id: UUID
    var index: Int
    var text: String
    var confidence: Double?
    var isEnabled: Bool
    var cropPNGData: Data?

    init(
        id: UUID = UUID(),
        index: Int,
        text: String = "",
        confidence: Double? = nil,
        isEnabled: Bool = true,
        cropPNGData: Data? = nil
    ) {
        self.id = id
        self.index = index
        self.text = text
        self.confidence = confidence
        self.isEnabled = isEnabled
        self.cropPNGData = cropPNGData
    }
}
