import Foundation

enum GlowAppConfig {
    // Where “Send Feedback” in the sidebar should point
    static let supportEmail = "donnoel@icloud.com"

    // Optional: subject/body defaults
    static let supportSubject = "Glow Feedback"
    static let supportBodyHint = "Tell us what felt great, and what felt heavy ✨"

    /// Builds a percent-encoded mailto: URL string we can safely open in SwiftUI.
    static func feedbackMailURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail

        let subject = supportSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = supportBodyHint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        return components.url
    }
}
