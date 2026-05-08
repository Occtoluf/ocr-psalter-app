import PhotosUI
import SwiftUI

struct SingleLineView: View {
    @EnvironmentObject private var ocrService: OCRService

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var resultPage: RecognizedPage?
    @State private var isRecognizing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Выбрать изображение строки", systemImage: "photo")
                }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 130)

                    Button {
                        recognize(selectedImage)
                    } label: {
                        Label(isRecognizing ? "Распознавание" : "Распознать", systemImage: "play.fill")
                    }
                    .disabled(isRecognizing)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Одна строка")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { item in
            load(item)
        }
        .navigationDestination(item: $resultPage) { page in
            ResultView(page: page)
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else {
            return
        }

        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image
                resultPage = nil
                errorMessage = nil
            }
        }
    }

    private func recognize(_ image: UIImage) {
        isRecognizing = true
        errorMessage = nil

        Task {
            do {
                let candidate = LineCandidate(index: 1, rect: .zero, image: image)
                let line = try await ocrService.recognize(candidate: candidate)
                resultPage = RecognizedPage(lines: [line], source: .singleLine)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRecognizing = false
        }
    }
}
