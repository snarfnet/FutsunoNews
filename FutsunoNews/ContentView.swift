import SwiftUI
import SafariServices

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
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        TabView {
            NewsListView(vm: vm, bookmarks: bookmarks, fontSize: fontSize, fontSizeRaw: $fontSizeRaw)
                .tabItem { Label("ニュース", systemImage: "newspaper") }

            BookmarksView(bookmarks: bookmarks, fontSize: fontSize)
                .tabItem { Label("保存済み", systemImage: "bookmark.fill") }
        }
        .task { await vm.fetch() }
    }
}

struct NewsListView: View {
    @ObservedObject var vm: NewsViewModel
    @ObservedObject var bookmarks: BookmarkManager
    let fontSize: FontSizeOption
    @Binding var fontSizeRaw: String

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
                            ForEach(vm.sections, id: \.date) { section in
                                Section(header: Text(section.date)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                ) {
                                    ForEach(section.items) { item in
                                        NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks)
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
    let fontSize: FontSizeOption

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
                        ForEach(bookmarks.bookmarks) { item in
                            NewsRow(item: item, fontSize: fontSize, bookmarks: bookmarks)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("保存済み")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct NewsRow: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarks: BookmarkManager
    @State private var showSafari = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                bookmarks.markRead(item.id)
                showSafari = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
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
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
