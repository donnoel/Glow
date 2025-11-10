import Testing
@testable import Glow
import Foundation

struct GlowAppConfigTests {

    @Test
    func support_email_is_not_empty() throws {
        #expect(!GlowAppConfig.supportEmail.isEmpty)
    }

    @Test
    func mailto_url_is_well_formed() throws {
        // this is basically what SidebarOverlay does internally
        let to = GlowAppConfig.supportEmail
        let subject = GlowAppConfig.supportSubject
        let body = GlowAppConfig.supportBodyHint

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)"

        #expect(URL(string: urlString) != nil)
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
