import SwiftUI
import WebKit

/// Settings › Extensions: what is installed, and the two ways in — a Chrome
/// Web Store link, or a folder.
struct ExtensionsPage: View {
    @ObservedObject var browser: Browser

    var body: some View {
        if #available(macOS 15.4, *) {
            Installer(browser: browser, extensions: .shared)
        } else {
            Card {
                Line("Chrome extensions", "需要 macOS 15.4 或更高版本，此版本的 WebKit 才支持运行扩展。") { EmptyView() }
            }
        }
    }

    @available(macOS 15.4, *)
    private struct Installer: View {
        @ObservedObject var browser: Browser
        @ObservedObject var extensions: Extensions
        @State private var link = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text("Add from the Chrome Web Store")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            Pill("Open the Store") {
                                browser.open(Browser.webStore, foreground: true)
                            }
                        }
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                if link.isEmpty {
                                    Text("Paste a link to an extension, or its id")
                                        .foregroundStyle(Palette.muted.opacity(0.8))
                                }
                                TextField("", text: $link)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(Palette.ink)
                                    .onSubmit(add)
                            }
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Palette.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                            if !extensions.busy.isEmpty {
                                Ring(size: 12)
                            } else {
                                Pill("Add", filled: true, action: add)
                                    .disabled(Crx.id(in: link) == nil)
                            }
                        }
                        Text("Or find it in the store and press Add to Search on its page.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                }

                Card {
                    Line("From another browser", "从 Chrome、Arc、Brave 等浏览器中识别到来自 Chrome 应用商店的扩展，将从商店全新安装并逐一由你确认") {
                        Pill("Bring them over…") {
                            browser.bringingExtensions = true
                            browser.lead(to: InternalPage(.importing))
                        }
                    }
                }

                if extensions.installed.isEmpty {
                    Card { Nothing("No extensions yet.") }
                } else {
                    Card {
                        ForEach(Array(extensions.installed.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Rule() }
                            Row(item: item, extensions: extensions)
                        }
                    }
                    Text("Each extension stays out of private tabs until you allow it in its … menu. One you allow can tell which tabs are private, but may still keep what you visit in them.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Recorders()

                Card {
                    Line("Load an unpacked extension", "包含 manifest.json 的文件夹，可以是你自制的或从其他浏览器导出的。重新加载即可应用后续更改。") {
                        Pill("Choose…") { extensions.installFolder() }
                    }
                }
            }
        }

        private func add() {
            guard Crx.id(in: link) != nil else { return }
            extensions.install(from: link)
            link = ""
        }
    }

    /// The extensions you let record your screen, each one to take back.
    @available(macOS 15.4, *)
    private struct Recorders: View {
        @ObservedObject private var capture = ExtensionCapture.shared

        var body: some View {
            let ids = ExtensionCapture.allowedIDs
            if !ids.isEmpty {
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                            if index > 0 { Rule() }
                            Line(Browser.extensionName(id), "可录制你的屏幕 — macOS 每次都会询问要共享的内容") {
                                Pill("Remove") { ExtensionCapture.forget(id) }
                            }
                        }
                    }
                }
            }
        }
    }

    @available(macOS 15.4, *)
    private struct Row: View {
        let item: Installed
        @ObservedObject var extensions: Extensions
        @State private var hovering = false

        var body: some View {
            let context = extensions.contexts[item.id]
            let sites = context.map(Extensions.asksForSites) == true
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Group {
                        if let icon = context?.webExtension.icon(for: CGSize(width: 32, height: 32)) {
                            Image(nsImage: icon).resizable().interpolation(.high)
                        } else {
                            Image(systemName: "puzzlepiece.extension").foregroundStyle(Palette.muted)
                        }
                    }
                    .frame(width: 22, height: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(detail(context))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                            .help(item.source ?? "")
                        // Switched on and not running: said as such, with
                        // WebKit's reason, not a row like any other (#1208).
                        if item.enabled, context == nil, let reason = extensions.notStarted[item.id] {
                            Text("Couldn’t start: \(reason)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.unsafe)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        // Running, but without what it is for (#1208).
                        if let limit = context.flatMap({ Extensions.cantDo($0.webExtension.manifest) }) {
                            Text(limit)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Palette.unsafe)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                    Spacer(minLength: 8)
                    if sites {
                        RunsOn(item: item, extensions: extensions)
                    }
                    // Five pills don't fit beside the name in a settings page's
                    // width, and wrapped a letter at a time when they tried. One
                    // menu holds them all, there without hovering to find it.
                    Menu { actions(context) } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(hovering ? Palette.ink : Palette.muted)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .accessibilityLabel("\(item.name) 的更多选项")
                    .help("\(item.name) 的更多选项")
                    Switch(on: Binding(get: { item.enabled }, set: { extensions.setEnabled(item.id, $0) }))
                }
                if sites, extensions.siteAccess(item.id).restricted {
                    SiteList(item: item, extensions: extensions)
                        .padding(.leading, 34)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(hovering ? Palette.hover : .clear)
            .onHover { hovering = $0 }
            .contextMenu { actions(context) }
        }

        @ViewBuilder
        private func actions(_ context: WKWebExtensionContext?) -> some View {
            Button(item.pinned == true ? "取消固定" : "固定到工具栏") {
                extensions.setPinned(item.id, !(item.pinned ?? false))
            }
            if context?.overrideNewTabPageURL != nil {
                let on = extensions.newTabPageID == item.id
                Button(on ? "停止在新标签页中显示" : "在新标签页中显示") {
                    extensions.setNewTabPage(on ? nil : item.id)
                }
            }
            if context?.optionsPageURL != nil {
                Button("选项") { extensions.openOptions(item.id) }
            }
            if item.source != nil || !item.fromStore {
                Button("重新载入") { extensions.reload(item.id) }
            }
            if let context {
                Divider()
                if (context.webExtension.manifest["incognito"] as? String) == "not_allowed" {
                    Text("Private Tabs Aren’t Supported")
                } else {
                    Toggle("允许在无痕标签页中运行", isOn: Binding(
                        get: { context.hasAccessToPrivateData },
                        set: { extensions.setPrivate(item.id, $0) }
                    ))
                    .accessibilityLabel("允许 \(item.name) 在无痕标签页中运行")
                    .help("在允许扩展前打开的无痕标签页需要重新打开。关闭后，已在页面中运行的脚本需在重新载入页面后才会停止。")
                }
            }
            Divider()
            Button("移除", role: .destructive) { extensions.remove(item.id) }
        }

        /// Where it was loaded from, by the folder's name — the whole path
        /// is in the tooltip.
        private var folder: String {
            item.source.map { "From “\(URL(fileURLWithPath: $0).lastPathComponent)”" } ?? "来自文件夹"
        }

        private func detail(_ context: WKWebExtensionContext?) -> String {
            var parts = ["Version \(item.version)", item.fromStore ? "Chrome 应用商店" : folder]
            if item.enabled, context == nil, extensions.notStarted[item.id] == nil { parts.append("couldn't start") }
            if extensions.newTabPageID == item.id {
                parts.append("shows in new tabs")
            }
            if context?.hasAccessToPrivateData == true { parts.append("allowed in private tabs") }
            if let errors = context.map(Extensions.errors(of:)), !errors.isEmpty { parts.append("\(errors.count) warning\(errors.count == 1 ? "" : "s")") }
            return parts.joined(separator: " · ")
        }
    }
}

/// An extension's "Runs on": every site it asked for (the default), the
/// ones you name, or only where you click its button.
@available(macOS 15.4, *)
private struct RunsOn: View {
    let item: Installed
    @ObservedObject var extensions: Extensions

    var body: some View {
        let access = extensions.siteAccess(item.id)
        Menu {
            Picker("运行范围", selection: Binding(
                get: { access.mode },
                set: { extensions.setSiteAccess(item.id, SiteAccess(mode: $0, hosts: access.hosts)) }
            )) {
                Text("All Sites It Asks For").tag(SiteAccess.Mode.all)
                Text("Only Sites I Name").tag(SiteAccess.Mode.some)
                Text("Only When I Click It").tag(SiteAccess.Mode.click)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 3) {
                Text(access.mode.title)
                    .font(.system(size: 11.5))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(access.restricted ? Palette.ink : Palette.muted)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Palette.wash, in: Capsule())
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("\(item.name) 的运行范围")
        .accessibilityValue(access.mode.title)
        .help("\(item.name) 的运行范围。启用的网站越少，其余页面占用的内存越少")
    }
}

/// Under an extension held to fewer sites: the sites you named, one to add,
/// and a word on what that means.
@available(macOS 15.4, *)
private struct SiteList: View {
    let item: Installed
    @ObservedObject var extensions: Extensions
    @State private var typed = ""

    var body: some View {
        let access = extensions.siteAccess(item.id)
        VStack(alignment: .leading, spacing: 6) {
            if access.mode == .some {
                ForEach(access.hosts, id: \.self) { host in
                    HStack(spacing: 6) {
                        Text(host)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Button {
                            extensions.setSiteAccess(item.id, access.removing(host))
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Palette.muted)
                                .frame(width: 18, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("移除 \(host)")
                        .help("移除 \(host)")
                    }
                }
                HStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        if typed.isEmpty {
                            Text("Add a site, like example.com")
                                .foregroundStyle(Palette.muted.opacity(0.8))
                        }
                        TextField("", text: $typed)
                            .textFieldStyle(.plain)
                            .foregroundStyle(Palette.ink)
                            .onSubmit(add)
                            .accessibilityLabel("为 \(item.name) 添加网站")
                    }
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Pill("Add", action: add)
                        .disabled(SiteAccess.host(from: typed) == nil)
                }
            }
            Text(note(access))
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func add() {
        guard let host = SiteAccess.host(from: typed) else { return }
        extensions.setSiteAccess(item.id, extensions.siteAccess(item.id).adding(host))
        typed = ""
    }

    private func note(_ access: SiteAccess) -> String {
        var out = access.mode == .some
            ? "包含子域名。在其他网站上，点击其按钮后将在当前标签页运行，直至离开该网站。"
            : "点击其按钮后将在当前标签页的该页面上运行，直至离开该网站。"
        if SiteAccess.needsEverySite(name: item.name, said: Extensions.settings(for: item.id)) {
            out += " \(item.name) may need every site to fill in sign-ins."
        }
        return out
    }
}

/// On an extension's page in the Chrome Web Store, the offer to add it —
/// where the store's own button only says "Switch to Chrome".
struct StoreOffer: View {
    @ObservedObject var browser: Browser

    var body: some View {
        if #available(macOS 15.4, *), let tab = browser.active {
            Watch(tab: tab, extensions: .shared)
        }
    }

    @available(macOS 15.4, *)
    private struct Watch: View {
        @ObservedObject var tab: Tab
        @ObservedObject var extensions: Extensions

        var body: some View {
            // Only where the page's own "Add to Search" isn't in place — a
            // store that has changed its markup still gets a way in.
            if let url = tab.address, let id = Crx.storeID(of: url),
               tab.storePlaced != id, !extensions.installed.contains(where: { $0.id == id }) {
                HStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(extensions.busy.contains(id) ? "正在添加…" : "将此扩展添加到 Search")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.ink)
                    if extensions.busy.contains(id) {
                        Ring(size: 10)
                    } else {
                        Button("添加") { extensions.install(from: id) }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.ground)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Palette.ink, in: Capsule())
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 10)
                .padding(.vertical, 9)
                .background(Palette.ground, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    static func isStorePage(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", url.user == nil, url.password == nil else { return false }
        let host = url.host()?.lowercased() ?? ""
        return host == "chromewebstore.google.com"
            || (host == "chrome.google.com" && url.path.hasPrefix("/webstore"))
    }
}

/// Settings › Browsing › Searching › Home page: what a new tab opens to, while an
/// extension offers a page for it. Search's own page with the address field
/// ready, or the page of an extension that asked to take its place, and
/// the way back from one that did. With nothing offered there is nothing to
/// pick, so the line isn't there at all, and neither is its hairline.
struct HomePageLine: View {
    var body: some View {
        if #available(macOS 15.4, *) {
            Chooser(extensions: .shared)
        }
    }

    @available(macOS 15.4, *)
    private struct Chooser: View {
        @ObservedObject var extensions: Extensions

        var body: some View {
            let askers = extensions.newTabAskers
            let current = extensions.newTabPageID
            if !askers.isEmpty {
                Rule()
                SettingRow(icon: "house", title: "主页", detail: detail(askers, current)) {
                    Picker("", selection: Binding(
                        get: { current ?? "" },
                        set: { extensions.setNewTabPage($0.isEmpty ? nil : $0) }
                    )) {
                        Text("Search's own").tag("")
                        Divider()
                        ForEach(askers) { Text($0.name).tag($0.id) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
            }
        }

        private func detail(_ askers: [Installed], _ current: String?) -> String {
            if let current, let name = askers.first(where: { $0.id == current })?.name {
                return "新标签页将显示 \(name) 的页面，因为你已允许它替换新标签页"
            }
            return askers.count == 1
                ? "新标签页打开为空白页。\(askers[0].name) 请求改为显示其页面"
                : "新标签页打开为空白页。\(askers.count) 个扩展请求改为显示其页面"
        }
    }
}
