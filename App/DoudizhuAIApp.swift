import SwiftUI

@main
struct DoudizhuAIApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app)
                .onAppear { app.startCaptureServer() }
        }
    }
}
