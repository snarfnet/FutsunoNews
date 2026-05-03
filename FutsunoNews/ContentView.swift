import SwiftUI
import WebKit
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
    @StateObject private var offlineCache = OfflineCache.shared
    @StateObject private var noteManager = NoteManager.shared
    @StateObject private var readingHistory = ReadingHistory.shared
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        TabView {
            NewsListView(vm: vm, bookmarks: bookmarks, tts: tts, fontSize: fontSize, fontSizeRaw: $fontSizeRaw, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
                .tabItem { Label("ニュース", systemImage: "newspaper") }

            BookmarksView(bookmarks: bookmarks, tts: tts, fontSize: fontSize, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
                .tabItem { Label("保存済み", systemImage: "bookmark.fill") }

            DigestView(readingHistory: readingHistory, vm: vm, bookmarks: bookmarks)
                .tabItem { Label("まとめ", systemImage: "doc.text.image") }

            StatsView(bookmarks: bookmarks, vm: vm, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
                .tabItem { Label("統計", systemImage: "chart.bar") }
        }
        .task { await vm.fetch() }
    }
}

// MARK: - News List

struct NewsListView: View {
    @ObservedObject var vm: NewsViewModel
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    let fontSize: FontSizeOption
    @Binding var fontSizeRaw: String
    @ObservedObject var offlineCache: OfflineCache
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var readingHistory: ReadingHistory
    @State private var searchText = ""
    @State private var selectedCategory: NewsCategory? = nil

    private var filteredSections: [(date: String, items: [NewsItem])] {
        var base = vm.sections
        if let cat = selectedCategory {
            base = base.compactMap { section in
                let filtered = section.items.filter { $0.category == cat }
                return filtered.isEmpty ? nil : (date: section.date, items: filtered)
            }
        }
        guard !searchText.isEmpty else { return base }
        let q = searchText.lowercased()
        return base.compactMap { section in
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
                        VStack(spacing: 0) {
                            CategoryFilterBar(selected: $selectedCategory)
                            List {
                                ForEach(filteredSections, id: \.date) { section in
                                    Section(header: Text(section.date)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    ) {
                                        ForEach(section.items) { item in
                                            NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks, tts: tts, searchText: searchText, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .refreshable { await vm.fetch() }
                        }
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

// MARK: - Category Filter Bar

struct CategoryFilterBar: View {
    @Binding var selected: NewsCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "すべて", icon: "list.bullet", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(NewsCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.rawValue, icon: cat.icon, isSelected: selected == cat) {
                        selected = (selected == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bookmarks

struct BookmarksView: View {
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    let fontSize: FontSizeOption
    @ObservedObject var offlineCache: OfflineCache
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var readingHistory: ReadingHistory
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
                            NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks, tts: tts, searchText: searchText, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
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

// MARK: - Stats

struct StatsView: View {
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var vm: NewsViewModel
    @ObservedObject var offlineCache: OfflineCache
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var readingHistory: ReadingHistory

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
                    HStack {
                        Label("オフライン保存", systemImage: "arrow.down.circle.fill")
                        Spacer()
                        Text("\(offlineCache.cachedCount)件")
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Label("メモ", systemImage: "note.text")
                        Spacer()
                        Text("\(noteManager.noteCount)件")
                            .foregroundStyle(.purple)
                    }
                }

                Section("閲覧履歴") {
                    HStack {
                        Label("今日読んだ記事", systemImage: "clock")
                        Spacer()
                        Text("\(readingHistory.todayEntries().count)件")
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Label("今週読んだ記事", systemImage: "calendar")
                        Spacer()
                        Text("\(readingHistory.thisWeekEntries().count)件")
                            .foregroundStyle(.blue)
                    }
                    if !readingHistory.entries.isEmpty {
                        Button(role: .destructive) {
                            readingHistory.clearHistory()
                        } label: {
                            Label("履歴をクリア", systemImage: "trash")
                        }
                    }
                }

                Section("カテゴリ別の閲覧傾向") {
                    let trends = categoryTrends()
                    if trends.isEmpty {
                        Text("記事を読むとカテゴリ別の傾向が表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(trends, id: \.category) { trend in
                            HStack(spacing: 8) {
                                Image(systemName: trend.category.icon)
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20)
                                Text(trend.category.rawValue)
                                    .font(.subheadline)
                                Spacer()
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.accentColor.opacity(0.6))
                                        .frame(width: geo.size.width * trend.ratio, height: 14)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                                .frame(width: 80, height: 14)
                                Text("\(trend.count)件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
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
                    Label("カテゴリバーで記事を絞り込み", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("スピーカーボタンで記事を読み上げ", systemImage: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("記事詳細で要約を自動生成", systemImage: "text.redaction")
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

    private func categoryTrends() -> [(category: NewsCategory, count: Int, ratio: CGFloat)] {
        let readItems = vm.sections.flatMap(\.items).filter { bookmarks.isRead($0.id) }
        var counts: [NewsCategory: Int] = [:]
        for item in readItems { counts[item.category, default: 0] += 1 }
        let sorted = counts.sorted { $0.value > $1.value }
        let maxCount = sorted.first?.value ?? 1
        return sorted.map { (category: $0.key, count: $0.value, ratio: CGFloat($0.value) / CGFloat(maxCount)) }
    }
}

// MARK: - News Row

struct NewsRow: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var tts: TTSManager
    var searchText: String = ""
    @ObservedObject var offlineCache: OfflineCache
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var readingHistory: ReadingHistory
    @State private var showReader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                bookmarks.markRead(item.id)
                readingHistory.addEntry(
                    articleId: item.id, title: item.title,
                    source: item.source, category: item.category.rawValue
                )
                showReader = true
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
                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Label(item.category.rawValue, systemImage: item.category.icon)
                            .font(.caption2)
                            .foregroundStyle(Color.accentColor.opacity(0.8))
                        if offlineCache.isCached(item.id) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        if noteManager.hasNote(item.id) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                    }
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
        .sheet(isPresented: $showReader) {
            if let url = item.articleURL {
                ArticleReaderView(url: url, title: item.title, articleId: item.id, source: item.source, category: item.category.rawValue, fontSize: fontSize, tts: tts, offlineCache: offlineCache, noteManager: noteManager, readingHistory: readingHistory)
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AVAudioSession setup failed: \(error)")
        }
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

// MARK: - Article Reader with Summary

struct ArticleReaderView: View {
    let url: URL
    let title: String
    var articleId: String = ""
    var source: String = ""
    var category: String = ""
    let fontSize: FontSizeOption
    @ObservedObject var tts: TTSManager
    @ObservedObject var offlineCache: OfflineCache
    @ObservedObject var noteManager: NoteManager
    @ObservedObject var readingHistory: ReadingHistory
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loader = ArticleLoader()
    @State private var showWebFallback = false
    @State private var showSummary = false
    @State private var showNoteEditor = false
    @State private var noteText = ""

    var body: some View {
        NavigationStack {
            Group {
                if loader.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("記事を読み込み中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let article = loader.articleText, !article.isEmpty, !showWebFallback {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(title)
                                .font(.system(size: fontSize.titleSize + 6, weight: .bold))
                                .padding(.bottom, 4)

                            HStack(spacing: 12) {
                                if let source = url.host {
                                    Text(source)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Label(readingTime(article), systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if showSummary, let summary = loader.summary {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("要約", systemImage: "text.redaction")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.accentColor)
                                    Text(summary)
                                        .font(.system(size: fontSize.titleSize))
                                        .lineSpacing(4)
                                        .foregroundStyle(.primary.opacity(0.9))
                                }
                                .padding()
                                .background(Color.accentColor.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Note display
                            if noteManager.hasNote(articleId) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("メモ", systemImage: "note.text")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.purple)
                                    Text(noteManager.getNote(articleId))
                                        .font(.system(size: fontSize.titleSize))
                                        .lineSpacing(4)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture {
                                    noteText = noteManager.getNote(articleId)
                                    showNoteEditor = true
                                }
                            }

                            Divider()

                            Text(article)
                                .font(.system(size: fontSize.titleSize + 2))
                                .lineSpacing(6)
                        }
                        .padding()
                    }
                } else {
                    ArticleWebView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("記事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if loader.summary != nil {
                        Button {
                            showSummary.toggle()
                        } label: {
                            Image(systemName: showSummary ? "text.redaction" : "text.alignleft")
                                .foregroundStyle(showSummary ? Color.accentColor : Color.primary)
                        }
                    }

                    // Note button
                    Button {
                        noteText = noteManager.getNote(articleId)
                        showNoteEditor = true
                    } label: {
                        Image(systemName: noteManager.hasNote(articleId) ? "note.text" : "note.text.badge.plus")
                            .foregroundStyle(noteManager.hasNote(articleId) ? .purple : .primary)
                    }

                    // Offline cache button
                    Button {
                        if offlineCache.isCached(articleId) {
                            offlineCache.removeCache(articleId)
                        } else if let text = loader.articleText {
                            offlineCache.cache(id: articleId, title: title, source: source, text: text, summary: loader.summary)
                        }
                    } label: {
                        Image(systemName: offlineCache.isCached(articleId) ? "arrow.down.circle.fill" : "arrow.down.circle")
                            .foregroundStyle(offlineCache.isCached(articleId) ? .green : .primary)
                    }

                    Button {
                        if let text = loader.articleText, !text.isEmpty {
                            tts.speak(showSummary && loader.summary != nil ? loader.summary! : text)
                        } else {
                            tts.speak(title)
                        }
                    } label: {
                        Image(systemName: tts.isSpeaking(loader.articleText ?? title) ? "speaker.wave.3.fill" : "speaker.wave.2")
                    }

                    if loader.articleText != nil && !showWebFallback {
                        Button {
                            showWebFallback = true
                        } label: {
                            Image(systemName: "globe")
                        }
                    } else if showWebFallback {
                        Button {
                            showWebFallback = false
                        } label: {
                            Image(systemName: "doc.text")
                        }
                    }

                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showNoteEditor) {
                NoteEditorView(articleId: articleId, noteText: $noteText, noteManager: noteManager)
            }
        }
        .task {
            await loader.load(url: url)
            // Auto-cache article text when loaded
            if let text = loader.articleText, !text.isEmpty, !articleId.isEmpty {
                offlineCache.cache(id: articleId, title: title, source: source, text: text, summary: loader.summary)
            }
        }
    }

    private func readingTime(_ text: String) -> String {
        let charCount = text.count
        let minutes = max(1, charCount / 500)
        return "約\(minutes)分"
    }
}

// MARK: - Note Editor

struct NoteEditorView: View {
    let articleId: String
    @Binding var noteText: String
    @ObservedObject var noteManager: NoteManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $noteText)
                    .padding()
                    .overlay(
                        Group {
                            if noteText.isEmpty {
                                Text("この記事についてメモを書く…")
                                    .foregroundStyle(.tertiary)
                                    .padding(20)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
            .navigationTitle("メモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        noteManager.saveNote(articleId, text: noteText)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Daily Digest

struct DigestView: View {
    @ObservedObject var readingHistory: ReadingHistory
    @ObservedObject var vm: NewsViewModel
    @ObservedObject var bookmarks: BookmarkManager

    var body: some View {
        NavigationStack {
            List {
                Section("今日の閲覧") {
                    let today = readingHistory.todayEntries()
                    if today.isEmpty {
                        Text("今日はまだ記事を読んでいません")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(today) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    Text(entry.source)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text("·")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    Text(entry.category)
                                        .font(.caption2)
                                        .foregroundStyle(Color.accentColor)
                                    Spacer()
                                    Text(entry.readAt, style: .time)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("今日のカテゴリ傾向") {
                    let today = readingHistory.todayEntries()
                    let catCounts = Dictionary(grouping: today, by: \.category)
                        .mapValues(\.count)
                        .sorted { $0.value > $1.value }
                    if catCounts.isEmpty {
                        Text("記事を読むと傾向が表示されます")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(catCounts, id: \.key) { cat, count in
                            HStack {
                                Text(cat)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(count)件")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("未読のおすすめ") {
                    let unread = vm.sections.flatMap(\.items)
                        .filter { !bookmarks.isRead($0.id) }
                        .prefix(5)
                    if unread.isEmpty {
                        Text("すべて既読です！")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(unread)) { item in
                            UnreadRecommendationRow(item: item, bookmarks: bookmarks, readingHistory: readingHistory)
                        }
                    }
                }
            }
            .navigationTitle("今日のまとめ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Unread Recommendation Row

struct UnreadRecommendationRow: View {
    let item: NewsItem
    @ObservedObject var bookmarks: BookmarkManager
    @ObservedObject var readingHistory: ReadingHistory
    @State private var showReader = false

    var body: some View {
        Button {
            bookmarks.markRead(item.id)
            readingHistory.addEntry(
                articleId: item.id, title: item.title,
                source: item.source, category: item.category.rawValue
            )
            showReader = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(item.source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label(item.category.rawValue, systemImage: item.category.icon)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showReader) {
            if let url = item.articleURL {
                ArticleReaderView(url: url, title: item.title, articleId: item.id, source: item.source, category: item.category.rawValue, fontSize: .medium, tts: TTSManager(), offlineCache: OfflineCache.shared, noteManager: NoteManager.shared, readingHistory: readingHistory)
            }
        }
    }
}

// MARK: - Article Loader with Summary

@MainActor
class ArticleLoader: ObservableObject {
    @Published var isLoading = true
    @Published var articleText: String?
    @Published var summary: String?

    func load(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) else {
                return
            }
            let text = extractText(from: html)
            articleText = text
            if let text = text, text.count > 100 {
                summary = generateSummary(from: text)
            }
        } catch {
            articleText = nil
        }
    }

    private func generateSummary(from text: String) -> String? {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: "。！？\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 10 }

        guard sentences.count >= 2 else { return nil }

        // Score sentences by position and length
        var scored: [(sentence: String, score: Double)] = []
        for (i, s) in sentences.enumerated() {
            var score = 0.0
            // First sentences are more important
            if i == 0 { score += 3.0 }
            else if i == 1 { score += 2.0 }
            else if i < 4 { score += 1.0 }
            // Prefer medium-length sentences
            if s.count > 20 && s.count < 150 { score += 1.0 }
            // Sentences with numbers often contain key facts
            if s.range(of: "\\d", options: .regularExpression) != nil { score += 0.5 }
            scored.append((sentence: s, score: score))
        }

        let top = scored.sorted { $0.score > $1.score }
            .prefix(3)
            .sorted { sentences.firstIndex(of: $0.sentence)! < sentences.firstIndex(of: $1.sentence)! }

        let result = top.map { $0.sentence + "。" }.joined(separator: "")
        return result.isEmpty ? nil : result
    }

    private func extractText(from html: String) -> String? {
        let stripped = html
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<nav[^>]*>[\\s\\S]*?</nav>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<header[^>]*>[\\s\\S]*?</header>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<footer[^>]*>[\\s\\S]*?</footer>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<aside[^>]*>[\\s\\S]*?</aside>", with: "", options: .regularExpression)

        var best: String?

        for tag in ["article", "main"] {
            if let range = stripped.range(of: "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>", options: .regularExpression) {
                let content = String(stripped[range])
                let text = htmlToPlainText(content)
                if text.count > 100 {
                    best = text
                    break
                }
            }
        }

        if best == nil {
            let paragraphs = extractParagraphs(from: stripped)
            let joined = paragraphs.joined(separator: "\n\n")
            if joined.count > 80 {
                best = joined
            }
        }

        return best
    }

    private func extractParagraphs(from html: String) -> [String] {
        var results: [String] = []
        let pattern = "<p[^>]*>(.*?)</p>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return results
        }
        let nsString = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            if match.numberOfRanges > 1 {
                let content = nsString.substring(with: match.range(at: 1))
                let text = htmlToPlainText(content).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 20 {
                    results.append(text)
                }
            }
        }
        return results
    }

    private func htmlToPlainText(_ html: String) -> String {
        html
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\\s*\\n\\s*\\n\\s*", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArticleWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
