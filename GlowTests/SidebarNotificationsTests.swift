import Testing
@testable import Glow
import Foundation

@MainActor
struct SidebarNotificationsTests {

    @Test
    func archive_notification_name_is_correct() throws {
        #expect(Notification.Name.glowShowArchive.rawValue == "glowShowArchive")
    }

    @Test
    func reminders_notification_name_is_correct() throws {
        #expect(Notification.Name.glowShowReminders.rawValue == "glowShowReminders")
    }

    // If you have these in another extension, you can uncomment / add:
    // @Test
    // func showYou_notification_name_is_correct() throws {
    //     #expect(Notification.Name.glowShowYou.rawValue == "glowShowYou")
    // }

    // @Test
    // func showTrends_notification_name_is_correct() throws {
    //     #expect(Notification.Name.glowShowTrends.rawValue == "glowShowTrends")
    // }

    // @Test
    // func showAbout_notification_name_is_correct() throws {
    //     #expect(Notification.Name.glowShowAbout.rawValue == "glowShowAbout")
    // }
}
