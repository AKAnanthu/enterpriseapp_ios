import Foundation

enum DashboardMapper {
    static func summary(from dto: DashboardSummaryDTO) -> DashboardSummary {
        DashboardSummary(metrics: unique(dto.metrics.elements.map(MetricMapper.map)), generatedAt: dto.generatedAt)
    }

    /// Maps, de-duplicates by id (keeping the first occurrence) and sorts newest first.
    static func activity(from dto: ActivityListDTO) -> [ActivityItem] {
        unique(dto.items.elements.map(activityItem(from:)))
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    static func activityItem(from dto: ActivityItemDTO) -> ActivityItem {
        ActivityItem(
            id: dto.id,
            title: dto.title,
            detail: dto.description,
            category: dto.category,
            occurredAt: dto.occurredAt,
            status: dto.status.flatMap(status(from:)),
            amount: dto.amount.map { amount in
                if let code = dto.currencyCode, code.count == 3 {
                    .currency(Decimal(string: String(amount)) ?? Decimal(amount), currencyCode: code.uppercased())
                } else {
                    .number(amount)
                }
            }
        )
    }

    static func status(from raw: String) -> ActivityStatus? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        switch value.lowercased() {
        case "": return nil
        case "completed", "complete", "success", "succeeded", "done": return .completed
        case "pending", "processing", "in_progress", "in-progress": return .pending
        case "failed", "failure", "error", "rejected", "cancelled", "canceled": return .failed
        default: return .other(value)
        }
    }

    private static func unique<T: Identifiable>(_ items: [T]) -> [T] {
        var seen = Set<T.ID>()
        return items.filter { seen.insert($0.id).inserted }
    }
}
