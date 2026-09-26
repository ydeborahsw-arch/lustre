import WidgetKit
import SwiftUI


struct LustreEntry: TimelineEntry {
    let date: Date
    let sleepH: Double
    let steps: Int
}

struct LustreProvider: TimelineProvider {
    static let group = "group.__LX_BUNDLE__"
    func placeholder(in context: Context) -> LustreEntry { LustreEntry(date: Date(), sleepH: 7.2, steps: 6800) }
    func snapshot(in context: Context, completion: @escaping (LustreEntry) -> Void) { completion(load()) }
    func timeline(in context: Context, completion: @escaping (Timeline<LustreEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }
    func load() -> LustreEntry {
        let d = UserDefaults(suiteName: LustreProvider.group)
        return LustreEntry(date: Date(),
                           sleepH: d?.double(forKey: "w.sleepH") ?? 0,
                           steps: d?.integer(forKey: "w.steps") ?? 0)
    }
}

struct LustreWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: LustreEntry
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack { Image(systemName: "sparkle").font(.system(size: 26, weight: .medium)) }
                .widgetURL(URL(string: "lustre://open"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Lustre").font(.system(size: 12, weight: .semibold))
                Text(entry.sleepH > 0 ? String(format: "睡眠 %.1fh", entry.sleepH) : "睡眠 —")
                    .font(.system(size: 12))
                Text(entry.steps > 0 ? "步数 \(entry.steps)" : "步数 —")
                    .font(.system(size: 12))
            }.widgetURL(URL(string: "lustre://open"))
        default:
            Text(entry.sleepH > 0 ? String(format: "%.1fh · %d步", entry.sleepH, entry.steps) : "Lustre")
                .widgetURL(URL(string: "lustre://open"))
        }
    }
}

@main
struct LustreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LustreWidget", provider: LustreProvider()) { entry in
            LustreWidgetView(entry: entry)
        }
        .configurationDisplayName("Lustre")
        .description("睡眠与步数,点开进App")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
