import Foundation

struct ModelMetadata: Decodable {
    struct Metrics: Decodable {
        let cer: Double?
        let wer: Double?
        let diacriticAccuracy: Double?

        enum CodingKeys: String, CodingKey {
            case cer
            case wer
            case diacriticAccuracy = "diacritic_accuracy"
        }
    }

    let name: String
    let coremlModel: String?
    let sourceCheckpoint: String?
    let architecture: String?
    let vocabSize: Int?
    let inputHeight: Int?
    let inputWidth: Int?
    let metrics: Metrics?

    enum CodingKeys: String, CodingKey {
        case name
        case coremlModel = "coreml_model"
        case sourceCheckpoint = "source_checkpoint"
        case architecture
        case vocabSize = "vocab_size"
        case inputHeight = "input_height"
        case inputWidth = "input_width"
        case metrics
    }
}
