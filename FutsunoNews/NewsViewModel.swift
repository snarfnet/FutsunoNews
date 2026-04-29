import Foundation

@MainActor
class NewsViewModel: ObservableObject {
    @Published var sections: [(date: String, items: [NewsItem])] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiURL = "https://backend-mu-one-z83zhj2wah.vercel.app/api/news?limit=100"

    func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: apiURL) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode([NewsItem].self, from: data)
            groupByDate(items)
        } catch {
            errorMessage = "読み込みに失敗しました"
        }
    }

    private func groupByDate(_ items: [NewsItem]) {
        var dict: [String: [NewsItem]] = [:]
        var order: [String] = []

        for item in items {
            let label = item.dateLabel
            if dict[label] == nil {
                dict[label] = []
                order.append(label)
            }
            dict[label]!.append(item)
        }

        sections = order.map { (date: $0, items: dict[$0]!) }
    }
}
