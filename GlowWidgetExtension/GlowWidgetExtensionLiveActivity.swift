//
//  GlowWidgetExtensionLiveActivity.swift
//  GlowWidgetExtension
//
//  Created by Don Noel on 11/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct GlowWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct GlowWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlowWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension GlowWidgetExtensionAttributes {
    fileprivate static var preview: GlowWidgetExtensionAttributes {
        GlowWidgetExtensionAttributes(name: "World")
    }
}

extension GlowWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: GlowWidgetExtensionAttributes.ContentState {
        GlowWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: GlowWidgetExtensionAttributes.ContentState {
         GlowWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: GlowWidgetExtensionAttributes.preview) {
   GlowWidgetExtensionLiveActivity()
} contentStates: {
    GlowWidgetExtensionAttributes.ContentState.smiley
    GlowWidgetExtensionAttributes.ContentState.starEyes
}
