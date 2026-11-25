import SwiftUI

// Every line of Settings, written down once.
//
// Settings › each section draws its groups from this list, and the ⌘F
// "Find a setting" field filters the same list, so a setting can't be on a
// page and missing from the search, or the other way round. Each line says
// which keys it reads and writes (the bench's `settings` verb answers with
// them, see Tests/settings_layout.py). The controls themselves are drawn in
// Settings.swift; what a merged control does to the old keys is here, on
// Preferences, so the switch and the bench write the same thing.

/// A titled group inside a section: a small heading with its icon, then
/// its rows in one card.
struct SettingsGroup: Identifiable {
    let id: String
    let page: SettingsPanel.Page
    let title: String
    let icon: String
}

/// One row of Settings.
struct SettingsItem: Identifiable {
    enum Kind {
        /// A control on the right of the row.
        case control
        /// A control wide enough to go under the words (pictures, long
        /// segmented choices).
        case wide
        /// No control: a feature that is always there, said so plainly.
        /// Only shown by the find field.
        case note
    }

    let id: String
    let group: String
    let icon: String
    let title: String
    /// One short line, under ~90 characters.
    let detail: String
    /// The rest of the story, behind the (i).
    var more: String? = nil
    /// The defaults keys the row reads and writes.
    var keys: [String] = []
    /// Other words someone might type for it.
    var words: [String] = []
    var kind: Kind = .control
    /// The row that makes this one count. It stands at the same level as
    /// every other row, and is only there while that one makes it count
    /// (see SettingsIndex.applies).
    var parent: String? = nil
    /// Only the find field shows it (moved to a menu, or always on).
    var findOnly = false

    var page: SettingsPanel.Page { SettingsIndex.group(group)?.page ?? .general }
}

enum SettingsIndex {
    // MARK: - groups

    static let groups: [SettingsGroup] = [
        .init(id: "browser", page: .general, title: "浏览器", icon: "globe.desk"),
        .init(id: "downloads", page: .general, title: "下载", icon: "arrow.down.circle"),

        .init(id: "theme", page: .appearance, title: "浅色与深色", icon: "circle.lefthalf.filled"),
        .init(id: "window", page: .appearance, title: "窗口", icon: "macwindow"),
        .init(id: "tablook", page: .appearance, title: "标签页", icon: "textformat.size"),
        .init(id: "motion", page: .appearance, title: "动态效果", icon: "wind"),

        .init(id: "themes", page: .themes, title: "起始页背景", icon: "photo.artframe"),

        .init(id: "newtabs", page: .tabs, title: "新标签页", icon: "plus.square"),
        .init(id: "memory", page: .tabs, title: "内存", icon: "moon.zzz"),
        .init(id: "tabbar", page: .tabs, title: "标签栏中", icon: "number"),
        .init(id: "tabwindows", page: .tabs, title: "窗口", icon: "macwindow.on.rectangle"),

        .init(id: "search", page: .browsing, title: "搜索", icon: "magnifyingglass"),
        .init(id: "links", page: .browsing, title: "链接", icon: "link"),
        .init(id: "reading", page: .browsing, title: "阅读模式", icon: "doc.plaintext"),
        .init(id: "video", page: .browsing, title: "视频", icon: "play.rectangle"),
        .init(id: "pages", page: .browsing, title: "网页", icon: "doc.richtext"),

        .init(id: "arc", page: .spaces, title: "从 Arc 迁移？", icon: "arrow.down.forward.square"),
        .init(id: "spaces", page: .spaces, title: "空间与个人资料", icon: "rectangle.3.group"),
        .init(id: "pins", page: .spaces, title: "固定标签页", icon: "pin"),
        .init(id: "opening", page: .spaces, title: "打开与启动", icon: "command"),

        .init(id: "passwords", page: .passwords, title: "你的密码", icon: "key"),
        .init(id: "apple", page: .passwords, title: "Apple 密码", icon: "lock.rectangle.stack"),
        .init(id: "forms", page: .passwords, title: "自动填充表单", icon: "character.cursor.ibeam"),

        .init(id: "blocking", page: .privacy, title: "内容拦截", icon: "shield"),
        .init(id: "permissions", page: .privacy, title: "网站权限", icon: "checkmark.shield"),
        .init(id: "clear", page: .privacy, title: "清除", icon: "trash"),

        .init(id: "mouse", page: .keyboard, title: "鼠标与触控板", icon: "computermouse"),
        .init(id: "anywhere", page: .keyboard, title: "来自任意 App", icon: "macwindow.on.rectangle"),

        .init(id: "updates", page: .about, title: "更新", icon: "arrow.triangle.2.circlepath"),
        .init(id: "news", page: .about, title: "邮件资讯", icon: "envelope.open"),
        .init(id: "developer", page: .about, title: "开发者", icon: "hammer"),

        // Drawn by ExtensionsPage itself; here so the find field reaches it.
        .init(id: "extensions", page: .extensions, title: "已安装", icon: "puzzlepiece.extension"),
    ]

    static func group(_ id: String) -> SettingsGroup? { groups.first { $0.id == id } }
    static func groups(of page: SettingsPanel.Page) -> [SettingsGroup] { groups.filter { $0.page == page } }
    static func items(in group: String) -> [SettingsItem] { items.filter { $0.group == group && !$0.findOnly } }

    // MARK: - rows

    static let items: [SettingsItem] = ([
        // General
        .init(id: "general.default", group: "browser", icon: "link.badge.plus",
              title: "打开其他 App 中的链接", detail: "将 Search 设为邮件、Slack 等其他 App 打开链接的默认浏览器",
              words: ["default browser"]),
        .init(id: "mail.webmail", group: "browser", icon: "envelope",
              title: "电子邮件链接打开方式", detail: "在标签页中用 Gmail 或其他网页邮箱撰写邮件，而非邮件 App",
              more: "点按网页中的电子邮件（mailto:）链接时，将在旁边的标签页中打开网页邮箱的新邮件窗口，并自动填好收件人、主题和正文。在无痕标签页中点按也会在已登录的普通标签页中打开。设为默认后，其他 App 中的链接以及“发送反馈”也会在此打开。",
              keys: ["mail.webmail"], words: ["email", "mailto", "gmail", "mail", "outlook", "fastmail", "proton", "webmail", "compose"]),
        .init(id: "mail.default", group: "browser", icon: "envelope.badge",
              title: "让 Search 打开电子邮件链接", detail: "使其他 App 中的链接也能通过你的网页邮箱打开",
              more: "macOS 会要求你确认。如需撤销，请在“邮件 › 设置 › 通用 › 默认电子邮件阅读器”中选择其他 App。",
              words: ["email", "mailto", "gmail", "mail", "default email", "handler"], parent: "mail.webmail"),
        .init(id: "general.import", group: "browser", icon: "square.and.arrow.down.on.square",
              title: "导入数据", detail: "从其他浏览器导入书签、历史记录、密码和扩展",
              more: "从这台 Mac 上的其他浏览器或其导出的文件导入。所有数据均不会离开你的 Mac。",
              words: ["import", "chrome", "safari", "arc", "migrate"]),
        .init(id: "sync", group: "browser", icon: "arrow.triangle.2.circlepath",
              title: "与其他 Mac 同步", detail: "通过自选文件夹同步空间、固定标签页、书签和设置",
              more: "选择一个在多台 Mac 间共享的文件夹（如 iCloud 云盘或 Dropbox），并在每台 Mac 的 Search 中选择同一文件夹开启此功能。各个人资料独立同步，不会同步历史记录、密码、Cookie、登录状态或已打开的标签页。无需账号和服务器，仅在该文件夹中保存小型文件。",
              keys: ["sync.folder"], words: ["sync", "icloud", "dropbox", "other mac", "devices", "mac"]),
        .init(id: "handoff", group: "browser", icon: "iphone.and.arrow.forward",
              title: "接力至你的 iPhone 和 iPad", detail: "当前网页会像 Safari 浏览器一样出现在它们的应用切换器中",
              more: "也会出现在其他 Mac 程序坞的末端。macOS 会将网址传输至登录同一 Apple 账户且开启“接力”的设备（Mac 上位于“系统设置 › 通用 › 隔空投送与接力”）。不会同步无痕标签页或独立登录的空间。当 Search 为默认浏览器时，从 iPhone 接力过来的网页将在此打开。",
              keys: ["handoff"], words: ["handoff", "continuity", "iphone", "ipad", "devices", "app switcher", "multitasking"]),
        .init(id: "icloud", group: "browser", icon: "icloud",
              title: "通过 iCloud 同步", detail: "与你的 iPhone 同步已打开的标签页、固定标签页、空间、书签及部分设置",
              more: "通过你的 iCloud 进行端到端加密同步：iPhone 和其他 Mac 上的 Search 可查看这台 Mac 上已打开的标签页（位于“历史记录”和地址栏的“其他设备上的标签页”中），并共享固定标签页、空间、书签、搜索引擎和外观设置。绝不同步无痕标签页、历史记录、密码、Cookie 或登录状态。全新安装的 Search 在离开欢迎页后默认开启（可在欢迎页提前关闭）；已有安装则保持关闭，直到你手动开启。关闭时不会有任何数据离开这台 Mac。不能与“与其他 Mac 同步”同时开启。",
              keys: ["icloud.sync"], words: ["sync", "icloud", "iphone", "ios", "cloudkit", "other devices", "devices", "icloud tabs", "tabs on other devices", "handoff"]),
        .init(id: "icloud.erase", group: "browser", icon: "trash",
              title: "从 iCloud 删除 Search 数据", detail: "适用于所有设备。各设备本地数据保持不变，此处将关闭同步",
              words: ["icloud", "delete", "erase", "remove", "sync"], parent: "icloud"),
        .init(id: "quit.confirm", group: "browser", icon: "power",
              title: "退出前确认", detail: "按 ⌘Q 或选择“退出 Search”关闭浏览器前进行询问",
              keys: ["quit.confirm"], words: ["quit", "cmd q"]),
        .init(id: "downloads.folder", group: "downloads", icon: "folder",
              title: "保存到", detail: "", keys: ["downloads"], words: ["download folder"]),
        .init(id: "downloads.ask", group: "downloads", icon: "questionmark.folder",
              title: "每次下载前询问保存位置", detail: "每次下载都弹出存储面板",
              keys: ["downloads.ask"]),
        .init(id: "downloads.button", group: "downloads", icon: "arrow.down.to.line",
              title: "始终显示下载按钮", detail: "关闭时，仅在下载文件期间显示",
              keys: ["downloads.button"]),
        .init(id: "downloads.open", group: "downloads", icon: "tray.and.arrow.down",
              title: "打开下载", detail: "通过下载按钮、⇧⌘J 或“历史记录 › 下载”打开",
              more: "在标签页中、在下载按钮旁以悬浮卡片形式，或在网页旁的侧边面板中打开。",
              keys: ["downloads.open"], words: ["downloads window", "popover", "side panel"]),

        // Themes
        .init(id: "home.theme", group: "themes", icon: "photo.artframe",
              title: "起始页背景", detail: "装扮空白标签页：背景墙、贴纸、纯色、渐变或自选图片",
              more: "默认关闭。仅绘制一次并缓存，浏览时无额外开销，且仅在空白标签页显示。所选图片会复制到 Search 内部，不会离开你的 Mac。",
              keys: ["home.theme", "home.theme.image", "home.tuning", "home.shuffle"],
              words: ["themes", "wallpaper", "background", "mural", "painting", "scenery", "shuffle", "stickers", "gradient", "colour", "color", "new tab", "image"],
              kind: .wide),

        // Appearance
        .init(id: "look", group: "theme", icon: "circle.lefthalf.filled",
              title: "外观", detail: "浅色、深色或跟随系统外观。网页也会随之切换",
              keys: ["look"], words: ["dark mode", "light mode", "theme", "system"], kind: .wide),
        .init(id: "pages.dusk", group: "theme", icon: "moon",
              title: "将浅色网页转为深色", detail: "没有原生深色外观的网页也会自动变暗",
              more: "自带深色外观的网站会自动适配。按 ⇧⌘D 切换当前网站，按 ⌥⇧⌘D 在所有网站暂停。",
              keys: ["pages.dusk"], words: ["dark", "dusk", "night"], parent: "look"),
        .init(id: "inspector.chrome", group: "theme", icon: "paintpalette",
              title: "在网页检查器中使用 Chrome 配色",
              detail: "采用扁平标签栏以及 DevTools 的行与代码配色",
              more: "关闭时保持检查器默认外观，面板和工具仍为网页检查器原生样式。",
              keys: ["inspector.chrome"], words: ["devtools", "inspect", "console", "chrome"]),
        .init(id: "inspector.dark", group: "theme", icon: "moon.stars",
              title: "保持网页检查器为深色", detail: "即使 Search 为浅色外观，检查器仍保持深色",
              more: "关闭时跟随外观设置。开启 Chrome 配色时同样受此项控制。",
              keys: ["inspector.dark"], words: ["devtools", "inspect", "console", "dark"], parent: "look"),
        .init(id: "tabs.layout", group: "window", icon: "sidebar.left",
              title: "标签页", detail: "置于窗口顶部、作为纵列置于一侧，或仅显示图标",
              more: "“仅图标”为窄列显示各标签页图标，悬停时以提示框显示标题，指针移过时不会展开。",
              keys: ["sidebar", "sidebar.position", "sidebar.icons"],
              words: ["sidebar", "vertical tabs", "column", "left", "right", "top", "tab bar", "position",
                      "icons only", "compact", "collapsed", "narrow", "favicons"], kind: .wide),
        .init(id: "sidebar.hides", group: "window", icon: "sidebar.squares.left",
              title: "隐藏边栏直至指针移至边缘", detail: "网页铺满整个窗口；按 ⌘S 可保持标签栏展开",
              keys: ["sidebar.hides"], words: ["auto hide", "sidebar"], parent: "tabs.layout"),
        .init(id: "sidebar.slides", group: "window", icon: "rectangle.lefthalf.inset.filled.arrow.left",
              title: "边栏滑入与滑出动画", detail: "按 ⌘S 或移至窗口边缘展开与收起边栏时使用更柔和的滑动效果",
              more: "若在“系统设置 › 辅助功能 › 显示”中开启了“减弱动态效果”，边栏将改为淡入淡出。若开启“减少动画”，则会立即显示或隐藏。",
              keys: [Motion.slidesKey], words: ["animation", "animate", "smooth", "slide", "sidebar", "arc"], parent: "tabs.layout"),
        .init(id: "sidebar.foldIcons", group: "window", icon: "arrow.down.right.and.arrow.up.left",
              title: "按 ⌘S 将边栏切换为仅图标", detail: "标签页保持为窄列图标显示；再按一次 ⌘S 恢复显示标题",
              more: "Off, ⌘S hides the column and the page takes the whole window.",
              keys: ["sidebar.foldIcons"], words: ["collapse", "collapsed", "compact", "narrow", "hide sidebar", "icons only", "favicons"],
              parent: "tabs.layout"),
        .init(id: "fold.loadingLine", group: "window", icon: "slider.horizontal.below.rectangle",
              title: "隐藏标签栏时显示加载进度线", detail: "按 ⌘S 收起标签栏后，在页面顶部用细线显示加载进度",
              more: "标签栏可见时，标签页上的圆环会显示加载状态。收起标签栏后，页面顶部的细线会随加载进度延伸，加载完成后消失。",
              keys: ["fold.loadingLine"], words: ["loading", "progress", "bar", "spinner", "indicator", "hidden sidebar", "folded", "arc"]),
        .init(id: "layout.cards", group: "window", icon: "rectangle.inset.filled",
              title: "以卡片形式显示网页", detail: "网页四周留出少量边距并采用圆角",
              more: "关闭时，网页延伸至窗口边缘，边栏呈白色并带有细分割线。",
              keys: ["layout.cards"], words: ["edge to edge", "rounded", "margin"], kind: .wide, parent: "tabs.layout"),
        .init(id: "layout.cardsFullScreen", group: "window", icon: "arrow.up.left.and.arrow.down.right",
              title: "全屏时保持卡片样式", detail: "关闭时，全屏模式下网页将铺满屏幕",
              keys: ["layout.cardsFullScreen"], words: ["full screen", "fullscreen", "card", "margin", "rounded", "zen", "arc"],
              parent: "layout.cards"),
        .init(id: "toolbar.left", group: "window", icon: "arrow.left.arrow.right",
              title: "将前进、后退与刷新按钮置于左侧", detail: "位于窗口控制按钮旁、标签页之前",
              keys: ["toolbar.left"], words: ["toolbar", "buttons", "navigation"], parent: "tabs.layout"),
        .init(id: "tabs.compact", group: "window", icon: "rectangle.compress.vertical",
              title: "紧凑标签栏", detail: "减少标签页上下留白，留出更多网页空间",
              keys: ["tabs.compact"], words: ["compact", "slim", "thin", "height", "padding", "tab bar", "toolbar"],
              parent: "tabs.layout"),
        .init(id: "address.shown", group: "window", icon: "link",
              title: "始终显示地址栏", detail: "显示完整网页地址以便直接输入",
              keys: ["address.shown"], words: ["address bar", "url", "location", "url bar", "omnibox", "full address"]),
        .init(id: "address.width", group: "window", icon: "arrow.left.and.right",
              title: "地址栏宽度", detail: "位于顶部标签栏左侧",
              keys: ["address.width"], words: ["address bar", "url", "width", "wide"], parent: "address.shown"),
        .init(id: "window.glass", group: "window", icon: "square.on.square.intersection.dashed",
              title: "玻璃效果", detail: "窗口后方的内容会经模糊后透出标签栏与边框",
              more: "类似 Arc 和 Zen 的效果。玻璃会采用空间配色；透明度和颗粒感可在空间菜单 › 颜色…中调整。全屏模式下不生效。",
              keys: ["window.glass"], words: ["glass", "translucent", "transparent", "blur", "frosted", "vibrancy", "see through", "arc", "zen"]),
        .init(id: "window.glass.style", group: "window", icon: "drop",
              title: "玻璃样式", detail: "磨砂玻璃或 Mac 的液态玻璃",
              keys: ["window.glass.style"], words: ["liquid glass", "liquid", "frosted", "glass", "tahoe"], parent: "window.glass"),
        .init(id: "window.glass.clear", group: "window", icon: "circle.lefthalf.filled",
              title: "透明度", detail: "从空间着色玻璃到透明玻璃",
              keys: ["window.glass.clear"], words: ["transparency", "tint", "opacity", "glass"], parent: "window.glass"),
        .init(id: "window.glass.grain", group: "window", icon: "circle.dotted",
              title: "颗粒感", detail: "在玻璃上叠加一层静态噪点",
              keys: ["window.glass.grain"], words: ["grain", "noise", "texture", "glass"], parent: "window.glass"),
        .init(id: "tabs.liquid", group: "tablook", icon: "drop.halffull",
              title: "液态玻璃标签页", detail: "当前标签页呈现可滑动、延展并回弹的液态玻璃质感",
              more: "滑过其他标签页时会产生折射变形。固定标签页和分屏网页保持灰色。开启“减弱动态效果”时会直接切换至所选标签页。",
              keys: ["tabs.liquid"], words: ["liquid glass", "liquid", "glass", "active tab", "selected tab", "animation", "wobble"]),
        .init(id: "sidebar.roomy", group: "tablook", icon: "textformat.size.larger",
              title: "宽松标签页", detail: "在边栏中使用更高的行高和更大的标题字号",
              keys: ["sidebar.roomy"], words: ["bigger", "larger", "text size", "accessibility"], parent: "tabs.layout"),
        .init(id: "sidebar.doorsUp", group: "tablook", icon: "rectangle.topthird.inset.filled",
              title: "顶部按钮", detail: "空间允许时，将书签、扩展和下载按钮置于前进、后退与刷新旁",
              keys: ["sidebar.doorsUp"], words: ["minimal", "toolbar", "footer", "bottom", "icons", "clean"], parent: "tabs.layout"),
        .init(id: "helm.shown", group: "tablook", icon: "arrow.left.arrow.right",
              title: "后退、前进和重新载入", detail: "取消勾选平时用快捷键操作的按钮，为标签页留出更多空间",
              more: "无论显示哪些按钮，⌘[、⌘] 和 ⌘R 均可使用。标签栏在边栏时，按钮位于窗口控制按钮旁；标签栏在顶部时，按钮位于该行末端。",
              keys: ["helm.back.hidden", "helm.forward.hidden", "helm.reload.hidden"],
              words: ["toolbar", "buttons", "navigation", "hide", "back", "forward", "reload", "minimal", "clean"], kind: .wide),
        .init(id: "foot.shown", group: "tablook", icon: "square.grid.3x1.below.line.grid.1x2",
              title: "边栏底部的按钮", detail: "取消勾选即可隐藏扩展、书签或个人资料按钮",
              more: "使用顶部标签栏时，这些按钮位于该行末端。固定的扩展会保留各自的按钮；你仍可从菜单打开“书签”，或前往“设置 › 扩展”。",
              keys: ["foot.extensions.hidden", "foot.bookmarks.hidden", "foot.profile.hidden"],
              words: ["toolbar", "buttons", "footer", "bottom", "hide", "extensions", "puzzle", "bookmarks", "profile", "customise", "customize", "minimal", "clean"], kind: .wide),
        .init(id: "sidebar.foldButton", group: "tablook", icon: "sidebar.left",
              title: "边栏按钮", detail: "位于窗口控制按钮旁，可像 ⌘S 一样隐藏边栏",
              more: "边栏隐藏时，按 ⌘S 或将指针移至窗口边缘可呼出，再点按按钮即可保持展开。",
              keys: ["sidebar.foldButton"], words: ["hide sidebar", "collapse", "toggle", "fold", "traffic lights", "safari", "arc"], parent: "tabs.layout"),
        .init(id: "sidebar.narrowIcons", group: "tablook", icon: "rectangle.leftthird.inset.filled",
              title: "缩窄为图标", detail: "边栏拖窄至不足 200 点时，自动变为网站图标与按钮条",
              more: "图标条会保留空间配色，并按标签页设置显示首字母或图标。前进、后退与刷新仍可通过快捷键使用。拉宽边缘或按 ⌘S 即可恢复标题。",
              keys: ["sidebar.narrowIcons"], words: ["collapse", "collapsed", "compact", "narrow", "thin", "strip", "icons only", "auto"], parent: "tabs.layout"),
        .init(id: "sidebar.player", group: "tablook", icon: "play.circle",
              title: "其他标签页中的播放内容", detail: "显示在边栏底部，可随时暂停、恢复播放或跳转至该标签页",
              more: "当你浏览其他标签页时，正在播放音频的标签页会显示在边栏底部上方。",
              keys: ["sidebar.player"], words: ["media", "music", "now playing", "pause", "player", "sound", "audio"], parent: "tabs.layout"),
        .init(id: "glyph", group: "tablook", icon: "app",
              title: "标签页图标", detail: "显示首字母或网站图标",
              more: "显示在标题旁以及固定标签页方块上。",
              keys: ["glyph"], words: ["favicon", "icons", "letters"]),
        .init(id: "tabs.highContrast", group: "tablook", icon: "bold",
              title: "高对比度文本", detail: "标签页标题使用纯黑或纯白色，而非柔和灰色",
              keys: ["tabs.highContrast"], words: ["contrast", "accessibility", "bold", "readable", "black", "white"]),
        .init(id: "tabs.reading", group: "tablook", icon: "text.line.first.and.arrowtriangle.forward",
              title: "显示阅读进度", detail: "向下滚动时，当前标签页背景会随进度填充灰色",
              keys: ["tabs.reading"], words: ["progress", "scroll"]),
        .init(id: "tabs.pinCounts", group: "tablook", icon: "app.badge",
              title: "显示固定标签页的未读数", detail: "从页面标题读取未读数，并以角标显示在固定标签页图标上",
              keys: ["tabs.pinCounts"], words: ["badge", "unread", "count", "messages", "notifications", "pinned", "whatsapp"]),
        .init(id: "tabs.give", group: "tablook", icon: "hand.point.up.left",
              title: "按压标签页时的下沉反馈", detail: "点按时标签页轻微下沉，类似 Arc 的手感",
              keys: ["tabs.give"], words: ["press", "animation", "bounce"]),
        .init(id: "bookmarks.bar", group: "tablook", icon: "bookmark",
              title: "显示书签栏", detail: "在网页上方以横排显示你的书签",
              keys: ["bookmarks.bar"], words: ["favorites bar"]),
        .init(id: "bookmarks.side", group: "tablook", icon: "list.bullet.rectangle",
              title: "在边栏中显示书签栏", detail: "将每个空间的书签栏从页面上方移至边栏顶部",
              more: "书签栏中的每个书签和文件夹各占一行，排列在固定行之前。点按文件夹时，会像在书签栏上一样打开菜单。",
              keys: ["bookmarks.side"], words: ["favorites bar", "bookmarks toolbar", "sidebar", "column", "folders"],
              parent: "bookmarks.bar"),
        .init(id: "bookmarks.iconsOnly", group: "tablook", icon: "square.grid.2x2",
              title: "书签栏仅显示图标", detail: "每个书签仅显示网站图标，悬停时显示名称",
              more: "文件夹保留名称。已清空名称的书签会继续只显示图标。",
              keys: ["bookmarks.iconsOnly"], words: ["favorites bar", "bookmarks toolbar", "favicons", "compact", "icon only", "names", "titles"],
              parent: "bookmarks.bar"),
        .init(id: "motion.light", group: "motion", icon: "leaf",
              title: "在低电量模式下节能", detail: "节能或机身发热时简化动态效果；低电量模式下闲置标签页更快休眠",
              more: "在低电量模式或 Mac 发热时生效，网页内容本身不受影响。",
              keys: [Motion.lightKey], words: ["battery", "animations", "motion"]),
        .init(id: "motion.instant", group: "motion", icon: "bolt",
              title: "减少动画", detail: "切换标签页、空间和面板时立即完成，无滑动或淡入淡出效果",
              more: "仅对 Search 生效，不受“系统设置”中“减弱动态效果”的影响。按 ⌘1–⌘9 选中的标签页和网页会立即呈现。",
              keys: [Motion.instantKey], words: ["animations", "motion", "instant", "faster", "reduce motion", "transitions"]),

        // Tabs
        .init(id: "tabs.newPlace", group: "newtabs", icon: "arrow.right.to.line",
              title: "新标签页位置", detail: "链接或按 ⌘T 新建的标签页在标签栏中的打开位置",
              more: "“当前标签页之后”会将 ⌘-点按的链接放在当前页紧邻右侧；按 ⌘T 新建的标签页及前台打开的链接位于末尾。固定标签页始终居前，标签页组内的链接仍留在组内。",
              keys: ["tabs.newPlace"], words: ["new tab", "order"]),
        .init(id: "tabs.frontBeside", group: "newtabs", icon: "arrow.turn.down.right",
              title: "前台打开的链接紧邻来源网页", detail: "在新标签页中打开的链接会放在来源标签页之后",
              more: "在来源页与新打开的标签页之间切换时，按点按顺序依次排列（与 ⌘-点按相同）。切换到其他任意标签页后，下次将重新从来源页后方排起。",
              keys: ["tabs.frontBeside"], words: ["target blank", "new tab", "order", "next to", "opener", "link"], parent: "tabs.newPlace"),
        .init(id: "tabs.newAfterLast", group: "newtabs", icon: "plus.rectangle.on.rectangle",
              title: "关闭最后一个标签页时保留新标签页", detail: "否则将切换至固定标签页",
              keys: ["tabs.newAfterLast"], words: ["last tab"]),
        .init(id: "tabs.closeGoesBack", group: "newtabs", icon: "arrow.uturn.backward",
              title: "关闭标签页后返回上一个查看的标签页", detail: "否则将切换至相邻标签页",
              more: "返回当前空间中上次查看的标签页（与 ⌃Tab 相同）。分屏视图的另一侧优先保留。",
              keys: ["tabs.closeGoesBack"], words: ["close", "previous tab", "recent"]),
        .init(id: "tabs.swipeBackCloses", group: "newtabs", icon: "xmark.circle",
              title: "轻扫返回以关闭由链接打开的标签页", detail: "返回先前的标签页，与 Safari 和 Arc 一致",
              more: "在由链接新开且无后退记录的标签页中，轻扫返回会显示关闭图标并关闭该标签页，随后返回上次查看的标签页。标签页内已浏览的页面仍按常规后退。仅支持轻扫手势，鼠标后退键在此不生效。",
              keys: ["tabs.swipeBackCloses"], words: ["swipe", "back", "close", "target blank", "new tab", "opener", "gesture", "link"]),
        .init(id: "home.grid", group: "newtabs", icon: "square.grid.4x3.fill",
              title: "在新标签页显示“主页”书签", detail: "在地址栏下方显示名为 Home 的书签文件夹中的网站",
              more: "在“书签”中创建名为 Home 的文件夹并添加网站：空白标签页会按顺序以带名称的磁贴展示其中最多 16 个网站。",
              keys: ["home.grid"], words: ["home", "home page", "start page", "new tab", "speed dial", "favorites"]),
        .init(id: "tabs.undoReopens", group: "newtabs", icon: "arrow.uturn.backward.circle",
              title: "按 ⌘Z 重新打开已关闭的标签页", detail: "关闭后立即按 ⌘Z 即可恢复，效果同 ⇧⌘T",
              more: "仅当关闭标签页为最近一次操作时生效：输入或点按其他内容后，⌘Z 恢复常规撤销功能。文档、绘图等自身使用 ⌘Z 的网页不受影响。",
              keys: ["tabs.undoReopens"], words: ["undo", "reopen", "closed tab", "cmd z", "restore"]),
        .init(id: "tabs.switcherBehindFirst", group: "newtabs", icon: "rectangle.stack",
              title: "按 ⌃Tab 切换至后台打开的链接", detail: "否则快速按 ⌃Tab 会返回之前所在的标签页",
              more: "通过 ⌘-点按、中键点按或“在新标签页中打开链接”打开的页面会在 ⌃Tab 切换器中紧随当前页排列（最新优先）。关闭时则排在上一个浏览的标签页之后。",
              keys: ["tabs.switcherBehindFirst"], words: ["ctrl tab", "switcher", "background", "recent", "new tab"]),
        .init(id: "tabs.switcherLeavesOutPins", group: "newtabs", icon: "pin.slash",
              title: "⌃Tab 切换器不显示固定标签页", detail: "否则固定标签页会与普通标签页一同显示",
              more: "开启时，固定标签页留在原位，不出现在 ⌃Tab 切换器网格中。关闭时，切换器会包含处于活动或前台状态的固定标签页。",
              keys: ["tabs.switcherLeavesOutPins"], words: ["ctrl tab", "switcher", "pins", "pinned", "exclude"]),
        .init(id: "tabs.lazy", group: "newtabs", icon: "hourglass",
              title: "切换至后台标签页时再加载", detail: "后台打开的链接将等到你切换过去时才开始加载",
              more: "适用于 ⌘-点按、中键点按或从其他 App 批量打开的链接。⇧⌘-点按仍会立即跳转并加载。",
              keys: ["tabs.lazy"], words: ["lazy", "background"]),
        .init(id: "tabs.popupWindows", group: "newtabs", icon: "macwindow.on.rectangle",
              title: "在独立小窗口中打开指定尺寸的弹窗", detail: "网站请求自定义尺寸窗口时以小窗口打开，而非标签页",
              more: "通话、登录或聊天等请求特定尺寸的窗口会像 Safari 一样以小窗口打开，弹窗拦截仍然有效。",
              keys: ["tabs.popupWindows"], words: ["popup", "pop-up", "window"]),
        .init(id: "tabs.sleep", group: "memory", icon: "moon.zzz",
              title: "休眠未使用的标签页", detail: "休眠的标签页会释放网页内存，返回时恢复到离开前的位置",
              more: "固定标签页、播放音频、通话及含输入内容的标签页不会休眠。右键点按网站卡片可设为保持唤醒。",
              keys: ["tabs.sleep", SleepPace.key], words: ["memory", "discard", "suspend", "ram"], kind: .wide),
        .init(id: "tabs.sleep.dim", group: "memory", icon: "moon",
              title: "调暗休眠标签页", detail: "休眠标签页的标题和图标会变暗，直至重新切换过去",
              keys: ["tabs.sleep.dim"], words: ["sleep", "dim", "fade", "inactive", "suspend"]),
        .init(id: "tabs.close.after", group: "memory", icon: "timer",
              title: "自动关闭闲置标签页", detail: "固定、重命名和已分组的标签页将保留。按 ⇧⌘T 可恢复",
              more: "从上次离开该标签页起计时，Search 退出期间也会计入。无痕标签页、音频、通话及含输入内容的标签页将保留。",
              keys: ["tabs.close.after"], words: ["auto close", "archive", "clean up"]),
        .init(id: "tabs.shortcuts", group: "tabbar", icon: "command",
              title: "按住 ⌘ 时显示标签页编号", detail: "提示 ⌘1–9 各自对应的标签页",
              keys: ["tabs.shortcuts"], words: ["numbers", "shortcut"]),
        .init(id: "tabs.address", group: "tabbar", icon: "lock",
              title: "在当前标签页上显示网址", detail: "以网站域名替代标题，指针悬停时恢复显示标题",
              more: "非拉丁字符的仿冒域名将显示其真实编码，普通 http 网页会标示“不安全”。关闭时，当前标签页对这两种情况仍会予以提示。",
              keys: ["tabs.address"], words: ["url", "domain", "security", "address bar"]),
        .init(id: "tabs.clickAddressOnly", group: "tabbar", icon: "character.cursor.ibeam",
              title: "点按当前标签页时只编辑网址", detail: "网址下方不再显示网站信息卡片",
              more: "仍可从标签页菜单的“网站信息…”打开卡片。",
              keys: ["tabs.clickAddressOnly"], words: ["site card", "site information", "card", "popover", "click", "url", "edit address", "address bar"]),
        .init(id: "tabs.mirror", group: "tabwindows", icon: "rectangle.on.rectangle",
              title: "在所有窗口中同步标签页", detail: "每个窗口在同一空间中显示相同的已打开标签页，如同共享固定标签页一样",
              more: "在任一窗口打开、关闭、移动、分组或重命名标签页，其他窗口都会同步更新。各窗口独立渲染网页，同一标签页可在两个窗口中同时查看。无痕标签页仅限于所在窗口，关闭某个窗口不会影响其他窗口中的标签页。",
              keys: ["tabs.mirror"], words: ["mirror", "arc", "sync tabs", "shared tabs", "every window", "all windows", "same tabs", "windows"]),

        // Browsing
        .init(id: "search.engine", group: "search", icon: "magnifyingglass",
              title: "默认搜索引擎", detail: "非网址内容将发送到此处进行搜索",
              keys: ["search.engine", "search.custom"], words: ["google", "duckduckgo", "engine", "kagi", "bing"]),
        .init(id: "search.shift", group: "search", icon: "shift",
              title: "按 Shift-Return 使用的搜索引擎", detail: "关闭时，Shift-Return 与 Return 效果相同",
              more: "一键调用第二个搜索引擎：按 Return 使用默认引擎，按 Shift-Return 则将输入内容原样发给此引擎。",
              keys: ["search.shift", "search.shiftCustom"], words: ["shift enter", "second engine", "alternate", "google", "perplexity"]),
        .init(id: "search.suggest", group: "search", icon: "text.magnifyingglass",
              title: "搜索引擎建议", detail: "输入内容将实时发送给搜索引擎",
              more: "搜索建议会显示在地址栏下方。绝不发送无痕标签页中的输入或网址。",
              keys: ["search.suggest"], words: ["autocomplete", "suggest"]),
        .init(id: "search.keywords", group: "search", icon: "character.cursor.ibeam",
              title: "网站搜索快捷词", detail: "在搜索词前加一个关键词即可定向到该网站：\"yt cats\"",
              keys: ["search.keywords"], words: ["keyword", "bang"]),
        .init(id: "links.little", group: "links", icon: "rectangle.on.rectangle",
              title: "在小窗口中打开其他 App 的链接", detail: "阅后即关，或按 ⌘O 在 Search 中打开保留；也可从标签页菜单打开小窗口",
              keys: ["links.little"], words: ["little arc", "mini window", "open in small window"]),
        .init(id: "links.little.tabs", group: "links", icon: "arrow.right.square",
              title: "跳转至已打开该网页的标签页", detail: "若网页已在某个标签页打开，则直接跳转至该标签页而非打开小窗口",
              keys: ["links.little.tabs"], words: ["switch to tab", "already open", "duplicate"], parent: "links.little"),
        .init(id: "reader.twins", group: "reading", icon: "doc.text",
              title: "优先阅读网站自带的 Markdown", detail: "网页提供 Markdown 版本时，阅读模式将直接显示该版本",
              more: "按 ⇧⌘R 以简洁排版单独阅读正文。多数文档站点都提供 Markdown 版本；其中所有内容均经转义，不会执行任何脚本。",
              keys: ["reader.twins"], words: ["markdown", "reader"]),
        .init(id: "reader.follows", group: "reading", icon: "circle.righthalf.filled",
              title: "阅读模式跟随浅色与深色外观", detail: "深色窗口下以深底浅字显示文章",
              more: "角落的小开关可将文章设为浅色、深色或跟随窗口，并记住用于下一篇。",
              keys: ["reader.follows"], words: ["reader", "dark"]),
        .init(id: "float.style", group: "video", icon: "pip",
              title: "悬浮视频", detail: "Search 自带悬浮窗，或 macOS 原生画中画",
              more: "Search 悬浮窗无需点按即可浮出视频并保持网页活跃。画中画则采用与 Safari 相同的系统原生控件。",
              keys: ["float.style"], words: ["pip", "picture in picture", "mini player"]),
        .init(id: "float.own", group: "video", icon: "pip.exit",
              title: "自动浮出视频", detail: "离开视频所在标签页或切换出 Search 时自动浮出正在播放的视频",
              more: "返回标签页时视频会自动归位；若窗口仍在另一屏幕上可见则保持原位。仍可按 ⇧⌘P 手动浮出。",
              keys: ["float.leave", "float.away"], words: ["pip", "picture in picture", "switch apps"], kind: .wide),
        .init(id: "float.minimize", group: "video", icon: "minus.circle",
              title: "最小化悬浮视频", detail: "点按按钮可将悬浮视频收起缩小，再次点按即可恢复",
              keys: ["float.minimize"], words: ["minimize", "pip", "collapse", "small"]),
        .init(id: "media.click", group: "video", icon: "play.slash",
              title: "点按后才播放视频", detail: "视频不会自动播放，即使处于静音状态",
              keys: [Preferences.waitsKey], words: ["autoplay", "auto-play"]),
        .init(id: "fullscreen.escapeTwice", group: "video", icon: "escape",
              title: "连按两次 Esc 退出全屏", detail: "首次按下时显示提示，与 Arc 一致",
              keys: ["fullscreen.escapeTwice"], words: ["escape", "full screen"]),
        .init(id: "fullscreen.keepsWindow", group: "video", icon: "macwindow",
              title: "全屏播放视频时保持窗口可用", detail: "视频在另一桌面全屏播放时，原窗口及其标签页仍可正常操作",
              keys: ["fullscreen.keepsWindow"], words: ["full screen", "desktop", "space", "video"]),
        .init(id: "translate.target", group: "pages", icon: "translate",
              title: "翻译语言", detail: "网页在这台 Mac 本地完成翻译",
              keys: ["translate.target"], words: ["translate", "language"]),
        .init(id: "pageZoom", group: "pages", icon: "plus.magnifyingglass",
              title: "页面缩放", detail: "所有网站的默认缩放比例。使用 ⌘+ 和 ⌘− 调整的比例会按网站分别记住",
              keys: ["pageZoom"], words: ["zoom", "size", "scale"]),
        .init(id: "pages.capture", group: "pages", icon: "camera.viewfinder",
              title: "网页截图", detail: "通过“显示”菜单中的“截图…”可截取选区、元素或整页",
              more: "拖选区域、点按元素或选择“整页”，按 Esc 取消。图片会复制到剪贴板并以 PNG 格式保存到下载文件夹，不会上传至任何位置。",
              keys: ["pages.capture"], words: ["screenshot", "capture", "snapshot", "picture", "png", "arc"]),
        .init(id: "sites.styles", group: "pages", icon: "paintbrush",
              title: "自定义网站样式", detail: "通过“显示”菜单中的“编辑网站样式…”可为当前网站应用自定义 CSS",
              more: "类似 Arc 的 Boosts，输入时即实时生效于该网站所有页面。仅支持 CSS，Search 不会在网页中运行自定义脚本。关闭后所有样式均会保留但暂不生效。",
              keys: ["sites.styles"], words: ["boost", "boosts", "css", "style", "stylesheet", "customize", "custom css", "arc", "theme"]),
        .init(id: "pages.120", group: "pages", icon: "speedometer",
              title: "120 Hz 网页刷新率", detail: "在支持的屏幕上获得更流畅的滚动体验，接通电源时启用更省电",
              more: "网页动画与滚动最高可达每秒 120 帧，而非 Safari 的 60 帧。",
              keys: ["pages.120.mode", "pages.120"], words: ["promotion", "frame rate", "fps", "smooth", "120"]),

        // Spaces & Pins
        .init(id: "arc.setup", group: "arc", icon: "wand.and.stars",
              title: "设为 Arc 风格", detail: "使用左侧标签栏、空间、固定行和 Arc 的操作习惯，例如在 12 小时后关闭标签页",
              more: "同时启用悬浮栏新建标签页、自动悬浮视频、轻扫返回以关闭由链接打开的标签页，以及按住 Shift 点按链接以速览。仅调整尚未启用的选项，撤销可恢复之前的设置。",
              words: ["arc", "the browser company", "auto archive", "archive", "peek", "picture in picture", "swipe back"]),
        .init(id: "arc.import", group: "arc", icon: "square.and.arrow.down",
              title: "导入 Arc 的空间与固定标签页", detail: "从这台 Mac 上的 Arc 读取你的空间、固定标签页与文件夹",
              words: ["arc", "import"]),
        .init(id: "spaces", group: "spaces", icon: "square.stack.3d.up",
              title: "空间", detail: "相互独立的标签页集合，可用 ⌃1–⌃9 或轻扫切换",
              more: "每个空间可共享登录状态，也可独立全新开始。若你在“调度中心”中启用了 Control-1 至 Control-9，系统快捷键将优先生效。",
              keys: ["spaces"], words: ["workspaces", "profiles"]),
        .init(id: "spaces.commandNumbers", group: "spaces", icon: "command",
              title: "使用 ⌘1–⌘9 切换空间", detail: "标签页切换改为 ⌃1–⌃9，与 Arc 一致",
              more: "两组快捷键互换位置。你在“键盘与鼠标 › 快捷键”中自定义的空间快捷键保持不变。若在“调度中心”中启用了 Control-1 至 Control-9，系统快捷键将优先生效。",
              keys: [Preferences.spacesOnCommandKey],
              words: ["arc", "cmd", "command", "control", "ctrl", "spaces", "numbers", "digits", "shortcut", "keys", "⌘1", "⌃1", "switch spaces", "swap"],
              parent: "spaces"),
        .init(id: "spaces.buttons", group: "spaces", icon: "square.grid.3x1.below.line.grid.1x2",
              title: "每个空间单独显示按钮", detail: "所有空间并列于书签旁，一键即可切换",
              more: "替代原先的单个空间图标与菜单。点按当前所在空间仍可打开该菜单。位于边栏底部时按钮居中显示。",
              keys: [Preferences.spaceButtonsKey],
              words: ["arc", "spaces", "buttons", "icons", "switcher", "dot", "footer", "bottom"],
              parent: "spaces"),
        .init(id: "profiles", group: "spaces", icon: "person.2",
              title: "个人资料", detail: "拥有各自登录状态、历史记录与书签的空间",
              more: "除非开启“单窗口切换个人资料”，否则各自在独立窗口中打开。扩展、密码和设置保持共享。",
              words: ["profile", "accounts", "work", "personal"]),
        .init(id: "profiles.oneWindow", group: "spaces", icon: "macwindow",
              title: "单窗口切换个人资料", detail: "所有个人资料的空间均在同一窗口中原地切换",
              more: "选择其他个人资料的空间时，会将其窗口原地切换至当前位置，各自保持独立登录状态。关闭该窗口将同时关闭所有关联窗口。",
              keys: ["profiles.oneWindow"], words: ["arc", "profiles", "single window", "merge"], parent: "profiles"),
        .init(id: "spaces.links", group: "spaces", icon: "arrow.triangle.branch",
              title: "将链接发送到空间", detail: "所选网站的链接将在对应空间中打开，并使用该空间的登录状态",
              more: "适用于来自其他 App 的链接，以及在其他空间页面中于新标签页打开的链接。网站包含其子域名。手动输入的地址、在当前标签页中打开的链接以及无痕标签页将保留在原位。右键点按标签页，即可将其网站发送到当前所在空间。",
              keys: [SpaceRoutes.key, SpaceRoutes.rulesKey],
              words: ["arc", "air traffic control", "route", "routing", "rules", "domain", "site", "open in space", "default space", "links from other apps"],
              parent: "spaces"),
        .init(id: "links.ask", group: "spaces", icon: "questionmark.square.dashed",
              title: "打开其他 App 的链接时询问空间",
              detail: "在加载前选择要用于打开其他 App 链接的空间",
              more: "弹出小面板列出所有空间：按数字键可在对应空间打开链接，按 Return 键可在已标记的空间中打开。开启“将链接发送到空间”后，选择“始终”可为该网站保存规则。",
              keys: ["links.ask", "links.ask.last"],
              words: ["choose space", "which space", "links from other apps", "panel", "ask"],
              parent: "spaces"),
        .init(id: "pins.keep", group: "pins", icon: "pin.circle",
              title: "固定标签页保留原网站", detail: "外部链接将在固定标签页上方打开，按 ⌘W 可返回主页",
              more: "与 Arc 和 Safari 一样：从固定标签页打开其他网站的链接时，会以速览形式显示在其上方；使用 ⌘W 关闭或退出 Search 时未关闭的固定标签页，重新打开时会回到最初固定的页面。",
              keys: ["pins.home", "pins.peek"], words: ["pinned tabs", "go home", "reset pin"]),
        .init(id: "pins.list", group: "pins", icon: "list.bullet.rectangle",
              title: "固定行", detail: "在方块固定标签页下方以行显示，其余标签页上方显示“清除”",
              more: "与 Arc 一样：常用网站以方块固定，常备页面以行固定，其余标签页上方有分隔线和“清除”按钮。右键点按标签页即可将其固定为行。",
              keys: ["pins.list"], words: ["arc", "pinned"], parent: "tabs.layout"),
        .init(id: "pins.folders", group: "pins", icon: "folder",
              title: "固定行中的文件夹", detail: "在文件夹中整理固定行并支持嵌套，与 Arc 一样",
              more: "右键点按固定行并选择“新建文件夹”，或将固定行拖到文件夹上。点按即可折叠文件夹，最多支持三级嵌套。从 Arc 导入数据时会保留原有文件夹结构。“新建实时文件夹…”可通过网站的 RSS 或 Atom 订阅源自动填充内容，并每半小时刷新一次。",
              keys: ["pins.folders"],
              words: ["arc", "folder", "folders", "nested", "subfolder", "pinned folder", "pinned tabs", "organise", "organize",
                      "live folder", "feed", "rss", "atom"],
              parent: "pins.list"),
        .init(id: "pins.commandNewTab", group: "pins", icon: "command",
              title: "按住 ⌘ 点按固定标签页以在新标签页中打开",
              detail: "在新标签页中打开固定标签页的网站，或将已跳转的页面移至普通标签页",
              more: "与 Arc 一样：按住 ⌘ 点按固定标签页会在其原地址打开新标签页；若固定标签页已离开原页面，当前页面会保留在普通标签页中，固定标签页则恢复为主页。关闭后，按住 ⌘ 点按会将固定标签页加入多选。",
              keys: ["pins.commandNewTab"],
              words: ["command click", "cmd click", "pinned", "arc", "selection", "multi select"]),
        .init(id: "newtab.floating", group: "opening", icon: "rectangle.and.text.magnifyingglass",
              title: "在悬浮栏中新建标签页", detail: "按 ⌘T 在页面上方呼出地址栏，与 Arc 一样",
              more: "按 Return 键在新标签页中打开输入的内容；按 Esc、⌘W 或点按外部即可关闭。",
              keys: ["newtab.floating"], words: ["command bar", "cmd t", "spotlight"]),
        .init(id: "field.window", group: "opening", icon: "rectangle.center.inset.filled",
              title: "在窗口中央显示悬浮地址栏", detail: "按 ⌘T 或 ⌘L 时，在窗口中间略靠上的位置显示悬浮地址栏",
              more: "位置与 Arc 和 Zen 类似，靠近“聚焦”搜索框；页面和边栏会一起变暗。关闭后，地址栏将在边栏旁的页面区域内居中。",
              keys: ["field.window"], words: ["command bar", "cmd t", "cmd l", "spotlight", "centre", "center", "position", "arc", "zen"]),
        .init(id: "newtab.recent", group: "opening", icon: "clock.arrow.circlepath",
              title: "新建标签页时显示最近访问", detail: "在输入前，⌘T 呼出的地址栏会列出最近访问的三个页面",
              more: "来自本机 Mac 的历史记录，排除已打开的页面（可用 ⌘K 查找）。在按下方向键前不会默认选中任何项，无痕标签页中不显示任何记录。",
              keys: ["newtab.recent"], words: ["recent", "history", "suggestions", "cmd t", "last visited"], parent: "newtab.floating"),
        .init(id: "newtab.arc", group: "opening", icon: "rectangle.stack",
              title: "⌘T 查找已打开的标签页", detail: "输入时自动匹配已打开的标签页或固定标签页，按 Return 键直接切换",
              more: "输入时优先匹配已打开的标签页，其次是固定标签页，最后是历史记录补全，按 Return 键即可切换到已有页面而无需重复打开。按 ↑ 可取消选中标签页，再按 Return 键打开输入的内容。",
              keys: ["newtab.arc"], words: ["arc", "open tabs", "switch tab", "pins", "cmd t", "tab search"], parent: "newtab.floating"),
        .init(id: "commandbar", group: "opening", icon: "chevron.right.square",
              title: "地址栏命令", detail: "在地址栏中直接输入 \"settings\" 或 \"new tab\" 即可前往",
              more: "输入部分名称（如 \"down\" 或 \"dwn\"）会在列表下方显示对应命令，涵盖名称包含所输字词的所有菜单命令和设置页面，类似 Arc 的命令栏。",
              keys: ["commandbar"], words: ["commands", "command palette"]),
        .init(id: "start.fresh", group: "opening", icon: "sunrise",
              title: "启动时打开全新窗口", detail: "仅恢复固定标签页、标签页组和已命名标签页；不恢复上次的其他标签页",
              keys: [Preferences.freshKey], words: ["restore", "session", "startup"]),

        // Passwords
        .init(id: "passwords.open", group: "passwords", icon: "key.viewfinder",
              title: "你的密码", detail: "存储在 macOS 钥匙串中，需通过触控 ID 查看", words: ["keychain"]),
        .init(id: "passwords.save", group: "passwords", icon: "square.and.arrow.down",
              title: "提示存储密码", detail: "每个网站仅询问一次，拒绝后不再提示",
              keys: ["passwords.save"], words: ["save password"]),
        .init(id: "passwords.fill", group: "passwords", icon: "rectangle.and.pencil.and.ellipsis",
              title: "自动填充登录信息", detail: "点按登录框即可在下方显示该网站的账户",
              keys: ["passwords.fill"], words: ["autofill", "login"]),
        .init(id: "passwords.fill.prove", group: "passwords", icon: "touchid",
              title: "填充前要求使用触控 ID", detail: "在网页上填充已存储的密码前，使用触控 ID 或 Mac 密码验证身份",
              more: "验证通过后，一分钟内无需再次验证；Mac 睡眠或锁定后需要重新验证。Apple 密码和扩展使用各自的验证方式。",
              keys: ["passwords.fill.prove"], words: ["touch id", "authenticate", "autofill", "lock", "biometric", "fingerprint", "password", "secure"],
              parent: "passwords.fill"),
        .init(id: "passkeys", group: "passwords", icon: "person.badge.key",
              title: "提供通行密钥", detail: "在支持的网站上使用触控 ID 或 iCloud 通行密钥",
              keys: ["passkeys"], words: ["webauthn", "touch id"]),
        .init(id: "passwords.apple", group: "apple", icon: "applelogo",
              title: "来自 Apple“密码”App 的密码", detail: "在输入框下方显示“密码”App 中的账户和验证码（非官方支持）",
              more: "Search 会以 Apple Chrome 扩展的身份与其辅助程序通信。绝不会在无痕标签页中启用。",
              keys: ["passwords.apple"], words: ["icloud keychain", "apple"]),
        .init(id: "contacts.fill", group: "forms", icon: "person.crop.rectangle",
              title: "自动填充联系信息", detail: "在姓名、电子邮件、电话和地址框下方显示“通讯录”中的个人名片",
              more: "点按即可一并填充表单中其余空白栏位。仅读取你本人的名片，且 macOS 会先请求授权。",
              keys: ["contacts.fill"], words: ["autofill", "address", "email", "phone", "name", "contacts", "me card"]),

        // Privacy
        .init(id: "shield", group: "blocking", icon: "shield.lefthalf.filled",
              title: "拦截广告和跟踪器", detail: "拦截仅用于跟踪的第三方内容及 YouTube 广告",
              more: "在 YouTube 上，播放器数据中声明的广告会在视频开始前被移除。如需为单个网站关闭，请点按当前标签页并在网站卡片中设置。",
              keys: ["shield"], words: ["adblock", "ad blocker", "ads", "youtube"]),
        .init(id: "sites.keep", group: "blocking", icon: "eye.slash",
              title: "阻止跨站跟踪", detail: "与 Safari 一样。无痕标签页始终开启",
              more: "开启后（与 Safari 相同），主要通过跟踪器链接访问的网站（如从 Google 访问 YouTube、通过登录按钮访问 GitHub）在一周内若无点击或输入交互，可能会清除已保存的偏好设置，随后可能退出登录。关闭后，很少打开的网站会保持登录状态，且其他网站中的跟踪器可以跨站跟踪你（与 Chrome 相同）。",
              keys: ["sites.keep"], words: ["itp", "cookies", "tracking"]),
        .init(id: "privacy.clickIDs", group: "blocking", icon: "scissors",
              title: "移除链接中的点击跟踪参数", detail: "在页面加载前移除 gclid、fbclid 等参数。无痕标签页始终开启",
              more: "这些是广告网络添加到链接中的 ID，用于识别点击来源。推广活动标签（utm_）将保留，与 Safari 一样。",
              keys: ["privacy.clickIDs"], words: ["gclid", "fbclid", "click id", "link tracking", "tracking parameters"]),
        .init(id: "privacy.gpc", group: "blocking", icon: "hand.raised",
              title: "告知网站不要出售或共享你的数据", detail: "在每次请求中发送全球隐私控制信号。无痕标签页始终开启",
              more: "发送 Sec-GPC: 1 标头，部分地区法律要求网站遵守此声明。",
              keys: ["privacy.gpc"], words: ["gpc", "do not sell", "do not track", "dnt", "global privacy control"]),
        .init(id: "privacy.httpsFirst", group: "blocking", icon: "lock",
              title: "优先尝试 HTTPS", detail: "当网站支持时，通过 HTTPS 加载 http:// 页面",
              more: "若网站不支持，则按原地址加载。本地地址（localhost、.test、.local、IP 地址）保持不变。",
              keys: ["privacy.httpsFirst"], words: ["https", "https only", "https first", "secure", "upgrade", "http"]),
        .init(id: "notifications.ask", group: "permissions", icon: "bell.badge",
              title: "允许网站请求发送通知", detail: "仅允许你授权的网站向 Mac 发送通知",
              keys: ["notifications.ask"], words: ["notifications", "alerts", "push"]),
        .init(id: "privacy.forget", group: "permissions", icon: "arrow.uturn.backward.circle",
              title: "摄像头、麦克风、位置和通知", detail: "查看各网站已允许或拒绝的权限",
              words: ["permissions", "camera", "microphone", "location", "reset"]),
        .init(id: "clear.history", group: "clear", icon: "clock.arrow.circlepath",
              title: "历史记录", detail: "你访问过的所有网址", words: ["clear history"]),
        .init(id: "clear.cookies", group: "clear", icon: "person.crop.circle.badge.xmark",
              title: "Cookie 与登录状态", detail: "退出所有网站的登录状态", words: ["cookies", "sign out"]),
        .init(id: "clear.cache", group: "clear", icon: "internaldrive",
              title: "缓存", detail: "仅包含用于渲染页面的缓存资源", words: ["clear cache", "empty caches", "cache storage"]),

        // Keyboard & Mouse
        .init(id: "links.peek", group: "mouse", icon: "eye",
              title: "预览链接", detail: "在当前阅读页面上方的面板中打开链接页面",
              more: "按 Esc 键关闭；点按另一按钮可将其保留为标签页。",
              keys: ["links.peek", "links.peekClick"], words: ["preview", "shift click", "peek"]),
        .init(id: "links.peek.stays", group: "mouse", icon: "eye.slash",
              title: "速览随所属标签页保留", detail: "切换标签页时隐藏速览并暂停其音视频，切回时重新显示",
              keys: ["links.peek.stays"], words: ["peek", "keep peek", "switch tabs"], parent: "links.peek"),
        .init(id: "links.optionSplit", group: "mouse", icon: "rectangle.split.2x1",
              title: "按住 ⌥ 点按链接以在分屏视图中打开", detail: "在当前页面旁并排显示链接页面，等同于“在分屏视图中打开链接”",
              more: "关闭后，按住 ⌥ 点按与普通点按一样打开链接。在 Safari 中此操作会下载链接。",
              keys: ["links.optionSplit"], words: ["option click", "alt click", "split", "side by side", "link", "open beside"]),
        .init(id: "autoscroll", group: "mouse", icon: "arrow.up.and.down.circle",
              title: "使用鼠标中键滚动", detail: "按下滚轮后移动鼠标进行滚动，与 Windows 一样",
              keys: ["autoscroll"], words: ["middle click", "autoscroll", "wheel"]),
        .init(id: "wheel.smooth", group: "mouse", icon: "computermouse",
              title: "使用鼠标滚轮时平滑滚动", detail: "滚轮每滚动一格，页面都会像 Chrome 一样平滑移动",
              more: "触控板和本身支持平滑滚动的鼠标会保持原有行为。按住 ⌘、⌃ 或 ⌥ 时，页面会直接接收滚轮输入，以便缩放。",
              keys: ["wheel.smooth"], words: ["smooth scrolling", "mouse wheel", "notch", "logitech", "jumpy", "choppy", "chrome"]),
        .init(id: "pages.bounce", group: "mouse", icon: "arrow.up.and.down",
              title: "顶部和底部回弹效果", detail: "滚动至页面尽头时略微拉伸并回弹，与 Safari 一样",
              keys: ["pages.bounce"], words: ["elastic", "rubber band", "overscroll", "bounce", "smooth scrolling", "safari"]),
        .init(id: "swipe.history", group: "mouse", icon: "hand.draw",
              title: "轻扫并按住以从历史记录中选择", detail: "向后轻扫后保持手指按住以选择页面",
              more: "向后或向前轻扫并保持手指不放，即可显示该方向的历史页面列表，上下移动即可选择。",
              keys: ["swipe.history"], words: ["gesture", "trackpad", "back"]),
        .init(id: "launcher.on", group: "anywhere", icon: "rectangle.and.text.magnifyingglass",
              title: "在任意 App 中打开地址栏", detail: "使用自定义快捷键在当前 App 上方呼出地址栏，类似聚焦搜索",
              more: "按 Return 键在 Search 最前窗口的新标签页中打开输入内容，或切换至已有标签页并将 Search 置前。按 Esc、点按外部或再按一次快捷键即可关闭并留在原处。当 Search 窗口位于最前时，该快捷键交由页面处理；此时请使用 ⌘L 聚焦地址栏。",
              keys: ["launcher.on", "launcher.key"],
              words: ["spotlight", "launcher", "global", "hotkey", "shortcut", "quick search", "raycast", "alfred", "anywhere"]),
        .init(id: "launcher.key", group: "anywhere", icon: "keyboard",
              title: "快捷键", detail: "在任意 App 中按下即可呼出地址栏",
              keys: ["launcher.key"], words: ["hotkey", "global shortcut", "shift command space"], parent: "launcher.on"),
        .init(id: "launcher.little", group: "anywhere", icon: "macwindow",
              title: "在小窗口中打开", detail: "按 Return 键在当前 App 上方的小窗口中打开页面，而非 Search 主窗口",
              more: "与来自其他 App 的链接（设置 › 通用）类似：在小窗口中显示页面并提供“在 Search 中打开”按钮，便于阅后即关或保留。若从列表中选择了已打开的标签页，仍会跳转至该标签页。",
              keys: ["launcher.little"], words: ["little arc", "little window", "small window", "quick look", "option command n"], parent: "launcher.on"),

        // About
        .init(id: "updates.version", group: "updates", icon: "arrow.down.app",
              title: "更新", detail: "每小时自动检查一次", words: ["version", "update"]),
        .init(id: "updates.auto", group: "updates", icon: "arrow.triangle.2.circlepath",
              title: "自动安装更新", detail: "关闭后，Search 会通知你并等待你选择“安装”",
              keys: [Updater.installKey], words: ["automatic updates"]),
        .init(id: "about.feedback", group: "updates", icon: "envelope",
              title: "发现问题？", detail: "打开已预填当前版本号的邮件草稿", words: ["bug", "feedback", "report"]),
        .init(id: "about.notes", group: "updates", icon: "sparkles",
              title: "新功能", detail: "各版本更新说明，按最新排序", words: ["release notes", "changelog"]),
        // An email field each, never sent without a press (OptIn.swift).
        // Only booleans are kept, never the address.
        .init(id: "news.updates", group: "news", icon: "envelope",
              title: "邮件资讯", detail: "极少发送邮件：仅推送实用新功能和重大更新，绝无其他内容",
              more: "你的电子邮件地址会连同 app-settings 标识及当前 Mac 下载版本信息发送至 searchbrowser.app，并通过我们的邮件服务 Resend 发送。每封邮件均附有退订链接。此 Mac 仅记录你已订阅，不会保存你的邮箱地址。",
              keys: [OptIn.joinedKey],
              words: ["newsletter", "email", "mailing list", "subscribe", "news", "updates by email"], kind: .wide),
        .init(id: "news.iphone", group: "news", icon: "iphone",
              title: "Search iPhone 测试版", detail: "申请 iPhone 测试版，邀请将发送至你的邮箱",
              more: "你的电子邮件地址会连同 app-settings 标识发送至 searchbrowser.app，用于发放测试资格及偶尔发送测试版动态。每封邮件均附有退订链接。此 Mac 仅记录你已申请，不会保存你的邮箱地址。",
              keys: [OptIn.betaKey],
              words: ["iphone", "ios", "beta", "testflight", "mobile", "phone", "email"], kind: .wide),
        .init(id: "bench", group: "developer", icon: "terminal",
              title: "允许脚本控制 Search", detail: "用于测试的本地套接字；其标签页绝不会接管焦点",
              more: "脚本打开的标签页会带有烧瓶图标并排显示在你的标签页旁。详见 ./bench。",
              keys: ["bench"], words: ["automation", "script", "developer"]),
        .init(id: "agents", group: "developer", icon: "cursorarrow.rays",
              title: "允许编程智能体使用 Search", detail: "Claude Code 或 Codex 可请求在独立标签页中浏览，全程可见可控",
              more: "每次连接时窗口都会先询问你的许可，除非你勾选了“始终允许”——该选项仅适用于由 Anthropic 签名的 Claude Code 自带 `claude`；最多保留 30 天或上次使用后 7 天，绝不访问你的标签页，且在你按下“停止”后会重新询问；你可在此处忘记授权。页面上不会绘制任何遮罩：智能体操作的标签页会显示小圆点，栏底（或标签栏）以及“文件 › 停止智能体 (⌃⌥⌘.)”会提供“停止”按钮直至其结束。它仅在自己的标签页中工作；只有勾选“允许其查看我已打开的标签页”时才能读取你的标签页，且绝不对其操作。它永远无法查看密码、卡号、一次性验证码、无痕标签页、Cookie 或设置，也无法下载或选择文件。它仅通过此 Mac 上的本地文件连接，不走网络：claude mcp add search -- /path/to/Search/search-mcp。",
              keys: ["agents"],
              words: ["agent", "ai", "claude", "claude code", "codex", "mcp", "automation", "computer use", "developer"]),

        // Moved to a menu, or always on: only the find field says so.
        .init(id: "autocorrect", group: "pages", icon: "textformat.abc.dottedunderline",
              title: "键入时自动纠正拼写", detail: "现已移至“编辑 › 拼写和语法”，与 Safari 一样",
              keys: ["autocorrect"], words: ["autocorrect", "spelling", "spell"], findOnly: true),
        .init(id: "inlinePredictions", group: "pages", icon: "text.cursor",
              title: "显示行内预测", detail: "键入时以灰色显示补全词尾；位于“编辑 › 拼写和语法”",
              keys: ["inlinePredictions"], words: ["inline", "predictions", "predictive text", "suggestions", "completion", "autocomplete", "autocorrect", "spelling"], findOnly: true),
        .init(id: "note.split", group: "window", icon: "rectangle.split.2x1",
              title: "分屏视图", detail: "始终可用：按住 ⌥ 点按标签页、将标签页拖到页面上，或按 ⌥⌘N",
              keys: ["splitView"], words: ["split", "side by side"], kind: .note, findOnly: true),
        .init(id: "note.groups", group: "newtabs", icon: "folder",
              title: "标签页组", detail: "始终可用：右键点按标签页 › 添加到新建标签页组",
              keys: ["tabs.groups"], words: ["groups", "folders"], kind: .note, findOnly: true),
        .init(id: "note.panel", group: "links", icon: "sidebar.right",
              title: "在侧边面板中打开网站", detail: "始终可用：显示 › 侧边面板，或右键点按标签页",
              keys: ["panel.sites"], words: ["side panel", "claude", "chatgpt"], kind: .note, findOnly: true),
        .init(id: "note.translate", group: "pages", icon: "translate",
              title: "在此 Mac 上翻译网页", detail: "始终可用：右键点按页面 › 翻译页面",
              keys: ["translate.pages"], words: ["translate", "language"], kind: .note, findOnly: true),
        .init(id: "extensions.sites", group: "extensions", icon: "globe",
              title: "扩展的运行范围", detail: "可为每个扩展设置“运行范围”：所有网站、指定网站或点按时运行",
              more: "限制运行网站可减少其余页面的内存占用。右键点按扩展按钮即可在当前网站运行。",
              keys: ["extensions.sites"],
              words: ["site access", "sites", "permissions", "host", "on click", "activetab", "memory", "extension"],
              kind: .note, findOnly: true),
        .init(id: "extensions.safariApps", group: "extensions", icon: "safari",
              title: "来自 Safari 扩展 App", detail: "默认关闭，可在“设置 › 扩展”底部开启",
              more: "列出“应用程序”中各 App 随附的 Safari 扩展，供你作为未打包的扩展添加。仅运行 JavaScript，原生消息传递和内容拦截器无法使用。",
              keys: [SafariApps.key],
              words: ["safari", "safari extension", "app extension", "appex", "mac app"],
              kind: .note, findOnly: true),
        .init(id: "note.awake", group: "memory", icon: "sun.max",
              title: "保持选定网站活跃", detail: "始终可用：在网站卡片中开启“保持此网站活跃”",
              keys: ["tabs.keepAwake"], words: ["awake", "sleep"], kind: .note, findOnly: true),
        .init(id: "note.sitesearch", group: "search", icon: "arrow.right.to.line.compact",
              title: "从地址栏搜索特定网站", detail: "始终可用：输入 red 后按 Tab 键即可搜索 Reddit",
              keys: ["search.sites"], words: ["tab to search", "site search"], kind: .note, findOnly: true),
        .init(id: "note.spaceGradient", group: "spaces", icon: "paintpalette",
              title: "空间的颜色或渐变", detail: "启用空间后始终可用：空间菜单 › 颜色…，可选纯色或渐变",
              keys: ["spaces.gradient"], words: ["gradient", "theme", "colour", "color", "tint", "grain", "arc"], kind: .note, findOnly: true),
        .init(id: "note.sharedpins", group: "pins", icon: "pin",
              title: "在所有空间中显示固定标签页", detail: "启用空间后始终可用：右键点按固定标签页 › 在所有空间中保留",
              keys: ["pins.shared"], words: ["favorites", "shared pins"], kind: .note, findOnly: true),
        .init(id: "note.pinback", group: "pins", icon: "arrow.uturn.backward",
              title: "再按一次固定标签页数字键以返回", detail: "始终可用：再次按下固定标签页对应的 ⌘ 数字键即可返回上一页面",
              keys: ["pins.numberBack"], words: ["cmd 1", "toggle"], kind: .note, findOnly: true),
        .init(id: "note.switcher", group: "mouse", icon: "rectangle.stack",
              title: "标签页切换器快捷键", detail: "始终可用：呼出 ⌃Tab 时可按 ⌃W、⌃R、⌃M 和 ⌃O",
              keys: ["switcher.keys"], words: ["ctrl tab", "switcher"], kind: .note, findOnly: true),
        .init(id: "note.links", group: "links", icon: "link",
              title: "显示链接目标地址", detail: "始终可用：在页面底部显示链接地址",
              keys: ["links.show"], words: ["status bar", "hover"], kind: .note, findOnly: true),
        .init(id: "note.flick", group: "video", icon: "hand.raised.fingers.spread",
              title: "轻扫将悬浮视频移至角落", detail: "始终可用：双指向目标角落轻扫即可将其移至该角",
              keys: ["float.flicks"], words: ["flick", "corner"], kind: .note, findOnly: true),
    ] as [SettingsItem]).filter(offered)

    /// Rows for a feature this Mac's WebKit doesn't have aren't listed at
    /// all, on the page or in the find field (see Privacy.swift).
    private static func offered(_ item: SettingsItem) -> Bool {
        switch item.id {
        case "privacy.clickIDs": return ClickIDs.possible
        case "privacy.gpc": return PrivacySignal.possible
        case "privacy.httpsFirst": return HTTPSFirst.possible
        default: return true
        }
    }

    static func item(_ id: String) -> SettingsItem? { items.first { $0.id == id } }

    // MARK: - finding

    /// The rows whose words match what was typed, in the order of the
    /// sections. Every word typed has to be found somewhere in the row.
    static func find(_ typed: String) -> [SettingsItem] {
        let words = typed.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }
        let order = SettingsPanel.Page.allCases
        return items
            .filter { item in
                let group = SettingsIndex.group(item.group)
                let hay = ([item.title, item.detail, item.more ?? "", group?.title ?? "", item.page.title]
                    + item.words + item.keys).joined(separator: " ").lowercased()
                return words.allSatisfy { hay.contains($0) }
            }
            .sorted { (order.firstIndex(of: $0.page) ?? 0, groupOrder($0.group)) < (order.firstIndex(of: $1.page) ?? 0, groupOrder($1.group)) }
    }

    private static func groupOrder(_ id: String) -> Int { groups.firstIndex { $0.id == id } ?? 0 }

    /// Whether a dependent row means anything as things are set now. Its
    /// section hides it otherwise; the find field shows it dimmed.
    @MainActor static func applies(_ item: SettingsItem, _ prefs: Preferences) -> Bool {
        switch item.id {
        case "pages.dusk": return prefs.look != .light
        case "inspector.dark": return prefs.look != .dark
        case "sidebar.roomy", "sidebar.player", "sidebar.doorsUp", "sidebar.foldButton", "sidebar.narrowIcons": return prefs.sidebar && !prefs.sideIcons
        case "sidebar.hides", "sidebar.slides", "layout.cards", "pins.list": return prefs.sidebar
        case "layout.cardsFullScreen": return prefs.sidebar && prefs.cards
        case "address.width": return prefs.addressLine && !prefs.sidebar
        case "tabs.liquid": return LiquidTab.available && !(prefs.sidebar && prefs.sideIcons)
        case "window.glass.style": return prefs.glass && GlassStyle.liquidAvailable
        // With spaces on they are in the space's Colour…, beside its colour.
        case "window.glass.clear", "window.glass.grain": return prefs.glass && !prefs.usesSpaces
        case "pins.folders": return prefs.sidebar && prefs.listsPins
        case "sidebar.foldIcons": return prefs.sidebar && !prefs.sideHides
        case "bookmarks.side": return prefs.sidebar && prefs.bookmarksBar
        case "bookmarks.iconsOnly": return prefs.bookmarksBar && !prefs.sideBookmarks
        case "passwords.fill.prove": return prefs.fillsPasswords
        case "toolbar.left", "tabs.compact": return !prefs.sidebar
        case "profiles.oneWindow": return Profiles.shared.several
        case "spaces.links", "links.ask", "spaces.buttons": return prefs.usesSpaces
        case "tabs.frontBeside": return prefs.newTabPlace == .next
        case "newtab.recent", "newtab.arc": return prefs.floatingNewTab
        case "links.little.tabs": return prefs.littleLinks
        case "mail.default": return prefs.webmail != .none
        case "links.peek.stays": return prefs.peeksLinks || prefs.pinsPeek
        case "launcher.key": return prefs.launcher
        case "icloud.erase": return ICloudSync.shared.on
        default: return true
        }
    }

    /// What a dimmed dependent row says instead of its own line.
    static func needs(_ item: SettingsItem) -> String {
        switch item.id {
        case "pages.dusk": return "仅在 Search 未设为浅色外观时可用"
        case "inspector.dark": return "仅在 Search 未设为深色外观时可用"
        case "toolbar.left", "tabs.compact", "address.width": return "仅在标签页位于顶部时可用"
        case "sidebar.roomy", "sidebar.doorsUp", "sidebar.foldButton", "sidebar.narrowIcons": return "仅在边栏显示标题时可用"
        case "tabs.liquid": return LiquidTab.available ? "仅在边栏显示标题或标签页位于顶部时可用" : "Liquid Glass 需要 macOS 26"
        case "window.glass.style": return GlassStyle.liquidAvailable ? "仅在开启 Glass 时可用" : "Liquid Glass 需要 macOS 26"
        case "window.glass.clear", "window.glass.grain": return "启用空间后，可在空间菜单 › 颜色… 中设置"
        case "sidebar.foldIcons": return "仅在边栏固定于一侧且未设为贴边隐藏时可用"
        case "icloud.erase": return "仅在开启 iCloud 同步时可用"
        case "profiles.oneWindow": return "仅在拥有多个个人资料时可用"
        case "spaces.links", "links.ask", "spaces.buttons": return "仅在启用空间时可用"
        case "sidebar.player": return "仅在边栏显示标题时可用"
        case "tabs.frontBeside": return "仅在“新标签页位置”设为“当前标签页之后”时可用"
        case "newtab.recent", "newtab.arc": return "仅在开启“在悬浮栏中新建标签页”时可用"
        case "links.little.tabs": return "仅在设置来自其他 App 的链接于小窗口打开时可用"
        case "mail.default": return "仅在为邮件链接选择了网页邮箱时可用"
        case "links.peek.stays": return "仅在链接或固定标签页以速览打开时可用"
        case "launcher.key": return "仅在开启“在任意 App 中打开地址栏”时可用"
        case "bookmarks.side": return "仅在显示书签栏且标签栏位于侧边时可用"
        default: return "仅在标签页位于侧边时可用"
        }
    }
}

// MARK: - merged controls

/// Tabs: across the top, a column down either side, or that column as
/// icons only. Reads and writes `sidebar` and `sidebar.position`, as the
/// two switches did, and `sidebar.icons`. Icons only keeps the side the
/// column was on.
enum TabsLayout: String, CaseIterable, Identifiable {
    case top, left, right, icons
    var id: String { rawValue }
    var title: String {
        switch self {
        case .top: return "顶部"
        case .left: return "左侧"
        case .right: return "右侧"
        case .icons: return "仅图标"
        }
    }
}

/// Sleep tabs: Never, or how soon. `tabs.sleep` and `tabs.sleep.pace`.
enum SleepChoice: String, CaseIterable, Identifiable {
    case never, later, normal, sooner
    var id: String { rawValue }
    var title: String { self == .never ? "永不" : pace!.title }
    var pace: SleepPace? { SleepPace(rawValue: rawValue) }
    var detail: String {
        guard let pace else { return "无论搁置多久，每个标签页都会保留其页面状态。" }
        return pace.detail.replacingOccurrences(of: ".", with: "") + ", a tab rests and wakes when you go back to it."
    }
}

/// Float the video on its own: `float.leave` and `float.away`.
enum FloatOwn: String, CaseIterable, Identifiable {
    case never, tabs, tabsOrApps
    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: return "永不"
        case .tabs: return "切换标签页时"
        case .tabsOrApps: return "切换标签页或 App 时"
        }
    }
}

/// Peek at a link: Off, or the click that does it. `links.peek` and
/// `links.peekClick`.
enum PeekChoice: String, CaseIterable, Identifiable {
    case off, shift, optionShift, optionCommand
    var id: String { rawValue }
    var title: String { self == .off ? "关闭" : click!.title }
    var click: PeekClick? { PeekClick(rawValue: rawValue) }
}

extension Preferences {
    var tabsLayout: TabsLayout {
        get { !sidebar ? .top : sideIcons ? .icons : (sidePosition == .right ? .right : .left) }
        set {
            switch newValue {
            case .top:
                sidebar = false
            case .icons:
                sideIcons = true
                sidebar = true
            case .left, .right:
                sidePosition = newValue == .right ? .right : .left
                sideIcons = false
                sidebar = true
            }
        }
    }

    var sleepChoice: SleepChoice {
        get { sleepsTabs ? (SleepChoice(rawValue: sleepPace.rawValue) ?? .normal) : .never }
        set {
            if let pace = newValue.pace { sleepPace = pace; sleepsTabs = true } else { sleepsTabs = false }
        }
    }

    /// Away alone (never seen from the switches, but possible) reads as the
    /// nearest choice that includes it.
    var floatOwn: FloatOwn {
        get { floatsAway ? .tabsOrApps : (floatsOnLeave ? .tabs : .never) }
        set {
            floatsOnLeave = newValue != .never
            floatsAway = newValue == .tabsOrApps
        }
    }

    var pinsKeepSite: Bool {
        get { pinsGoHome || pinsPeek }
        set { pinsGoHome = newValue; pinsPeek = newValue }
    }

    var peekChoice: PeekChoice {
        get { peeksLinks ? (PeekChoice(rawValue: peekClick.rawValue) ?? .shift) : .off }
        set {
            if let click = newValue.click { peekClick = click; peeksLinks = true } else { peeksLinks = false }
        }
    }

    /// Set Up Like Arc: what it turns on, and what was there before, so
    /// Undo can put it back.
    struct ArcSetup {
        /// The three keys the tabs' layout is made of, so Undo puts back
        /// the side and icons a top layout kept underneath.
        var side: (shown: Bool, icons: Bool, position: SidebarPosition)
        var spaces: Bool
        var rows: Bool
        var keep: (home: Bool, peek: Bool)
        var floating: Bool
        /// Arc's habits, added after 1.0.7: tabs that close themselves,
        /// the video that floats out, swipe back closing a link's tab, and
        /// peek. Kept key by key, so Undo puts back the exact choice.
        var life: TabLife
        var float: (leave: Bool, away: Bool)
        var swipeCloses: Bool
        var peek: (on: Bool, click: PeekClick)
    }

    var arcSnapshot: ArcSetup {
        ArcSetup(side: (sidebar, sideIcons, sidePosition), spaces: usesSpaces, rows: listsPins, keep: (pinsGoHome, pinsPeek), floating: floatingNewTab,
                 life: tabLife, float: (floatsOnLeave, floatsAway), swipeCloses: swipeBackCloses, peek: (peeksLinks, peekClick))
    }

    /// Any duration, float or click someone chose counts: Set Up only
    /// turns on what is off, with Arc's own (12 hours, on leaving a tab,
    /// Shift-click), and leaves a choice already made alone.
    var looksLikeArc: Bool {
        tabsLayout == .left && usesSpaces && listsPins && pinsGoHome && pinsPeek && floatingNewTab
            && tabLife != .never && floatOwn != .never && swipeBackCloses && peeksLinks
    }

    /// Turns Arc's way on and says what changed.
    @discardableResult
    func setUpLikeArc() -> [String] {
        var changed: [String] = []
        if tabsLayout != .left { tabsLayout = .left; changed.append("左侧标签栏") }
        if !usesSpaces { usesSpaces = true; changed.append("空间") }
        if !listsPins { listsPins = true; changed.append("固定行") }
        if !(pinsGoHome && pinsPeek) { pinsKeepSite = true; changed.append("固定标签页保留原网站") }
        if !floatingNewTab { floatingNewTab = true; changed.append("悬浮栏新建标签页") }
        if tabLife == .never { tabLife = .halfDay; changed.append("12 小时后关闭标签页") }
        if floatOwn == .never { floatOwn = .tabs; changed.append("自动悬浮视频") }
        if !swipeBackCloses { swipeBackCloses = true; changed.append("轻扫返回以关闭由链接打开的标签页") }
        if !peeksLinks { peekChoice = .shift; changed.append("按住 Shift 点按链接以速览") }
        return changed
    }

    /// Only what differs is written back, so a key Set Up never touched
    /// stays as unwritten as it was.
    func restore(_ before: ArcSetup) {
        if sidePosition != before.side.position { sidePosition = before.side.position }
        if sideIcons != before.side.icons { sideIcons = before.side.icons }
        if sidebar != before.side.shown { sidebar = before.side.shown }
        if usesSpaces != before.spaces { usesSpaces = before.spaces }
        if listsPins != before.rows { listsPins = before.rows }
        if pinsGoHome != before.keep.home { pinsGoHome = before.keep.home }
        if pinsPeek != before.keep.peek { pinsPeek = before.keep.peek }
        if floatingNewTab != before.floating { floatingNewTab = before.floating }
        if tabLife != before.life { tabLife = before.life }
        if floatsOnLeave != before.float.leave { floatsOnLeave = before.float.leave }
        if floatsAway != before.float.away { floatsAway = before.float.away }
        if swipeBackCloses != before.swipeCloses { swipeBackCloses = before.swipeCloses }
        if peekClick != before.peek.click { peekClick = before.peek.click }
        if peeksLinks != before.peek.on { peeksLinks = before.peek.on }
    }

}

/// Set Up Like Arc, wherever it is offered (Settings, the welcome, after
/// Arc's spaces are brought over): what was there before it, for one Undo
/// shared by all three.
@MainActor
final class LikeArc: ObservableObject {
    static let shared = LikeArc()
    @Published private(set) var before: Preferences.ArcSetup?

    /// Sets it up, keeps what was there, and says what changed.
    @discardableResult
    func setUp(_ prefs: Preferences) -> [String] {
        let was = prefs.arcSnapshot
        let changed = prefs.setUpLikeArc()
        if !changed.isEmpty { before = was }
        return changed
    }

    func undo(_ prefs: Preferences) {
        guard let before else { return }
        prefs.restore(before)
        self.before = nil
    }

    /// Undo is there while it is still set up like Arc: changed by hand
    /// since, there is nothing to undo.
    func undoable(_ prefs: Preferences) -> Bool { before != nil && prefs.looksLikeArc }

    static func said(_ changed: [String]) -> String {
        changed.isEmpty ? "已设为 Arc 风格" : "已开启：" + changed.joined(separator: "、")
    }
}

// MARK: - for the bench

extension SettingsIndex {
    /// The merged controls as Settings shows them, and the switches whose
    /// defaults changed: what Tests/settings_layout.py reads back.
    @MainActor static func values(_ prefs: Preferences) -> [String: Any] {
        [
            "tabs.layout": prefs.tabsLayout.rawValue,
            "tabs.sleep": prefs.sleepChoice.rawValue,
            "float.own": prefs.floatOwn.rawValue,
            "pins.keep": prefs.pinsKeepSite,
            "pins.home": prefs.pinsGoHome,
            "pins.peek": prefs.pinsPeek,
            "links.peek": prefs.peekChoice.rawValue,
            "pages.120": prefs.fastPages.rawValue,
            "swipe.history": prefs.holdsHistory,
            "tabs.address": prefs.showsAddress,
            "links.show": prefs.showsLinks,
            "float.flicks": prefs.floatFlicks,
            "arc": prefs.looksLikeArc,
            "profiles.oneWindow": prefs.profilesInOneWindow,
            "tabs.mirror": prefs.mirrorsTabs,
            "sidebar.slides": prefs.slidesColumn,
            "always": [
                "splitView": prefs.splitView, "tabs.groups": prefs.usesTabGroups,
                "panel.sites": prefs.sitesInPanel, "translate": PageTranslator.enabled,
                "tabs.keepAwake": prefs.keepsSitesAwake, "search.sites": prefs.searchesSites,
                "pins.shared": prefs.sharesPins, "pins.numberBack": prefs.pinNumberGoesBack,
                "switcher.keys": prefs.switcherKeys,
            ],
        ]
    }

    /// A merged control moved as Settings moves it. False for an id or a
    /// value it doesn't know.
    @MainActor static func apply(_ id: String, _ value: Any, to prefs: Preferences) -> Bool {
        switch id {
        case "tabs.layout":
            guard let layout = (value as? String).flatMap(TabsLayout.init) else { return false }
            prefs.tabsLayout = layout
        case "tabs.sleep":
            guard let choice = (value as? String).flatMap(SleepChoice.init) else { return false }
            prefs.sleepChoice = choice
        case "float.own":
            guard let choice = (value as? String).flatMap(FloatOwn.init) else { return false }
            prefs.floatOwn = choice
        case "pins.keep":
            guard let on = value as? Bool else { return false }
            prefs.pinsKeepSite = on
        case "tabs.mirror":
            guard let on = value as? Bool else { return false }
            prefs.mirrorsTabs = on
        case "pins.folders":
            guard let on = value as? Bool else { return false }
            prefs.pinFolders = on
        case "sidebar.slides":
            guard let on = value as? Bool else { return false }
            prefs.slidesColumn = on
        case "profiles.oneWindow":
            guard let on = value as? Bool else { return false }
            prefs.profilesInOneWindow = on
        case "links.peek":
            guard let choice = (value as? String).flatMap(PeekChoice.init) else { return false }
            prefs.peekChoice = choice
        case "arc.setup":
            LikeArc.shared.setUp(prefs)
        case "arc.undo":
            LikeArc.shared.undo(prefs)
        default:
            return false
        }
        return true
    }

    static func describe(_ item: SettingsItem) -> [String: Any] {
        ["id": item.id, "page": item.page.rawValue, "group": item.group,
         "groupTitle": group(item.group)?.title ?? "", "title": item.title, "detail": item.detail,
         "keys": item.keys, "findOnly": item.findOnly, "note": item.kind == .note,
         "parent": item.parent ?? ""]
    }
}
