import Foundation

struct TranscriptionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let polishedText: String

    init(id: UUID = UUID(), timestamp: Date = Date(), originalText: String, polishedText: String) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.polishedText = polishedText
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    var timeAgo: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            let components = calendar.dateComponents([.hour, .minute], from: timestamp, to: now)
            if let hours = components.hour, hours > 0 {
                return "\(hours)小时前"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes)分钟前"
            } else {
                return "刚刚"
            }
        } else if calendar.isDateInYesterday(timestamp) {
            return "昨天"
        } else {
            let components = calendar.dateComponents([.day], from: timestamp, to: now)
            if let days = components.day, days < 7 {
                return "\(days)天前"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd"
                return formatter.string(from: timestamp)
            }
        }
    }
}
