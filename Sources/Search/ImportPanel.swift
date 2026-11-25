import SwiftUI

/// Bringing things over from another browser, all in one place: which
/// browser, which of its profiles, and what of it. Opened from Settings ›
/// Passwords and from Bring in… in Bookmarks and Passwords; the Welcome has
/// the short version of it. From Settings › Extensions it opens on the
/// extensions alone.
///
/// What each browser holds is counted as the sheet opens, off the main
/// thread and from its files alone — no key is asked for and nothing is
/// decrypted, so nothing prompts until Bring them in is pressed. Then macOS
/// asks once for that browser's key, if it keeps one.
struct ImportPanel: View {
    @ObservedObject var browser: Browser

    @State private var sources: [ImportSource] = []
    @State private var unreadable: [Chromium.Unavailable] = []
    @State private var folderError: String?
    @State private var looking = true
    @State private var pick: ImportSource?
    /// Each browser's profiles, and the one used most recently.
    @State private var profiles: [String: [ImportSource.Profile]] = [:]
    @State private var usual: [String: String] = [:]
    /// The profile chosen for a browser, where it isn't the usual one:
    /// a folder's name, or "" for all of them.
    @State private var chosen: [String: String] = [:]
    @State private var previews: [String: ImportSource.Preview] = [:]

    @State private var wantsPasswords = true
    @State private var wantsBookmarks = true
    @State private var wantsHistory = true
    @State private var wantsExtensions = false
    /// A browser's open tabs and tab groups (see takeSession).
    /// Off unless asked for.
    @State private var wantsTabs = false
    /// What came from this browser before goes, and its bookmarks come
    /// fresh. Off unless asked for; passwords are never taken out.
    @State private var replaceBookmarks = false
    /// Arc's or Zen's spaces, their pinned tabs, and Arc's favourites or
    /// Zen's Essentials (see takeArc).
    @State private var wantsArc = true
    /// How many spaces and pinned things Arc or Zen has, by browser and profile.
    @State private var arcCounts: [String: (spaces: Int, pinned: Int)] = [:]
    /// Opened for the extensions: the first browser counted with some is
    /// picked, until you pick one yourself.
    @State private var forExtensions = false
    @State private var bringing = false
    @State private var brought: [Said]?
    /// Whether that import left any bookmarks behind, which is what the
    /// offer to show the bar is for.
    @State private var marksLanded = false
    /// The steps for exporting from Safari, shown when asked.
    @State private var safariSteps = false
    /// Arc's spaces and pins came over in this import: Set Up Like Arc is
    /// offered under what came, unless it already is (LikeArc).
    @State private var arcLanded = false
    /// What Set Up Like Arc turned on from here, for its line and Undo.
    @State private var arcSaid: String?
    @ObservedObject private var likeArc = LikeArc.shared

    struct Said: Hashable {
        let ok: Bool
        let text: String
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nothing in the other browser changes. Passwords go into your keychain.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.muted)

            if looking {
                HStack(spacing: 8) {
                    Ring(size: 10)
                    Text("Looking on this Mac…").font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            } else if sources.isEmpty {
                Card { Nothing(unreadable.isEmpty ? "这台 Mac 上未找到其他浏览器。" : "请在下方选择浏览器的数据文件夹，以允许 Search 读取。") }
            } else {
                Caption("On this Mac")
                Card {
                    ForEach(Array(sources.enumerated()), id: \.element.id) { index, source in
                        if index > 0 { Rule() }
                        Row(name: source.name, detail: detail(of: source), can: source.canBringLine, chosen: pick == source) {
                            guard !bringing else { return }
                            pick = source
                            replaceBookmarks = false
                            forExtensions = false
                            brought = nil
                        }
                    }
                }
            }

            notes

            if let source = pick {
                options(for: source)
            }
        }
    }

    var body: some View {
        Plate("Bring things over", width: 580, close: { browser.bringingIn = nil }) {
            // As tall as it needs to be, and scrolling past what the window
            // can hold: many browsers, or a small window.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }
        } foot: {
            VStack(alignment: .leading, spacing: 10) {
                if let brought {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(brought, id: \.self) { said in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: said.ok ? "checkmark" : "exclamationmark.circle")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(said.ok ? Palette.ink : Palette.muted)
                                    .frame(width: 12)
                                Text(said.text)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(said.ok ? Palette.ink : Palette.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.opacity)
                }
                if brought != nil, arcLanded, arcSaid != nil || !browser.prefs.looksLikeArc {
                    arcOffer
                        .transition(.opacity)
                }
                HStack(spacing: 8) {
                    if brought != nil {
                        Pill("Show bookmarks") { browser.lead(to: InternalPage(.bookmarks)) }
                        // The bar is off until it is asked for, and nobody asks
                        // for a row that has nothing in it. Bookmarks having just
                        // arrived is the one moment it is worth offering; the
                        // bar comes in above this page, where it is seen.
                        if marksLanded, !browser.prefs.bookmarksBar {
                            Pill("Show the bookmarks bar") {
                                withAnimation(Motion.glide) { browser.prefs.bookmarksBar = true }
                            }
                        }
                        Pill("Show passwords") { browser.lead(to: InternalPage(.passwords)) }
                    } else if let source = pick {
                        Pill(bringing ? "正在导入…" : "开始导入", filled: true) { bring(from: source) }
                            .disabled(bringing || !(wantsPasswords || wantsBookmarks || wantsHistory || (wantsExtensions && !fresh(source).isEmpty)
                                                     || (wantsArc && arcCounts[key(source, profile(of: source))] != nil)
                                                     || (wantsTabs && bringsTabs(source))))
                        if bringing { Ring(size: 10) }
                    }
                    Spacer(minLength: 8)
                    Pill("File…") { browser.importFile() }
                        .disabled(bringing)
                }
            }
        }
        .animation(Motion.settle, value: brought)
        .animation(Motion.settle, value: pick)
        .onAppear {
            if browser.bringingExtensions {
                browser.bringingExtensions = false
                forExtensions = true
                wantsExtensions = true
                wantsPasswords = false
                wantsBookmarks = false
                wantsHistory = false
            }
            look()
        }
        .onChange(of: previews) { _, _ in
            guard forExtensions, let pick, fresh(pick).isEmpty,
                  let other = sources.first(where: { !fresh($0).isEmpty }) else { return }
            self.pick = other
        }
        // Asked for again at another browser while still open.
        .onChange(of: browser.bringingIn) { _, name in
            guard !bringing, let found = sources.first(where: { $0.name == name }) else { return }
            pick = found
            brought = nil
        }
    }

    /// What Arc's side of the import will do, which depends on whether pinned
    /// rows are on: with them on, the pages Arc keeps loose become rows under
    /// the pins and the ones it filed stay tabs in a group of that folder's
    /// name, so that neither the keeping nor the folder is lost.
    private func arcDetail(_ arc: (spaces: Int, pinned: Int), _ source: ImportSource) -> String {
        let spaces = arc.spaces == 1 ? "1 个空间" : "\(arc.spaces) 个空间"
        let favourites = source.name == "Zen" ? "常用" : "favourites"
        let head = "\(spaces), \(arc.pinned) pinned — each a space here, the \(favourites) as pins"
        if browser.prefs.listsPins && browser.prefs.pinFolders {
            return head + ", its pinned pages as rows under them, in its folders as folders of rows"
        }
        return browser.prefs.listsPins
            ? head + ", its pinned pages as rows under them, and the ones it filed in a folder as tabs in a group of that name"
            : head + ", its pinned tabs asleep in it"
    }

    /// Whether Arc's own spaces are coming over: they hold its tabs, which
    /// its session file holds again, so its open tabs then stay behind.
    /// Zen's open tabs leave its pins out, so both can come.
    private func takesArc(_ source: ImportSource) -> Bool {
        wantsArc && source.sessionRepeatsSpaces && arcCounts[key(source, profile(of: source))] != nil
    }

    /// Whether the open tabs switch, on, would bring anything.
    private func bringsTabs(_ source: ImportSource) -> Bool {
        (previews[key(source, profile(of: source))]?.session.tabs ?? 0) > 0 && !takesArc(source)
    }

    /// What the open tabs side of the import will do.
    private func tabsDetail(_ preview: ImportSource.Preview?, _ source: ImportSource) -> String {
        guard let session = preview?.session, session.tabs > 0 else { return "\(source.name) 中无打开的标签页" }
        if takesArc(source) { return "它们会随 Arc 的空间一同导入；关闭该项可改为导入打开的标签页" }
        func count(_ n: Int, _ one: String) -> String { n == 1 ? "1 \(one)" : "\(n.formatted()) \(one)s" }
        let tabs = session.found > session.tabs
            ? "共 \(session.found.formatted()) 个标签页中的前 \(session.tabs.formatted()) 个" : count(session.tabs, "tab")
        let groups = session.groups.isEmpty ? "" : "，位于 \(count(session.groups.count, "group")) 中"
        if case .mozilla(let mozilla) = source, mozilla.keepsSpaces {
            return "\(tabs)\(groups) — 将以休眠状态放在此空间末尾；其固定标签页会随空间一同导入"
        }
        return "\(tabs)\(groups) — 将以休眠状态放在此空间末尾，固定标签页将保留为固定标签页"
    }

    /// Safari, and browsers on this Mac with nothing where their data should
    /// be: said by name rather than left out.
    @ViewBuilder
    private var notes: some View {
        if ImportSource.safari || !unreadable.isEmpty || folderError != nil {
            VStack(alignment: .leading, spacing: 4) {
                if ImportSource.safari {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("Safari — macOS keeps its files from other apps, so it comes over from a file it exports.")
                        Spacer(minLength: 4)
                        Pill(safariSteps ? "隐藏" : "查看方法") { withAnimation(Motion.settle) { safariSteps.toggle() } }
                    }
                    if safariSteps {
                        Text("In Safari, choose File › Export Browsing Data to File…, keep Bookmarks, History and Passwords, and save. Then press File… below and choose the ZIP it made.")
                            .foregroundStyle(Palette.muted)
                            .transition(.opacity)
                    }
                }
                ForEach(unreadable.indices, id: \.self) { index in
                    let missing = unreadable[index]
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(missing.message)
                        Spacer(minLength: 4)
                        Pill("Choose folder…") { chooseFolder(for: missing.source) }
                    }
                }
                if let folderError {
                    Text(folderError)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.faint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 2)
        }
    }

    /// macOS protects another app's data. Choosing its folder in the system
    /// panel grants this browser access without asking for Full Disk Access.
    private func chooseFolder(for source: Chromium.Source) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = source.root.deletingLastPathComponent()
        panel.message = "选择 \(source.name) 的浏览器数据文件夹"
        panel.prompt = "使用文件夹"
        panel.begin { answer in
            guard answer == .OK, let folder = panel.url else { return }
            looking = true
            DispatchQueue.global(qos: .userInitiated).async {
                var selected = source
                selected.rootOverride = folder.resolvingSymlinksInPath()
                let found = !selected.profiles.isEmpty
                DispatchQueue.main.async {
                    guard found else {
                        looking = false
                        folderError = "No browser profile was found in \(folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")). Choose the folder that contains Default or Profile 1."
                        return
                    }
                    Chromium.useForSession(folder, for: source)
                    folderError = nil
                    previews = [:]
                    profiles = [:]
                    usual = [:]
                    look()
                }
            }
        }
    }

    private func options(for source: ImportSource) -> some View {
        let preview = previews[key(source, profile(of: source))]
        let extensions = fresh(source)
        return Card {
            if case .chromium(let chromium) = source,
               let root = Chromium.chosenRoot(for: chromium.name), !Store.testing {
                Text("From \(root.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .textSelection(.enabled)
                Rule()
            }
            if let record = ImportRecords.of(source.name) {
                Line("Brought before", broughtBefore(record)) { EmptyView() }
                Rule()
            }
            if let choices = profiles[source.id], choices.count > 1 {
                Line("Profile") {
                    Picker("", selection: Binding(
                        get: { chosen[source.id] ?? usual[source.id] ?? "" },
                        set: { value in
                            chosen[source.id] = value
                            brought = nil
                            count(source)
                        }
                    )) {
                        ForEach(choices) { profile in
                            Text(profile.id == usual[source.id] ? "最近使用：\(profile.name)" : profile.name).tag(profile.id)
                        }
                        Divider()
                        Text("All profiles").tag("")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                Rule()
            }
            // A kind the browser has none of is said so, and can't be picked.
            Line("Passwords", !source.importsPasswords ? (!source.passwordsInPasswordsApp ? "不支持 \(source.name)"
                                                          : "\(source.name) 将其保存在“密码” App 中：请从该 App 导出后导入 CSV 文件") : preview?.passwords == 0 ? "\(source.name) 中无内容" : source.asksForKey
                 ? "macOS 会请求一次 \(source.name) 的钥匙串密钥"
                 : "直接从 \(source.name) 的本地文件读取（除非已设置主密码）") {
                option($wantsPasswords, none: !source.importsPasswords || preview?.passwords == 0)
            }
            Rule()
            Line("Bookmarks", preview?.bookmarks == 0 ? "\(source.name) 中无内容" : "放入“\(source.name)”文件夹；若尚无书签，则直接放在顶层") {
                option($wantsBookmarks, none: preview?.bookmarks == 0)
            }
            // Brought before: only what is new comes, unless what came from
            // it last time is to go first. An import from before this was
            // kept has nothing recorded, and nothing is guessed at.
            if wantsBookmarks, preview?.bookmarks != 0, let record = ImportRecords.of(source.name) {
                Rule()
                let recorded = !record.bookmarkIDs.isEmpty
                Line("Replace what came from \(source.name) before",
                     recorded ? "\(record.date.formatted(.dateTime.day().month())) 导入的书签将被替换，而密码只会新增"
                              : "尚未记录来自 \(source.name) 的导入——仅会导入新增内容") {
                    option($replaceBookmarks, none: !recorded)
                }
            }
            Rule()
            Line("History", preview?.places == 0 ? "\(source.name) 中无内容" : "最近 \((preview.map { $0.places } ?? 3000).formatted()) 条访问记录") {
                option($wantsHistory, none: preview?.places == 0)
            }
            // Its open tabs and tab groups, asleep at the end of this space.
            if source.readsOpenTabs {
                Rule()
                Line("Open tabs & tab groups", tabsDetail(preview, source)) {
                    option($wantsTabs, none: !bringsTabs(source))
                }
            }
            // Arc's own, or Zen's: its spaces, what is pinned in them, its
            // favourites or Essentials.
            if let arc = arcCounts[key(source, profile(of: source))], arc.spaces + arc.pinned > 0 {
                Rule()
                Line("Spaces and pinned tabs", arcDetail(arc, source)) {
                    Switch(on: $wantsArc)
                }
                // Pinned pages only keep their shape as pinned rows, and
                // those are off until asked for. This is the moment someone
                // would ask, so the sheet offers the switch here, once, rather
                // than bringing them in as tabs and leaving the setting to be
                // found afterwards.
                if wantsArc, arc.pinned > 0, !browser.prefs.listsPins {
                    Rule()
                    Line("Keep them as pinned rows",
                         "As in \(source.name): each pinned page a row with its name, under your pins. Turned on, it stays in Settings › Spaces & Pins › Pinned rows"
                         + (browser.prefs.sidebar ? "" : "；固定行将随侧边标签页一同显示")) {
                        Pill("Turn on pinned rows") {
                            withAnimation(Motion.glide) { browser.prefs.listsPins = true }
                        }
                    }
                }
                // Its folders, as folders of rows rather than tab groups:
                // offered here, the moment they would be wanted, as the rows are.
                if wantsArc, arc.pinned > 0, browser.prefs.listsPins, !browser.prefs.pinFolders {
                    Rule()
                    Line("Keep its folders as folders",
                         "As in \(source.name): each folder of pinned pages a folder of rows, nested as it was, rather than a tab group. Turned on, it stays in Settings › Spaces & Pins › Folders in pinned rows") {
                        Pill("Turn on folders") {
                            withAnimation(Motion.glide) { browser.prefs.pinFolders = true }
                        }
                    }
                }
            }
            if !extensions.isEmpty {
                Rule()
                Line("Extensions", "找到 \(extensions.count) 个——将从 Chrome 应用商店全新安装，需逐一确认") {
                    Switch(on: $wantsExtensions)
                }
            }
        }
    }

    // MARK: - counting

    private func key(_ source: ImportSource, _ profile: String?) -> String {
        "\(source.id)/\(profile ?? "")"
    }

    /// The profile to read: the one chosen, or the one used most recently;
    /// nil for all of them.
    private func profile(of source: ImportSource) -> String? {
        let id = chosen[source.id] ?? usual[source.id] ?? ""
        return id.isEmpty ? nil : id
    }

    private func detail(of source: ImportSource) -> String {
        guard let preview = previews[key(source, profile(of: source))] else { return "正在统计…" }
        func count(_ n: Int, _ one: String) -> String { n == 1 ? "1 \(one)" : "\(n.formatted()) \(one)s" }
        var parts: [String] = []
        if let choices = profiles[source.id], choices.count > 1 { parts.append("\(choices.count) profiles") }
        // What it has; a kind it has none of isn't worth a word.
        for (n, one) in [(preview.bookmarks, "bookmark"), (preview.places, "place"), (preview.passwords, "password")] where n > 0 {
            parts.append(count(n, one))
        }
        if preview.session.found > 0 { parts.append(count(preview.session.found, "打开的标签页")) }
        if let arc = arcCounts[key(source, profile(of: source))], arc.spaces > 0 {
            parts.append(count(arc.spaces, "space"))
        }
        if let record = ImportRecords.of(source.name) {
            parts.append("brought \(record.date.formatted(.dateTime.day().month()))")
        }
        return parts.isEmpty ? "没有可导入的内容" : parts.joined(separator: " · ")
    }

    /// What was brought from it before, in a line: "312 bookmarks, 1,204
    /// places and 58 passwords, 27 Sep".
    private func broughtBefore(_ record: ImportRecord) -> String {
        func count(_ n: Int, _ one: String) -> String { n == 1 ? "1 \(one)" : "\(n.formatted()) \(one)s" }
        let parts = [(record.bookmarks, "bookmark"), (record.places, "place"), (record.passwords, "password"),
                     (record.spaces ?? 0, "space"), (record.pinned ?? 0, "固定标签页")]
            .filter { $0.0 > 0 }.map { count($0.0, $0.1) }
        let what = parts.isEmpty ? "没有新内容" : ListFormatter.localizedString(byJoining: parts)
        return "\(what)，\(record.date.formatted(.dateTime.day().month()))"
    }

    /// A kind's switch; off and out of reach when there is none of it.
    @ViewBuilder
    private func option(_ on: Binding<Bool>, none: Bool) -> some View {
        if none {
            Switch(on: .constant(false)).disabled(true).opacity(0.4)
        } else {
            Switch(on: on)
        }
    }

    /// The store extensions it has that aren't here already.
    private func fresh(_ source: ImportSource) -> [String] {
        guard #available(macOS 15.4, *), let preview = previews[key(source, profile(of: source))] else { return [] }
        let have = Set(Extensions.shared.installed.map(\.id))
        return preview.extensions.filter { !have.contains($0) }
    }

    /// Every browser on this Mac, its profiles and what each holds, found
    /// off the main thread.
    private func look() {
        let wanted = browser.bringingIn ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
            let found = ImportSource.installed()
            let missing = Chromium.unreadable()
            let lists = found.map { ($0.id, $0.profiles, $0.usual) }
            DispatchQueue.main.async {
                sources = found
                unreadable = missing
                for (id, list, most) in lists {
                    profiles[id] = list
                    usual[id] = most
                }
                pick = found.first { $0.name == wanted } ?? found.first
                looking = false
                found.forEach(count)
            }
        }
    }

    /// What a browser holds in the profile chosen for it, unless counted
    /// already.
    private func count(_ source: ImportSource) {
        let profile = profile(of: source)
        let key = key(source, profile)
        guard previews[key] == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let preview = source.preview(profile: profile)
            let arc = source.arcCounts(profile: profile)
            DispatchQueue.main.async {
                if let arc { arcCounts[key] = arc }
                previews[key] = preview
            }
        }
    }

    // MARK: - bringing

    private func bring(from source: ImportSource) {
        // This import's own answer, not the one before it in the same sheet.
        marksLanded = false
        arcLanded = false
        arcSaid = nil
        let profile = profile(of: source)
        let extensions = wantsExtensions ? fresh(source) : []
        // A kind it has none of isn't read at all: no keychain question for
        // a browser with no passwords.
        let preview = previews[key(source, profile)]
        let passwords = wantsPasswords && source.importsPasswords && preview?.passwords != 0
        let marks = wantsBookmarks && preview?.bookmarks != 0
        let places = wantsHistory && preview?.places != 0
        bringing = true
        var said: [Int: Said] = [:]
        let group = DispatchGroup()
        if passwords {
            group.enter()
            // The one moment macOS asks for the key, if the browser keeps one.
            DispatchQueue.global(qos: .userInitiated).async {
                let outcome = Result { try source.read(profile: profile) }
                DispatchQueue.main.async {
                    switch outcome {
                    case .success(let found):
                        let kept = browser.keep(found)
                        ImportRecords.note(source.name, passwords: kept)
                        let skipped = found.skipped > 0 ? "（已跳过 \(found.skipped.formatted()) 项：无网址）" : ""
                        // Ones that didn't decrypt: said, so an import that
                        // brought nothing says why rather than "0 passwords".
                        let locked = found.undecrypted > 0
                            ? " —— \(found.undecrypted.formatted()) 项无法使用 \(source.name) 的密钥解密" : ""
                        said[0] = Said(ok: kept > 0 || found.undecrypted == 0,
                                       text: (kept == 1 ? "1 个密码" : "\(kept.formatted()) 条密码") + skipped + locked)
                    case .failure(Chromium.Trouble.noPassphrase):
                        said[0] = Said(ok: false, text: "macOS didn't hand over \(source.name)'s key — allow it and try again")
                    case .failure(Mozilla.Trouble.primaryPassword):
                        said[0] = Said(ok: false, text: "\(source.name) has a primary password: export your passwords from it and bring in the CSV file")
                    case .failure:
                        said[0] = Said(ok: false, text: "No passwords readable in \(source.name)")
                    }
                    group.leave()
                }
            }
        }
        if marks {
            let (added, already, kept) = browser.takeBookmarks(from: source, profile: profile, replacing: replaceBookmarks)
            marksLanded = added + already > 0
            said[1] = kept
                ? Said(ok: false, text: "Couldn't read all of \(source.name)'s bookmarks: what came from it before was kept, \(added.formatted()) new")
                : Said(ok: true, text: added == 0 && already == 0 ? "\(source.name) 中没有书签"
                           : already == 0 ? "\(added.formatted()) 个书签"
                           : "新增 \(added.formatted()) 个书签，另有 \(already.formatted()) 个已存在")
        }
        if places {
            group.enter()
            browser.takePlaces(from: source, profile: profile) { count in
                said[2] = Said(ok: true, text: "\(count.formatted()) places")
                group.leave()
            }
        }
        if #available(macOS 15.4, *), !extensions.isEmpty {
            // Each from the store, fresh and checked, one question at a time.
            Task { for id in extensions { await Extensions.shared.install(id: id) } }
            said[3] = Said(ok: true, text: extensions.count == 1 ? "1 个扩展待确认" : "\(extensions.count) 个扩展待确认")
        }
        if wantsArc, arcCounts[key(source, profile)] != nil, let sidebar = source.arcSidebar(profile: profile) {
            let (spaces, pins, tabs) = browser.takeArc(sidebar, from: source, profile: profile)
            ImportRecords.note(source.name, spaces: spaces, pinned: pins + tabs)
            arcLanded = source.sessionRepeatsSpaces
            func count(_ n: Int, _ one: String) -> String { n == 1 ? "1 \(one)" : "\(n.formatted()) \(one)s" }
            said[4] = Said(ok: true, text: spaces + pins + tabs == 0 ? "\(source.name) 的空间和固定标签页均已存在"
                           : "\(count(spaces, "new space")), \(count(pins, "pin")), \(count(tabs, "pinned tab"))")
        }
        // From what was read when the sheet counted, not read again here.
        if wantsTabs, bringsTabs(source), let session = preview?.session {
            let got = browser.takeSession(session, from: source, profile: profile)
            func count(_ n: Int, _ one: String) -> String { n == 1 ? "1 \(one)" : "\(n.formatted()) \(one)s" }
            var parts = [count(got.tabs, "打开的标签页")]
            if got.groups > 0 { parts.append(count(got.groups, "新标签页组")) }
            if got.pins > 0 { parts.append(count(got.pins, "pin")) }
            said[5] = Said(ok: true, text: got.tabs + got.pins == 0 ? "\(source.name) 中打开的标签页均已存在"
                           : parts.joined(separator: ", "))
        }
        group.notify(queue: .main) {
            bringing = false
            brought = said.keys.sorted().compactMap { said[$0] }
        }
    }

    /// Set Up Like Arc, right after Arc's spaces came: one button, and once
    /// pressed, what it turned on with Undo.
    private var arcOffer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(arcSaid ?? "要使用左侧标签栏、固定行和 Arc 的操作习惯吗？")
                .font(.system(size: 12.5))
                .foregroundStyle(arcSaid == nil ? Palette.muted : Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if arcSaid != nil, likeArc.undoable(browser.prefs) {
                Pill("撤销") {
                    withAnimation(Motion.glide) { likeArc.undo(browser.prefs) }
                    arcSaid = nil
                }
            } else if arcSaid == nil {
                Pill("设为 Arc 风格", filled: true) {
                    arcSaid = LikeArc.said(withAnimation(Motion.glide) { likeArc.setUp(browser.prefs) })
                }
            }
        }
    }

    /// One browser to choose, and what it holds.
    private struct Row: View {
        let name: String
        let detail: String
        /// What can come from it at all (ImportSource.canBringLine).
        let can: String
        let chosen: Bool
        let pick: () -> Void
        @State private var hovering = false

        var body: some View {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(chosen ? Palette.ink : Palette.faint, lineWidth: chosen ? 4.5 : 1.2)
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.system(size: 13)).foregroundStyle(Palette.ink)
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Palette.muted).monospacedDigit()
                    Text(can).font(.system(size: 11)).foregroundStyle(Palette.faint)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(hovering ? Palette.hover : .clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: pick)
            .onHover { hovering = $0 }
            .animation(Motion.quick, value: hovering)
        }
    }
}
