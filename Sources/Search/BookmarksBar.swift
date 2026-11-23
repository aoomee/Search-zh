import SwiftUI

// The bookmarks bar: the top of the bookmarks, in a thin row above the page,
// as Chrome and Safari have one. A folder opens as a menu. More than the row
// holds scrolls sideways.
//
// Off unless asked for — Settings › Tabs, or Bookmarks › Show Bookmarks Bar
// — since the page gives up a strip of its height to it. It goes with the
// tabs when they fold away (⌘S) and when a video takes the screen.

struct BookmarksBar: View {
    @ObservedObject var browser: Browser
    let bookmarks: Bookmarks
    /// On the window's ground, above the page's card, with the tabs down the
    /// side: the ground's colour and no line of its own, the card's edge
    /// being the line (see CardEdge).
    var onFrame = false

    static let height: CGFloat = 30

    var body: some View {
        let _ = Bench.count("bar")
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(bookmarks.roots) { node in
                    Item(node: node) {
                        if node.isFolder {
                            BookmarkMenu.shared.popUp(node)
                        } else if let text = node.url, let url = URL(string: text) {
                            browser.openBookmark(url)
                        }
                    }
                    .overlay {
                        if let url = node.url.flatMap(URL.init(string:)) {
                            MiddleClick { browser.pickBookmark(url, inNewTab: true) }
                        }
                    }
                    .contextMenu {
                        if node.isFolder {
                            folderMenu(node)
                        } else if let url = node.url.flatMap(URL.init(string:)) {
                            bookmarkMenu(node, url)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: BookmarksBar.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("新建文件夹…") { bookmarks.askNewFolder(in: nil) }
            Divider()
            Button("显示书签…") { browser.bookmarking = true }
            Button("隐藏书签栏") {
                withAnimation(Motion.glide) { browser.prefs.bookmarksBar = false }
            }
        }
        .background {
            ZStack {
                // On glass the window's ground, colour and all, shows
                // through (Glass.swift).
                if !browser.glassy { onFrame ? Palette.frame : Palette.ground }
                // The tabs' wash carried on under them, or the colour
                // stopped at the bar's edge.
                if !browser.glassy { SpaceWash(look: browser.wash) }
            }
        }
        .overlay(alignment: .bottom) {
            if !onFrame { Rectangle().fill(Palette.hairline).frame(height: 1) }
        }
    }

    @ViewBuilder
    private func bookmarkMenu(_ node: Bookmark, _ url: URL) -> some View {
        Button("在新标签页中打开") { browser.pickBookmark(url, inNewTab: true) }
        Button("在新窗口中打开") { browser.openInNewWindow([url]) }
        if browser.prefs.splitView {
            Button("在分屏视图中打开") { browser.openInSplit(url) }
        }
        Button("在无痕标签页中打开") { browser.openShy(url) }
        Divider()
        Button("重命名…") { bookmarks.askRename(node) }
        Button("编辑地址…") { bookmarks.askAddress(node) }
        Button("拷贝链接") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.absoluteString, forType: .string)
        }
        Divider()
        moveMenu(node)
        Button("移除", role: .destructive) { bookmarks.askRemove(node) }
    }

    @ViewBuilder
    private func folderMenu(_ node: Bookmark) -> some View {
        let urls = (node.children ?? []).compactMap { $0.url.flatMap(URL.init(string:)) }
        Button("在新标签页中全部打开") {
            for url in urls { browser.open(url, foreground: false, atEnd: true, from: browser.active, mayWait: true) }
        }
        .disabled(urls.isEmpty)
        Button("在新窗口中全部打开") { browser.openInNewWindow(urls) }
            .disabled(urls.isEmpty)
        if browser.prefs.usesTabGroups {
            Button("在标签页组中全部打开") { browser.openInTabGroup(urls, named: node.title) }
                .disabled(urls.isEmpty)
        }
        Divider()
        Button("重命名…") { bookmarks.askRename(node) }
        Button("在内部新建文件夹…") { bookmarks.askNewFolder(in: node.id) }
        Divider()
        moveMenu(node)
        Button("移除", role: .destructive) { bookmarks.askRemove(node) }
    }

    @ViewBuilder
    private func moveMenu(_ node: Bookmark) -> some View {
        let targets = Bookmarks.folders(bookmarks.roots).filter { !Bookmarks.holds($0.node.id, node) }
        if !targets.isEmpty {
            Menu("移至") {
                ForEach(targets, id: \.node.id) { target in
                    Button(String(repeating: "   ", count: target.depth) + target.node.title) {
                        bookmarks.move(node.id, into: target.node.id)
                    }
                }
            }
        }
    }

    /// One on the bar. A bookmark without a name is its icon alone, in a
    /// square as tall as the others, its address on hover.
    struct Item: View {
        let node: Bookmark
        let act: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 6) {
                if node.isFolder {
                    Image(systemName: "folder")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.muted)
                } else {
                    Mark(icon: Favicons.shared.cached(for: node.address), letter: String((node.host ?? "•").prefix(1)).uppercased(), size: 13)
                }
                if !node.unnamed {
                    Text(node.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if node.isFolder {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                }
            }
            .padding(.horizontal, node.unnamed ? 0 : 8)
            .frame(minWidth: node.unnamed ? 22 : nil)
            .frame(height: 22)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovering ? Palette.hover : .clear))
            .contentShape(Rectangle())
            .onTapGesture(perform: act)
            .onHover { hovering = $0 }
            .help(node.url ?? node.title)
        }
    }
}
