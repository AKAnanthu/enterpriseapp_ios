import Foundation
import SwiftUI

/// Deterministic, locale-aware formatting. Views read it from the environment; tests construct
/// it with a fixed locale, time zone and clock.
struct AppFormatters: Sendable {
    var locale: Locale
    var timeZone: TimeZone
    var calendar: Calendar
    var now: @Sendable () -> Date

    init(locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent, now: @escaping @Sendable () -> Date = { Date() }) {
        self.locale = locale
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = timeZone
        self.calendar = calendar
        self.now = now
    }

    static let live = AppFormatters()

    // MARK: Metrics

    func string(for value: MetricValue) -> String {
        switch value {
        case .count(let count):
            count.formatted(.number.locale(locale))
        case .number(let number):
            number.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
        case .currency(let amount, let code):
            amount.formatted(.currency(code: code).locale(locale))
        case .percentage(let fraction):
            fraction.formatted(.percent.precision(.fractionLength(0...1)).locale(locale))
        }
    }

    /// Formats a percentage change such as `4.2` as "+4.2%".
    func change(_ percent: Double) -> String {
        (percent / 100).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always(includingZero: false)).locale(locale))
    }

    // MARK: Dates

    /// "5 min ago" within the last week, otherwise an absolute date.
    func timestamp(_ date: Date) -> String {
        let reference = now()
        let interval = reference.timeIntervalSince(date)
        if interval >= 0, interval < 7 * 24 * 60 * 60 {
            if interval < 60 {
                return String(localized: "Just now")
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.unitsStyle = .abbreviated
            formatter.dateTimeStyle = .numeric
            return formatter.localizedString(for: date, relativeTo: reference)
        }
        return absolute(date)
    }

    func absolute(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .shortened)
        style.locale = locale
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    func day(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        style.locale = locale
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    /// Date without time, including the year, e.g. "Sep 22, 2025".
    func date(_ date: Date) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: .omitted)
        style.locale = locale
        style.timeZone = timeZone
        style.calendar = calendar
        return date.formatted(style)
    }

    /// Time-of-day greeting for the dashboard header.
    func greeting() -> String {
        switch calendar.component(.hour, from: now()) {
        case 5..<12: String(localized: "Good morning")
        case 12..<18: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }
}

extension EnvironmentValues {
    @Entry var formatters: AppFormatters = .live
}
