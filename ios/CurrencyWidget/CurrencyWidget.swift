//
//  CurrencyWidget.swift
//  CurrencyWidget
//

import WidgetKit
import SwiftUI

private let appGroup = "group.com.karatexchange.app"

struct CurrencyEntry: TimelineEntry {
    let date: Date
    let pair1Label: String
    let pair1Value: String
    let pair2Label: String
    let pair2Value: String
    let pair3Label: String
    let pair3Value: String
    let goldLabel: String
    let goldValue: String
    let widgetDate: String
}

struct CurrencyProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyEntry {
        CurrencyEntry(date: Date(),
                      pair1Label: "EUR/USD", pair1Value: "1.0845",
                      pair2Label: "EUR/TRY", pair2Value: "36.50",
                      pair3Label: "EUR/GBP", pair3Value: "0.8512",
                      goldLabel: "🥇 Gold/g (EUR)", goldValue: "€95.20",
                      widgetDate: "")
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrencyEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> CurrencyEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        return CurrencyEntry(
            date: Date(),
            pair1Label: defaults?.string(forKey: "pair1_label") ?? "EUR/USD",
            pair1Value: defaults?.string(forKey: "pair1_value") ?? "-",
            pair2Label: defaults?.string(forKey: "pair2_label") ?? "EUR/TRY",
            pair2Value: defaults?.string(forKey: "pair2_value") ?? "-",
            pair3Label: defaults?.string(forKey: "pair3_label") ?? "EUR/GBP",
            pair3Value: defaults?.string(forKey: "pair3_value") ?? "-",
            goldLabel: defaults?.string(forKey: "gold_label") ?? "🥇 Gold/g",
            goldValue: defaults?.string(forKey: "gold_value") ?? "-",
            widgetDate: defaults?.string(forKey: "widget_date") ?? ""
        )
    }
}

struct CurrencyWidgetEntryView: View {
    var entry: CurrencyEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("KaratExchange")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    if !entry.widgetDate.isEmpty {
                        Text(entry.widgetDate)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                Divider().background(Color.white.opacity(0.2))

                pairRow(label: entry.pair1Label, value: entry.pair1Value)
                pairRow(label: entry.pair2Label, value: entry.pair2Value)

                if family != .systemSmall {
                    pairRow(label: entry.pair3Label, value: entry.pair3Value)
                    pairRow(label: entry.goldLabel, value: entry.goldValue)
                } else {
                    pairRow(label: entry.goldLabel, value: entry.goldValue)
                }
            }
            .padding(10)
        }
    }

    func pairRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
        }
    }
}

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrencyProvider()) { entry in
            CurrencyWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.1, green: 0.1, blue: 0.18), for: .widget)
        }
        .configurationDisplayName("KaratExchange")
        .description("Aktuelle Wechselkurse auf dem Home-Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    CurrencyWidget()
} timeline: {
    CurrencyEntry(date: .now,
                  pair1Label: "EUR/USD", pair1Value: "1.0845",
                  pair2Label: "EUR/TRY", pair2Value: "36.50",
                  pair3Label: "EUR/GBP", pair3Value: "0.8512",
                  goldLabel: "🥇 Gold/g (EUR)", goldValue: "€95.20",
                  widgetDate: "19.04.2026")
}


import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct CurrencyWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack {
            Text("Time:")
            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CurrencyWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    CurrencyWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}
