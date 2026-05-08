import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        List {
            if historyStore.pages.isEmpty {
                EmptyStateView(
                    title: "История пуста",
                    systemImage: "clock",
                    message: "Сохранённые распознавания появятся здесь."
                )
            } else {
                ForEach(historyStore.pages) { page in
                    NavigationLink {
                        ResultView(page: page)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(page.title)
                                .font(.headline)
                            Text(page.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(page.preview)
                                .font(AppFonts.ponomar(size: 17))
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: historyStore.delete)
            }
        }
        .navigationTitle("История")
        .navigationBarTitleDisplayMode(.inline)
    }
}
