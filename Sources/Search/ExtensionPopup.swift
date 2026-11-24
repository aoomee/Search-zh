import AppKit
import QuartzCore
import WebKit

// An extension's popup, hosted in a borderless floating NSPanel:
// - Bypasses macOS 26's oversized NSPopover mask so extension UI corners are
//   never sliced off.
// - Waits for WebKit to finish painting at the final size (2x rAF) before
//   fading/scaling in, eliminating the stale 25x25 black-square flash.
// - Presents with macOS 26 native glass chrome + smooth top-anchored pop-in.

@available(macOS 15.4, *)
@MainActor
private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        ExtensionPopup.shared.close()
    }
}

@available(macOS 15.4, *)
@MainActor
final class ExtensionPopup: NSObject, WKUIDelegate, WKNavigationDelegate, NSWindowDelegate {
    static let shared = ExtensionPopup()

    private var panel: PopupPanel?
    private var chrome: NSView?
    private var stage: NSView?
    private var web: WKWebView?
    private var page: PopupPage?
    private var measuring: Timer?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private weak var parentWindow: NSWindow?

    private(set) var extensionID: String?
    private weak var button: NSView?
    private var closedByButton: (id: String, at: Date)?

    private var anchorScreenRect: NSRect = .zero
    private var preferredEdge: NSRectEdge = .minY

    /// The popup's web view, while one is up — for the bench.
    var view: WKWebView? { web }

    /// On screen now.
    var isUp: Bool { panel?.isVisible == true }

    /// Where the last popup was hung from, for the bench.
    private(set) var placement: [String: Any] = [:]

    /// Each extension's stable popup size, so the next opening starts there.
    private static var lastSize: [String: NSSize] = [:]
    private static let minStableWidth: CGFloat = 120
    private static let minStableHeight: CGFloat = 80
    private static let cornerRadius: CGFloat = 16
    private static let anchorGap: CGFloat = 6
    private static let screenMargin: CGFloat = 8

    private var shown = false
    private var revealing = false

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        guard let browser = Browsers.front else { return decisionHandler(.deny) }
        browser.askedForCapture(webView, origin: origin, frame: frame, type: type, decisionHandler: decisionHandler)
    }

    @objc(_webView:requestDisplayCapturePermissionForOrigin:initiatedByFrame:withSystemAudio:decisionHandler:)
    func displayCapture(_ web: WKWebView, origin: WKSecurityOrigin, frame: WKFrameInfo, systemAudio: Bool,
                        decisionHandler: @escaping (Int) -> Void) {
        decisionHandler(ExtensionCapture.shared.displayDecision(for: web))
    }

    func client(of id: String) -> [String: Any]? {
        guard extensionID == id, let url = web?.url else { return nil }
        return ["id": "popup", "url": url.absoluteString, "visible": isUp, "focused": isUp && panel?.isKeyWindow == true]
    }

    func show(_ url: URL, for context: WKWebExtensionContext, from anchor: NSView?, in browser: Browser? = nil) {
        close(immediate: true)
        guard let configuration = context.webViewConfiguration else { return }

        let targetBrowser = browser ?? anchor?.window.flatMap(Browsers.browser(for:))
        let hostWindow = anchor?.window
            ?? targetBrowser?.window
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain && $0.frame.minX > -10_000 })

        let initialSize = ExtensionPopup.lastSize[context.uniqueIdentifier] ?? NSSize(width: 340, height: 260)

        if let anchor, let win = anchor.window {
            let inWindow = anchor.convert(anchor.bounds, to: nil)
            anchorScreenRect = win.convertToScreen(inWindow)
            preferredEdge = .minY
        } else if let win = hostWindow, let content = win.contentView {
            let bounds = content.bounds
            let flipped = content.isFlipped
            let prefs = (targetBrowser ?? Extensions.shared.browser)?.prefs
            let column = prefs?.sidebar == true
            let right = prefs?.sidePosition == .right
            let spot = column
                ? NSRect(x: right ? bounds.maxX - 24 : bounds.minX + 24,
                         y: flipped ? bounds.maxY - 24 : bounds.minY + 24, width: 1, height: 1)
                : NSRect(x: bounds.maxX - 60,
                         y: flipped ? bounds.minY + 40 : bounds.maxY - 40, width: 1, height: 1)
            anchorScreenRect = win.convertToScreen(content.convert(spot, to: nil))
            preferredEdge = column ? (right ? .minX : .maxX) : .minY
        } else {
            anchorScreenRect = NSRect(x: 400, y: 600, width: 24, height: 24)
            preferredEdge = .minY
        }

        // Start WebKit at 25x25 inside an invisible panel so Chrome-style
        // min-content sizing works without ever showing the 25x25 frame.
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 25, height: 25), configuration: configuration)
        web.uiDelegate = self
        web.navigationDelegate = self
        web.load(URLRequest(url: url))

        // Outer macOS 26 glass / vibrancy chrome + clipped content stage.
        let container = NSView(frame: NSRect(origin: .zero, size: initialSize))
        container.wantsLayer = true
        if let layer = container.layer {
            layer.cornerRadius = ExtensionPopup.cornerRadius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
            layer.borderWidth = 0.5
            layer.borderColor = NSColor.labelColor.withAlphaComponent(0.14).cgColor
        }

        let backdrop: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: container.bounds)
            glass.autoresizingMask = [.width, .height]
            glass.cornerRadius = ExtensionPopup.cornerRadius
            backdrop = glass
        } else {
            let effect = NSVisualEffectView(frame: container.bounds)
            effect.autoresizingMask = [.width, .height]
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            backdrop = effect
        }
        container.addSubview(backdrop)

        let stage = NSView(frame: container.bounds)
        stage.autoresizingMask = [.width, .height]
        stage.wantsLayer = true
        if let layer = stage.layer {
            layer.cornerRadius = ExtensionPopup.cornerRadius
            layer.cornerCurve = .continuous
            layer.masksToBounds = true
            layer.backgroundColor = NSColor.white.cgColor
        }
        stage.addSubview(web)
        container.addSubview(stage)

        let frame = frameForSize(initialSize)
        let panel = PopupPanel(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hidesOnDeactivate = true
        panel.contentView = container
        panel.delegate = self
        // Completely invisible until WebKit finishes painting at the full size.
        panel.alphaValue = 0

        self.panel = panel
        self.chrome = container
        self.stage = stage
        self.web = web
        self.parentWindow = hostWindow
        extensionID = context.uniqueIdentifier
        button = anchor != nil && Extensions.shared.isOwnButton(anchor, for: context.uniqueIdentifier) ? anchor : nil

        let page = PopupPage(web: web, browser: targetBrowser)
        self.page = page
        Extensions.shared.controller.didOpenTab(page)

        shown = false
        revealing = false
        placement = anchor.map(ExtensionPopup.describe) ?? ["from": "window"]

        hostWindow?.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        installDismissMonitors()

        // Fallback reveal in case an extension is genuinely tiny or slow.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self, weak panel] in
            guard let self, let panel, panel === self.panel, !self.shown, !self.revealing else { return }
            self.firstMeasure(forceReveal: true)
            self.follow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self, weak panel] in
            guard let self, let panel, panel === self.panel, !self.shown, !self.revealing else { return }
            self.prepareAndReveal()
        }
    }

    private func frameForSize(_ size: NSSize) -> NSRect {
        let mid = NSPoint(x: anchorScreenRect.midX, y: anchorScreenRect.midY)
        let visible = NSScreen.screens.first(where: { $0.frame.contains(mid) })?.visibleFrame
            ?? parentWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let w = min(800, max(25, size.width))
        let h = min(600, max(25, size.height))
        let margin = ExtensionPopup.screenMargin
        let gap = ExtensionPopup.anchorGap

        var x: CGFloat
        var y: CGFloat

        switch preferredEdge {
        case .minX:
            x = anchorScreenRect.minX - gap - w
            y = anchorScreenRect.midY - h / 2
        case .maxX:
            x = anchorScreenRect.maxX + gap
            y = anchorScreenRect.midY - h / 2
        default:
            x = anchorScreenRect.midX - w / 2
            y = anchorScreenRect.minY - gap - h
            if y < visible.minY + margin {
                y = anchorScreenRect.maxY + gap
            }
        }

        x = min(max(x, visible.minX + margin), visible.maxX - margin - w)
        y = min(max(y, visible.minY + margin), visible.maxY - margin - h)
        return NSRect(x: x.rounded(), y: y.rounded(), width: w.rounded(.up), height: h.rounded(.up))
    }

    private func installDismissMonitors() {
        removeDismissMonitors()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.window === panel { return event }
            if let id = self.extensionID, let button = self.button, let win = button.window, event.window === win {
                let spot = button.convert(event.locationInWindow, from: nil)
                if button.bounds.contains(spot) {
                    self.closedByButton = (id, Date())
                }
            }
            self.close()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func removeDismissMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }

    static func describe(_ view: NSView) -> [String: Any] {
        guard let window = view.window, let content = window.contentView else { return ["from": "view", "inWindow": false] }
        let r = view.convert(view.bounds, to: nil)
        var alpha = view.alphaValue
        var up = view.superview
        while let v = up { alpha *= v.alphaValue; up = v.superview }
        return ["from": "view", "inWindow": true, "hidden": view.isHiddenOrHasHiddenAncestor, "alpha": Double(alpha),
                "rect": [Int(r.minX), Int(r.minY), Int(r.width), Int(r.height)],
                "content": [Int(content.bounds.width), Int(content.bounds.height)],
                "onWindow": content.convert(content.bounds, to: nil).intersects(r)]
    }

    /// Resizes WKWebView to the full stage while the panel is still invisible,
    /// waits for 2 animation frames so WebKit's GPU process finishes painting
    /// the full-size layout (preventing the 25x25 black-square flash), and then
    /// runs a smooth macOS 26 pop-in animation.
    private func prepareAndReveal() {
        guard !shown, !revealing, let panel, let stage, let web else { return }
        revealing = true

        // Resize WebKit while panel.alphaValue is still 0.
        web.frame = stage.bounds
        web.autoresizingMask = [.width, .height]
        stage.layoutSubtreeIfNeeded()
        panel.invalidateShadow()

        let finishReveal: @MainActor () -> Void = { [weak self, weak panel] in
            guard let self, let panel, panel === self.panel, !self.shown else { return }
            self.shown = true
            self.revealing = false
            self.animateIn(panel)
        }

        // Wait for 2 rAFs so WebKit commits a painted frame at the full size.
        Task { @MainActor in
            _ = try? await web.callAsyncJavaScript(
                "await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))); return true;",
                arguments: [:],
                in: nil,
                contentWorld: .page
            )
            finishReveal()
        }

        // Safety cap so slow/suspended pages still appear promptly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            finishReveal()
        }
    }

    private func animateIn(_ panel: PopupPanel) {
        guard let layer = chrome?.layer else {
            panel.alphaValue = 1
            return
        }
        if Motion.instant {
            panel.alphaValue = 1
            return
        }

        // Subtle macOS 26 pop-in: scale 0.96 -> 1.0 + translateY -6pt -> 0 + fade 0 -> 1.
        let bounds = layer.bounds
        let cx = bounds.midX
        let topY = bounds.maxY
        let start = CATransform3DConcat(
            CATransform3DMakeTranslation(-cx, -topY, 0),
            CATransform3DConcat(
                CATransform3DMakeScale(0.96, 0.96, 1),
                CATransform3DMakeTranslation(cx, topY + 4, 0)
            )
        )
        let timing = CAMediaTimingFunction(controlPoints: 0.22, 1.0, 0.36, 1.0)
        let duration = Motion.seconds(0.18)

        let anim = CABasicAnimation(keyPath: "transform")
        anim.fromValue = NSValue(caTransform3D: start)
        anim.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        anim.duration = duration
        anim.timingFunction = timing
        layer.add(anim, forKey: "popupReveal")

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = timing
            panel.animator().alphaValue = 1
        }
    }

    private func follow() {
        guard measuring == nil else { return }
        if !shown && !revealing { firstMeasure(forceReveal: false) }
        ticks = 0
        measuring = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.grow() }
        }
    }

    func close(immediate: Bool = false) {
        measuring?.invalidate()
        measuring = nil
        removeDismissMonitors()
        let closing = panel
        let parent = parentWindow
        let wasShown = shown
        forget()
        guard let closing else { return }

        if immediate || !wasShown || Motion.instant {
            parent?.removeChildWindow(closing)
            closing.orderOut(nil)
            closing.close()
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Motion.seconds(0.11)
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                closing.animator().alphaValue = 0
            }, completionHandler: {
                Task { @MainActor in
                    parent?.removeChildWindow(closing)
                    closing.orderOut(nil)
                    closing.close()
                }
            })
        }
    }

    private func forget() {
        if let page { Extensions.shared.controller.didCloseTab(page, windowIsClosing: false) }
        page = nil
        panel = nil
        chrome = nil
        stage = nil
        web = nil
        parentWindow = nil
        extensionID = nil
        button = nil
        shown = false
        revealing = false
    }

    func closes(_ id: String) -> Bool {
        defer { closedByButton = nil }
        if panel != nil, extensionID == id {
            close()
            return true
        }
        guard let closed = closedByButton, closed.id == id else { return false }
        return Date().timeIntervalSince(closed.at) < 1.5
    }

    // MARK: - Sizing (Chrome-compatible Blink auto-size)

    static let preferred = """
    () => {
      const d = document.documentElement, v = document.compatMode === "BackCompat" ? document.body : d;
      if (!v) return null;
      const m = window.__searchSizing || (window.__searchSizing = {});
      const saved = d.getAttribute("style");
      const back = () => saved === null ? d.removeAttribute("style") : d.setAttribute("style", saved);
      const root = getComputedStyle(d), body = document.body && getComputedStyle(document.body);
      const view = root.overflowX === "visible" && root.overflowY === "visible" && body ? body : root;
      const bar = innerWidth - v.clientWidth, barAcross = innerHeight - v.clientHeight;
      const across = view.overflowX === "scroll" ? barAcross : 0;
      let gutter = view.overflowY === "scroll" ? bar : 0;
      const box = d.getBoundingClientRect();
      let w;
      if (Math.abs(box.width - v.clientWidth) > 1) w = m.w = box.width;
      else if (m.w && Math.abs(m.w - v.clientWidth) <= 1) w = m.w;
      else {
        d.style.setProperty("width", "min-content", "important");
        const narrowest = d.getBoundingClientRect().width;
        back();
        w = narrowest >= 100 ? narrowest : Math.max(narrowest, d.scrollWidth);
      }
      let width;
      const lay = () => {
        back();
        width = Math.min(800, Math.max(25, Math.ceil(w + gutter)));
        d.style.setProperty("width", (width - gutter) + "px", "important");
        let h = d.getBoundingClientRect().height;
        if (Math.abs(h - innerHeight) > 1) m.h = h;
        else if (m.h && Math.abs(m.h - innerHeight) <= 1) h = m.h;
        else {
          d.style.setProperty("height", "auto", "important");
          d.style.setProperty("min-height", "0", "important");
          h = d.getBoundingClientRect().height;
        }
        return h;
      };
      let h = lay();
      if (gutter !== bar && h + across > 600) { gutter = bar; h = lay(); }
      back();
      return [width, Math.min(600, Math.max(25, Math.ceil(h + across)))];
    }
    """

    @objc(_webView:navigationDidFinishDocumentLoad:)
    func webView(_ webView: WKWebView, navigationDidFinishDocumentLoad navigation: WKNavigation?) {
        guard webView === web else { return }
        firstMeasure(forceReveal: false)
    }

    private func firstMeasure(forceReveal: Bool) {
        guard let web, !shown, !revealing else { return }
        web.evaluateJavaScript("(\(ExtensionPopup.preferred))()") { [weak self] value, _ in
            MainActor.assumeIsolated {
                guard let self, web === self.web, !self.shown, !self.revealing else { return }
                guard let pair = value as? [Double], pair.count == 2 else {
                    if forceReveal { self.prepareAndReveal() }
                    return
                }
                let measured = NSSize(width: pair[0], height: pair[1])
                let isStable = measured.width >= ExtensionPopup.minStableWidth && measured.height >= ExtensionPopup.minStableHeight
                if !isStable && !forceReveal {
                    self.follow()
                    return
                }
                self.apply(measured, allowReveal: true)
            }
        }
    }

    private func apply(_ size: NSSize, allowReveal: Bool = true) {
        guard let panel, let chrome, let stage else { return }
        let isStable = size.width >= ExtensionPopup.minStableWidth && size.height >= ExtensionPopup.minStableHeight
        if !shown && !isStable && !allowReveal { return }

        let target = NSSize(
            width: min(800, max(25, size.width.rounded(.up))),
            height: min(600, max(25, size.height.rounded(.up)))
        )
        let nextFrame = frameForSize(target)
        if abs(nextFrame.width - panel.frame.width) > 1 || abs(nextFrame.height - panel.frame.height) > 1 ||
           abs(nextFrame.origin.x - panel.frame.origin.x) > 1 || abs(nextFrame.origin.y - panel.frame.origin.y) > 1 {
            panel.setFrame(nextFrame, display: true, animate: false)
            chrome.frame = NSRect(origin: .zero, size: nextFrame.size)
            stage.frame = chrome.bounds
            if shown || revealing {
                web?.frame = stage.bounds
            }
            panel.invalidateShadow()
        }
        if isStable, let id = extensionID {
            ExtensionPopup.lastSize[id] = target
        }
        if allowReveal && !shown && !revealing {
            prepareAndReveal()
        }
    }

    static let reach = """
    ((key) => {
      const d = document.documentElement, v = document.compatMode === "BackCompat" ? document.body : d;
      if (!v) return null;
      if (key === "height") return d.scrollHeight;
      const own = d.getBoundingClientRect().width, gutter = innerWidth - v.clientWidth;
      if (own > v.clientWidth + 1) return own + gutter;
      const saved = d.getAttribute("style");
      d.style.setProperty("width", "min-content", "important");
      const narrowest = d.getBoundingClientRect().width;
      saved === null ? d.removeAttribute("style") : d.setAttribute("style", saved);
      return (narrowest >= 100 ? narrowest : Math.max(narrowest, d.scrollWidth)) + gutter;
    })
    """

    private var ticks = 0
    private func grow() {
        guard let web, let panel else { return }
        ticks += 1
        if !shown {
            if !revealing { firstMeasure(forceReveal: ticks >= 3) }
            return
        }
        if ticks <= 8 {
            web.evaluateJavaScript("(\(ExtensionPopup.preferred))()") { [weak self] value, _ in
                MainActor.assumeIsolated {
                    guard let self, let pair = value as? [Double], pair.count == 2 else { return }
                    let wanted = NSSize(width: pair[0], height: pair[1])
                    let now = panel.frame.size
                    if abs(wanted.width - now.width) > 2 || abs(wanted.height - now.height) > 2 {
                        self.apply(wanted)
                    }
                }
            }
            return
        }
        if ticks > 24, ticks % 4 != 0 { return }
        web.evaluateJavaScript("[\(ExtensionPopup.reach)('width'), (() => { const d = document.documentElement; return d && d.scrollHeight > d.clientHeight ? d.scrollHeight : 0; })(), (() => { const m = window.__searchSizing || (window.__searchSizing = {}), d = document.documentElement, v = document.compatMode === 'BackCompat' ? document.body : d, w = d.getBoundingClientRect().width, gutter = innerWidth - v.clientWidth; if (Math.abs(w - v.clientWidth) > 1) return (m.w = w) + gutter; return m.w && Math.abs(m.w - v.clientWidth) <= 1 ? m.w + gutter : 0; })()]") { value, _ in
            MainActor.assumeIsolated {
                guard let pair = value as? [Double], pair.count == 3 else { return }
                let now = panel.frame.size
                let width = pair[2] > 0 ? max(25, pair[2].rounded(.up)) : max(now.width, pair[0])
                let wanted = NSSize(width: min(800, width), height: min(600, max(now.height, pair[1])))
                if abs(wanted.width - now.width) > 1 || abs(wanted.height - now.height) > 1 {
                    self.apply(wanted)
                }
            }
        }
    }

    // MARK: - Delegates

    func webViewDidClose(_ webView: WKWebView) { close() }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { follow() }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, (try? Extensions.mayOpen(url)) != nil {
            Extensions.shared.browser?.open(url, foreground: true)
        }
        close()
        return nil
    }

    func windowDidResignKey(_ notification: Notification) {
        guard (notification.object as? PopupPanel) === panel else { return }
        close()
    }
}

/// The popup page, as WebKit finds it: in the browser's window, but not
/// among its tabs — which is where Chrome puts a popup too.
@available(macOS 15.4, *)
@MainActor
final class PopupPage: NSObject, WKWebExtensionTab {
    weak var web: WKWebView?
    weak var browser: Browser?

    init(web: WKWebView, browser: Browser? = nil) {
        self.web = web
        self.browser = browser
    }

    func window(for context: WKWebExtensionContext) -> (any WKWebExtensionWindow)? {
        (browser ?? Extensions.shared.browser).map(Extensions.shared.window(of:))
    }
    func indexInWindow(for context: WKWebExtensionContext) -> Int { NSNotFound }
    func webView(for context: WKWebExtensionContext) -> WKWebView? { web }
    func title(for context: WKWebExtensionContext) -> String? { web?.title }
    func url(for context: WKWebExtensionContext) -> URL? { web?.url }
    func isLoadingComplete(for context: WKWebExtensionContext) -> Bool { !(web?.isLoading ?? false) }
    func isSelected(for context: WKWebExtensionContext) -> Bool { false }
    func close(for context: WKWebExtensionContext) async throws { ExtensionPopup.shared.close() }
}
