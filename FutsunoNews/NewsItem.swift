import Foundation

struct NewsItem: Identifiable, Codable {
    let id: String
    let title: String
    let url: String
    let source: String
    let published_at: String

    var articleURL: URL? { URL(string: url) }

    var publishedDate: Date {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return fmt.date(from: published_at) ?? Date.distantPast
    }

    var dateLabel: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日（E）"
        return fmt.string(from: publishedDate)
    }
}
