import SwiftUI
import SafariServices
import AVFoundation

private let kTopBannerID    = "ca-app-pub-9404799280370656/9614494112"
private let kBottomBannerID = "ca-app-pub-9404799280370656/1118636003"

enum FontSizeOption: String, CaseIterable {
    case small  = "小"
    case medium = "中"
    case large  = "大"

    var titleSize: CGFloat {
        switch self {
        case .small:  return 12
        case .medium: return 16
        case .large:  return 20
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = NewsViewModel()
    @StateObject private var bookmarks = BookmarkManager()
    @StateObject private var tts = TTSManager()
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        TabView {
            NewsListView(vm: vm, bookmarks: bookmarks, tts: tts, fontSize: fontSize, fontSizeRaw: $fontSizeRaw)
                .tabItem { Label("ニュース", systemImage: "newspaper") }

            BookmarksView(bookmarks: bookmarks, tts: tts, fontSize: fontSize)
                .tabItem { Label("保存済み", systemImage: "bookmark.fill") }

            StatsView(bookmarks: bookmarks, vm: vm)
                .tabItem { Label("統計", systemImage: "chart.bar") }
        }
        .task { await vm.fetch() }
    }
}

struct NewsListView: View {
    @ObservedObject var vm: NewsViewModel
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    let fontSize: FontSizeOption
    @Binding var fontSizeRaw: String
    @State private var searchText = ""

    private var filteredSections: [(date: String, items: [NewsItem])] {
        guard !searchText.isEmpty else { return vm.sections }
        let q = searchText.lowercased()
        return vm.sections.compactMap { section in
            let filtered = section.items.filter {
                $0.title.lowercased().contains(q) || $0.source.lowercased().contains(q)
            }
            return filtered.isEmpty ? nil : (date: section.date, items: filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            BannerAdView(adUnitID: kTopBannerID).frame(height: 50)
            NavigationStack {
                Group {
                    if vm.isLoading && vm.sections.isEmpty {
                        ProgressView("読み込み中…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let err = vm.errorMessage {
                        VStack(spacing: 16) {
                            Text(err).foregroundStyle(.secondary)
                            Button("再読み込み") { Task { await vm.fetch() } }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(filteredSections, id: \.date) { section in
                                Section(header: Text(section.date)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                ) {
                                    ForEach(section.items) { item in
                                        NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks, tts: tts, searchText: searchText)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await vm.fetch() }
                    }
                }
                .navigationTitle("普通のニュース")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "記事を検索…")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Picker("文字サイズ", selection: $fontSizeRaw) {
                            ForEach(FontSizeOption.allCases, id: \.rawValue) { size in
                                Text(size.rawValue).tag(size.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 90)
                    }
                }
            }
            BannerAdView(adUnitID: kBottomBannerID).frame(height: 50)
        }
    }
}

struct BookmarksView: View {
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    let fontSize: FontSizeOption
    @State private var searchText = ""

    private var filteredBookmarks: [NewsItem] {
        guard !searchText.isEmpty else { return bookmarks.bookmarks }
        let q = searchText.lowercased()
        return bookmarks.bookmarks.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.bookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("保存した記事がここに表示されます")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("記事右下のブックマークアイコンをタップして保存")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredBookmarks) { item in
                            NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks, tts: tts, searchText: searchText)
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                bookmarks.toggle(filteredBookmarks[i])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("保存済み")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "保存記事を検索…")
        }
    }
}

struct StatsView: View {
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var vm: NewsViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("閲覧データ") {
                    HStack {
                        Label("読んだ記事", systemImage: "eye")
                        Spacer()
                        Text("\(bookmarks.readIDs.count)件")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("ブックマーク", systemImage: "bookmark.fill")
                        Spacer()
                        Text("\(bookmarks.bookmarks.count)件")
                            .foregroundStyle(.orange)
                    }
                    HStack {
                        Label("取得記事数", systemImage: "newspaper")
                        Spacer()
                        Text("\(vm.totalCount)件")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("よく読むメディア") {
                    let sources = topSources()
                    if sources.isEmpty {
                        Text("記事を読むと統計が表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sources, id: \.name) { source in
                            HStack {
                                Text(source.name)
                                Spacer()
                                Text("\(source.count)件")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section("使い方ヒント") {
                    Label("左にスワイプで記事を削除", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("スピーカーボタンで記事を読み上げ", systemImage: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("検索バーで記事をフィルタリング", systemImage: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("統計")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func topSources() -> [(name: String, count: Int)] {
        let readItems = vm.sections.flatMap(\.items).filter { bookmarks.isRead($0.id) }
        var counts: [String: Int] = [:]
        for item in readItems { counts[item.source, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { (name: $0.key, count: $0.value) }
    }
}

struct NewsRow: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    var searchText: String = ""
    @State private var showSafari = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                bookmarks.markRead(item.id)
                showSafari = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlightedTitle)
                        .font(.system(
                            size: fontSize.titleSize,
                            weight: bookmarks.isRead(item.id) ? .regular : .semibold
                        ))
                        .foregroundStyle(bookmarks.isRead(item.id) ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    Text(item.source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Spacer()
                Button {
                    tts.speak(item.title)
                } label: {
                    Image(systemName: tts.isSpeaking(item.title) ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(tts.isSpeaking(item.title) ? .blue : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if let url = item.articleURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    bookmarks.toggle(item)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(item) ? "bookmark.fill" : "bookmark")
                        .font(.caption)
                        .foregroundStyle(bookmarks.isBookmarked(item) ? .orange : .secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = item.articleURL {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }

    private var highlightedTitle: AttributedString {
        var attr = AttributedString(item.title)
        guard !searchText.isEmpty else { return attr }
        let lower = item.title.lowercased()
        let query = searchText.lowercased()
        var start = lower.startIndex
        while let range = lower.range(of: query, range: start..<lower.endIndex) {
            let attrStart = AttributedString.Index(range.lowerBound, within: attr)!
            let attrEnd = AttributedString.Index(range.upperBound, within: attr)!
            attr[attrStart..<attrEnd].backgroundColor = .yellow.opacity(0.3)
            start = range.upperBound
        }
        return attr
    }
}

// MARK: - TTS Manager

class TTSManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    @Published private var currentText: String?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            if currentText == text {
                currentText = nil
                return
            }
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        currentText = text
        synthesizer.speak(utterance)
    }

    func isSpeaking(_ text: String) -> Bool {
        synthesizer.isSpeaking && currentText == text
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.currentText = nil }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
