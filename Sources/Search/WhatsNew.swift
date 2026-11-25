import SwiftUI

// What's new, once, after an update.
//
// New features start off, so someone who never opens Settings never meets
// them (a reply on X). The first time a newer version opens, a small card
// shows its new switches, each with a line of what it does and the switch
// itself, and — so nothing gets lost — the switches from earlier versions
// that are still off. Nothing else: few words (Drice). Closed, it
// doesn't come back for that version. Not after a fresh install: the welcome
// is for that. Every version's notes are in Settings › About › What's New…
//
// A release edits `toggles` (its new switches, marked with its version),
// `releases` (that it has a card) and `notes` (what it brought).
//
// A few switches lead: first on every card, above that version's own, for
// as long as they are off. Sync with iCloud and Handoff do, since 22 Nov
// 2026: on for a new install (SyncDefault.swift), offered here to everyone
// who had Search before and never turned them on.

enum WhatsNew {
    /// A switch the card offers: the same setting as in Settings.
    struct Toggle {
        let title: String
        let detail: String
        /// The version it came in.
        let since: String
        let get: @MainActor (Preferences) -> Bool
        let set: @MainActor (Preferences, Bool) -> Void
        /// Whether it can do anything now: a switch that needs another one
        /// on stays off the card until it is.
        var shown: @MainActor (Preferences) -> Bool = { _ in true }
        /// First on every card while it is off, whatever its version.
        var lead = false
    }

    /// A version that has a card.
    struct Release {
        let version: String
    }

    /// Every switch worth meeting, the leading ones first, then oldest
    /// last. The card shows the leading ones still off, this version's, and
    /// the older ones still off.
    static let toggles: [Toggle] = [
        // Leading, in this order (see the top of this file).
        Toggle(title: "通过 iCloud 同步", detail: "在 iPhone 和其他 Mac 间同步你的标签页、固定标签页与空间，全程端到端加密。",
               since: "1.0.16", get: { _ in ICloudSync.shared.on },
               set: { _, on in on ? ICloudSync.shared.turnOnOrWait() : ICloudSync.shared.turnOff() },
               // Never beside the folder sync: the two would undo each other.
               shown: { _ in ICloudSync.shared.on || !Sync.shared.on }, lead: true),
        Toggle(title: "接力到 iPhone", detail: "当前页面会显示在 iPhone 和 iPad 的 App 切换器中。",
               since: "1.0.16", get: { $0.handoff }, set: { $0.handoff = $1 }, lead: true),
    ] + (AI.shipped ? [
        Toggle(title: "页面 AI", detail: "总结页面内容或直接提问。可在“设置 › AI”中选择运行方式。",
               since: "1.0.5", get: { $0.ai }, set: { $0.ai = $1 }),
    ] : []) + [
        Toggle(title: "在边栏中显示书签栏", detail: "在每个空间的边栏顶部显示书签栏。",
               since: "1.0.19", get: { $0.bookmarksInSidebar }, set: { $0.bookmarksInSidebar = $1 }),
        Toggle(title: "在窗口中央显示悬浮地址栏", detail: "与 Arc 一样，按 ⌘T 或 ⌘L 时，地址栏会显示在窗口中央略靠上的位置。",
               since: "1.0.19", get: { $0.fieldOnWindow }, set: { $0.fieldOnWindow = $1 }),
        Toggle(title: "使用鼠标滚轮时平滑滚动", detail: "与 Chrome 一样，每滚动一格都会平滑移动页面。触控板保持原有行为。",
               since: "1.0.19", get: { $0.wheelGlides }, set: { $0.wheelGlides = $1 }),
        Toggle(title: "隐藏标签栏时显示加载进度线", detail: "收起标签栏后，在页面顶部用细线显示加载进度。",
               since: "1.0.19", get: { $0.showsLoadingLine }, set: { $0.showsLoadingLine = $1 }),
        Toggle(title: "点按当前标签页以编辑网址", detail: "只编辑网址。仍可从右键菜单的“网站信息…”打开信息卡片。",
               since: "1.0.19", get: { $0.tabClickAddressOnly }, set: { $0.tabClickAddressOnly = $1 }),
        Toggle(title: "填充密码前使用触控 ID", detail: "在网页上填充已存储的密码前，使用触控 ID 或 Mac 密码验证身份。",
               since: "1.0.19", get: { $0.asksBeforeFilling }, set: { $0.asksBeforeFilling = $1 }),
        Toggle(title: "书签栏仅显示图标", detail: "每个书签仅显示网站图标，悬停时显示名称。文件夹保留名称。",
               since: "1.0.19", get: { $0.bookmarksIconsOnly }, set: { $0.bookmarksIconsOnly = $1 }),
        Toggle(title: "固定标签页上的未读数", detail: "在 WhatsApp 或 Discord 的固定标签页上以角标显示未读数。",
               since: "1.0.19", get: { $0.showsPinCounts }, set: { $0.showsPinCounts = $1 }),

        Toggle(title: "边栏按钮", detail: "位于窗口按钮旁，与 ⌘S 一样可隐藏边栏。",
               since: "1.0.18", get: { $0.foldButton }, set: { $0.foldButton = $1 }),
        Toggle(title: "缩窄为图标", detail: "将边栏拖窄即可变为一列网站图标。",
               since: "1.0.18", get: { $0.narrowsToIcons }, set: { $0.narrowsToIcons = $1 }),

        Toggle(title: "轻扫返回以关闭由链接打开的标签页", detail: "在由链接打开的页面上轻扫返回，即可关闭该标签页并回到之前的标签页。",
               since: "1.0.17", get: { $0.swipeBackCloses }, set: { $0.swipeBackCloses = $1 }),

        Toggle(title: "⌘T 查找已打开的标签页", detail: "在 ⌘T 搜索栏中输入时，优先显示匹配的已打开标签页或固定标签页。",
               since: "1.0.17", get: { $0.arcTabPopup }, set: { $0.arcTabPopup = $1 },
               shown: { $0.floatingNewTab }),
        Toggle(title: "在新标签页显示“主页”书签", detail: "将名为“Home”的书签文件夹中的网站以磁贴形式展示。",
               since: "1.0.17", get: { $0.homeGrid }, set: { $0.homeGrid = $1 }),
        Toggle(title: "每个空间单独显示按钮", detail: "所有空间都位于书签旁，一键即可切换。",
               since: "1.0.17", get: { $0.spaceButtons }, set: { $0.spaceButtons = $1 },
               shown: { $0.usesSpaces }),
        Toggle(title: "优先尝试 HTTPS", detail: "当网站支持时，自动通过 HTTPS 加载 http:// 页面。",
               since: "1.0.17", get: { $0.triesHTTPSFirst }, set: { $0.triesHTTPSFirst = $1 }),

        Toggle(title: "始终显示地址栏", detail: "始终显示完整网址，方便随时编辑。",
               since: "1.0.16", get: { $0.addressLine }, set: { $0.addressLine = $1 }),
        Toggle(title: "毛玻璃窗口", detail: "边栏和窗口边缘呈现覆盖于桌面之上的磨砂玻璃效果。",
               since: "1.0.16", get: { $0.glass }, set: { $0.glass = $1 }),
        Toggle(title: "顶部按钮", detail: "将边栏底部按钮移至返回、前进和重新载入按钮旁。",
               since: "1.0.16", get: { $0.doorsUp }, set: { $0.doorsUp = $1 }),
        Toggle(title: "询问链接在哪个空间中打开", detail: "适用于来自其他 App 的链接。",
               since: "1.0.16", get: { $0.asksSpaceForLinks }, set: { $0.asksSpaceForLinks = $1 }),
        Toggle(title: "调暗休眠标签页", detail: "休眠的标签页会变淡显示，直到你再次切换回来。",
               since: "1.0.16", get: { $0.dimsSleepingTabs }, set: { $0.dimsSleepingTabs = $1 }),
        Toggle(title: "高对比度标签页文字", detail: "标签页标题以纯黑或纯白显示。",
               since: "1.0.16", get: { $0.highContrastText }, set: { $0.highContrastText = $1 }),

        Toggle(title: "使用 ⌘1–⌘9 切换空间", detail: "与 Arc 相同：标签页快捷键移至 ⌃1–⌃9。",
               since: "1.0.15", get: { $0.spacesOnCommand }, set: { $0.spacesOnCommand = $1 },
               shown: { $0.usesSpaces }),
        Toggle(title: "在所有窗口中同步标签页", detail: "所有窗口均显示相同的已打开标签页，与 Arc 边栏一致。",
               since: "1.0.15", get: { $0.mirrorsTabs }, set: { $0.mirrorsTabs = $1 }),
        Toggle(title: "按住 ⌥ 点按链接以在分屏视图中打开", detail: "显示在正在浏览的页面旁。",
               since: "1.0.15", get: { $0.optionClickSplits }, set: { $0.optionClickSplits = $1 }),
        Toggle(title: "顶部和底部回弹效果", detail: "页面滚动至边缘时支持弹性回弹，与 Safari 一致。",
               since: "1.0.15", get: { $0.bounces }, set: { $0.bounces = $1 }),
        Toggle(title: "边栏滑入与滑出动画", detail: "为 ⌘S 和自动隐藏边栏带来顺滑的缓动滑出动画。",
               since: "1.0.15", get: { $0.slidesColumn }, set: { $0.slidesColumn = $1 }),

        Toggle(title: "自定义网站样式", detail: "“显示”菜单中的“编辑网站样式…”：为当前网站自定义 CSS，类似 Arc 的 Boosts。",
               since: "1.0.14", get: { $0.sitesStyles }, set: { $0.sitesStyles = $1 }),
        Toggle(title: "全屏时保持卡片样式", detail: "窗口占满屏幕时，页面仍保留留白与圆角。",
               since: "1.0.14", get: { $0.cardsInFullScreen }, set: { $0.cardsInFullScreen = $1 },
               shown: { $0.sidebar && $0.cards }),
        Toggle(title: "按住 ⌘ 点按固定标签页以在新标签页中打开", detail: "与 Arc 一致，或将偏离原站点的页面移入普通标签页。",
               since: "1.0.14", get: { $0.pinCommandOpensTab }, set: { $0.pinCommandOpensTab = $1 }),

        Toggle(title: "在地址栏中执行命令", detail: "输入任意菜单命令或设置名称即可执行，类似 Arc 的命令栏。",
               since: "1.0.13", get: { $0.commandBar }, set: { $0.commandBar = $1 }),
        Toggle(title: "截屏", detail: "通过“显示 › 截屏…”截取页面局部或完整长图。",
               since: "1.0.13", get: { $0.capturesPages }, set: { $0.capturesPages = $1 }),
        Toggle(title: "固定行中的文件夹", detail: "将固定行归入可折叠的文件夹，与 Arc 一致。",
               since: "1.0.13", get: { $0.pinFolders }, set: { $0.pinFolders = $1 },
               shown: { $0.listsPins }),

        Toggle(title: "将链接发送到空间", detail: "所选网站的链接将在对应空间中打开并使用其登录状态，与 Arc 一致。",
               since: "1.0.11", get: { $0.sendsLinksToSpaces }, set: { $0.sendsLinksToSpaces = $1 },
               shown: { $0.usesSpaces }),

        Toggle(title: "单窗口切换个人资料", detail: "其他个人资料的空间可在同一窗口中打开并保留各自登录状态，与 Arc 一致。",
               since: "1.0.9", get: { $0.profilesInOneWindow }, set: { $0.profilesInOneWindow = $1 }),

        Toggle(title: "关闭后返回上一标签页", detail: "关闭当前标签页后，自动回到上一个浏览的标签页，效果如同按下 ⌃Tab。",
               since: "1.0.8", get: { $0.closeGoesBack }, set: { $0.closeGoesBack = $1 }),

        Toggle(title: "你的 Apple 密码", detail: "在登录框下方直接填充 Apple“密码” App 中的账号，并自动获取 Mac 验证码。",
               since: "1.0.7", get: { $0.applePasswords }, set: { $0.applePasswords = $1 }),
        Toggle(title: "退出前询问", detail: "⌘Q asks first, so a slip doesn't close every window.",
               since: "1.0.7", get: { $0.confirmsQuit }, set: { $0.confirmsQuit = $1 }),
        Toggle(title: "按住 ⌘ 时显示标签页编号", detail: "直观查看 ⌘1–⌘9 分别对应的标签页。",
               since: "1.0.7", get: { $0.showsTabShortcuts }, set: { $0.showsTabShortcuts = $1 }),
        Toggle(title: "纯图标边栏", detail: "在侧边仅以图标显示标签页，指针悬停时不展开。",
               since: "1.0.7", get: { $0.sideIcons }, set: { $0.sideIcons = $1 }),
        Toggle(title: "连按两次 Esc 退出全屏", detail: "按一次 Esc 交给页面处理，再按一次退出全屏。",
               since: "1.0.7", get: { $0.escapeTwice }, set: { $0.escapeTwice = $1 }),

        Toggle(title: "搜索引擎建议", detail: "输入时实时显示搜索建议。输入内容将发送至搜索引擎，无痕标签页除外。",
               since: "1.0.6", get: { $0.engineSuggests }, set: { $0.engineSuggests = $1 }),
        Toggle(title: "固定标签页保留原网站", detail: "外部链接以速览打开，按 ⌘W 可将固定标签页重置回原页面，与 Arc 一致。",
               since: "1.0.6", get: { $0.pinsKeepSite }, set: { $0.pinsKeepSite = $1 }),
        Toggle(title: "自动调暗浅色页面", detail: "当 Search 处于深色外观时，自动将不支持深色模式的页面调暗。",
               since: "1.0.6", get: { $0.darkensPages }, set: { $0.darkensPages = $1 }),
        Toggle(title: "宽松标签页", detail: "边栏采用更高的行高和更大的标题字号。",
               since: "1.0.6", get: { $0.roomyTabs }, set: { $0.roomyTabs = $1 }),
        Toggle(title: "在悬浮栏中新建标签页", detail: "按 ⌘T 在当前页面上方浮出地址栏，与 Arc 一致。",
               since: "1.0.6", get: { $0.floatingNewTab }, set: { $0.floatingNewTab = $1 }),

        Toggle(title: "固定行", detail: "在方形图标下方以带标题的固定行展示固定标签页，与 Arc 一致。右键点按标签页即可固定为行。",
               since: "1.0.5", get: { $0.listsPins }, set: { $0.listsPins = $1 }),
        Toggle(title: "启动时打开全新窗口", detail: "仅保留固定标签页、标签页组和已命名标签页，不恢复上次的其他标签页。",
               since: "1.0.5", get: { $0.startsFresh }, set: { $0.startsFresh = $1 }),

        Toggle(title: "右侧边栏", detail: "The tabs down the right edge of the window.",
               since: "1.0.4", get: { $0.sidebar && $0.sidePosition == .right },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sidePosition = on ? .right : .left
               }),
        Toggle(title: "点按后才播放视频", detail: "阻止视频自动播放，即使是静音视频。",
               since: "1.0.4", get: { $0.waitsForPlay }, set: { $0.waitsForPlay = $1 }),
        Toggle(title: "始终显示下载按钮", detail: "下载按钮位于其他按钮旁，一键即可查看。",
               since: "1.0.4", get: { $0.alwaysShowsDownloads }, set: { $0.alwaysShowsDownloads = $1 }),

        Toggle(title: "空间", detail: "多组独立标签页，各自拥有独立登录状态。按 ⌃1–⌃9 切换。",
               since: "1.0.1", get: { $0.usesSpaces }, set: { $0.usesSpaces = $1 }),
        Toggle(title: "自动隐藏边栏", detail: "页面占满整个窗口，指针移至边缘时显示标签页。",
               since: "1.0.1", get: { $0.sidebar && $0.sideHides },
               set: { prefs, on in
                   if on { prefs.sidebar = true }
                   prefs.sideHides = on
               }),
        Toggle(title: "书签栏", detail: "在页面上方以单行显示书签。",
               since: "1.0.2", get: { $0.bookmarksBar }, set: { $0.bookmarksBar = $1 }),
        Toggle(title: "切换 App 时自动悬浮视频", detail: "A playing video follows you out into a small window.",
               since: "1.0.2", get: { $0.floatsAway }, set: { prefs, on in if on { prefs.floatOwn = .tabsOrApps } else { prefs.floatsAway = false } }),
        Toggle(title: "120 Hz 网页刷新率", detail: "在支持的屏幕上启用更顺滑的滚动与动画，耗电量会略有增加。",
               since: "1.0.2", get: { $0.fastPages != .never }, set: { $0.fastPages = $1 ? .onPower : .never }),
        Toggle(title: "使用鼠标中键滚动", detail: "按下鼠标滚轮并移动鼠标即可滚动页面，与 Windows 一致。",
               since: "1.0.3", get: { $0.autoScroll }, set: { $0.autoScroll = $1 }),
    ]

    static let releases: [Release] = [
        Release(version: "1.0.19"),
        Release(version: "1.0.18"),
        Release(version: "1.0.17"),
        Release(version: "1.0.16"),
        Release(version: "1.0.15"),
        Release(version: "1.0.14"),
        Release(version: "1.0.13"),
        Release(version: "1.0.12"),
        Release(version: "1.0.11"),
        Release(version: "1.0.10"),
        Release(version: "1.0.9"),
        Release(version: "1.0.8"),
        Release(version: "1.0.7"),
        Release(version: "1.0.6"),
        Release(version: "1.0.5"),
        Release(version: "1.0.4"),
    ]

    /// What a card opened now lists: first the leading switches still off,
    /// then the version's own; under their caption, the earlier ones still
    /// off.
    @MainActor static func rows(for release: Release, prefs: Preferences) -> (leading: [Toggle], own: [Toggle], earlier: [Toggle]) {
        (toggles.filter { $0.lead && !$0.get(prefs) && $0.shown(prefs) },
         toggles.filter { !$0.lead && $0.since == release.version && $0.shown(prefs) },
         toggles.filter { !$0.lead && older($0.since, than: release.version) && !$0.get(prefs) && $0.shown(prefs) })
    }

    /// This version's card, when it has one.
    static var current: Release? { releases.first { $0.version == Updater.version } }

    /// Version strings in order: 1.0.10 after 1.0.9.
    static func older(_ one: String, than other: String) -> Bool {
        let a = one.split(separator: ".").compactMap { Int($0) }
        let b = other.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x < y }
        }
        return false
    }

    private static let seenKey = "whatsnew.seen"

    /// At launch, once: whether the card is due. Not on a fresh install (the
    /// welcome is up, and this version counts as seen), nor in a test world
    /// unless the bench asks; otherwise once per version that has a card.
    @MainActor static func due(prefs: Preferences, welcoming: Bool) -> Bool {
        let store = Store.settings
        guard let current, !Store.testing else { return false }
        if welcoming {
            store.set(current.version, forKey: seenKey)
            return false
        }
        guard store.string(forKey: seenKey) != current.version else { return false }
        store.set(current.version, forKey: seenKey)
        return true
    }

    /// Search › What's New… and the About window's button (idea 968): this
    /// version's card again, exactly as after an update, switches and all.
    /// Nothing is marked: the card was already seen once.
    @MainActor static func showAgain(in browser: Browser) {
        guard current != nil else { return }
        browser.newsShowing = true
    }

    // MARK: - every version's notes

    /// What a version brought, for Settings › About › What's New…
    struct Notes {
        let version: String
        let date: String
        /// A sentence or two: what the version is about.
        let headline: String
        let new: [String]
        let better: [String]
        let fixed: [String]
    }

    /// Newest first.
    static let notes: [Notes] = [
        Notes(
            version: "1.0.19", date: "2026年11月23日",
            headline: "修复了你们反馈的问题，也带来了更多熟悉的 Arc 操作。",
            new: [
                "“设为 Arc 风格”现在也能启用 Arc 较新的操作习惯。你可以在欢迎页面或从 Arc 导入后选择它。",
                "选择“Search › 新版功能…”即可重新打开此卡片。",
                "新增“文件 › 打开文件…”、“粘贴并匹配样式”、“在无痕标签页中打开链接”、“在分屏视图中打开图像”和“在分组中新建标签页”。",
                "书签栏放不下的项目可从末端的 » 打开。书签可只显示图标；用鼠标中键或按住 ⌘ 点按文件夹可打开其中的全部书签。",
                "在“设置 › 密码”中，可要求在填充已存储的密码前使用触控 ID。",
                "固定标签页可显示未读数。在“设置 › 隐私”中，可查看各网站的摄像头、麦克风、位置和通知权限。",
                "在“设置 › 键盘与鼠标 › 快捷键”中，可为切换到上一个或下一个空间，以及切换到各个个人资料设置快捷键。",
                "在“设置 › 外观”中，可分别隐藏后退、前进、重新载入和边栏底部的各个按钮。",
                "在“设置 › 扩展”中，可添加其他 App 随附的 Safari 扩展。此功能默认关闭。",
            ],
            better: [
                "uBlock Origin Lite 现在从启动之初就能拦截内容。",
                "Chrome 网上应用店中的已安装扩展现在可获得与新安装时相同的更新。检查失败后会在一小时内重试。",
                "更多登录页面现在可以使用已存储的密码，填充过程也更加安全。",
                "在全屏窗口中，Esc 键会像在 Safari 中一样交由页面处理。",
                "启用“切换 App 时自动悬浮视频”后，视频会等到窗口离开视野才悬浮。",
                "点按“仍要继续”时，只会信任你刚查看的那份证书。",
                "扩展管理器现在可通过 chrome.management 查看已安装的扩展。",
            ],
            fixed: [
                "修复了 uBlock Origin 弹窗、Readwise Highlighter、Raindrop.io 登录、Zotero Connector 和 Claude 侧面板的问题。",
                "修复了在 Google 表格中横向轻扫或快速滚动时意外返回上一页的问题。",
                "修复了分屏时出现两排窗口按钮，以及全屏栏比 Safari 更高的问题。",
                "修复了退出全屏后视频画面变白，以及 YouTube 页面被当作下载打开的问题。",
                "提高了浅色模式下液态玻璃标签页的可见度，并修复了侧面板闪白的问题。",
                "修复了标签页很多时，地址栏获得键盘焦点会导致窗口短暂无响应的问题。",
                "修复了 Enhancer for YouTube 按钮重复出现四次，以及扩展列表在屏幕角落打开后立即关闭的问题。",
                "修复了跨空间使用画中画返回按钮、缩窄边栏后的行布局，以及标签页重命名后标题无法正确更新的问题。",
            ]
        ),
        Notes(
            version: "1.0.18", date: "2026年11月22日",
            headline: "初始即支持同步、邮件接收更新动态，以及大家反馈的问题修复。",
            new: [
                "Sync with iCloud and Handoff are on for a new install, with both switches on the welcome's first page.",
                "News by email and the Search for iPhone beta: leave your email on this card, in the welcome or in Settings › About.",
                "A sidebar button beside the window's buttons, and a sidebar that narrows to icons. Settings › Appearance › Tabs.",
            ],
            better: [
                "⌘S is smooth again with several spaces and the column made icons only.",
                "With the tabs across the top, an open group shows where it starts and ends.",
                "Buttons say the key you set for them in Settings › Shortcuts.",
            ],
            fixed: [
                "In full screen, the menu bar no longer comes down over the tabs.",
                "Selecting text in a field at the very top of a page, and Rename on a pinned square.",
                "Asking to save a password nobody typed, and YouTube previews floating as a video.",
                "Windows coming back twice, sites at .local names, and tabs showing a lone \u{2026}.",
            ]
        ),
        Notes(
            version: "1.0.17", date: "2026年11月22日",
            headline: "支持从 Zen 导入空间、新增更多可导入浏览器，以及大家反馈的问题修复。",
            new: [
                "Coming from Zen brings its spaces, pins and folders, and open tabs come over from Firefox and Zen.",
                "Eleven more browsers to come from, and Safari directly when macOS allows it.",
                "Themes for the blank tab, your Home bookmarks as tiles, and ⌘T finding your open tabs. Settings › Themes and Settings › Tabs.",
                "A split pinned as a split, one button per space, and Try HTTPS first. Settings › Spaces & Pins and Settings › Privacy.",
            ],
            better: [
                "⌘S slides the column smoothly again, as in 1.0.15.",
                "Any space can be deleted, the first one included, and profiles can be put in any order.",
                "A bookmarks folder of thousands opens at once.",
            ],
            fixed: [
                "Pinned-row folders syncing between Macs, and the history of signed-out spaces.",
                "YouTube videos held at 0:00, YouTube Music's floating player, and Reddit's promoted posts.",
                "Client certificates for company sign-ins, security keys with passkeys off, and games locking the pointer.",
                "Stylus, Monarch Money, Floccus, Similarweb and Brandsearch.",
            ]
        ),
        Notes(
            version: "1.0.16", date: "2026年11月20日",
            headline: "支持与 iPhone 同步、接力，以及两天来大家反馈的问题修复。",
            new: [
                "Sync with iCloud: open tabs, pins, spaces and bookmarks with Search on iPhone, in public beta. Settings › General.",
                "Handoff of the page in front to your iPhone and iPad. Settings › General.",
                "The address bar always in sight, a glass window, and buttons at the top. Settings › Appearance.",
                "Choose the space a link from another app opens in. Settings › Spaces & Pins.",
            ],
            better: [
                "Switching spaces is about three times quicker with many tabs.",
                "The accounts under a sign-in box answer ↓, ↑ and Return.",
                "A sideways scroll in Google Sheets scrolls the sheet instead of going back.",
            ],
            fixed: [
                "Swish and other window managers moving the window, and ⌃⌘F.",
                "Teams' Shared tab, PDFs that stopped zooming, and Zotero Connector.",
                "⌘S forgetting the hidden column, and spelling corrected with correction off.",
                "A crash on macOS 27.2.",
            ]
        ),
        Notes(
            version: "1.0.15", date: "2026年11月18日",
            headline: "空间渐变色、可用的扩展、编程智能体，以及一天来大家反馈的问题修复。",
            new: [
                "A gradient or a stronger colour for a space. The space's menu › Colour….",
                "The same tabs in every window. Settings › Tabs.",
                "⌘1–⌘9 switch spaces, as in Arc. Settings › Spaces & Pins.",
                "Email links open in Gmail, Outlook.com, Fastmail or Proton Mail. Settings › General.",
                "Choose where each extension runs: all sites, some, or on click. Settings › Extensions.",
                "Claude Code or Codex can browse in tabs of their own while you watch. Settings › About › Developer.",
            ],
            better: [
                "Pages load faster with extensions on.",
                "Spread two fingers on a peek to open it as a tab.",
                "A right-click anywhere in the tab column has a menu.",
            ],
            fixed: [
                "Eagle, Cosmos, Raindrop.io, Language Reactor and Voice-over-Translation.",
                "Signing in to X with passkeys off, and 1Password passkeys.",
                "Claude's side panel once signed in.",
                "Extensions reopening their welcome tab at every launch.",
            ]
        ),
        Notes(
            version: "1.0.14", date: "2026年11月17日",
            headline: "实时文件夹、自定义网站样式、窗口空间主题色，以及大家反馈的问题修复。",
            new: [
                "Live folders: a folder in the pinned rows that fills itself from a feed. Right-click a pinned row › New Live Folder….",
                "Your own CSS for a site, as Arc's Boosts. Turn it on in Settings › Browsing.",
                "Keep the page as a card in full screen. Settings › Appearance › Window.",
                "⌘-click on a pin opens a new tab, as in Arc. Settings › Spaces & Pins.",
            ],
            better: [
                "A space with a colour gives the window a faint wash of it.",
            ],
            fixed: [
                "⌘1–⌘9 counting a group's closed tabs.",
                "⌫ leaving the page you were typing in.",
                "Extension popups that open themselves, such as Inoreader's.",
            ]
        ),
        Notes(
            version: "1.0.13", date: "2026年11月17日",
            headline: "固定行文件夹、四页分屏视图、Mac 间同步，以及大家反馈的问题修复。",
            new: [
                "Sync your spaces, pins, bookmarks and a few settings between your Macs, through a folder they share. Settings › General.",
                "Folders in pinned rows, as in Arc. Settings › Spaces & Pins.",
                "Capture… in the View menu: a picture of part of a page, or all of it.",
                "Commands in the address field, as Arc's Command Bar.",
                "History › Archived Tabs: the tabs Search closed by itself, for 30 days.",
                "A colour for each space, from the space's menu.",
                "The address field from any app, with a key of your own. Settings › Keyboard & Mouse.",
            ],
            better: [
                "Split View holds up to four pages.",
                "Switching tabs shows the page sooner.",
                "A new install starts with the tabs down the side, and links from other apps in a small window.",
            ],
            fixed: [
                "⌘T opening its page in a group, from an empty tab left there.",
                "A window opened with ⌘N that the menus didn't act on.",
                "Control Panel for YouTube not saving its switches.",
                "The floating video coming back small in its tab.",
                "A link from another app bringing up the browser's window beside its small one.",
            ]
        ),
        Notes(
            version: "1.0.12", date: "2026年11月9日",
            headline: "表单自动填充联系人信息、重新支持在顶部拖动标签页，以及大家反馈的问题修复。",
            new: [
                "Your card in Contacts under a box for your name, email, phone or address, as in Safari. Turn it on in Settings › Passwords.",
                "Open All in New Tabs at the foot of each folder in the Bookmarks menu.",
            ],
            better: [
                "A tab carried off its row or column goes with the pointer.",
                "Pages with many frames load quicker with extensions such as 1Password.",
            ],
            fixed: [
                "A tab across the top that couldn't be dragged, moving the window instead, with Tabs give when pressed on.",
            ]
        ),
        Notes(
            version: "1.0.11", date: "2026年11月9日",
            headline: "将链接发送至指定空间、全局浏览器代理、多标签页窗口更流畅，以及大家反馈的问题修复。",
            new: [
                "Send links to a space, as in Arc: the sites you choose open in their space, in Settings › Spaces & Pins or a tab's right-click menu.",
                "An HTTP or SOCKS5 proxy for the whole browser, in Settings › Privacy.",
                "Bring Things Over can bring the tabs Helium, Chrome or another Chromium browser has open, with their groups.",
                "⌥-click a tab to put it beside the page in Split View.",
                "Replace a pin's page with the one it shows, from the pin's right-click menu.",
            ],
            better: [
                "Typing in the address field and swiping between spaces stay quick with many tabs open.",
                "Your site shortcuts are offered as you type, like the built-in sites.",
                "The tab column has no scroll bar, as the tabs across the top.",
                "Show how far you've read is off unless you turn it on.",
                "Passkeys and saved passwords are handled more carefully, and the sites you sign in to stay out of the Mac's log.",
            ],
            fixed: [
                "⌘-click opening a link in the same tab on some shops.",
                "The floating video flickering as it pops out of the page.",
                "Closing a window right after using it taking away its space's pins.",
                "And more, from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.10", date: "2026年11月8日",
            headline: "网站卡片内管理权限、Claude for Chrome 现可在 Search 中运行、⇧⌘T 完整恢复关闭的标签页，以及大家反馈的问题修复。",
            new: [
                "Site Permissions in the site card: camera, microphone, location and notifications, each Ask, Allow or Block.",
                "Codes from Apple's Passwords app under the box that asks for one.",
                "Choose the language pages are translated into, in Settings › Browsing.",
                "Shift-Return searches with a second engine, if you pick one in Settings › Browsing.",
                "Copy Address in a download's right-click menu.",
                "With a site put in the address field with Tab, what you searched there before, read from this Mac only.",
            ],
            better: [
                "The address field says where Return goes, and the key that raised it puts it away.",
                "⇧⌘T brings a tab back with its Back and Forward, and brings back Settings, History and the other pages of Search.",
                "Turning the blocker off for one site is a switch in the site's card.",
                "With Tabs show: Letters, a tab's letter is beside its title.",
                "⌘S slides the column at once, and keeping a bookmark no longer stalls a window with many tabs.",
                "Dragging one of several selected tabs carries them all.",
                "A space's downloads folder is one Downloads submenu in its menu.",
            ],
            fixed: [
                "Claude in Chrome's actions, which all failed with \"No tabs to group\".",
                "Discord signing you out when reloaded with the column out.",
                "A video on a TV or second display floating out when you work in another app on this screen.",
                "A tab carried past another or a Split View pair drifting away from the pointer.",
                "A closed tab's video or music playing on in the background.",
                "uBlock Origin Lite leaving GitLab and similar pages half-drawn.",
                "A waking tab shown zoomed in, and a window stuck after a video's full screen.",
                "And many more, most from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.9", date: "2026年11月4日",
            headline: "侧边面板集成 Claude、单窗口多个人资料，以及大家反馈的问题修复。",
            new: [
                "Profiles in one window, as in Arc, if you turn it on in Settings › Spaces & Pins.",
                "Downloads can open floating by its button, or in the side panel.",
                "Delete in a pin's right-click menu.",
            ],
            better: [
                "Claude in Chrome's side panel is signed in when your tabs are.",
                "Address suggestions match words anywhere in a page's title and forgive typos.",
                "⌘R reloads the page in a peek, and a link's menu starts with Open Link in New Tab.",
                "A video floats when you switch spaces, if automatic floating is on.",
            ],
            fixed: [
                "Copy Image copies at once, where a big picture took up to a minute.",
                "Google Docs and Sheets are sharp on macOS 26.3 and earlier.",
                "A pin no longer stays stuck mid-drag, and a page no longer stays shifted after a swipe back.",
                "A page that keeps crashing stops reloading itself and says so.",
                "And many more, most from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.8", date: "2026年11月2日",
            headline: "数十项大家反馈的问题修复，以及一些小改进。",
            new: [
                "Open Link in Split View, in a link's right-click menu.",
                "Close Tabs Below, beside Close Other Tabs.",
                "File › Save Page As… keeps a page as one web archive.",
                "Closing a tab can take you back to the one you were on before, if you turn it on.",
            ],
            better: [
                "Bookmarks in the address field as you type, by name or address.",
                "Links opened behind a page go after it in the order you clicked them.",
                "⌘W closes every tab picked in the column; a tab in a group is put away rather than closed.",
                "Closing the last window lets its pages sleep, as Safari and Chrome do.",
            ],
            fixed: [
                "Typing in a new tab no longer stops with a beep after the first letters.",
                "The page under a peek no longer reacts to the pointer.",
                "1Password no longer quits Search on macOS 15; Claude's and ChatGPT's side panels and Vimium C work again.",
                "Picture in picture's button takes you back to the video, and a paused full-screen video takes clicks.",
                "And many more, most from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.7", date: "2026年10月25日",
            headline: "网页式设置、个人资料、页面翻译、Apple 密码，以及无广告 YouTube。",
            new: [
                "Settings, History, Downloads, Bookmarks and Passwords open as pages in tabs of their own; Settings is sorted into sections with ⌘F to find a setting.",
                "Profiles: each keeps its own spaces, sign-ins, history and bookmarks, one per window.",
                "Translate a page on your Mac, from its right-click menu; nothing is sent anywhere.",
                "Your passwords from Apple's Passwords app, under the sign-in field.",
                "Shield blocks YouTube's ads.",
                "The tab you're on shows its site; plain http and look-alike names always show.",
                "A site in the side panel, a column of icons only, ask before quitting, tab numbers while ⌘ is held.",
                "Copy Clean Link, Fold All Groups, Move Group to Space, ⌃Tab on a key of your own, Open 2 Tabs in Split View.",
            ],
            better: [
                "Fewer switches: Split View, tab groups and more are simply there; pins keep their site by default.",
                "Drag tabs onto the pins and pins back among the tabs; small handles on the edges you resize.",
                "A call keeps its camera and sound when you switch tabs.",
                "Reading mode keeps pictures and charts and follows light and dark.",
            ],
            fixed: [
                "Saved accounts show under the sign-in field again, and only in real sign-in fields.",
                "Sites you allow get your location; links to other folders' files open.",
                "Norma's and other extensions' block pages show; an extension's rules no longer blank pages.",
                "And many more, most from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.6", date: "2026年10月24日",
            headline: "侧边面板、可按需打开已拦截的弹窗，以及一个月来大家反馈的问题修复。新功能默认关闭，更新后的卡片可按需开启。",
            new: [
                "An extension's side panel, as in Chrome: Claude's, ChatGPT's or Sider's panel opens beside the page instead of in a tab.",
                "A pop-up refused because no click asked for it says so beside the tab's title, with Open and Always Allow, as in Safari.",
                "Suggestions from your search engine as you type, never from a private tab.",
                "Extensions in private tabs, each with its own switch in Settings › Extensions.",
                "Pins go back home and keep their site, with links elsewhere in a peek; pins can sit above every space.",
                "Tabs can close themselves after a while, and chosen sites can stay awake.",
                "⇧⌘W closes the window, the mouse's side buttons change space, and media keys reach the page.",
                "New tabs at the top or the bottom, a floating ⌘T, roomier tabs, and light pages darkened in dark mode.",
                "Select several tabs with ⌘- or ⇧-click, export a page as a PDF, and Open With from the Finder.",
            ],
            better: [
                "The page as a card can be turned off, and full screen goes edge to edge.",
                "Leaving a video's full screen happens in one move.",
                "Pins in spaces you aren't in sleep and give their memory back.",
                "A bookmark opens in a tab of its own, never in a pin's place.",
                "Claude in Chrome signs in, and signs in again quietly each time Search starts.",
                "Stylus and Vimium C work.",
            ],
            fixed: [
                "A pop-up rewritten by the page that opened it is no longer offered that site's saved passwords.",
                "Sites you allow to know your location get it.",
                "Start with a fresh window keeps your tab groups and named tabs.",
                "A Gmail link opens one tab, not two.",
                "A video file opened as a page plays.",
                "Links between files on your Mac open, and links in AI chats' answers too.",
                "Saved accounts show with Split View on.",
                "Dragging a tab across the top moves the tab, not the window.",
                "And many more, most from your messages and pull requests.",
            ]
        ),
        Notes(
            version: "1.0.5", date: "2026年10月14日",
            headline: "分屏视图、固定行、通知与屏幕录制支持。新功能默认关闭，更新后的卡片可按需开启。",
            new: [
                "With the tabs down the side, the page sits in the window as a card, a little apart from the column.",
                "Split View: two tabs side by side. Drag a tab to the left or right edge of a page, choose Open in Split View in its menu, or press ⌥⌘N.",
                "Pinned rows, as in Arc: a pin can be a row with its name, under the squares, and Clear closes the tabs below.",
                "Websites can send notifications and ask for your location, as in Safari, site by site.",
                "Loom and other screen recorders work: macOS asks what to share each time, and a pill says who is recording, with Stop.",
                "Search a site straight from the address field, as in Arc: type its name, then Tab.",
                "Passkeys show under the sign-in field, beside your saved passwords.",
                "Sign-ins that ask for your name first, or for a password alone, offer your saved accounts too.",
                "Your Mac's text replacements work in pages, and Edit › Substitutions turns them, smart quotes and smart dashes on or off.",
                "Find says “3 of 17”, paints every match, and can match case or whole words.",
                "Downloads pause and resume.",
                "Open Link in New Tab leaves you where you are; hold ⌥ to go to it.",
                "Search can start with a fresh window: your pinned tabs, tab groups and named tabs, and none of last time's others.",
                "Intel Macs get a download of their own.",
            ],
            better: [
                "Search is built for size, so all of this fits in 6.8 MB, and pages that change all the time, like a chat writing its answer, stay quick.",
                "An extension's popup window opens as a small window, as in Chrome: a password manager's vault, a sign-in.",
                "Esc closes a new tab you haven't used, and words typed into a new tab wait for you.",
                "Tampermonkey installs scripts from a link, and SingleFile saves pages again.",
                "Close Group in a tab group's menu, and one ⇧⌘T brings the whole group back.",
                "Don't Float Videos Here, in a site's card.",
                "Bringing Arc over keeps its shape: pinned pages as pinned rows, its folders as named tab groups.",
                "Too many pinned extensions no longer push the column off screen.",
                "Empty a bookmark's name and it is its icon alone on the bookmarks bar.",
            ],
            fixed: [
                "A live video, on X and elsewhere, no longer jumps every few seconds.",
                "A site's icon follows the page: GitHub's in the dark, a chat's unread count, and each port of localhost its own.",
                "Pins brought over from Arc wear their icons straight away.",
                "The tabs come back after a video's full screen.",
                "A folder in the bookmarks list opens whole.",
                "Signing in with a passkey works on GitHub again.",
                "Bitwarden's passkey window, its sync and its narrow popup.",
                "Keys in games no longer make the Mac beep.",
                "History keeps localhost:3000 and localhost:4000 apart.",
                "Copy Image works on WhatsApp Web's photos.",
                "Signing in to Claude's extension finishes on claude.ai.",
                "The Bookmarks menu keeps its bookmarks while a tab's title keeps changing.",
                "Popovers keep their rounded corners on macOS 15.",
                "Security hardening from a third careful private report, and many smaller fixes.",
            ]
        ),
        Notes(
            version: "1.0.4", date: "2026年9月27日",
            headline: "多窗口支持与众多新特性。大多数新功能默认关闭，更新后的卡片可按需开启。",
            new: [
                "Several windows. ⌘N opens one with its own tabs; drag a tab out of the row, or use Move to Window in its menu, and it moves with its page as it is. Pinned tabs are the same in every window.",
                "Tab groups, and a sidebar on the right.",
                "⌃Tab shows your recent tabs as pictures, the last one first: a quick ⌃Tab goes back to the tab you were on.",
                "Your own keyboard shortcuts, in Settings › Shortcuts.",
                "Downloads show while they happen: a small circle fills beside the other buttons, and the Finder and the Dock show the progress too. The button can stay there for good.",
                "Bring things over from Firefox, Zen, Helium, Comet, Opera, Chrome's other channels and Arc, its spaces and pinned tabs included, or from an exported file.",
                "Site shortcuts: a word of your own before a search sends it to that site, like yt cats to YouTube.",
                "Bookmarks in the order you choose, folders of your own, and a card to name a bookmark as you add it.",
                "Videos can wait for a click, and every site can start at a zoom of your choice.",
                "A double-click on a pinned tab takes it back to the page it was pinned at.",
                "Hold a back or forward swipe to pick a page from history.",
            ],
            better: [
                "Scrolling asks far less of the window, and a tab still loading no longer keeps the Mac busy.",
                "Where links go, peeking at a link with a shift-click, and flicking the floating video to a corner are now on.",
                "Tab managers and other extensions see every tab, in every window.",
                "Window › Move & Resize and the Mac's tiling work with Search's window.",
                "⌘K always opens the list of your tabs, whatever the page.",
            ],
            fixed: [
                "⌘← and ⌘→ go back and forward again.",
                "Links from Notion and other apps bring Search to the front.",
                "Addresses a dev server prints, like 0.0.0.0:3000, open.",
                "The tabs you had at quit are the ones that come back.",
                "The × closes a tab in the tab bar folded away with ⌘S.",
                "1Password, Bitwarden, NordPass, Passbolt, iCloud Passwords and the Claude extension each get their fixes.",
                "And many smaller fixes.",
            ]
        ),
        Notes(
            version: "1.0.3", date: "2026年9月24日",
            headline: "安全性改进与鼠标滚轮支持。",
            new: [
                "Copying a saved password asks for Touch ID.",
            ],
            better: [
                "A mouse wheel scrolls smoothly again on x.com and pages like it.",
                "History opens at once.",
                "Music keeps playing when you switch spaces.",
                "Pop-ups need a click.",
            ],
            fixed: [
                "The holes found in this week's reviews: an extension could read files outside its own folder, and a page or an ad could open another app without asking.",
                "Bitwarden signs in to a self-hosted server, and extension popups hear what changes while they're open.",
                "A link from Mail brings Search to the front, and a full-screen video no longer goes black.",
                "Your extensions may each ask once more for their permissions at their next update.",
            ]
        ),
        Notes(
            version: "1.0.2", date: "2026年9月24日",
            headline: "通行密钥、密码管理器与 Google 支持。",
            new: [
                "A site's passkey button brings up the Mac's own passkey sheet: Touch ID, your iPhone, a security key.",
                "Search can be the Mac's default browser.",
                "Each off until you turn it on in Settings: a bookmarks bar, a peek at a link with a shift-click, the video that follows you to another app, pages at 120 Hz, and where a link goes.",
                "Mute a tab, share a page, copy a link as Markdown, the mouse's back and forward buttons, and spaces in the bar across the top.",
            ],
            better: [
                "Faster to open, and new tabs in about 10 ms.",
                "Pages see nothing of Search that Safari doesn't show them, and a saved password is offered only on its own site.",
            ],
            fixed: [
                "1Password, Bitwarden and Proton Pass.",
                "If passkeys still fail after the update, restart your Mac once.",
            ]
        ),
        Notes(
            version: "1.0.1", date: "2026年9月23日",
            headline: "首个更新，凝聚了一天来大家的回复与 Pull Request。",
            new: [
                "Each off until you turn it on in Settings: Spaces, a sidebar that hides until the pointer reaches the edge, and the search engine of your choice.",
                "⌘S folds the sidebar away, a middle-click closes a tab, a tab can be renamed, and the Web Inspector is in the View menu.",
            ],
            better: [],
            fixed: [
                "Search opens again on macOS 14.",
                "Signing in to Google no longer reloads the page over and over with iCloud Passwords installed.",
                "⌘1–⌘9 on every keyboard layout, Tab between a form's fields, dragging tabs, a double-click along the top to fill the screen, and the Mac's beep while typing.",
            ]
        ),
        Notes(
            version: "1.0", date: "2026年9月23日",
            headline: "首个版本。一款纯粹、无干扰的 Mac 浏览器。",
            new: [
                "Tabs in a row or down the side, pinned tabs that keep their place, and one field for addresses and searches.",
                "Ads blocked before they load; passwords and passkeys in your keychain.",
                "Anything on a page can be hidden; articles open in a reading mode and videos float.",
                "Chrome extensions from the Chrome Web Store, on macOS 15.4 or later.",
                "Tabs you haven't looked at for half an hour sleep and give their memory back.",
                "It runs on the engine already in macOS and weighs 2.9 MB.",
            ],
            better: [],
            fixed: []
        ),
    ]
}

/// The card: what's new in this version, its switches right there, and
/// the earlier ones still off.
struct WhatsNewCard: View {
    let release: WhatsNew.Release
    @ObservedObject var prefs: Preferences
    let close: () -> Void
    let notes: () -> Void
    /// A link from the card (the privacy page), opened in a tab.
    var open: (URL) -> Void = { NSWorkspace.shared.open($0) }
    /// For pictures: the email block's state, and whether it is offered
    /// whatever this Mac remembers.
    var optInStart: OptInForm.Phase = .idle
    var optInEmail = ""
    var optInForced: Bool? = nil

    /// The leading and earlier switches, read once as the card opens
    /// (WhatsNew.rows): one turned on here stays in the list rather than
    /// vanishing under the hand. The version's own are read as they stand.
    @State private var listed: (leading: [WhatsNew.Toggle], own: [WhatsNew.Toggle], earlier: [WhatsNew.Toggle])?
    /// Sync with iCloud's switch is its own, not a preference's.
    @ObservedObject private var icloud = ICloudSync.shared
    /// The email block (OptIn.swift), read once as the card opens: offered
    /// until an email has been given, and kept after one is, for its thanks.
    @State private var offering: Bool?
    @ObservedObject private var reach = OptIn.Reach.shared

    /// Pinned under the list, outside its scroll, so it is always in sight;
    /// left off while the Mac is offline, where a press could only fail.
    private var showsOptIn: Bool { (optInForced ?? offering ?? OptIn.offered()) && (optInForced != nil || reach.online) }

    var body: some View {
        Plate("Search \(release.version) 的新功能", width: 460, close: close) {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        rows((listed?.leading ?? []) + WhatsNew.rows(for: release, prefs: prefs).own)
                        if let earlier = listed?.earlier, !earlier.isEmpty {
                            Caption("回顾之前版本的功能")
                                .padding(.top, 6)
                            rows(earlier)
                        }
                    }
                }
                .frame(maxHeight: showsOptIn ? 360 : 470)
                .fixedSize(horizontal: false, vertical: true)
                if showsOptIn {
                    OptInBlock(source: .whatsNew, open: open, start: optInStart, startEmail: optInEmail)
                }
            }
        } foot: {
            HStack {
                Button(action: notes) {
                    Text("查看所有更新…")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                Spacer()
                Pill("关闭", filled: true, action: close)
            }
        }
        .onAppear {
            if offering == nil { offering = OptIn.offered() }
            if listed == nil { listed = WhatsNew.rows(for: release, prefs: prefs) }
        }
    }

    private func rows(_ toggles: [WhatsNew.Toggle]) -> some View {
        Card {
            ForEach(Array(toggles.enumerated()), id: \.offset) { index, toggle in
                if index > 0 { Rule() }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(toggle.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.ink)
                        Text(toggle.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Switch(on: Binding(get: { toggle.get(prefs) }, set: { toggle.set(prefs, $0) }))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }
}

/// Every version's notes, newest first: Settings › About › What's New…
struct ReleaseNotesPanel: View {
    let close: () -> Void

    var body: some View {
        Plate("新版功能", width: 560, close: close) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ForEach(WhatsNew.notes, id: \.version) { note in
                        version(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .listHeight(480)
        }
    }

    private func version(_ note: WhatsNew.Notes) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Search \(note.version)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if !note.date.isEmpty {
                    Text(note.date)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                }
            }
            Text(note.headline)
                .font(.system(size: 13))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            list("新功能", note.new)
            list("改进", note.better)
            list("问题修复", note.fixed)
        }
    }

    @ViewBuilder
    private func list(_ title: String, _ lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Palette.muted)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Palette.faint)
                        Text(line)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12.5))
                }
            }
        }
    }
}
