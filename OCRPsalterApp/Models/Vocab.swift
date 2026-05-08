import Foundation

struct VocabClass: Decodable {
    let char: String
    let idx: Int
}

struct VocabFile: Decodable {
    let total: Int
    let classes: [VocabClass]

    enum CodingKeys: String, CodingKey {
        case total = "_total"
        case classes
    }
}

struct Vocab {
    let blankIndex = 0
    let unknownToken = "<?>"
    let total: Int
    let idxToChar: [Int: String]

    static func loadFromBundle() throws -> Vocab {
        guard let url = Bundle.main.url(
            forResource: "vocab",
            withExtension: "json",
            subdirectory: "ModelResources/mobile_model_v1"
        ) else {
            throw OCRServiceError.vocabMissing
        }

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(VocabFile.self, from: data)
        var mapping: [Int: String] = [0: ""]

        for item in decoded.classes {
            if item.char == "<blank>" {
                mapping[item.idx] = ""
            } else if item.char == "<unk>" {
                mapping[item.idx] = "<?>"
            } else {
                mapping[item.idx] = item.char
            }
        }

        return Vocab(total: decoded.total, idxToChar: mapping)
    }
}
