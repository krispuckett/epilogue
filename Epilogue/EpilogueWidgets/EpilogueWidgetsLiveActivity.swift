//
//  EpilogueWidgetsLiveActivity.swift
//  EpilogueWidgets
//
//  Created by Kris Puckett on 10/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct EpilogueWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct EpilogueWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EpilogueWidgetsAttributes.self) { context in
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

extension EpilogueWidgetsAttributes {
    fileprivate static var preview: EpilogueWidgetsAttributes {
        EpilogueWidgetsAttributes(name: "World")
    }
}

extension EpilogueWidgetsAttributes.ContentState {
    fileprivate static var smiley: EpilogueWidgetsAttributes.ContentState {
        EpilogueWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: EpilogueWidgetsAttributes.ContentState {
         EpilogueWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: EpilogueWidgetsAttributes.preview) {
   EpilogueWidgetsLiveActivity()
} contentStates: {
    EpilogueWidgetsAttributes.ContentState.smiley
    EpilogueWidgetsAttributes.ContentState.starEyes
}
