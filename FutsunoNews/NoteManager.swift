import Foundation

class NoteManager: ObservableObject {
    static let shared = NoteManager()
    @Published private(set) var notes: [String: ArticleNote] = [:]

    private let notesKey = "futsuno_notes"

    struct ArticleNote: Codable {
        let articleId: String
        var text: String
        let createdAt: Date
        var updatedAt: Date
    }

    init() { load() }

    func getNote(_ articleId: String) -> String {
        notes[articleId]?.text ?? ""
    }

    func hasNote(_ articleId: String) -> Bool {
        guard let note = notes[articleId] else { return false }
        return !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveNote(_ articleId: String, text: String) {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes.removeValue(forKey: articleId)
        } else if var existing = notes[articleId] {
            existing.text = text
            existing.updatedAt = Date()
            notes[articleId] = existing
        } else {
            notes[articleId] = ArticleNote(
                articleId: articleId, text: text,
                createdAt: Date(), updatedAt: Date()
            )
        }
        save()
    }

    var noteCount: Int {
        notes.values.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: notesKey),
              let dict = try? JSONDecoder().decode([String: ArticleNote].self, from: data) else { return }
        notes = dict
    }

    private func save() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: notesKey)
        }
    }
}
