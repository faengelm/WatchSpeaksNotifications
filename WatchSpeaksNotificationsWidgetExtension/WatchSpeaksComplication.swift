import WidgetKit
import SwiftUI

@main
struct WatchSpeaksComplication: Widget {
    let kind = "WatchSpeaksComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Watch Speaks")
        .description("Tap to open Watch Speaks")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60)))
        completion(timeline)
    }
}

struct ComplicationView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .widgetAccentable()
            }
        case .accessoryCorner:
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .widgetAccentable()
                .widgetLabel("Watch Speaks")
        case .accessoryInline:
            Label("Watch Speaks", systemImage: "speaker.wave.2.fill")
        case .accessoryRectangular:
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                VStack(alignment: .leading) {
                    Text("Watch Speaks")
                        .font(.headline)
                        .widgetAccentable()
                    Text("Announcements")
                        .font(.caption)
                }
            }
        @unknown default:
            Image(systemName: "speaker.wave.2.fill")
        }
    }
}
