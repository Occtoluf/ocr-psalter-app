import SwiftUI
import UIKit

struct ResultView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    @State var page: RecognizedPage
    @State private var didSave = false

    var body: some View {
        List {
            Section {
                Button {
                    UIPasteboard.general.string = page.plainText
                } label: {
                    Label("Копировать текст", systemImage: "doc.on.doc")
                }

                Button {
                    historyStore.add(page)
                    didSave = true
                } label: {
                    Label(didSave ? "Сохранено" : "Сохранить в историю", systemImage: didSave ? "checkmark" : "tray.and.arrow.down")
                }
                .disabled(didSave)
            }

            Section("Текст") {
                ForEach($page.lines) { $line in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Строка \(line.index)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("Использовать", isOn: $line.isEnabled)
                                .font(.caption)
                        }

                        if let data = line.cropPNGData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 46)
                                .opacity(line.isEnabled ? 1 : 0.35)
                        }

                        TextEditor(text: $line.text)
                            .font(.body)
                            .frame(minHeight: 58)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Результат")
        .navigationBarTitleDisplayMode(.inline)
    }
}
