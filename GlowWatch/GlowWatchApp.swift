import SwiftUI

@main
struct GlowWatchApp: App {
    @StateObject private var model = GlowWatchViewModel()

    var body: some Scene {
        WindowGroup {
            GlowWatchTodayView(model: model)
        }
        .backgroundTask(.watchConnectivity) {
            await model.handleBackgroundDelivery()
        }
    }
}
