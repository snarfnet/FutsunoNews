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

    var category: NewsCategory { NewsCategory.classify(title) }
}

enum NewsCategory: String, CaseIterable, Codable {
    case politics = "政治"
    case economy = "経済"
    case international = "国際"
    case society = "社会"
    case sports = "スポーツ"
    case entertainment = "芸能"
    case tech = "テクノロジー"
    case lifestyle = "くらし"
    case other = "その他"

    var icon: String {
        switch self {
        case .politics:      return "building.columns"
        case .economy:       return "yensign.circle"
        case .international: return "globe.asia.australia"
        case .society:       return "person.3"
        case .sports:        return "sportscourt"
        case .entertainment: return "star"
        case .tech:          return "cpu"
        case .lifestyle:     return "house"
        case .other:         return "newspaper"
        }
    }

    static func classify(_ title: String) -> NewsCategory {
        let t = title.lowercased()
        let rules: [(NewsCategory, [String])] = [
            (.politics, ["首相", "政府", "国会", "自民", "立憲", "与党", "野党", "選挙", "閣議", "法案", "政権", "大臣", "知事"]),
            (.economy, ["株", "円安", "円高", "日銀", "GDP", "景気", "企業", "決算", "経済", "市場", "投資", "金利", "物価", "賃金"]),
            (.international, ["米国", "中国", "韓国", "ロシア", "ウクライナ", "EU", "NATO", "国連", "外交", "トランプ", "バイデン", "大統領"]),
            (.sports, ["野球", "サッカー", "大谷", "五輪", "W杯", "優勝", "試合", "選手", "リーグ", "甲子園", "相撲", "テニス", "ゴルフ"]),
            (.entertainment, ["映画", "ドラマ", "アニメ", "俳優", "女優", "芸人", "紅白", "視聴率", "ジャニーズ", "アイドル", "結婚", "離婚"]),
            (.tech, ["AI", "iPhone", "Google", "Apple", "アプリ", "ロボット", "宇宙", "半導体", "量子", "サイバー", "プログラム"]),
            (.lifestyle, ["健康", "レシピ", "子育て", "教育", "天気", "地震", "台風", "猛暑", "コロナ", "ワクチン", "病院"]),
            (.society, ["事件", "逮捕", "事故", "裁判", "警察", "容疑", "詐欺", "火災", "殺人", "被害"]),
        ]
        for (cat, keywords) in rules {
            if keywords.contains(where: { t.contains($0.lowercased()) }) {
                return cat
            }
        }
        return .other
    }
}
