import Foundation
import SwiftUI

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var pages: [RecognizedPage] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("ocr_history.json")
        load()
    }

    func add(_ page: RecognizedPage) {
        var stored = page
        stored.title = title(for: page)
        pages.insert(stored, at: 0)
        save()
    }

    func update(_ page: RecognizedPage) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else {
            add(page)
            return
        }
        pages[index] = page
        save()
    }

    func delete(at offsets: IndexSet) {
        pages.remove(atOffsets: offsets)
        save()
    }

    private func title(for page: RecognizedPage) -> String {
        switch page.source {
        case .pageScan:
            return "Страница"
        case .singleLine:
            return "Строка"
        case .history:
            return page.title
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            pages = try JSONDecoder().decode([RecognizedPage].self, from: data)
        } catch {
            pages = []
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(pages)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save OCR history: \(error)")
        }
    }
}
