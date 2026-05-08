import CoreML
import Foundation
import UIKit

enum OCRServiceError: LocalizedError {
    case modelMissing
    case vocabMissing
    case invalidModelOutput
    case preprocessingFailed

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "Core ML модель не найдена. Добавьте CRNNLineRecognizer.mlpackage или .mlmodelc в ModelResources/mobile_model_v1."
        case .vocabMissing:
            return "vocab.json не найден в пакете модели."
        case .invalidModelOutput:
            return "Core ML модель вернула выход в неожиданном формате."
        case .preprocessingFailed:
            return "Не удалось подготовить изображение строки для модели."
        }
    }
}

@MainActor
final class OCRService: ObservableObject {
    @Published private(set) var modelState: String = "Модель не загружена"
    @Published private(set) var lastError: String?

    private var model: MLModel?
    private var vocab: Vocab?
    private let preprocessor = LineImagePreprocessor()
    private let decoder = CTCDecoder()

    let inputHeight = 48
    let inputWidth = 1024

    var isModelAvailable: Bool {
        model != nil
    }

    func warmUp() async {
        do {
            try await loadIfNeeded()
        } catch {
            lastError = error.localizedDescription
            modelState = "Модель не найдена"
        }
    }

    func recognize(candidate: LineCandidate) async throws -> RecognizedLine {
        try await loadIfNeeded()
        guard let model, let vocab else {
            throw OCRServiceError.modelMissing
        }

        let input = try preprocessor.makeInputArray(
            from: candidate.image,
            targetHeight: inputHeight,
            targetWidth: inputWidth
        )
        let provider = try MLDictionaryFeatureProvider(dictionary: ["line_image": input])
        let prediction = try model.prediction(from: provider)

        guard let logProbs = prediction.featureValue(for: "log_probs")?.multiArrayValue
            ?? prediction.featureValue(for: "var_0")?.multiArrayValue
            ?? prediction.featureValue(for: "Identity")?.multiArrayValue
        else {
            throw OCRServiceError.invalidModelOutput
        }

        let text = decoder.decode(logProbs: logProbs, vocab: vocab)
        return RecognizedLine(
            index: candidate.index,
            text: text,
            confidence: nil,
            isEnabled: candidate.isEnabled,
            cropPNGData: candidate.image.pngData()
        )
    }

    func recognize(candidates: [LineCandidate], progress: @escaping @MainActor (Int, Int) -> Void) async throws -> [RecognizedLine] {
        var result: [RecognizedLine] = []
        let enabled = candidates.filter(\.isEnabled).sorted { $0.index < $1.index }

        for (offset, candidate) in enabled.enumerated() {
            let line = try await recognize(candidate: candidate)
            result.append(line)
            await progress(offset + 1, enabled.count)
        }

        return result
    }

    private func loadIfNeeded() async throws {
        if model != nil, vocab != nil {
            return
        }

        vocab = try Vocab.loadFromBundle()
        guard let modelURL = Self.findModelURL() else {
            modelState = "Core ML модель отсутствует"
            throw OCRServiceError.modelMissing
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        let loadURL: URL
        if modelURL.pathExtension == "mlmodel" || modelURL.pathExtension == "mlpackage" {
            loadURL = try MLModel.compileModel(at: modelURL)
        } else {
            loadURL = modelURL
        }

        model = try MLModel(contentsOf: loadURL, configuration: config)
        modelState = "Модель загружена"
        lastError = nil
    }

    private static func findModelURL() -> URL? {
        guard let root = Bundle.main.resourceURL else {
            return nil
        }

        let base = root.appendingPathComponent("ModelResources/mobile_model_v1")
        let candidates = [
            "CRNNLineRecognizer.mlmodelc",
            "CRNNLineRecognizer.mlpackage",
            "CRNNLineRecognizer.mlmodel"
        ]

        for name in candidates {
            let url = base.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
