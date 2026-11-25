import SwiftUI

/// Settings › Passwords: the switch for the Mac's Passwords app, and, once
/// on, the pairing — Connect…, the code your Mac shows typed in here, and
/// Disconnect. The code is typed into Search, never into a page.
struct ApplePasswordsCard: View {
    @ObservedObject var prefs: Preferences
    /// Under Settings' own row for the switch: only the pairing, once on.
    var bare = false
    @ObservedObject private var apple = ApplePasswords.shared
    @State private var code = ""
    @FocusState private var typing: Bool

    var body: some View {
        Group {
            if bare {
                if prefs.applePasswords {
                    Rule()
                    pairing
                }
            } else {
                Card {
                    Line("使用 Apple“密码” App 中的密码",
                         "在登录框下方显示“密码” App 中存储的账号和验证码。此集成为非官方实现：Search 使用 Apple 为 Chrome 扩展提供的辅助程序。无痕标签页中停用此功能。") {
                        Switch(on: $prefs.applePasswords)
                    }
                    if prefs.applePasswords {
                        Rule()
                        pairing
                    }
                }
            }
        }
        .onChange(of: apple.state) { _, state in
            code = ""
            if state == .code { typing = true }
        }
    }

    @ViewBuilder private var pairing: some View {
        switch apple.state {
        case .idle, .starting:
            // One row for both, its button kept and only greyed while
            // starting: a start that fails at once leaves it as it was (idea 781).
            if apple.refused {
                Line(apple.trouble ?? "未连接", "Search 启动 Apple 密码辅助程序时，macOS 会立即将其停止。iCloud 密码扩展也需要此辅助程序。") { EmptyView() }
            } else {
                Line(ApplePasswords.title(state: apple.state, trouble: apple.trouble, connecting: apple.connecting),
                     "你的 Mac 会显示一个验证码，请在此输入。每次启动 Search 只需配对一次，且仅在首次需要使用账号时提示：在登录框下方，点按“连接 Apple 密码…”即可输入。") {
                    Pill("连接…") { Task { await apple.connect() } }
                        .disabled(apple.state == .starting)
                }
            }
        case .code, .checking:
            Line("输入 Mac 显示的验证码", apple.state == .checking ? "正在检查…" : "来自“密码”窗口的六位数字") {
                HStack(spacing: 8) {
                    TextField("000000", text: $code)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 70)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Palette.wash, in: Capsule(style: .continuous))
                        .focused($typing)
                        .onChange(of: code) { _, typed in
                            let digits = String(typed.filter(\.isNumber).prefix(6))
                            if digits != typed { code = digits }
                            // Six digits are the whole code: sent without OK.
                            if digits.count == 6 { send() }
                        }
                        .onSubmit(send)
                        .disabled(apple.state == .checking)
                    Pill("OK", filled: true, action: send)
                    Pill("Cancel") { apple.disconnect() }
                }
            }
        case .paired:
            Line("Connected", "保持连接直至退出 Search。账号会显示在登录框下方，并标注为“Apple 密码”；填充前 macOS 可能会要求使用触控 ID 验证。") {
                Pill("Disconnect") { apple.disconnect() }
            }
        }
    }

    private func send() {
        guard code.count == 6, apple.state == .code else { return }
        let typed = code
        code = ""
        Task { await apple.enter(typed) }
    }
}

/// Connect Apple Passwords, from under a sign-in box: a small card of
/// Search's own where the list was, that takes the code your Mac shows and
/// goes once paired, the caret back in the box. Six digits are sent as soon
/// as they are typed. Esc or Cancel stops the helper, its window with it.
struct ApplePairingCard: View {
    @ObservedObject var browser: Browser
    @ObservedObject var apple: ApplePasswords
    let pairing: Browser.ApplePairing
    @State private var code = ""
    @FocusState private var typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "key.icloud")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 22, height: 22)
                    .background(Palette.wash, in: Capsule(style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if apple.state == .code || apple.state == .checking {
                    TextField("000000", text: $code)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 70)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Palette.wash, in: Capsule(style: .continuous))
                        .focused($typing)
                        .disabled(apple.state == .checking)
                        .onChange(of: code) { _, typed in
                            let digits = String(typed.filter(\.isNumber).prefix(6))
                            if digits != typed { code = digits }
                            if digits.count == 6 { send() }
                        }
                        .onSubmit(send)
                } else if !apple.refused, apple.state == .idle || apple.state == .starting {
                    Pill("重试", filled: true) { Task { await apple.connect() } }
                        .disabled(apple.state == .starting)
                }
                Spacer(minLength: 0)
                Pill("Cancel") { browser.endApplePairing(paired: false) }
            }
        }
        .padding(10)
        .frame(width: max(240, min(360, pairing.spot.width)), alignment: .leading)
        .background(Palette.ground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 22, y: 8)
        .offset(x: pairing.spot.minX, y: pairing.spot.maxY + 6)
        .onExitCommand { browser.endApplePairing(paired: false) }
        .onAppear { if apple.state == .code { typing = true } }
        .onChange(of: apple.state) { _, state in
            code = ""
            if state == .code { typing = true }
        }
    }

    private var title: String {
        switch apple.state {
        case .idle: return apple.trouble ?? "未连接"
        case .starting: return apple.connecting ? "正在连接 Apple 密码…" : apple.trouble ?? "正在连接 Apple 密码…"
        case .code: return "输入 Mac 显示的验证码"
        case .checking: return "正在检查…"
        case .paired: return "已连接"
        }
    }

    private var detail: String {
        switch apple.state {
        case .starting: return "你的 Mac 稍后会显示一个六位验证码"
        case .code, .checking: return "输入“密码”窗口中显示的六位验证码。每次启动 Search 只需验证一次。"
        default: return "Apple 密码"
        }
    }

    private func send() {
        guard code.count == 6, apple.state == .code else { return }
        let typed = code
        code = ""
        Task { await apple.enter(typed) }
    }
}
