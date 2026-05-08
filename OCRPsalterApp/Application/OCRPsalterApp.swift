import SwiftUI

@main
struct OCRPsalterApp: App {
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var ocrService = OCRService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(historyStore)
                .environmentObject(ocrService)
        }
    }
}
