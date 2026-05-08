import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var ocrService: OCRService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ScanPageView()
                    } label: {
                        Label("Сканировать страницу", systemImage: "doc.viewfinder")
                    }

                    NavigationLink {
                        SingleLineView()
                    } label: {
                        Label("Распознать строку", systemImage: "text.viewfinder")
                    }

                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("История", systemImage: "clock.arrow.circlepath")
                    }
                }

                Section("Модель") {
                    HStack {
                        Image(systemName: ocrService.isModelAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ocrService.isModelAvailable ? .green : .orange)
                        Text(ocrService.modelState)
                    }
                    if let error = ocrService.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Локальные результаты") {
                    HStack {
                        Text("Сохранено")
                        Spacer()
                        Text("\(historyStore.pages.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("OCR ЦС")
            .task {
                await ocrService.warmUp()
            }
        }
    }
}
