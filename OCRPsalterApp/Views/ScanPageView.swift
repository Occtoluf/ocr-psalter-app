import SwiftUI

struct ScanPageView: View {
    @State private var isScannerPresented = false
    @State private var scannedImage: UIImage?
    @State private var candidates: [LineCandidate] = []
    @State private var isSegmenting = false
    @State private var errorMessage: String?

    private let segmenter = PageLineSegmenter()

    var body: some View {
        VStack(spacing: 0) {
            if let scannedImage {
                Image(uiImage: scannedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .background(Color(.secondarySystemBackground))
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(candidates.count) строк")
                            .font(.caption)
                            .padding(8)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                    }
            } else {
                EmptyStateView(
                    title: "Страница не выбрана",
                    systemImage: "doc.viewfinder",
                    message: "Отсканируйте одну страницу печатного церковнославянского текста."
                )
            }

            List {
                Section {
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label(scannedImage == nil ? "Открыть сканер" : "Переснять страницу", systemImage: "camera.viewfinder")
                    }

                    if scannedImage != nil {
                        NavigationLink {
                            LineReviewView(candidates: candidates, source: .pageScan)
                        } label: {
                            Label("Проверить строки", systemImage: "text.line.first.and.arrowtriangle.forward")
                        }
                        .disabled(candidates.isEmpty || isSegmenting)
                    }
                }

                if isSegmenting {
                    Section {
                        ProgressView("Идёт выделение строк")
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                }

                if !candidates.isEmpty {
                    Section("Найденные строки") {
                        ForEach(candidates.prefix(6)) { candidate in
                            HStack {
                                Text("\(candidate.index)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)
                                Image(uiImage: candidate.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 34)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Скан страницы")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isScannerPresented) {
            DocumentScannerView { images in
                guard let first = images.first else {
                    return
                }
                scannedImage = first
                segment(first)
            } onCancel: {}
        }
    }

    private func segment(_ image: UIImage) {
        isSegmenting = true
        errorMessage = nil

        Task.detached {
            let found = segmenter.segment(image: image)
            await MainActor.run {
                candidates = found
                isSegmenting = false
                if found.isEmpty {
                    errorMessage = "Строки не найдены. Попробуйте переснять страницу ровнее или используйте режим одной строки."
                }
            }
        }
    }
}
