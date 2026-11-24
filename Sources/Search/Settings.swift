import SwiftUI

/// Everything there is to set. Sections down the left, under a field that
/// finds any setting by its words (⌘F); one section at a time on the right,
/// in titled groups, each a card of rows. A row says what it is with a small
/// icon and a line of plain words, the rest behind its (i). Every row of a
/// card stands at the same level, hairlines from edge to edge; a row that
/// only counts while another is on is only there while it counts. Every
/// row comes from SettingsIndex, so what the find field finds is exactly
/// what the sections hold.
struct SettingsPanel: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences
    /// The section the tab's address names (search://settings/privacy),
    /// when Settings is a tab: asked for again, it moves there.
    var asked: String? = nil
    /// Words already in Find a setting when it opens (previews).
    var found: String? = nil
    @Environment(\.asTab) private var asTab

    @ObservedObject private var updater = Updater.shared
    @ObservedObject private var shield = Shield.shared
    @ObservedObject private var sync = Sync.shared
    @ObservedObject private var icloud = ICloudSync.shared
    /// The keys rows name, as Settings › Shortcuts has them now.
    @ObservedObject private var shortcuts = ShortcutStore.shared
    @State private var isDefault = Links.isDefault
    /// Whether Search opens email links, and which app does now.
    @State private var mailDefault = Mail.isDefault
    @State private var mailHandler = Mail.handlerName
    /// A site shortcut being written, kept out of Preferences until it's saved.
    @State private var draft: Keyword?
    @State private var page: Page = Page.named(Store.settings.string(forKey: "settings.page") ?? "") ?? .general
    /// The chosen section's white, slid from one to the next as the tab
    /// column slides its live tab's (Side.swift).
    @Namespace private var chosen
    /// What is typed in Find a setting.
    @State private var query = ""
    @FocusState private var finding: Bool
    /// A row gone to from a result, lit for a moment.
    @State private var lit: String?
    /// What Set Up Like Arc changed, for Undo.
    @State private var arcBefore: Preferences.ArcSetup? = SettingsPanel.arcBefore
    @MainActor static var arcBefore: Preferences.ArcSetup?

    enum Page: String, CaseIterable, Identifiable {
        case general, appearance, themes, tabs, browsing, spaces, passwords, privacy, ai, extensions, keyboard, about
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "通用"
            case .appearance: return "外观"
            case .themes: return "主题"
            case .tabs: return "标签页"
            case .browsing: return "浏览"
            case .spaces: return "空间与固定标签页"
            case .passwords: return "密码"
            case .privacy: return "隐私"
            case .ai: return "AI"
            case .extensions: return "扩展"
            case .keyboard: return "键盘与鼠标"
            case .about: return "关于"
            }
        }
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .appearance: return "paintbrush"
            case .themes: return "photo.artframe"
            case .tabs: return "square.on.square"
            case .browsing: return "globe"
            case .spaces: return "square.stack"
            case .passwords: return "key"
            case .privacy: return "hand.raised"
            case .ai: return "sparkles"
            case .extensions: return "puzzlepiece.extension"
            case .keyboard: return "keyboard"
            case .about: return "info.circle"
            }
        }
        /// A section by its name in an address or in the settings file,
        /// the old names included: Downloads is in General now, Shortcuts
        /// is Keyboard & Mouse.
        static func named(_ name: String) -> Page? {
            switch name.lowercased() {
            case "downloads": return .general
            case "shortcuts", "mouse": return .keyboard
            default: return Page(rawValue: name.lowercased())
            }
        }
        /// The rail's three blocks: the browser, your data and tools, About.
        static var blocks: [[Page]] {
            [[.general, .appearance, .themes, .tabs, .browsing, .spaces],
             [.passwords, .privacy] + (AI.shipped ? [.ai] : []) + [.extensions, .keyboard],
             [.about]]
        }
    }

    private static let rail: CGFloat = 196
    private static let column: CGFloat = 600
    private static let width: CGFloat = 720
    private static let height: CGFloat = 540
    /// Where a row's words start, past its icon. What goes under a row's
    /// words (pictures, lists, fields) starts there too.
    static let textInset: CGFloat = 52
    /// A list under a row's words starts this far in, its lines adding
    /// their own 14 to reach textInset.
    static let listInset: CGFloat = textInset - 14

    var body: some View {
        Group {
            if asTab { tabbed } else { card }
        }
        .onChange(of: browser.settingsFind) { _, _ in finding = true }
        .onAppear { if let found { query = found } }
    }

    /// In a tab of its own (see InternalPages.swift): the sections down the
    /// left, the window's whole height, and the section down the middle of
    /// the rest.
    private var tabbed: some View {
        HStack(spacing: 0) {
            pages
            Rectangle().fill(Palette.hairline).frame(width: 1)
            content
                .padding(.top, 26)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { follow(asked) }
        .onChange(of: asked) { _, asked in follow(asked) }
        .onChange(of: page) { _, page in
            Store.settings.set(page.rawValue, forKey: "settings.page")
            browser.settingsMoved(to: page)
        }
    }

    private func follow(_ asked: String?) {
        guard let asked, let wanted = Page.named(asked), wanted != .ai || AI.shipped, wanted != page else { return }
        page = wanted
    }

    private var card: some View {
        HStack(spacing: 0) {
            pages
            Rectangle().fill(Palette.hairline).frame(width: 1)
            content
        }
        .frame(width: SettingsPanel.width, height: SettingsPanel.height)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 34, y: 12)
        .onChange(of: page) { _, page in Store.settings.set(page.rawValue, forKey: "settings.page") }
    }

    // MARK: - the rail

    private var hits: [SettingsItem] { SettingsIndex.find(query) }
    private var searching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var pages: some View {
        let counts = Dictionary(grouping: hits, by: \.page).mapValues(\.count)
        return VStack(alignment: .leading, spacing: 2) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 10)
                .padding(.top, 14)
                .padding(.bottom, 10)
            FindField(text: $query, focus: $finding)
                .padding(.bottom, 10)
            ForEach(Array(Page.blocks.enumerated()), id: \.offset) { index, block in
                if index > 0 {
                    Rectangle().fill(Palette.hairline).frame(height: 1)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                }
                ForEach(block) { item in
                    PageRow(page: item, on: !searching && page == item,
                            count: searching ? counts[item] ?? 0 : nil, chosen: chosen) {
                        query = ""
                        page = item
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .animation(slide, value: page)
        .padding(8)
        .frame(width: SettingsPanel.rail, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.wash.opacity(0.45), in: Rectangle())
    }

    /// The white's move: the tab column's glide, a touch longer and with a
    /// little give at the end, so the eye follows it down the rail. None
    /// with Reduce Motion, and a plain ease in Low Power Mode, as glide.
    private var slide: Animation? {
        Motion.reduced ? nil : Motion.light ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.72)
    }

    /// Find a setting: the wash, the glass, ⌘F beside it until something
    /// is typed. Escape empties it.
    private struct FindField: View {
        @Binding var text: String
        var focus: FocusState<Bool>.Binding

        var body: some View {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Find a setting").foregroundStyle(Palette.muted.opacity(0.8))
                    }
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.ink)
                        .focused(focus)
                        .onExitCommand { text = "" }
                        .accessibilityLabel("查找设置")
                }
                .font(.system(size: 12.5))
                if text.isEmpty {
                    Text("⌘F")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Palette.muted.opacity(0.8))
                } else {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(Palette.ground, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
    }

    private struct PageRow: View {
        let page: Page
        let on: Bool
        /// While searching: how many rows of this section match.
        let count: Int?
        let chosen: Namespace.ID
        let act: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: act) {
                HStack(spacing: 9) {
                    Image(systemName: page.icon)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 16)
                    Text(page.title)
                        .font(.system(size: 13, weight: on ? .medium : .regular))
                    Spacer(minLength: 0)
                    if let count, count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 6)
                            .frame(height: 17)
                            .background(Palette.ground, in: Capsule(style: .continuous))
                    }
                }
                .foregroundStyle(on ? Palette.ink : (hovering ? Palette.ink.opacity(0.75) : Palette.muted))
                .opacity(count == 0 ? 0.4 : 1)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background {
                    if on {
                        Capsule(style: .continuous)
                            .fill(Palette.ground)
                            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "chosen", in: chosen)
                    } else if hovering {
                        Capsule(style: .continuous)
                            .fill(Palette.hover)
                    }
                }
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }

    // MARK: - the page

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if !searching {
                    Image(systemName: page.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
                Text(searching ? "匹配“\(query.trimmingCharacters(in: .whitespaces))”的设置" : page.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer()
                if !asTab {
                    Door(icon: "xmark", help: "完成   esc") { browser.tuning = false }
                }
            }
            .padding(.bottom, 18)
            .padding(.horizontal, 24)
            .frame(maxWidth: asTab ? SettingsPanel.column : .infinity)
            .frame(maxWidth: .infinity)

            ScrollViewReader { reader in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if searching { results } else { section(page) }
                    }
                    .environment(\.ruleInset, 0)
                    .padding(.bottom, 24)
                    // Keep the rows narrow, not the scroll view: the empty
                    // space beside them must receive scrolling too.
                    .padding(.horizontal, 24)
                    .frame(maxWidth: asTab ? SettingsPanel.column : .infinity)
                    .frame(maxWidth: .infinity)
                }
                .onAppear { if let lit { reader.scrollTo(lit, anchor: .center) } }
            }
            // A page of its own opens at its top. One scroll view kept for
            // them all opened Tabs as far down as General had been read.
            .id(searching ? "found" : page.rawValue)
        }
        .padding(.top, 18)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func section(_ page: Page) -> some View {
        switch page {
        case .about:
            aboutHeader
            groups(of: page)
        case .keyboard:
            groups(of: page)
            GroupBlock(title: "快捷键", icon: "command") {
                ShortcutsPage(browser: browser, store: .shared, prefs: prefs)
            }
        case .privacy:
            groups(of: page)
            GroupBlock(title: "代理", icon: "network") {
                ProxySettings()
            }
        case .extensions:
            ExtensionsPage(browser: browser)
        case .ai:
            if AI.shipped { AISettings(browser: browser, prefs: prefs) }
        default:
            groups(of: page)
        }
    }

    private func groups(of page: Page) -> some View {
        ForEach(SettingsIndex.groups(of: page)) { group in
            GroupBlock(title: group.title, icon: group.icon) {
                Card { rows(SettingsIndex.items(in: group.id).filter(shown), searched: false) }
            }
        }
    }

    /// In its section, a dependent row is there only while it counts.
    private func shown(_ item: SettingsItem) -> Bool { SettingsIndex.applies(item, prefs) }

    private func rows(_ items: [SettingsItem], searched: Bool) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 { Rule() }
            row(item)
            after(item, searched: searched)
        }
    }

    private func row(_ item: SettingsItem) -> some View {
        let counts = SettingsIndex.applies(item, prefs)
        // The switch that swaps ⌘1–⌘9 and ⌃1–⌃9 names both as they were.
        let relabel: (String) -> String = item.id == "spaces.commandNumbers" ? { $0 } : shortcuts.relabel
        return SettingRow(
            icon: item.icon,
            title: relabel(title(of: item)),
            detail: relabel(counts ? detail(of: item) : SettingsIndex.needs(item)),
            more: counts ? item.more.map(relabel) : nil,
            wide: item.kind == .wide,
            lit: lit == item.id
        ) {
            control(item)
        }
        .disabled(!counts)
        .opacity(counts ? 1 : 0.5)
        .id(item.id)
    }

    // MARK: - found

    @ViewBuilder
    private var results: some View {
        let found = hits
        if found.isEmpty {
            Card { Nothing("No setting called that. Try other words, like dark, tabs or video") }
        }
        let byGroup = Dictionary(grouping: found, by: \.group)
        ForEach(SettingsIndex.groups.filter { byGroup[$0.id] != nil }) { group in
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    let first = byGroup[group.id]?.first
                    query = ""
                    page = group.page
                    lit = first?.findOnly == false ? first?.id : nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { withAnimation(Motion.quick) { lit = nil } }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: group.icon).font(.system(size: 10.5, weight: .medium))
                        Text("\(group.page.title)  ›  \(group.title)".uppercased())
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(0.4)
                        Image(systemName: "arrow.right").font(.system(size: 9, weight: .semibold)).opacity(0.6)
                    }
                    .foregroundStyle(Palette.muted)
                    .padding(.leading, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开\(group.page.title)中的\(group.title)")
                Card { rows(byGroup[group.id] ?? [], searched: true) }
            }
        }
    }

    // MARK: - words that change

    private func title(of item: SettingsItem) -> String {
        switch item.id {
        case "updates.version": return versionTitle
        // ⌃ while it picks the tabs (Settings › Spaces & Pins).
        case "tabs.shortcuts" where prefs.usesSpaces && prefs.spacesOnCommand: return "按住 ⌃ 时显示标签页编号"
        default: return item.title
        }
    }

    private func detail(of item: SettingsItem) -> String {
        switch item.id {
        case "general.default":
            return isDefault ? "Search 已设为这台 Mac 的默认浏览器" : item.detail
        case "mail.default":
            if mailDefault { return "其他 App 中的电子邮件链接将在此打开" }
            return mailHandler.map { "Email links from other apps go to \($0) now" } ?? item.detail
        case "downloads.folder":
            return prefs.downloads.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        case "sync": return icloud.on ? "开启“通过 iCloud 同步”时将关闭此项" : sync.on ? sync.summary : item.detail
        case "icloud": return icloud.summary(folderSyncOn: sync.on, otherwise: item.detail)
        case "search.engine": return searchDetail
        case "search.shift": return shiftDetail
        case "search.suggest": return suggestDetail
        case "search.keywords": return keywordDetail
        case "passwords.save": return savingDetail
        case "passkeys":
            return !prefs.passkeysPossible
                ? "需要此版本暂未包含的 Apple 权限"
                : Passkeys.access == .denied
                ? "macOS 已拒绝权限：系统设置 › 隐私与安全性 › 通行密钥"
                : item.detail
        case "shield": return shield.trouble ?? item.detail
        case "updates.version": return versionDetail
        case "arc.import": return arcHere ? item.detail : "这台 Mac 上未安装 Arc。“导入数据”可读取导出文件"
        default: return item.detail
        }
    }

    private var arcHere: Bool { FileManager.default.fileExists(atPath: Arc.file.path) }

    // MARK: - controls

    @ViewBuilder
    private func control(_ item: SettingsItem) -> some View {
        switch item.page {
        case .general: generalControl(item.id)
        case .appearance: appearanceControl(item.id)
        case .themes: ThemesPage(prefs: prefs)
        case .tabs: tabsControl(item.id)
        case .browsing: browsingControl(item.id)
        case .spaces: spacesControl(item.id)
        case .passwords, .privacy: keptControl(item.id)
        case .keyboard, .about: otherControl(item.id)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func generalControl(_ id: String) -> some View {
        switch id {
        case "general.default":
            if isDefault {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 24)
            } else {
                Pill("Make default", filled: true) {
                    Links.becomeDefault { worked in
                        isDefault = Links.isDefault
                        browser.announce(worked && isDefault ? "链接现将在此打开" : "macOS 未应用此更改")
                    }
                }
            }
        case "mail.webmail":
            Picker("", selection: $prefs.webmail) {
                ForEach(Webmail.allCases) { mail in
                    Text(mail.title).tag(mail)
                    if mail == .none { Divider() }
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "mail.default":
            if mailDefault {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 24)
            } else {
                // Only ever from this click: macOS asks to confirm.
                Pill("Make default", filled: true) {
                    Mail.becomeDefault { worked in
                        mailDefault = Mail.isDefault
                        mailHandler = Mail.handlerName
                        browser.announce(worked && mailDefault ? "电子邮件链接现将在此打开" : "macOS 未应用此更改")
                    }
                }
            }
        case "general.import":
            // Coming from another browser, now or any time later: the same
            // page as File › Bring Things Over… and the Welcome's.
            Pill("Bring Things Over…") { browser.lead(to: InternalPage(.importing)) }
        case "sync":
            // On asks for the folder first; cancelled, it stays off.
            // Never with Sync with iCloud: the two would undo each other.
            Switch(on: Binding(get: { sync.on }, set: { $0 ? sync.choose() : sync.turnOff() }))
                .disabled(icloud.on && !sync.on)
                .opacity(icloud.on && !sync.on ? 0.4 : 1)
        case "handoff": Switch(on: $prefs.handoff)
        case "icloud":
            // Off limits in a build not signed for iCloud, and while the
            // folder sync is on.
            let locked = !icloud.on && (!icloud.available || sync.on)
            Switch(on: Binding(get: { icloud.on }, set: { $0 ? icloud.turnOn() : icloud.turnOff() }))
                .disabled(locked)
                .opacity(locked ? 0.4 : 1)
        case "icloud.erase":
            Pill("Delete…") {
                let alert = NSAlert()
                alert.messageText = "Delete Search's data from iCloud?"
                alert.informativeText = "Open tabs, pins, spaces, bookmarks and settings leave iCloud for every device. What is on each device stays. Sync with iCloud turns off here and on your other devices."
                alert.addButton(withTitle: "删除")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn { icloud.erase() }
            }
        case "quit.confirm": Switch(on: $prefs.confirmsQuit)
        case "downloads.folder": Pill("Change…") { chooseFolder() }
        case "downloads.ask": Switch(on: $prefs.asksWhereToSave)
        case "downloads.button": Switch(on: $prefs.alwaysShowsDownloads)
        case "downloads.open":
            Picker("打开下载", selection: $prefs.downloadsOpening) {
                ForEach(DownloadsOpening.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func appearanceControl(_ id: String) -> some View {
        switch id {
        case "look":
            Pictures(options: Look.allCases.map { look in
                (look, look == .system ? "自动" : look.title, AnyView(LookPicture(look: look)))
            }, selection: $prefs.look)
        case "pages.dusk": Switch(on: $prefs.darkensPages)
        case "inspector.chrome": Switch(on: $prefs.inspectorChrome)
        case "inspector.dark": Switch(on: $prefs.inspectorDark)
        case "tabs.layout":
            Pictures(options: TabsLayout.allCases.map { ($0, $0.title, AnyView(LayoutPicture(layout: $0))) },
                     selection: Binding(
                        get: { prefs.tabsLayout },
                        set: { layout in withAnimation(Motion.glide) { prefs.tabsLayout = layout } }
                     ))
        case "sidebar.hides": Switch(on: $prefs.sideHides)
        case "sidebar.slides": Switch(on: $prefs.slidesColumn)
        case "sidebar.foldIcons": Switch(on: $prefs.foldsToIcons)
        case "layout.cards":
            Pictures(options: [(true, "卡片式", AnyView(CardPicture(card: true))),
                               (false, "铺满窗口", AnyView(CardPicture(card: false)))],
                     selection: Binding(
                        get: { prefs.cards },
                        set: { on in withAnimation(Motion.glide) { prefs.cards = on } }
                     ))
        case "layout.cardsFullScreen": Switch(on: $prefs.cardsInFullScreen)
        case "address.shown": Switch(on: $prefs.addressLine)
        case "address.width": Segmented(options: AddressWidth.allCases.map { ($0, $0.title) }, selection: $prefs.addressWidth)
        case "window.glass": Switch(on: $prefs.glass)
        case "window.glass.style": Segmented(options: GlassStyle.allCases.map { ($0, $0.title) }, selection: $prefs.glassStyle)
        case "window.glass.clear": Slider(value: $prefs.glassClear, in: 0...1).controlSize(.small).frame(width: 160)
        case "window.glass.grain": Slider(value: $prefs.glassGrain, in: 0...1).controlSize(.small).frame(width: 160)
        case "toolbar.left": Switch(on: $prefs.navigationLeft)
        case "tabs.compact":
            Switch(on: Binding(
                get: { prefs.compactStrip },
                set: { on in withAnimation(Motion.glide) { prefs.compactStrip = on } }
            ))
        case "tabs.liquid": Switch(on: $prefs.liquidTabs)
        case "sidebar.roomy":
            Switch(on: Binding(
                get: { prefs.roomyTabs },
                set: { on in withAnimation(Motion.glide) { prefs.roomyTabs = on } }
            ))
        case "sidebar.player": Switch(on: $prefs.showsPlayer)
        case "sidebar.foldButton": Switch(on: $prefs.foldButton)
        case "sidebar.narrowIcons":
            Switch(on: Binding(
                get: { prefs.narrowsToIcons },
                // Off, the column has its titles back, and on again it starts
                // with them rather than as a strip from long ago.
                set: { on in withAnimation(Motion.glide) { prefs.narrowsToIcons = on; if !on { prefs.narrowed = false } } }
            ))
        case "sidebar.doorsUp":
            Switch(on: Binding(
                get: { prefs.doorsUp },
                set: { on in withAnimation(Motion.glide) { prefs.doorsUp = on } }
            ))
        case "glyph": Segmented(options: Glyph.allCases.map { ($0, $0.title) }, selection: $prefs.glyph)
        case "tabs.highContrast": Switch(on: $prefs.highContrastText)
        case "tabs.reading": Switch(on: $prefs.showsReading)
        case "tabs.give": Switch(on: $prefs.tabsGive)
        case "bookmarks.bar": Switch(on: $prefs.bookmarksBar)
        case "motion.light": Switch(on: $prefs.lightMotion)
        case "motion.instant": Switch(on: $prefs.instantMotion)
        case "note.split": Always()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func tabsControl(_ id: String) -> some View {
        switch id {
        case "tabs.newPlace":
            Picker("新标签页位置", selection: $prefs.newTabPlace) {
                Text("After current").tag(NewTabPlace.next)
                Text(prefs.sidebar ? "顶部" : "最左侧").tag(NewTabPlace.top)
                Text(prefs.sidebar ? "底部" : "最右侧").tag(NewTabPlace.end)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "tabs.newAfterLast": Switch(on: $prefs.newTabAfterLast)
        case "tabs.closeGoesBack": Switch(on: $prefs.closeGoesBack)
        case "home.grid": Switch(on: $prefs.homeGrid)
        case "tabs.undoReopens": Switch(on: $prefs.undoReopensTab)
        case "tabs.switcherBehindFirst": Switch(on: $prefs.switcherBehindFirst)
        case "tabs.switcherLeavesOutPins": Switch(on: $prefs.switcherLeavesOutPins)
        case "tabs.frontBeside": Switch(on: $prefs.frontLinksBeside)
        case "tabs.swipeBackCloses": Switch(on: $prefs.swipeBackCloses)
        case "tabs.mirror": Switch(on: $prefs.mirrorsTabs)
        case "tabs.lazy": Switch(on: $prefs.lazyTabs)
        case "tabs.popupWindows": Switch(on: $prefs.popupWindows)
        case "tabs.sleep":
            VStack(alignment: .leading, spacing: 7) {
                Segmented(options: SleepChoice.allCases.map { ($0, $0.title) }, selection: $prefs.sleepChoice, wide: true)
                    .frame(maxWidth: 340)
                Text(prefs.sleepChoice.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        case "tabs.sleep.dim": Switch(on: $prefs.dimsSleepingTabs)
        case "tabs.close.after":
            Picker("", selection: $prefs.tabLife) {
                ForEach(TabLife.allCases) { life in
                    Text(life.title).tag(life)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "tabs.shortcuts": Switch(on: $prefs.showsTabShortcuts)
        case "tabs.address":
            Switch(on: Binding(
                get: { prefs.showsAddress },
                set: { on in withAnimation(Motion.glide) { prefs.showsAddress = on } }
            ))
        case "note.groups", "note.awake": Always()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func browsingControl(_ id: String) -> some View {
        switch id {
        case "search.engine":
            Picker("", selection: $prefs.engine) {
                ForEach(Engine.allCases) { engine in
                    Text(engine.title).tag(engine)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "search.shift":
            Picker("", selection: $prefs.shiftEngine) {
                Text("Off").tag(Engine?.none)
                Divider()
                ForEach(Engine.allCases) { engine in
                    Text(engine.title).tag(Engine?.some(engine))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "search.suggest": Switch(on: $prefs.engineSuggests)
        case "search.keywords":
            if draft == nil {
                Pill("Add") { draft = Keyword() }
            } else {
                HStack(spacing: 6) {
                    Pill("Cancel") { draft = nil }
                    Pill("Save", filled: true) { saveDraft() }
                        .disabled(draftProblem != nil)
                        .opacity(draftProblem == nil ? 1 : 0.4)
                }
            }
        case "links.little": Switch(on: $prefs.littleLinks)
        case "links.little.tabs": Switch(on: $prefs.littleFindsTabs)
        case "reader.twins": Switch(on: $prefs.readsTwins)
        case "reader.follows": Switch(on: $prefs.readerFollowsLook)
        case "float.style": Segmented(options: FloatStyle.allCases.map { ($0, $0.title) }, selection: $prefs.floatStyle)
        case "float.own":
            Segmented(options: FloatOwn.allCases.map { ($0, $0.title) }, selection: $prefs.floatOwn, wide: true)
                .frame(maxWidth: 340)
        case "float.minimize": Switch(on: $prefs.floatMinimizes)
        case "media.click": Switch(on: $prefs.waitsForPlay)
        case "fullscreen.escapeTwice": Switch(on: $prefs.escapeTwice)
        case "fullscreen.keepsWindow": Switch(on: $prefs.keepsWindow)
        case "translate.target":
            if PageTranslator.available { TranslateTargetPicker(prefs: prefs) }
            else { Text("Requires macOS 15").foregroundStyle(Palette.muted) }
        case "pageZoom":
            // The number itself takes it back to 100%.
            Steps(stops: Preferences.zooms, value: $prefs.pageZoom, home: 1) { "\(Int(($0 * 100).rounded()))%" }
        case "pages.120": Segmented(options: FastPages.allCases.map { ($0, $0.title) }, selection: $prefs.fastPages)
        case "pages.capture": Switch(on: $prefs.capturesPages)
        case "sites.styles": SiteStylesControl(prefs: prefs)
        case "autocorrect": Switch(on: $prefs.autocorrect)
        case "inlinePredictions": Switch(on: $prefs.inlinePredictions)
        case "note.panel", "note.translate", "note.sitesearch", "note.links", "note.flick": Always()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func spacesControl(_ id: String) -> some View {
        switch id {
        case "arc.setup":
            if let before = arcBefore, prefs.looksLikeArc {
                Pill("Undo") {
                    withAnimation(Motion.glide) { prefs.restore(before) }
                    arcBefore = nil
                    SettingsPanel.arcBefore = nil
                    browser.announce("Put back as it was")
                }
            } else if prefs.looksLikeArc {
                Always(text: "Set up")
            } else {
                Pill("Set Up", filled: true) { setUpLikeArc() }
            }
        case "arc.import":
            Pill("Bring Over…") { browser.lead(to: InternalPage(.importing, "Arc")) }
                .disabled(!arcHere)
                .opacity(arcHere ? 1 : 0.4)
        case "spaces": Switch(on: $prefs.usesSpaces)
        case "spaces.commandNumbers": Switch(on: $prefs.spacesOnCommand)
        case "profiles": Pill("New Profile…") { ProfileMenu.askNew() }
        case "profiles.oneWindow": Switch(on: $prefs.profilesInOneWindow)
        case "spaces.links": Switch(on: $prefs.sendsLinksToSpaces)
        case "spaces.buttons": Switch(on: $prefs.spaceButtons)
        case "links.ask": Switch(on: $prefs.asksSpaceForLinks)
        case "pins.keep": Switch(on: $prefs.pinsKeepSite)
        case "pins.list": Switch(on: $prefs.listsPins)
        case "pins.folders": Switch(on: $prefs.pinFolders)
        case "pins.commandNewTab": Switch(on: $prefs.pinCommandOpensTab)
        case "newtab.floating": Switch(on: $prefs.floatingNewTab)
        case "newtab.recent": Switch(on: $prefs.recentInNewTab)
        case "newtab.arc": Switch(on: $prefs.arcTabPopup)
        case "commandbar": Switch(on: $prefs.commandBar)
        case "start.fresh": Switch(on: $prefs.startsFresh)
        case "note.sharedpins", "note.pinback": Always()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func keptControl(_ id: String) -> some View {
        switch id {
        case "passwords.open": Pill("Open…") { browser.lead(to: InternalPage(.passwords)) }
        case "passwords.save": Switch(on: $prefs.savesPasswords)
        case "passwords.fill": Switch(on: $prefs.fillsPasswords)
        case "passkeys": Switch(on: $prefs.passkeys)
        case "passwords.apple": Switch(on: $prefs.applePasswords)
        // Turned on, macOS is asked whether Search may read Contacts; a no,
        // or no card of yours, leaves it off and says why.
        case "contacts.fill":
            Switch(on: Binding(get: { prefs.fillsContacts }, set: { on in
                guard on else { prefs.fillsContacts = false; return }
                Task { @MainActor in
                    guard await MeCard.shared.ask() else {
                        browser.announce("Search may not read Contacts: System Settings › Privacy & Security › Contacts")
                        return
                    }
                    guard await MeCard.shared.reload() else {
                        browser.announce("No card of yours in Contacts: pick yours there, then Card › Make This My Card")
                        return
                    }
                    prefs.fillsContacts = true
                }
            }))
        case "shield": Switch(on: $prefs.shielded)
        case "sites.keep": Switch(on: Binding(get: { !prefs.keepsSignIns }, set: { prefs.keepsSignIns = !$0 }))
        case "privacy.clickIDs": Switch(on: $prefs.removesClickIDs)
        case "privacy.gpc": Switch(on: $prefs.sendsPrivacySignal)
        case "privacy.httpsFirst": Switch(on: $prefs.triesHTTPSFirst)
        case "notifications.ask": Switch(on: $prefs.siteNotifications)
        case "privacy.forget": Pill("Forget choices") { browser.forgetCaptureChoices() }
        case "clear.history": Pill("Clear") { browser.clearHistory() }
        case "clear.cookies": Pill("Sign out of everything") { browser.clearSites() }
        case "clear.cache": Pill("Clear") { browser.clearCache() }
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func otherControl(_ id: String) -> some View {
        switch id {
        case "links.peek":
            Picker("预览链接", selection: $prefs.peekChoice) {
                ForEach(PeekChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        case "links.peek.stays": Switch(on: $prefs.peekStays)
        case "links.optionSplit": Switch(on: $prefs.optionClickSplits)
        case "autoscroll": Switch(on: $prefs.autoScroll)
        case "pages.bounce": Switch(on: $prefs.bounces)
        case "swipe.history": Switch(on: $prefs.holdsHistory)
        case "launcher.on": Switch(on: $prefs.launcher)
        case "launcher.key": LauncherKeyBox(prefs: prefs)
        case "launcher.little": Switch(on: $prefs.launcherLittle)
        case "note.switcher": Always()
        case "updates.version": versionControl
        case "updates.auto": Switch(on: $prefs.installsUpdates)
        case "about.feedback": Pill("Send Feedback") { Links.writeFeedback() }
        case "about.notes": Pill("What's New…") { browser.lead(to: InternalPage(.notes)) }
        case "bench": Switch(on: $prefs.bench)
        case "agents": Switch(on: $prefs.agents)
        case "news.updates": OptInSettingsField(betaOnly: false) { _ = browser.open($0, foreground: true) }
        case "news.iphone": OptInSettingsField(betaOnly: true) { _ = browser.open($0, foreground: true) }
        default: EmptyView()
        }
    }

    // MARK: - what goes under a row

    // Rows here are siblings of the one above, at its level; lists sit
    // under its words, as pictures do, their hairlines still edge to edge.

    @ViewBuilder
    private func after(_ item: SettingsItem, searched: Bool) -> some View {
        switch item.id {
        case "search.engine":
            if prefs.engine == .custom { templateField($prefs.customEngine) }
        case "search.shift":
            if prefs.shiftEngine == .custom { templateField($prefs.shiftCustom) }
        case "search.keywords":
            keywordEditor
            // What ⌘T opens to, and the way back after an extension took
            // it. Only there while an extension offers a page.
            if !searched { HomePageLine() }
        case "shield":
            if let trouble = shield.trouble {
                Rule()
                Line(trouble, "此问题解决前不会拦截任何内容。请重试或重新启动 Search") {
                    Pill("Try again") { shield.compile() }
                }
                .under()
            }
        case "privacy.forget":
            if !searched {
                Group {
                    NotificationSites()
                    PopupSiteList(prefs: prefs)
                }
                .under()
            }
        case "passkeys":
            if !searched, !Vault.never.isEmpty {
                Rule()
                SettingRow(icon: "hand.raised.slash", title: "永不询问的网站",
                           detail: "已对 \(Vault.never.count) 个网站停止提示") {
                    Pill("Forget") {
                        Vault.never = []
                        browser.announce("Every site can ask again")
                    }
                }
            }
        case "agents":
            if !searched, prefs.agents { RememberedAgents() }
        case "passwords.apple":
            ApplePasswordsCard(prefs: prefs, bare: true)
                .under()
        case "profiles":
            if !searched {
                ProfileList(browser: browser)
                    .under()
            }
        case "spaces.links":
            if !searched, prefs.usesSpaces, prefs.sendsLinksToSpaces {
                SpaceRouteList(prefs: prefs)
                    .under()
            }
        case "pages.120":
            if !searched, PageTranslator.available, !prefs.translateAlways.isEmpty {
                TranslateLanguageList(prefs: prefs)
                    .under()
            }
        default:
            EmptyView()
        }
    }

    /// A custom engine's address, under the row that chose Custom.
    private func templateField(_ text: Binding<String>) -> some View {
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text("https://example.com/search?q=%s")
                    .foregroundStyle(Palette.muted.opacity(0.8))
            }
            TextField("", text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(Palette.ink)
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Palette.wash, in: Capsule(style: .continuous))
        .padding(.leading, SettingsPanel.textInset)
        .padding(.trailing, 14)
        .padding(.bottom, 11)
    }

    @ViewBuilder
    private var keywordEditor: some View {
        if let current = draft {
            HStack(spacing: 8) {
                TextField("yt", text: Binding(
                    get: { current.keyword },
                    set: { draft?.keyword = $0 }
                ))
                .textFieldStyle(.plain)
                .frame(width: 50)
                Text("→").foregroundStyle(Palette.muted)
                TextField("https://www.youtube.com/results?search_query=%s", text: Binding(
                    get: { current.template },
                    set: { draft?.template = $0 }
                ))
                .textFieldStyle(.plain)
                .onSubmit(saveDraft)
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Palette.wash, in: Capsule(style: .continuous))
            .padding(.leading, SettingsPanel.textInset)
            .padding(.trailing, 14)
            .padding(.bottom, 6)
        }
        // The one being changed is up in the editor, not here as well.
        ForEach(prefs.keywords.filter { $0.id != draft?.id }) { entry in
            HStack(spacing: 8) {
                // Clicked, a saved shortcut opens in the editor to be
                // changed, rather than deleted and written again.
                HStack(spacing: 8) {
                    Text(entry.keyword)
                        .frame(width: 50, alignment: .leading)
                    Text("→").foregroundStyle(Palette.muted)
                    Text(entry.template)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { draft = entry }
                .help("点按以更改")
                Button {
                    prefs.keywords.removeAll { $0.id == entry.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.faint)
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Palette.wash, in: Capsule(style: .continuous))
            .padding(.leading, SettingsPanel.textInset)
            .padding(.trailing, 14)
            .padding(.bottom, 6)
        }
    }

    /// Checked when it's saved, not as it's typed into the list: a shortcut
    /// only exists once its address is one it's safe to send words to.
    private var draftProblem: String? {
        guard let draft else { return nil }
        return Keyword.problem(word: draft.keyword, template: draft.template,
                               among: prefs.keywords.filter { $0.id != draft.id })
    }

    private var keywordDetail: String {
        guard let draft else { return SettingsIndex.item("search.keywords")?.detail ?? "" }
        if draft.keyword.isEmpty, draft.template.isEmpty {
            return "输入关键词，再填入网站搜索网址，用 %s 代替搜索词"
        }
        return draftProblem ?? "输入 \(draft.keyword.trimmingCharacters(in: .whitespacesAndNewlines)) 将搜索 \(draft.name)"
    }

    private func saveDraft() {
        guard let current = draft, draftProblem == nil else { return }
        let saved = Keyword(
            id: current.id,
            keyword: current.keyword.trimmingCharacters(in: .whitespacesAndNewlines),
            template: current.template.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        // One being changed keeps its place in the list.
        if let index = prefs.keywords.firstIndex(where: { $0.id == saved.id }) {
            prefs.keywords[index] = saved
        } else {
            prefs.keywords.append(saved)
        }
        draft = nil
    }

    /// Said plainly: turned on, what you type leaves the Mac as you type it.
    private var suggestDetail: String {
        let name = prefs.engine.name(custom: prefs.customEngine)
        guard EngineSuggest.endpoint(for: prefs.engine) != nil else {
            return "自定义搜索引擎不提供建议，因此不会发送任何内容"
        }
        return "输入内容将实时发送给 \(name)"
    }

    private var searchDetail: String {
        guard prefs.engine == .custom else { return "非网址内容将发送到此处进行搜索" }
        guard Engine.accepts(Engine.written(prefs.customEngine)) else {
            return "填入包含 %s（代替搜索词）的 http 或 https 网址。设置前默认使用 Google"
        }
        return "搜索词将发送至 \(prefs.engine.name(custom: prefs.customEngine))"
    }

    private var shiftDetail: String {
        guard let engine = prefs.shiftEngine else {
            return SettingsIndex.item("search.shift")?.detail ?? ""
        }
        guard engine == .custom else { return "按 Shift-Return 可将输入内容发送至 \(engine.title)" }
        guard Engine.accepts(Engine.written(prefs.shiftCustom)) else {
            return "填入包含 %s（代替搜索词）的 http 或 https 网址。设置前默认使用 Google"
        }
        return "按 Shift-Return 可将输入内容发送至 \(engine.name(custom: prefs.shiftCustom))"
    }

    /// Says so when a password manager extension has taken the saving over.
    private var savingDetail: String {
        if #available(macOS 15.4, *), let name = Extensions.shared.passwordSavingTakenBy {
            return "由 \(name) 负责保存；该扩展已要求 Search 不再提示"
        }
        return "每个网站仅询问一次，拒绝后不再提示"
    }

    private func setUpLikeArc() {
        let before = prefs.arcSnapshot
        let changed = withAnimation(Motion.glide) { prefs.setUpLikeArc() }
        arcBefore = before
        SettingsPanel.arcBefore = before
        browser.announce(changed.isEmpty ? "已按 Arc 风格配置" : "已开启：" + changed.joined(separator: ", "))
    }

    // MARK: - about

    private var aboutHeader: some View {
        HStack(spacing: 14) {
            Logomark()
                .fill(Palette.ink, style: FillStyle(eoFill: true))
                .aspectRatio(Logomark.canvas.width / Logomark.canvas.height, contentMode: .fit)
                .frame(height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("Search")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("by Office Commun · version \(Updater.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    /// The version line follows the newer build from found to fetched to
    /// in place; with none, it is simply this one.
    private var versionTitle: String {
        switch updater.stage {
        case .none: return "更新"
        case .fetching(let next): return "正在下载 Search \(next.version)…"
        case .ready(let next): return "Search \(next.version) 已准备就绪"
        case .offered(let next), .waiting(let next): return "Search \(next.version) 已发布"
        }
    }

    private var versionDetail: String {
        switch updater.stage {
        case .none:
            return updater.lastChecked.map { "Checked \($0.formatted(.relative(presentation: .named))), every hour on its own" }
                ?? "每小时自动检查一次"
        case .fetching(let next):
            return next.notes ?? "在后台静默完成，不会影响你现有的任何设置"
        case .ready(let next):
            return next.notes ?? "下次打开 Search 时生效"
        case .offered(let next):
            return next.notes ?? "像首次安装时一样打开磁盘映像"
        case .waiting(let next):
            return next.notes ?? "点按“安装”后将校验并完成更新"
        }
    }

    @ViewBuilder
    private var versionControl: some View {
        switch updater.stage {
        case .none:
            Pill(updater.checking ? "正在检查…" : "立即检查") {
                updater.check { found in
                    if found == nil { browser.announce("This is the latest one") }
                }
            }
            .disabled(updater.checking)
        case .fetching:
            Ring(size: 12)
        case .ready:
            Pill("Relaunch now", filled: true) { updater.relaunch() }
        case .offered:
            Pill(updater.fetchingDisk ? "正在下载…" : "下载", filled: true) { updater.openDisk() }
                .disabled(updater.fetchingDisk)
        case .waiting:
            Pill("Install", filled: true) { updater.install() }
        }
    }

    // MARK: - doing

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = prefs.downloads
        panel.prompt = "使用此文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        prefs.downloads = url
    }
}

// MARK: - pieces

private extension View {
    /// A list under a row's words (sites, profiles, languages): its lines
    /// start where the row's title does, and its hairlines are pulled back
    /// out to the card's left edge, as every other one in Settings.
    func under() -> some View {
        padding(.leading, SettingsPanel.listInset)
            .environment(\.ruleInset, -SettingsPanel.listInset)
    }
}

/// A group of a section: its small heading with an icon, then its card.
/// No line under the heading: the rows say what they do.
struct GroupBlock<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(Palette.ink.opacity(0.62))
            .padding(.leading, 2)
            content()
        }
    }
}

/// One setting: its icon in a soft tile, what it is, one line on what it
/// does (the rest behind the (i)), and its control. A wide control goes
/// under the words.
struct SettingRow<Control: View>: View {
    let icon: String
    let title: String
    let detail: String
    var more: String? = nil
    var wide = false
    var lit = false
    @ViewBuilder let control: () -> Control

    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.ink.opacity(0.78))
                    .frame(width: 26, height: 26)
                    .background(Palette.wash, in: Capsule(style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(title)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if more != nil {
                            Button { withAnimation(Motion.quick) { open.toggle() } } label: {
                                Image(systemName: open ? "info.circle.fill" : "info.circle")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(Palette.muted.opacity(0.8))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(more ?? "")
                            .accessibilityLabel("关于\(title)的更多信息")
                        }
                    }
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if open, let more {
                        Text(more)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: 8)
                if !wide { control() }
            }
            if wide {
                control()
                    .padding(.leading, 38)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background(lit ? Palette.hover : .clear)
    }
}

/// For a feature that is simply there: no switch, a quiet word.
struct Always: View {
    var text = "Always on"
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Palette.wash, in: Capsule(style: .continuous))
    }
}

/// Choices shown as small pictures, as macOS's own Appearance pane has
/// them: a ring around the one picked, its name under each.
struct Pictures<Option: Hashable>: View {
    let options: [(Option, String, AnyView)]
    @Binding var selection: Option

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(options, id: \.0) { option, title, picture in
                let on = option == selection
                Button { withAnimation(Motion.settle) { selection = option } } label: {
                    VStack(spacing: 6) {
                        picture
                            .frame(width: 76, height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 1)
                            )
                            .padding(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                                    .strokeBorder(on ? Palette.ink : .clear, lineWidth: 2)
                            )
                        Text(title)
                            .font(.system(size: 11.5, weight: on ? .medium : .regular))
                            .foregroundStyle(on ? Palette.ink : Palette.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// A window in miniature with the tabs where a layout puts them.
private struct LayoutPicture: View {
    let layout: TabsLayout

    var body: some View {
        let tab = Palette.ink.opacity(0.22)
        let lit = Palette.ink.opacity(0.55)
        ZStack {
            Palette.wash
            switch layout {
            case .top:
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        lights
                        Capsule().fill(lit).frame(width: 14, height: 4)
                        Capsule().fill(tab).frame(width: 14, height: 4)
                        Capsule().fill(tab).frame(width: 10, height: 4)
                        Spacer(minLength: 0)
                    }
                    page
                }
                .padding(5)
            case .left, .right:
                HStack(spacing: 4) {
                    if layout == .right { page }
                    VStack(alignment: .leading, spacing: 3) {
                        if layout == .left { lights } else { Color.clear.frame(height: 3) }
                        Capsule().fill(lit).frame(width: 16, height: 3.5)
                        Capsule().fill(tab).frame(width: 16, height: 3.5)
                        Capsule().fill(tab).frame(width: 12, height: 3.5)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 18)
                    if layout == .left { page }
                }
                .padding(5)
            case .icons:
                // A narrow column of squares, one under the other: the
                // tabs' icons, no titles.
                HStack(spacing: 4) {
                    VStack(spacing: 3) {
                        VStack(spacing: 1.5) {
                            ForEach(0..<3) { _ in Circle().fill(Palette.ink.opacity(0.25)).frame(width: 3, height: 3) }
                        }
                        .padding(.bottom, 1)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(lit).frame(width: 6, height: 6)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(tab).frame(width: 6, height: 6)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(tab).frame(width: 6, height: 6)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 8)
                    page
                }
                .padding(5)
            }
        }
    }

    private var lights: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<3) { _ in Circle().fill(Palette.ink.opacity(0.25)).frame(width: 3, height: 3) }
        }
    }

    private var page: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Palette.ground)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Capsule().fill(Palette.ink.opacity(0.18)).frame(width: 22, height: 3)
                    Capsule().fill(Palette.ink.opacity(0.1)).frame(width: 30, height: 2.5)
                    Capsule().fill(Palette.ink.opacity(0.1)).frame(width: 26, height: 2.5)
                }
                .padding(5)
            }
    }
}

/// The page as a card, or reaching the window's edges.
private struct CardPicture: View {
    let card: Bool

    var body: some View {
        HStack(spacing: card ? 4 : 0) {
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(Palette.ink.opacity(0.55)).frame(width: 15, height: 3.5)
                Capsule().fill(Palette.ink.opacity(0.22)).frame(width: 15, height: 3.5)
                Capsule().fill(Palette.ink.opacity(0.22)).frame(width: 11, height: 3.5)
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .padding(.leading, card ? 0 : 5)
            .frame(width: card ? 17 : 22, alignment: .leading)
            if !card { Rectangle().fill(Palette.hairline).frame(width: 1) }
            RoundedRectangle(cornerRadius: card ? 4 : 0, style: .continuous)
                .fill(Palette.ground)
                .shadow(color: .black.opacity(card ? 0.12 : 0), radius: 1.5, y: 0.5)
        }
        .padding(card ? 5 : 0)
        .background(card ? Palette.wash : Palette.ground)
    }
}

/// Light, dark, or both halves for Auto: drawn in the look itself, not in
/// the one Search is in now.
private struct LookPicture: View {
    let look: Look

    var body: some View {
        switch look {
        case .light: Window(dark: false)
        case .dark: Window(dark: true)
        default:
            ZStack {
                Window(dark: false)
                Window(dark: true).mask(HStack(spacing: 0) { Color.clear; Color.black })
            }
        }
    }

    private struct Window: View {
        let dark: Bool
        var body: some View {
            let ground = Color(white: dark ? 0.11 : 1)
            let wash = Color(white: dark ? 0.17 : 0.93)
            let ink = Color(white: dark ? 0.93 : 0.09)
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(ink.opacity(0.55)).frame(width: 14, height: 3.5)
                    Capsule().fill(ink.opacity(0.2)).frame(width: 14, height: 3.5)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .frame(width: 16)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ground)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 2.5) {
                            Capsule().fill(ink.opacity(0.4)).frame(width: 20, height: 3)
                            Capsule().fill(ink.opacity(0.18)).frame(width: 28, height: 2.5)
                        }
                        .padding(5)
                    }
            }
            .padding(5)
            .background(wash)
        }
    }
}

/// A row of choices in a grey track, one of them lifted out in white. The
/// white slides to the one you pick rather than appearing there.
struct Segmented<Option: Hashable>: View {
    let options: [(Option, String)]
    @Binding var selection: Option
    /// True when the control has the whole width to itself, so the choices
    /// share it evenly instead of each taking only what its word needs.
    var wide = false

    @Namespace private var slide

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.0) { option, title in
                Text(title)
                    .font(.system(size: 11.5, weight: option == selection ? .medium : .regular))
                    .foregroundStyle(option == selection ? Palette.ink : Palette.muted)
                    .lineLimit(1)
                    .fixedSize(horizontal: !wide, vertical: false)
                    .frame(maxWidth: wide ? .infinity : nil)
                    .padding(.horizontal, wide ? 4 : 10)
                    .padding(.vertical, 5)
                    .background {
                        if option == selection {
                            Capsule(style: .continuous)
                                .fill(Palette.ground)
                                .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                .matchedGeometryEffect(id: "chosen", in: slide)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                    .onTapGesture {
                        withAnimation(Motion.settle) { selection = option }
                    }
            }
        }
        .padding(2)
        .background(Palette.wash, in: Capsule(style: .continuous))
        .animation(Motion.settle, value: selection)
    }
}

/// On or off, in ink rather than in blue.
struct Switch: View {
    @Binding var on: Bool

    var body: some View {
        Capsule(style: .continuous)
            .fill(on ? Palette.ink : Palette.faint)
            .frame(width: 30, height: 18)
            .overlay(alignment: on ? .trailing : .leading) {
                Circle()
                    .fill(Palette.ground)
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                    .padding(2)
            }
            .contentShape(Capsule(style: .continuous))
            .onTapGesture { withAnimation(Motion.settle) { on.toggle() } }
            .animation(Motion.settle, value: on)
    }
}

/// A value moved one stop at a time: − and + either side of it, in the same
/// outlined capsule as a pill. Pressing the value itself takes it home.
struct Steps: View {
    let stops: [Double]
    @Binding var value: Double
    let home: Double
    let label: (Double) -> String

    /// The nearest stop either way — a value between stops, from before
    /// there were stops, still moves to a round one.
    private var below: Double? { stops.last { $0 < value - 0.001 } }
    private var above: Double? { stops.first { $0 > value + 0.001 } }

    var body: some View {
        HStack(spacing: 0) {
            Step(icon: "minus", to: below) { value = $0 }
            Button { value = home } label: {
                Text(label(value))
                    .font(.system(size: 11.5))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("返回\(label(home))")
            Step(icon: "plus", to: above) { value = $0 }
        }
        .padding(.horizontal, 2)
        .frame(height: 24)
        .background(Palette.ground, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private struct Step: View {
        let icon: String
        let to: Double?
        let act: (Double) -> Void
        @State private var hovering = false

        var body: some View {
            Button { if let to { act(to) } } label: {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(to == nil ? Palette.faint : Palette.ink)
                    .frame(width: 20, height: 20)
                    .background(hovering && to != nil ? Palette.hover : .clear, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(to == nil)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}

/// A small capsule that does one thing. Outlined by default; filled in ink
/// when it is the thing you came here to press.
struct Pill: View {
    let title: String
    var filled = false
    var tint: Color = Palette.ink
    let action: () -> Void

    @State private var hovering = false

    init(_ title: String, filled: Bool = false, tint: Color = Palette.ink, action: @escaping () -> Void) {
        self.title = title
        self.filled = filled
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5))
                .foregroundStyle(filled ? Palette.ground : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(filled ? Palette.ink : (hovering ? Palette.hover : Palette.ground), in: Capsule(style: .continuous))
                .overlay(Capsule(style: .continuous).strokeBorder(filled ? .clear : Palette.hairline, lineWidth: 1))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Motion.quick, value: hovering)
    }
}

/// Settings › Privacy: the sites allowed to send notifications, each with a
/// way to take it back.
private struct NotificationSites: View {
    @ObservedObject private var notifications = SiteNotifications.shared

    var body: some View {
        let sites = SiteNotifications.allowed
        if !sites.isEmpty {
            ForEach(sites, id: \.self) { site in
                Rule()
                Line(URL(string: site).map(SiteCard.site) ?? site, "可发送通知") {
                    Pill("Remove") { SiteNotifications.forget(site) }
                }
            }
        }
    }
}

/// The coding agents you said to always allow (AgentTrust), each with who
/// signed the program that starts it and when it was last let in, and
/// Forget. Under "Let coding agents use Search".
private struct RememberedAgents: View {
    @ObservedObject private var trust = AgentTrust.shared

    var body: some View {
        ForEach(trust.remembered) { entry in
            Rule()
            SettingRow(icon: "checkmark.shield", title: entry.client,
                       detail: (entry.suspended == true ? "停用后曾再次请求" : "无需询问即允许")
                           + " · signed by \(entry.signer) · last used \(Self.when(entry.used)) · until \(Self.day(entry.expires))",
                       more: entry.path.isEmpty ? nil : "由 \((entry.path as NSString).lastPathComponent)（\(entry.identifier)，团队 \(entry.team)）启动，上次路径为 \(entry.path)。仅在该程序仍通过代码签名验证且自称为“\(entry.client)”时放行。") {
                Pill("Forget") { trust.forget(entry.id) }
            }
        }
    }

    private static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private static func when(_ date: Date) -> String {
        let format = RelativeDateTimeFormatter()
        format.unitsStyle = .full
        return Date().timeIntervalSince(date) < 60 ? "刚刚" : format.localizedString(for: date, relativeTo: Date())
    }
}
