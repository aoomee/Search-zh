import SwiftUI

/// The first time. Four short pages over the window, in the app's own
/// language: what this is, what to bring over, how to hold it, and whether
/// links from other apps should come here — and a fifth, until an email has
/// been given once, offering the iPhone beta and news by email (OptIn.swift).
/// Nothing is asked twice, and every page can be skipped.
///
/// The first page also holds Sync with iCloud and Handoff, on for a new
/// install (SyncDefault.swift): there, before Skip or Continue, so nobody
/// leaves without having seen them. They take effect when the welcome is
/// left, however it is; nothing goes anywhere while it is up.
struct WelcomePanel: View {
    @ObservedObject var browser: Browser
    @ObservedObject var prefs: Preferences

    @State private var page = 0
    // Sync with iCloud and Handoff, as they will be once the welcome is
    // left (SyncDefault.starts).
    @State private var syncs = SyncDefault.startsNow().sync
    @State private var handsOff = SyncDefault.startsNow().handoff
    @State private var forward = true

    // Bringing things over. Nil until one is picked, which means the first:
    // finding them looks through each browser's folders, and as an initial
    // value that ran every time the panel was made, the first window's
    // included, for a page that isn't showing yet.
    @State private var source: ImportSource?
    @State private var wantsPasswords = true
    @State private var wantsHistory = true
    @State private var wantsBookmarks = true
    @State private var bringing = false
    @State private var brought: String?

    // The default browser.
    @State private var isDefault = Links.isDefault
    @State private var asked = false

    private var importsPasswords: Bool { (source ?? ImportSource.installed().first)?.importsPasswords ?? false }

    /// Read once: the email page stays to the end once it is there, for
    /// its thanks.
    @State private var offersEmail = OptIn.offered()
    /// For pictures: the page to open at, and the email page's state.
    var startPage = 0
    var optInStart: OptInForm.Phase = .idle
    var optInEmail = ""
    @State private var began = false

    /// Set Up Like Arc from the welcome: what it turned on, for its line
    /// and Undo. Nothing changes unless it is pressed.
    @State private var arcSaid: String?
    @ObservedObject private var likeArc = LikeArc.shared

    private var pages: Int { offersEmail ? 5 : 4 }

    var body: some View {
        ZStack {
            Palette.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                ZStack {
                    switch page {
                    case 0: welcome
                    case 1: bring
                    case 2: hold
                    case 3: links
                    default: early
                    }
                }
                .frame(maxWidth: 520)
                .id(page)
                .transition(.asymmetric(
                    insertion: .offset(x: forward ? 40 : -40).combined(with: .opacity),
                    removal: .offset(x: forward ? -40 : 40).combined(with: .opacity)
                ))
                Spacer(minLength: 0)
                foot
            }
            .padding(40)
        }
        .animation(Motion.glide, value: page)
        .transition(.opacity)
        .onAppear {
            guard !began else { return }
            began = true
            page = min(startPage, pages - 1)
        }
    }

    // MARK: - the pages

    private var welcome: some View {
        VStack(spacing: 22) {
            Plate(size: 72)
            VStack(spacing: 10) {
                Text("Search")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Palette.ink)
                Text("A browser with nothing in the way. Four megabytes, the engine already in your Mac, and as little around the page as we could manage.")
                    .font(.system(size: 14.5))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 400)
            }
            devices
                .padding(.top, 10)
        }
    }

    /// Sync with iCloud and Handoff, in sight before anything starts.
    private var devices: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 14) {
                Choice("Sync with iCloud", "在你的 iPhone 和其他 Mac 上同步已打开的标签页、固定标签页、空间、书签和部分设置。通过你自己的 iCloud 端到端加密。", on: $syncs, plain: true)
                Rule(inset: 0)
                Choice("Handoff", "当前页面会显示在你的 iPhone 和 iPad 上。", on: $handsOff, plain: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.wash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("Nothing starts until you leave this welcome. Both are in Settings › General.")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: 440)
    }

    private var bring: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("导入你的数据。", "密码会存入你的钥匙串，书签会添加到菜单中，历史记录则让地址栏熟悉你常去的网站。其他浏览器中的数据不会发生任何改动。")

            let sources = ImportSource.installed()
            let unreadable = Chromium.unreadable()
            if sources.isEmpty {
                if unreadable.isEmpty {
                    Text("No other browser found on this Mac — nothing to bring.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if sources.count > 1 {
                        Segmented(
                            options: sources.map { ($0, $0.name) },
                            selection: Binding(get: { source ?? sources[0] }, set: { source = $0 })
                        )
                    } else {
                        Text("From \(sources[0].name)")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                    // What can come from it at all; spaces and open tabs
                    // are in the full sheet (File › Bring Things Over…).
                    Text("\((source ?? sources[0]).name) can bring: \((source ?? sources[0]).canBringLine.lowercased())")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                    if importsPasswords {
                        Choice("Passwords", "macOS 将请求一次该浏览器的钥匙串密钥", on: $wantsPasswords)
                    } else {
                        Text((source ?? sources[0]).passwordsInPasswordsApp
                             ? "\((source ?? sources[0]).name) 将密码存储在“密码”App 中：请先从那里导出，然后在下方导入文件。"
                             : "暂不支持从 \((source ?? sources[0]).name) 导入密码。")
                            .font(.system(size: 13)).foregroundStyle(Palette.muted)
                    }
                    Choice("Bookmarks", "包含所有文件夹，位于书签按钮下方", on: $wantsBookmarks)
                    Choice("History", "最近数千条访问记录，用于自动补全网址", on: $wantsHistory)
                }

                HStack(spacing: 12) {
                    Big(bringing ? "正在导入…" : "开始导入", filled: true) { bringAll() }
                        .disabled(bringing || brought != nil || !((importsPasswords && wantsPasswords) || wantsHistory || wantsBookmarks))
                    if bringing { Ring(size: 10) }
                    if let brought {
                        Text(brought)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                            .transition(.opacity)
                    }
                }
                .animation(Motion.settle, value: brought)
            }

            if !unreadable.isEmpty {
                Text(unreadable.map(\.message).joined(separator: "\n"))
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Safari, a browser on another Mac, one Search can't read: what
            // it exported, bookmarks, passwords or Safari's own ZIP.
            Pill("From a file another browser exported…") { browser.importFile() }
        }
    }

    private var hold: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("两种布局方式。", "标签页标题可沿侧边排列，也可横置顶部。无论哪种布局，灰色指示条都会随所选标签页滑动，随时可按 ⇧⌘S 切换。")
            HStack(spacing: 12) {
                Way(title: "边栏", sidebar: true, glyph: prefs.glyph, chosen: prefs.sidebar) {
                    withAnimation(Motion.glide) { prefs.sidebar = true }
                }
                Way(title: "标签页栏", sidebar: false, glyph: prefs.glyph, chosen: !prefs.sidebar) {
                    withAnimation(Motion.glide) { prefs.sidebar = false }
                }
            }
            HStack(spacing: 12) {
                Text("Tabs wear")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                Segmented(options: Glyph.allCases.map { ($0, $0.title) }, selection: $prefs.glyph)
            }
            arcCard
        }
    }

    /// Coming from Arc? One button for Arc's way (LikeArc), optional like
    /// everything here: Continue goes on without it.
    private var arcCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("从 Arc 迁移？")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Palette.ink)
                Text(arcSaid ?? "将标签栏放在左侧，启用空间与固定行，并沿用 Arc 的习惯：12 小时后关闭标签页、速览链接和悬浮播放视频。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if arcSaid != nil, likeArc.undoable(prefs) {
                Big("撤销") {
                    withAnimation(Motion.glide) { likeArc.undo(prefs) }
                    arcSaid = nil
                }
            } else if prefs.looksLikeArc {
                Text(arcSaid == nil ? "设为 Arc 风格" : "")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
            } else {
                Big("设为 Arc 风格") {
                    arcSaid = LikeArc.said(withAnimation(Motion.glide) { likeArc.setUp(prefs) })
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .animation(Motion.settle, value: arcSaid)
    }

    private var links: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("来自其他 App 的链接。", "在“邮件”、Slack 或 PDF 中点击链接时，macOS 会使用默认浏览器打开。你可以将 Search 设为默认。")
            HStack(spacing: 12) {
                if isDefault {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .medium))
                        Text("Search is the default browser")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                } else {
                    Big("Make Search the default", filled: true) {
                        asked = true
                        Links.becomeDefault { _ in isDefault = Links.isDefault }
                    }
                    if asked, !isDefault {
                        Text("macOS asks in its own dialog")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.faint)
                    }
                }
            }
            .animation(Motion.settle, value: isDefault)

            VStack(alignment: .leading, spacing: 8) {
                Text("A few things worth knowing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.faint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.top, 6)
                Key("⌘T", "新建标签页。输入网址或搜索词。")
                Key("⌘K", "按名称列出所有打开的标签页。")
                Key("⌘,", "设置，包含密码与更新。在其中按 ⌘F 可查找任意设置。")
                Key("⌃1", "空间：隔离标签页与登录状态。可在“设置 › 空间与固定标签页”中开启，或在此按 Arc 风格配置。")
                Key("⌥⌘N", "将页面一分为二：按住 ⌥ 点按标签页即可将其并排显示，或直接将标签页拖到页面上；按 ⌃⌘← 和 ⌃⌘→ 在两页间切换，再次按 ⌥⌘N 取消分屏。")
                Key("⌘O", "来自其他 App 的链接会在小窗口中打开；按 ⌘O 可将其保留为标签页。详见“设置 › 浏览”。")
                Key("⌘L", "输入时显示搜索引擎建议——默认关闭，可在“设置 › 浏览”中开启。")
                Key("⌘", "按住后可显示各标签页对应的 ⌘1–9 编号。详见“设置 › 标签页”。")
                Key("⌘,", "可为空白标签页设置背景墙纸——详见“设置 › 主题”。默认关闭，需手动选择。")
                Key("⌘1", "再次点按固定标签页，即可返回之前的位置。")
                Key("⇧⌘P", "在 Search 窗口中悬浮播放视频，或使用 macOS 画中画。详见“设置 › 浏览”。")
                Key("⌃-click", "在页面旁的侧边面板中使用 Claude 或 ChatGPT：右键点按标签页 › 在侧边面板中打开，或前往“显示 › 侧边面板”。")
                Key("⌘Q", "Search 可在退出前询问确认。详见“设置 › 通用”。")
                Key("⌘,", "在登录栏下方显示你的 Apple 密码——详见“设置 › 密码”。")
                if PageTranslator.available {
                    Key("⌃-click", "在这台 Mac 本地将页面翻译为你的语言，不会向外发送任何数据。右键点按页面 › 翻译页面。")
                }
                if AI.shipped {
                    Key("⌘,", "AI 页面摘要与问答——默认关闭，可在“设置 › AI”中开启。")
                }
            }
        }
    }

    /// Light, and skippable like every page: Start browsing goes on
    /// without it (OptIn.swift).
    private var early: some View {
        OptInWelcomePage(start: optInStart, startEmail: optInEmail) { url in
            finish()
            _ = browser.open(url, foreground: true)
        }
    }

    // MARK: - the bottom edge

    private var foot: some View {
        HStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(0..<pages, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Palette.ink : Palette.faint.opacity(0.6))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if page > 0 {
                Button("后退") { forward = false; page -= 1 }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            if page < pages - 1 {
                Button("跳过") { finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            Big(page < pages - 1 ? "继续" : "开始浏览", filled: true) {
                if page < pages - 1 { forward = true; page += 1 } else { finish() }
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: 520)
    }

    // MARK: - doing

    private func bringAll() {
        guard let source = source ?? ImportSource.installed().first else { return }
        // The profile used most recently, without asking: the sheet in
        // Settings › Passwords is where another is chosen.
        let profile = source.usual
        bringing = true
        var lines: [String] = []
        let group = DispatchGroup()
        if wantsPasswords && source.importsPasswords {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome = Result { try source.read(profile: profile) }
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let found):
                        let kept = browser.keep(found)
                        ImportRecords.note(source.name, passwords: kept)
                        lines.append("\(kept) passwords" + (found.undecrypted > 0 ? "（\(found.undecrypted) 项无法解密）" : ""))
                    case .failure(Chromium.Trouble.noPassphrase):
                        lines.append("passwords: macOS didn't hand over the key — allow it and try again")
                    case .failure(Mozilla.Trouble.primaryPassword):
                        lines.append("passwords: \(source.name) has a primary password — export them from it and bring in the CSV")
                    case .failure:
                        lines.append("passwords: nothing readable")
                    }
                    group.leave()
                }
            }
        }
        if wantsBookmarks {
            lines.append("\(browser.takeBookmarks(from: source, profile: profile).added) bookmarks")
        }
        if wantsHistory {
            group.enter()
            browser.takePlaces(from: source, profile: profile) { count in
                lines.append("\(count) places")
                group.leave()
            }
        }
        group.notify(queue: .main) {
            bringing = false
            brought = lines.joined(separator: " · ")
            browser.relist()
        }
    }

    private func finish() {
        SyncDefault.welcomeLeft(sync: syncs, handoff: handsOff, prefs: prefs, icloud: ICloudSync.shared)
        prefs.welcomed = true
        withAnimation(Motion.settle) { browser.welcoming = false }
    }

    private func heading(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.ink)
            Text(line)
                .font(.system(size: 14))
                .foregroundStyle(Palette.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - pieces

    /// The mark alone, at whatever height the page wants — no plate behind
    /// it, the same as everywhere else it's drawn.
    private struct Plate: View {
        let size: CGFloat
        var body: some View {
            Logomark()
                .fill(Palette.ink, style: FillStyle(eoFill: true))
                .aspectRatio(Logomark.canvas.width / Logomark.canvas.height, contentMode: .fit)
                .frame(height: size * 0.56)
        }
    }

    private struct Big: View {
        let title: String
        var filled = false
        let act: () -> Void
        @State private var hovering = false

        init(_ title: String, filled: Bool = false, act: @escaping () -> Void) {
            self.title = title
            self.filled = filled
            self.act = act
        }

        var body: some View {
            Button(action: act) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(filled ? Palette.ground : Palette.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(filled ? Palette.ink : (hovering ? Palette.hover : Palette.wash), in: Capsule(style: .continuous))
                    .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
        }
    }

    private struct Choice: View {
        let title: String
        let detail: String
        @Binding var on: Bool
        /// The line under in the darker grey, for one that must be read.
        var plain = false

        init(_ title: String, _ detail: String, on: Binding<Bool>, plain: Bool = false) {
            self.title = title
            self.detail = detail
            _on = on
            self.plain = plain
        }

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5)).foregroundStyle(Palette.ink)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(plain ? Palette.muted : Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Switch(on: $on)
            }
        }
    }

    /// One of the two ways, as a small drawing of the window.
    private struct Way: View {
        let title: String
        let sidebar: Bool
        let glyph: Glyph
        let chosen: Bool
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            Button(action: pick) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.ground)
                        if sidebar {
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Palette.faint).frame(width: 5, height: 5) } }
                                        .padding(.bottom, 4)
                                    ForEach(0..<4, id: \.self) { i in
                                        HStack(spacing: 3) {
                                            Wear(glyph: glyph, tab: i)
                                            RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Palette.wash : Palette.hover).frame(height: 8)
                                        }
                                    }
                                }
                                .padding(8)
                                .frame(width: 62)
                                Rectangle().fill(Palette.hairline).frame(width: 1)
                                Spacer()
                            }
                        } else {
                            HStack(spacing: 3) {
                                HStack(spacing: 3) { ForEach(0..<3, id: \.self) { _ in Circle().fill(Palette.faint).frame(width: 5, height: 5) } }
                                    .padding(.trailing, 6)
                                ForEach(0..<4, id: \.self) { i in
                                    HStack(spacing: 3) {
                                        Wear(glyph: glyph, tab: i)
                                        RoundedRectangle(cornerRadius: 3).fill(i == 0 ? Palette.wash : Palette.hover).frame(width: 24, height: 8)
                                    }
                                    .padding(.trailing, 3)
                                }
                            }
                            .padding(8)
                        }
                    }
                    .frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
                    Text(title)
                        .font(.system(size: 13, weight: chosen ? .medium : .regular))
                        .foregroundStyle(chosen ? Palette.ink : Palette.muted)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(chosen ? Palette.wash : (hovering ? Palette.hover : .clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(chosen ? Palette.ink.opacity(0.35) : Palette.hairline, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
            .animation(Motion.settle, value: chosen)
        }
    }

    /// What a tab wears in the two small pictures, as Tabs wear has it: a
    /// letter in a faint square, as Mark draws one, or a patch of colour
    /// where a site's own icon would be. Seen before it is chosen: letters
    /// were taken for icons that hadn't loaded (#1271).
    private struct Wear: View {
        let glyph: Glyph
        let tab: Int

        private static let letters = ["G", "M", "Y", "W"]
        private static let tints: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemOrange]

        var body: some View {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(glyph == .icons ? Color(nsColor: Wear.tints[tab]).opacity(0.7) : Palette.ink.opacity(0.06))
                .frame(width: 10, height: 10)
                .overlay {
                    if glyph == .letters {
                        Text(Wear.letters[tab])
                            .font(.system(size: 6.5, weight: .medium))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .animation(Motion.quick, value: glyph)
        }
    }

    private struct Key: View {
        let keys: String
        let what: String
        init(_ keys: String, _ what: String) { self.keys = keys; self.what = what }
        var body: some View {
            HStack(spacing: 10) {
                Text(keys)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Palette.wash, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(minWidth: 44)
                Text(what).font(.system(size: 13)).foregroundStyle(Palette.muted)
            }
        }
    }
}
