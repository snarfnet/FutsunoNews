import Foundation

class OfflineCache: ObservableObject {
    static let shared = OfflineCache()
    @Published private(set) var cachedArticles: [String: CachedArticle] = [:]

    private let cacheKey = "futsuno_offline_cache"

    struct CachedArticle: Codable {
        let id: String
        let title: String
        let source: String
        let text: String
        let summary: String?
        let cachedAt: Date
    }

    init() { load() }

    func cache(id: String, title: String, source: String, text: String, summary: String?) {
        cachedArticles[id] = CachedArticle(
            id: id, title: title, source: source,
            text: text, summary: summary, cachedAt: Date()
        )
        save()
    }

    func getCached(_ id: String) -> CachedArticle? {
        cachedArticles[id]
    }

    func isCached(_ id: String) -> Bool {
        cachedArticles[id] != nil
    }

    func removeCache(_ id: String) {
        cachedArticles.removeValue(forKey: id)
        save()
    }

    func clearAll() {
        cachedArticles.removeAll()
        save()
    }

    var cachedCount: Int { cachedArticles.count }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONDecoder().decode([String: CachedArticle].self, from: data) else { return }
        cachedArticles = dict
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cachedArticles) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
