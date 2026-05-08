import CoreML
import Foundation

struct CTCDecoder {
    func decode(logProbs: MLMultiArray, vocab: Vocab) -> String {
        let shape = logProbs.shape.map(\.intValue)
        guard shape.count >= 2 else {
            return ""
        }

        let vocabSize = vocab.total
        let classDim = shape.firstIndex(of: vocabSize) ?? (shape.count - 1)
        let timeDim = shape.indices.first { $0 != classDim && shape[$0] > 1 } ?? 0
        let timeSteps = shape[timeDim]

        var decoded: [Int] = []
        var previous: Int?

        for t in 0..<timeSteps {
            var bestClass = 0
            var bestScore = -Double.infinity

            for cls in 0..<vocabSize {
                var indices = Array(repeating: 0, count: shape.count)
                indices[timeDim] = t
                indices[classDim] = cls
                let nsIndices = indices.map { NSNumber(value: $0) }
                let score = logProbs[nsIndices].doubleValue

                if score > bestScore {
                    bestScore = score
                    bestClass = cls
                }
            }

            if bestClass != vocab.blankIndex, bestClass != previous {
                decoded.append(bestClass)
            }
            previous = bestClass
        }

        return decoded.map { vocab.idxToChar[$0] ?? vocab.unknownToken }.joined()
    }
}
