import Foundation

/// A generic, server-configured KPI. Used by Home and Analytics.
struct Metric: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let value: MetricValue
    /// Percentage change versus the previous period, e.g. `4.2` for +4.2%. `nil` when not provided.
    let changePercent: Double?

    var trend: MetricTrend {
        guard let changePercent else { return .flat }
        if changePercent > 0 { return .up }
        if changePercent < 0 { return .down }
        return .flat
    }
}

enum MetricValue: Hashable, Sendable {
    case count(Int)
    case number(Double)
    case currency(Decimal, currencyCode: String)
    /// A fraction, e.g. `0.42` for 42%.
    case percentage(Double)
}

enum MetricTrend: Sendable {
    case up, down, flat

    var systemImage: String {
        switch self {
        case .up: "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }
}

/// Server representation shared by the Home and Analytics features.
struct MetricDTO: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let value: Double
    /// `count`, `number`, `currency` or `percentage`. Unknown values fall back to `number`.
    let format: String?
    let currencyCode: String?
    let changePercent: Double?
}

enum MetricMapper {
    static func map(_ dto: MetricDTO) -> Metric {
        Metric(id: dto.id, title: dto.title, value: value(for: dto), changePercent: dto.changePercent)
    }

    private static func value(for dto: MetricDTO) -> MetricValue {
        switch dto.format?.lowercased() {
        case "count":
            .count(Int(dto.value.rounded()))
        case "currency":
            if let code = dto.currencyCode, code.count == 3 {
                // Decimal(string:) avoids binary floating point artefacts in currency amounts.
                .currency(Decimal(string: String(dto.value)) ?? Decimal(dto.value), currencyCode: code.uppercased())
            } else {
                .number(dto.value)
            }
        case "percentage", "percent":
            .percentage(dto.value)
        default:
            .number(dto.value)
        }
    }
}
