import Foundation

class BookmarkManager: ObservableObject {
    @Published private(set) var bookmarks: [NewsItem] = []
    @Published private(set) var readIDs: Set<String> = []

    private let bookmarksKey = "futsuno_bookmarks"
    private let readKey = "futsuno_read_ids"

    init() { load() }

    func isBookmarked(_ item: NewsItem) -> Bool {
        bookmarks.contains(where: { $0.id == item.id })
    }

    func toggle(_ item: NewsItem) {
        if isBookmarked(item) {
            bookmarks.removeAll { $0.id == item.id }
        } else {
            bookmarks.insert(item, at: 0)
        }
        save()
    }

    func markRead(_ id: String) {
        readIDs.insert(id)
        if let data = try? JSONEncoder().encode(Array(readIDs)) {
            UserDefaults.standard.set(data, forKey: readKey)
        }
    }

    func isRead(_ id: String) -> Bool { readIDs.contains(id) }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let items = try? JSONDecoder().decode([NewsItem].self, from: data) {
            bookmarks = items
        }
        if let data = UserDefaults.standard.data(forKey: readKey),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            readIDs = Set(ids)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }
}
