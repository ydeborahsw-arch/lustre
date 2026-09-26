import UIKit
import QuickLook
import WebKit


final class LXLightbox: UIView, UIScrollViewDelegate {
    private let scroll = UIScrollView()
    private let iv = UIImageView()
    private let dim = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var dragStart: CGPoint = .zero

    static weak var live: LXLightbox?

    static func show(_ url: URL, host: UIView) {
        live?.close(animated: false)
        let v = LXLightbox(frame: host.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(v)
        LXStage.settle(host)
        live = v
        v.load(url)
        v.dim.alpha = 0
        v.scroll.alpha = 0
        UIView.animate(withDuration: 0.22) { v.dim.alpha = 1; v.scroll.alpha = 1 }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        dim.frame = bounds
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dim.backgroundColor = .black
        addSubview(dim)

        scroll.frame = bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.delegate = self
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.backgroundColor = .clear
        addSubview(scroll)

        iv.frame = scroll.bounds
        iv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        scroll.addSubview(iv)

        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
        spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin,
                                    .flexibleLeftMargin, .flexibleRightMargin]
        spinner.color = UIColor(white: 1, alpha: 0.7)
        spinner.startAnimating()
        addSubview(spinner)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        let dbl = UITapGestureRecognizer(target: self, action: #selector(onDouble))
        dbl.numberOfTapsRequired = 2
        tap.require(toFail: dbl)
        addGestureRecognizer(tap)
        addGestureRecognizer(dbl)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan))
        pan.delegate = nil
        scroll.addGestureRecognizer(pan)
        pan.require(toFail: scroll.panGestureRecognizer)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func load(_ url: URL) {
        if let hit = LXAttImage.cache.object(forKey: url.absoluteString as NSString) {
            iv.image = hit; spinner.stopAnimating(); return
        }
        Task { [weak self] in
            guard let (d, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let img = UIImage(data: d) else {
                await MainActor.run { self?.spinner.stopAnimating() }
                return
            }
            await MainActor.run {
                self?.iv.image = img
                self?.spinner.stopAnimating()
            }
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { iv }

    @objc private func onTap() { close(animated: true) }

    @objc private func onDouble(_ g: UITapGestureRecognizer) {
        if scroll.zoomScale > 1 {
            scroll.setZoomScale(1, animated: true)
        } else {
            let p = g.location(in: iv)
            let side = bounds.width / 2.5
            scroll.zoom(to: CGRect(x: p.x - side / 2, y: p.y - side / 2, width: side, height: side), animated: true)
        }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard scroll.zoomScale <= 1.01 else { return }
        let t = g.translation(in: self)
        switch g.state {
        case .began: dragStart = t
        case .changed:
            let dy = t.y - dragStart.y
            scroll.transform = CGAffineTransform(translationX: 0, y: dy)
            dim.alpha = max(0.2, 1 - abs(dy) / 420)
        case .ended, .cancelled:
            let dy = t.y - dragStart.y
            let v = g.velocity(in: self).y
            if abs(dy) > 110 || abs(v) > 900 {
                let out = dy >= 0 ? bounds.height : -bounds.height
                UIView.animate(withDuration: 0.2, animations: {
                    self.scroll.transform = CGAffineTransform(translationX: 0, y: out)
                    self.dim.alpha = 0
                }, completion: { _ in self.removeFromSuperview() })
            } else {
                UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.85,
                               initialSpringVelocity: 0, options: [.allowUserInteraction]) {
                    self.scroll.transform = .identity
                    self.dim.alpha = 1
                }
            }
        default: break
        }
    }

    func close(animated: Bool) {
        guard animated else { removeFromSuperview(); return }
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }, completion: { _ in self.removeFromSuperview() })
    }
}

final class LXFilePreview: NSObject, QLPreviewControllerDataSource {
    static let shared = LXFilePreview()
    private var local: URL?

    func open(url: URL, name: String) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lx-preview", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = name.isEmpty ? "file" : name.replacingOccurrences(of: "/", with: "_")
        let dst = dir.appendingPathComponent(safe)
        if FileManager.default.fileExists(atPath: dst.path) { present(dst); return }
        Task { [weak self] in
            guard let (d, resp) = try? await URLSession.shared.data(from: url),
                  (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            try? d.write(to: dst)
            await MainActor.run { self?.present(dst) }
        }
    }

    private func present(_ u: URL) {
        if ["html", "htm"].contains(u.pathExtension.lowercased()) {
            let nav = UINavigationController(rootViewController: LXHTMLViewer(file: u))
            nav.modalPresentationStyle = .pageSheet
            if let sh = nav.sheetPresentationController {
                sh.detents = [.medium(), .large()]
                sh.selectedDetentIdentifier = .medium
                sh.prefersGrabberVisible = true
                sh.prefersScrollingExpandsWhenScrolledToEdge = true
            }
            DrawerPlugin.topVC()?.present(nav, animated: true)
            return
        }
        local = u
        let vc = QLPreviewController()
        vc.dataSource = self
        DrawerPlugin.topVC()?.present(vc, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { local == nil ? 0 : 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        (local ?? URL(fileURLWithPath: "/dev/null")) as QLPreviewItem
    }
}

final class LXHTMLViewer: UIViewController {
    private let file: URL
    private let web: WKWebView

    init(file: URL) {
        self.file = file
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        cfg.allowsInlineMediaPlayback = true
        web = WKWebView(frame: .zero, configuration: cfg)
        super.init(nibName: nil, bundle: nil)
        title = file.lastPathComponent
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 0925 她的单:底部升起的小卡不用纯黑,跟模型小卡同色(实测 #0E0E10)
        view.backgroundColor = LXSheetInk.dark ? UIColor(red: 14/255, green: 14/255, blue: 16/255, alpha: 1) : .systemBackground
        web.frame = view.bounds
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.isOpaque = false
        view.addSubview(web)
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .action, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            let ac = UIActivityViewController(activityItems: [self.file], applicationActivities: nil)
            ac.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
            self.present(ac, animated: true)
        })
        web.loadFileURL(file, allowingReadAccessTo: file.deletingLastPathComponent())
    }
}

final class LXToast: UIView {
    private static weak var live: LXToast?

    static func show(_ text: String, host: UIView?) {
        guard let host = host, !text.isEmpty else { return }
        live?.removeFromSuperview()
        let v = LXToast(text: text)
        host.addSubview(v)
        LXStage.settle(host)
        NSLayoutConstraint.activate([
            v.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            v.bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -96),
            v.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 24),
            v.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -24),
        ])
        live = v
        v.alpha = 0
        UIView.animate(withDuration: 0.18) { v.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak v] in
            guard let v = v, v.superview != nil else { return }
            UIView.animate(withDuration: 0.22, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
        }
    }

    private init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        backgroundColor = UIColor(white: 0.04, alpha: 0.95)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = text
        l.textColor = .white
        l.font = LXBubbleCell.bodyFont().withSize(14)
        l.numberOfLines = 3
        l.textAlignment = .center
        addSubview(l)
        NSLayoutConstraint.activate([
            l.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            l.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            l.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            l.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// 0925 她:长按 → Select text 用底部升起的深色玻璃小卡(跟模型小卡同一个 LXCardSheet),不要屏幕正中那张卡。
/// 字框高度 = 文字实际排出来的高度,超过屏高 62% 封顶、在卡里滚;不默认全选,她自己选。
enum LXSelectText {
    static func show(_ text: String, host: UIView?, theme: LXChatTheme) {
        guard let host = host, !text.isEmpty else { return }
        let tv = UITextView()
        tv.text = text
        tv.isEditable = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textColor = LXSheetInk.text
        tv.font = LXBubbleCell.bodyFont()
        tv.textContainerInset = UIEdgeInsets(top: 2, left: 4, bottom: 6, right: 4)
        let w = max(1, host.bounds.width - 32)
        let fit = ceil(tv.sizeThatFits(CGSize(width: w, height: .greatestFiniteMagnitude)).height)
        let maxH = floor(host.bounds.height * 0.62)
        tv.isScrollEnabled = fit > maxH
        tv.heightAnchor.constraint(equalToConstant: min(fit, maxH)).isActive = true
        _ = LXCardSheet(host: host, title: "Select text", build: { $0.content.addArrangedSubview(tv) })
        LXStage.settle(host)
    }
}

final class LXTerminalVC: UIViewController, UITextViewDelegate {
    private let theme = ChatListPlugin.live?.theme ?? LXChatTheme()
    private let tabsScroll = UIScrollView()
    private let tabsStack = UIStackView()
    private let screen = UITextView()
    private let input = UITextView()
    private let inputPh = UILabel()
    private let sendB = UIButton(type: .system)
    private var inputHC: NSLayoutConstraint!
    private var windows: [(i: Int, label: String)] = []
    private var win = UserDefaults.standard.integer(forKey: "lx.term.win")
    private var timer: Timer?
    private var lastText = ""
    private var inflight = false

    private static func url(_ path: String) -> URL? {
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: LustreConfig.origin + "/term/api/" + path + (path.contains("?") ? "&" : "?") + "auth=" + tok)
    }
    private static func get(_ path: String, _ done: @escaping ([String: Any]?, Int) -> Void) {
        guard let u = url(path) else { return }
        var r = URLRequest(url: u)
        r.timeoutInterval = 8
        r.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: r) { d, resp, _ in
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done(obj, (resp as? HTTPURLResponse)?.statusCode ?? 0) }
        }.resume()
    }
    private static func post(_ path: String, _ body: [String: Any], timeout: TimeInterval = 8,
                             _ done: (([String: Any]?) -> Void)? = nil) {
        guard let u = url(path) else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = timeout
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r) { d, _, _ in
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done?(obj) }
        }.resume()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.bg
        let mono = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let close = circle("xmark") { [weak self] in self?.dismiss(animated: true) }
        let login = circle("key") { [weak self] in self?.startLogin() }
        let title = UILabel()
        title.text = "Terminal"
        title.font = LXDrawerTint.font(17, wght: 600)
        title.textColor = theme.aiFg

        tabsScroll.showsHorizontalScrollIndicator = false
        tabsScroll.alwaysBounceVertical = false
        tabsStack.axis = .horizontal
        tabsStack.spacing = 8
        tabsStack.translatesAutoresizingMaskIntoConstraints = false
        tabsScroll.addSubview(tabsStack)

        screen.isEditable = false
        screen.isSelectable = true
        screen.backgroundColor = .clear
        screen.font = mono
        screen.textColor = theme.aiFg
        screen.dataDetectorTypes = [.link]
        screen.alwaysBounceVertical = true
        screen.keyboardDismissMode = .interactive
        screen.textContainerInset = UIEdgeInsets(top: 8, left: 14, bottom: 12, right: 14)
        screen.delegate = self
        screen.text = "连接中…"

        let keys: [(String, String)] = [("上翻", "PPage"), ("下翻", "NPage"), ("Ctrl+C", "C-c"), ("Esc", "Escape"),
                                        ("↑", "Up"), ("↓", "Down"), ("Tab", "Tab"), ("回车", "Enter")]
        let keyRow = UIStackView()
        keyRow.axis = .horizontal
        keyRow.spacing = 6
        keyRow.distribution = .fillProportionally
        for (t, k) in keys {
            let b = UIButton(type: .system)
            b.setTitle(t, for: .normal)
            b.titleLabel?.font = LXDrawerTint.font(13, wght: 500)
            b.setTitleColor(theme.aiFg, for: .normal)
            b.backgroundColor = theme.segTrack
            b.layer.cornerRadius = 14
            b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            b.addAction(UIAction { [weak self] _ in self?.sendKey(k) }, for: .touchUpInside)
            keyRow.addArrangedSubview(b)
        }
        let keyScroll = UIScrollView()
        keyScroll.showsHorizontalScrollIndicator = false
        keyRow.translatesAutoresizingMaskIntoConstraints = false
        keyScroll.addSubview(keyRow)

        let box = UIView()
        box.backgroundColor = theme.cardBg
        box.layer.cornerRadius = 20
        box.layer.cornerCurve = .continuous
        box.layer.borderWidth = 1
        box.layer.borderColor = theme.hairline.cgColor
        input.font = LXBubbleCell.bodyFont()
        input.textColor = theme.aiFg
        input.backgroundColor = .clear
        input.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 4)
        input.delegate = self
        input.keyboardAppearance = RPSpec.moonState == "day" ? .light : .dark
        inputPh.text = "发到这个窗口…"
        inputPh.font = input.font
        inputPh.textColor = theme.faint
        sendB.setImage(UIImage(systemName: "arrow.up", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        sendB.tintColor = theme.accentFg
        sendB.backgroundColor = theme.accent
        sendB.layer.cornerRadius = 16
        sendB.addAction(UIAction { [weak self] _ in self?.sendText() }, for: .touchUpInside)

        for v in [close, login, title, tabsScroll, screen, keyScroll, box] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v)
        }
        for v in [input, inputPh, sendB] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; box.addSubview(v) }
        inputHC = input.heightAnchor.constraint(equalToConstant: 42)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            login.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            login.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            title.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tabsScroll.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 10),
            tabsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabsScroll.heightAnchor.constraint(equalToConstant: 34),
            tabsStack.topAnchor.constraint(equalTo: tabsScroll.contentLayoutGuide.topAnchor),
            tabsStack.bottomAnchor.constraint(equalTo: tabsScroll.contentLayoutGuide.bottomAnchor),
            tabsStack.leadingAnchor.constraint(equalTo: tabsScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            tabsStack.trailingAnchor.constraint(equalTo: tabsScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            tabsStack.heightAnchor.constraint(equalTo: tabsScroll.frameLayoutGuide.heightAnchor),
            screen.topAnchor.constraint(equalTo: tabsScroll.bottomAnchor, constant: 6),
            screen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            screen.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyScroll.topAnchor.constraint(equalTo: screen.bottomAnchor, constant: 4),
            keyScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyScroll.heightAnchor.constraint(equalToConstant: 34),
            keyRow.topAnchor.constraint(equalTo: keyScroll.contentLayoutGuide.topAnchor),
            keyRow.bottomAnchor.constraint(equalTo: keyScroll.contentLayoutGuide.bottomAnchor),
            keyRow.leadingAnchor.constraint(equalTo: keyScroll.contentLayoutGuide.leadingAnchor, constant: 12),
            keyRow.trailingAnchor.constraint(equalTo: keyScroll.contentLayoutGuide.trailingAnchor, constant: -12),
            keyRow.heightAnchor.constraint(equalTo: keyScroll.frameLayoutGuide.heightAnchor),
            box.topAnchor.constraint(equalTo: keyScroll.bottomAnchor, constant: 8),
            box.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            box.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            box.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8),
            input.topAnchor.constraint(equalTo: box.topAnchor, constant: 2),
            input.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2),
            input.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 2),
            input.trailingAnchor.constraint(equalTo: sendB.leadingAnchor, constant: -4),
            inputHC,
            inputPh.leadingAnchor.constraint(equalTo: input.leadingAnchor, constant: 12),
            inputPh.centerYAnchor.constraint(equalTo: input.topAnchor, constant: 21),
            sendB.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -7),
            sendB.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -7),
            sendB.widthAnchor.constraint(equalToConstant: 32),
            sendB.heightAnchor.constraint(equalToConstant: 32),
        ])
        loadWindows()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        timer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.3
        timer = t
        tick()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate(); timer = nil
    }

    private func circle(_ sym: String, _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        b.tintColor = theme.hdrBtnFg
        b.backgroundColor = theme.hdrBtnBg
        b.layer.cornerRadius = 18
        b.layer.borderWidth = 1
        b.layer.borderColor = theme.hdrRing.cgColor
        b.widthAnchor.constraint(equalToConstant: 36).isActive = true
        b.heightAnchor.constraint(equalToConstant: 36).isActive = true
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }

    private func loadWindows() {
        Self.get("windows") { [weak self] obj, _ in
            guard let s = self, let arr = obj?["windows"] as? [[String: Any]] else { return }
            s.windows = arr.compactMap { d in
                guard let i = (d["i"] as? NSNumber)?.intValue else { return nil }
                return (i, (d["label"] as? String) ?? "窗口 \(i)")
            }
            if !s.windows.contains(where: { $0.i == s.win }) { s.win = s.windows.first?.i ?? 0 }
            s.paintTabs()
        }
    }

    private func paintTabs() {
        tabsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for w in windows {
            let b = UIButton(type: .system)
            b.setTitle(w.label, for: .normal)
            b.titleLabel?.font = LXDrawerTint.font(13, wght: w.i == win ? 600 : 400)
            let on = w.i == win
            b.setTitleColor(on ? theme.accentFg : theme.aiFg, for: .normal)
            b.backgroundColor = on ? theme.accent : theme.segTrack
            b.layer.cornerRadius = 17
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            b.addAction(UIAction { [weak self] _ in self?.pick(w.i) }, for: .touchUpInside)
            tabsStack.addArrangedSubview(b)
        }
    }

    private func pick(_ i: Int) {
        guard i != win else { return }
        win = i
        UserDefaults.standard.set(i, forKey: "lx.term.win")
        lastText = ""
        screen.text = "连接中…"
        paintTabs()
        tick(forceBottom: true)
    }

    private var atBottom: Bool {
        screen.contentSize.height - screen.contentOffset.y - screen.bounds.height < 40
    }

    private func tick(forceBottom: Bool = false, forceTop: Bool = false) {
        let forced = forceBottom || forceTop
        guard !inflight || forced else { return }
        if !forced, screen.isTracking || screen.isDragging || screen.isDecelerating { return }
        if !forced, screen.selectedRange.length > 0 { return }
        inflight = true
        let w = win
        Self.get("peek?window=\(w)&lines=2000") { [weak self] obj, code in
            guard let s = self else { return }
            s.inflight = false
            guard s.win == w else { return }
            if code == 404 { s.setScreen("这个窗口现在没有在运行。", bottom: true); return }
            guard let text = obj?["text"] as? String else { return }
            guard text != s.lastText else { return }
            if !forced, s.screen.isTracking || s.screen.isDragging || s.screen.isDecelerating || s.screen.selectedRange.length > 0 { return }
            s.lastText = text
            s.setScreen(text.isEmpty ? "(空)" : text, bottom: forceBottom || (!forceTop && s.atBottom), top: forceTop)
        }
    }

    private func setScreen(_ text: String, bottom: Bool, top: Bool = false) {
        let off = top ? CGPoint(x: 0, y: -screen.adjustedContentInset.top) : screen.contentOffset
        UIView.performWithoutAnimation {
            screen.text = text
            screen.layoutIfNeeded()
            if bottom {
                let y = max(-screen.adjustedContentInset.top, screen.contentSize.height - screen.bounds.height + screen.adjustedContentInset.bottom)
                screen.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            } else {
                screen.setContentOffset(off, animated: false)
            }
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === screen else { return }
        let top = -screen.adjustedContentInset.top
        let bottom = screen.contentSize.height - screen.bounds.height + screen.adjustedContentInset.bottom
        if screen.contentOffset.y < top - 60 { sendKey("PPage") }
        else if screen.contentOffset.y > max(top, bottom) + 60 { sendKey("NPage") }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === input else { return }
        inputPh.isHidden = !input.text.isEmpty
        let h = min(120, max(42, input.sizeThatFits(CGSize(width: input.bounds.width, height: .greatestFiniteMagnitude)).height))
        if abs(inputHC.constant - h) > 0.5 { inputHC.constant = h; view.layoutIfNeeded() }
    }

    private func sendText() {
        let t = input.text ?? ""
        guard !t.isEmpty else { sendKey("Enter"); return }
        input.text = ""
        textViewDidChange(input)
        Self.post("input", ["window": win, "text": t, "enter": true]) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self?.tick(forceBottom: true) }
        }
    }

    private func sendKey(_ k: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Self.post("key", ["window": win, "key": k]) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if k == "PPage" { self?.tick(forceTop: true) } else { self?.tick(forceBottom: true) }
            }
        }
    }

    private func startLogin() {
        LXToast.show("正在打开登录…", host: view)
        Self.post("login/start", ["window": 0], timeout: 30) { [weak self] obj in
            guard let s = self else { return }
            if let u = obj?["url"] as? String, !u.isEmpty { s.showLoginURL(u); return }
            let msg = (obj?["msg"] as? String) ?? "没拿到授权网址"
            let a = UIAlertController(title: "登录", message: msg, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "好", style: .cancel))
            s.present(a, animated: true)
        }
    }

    private func showLoginURL(_ u: String) {
        let a = UIAlertController(title: "登录", message: "先打开授权页,在那边拿到代码,再回来填。", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "打开授权页", style: .default) { [weak self] _ in
            if let url = URL(string: u) { UIApplication.shared.open(url) }
            self?.askCode()
        })
        a.addAction(UIAlertAction(title: "复制链接", style: .default) { [weak self] _ in
            UIPasteboard.general.string = u
            LXToast.show("链接已复制", host: self?.view)
            self?.askCode()
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }

    private func askCode() {
        let a = UIAlertController(title: "填代码", message: "把授权页给的代码粘进来", preferredStyle: .alert)
        a.addTextField { $0.placeholder = "代码"; $0.autocorrectionType = .no; $0.autocapitalizationType = .none }
        a.addAction(UIAlertAction(title: "提交", style: .default) { [weak self, weak a] _ in
            let code = a?.textFields?.first?.text ?? ""
            LXToast.show("提交中…", host: self?.view)
            Self.post("login/code", ["window": 0, "code": code], timeout: 40) { obj in
                guard let s = self else { return }
                let ok = (obj?["ok"] as? Bool) ?? false
                let msg = (obj?["msg"] as? String) ?? (ok ? "登录成功" : "没等到结果")
                let r = UIAlertController(title: ok ? "登录成功" : "没成功", message: ok ? nil : msg, preferredStyle: .alert)
                if !ok { r.addAction(UIAlertAction(title: "重填", style: .default) { _ in s.askCode() }) }
                r.addAction(UIAlertAction(title: "好", style: .cancel))
                s.present(r, animated: true)
            }
        })
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(a, animated: true)
    }
}

final class LXArchiveVC: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private let theme = ChatListPlugin.live?.theme ?? LXChatTheme()
    private let search = UISearchBar()
    private let table = UITableView(frame: .zero, style: .plain)
    private let hint = UILabel()
    private var items: [[String: Any]] = []
    private var stars: [[String: Any]] = []
    private var query = ""
    private var debounce: DispatchWorkItem?
    private let tdf: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d HH:mm"
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return f
    }()

    private static func get(_ path: String, _ done: @escaping ([String: Any]?) -> Void) {
        guard let u = URL(string: LustreConfig.apiBase + path) else { return }
        var r = URLRequest(url: u)
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 20
        URLSession.shared.dataTask(with: r) { d, _, _ in
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = theme.bg
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        close.tintColor = theme.hdrBtnFg
        close.backgroundColor = theme.hdrBtnBg
        close.layer.cornerRadius = 18
        close.layer.borderWidth = 1
        close.layer.borderColor = theme.hdrRing.cgColor
        close.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        let title = UILabel()
        title.text = "Archive"
        title.font = LXDrawerTint.font(17, wght: 600)
        title.textColor = theme.aiFg

        search.searchBarStyle = .minimal
        search.placeholder = "搜全部聊天记录"
        search.delegate = self
        search.searchTextField.textColor = theme.aiFg
        search.searchTextField.backgroundColor = theme.cardBg
        search.keyboardAppearance = RPSpec.moonState == "day" ? .light : .dark

        table.backgroundColor = .clear
        table.separatorColor = theme.hairline
        table.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.register(UITableViewCell.self, forCellReuseIdentifier: "a")

        hint.font = LXDrawerTint.font(13)
        hint.textColor = theme.faint
        hint.textAlignment = .center
        hint.numberOfLines = 0
        hint.text = "读取中…"

        for v in [close, title, search, table, hint] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            close.widthAnchor.constraint(equalToConstant: 36),
            close.heightAnchor.constraint(equalToConstant: 36),
            title.centerYAnchor.constraint(equalTo: close.centerYAnchor),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            search.topAnchor.constraint(equalTo: close.bottomAnchor, constant: 8),
            search.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            search.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            table.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 4),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hint.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 40),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
        loadStars()
    }

    private func loadStars() {
        Self.get("/app/stars?limit=500") { [weak self] obj in
            guard let s = self else { return }
            s.stars = (obj?["messages"] as? [[String: Any]]) ?? []
            if s.query.isEmpty { s.show(s.stars, empty: obj == nil ? "读不出来。" : "还没有收藏。长按消息可以收藏。") }
        }
    }

    private func show(_ list: [[String: Any]], empty: String) {
        items = list
        hint.text = empty
        hint.isHidden = !list.isEmpty
        table.reloadData()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debounce?.cancel()
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        query = q
        if q.isEmpty { show(stars, empty: "还没有收藏。长按消息可以收藏。"); return }
        let w = DispatchWorkItem { [weak self] in self?.runSearch(q) }
        debounce = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        let q = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { runSearch(q) }
    }

    private func runSearch(_ q: String) {
        hint.text = "搜索中…"; hint.isHidden = false
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        Self.get("/app/search?q=\(enc)&limit=200") { [weak self] obj in
            guard let s = self, s.query == q else { return }
            s.show((obj?["messages"] as? [[String: Any]]) ?? [], empty: "没搜到「\(q)」。")
        }
    }

    private func sessionOf(_ m: [String: Any]) -> String {
        let sid = ((m["meta"] as? [String: Any])?["api_session"] as? String) ?? ""
        return sid.isEmpty ? "__legacy__" : sid
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let c = tableView.dequeueReusableCell(withIdentifier: "a", for: indexPath)
        let m = items[indexPath.row]
        c.backgroundColor = .clear
        let bg = UIView(); bg.backgroundColor = theme.segTrack
        c.selectedBackgroundView = bg
        let from = (m["from"] as? String) ?? ""
        let sid = sessionOf(m)
        let line = sid == "yan-main" ? LXNick.yan : (sid == "__legacy__" ? LXNick.zhao : "会话")
        let who = from == "human" ? "你" : line
        let kind = (m["kind"] as? String) ?? ""
        let ts = ((m["ts"] as? String) ?? "").replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        let d = ISO8601DateFormatter().date(from: ts)
        // 0925 她的单:一人一个对话,AI 说的话不再"名字·名字"重复;她自己说的留"你 · 对方"标明在哪条线
        var head = who == line ? who : "\(who) · \(line)"
        if kind == "thinking" { head += " · 思考" }
        if let d = d { head += " · " + tdf.string(from: d) }
        var body = ((m["text"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty { body = "[附件]" }
        if body.count > 240 { body = String(body.prefix(240)) + "…" }
        let a = NSMutableAttributedString(string: head + "\n", attributes: [
            .font: LXDrawerTint.font(11.5), .foregroundColor: theme.faint])
        let ps = NSMutableParagraphStyle(); ps.lineSpacing = 3; ps.paragraphSpacingBefore = 4
        a.append(NSAttributedString(string: body, attributes: [
            .font: LXDrawerTint.font(15), .foregroundColor: theme.aiFg, .paragraphStyle: ps]))
        var cfg = c.defaultContentConfiguration()
        cfg.attributedText = a
        cfg.textProperties.numberOfLines = 5
        cfg.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        c.contentConfiguration = cfg
        return c
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let m = items[indexPath.row]
        guard let id = (m["id"] as? NSNumber)?.int64Value else { return }
        let sid = sessionOf(m)
        dismiss(animated: true) {
            guard let p = ChatListPlugin.live else { return }
            p.switchTo(sid)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { p.jumpToMessage(id) }
        }
    }
}
