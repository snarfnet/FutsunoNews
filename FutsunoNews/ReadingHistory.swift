import Foundation

class ReadingHistory: ObservableObject {
    static let shared = ReadingHistory()
    @Published private(set) var entries: [HistoryEntry] = []

    private let historyKey = "futsuno_reading_history"

    struct HistoryEntry: Codable, Identifiable {
        var id: String { "\(articleId)_\(readAt.timeIntervalSince1970)" }
        let articleId: String
        let title: String
        let source: String
        let category: String
        let readAt: Date
    }

    init() { load() }

    func addEntry(articleId: String, title: String, source: String, category: String) {
        let entry = HistoryEntry(
            articleId: articleId, title: title,
            source: source, category: category, readAt: Date()
        )
        entries.insert(entry, at: 0)
        // Keep last 200 entries
        if entries.count > 200 {
            entries = Array(entries.prefix(200))
        }
        save()
    }

    func todayEntries() -> [HistoryEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.readAt) }
    }

    func thisWeekEntries() -> [HistoryEntry] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return entries.filter { $0.readAt > weekAgo }
    }

    func clearHistory() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let list = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = list
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}
