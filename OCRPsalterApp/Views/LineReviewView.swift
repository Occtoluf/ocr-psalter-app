import SwiftUI

struct LineReviewView: View {
    @EnvironmentObject private var ocrService: OCRService

    @State var candidates: [LineCandidate]
    let source: RecognitionSource

    @State private var isRecognizing = false
    @State private var progressText = ""
    @State private var resultPage: RecognizedPage?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    recognize()
                } label: {
                    if isRecognizing {
                        Label(progressText, systemImage: "hourglass")
                    } else {
                        Label("Распознать выбранные строки", systemImage: "play.fill")
                    }
                }
                .disabled(isRecognizing || candidates.filter(\.isEnabled).isEmpty)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Строки") {
                ForEach($candidates) { $candidate in
                    HStack(alignment: .center, spacing: 12) {
                        Toggle("", isOn: $candidate.isEnabled)
                            .labelsHidden()
                        Text("\(candidate.index)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        Image(uiImage: candidate.image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                            .opacity(candidate.isEnabled ? 1 : 0.35)
                    }
                }
            }
        }
        .navigationTitle("Проверка строк")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $resultPage) { page in
            ResultView(page: page)
        }
    }

    private func recognize() {
        isRecognizing = true
        errorMessage = nil
        progressText = "Подготовка"

        Task {
            do {
                let lines = try await ocrService.recognize(candidates: candidates) { done, total in
                    progressText = "\(done) из \(total)"
                }
                resultPage = RecognizedPage(lines: lines, source: source)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRecognizing = false
        }
    }
}
