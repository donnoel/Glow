import UserNotifications

nonisolated enum WaterNudgeAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// System permission is requested only by an explicit tap in the app.
nonisolated enum WaterNudgeAuthorization {
    static func status() async -> WaterNudgeAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .authorized, .provisional: return .authorized
        default: return .denied
        }
    }

    static func request() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
