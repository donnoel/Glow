import Testing
@testable import Glow
import Foundation

extension GlowAppConfig {
    /// Test-only helper to construct the support mail URL.
    /// This mirrors the behavior used by the app when composing a support email.
    static var supportMailURL: URL? {
        let to = supportEmail
        let subject = supportSubject
        let body = supportBodyHint

        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)"
        return URL(string: urlString)
    }
}

@MainActor
struct GlowAppConfigTests {

    @Test
    func support_email_is_not_empty() throws {
        #expect(!GlowAppConfig.supportEmail.isEmpty)
    }

    @Test
    func support_mail_url_is_non_nil() throws {
        #expect(GlowAppConfig.supportMailURL != nil)
    }

    @Test
    func support_mail_url_has_mailto_scheme_and_recipient() throws {
        let url = GlowAppConfig.supportMailURL
        #expect(url != nil)

        if let url {
            #expect(url.scheme == "mailto")
            // resourceSpecifier for a mailto URL begins with the address
            #expect(url.absoluteString.hasPrefix("mailto:\(GlowAppConfig.supportEmail)"))
        }
    }

    @Test
    func subject_is_percent_encodable() throws {
        let subject = GlowAppConfig.supportSubject
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)
    }

    @Test
    func body_is_percent_encodable() throws {
        let body = GlowAppConfig.supportBodyHint
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        #expect(encoded != nil)
    }
}
