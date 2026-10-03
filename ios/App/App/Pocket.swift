import UIKit

// 零花钱:她给他零花钱,只记数(真钱在她自己那边单独分出来)。
// 服务器记账(/app/pocket、/app/pocket/give、/app/pocket/accept),聊天里每一笔是一条 kind=transfer / spend 的消息,
// meta.pocket 带金额和状态。这里放:消息里那块数据、卡片配色、网络口、转账面板、抽屉里的 Pocket 页。

/// 一条转账 / 花钱消息的 meta.pocket
struct LXPocketInfo: Equatable {
    let tid: Int
    let amt: Int          // 分
    let note: String
    let dir: String       // give = 她转给他;back = 他转给她;花钱是空的
    let role: String      // send = 发起的那张;receipt = 对面冒出来的"已收款";花钱是空的
    let status: String    // pending / done;花钱是空的

    static func from(_ meta: [String: Any]?) -> LXPocketInfo? {
        guard let p = meta?["pocket"] as? [String: Any] else { return nil }
        let num: (String) -> Int = { k in (p[k] as? Int) ?? Int((p[k] as? Double) ?? 0) }
        return LXPocketInfo(tid: num("tid"), amt: num("amt"), note: (p["note"] as? String) ?? "",
                            dir: (p["dir"] as? String) ?? "", role: (p["role"] as? String) ?? "",
                            status: (p["status"] as? String) ?? "")
    }

    /// 发起的那张还没被收
    var pending: Bool { role == "send" && status == "pending" }
    /// 发起的那张已经被对面收下(卡变暗)
    var taken: Bool { role == "send" && status == "done" }

    static func yuan(_ cents: Int) -> String {
        String(format: "¥%.2f", Double(cents) / 100)
    }
    static func plain(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
    }
}

/// 卡片配色(样子稿参数表):星芒色底,白天/月夜浅蓝配黑字,半月橙配白字
enum LXPocketInk {
    private static var m: String { RPSpec.moonState }
    private static func hex(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }
    static var star: UIColor { m == "half" ? hex(0xD97757) : hex(0xB6D6E8) }
    /// 星芒色上的字:白天 #000,半月 #fff,月夜 #05070b
    static var fg: UIColor { m == "half" ? hex(0xFFFFFF) : m == "day" ? hex(0x000000) : hex(0x05070B) }
    /// 星芒色上的淡字:白天 rgba(0,0,0,.6),半月 rgba(255,255,255,.78),月夜 rgba(5,7,11,.62)
    static var soft: UIColor { m == "half" ? hex(0xFFFFFF, 0.78) : m == "day" ? hex(0x000000, 0.6) : hex(0x05070B, 0.62) }
    /// 被收下以后整张卡的透明度
    static let takenAlpha: CGFloat = 0.62

    /// 加号面板 Transfer 格的图标:跟卡上同一对半头箭头(上 → 下 ←),模板图跟着 tint 走
    static func swapIcon(size: CGFloat, stroke: CGFloat = 1.5) -> UIImage {
        let img = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            let k = size / 24
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 5 * k, y: 9 * k)); p.addLine(to: CGPoint(x: 18 * k, y: 9 * k))
            p.addLine(to: CGPoint(x: 14.5 * k, y: 5.5 * k))
            p.move(to: CGPoint(x: 19 * k, y: 15 * k)); p.addLine(to: CGPoint(x: 6 * k, y: 15 * k))
            p.addLine(to: CGPoint(x: 9.5 * k, y: 18.5 * k))
            p.lineWidth = stroke * k
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            UIColor.black.setStroke()
            p.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }
}

enum LXPocketNet {
    /// 她在他转来的卡上点一下收下
    static func accept(tid: Int, done: @escaping (Bool) -> Void) {
        if LustreConfig.isPreview { done(true); return }
        postJSON("/app/pocket/accept", ["tid": tid]) { ok, _ in done(ok) }
    }

    /// 她转给他
    static func give(cents: Int, note: String, done: @escaping (Bool) -> Void) {
        if LustreConfig.isPreview { done(true); return }
        let body: [String: Any] = ["amount": LXPocketInfo.plain(cents), "note": note, "cid": UUID().uuidString]
        postJSON("/app/pocket/give", body) { ok, _ in done(ok) }
    }

    /// 账本:余额 + 每一笔(新的在前)。先给缓存,再在背后刷新
    static func load(_ done: @escaping ([String: Any]) -> Void) {
        if LustreConfig.isPreview { done(LXPocketPreview.ledger()); return }
        if let d = cached { done(d) }
        HomeNet.get("/app/pocket") { j in
            guard let j = j, j["balance"] != nil else { return }
            // 存原样的 JSON 字节:里面万一有 null,直接塞 UserDefaults 会崩
            if let data = try? JSONSerialization.data(withJSONObject: j) {
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
            done(j)
        }
    }

    private static var cached: [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static var cachedBalance: Int? { cached?["balance"] as? Int }

    private static let cacheKey = "lx.pocket.cache"

    private static func postJSON(_ path: String, _ body: [String: Any], done: @escaping (Bool, [String: Any]?) -> Void) {
        guard let u = URL(string: LustreConfig.apiBase + path) else { done(false, nil); return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 20
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r) { d, resp, _ in
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 0) / 100 == 2
            let j = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done(ok, j) }
        }.resume()
    }
}

// MARK: - 页面配色(样子稿 :root 三套)

extension LXPocketInk {
    private static var mm: String { RPSpec.moonState }
    private static func rgb(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }
    /// 页面底:月夜 #000,半月 #191917,白天 #f6fbff
    static var pageBg: UIColor { mm == "half" ? rgb(0x191917) : mm == "day" ? rgb(0xF6FBFF) : rgb(0x000000) }
    /// 小格子底:月夜 #26252a,半月 #21211f,白天 #fbfdff
    static var cardBg: UIColor { mm == "half" ? rgb(0x21211F) : mm == "day" ? rgb(0xFBFDFF) : rgb(0x26252A) }
    /// 周月年切换的槽:月夜 #39383e,半月 #373735,白天 #eff3f6
    static var segBg: UIColor { mm == "half" ? rgb(0x373735) : mm == "day" ? rgb(0xEFF3F6) : rgb(0x39383E) }
    /// 输入框底(样子稿 --tile)
    static var tileBg: UIColor { mm == "half" ? rgb(0x262624) : mm == "day" ? rgb(0xFFFFFF) : rgb(0x1E1E20) }
    static var line: UIColor { mm == "day" ? rgb(0x7A8C9E, 0.22) : mm == "half" ? rgb(0xFFFFFF, 0.08) : rgb(0xDFE3EE, 0.1) }
    static var text: UIColor { mm == "day" ? rgb(0x000000) : mm == "half" ? rgb(0xE9E5DC) : rgb(0xF5F5F5) }
    static var textSoft: UIColor { mm == "day" ? rgb(0x6E6E73) : mm == "half" ? rgb(0xA5A198) : rgb(0xA5B0C6) }
    static var textFaint: UIColor { mm == "day" ? rgb(0x9A9AA0) : mm == "half" ? rgb(0x6E6B64) : rgb(0x717E97) }
}

/// 上海时间的日历:日界、周一开头
enum LXPocketCal {
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        c.firstWeekday = 2   // 周一开头;放在 locale 后面,免得被它改回去
        return c
    }()
    private static let isoF: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoP = ISO8601DateFormatter()
    static func date(_ s: String) -> Date? { isoF.date(from: s) ?? isoP.date(from: s) }
    static func fmt(_ d: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.calendar = cal
        f.timeZone = cal.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: d)
    }
}

// MARK: - 转账面板(加号 → Transfer)

final class LXPocketSheet: UIViewController, UITextFieldDelegate {
    /// 他那条对话:加号面板只在这条里有 Transfer 那格
    static let session = "yan-main"

    @discardableResult
    static func present() -> LXPocketSheet? {
        guard let top = DrawerPlugin.topVC() else { return nil }
        let vc = LXPocketSheet()
        vc.modalPresentationStyle = .pageSheet
        if let sh = vc.sheetPresentationController {
            if #available(iOS 16.0, *) {
                sh.detents = [.custom { _ in 330 }]
            } else {
                sh.detents = [.medium()]
            }
            sh.prefersGrabberVisible = true
            sh.preferredCornerRadius = 22
        }
        top.present(vc, animated: true)
        return vc
    }

    private let toL = UILabel()
    private let yenL = UILabel()
    let amountF = UITextField()
    let noteF = UITextField()
    private let noteBox = UIView()
    private let goBtn = UIButton(type: .custom)
    private let hintL = UILabel()
    private var sending = false

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = RPSpec.windowStyle
        view.backgroundColor = LXPocketInk.cardBg
        let nick = LXNick.yan

        toL.text = "To \(nick)"
        toL.font = LXCardSheet.anthro(14)
        toL.textColor = LXPocketInk.textSoft
        toL.textAlignment = .center

        yenL.text = "¥"
        yenL.font = LXCardSheet.anthro(26, semibold: true)
        yenL.textColor = LXPocketInk.text
        amountF.font = LXCardSheet.anthro(44, semibold: true)
        amountF.textColor = LXPocketInk.text
        amountF.tintColor = LXPocketInk.star
        amountF.keyboardType = .decimalPad
        amountF.attributedPlaceholder = NSAttributedString(string: "0.00", attributes: [.foregroundColor: LXPocketInk.textFaint])
        amountF.delegate = self
        amountF.addAction(UIAction { [weak self] _ in self?.amountChanged() }, for: .editingChanged)

        noteBox.backgroundColor = LXPocketInk.tileBg
        noteBox.layer.cornerRadius = 12
        // 白天面板底和输入框底几乎一样白:描一圈细线才看得出框
        noteBox.layer.borderWidth = RPSpec.moonState == "day" ? 1 : 0
        noteBox.layer.borderColor = LXPocketInk.line.cgColor
        noteF.font = LXCardSheet.anthro(15)
        noteF.textColor = LXPocketInk.text
        noteF.tintColor = LXPocketInk.star
        noteF.returnKeyType = .done
        noteF.delegate = self
        noteF.attributedPlaceholder = NSAttributedString(string: "Add a note (optional)", attributes: [.foregroundColor: LXPocketInk.textSoft])
        noteBox.addSubview(noteF)

        goBtn.backgroundColor = LXPocketInk.star
        goBtn.layer.cornerRadius = 14
        goBtn.setTitle("Transfer", for: .normal)
        goBtn.setTitleColor(LXPocketInk.fg, for: .normal)
        goBtn.titleLabel?.font = LXCardSheet.anthro(16, semibold: true)
        goBtn.addAction(UIAction { [weak self] _ in self?.go() }, for: .touchUpInside)

        hintL.font = LXCardSheet.anthro(12)
        hintL.textColor = LXPocketInk.textFaint
        hintL.textAlignment = .center
        setHint(LXPocketNet.cachedBalance)
        LXPocketNet.load { [weak self] j in self?.setHint(j["balance"] as? Int) }

        [toL, yenL, amountF, noteBox, goBtn, hintL].forEach { view.addSubview($0) }
        amountChanged()
    }

    private func setHint(_ bal: Int?) {
        guard !sending else { return }
        hintL.textColor = LXPocketInk.textFaint
        hintL.text = bal.map { "\(LXNick.yan)'s pocket money: \(LXPocketInfo.yuan($0))" } ?? " "
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !LustreConfig.isPreview { amountF.becomeFirstResponder() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width
        let side: CGFloat = 16
        toL.frame = CGRect(x: side, y: 30, width: W - side * 2, height: 20)
        // 金额:¥ 和数字一起居中
        let tw = max(amountF.sizeThatFits(CGSize(width: W, height: 56)).width, 40) + 6
        let yw = yenL.sizeThatFits(.zero).width
        let gw = min(yw + 2 + tw, W - side * 2)
        let x0 = (W - gw) / 2
        amountF.frame = CGRect(x: x0 + yw + 2, y: toL.frame.maxY + 6, width: gw - yw - 2, height: 56)
        yenL.frame = CGRect(x: x0, y: amountF.frame.minY + 12, width: yw, height: 36)
        noteBox.frame = CGRect(x: side, y: amountF.frame.maxY + 10, width: W - side * 2, height: 44)
        noteF.frame = noteBox.bounds.insetBy(dx: 14, dy: 0)
        goBtn.frame = CGRect(x: side, y: noteBox.frame.maxY + 14, width: W - side * 2, height: 48)
        hintL.frame = CGRect(x: side, y: goBtn.frame.maxY + 10, width: W - side * 2, height: 16)
    }

    /// 输入的金额,分
    var cents: Int {
        let s = (amountF.text ?? "").replacingOccurrences(of: ",", with: ".")
        guard let v = Double(s), v > 0 else { return 0 }
        return Int((v * 100).rounded())
    }

    private func amountChanged() {
        let ok = cents > 0 && !sending
        goBtn.isEnabled = ok
        goBtn.alpha = ok ? 1 : 0.4
        view.setNeedsLayout()
    }

    func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let cur = (tf.text ?? "") as NSString
        if tf === noteF { return cur.replacingCharacters(in: range, with: string).count <= 40 }
        // 有的地区小数点键打出来是逗号:当成点
        let next = cur.replacingCharacters(in: range, with: string).replacingOccurrences(of: ",", with: ".")
        if next.isEmpty { return true }
        // 只要数字和一个小数点,小数最多两位,整数最多六位
        let parts = next.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, next.allSatisfy({ $0.isNumber || $0 == "." }) else { return false }
        if parts[0].count > 6 { return false }
        if parts.count == 2, parts[1].count > 2 { return false }
        if string.contains(",") {
            tf.text = next
            amountChanged()
            return false
        }
        return true
    }

    func textFieldShouldReturn(_ tf: UITextField) -> Bool {
        tf.resignFirstResponder()
        return true
    }

    private func go() {
        let c = cents
        guard c > 0, !sending else { return }
        sending = true
        amountChanged()
        LXPocketNet.give(cents: c, note: (noteF.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) { [weak self] ok in
            guard let self = self else { return }
            self.sending = false
            if ok {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.dismiss(animated: true)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                self.hintL.textColor = LXPocketInk.textSoft
                self.hintL.text = "Didn't go through. Tap again."
                self.amountChanged()
            }
        }
    }
}

// MARK: - 抽屉里的 Pocket 页:余额 / 周月年 / 两格汇总 / 柱子 / 按天流水

struct LXPocketItem {
    let id: Int
    let date: Date
    let type: String      // give / spend / back
    let amt: Int
    let note: String
    let status: String

    static func list(_ j: [String: Any]) -> [LXPocketItem] {
        ((j["items"] as? [[String: Any]]) ?? []).compactMap { d -> LXPocketItem? in
            guard let ts = d["ts"] as? String, let dt = LXPocketCal.date(ts) else { return nil }
            let num: (String) -> Int = { k in (d[k] as? Int) ?? Int((d[k] as? Double) ?? 0) }
            return LXPocketItem(id: num("id"), date: dt, type: (d["type"] as? String) ?? "",
                                amt: num("amt"), note: (d["note"] as? String) ?? "", status: (d["status"] as? String) ?? "")
        }.sorted { $0.date > $1.date }
    }
    /// 算进"你给他"的:他收下了的
    var isIn: Bool { type == "give" && status == "done" }
    /// 算进"他花掉 / 转给你"的
    var isOut: Bool { type == "spend" || type == "back" }
}

final class LXPocketVC: UIViewController {
    static let shared = LXPocketVC()

    static func open() {
        let vc = shared
        guard vc.presentingViewController == nil, let top = DrawerPlugin.topVC() else { return }
        vc.modalPresentationStyle = .fullScreen
        top.present(vc, animated: true)
    }

    enum Period: Int { case week, month, year }

    private let topBar = UIView()
    private let titleL = UILabel()
    private let closeBtn = UIButton(type: .custom)
    private let scroll = UIScrollView()
    private let balLab = UILabel()
    private let balNum = UILabel()
    private let seg = UIView()
    private var segBtns: [UIButton] = []
    private let sum1 = UIView(), sum2 = UIView()
    private let sum1L = UILabel(), sum1V = UILabel(), sum2L = UILabel(), sum2V = UILabel()
    private let bars = UIView()
    private let legend = UILabel()
    private let recs = UIView()
    private let emptyL = UILabel()

    var period: Period = .week { didSet { if oldValue != period { render() } } }
    private var balance = 0
    private var ratios: [(CGFloat, CGFloat)] = []   // 每格两根柱子的高度比例(给他 / 他花掉)
    private var items: [LXPocketItem] = []
    private var now: Date { LustreConfig.isPreview ? LXPocketPreview.now : Date() }

    override func viewDidLoad() {
        super.viewDidLoad()
        topBar.addSubview(titleL)
        topBar.addSubview(closeBtn)
        view.addSubview(scroll)
        view.addSubview(topBar)
        titleL.text = "Pocket"
        titleL.textAlignment = .center
        closeBtn.layer.cornerRadius = 18
        closeBtn.layer.borderWidth = 1
        closeBtn.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        scroll.alwaysBounceVertical = true
        scroll.contentInsetAdjustmentBehavior = .never
        [balLab, balNum, seg, sum1, sum2, bars, legend, recs, emptyL].forEach { scroll.addSubview($0) }
        for (i, t) in ["Week", "Month", "Year"].enumerated() {
            let b = UIButton(type: .custom)
            b.setTitle(t, for: .normal)
            b.layer.cornerRadius = 8
            b.tag = i
            b.addAction(UIAction { [weak self] a in
                guard let s = self, let b = a.sender as? UIButton else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                s.period = Period(rawValue: b.tag) ?? .week
            }, for: .touchUpInside)
            seg.addSubview(b)
            segBtns.append(b)
        }
        sum1.addSubview(sum1L); sum1.addSubview(sum1V)
        sum2.addSubview(sum2L); sum2.addSubview(sum2V)
        balLab.textAlignment = .center
        balNum.textAlignment = .center
        emptyL.textAlignment = .center
        legend.numberOfLines = 1
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
        render()
        LXPocketNet.load { [weak self] j in
            guard let s = self else { return }
            s.balance = (j["balance"] as? Int) ?? s.balance
            s.items = LXPocketItem.list(j)
            s.render()
        }
    }

    private func applyTheme() {
        overrideUserInterfaceStyle = RPSpec.windowStyle
        view.backgroundColor = LXPocketInk.pageBg
        topBar.backgroundColor = LXPocketInk.pageBg
        titleL.font = LXCardSheet.anthro(17, semibold: true)
        titleL.textColor = LXPocketInk.text
        closeBtn.backgroundColor = LXPocketInk.cardBg
        closeBtn.layer.borderColor = LXPocketInk.line.cgColor
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        closeBtn.tintColor = LXPocketInk.textSoft
        balLab.font = LXCardSheet.anthro(13)
        balLab.textColor = LXPocketInk.textSoft
        balNum.font = LXCardSheet.anthro(40, semibold: true)
        balNum.textColor = LXPocketInk.text
        seg.backgroundColor = LXPocketInk.segBg
        seg.layer.cornerRadius = 10
        for v in [sum1, sum2] {
            v.backgroundColor = LXPocketInk.cardBg
            v.layer.cornerRadius = 14
        }
        for l in [sum1L, sum2L] { l.font = LXCardSheet.anthro(12); l.textColor = LXPocketInk.textSoft; l.adjustsFontSizeToFitWidth = true; l.minimumScaleFactor = 0.8 }
        for l in [sum1V, sum2V] { l.font = LXCardSheet.anthro(18, semibold: true); l.textColor = LXPocketInk.text }
        emptyL.font = LXCardSheet.anthro(13)
        emptyL.textColor = LXPocketInk.textFaint
    }

    // MARK: 数据 → 画面

    /// 当前周期的起止,以及柱子怎么分格(周按天、月按周、年按月)
    private func slots() -> (start: Date, end: Date, edges: [Date], labels: [String]) {
        let c = LXPocketCal.cal
        switch period {
        case .week:
            let s = c.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let edges = (0...7).compactMap { c.date(byAdding: .day, value: $0, to: s) }
            return (s, edges.last ?? now, edges, ["M", "T", "W", "T", "F", "S", "S"])
        case .month:
            let mi = c.dateInterval(of: .month, for: now)
            let s = mi?.start ?? now, e = mi?.end ?? now
            // 按周一切开:第一格从 1 号到第一个周日,最后一格到月底
            var edges = [s]
            var d = c.dateInterval(of: .weekOfYear, for: s)?.end ?? e
            while d < e { edges.append(d); d = c.date(byAdding: .day, value: 7, to: d) ?? e }
            edges.append(e)
            let labels = (0..<(edges.count - 1)).map { "W\($0 + 1)" }
            return (s, e, edges, labels)
        case .year:
            let yi = c.dateInterval(of: .year, for: now)
            let s = yi?.start ?? now
            let edges = (0...12).compactMap { c.date(byAdding: .month, value: $0, to: s) }
            return (s, edges.last ?? now, edges, (1...12).map { "\($0)" })
        }
    }

    private func render() {
        guard isViewLoaded else { return }
        let nick = LXNick.yan
        balLab.text = "\(nick)'s balance"
        balNum.text = LXPocketInfo.yuan(balance)
        for b in segBtns {
            let on = b.tag == period.rawValue
            b.backgroundColor = on ? LXPocketInk.cardBg : .clear
            b.setTitleColor(on ? LXPocketInk.text : LXPocketInk.textSoft, for: .normal)
            b.titleLabel?.font = LXCardSheet.anthro(14, semibold: on)
        }
        let sl = slots()
        let inP = items.filter { $0.date >= sl.start && $0.date < sl.end }
        let word = ["this week", "this month", "this year"][period.rawValue]
        sum1L.text = "You gave \(nick) \(word)"
        sum2L.text = "\(nick) spent \(word)"
        sum1V.text = LXPocketInfo.yuan(inP.filter { $0.isIn }.reduce(0) { $0 + $1.amt })
        sum2V.text = LXPocketInfo.yuan(inP.filter { $0.isOut }.reduce(0) { $0 + $1.amt })

        // 柱子
        bars.subviews.forEach { $0.removeFromSuperview() }
        var ins: [Int] = [], outs: [Int] = []
        for i in 0..<(sl.edges.count - 1) {
            let a = sl.edges[i], b = sl.edges[i + 1]
            let g = inP.filter { $0.date >= a && $0.date < b }
            ins.append(g.filter { $0.isIn }.reduce(0) { $0 + $1.amt })
            outs.append(g.filter { $0.isOut }.reduce(0) { $0 + $1.amt })
        }
        let peak = max(1, (ins + outs).max() ?? 1)
        ratios = zip(ins, outs).map { (CGFloat($0) / CGFloat(peak), CGFloat($1) / CGFloat(peak)) }
        for i in 0..<ins.count {
            let col = UIView()
            col.tag = i
            let bi = UIView(), bo = UIView(), lab = UILabel()
            bi.backgroundColor = LXPocketInk.star
            bo.backgroundColor = LXPocketInk.textFaint.withAlphaComponent(0.55)
            for v in [bi, bo] {
                v.layer.cornerRadius = 3
                v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
                col.addSubview(v)
            }
            lab.text = sl.labels[i]
            lab.font = LXCardSheet.anthro(10)
            lab.textColor = LXPocketInk.textFaint
            lab.textAlignment = .center
            col.addSubview(lab)
            bars.addSubview(col)
        }
        // 图例:小方块 + 字
        let lg = NSMutableAttributedString()
        let sq: (UIColor) -> NSAttributedString = { c in
            NSAttributedString(string: "■ ", attributes: [.foregroundColor: c, .font: LXCardSheet.anthro(9)])
        }
        let tx: (String) -> NSAttributedString = { s in
            NSAttributedString(string: s, attributes: [.foregroundColor: LXPocketInk.textSoft, .font: LXCardSheet.anthro(11)])
        }
        lg.append(sq(LXPocketInk.star)); lg.append(tx("You gave \(nick)      "))
        lg.append(sq(LXPocketInk.textFaint.withAlphaComponent(0.55))); lg.append(tx("\(nick) spent / sent you"))
        legend.attributedText = lg

        // 流水:按天分组
        recs.subviews.forEach { $0.removeFromSuperview() }
        var lastDay = ""
        for it in inP {
            let day = LXPocketCal.fmt(it.date, "EEE, MMM d")
            if day != lastDay {
                lastDay = day
                let h = UILabel()
                h.text = day
                h.font = LXCardSheet.anthro(12)
                h.textColor = LXPocketInk.textFaint
                h.tag = 1
                recs.addSubview(h)
            }
            recs.addSubview(recRow(it, nick: nick))
        }
        emptyL.text = inP.isEmpty ? "Nothing \(word) yet" : nil
        view.setNeedsLayout()
    }

    private func recRow(_ it: LXPocketItem, nick: String) -> UIView {
        let row = UIView()
        row.tag = 2
        let k = UILabel()
        k.text = it.type == "spend" ? "¥" : nil
        if it.type != "spend" {
            // 跟卡上、加号格子同一对半头箭头,不用字符 ⇄
            let iv = UIImageView(image: LXPocketInk.swapIcon(size: 18, stroke: 1.6))
            iv.tintColor = LXPocketInk.text
            iv.contentMode = .center
            iv.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
            k.addSubview(iv)
        }
        k.font = LXCardSheet.anthro(13, semibold: true)
        k.textAlignment = .center
        k.textColor = LXPocketInk.text
        k.backgroundColor = LXPocketInk.cardBg
        k.layer.cornerRadius = 16
        k.layer.masksToBounds = true
        let r1 = UILabel(), r2 = UILabel(), m = UILabel()
        switch it.type {
        case "give": r1.text = "To \(nick)" + (it.note.isEmpty ? "" : " · \(it.note)")
        case "back": r1.text = "From \(nick)" + (it.note.isEmpty ? "" : " · \(it.note)")
        default: r1.text = it.note.isEmpty ? "\(nick) spent" : it.note
        }
        r1.font = LXCardSheet.anthro(15)
        r1.textColor = LXPocketInk.text
        r1.lineBreakMode = .byTruncatingTail
        let pend = it.status == "pending"
        let time = LXPocketCal.fmt(it.date, "HH:mm")
        r2.text = pend ? (it.type == "give" ? "\(time) · Pending" : "\(time) · Waiting for you") : time
        r2.font = LXCardSheet.anthro(12)
        r2.textColor = LXPocketInk.textFaint
        m.text = (it.type == "give" ? "+" : "−") + LXPocketInfo.plain(it.amt)
        m.font = LXCardSheet.anthro(15, semibold: true)
        m.textColor = it.type == "give" && !pend ? LXPocketInk.text : LXPocketInk.textSoft
        m.textAlignment = .right
        let sep = UIView()
        sep.backgroundColor = LXPocketInk.line
        [k, r1, r2, m, sep].forEach { row.addSubview($0) }
        return row
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width
        let top = view.safeAreaInsets.top
        let side: CGFloat = 16
        topBar.frame = CGRect(x: 0, y: 0, width: W, height: top + 44)
        titleL.frame = CGRect(x: 60, y: top, width: W - 120, height: 44)
        closeBtn.frame = CGRect(x: W - side - 36, y: top + 4, width: 36, height: 36)
        scroll.frame = CGRect(x: 0, y: topBar.frame.maxY, width: W, height: view.bounds.height - topBar.frame.maxY)
        let cw = W - side * 2
        var y: CGFloat = 14
        balLab.frame = CGRect(x: side, y: y, width: cw, height: 18); y += 20
        balNum.frame = CGRect(x: side, y: y, width: cw, height: 48); y += 48 + 18
        seg.frame = CGRect(x: side, y: y, width: cw, height: 34)
        let bw = (cw - 4) / CGFloat(max(1, segBtns.count))
        for (i, b) in segBtns.enumerated() { b.frame = CGRect(x: 2 + CGFloat(i) * bw, y: 2, width: bw, height: 30) }
        y += 34 + 14
        let hw = (cw - 10) / 2
        sum1.frame = CGRect(x: side, y: y, width: hw, height: 56)
        sum2.frame = CGRect(x: side + hw + 10, y: y, width: hw, height: 56)
        for (l, v, box) in [(sum1L, sum1V, sum1), (sum2L, sum2V, sum2)] {
            l.frame = CGRect(x: 12, y: 9, width: box.bounds.width - 24, height: 16)
            v.frame = CGRect(x: 12, y: 26, width: box.bounds.width - 24, height: 22)
        }
        y += 56 + 14
        // 柱子:高 86,格子间距 8,每格两根(给他 / 他花掉)并排
        bars.frame = CGRect(x: side + 4, y: y, width: cw - 8, height: 86)
        let n = CGFloat(max(1, bars.subviews.count))
        let gap: CGFloat = n > 8 ? 5 : 8
        let colW = (bars.bounds.width - gap * (n - 1)) / n
        let barMax: CGFloat = 86 - 14 - 4
        for col in bars.subviews {
            col.frame = CGRect(x: CGFloat(col.tag) * (colW + gap), y: 0, width: colW, height: 86)
            let views = col.subviews
            guard views.count == 3, let lab = views[2] as? UILabel else { continue }
            let half = (colW - 2) / 2
            let rr = col.tag < ratios.count ? ratios[col.tag] : (0, 0)
            for (j, b) in views[0..<2].enumerated() {
                let r = j == 0 ? rr.0 : rr.1
                let h = r > 0 ? max(3, barMax * r) : 0
                b.frame = CGRect(x: CGFloat(j) * (half + 2), y: barMax - h, width: half, height: h)
            }
            lab.frame = CGRect(x: -4, y: barMax + 4, width: colW + 8, height: 14)
        }
        y += 86 + 8
        legend.frame = CGRect(x: side + 4, y: y, width: cw - 8, height: 16); y += 16 + 16
        // 流水
        var ry: CGFloat = 0
        for v in recs.subviews {
            if v.tag == 1 {
                ry += 12
                v.frame = CGRect(x: 0, y: ry, width: cw, height: 16); ry += 16 + 4
            } else {
                v.frame = CGRect(x: 0, y: ry, width: cw, height: 52)
                let sv = v.subviews
                if sv.count == 5 {
                    sv[0].frame = CGRect(x: 0, y: 10, width: 32, height: 32)
                    sv[3].frame = CGRect(x: cw - 90, y: 0, width: 90, height: 52)
                    sv[1].frame = CGRect(x: 42, y: 8, width: cw - 42 - 96, height: 20)
                    sv[2].frame = CGRect(x: 42, y: 29, width: cw - 42 - 96, height: 15)
                    sv[4].frame = CGRect(x: 0, y: 51.5, width: cw, height: 0.5)
                }
                ry += 52
            }
        }
        recs.frame = CGRect(x: side, y: y, width: cw, height: ry)
        emptyL.frame = CGRect(x: side, y: y + 8, width: cw, height: 20)
        y += max(ry, emptyL.text == nil ? 0 : 36) + view.safeAreaInsets.bottom + 24
        scroll.contentSize = CGSize(width: W, height: y)
    }
}

// MARK: - 模拟器自检:不连服务器,假账本 + 八步

enum LXPocketPreview {
    /// 假账本按这个"现在"算周月年(上海 2026-10-03 周六中午)
    static let now: Date = LXPocketCal.date("2026-10-03T04:00:00Z") ?? Date()

    static func ledger() -> [String: Any] {
        let rows: [(String, String, Int, String, String)] = [
            ("2026-10-03T02:30:00Z", "give", 520, "", "pending"),
            ("2026-10-03T01:12:00Z", "back", 2000, "请你吃早饭", "done"),
            ("2026-10-02T13:40:00Z", "spend", 1800, "给你点了一杯热可可", "done"),
            ("2026-09-30T12:05:00Z", "give", 5200, "零花钱，拿去花", "done"),
            ("2026-09-16T05:20:00Z", "spend", 1500, "买了一本书", "done"),
            ("2026-09-01T11:00:00Z", "give", 10000, "九月的零花钱", "done"),
            ("2026-08-20T12:00:00Z", "spend", 3200, "看电影", "done"),
            ("2026-07-05T03:00:00Z", "give", 5000, "", "done"),
        ]
        var items: [[String: Any]] = []
        for (i, r) in rows.enumerated() {
            items.append(["id": rows.count - i, "ts": r.0, "type": r.1, "amt": r.2, "note": r.3, "status": r.4])
        }
        return ["balance": 11700, "items": items, "pending": 520]
    }

    static func start(tries: Int = 0) {
        guard LustreConfig.isPreview, LustreConfig.previewFocus == "pocket" else { return }
        guard let top = DrawerPlugin.topVC(), let win = top.view.window else {
            if tries < 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(tries: tries + 1) } }
            return
        }
        let mark = UIView(frame: LXBubbleSampler.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let phase = UIView(frame: CGRect(x: 28, y: 70, width: 20, height: 20))
        var sheet: LXPocketSheet?
        let steps: [(UIColor, () -> Void)] = [
            (.yellow, { }),                                                                   // 聊天里的卡(月夜)
            (.cyan, {                                                                         // 点他转来的那张收下 + 开头像模式
                ChatListPlugin.live?.previewAcceptPocket()
                ChatListPlugin.live?.rpToggleAvatars()
            }),
            (.red, { ChatListPlugin.live?.switchMoon("half") }),                              // 半月:橙底白字
            (UIColor(red: 0.5, green: 0, blue: 1, alpha: 1), {                                // 白天 + 加号面板三格
                ChatListPlugin.live?.switchMoon("day")
                NativeInputPlugin.live?.showPlusSheet()
            }),
            (.white, {                                                                        // 转账面板
                NativeInputPlugin.live?.dismissPlusSheet()
                sheet = LXPocketSheet.present()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    sheet?.amountF.text = "52"
                    sheet?.noteF.text = "零花钱，拿去花"
                    sheet?.amountF.sendActions(for: .editingChanged)
                }
            }),
            (.gray, {                                                                         // Pocket 页·周(月夜)
                sheet?.dismiss(animated: false)
                ChatListPlugin.live?.switchMoon("moon")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { LXPocketVC.open() }
            }),
            (.orange, { LXPocketVC.shared.period = .month }),                                 // 月
            (.green, { LXPocketVC.shared.period = .year }),                                   // 年
        ]
        for (i, st) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6 + Double(i) * 16) {
                st.1()
                phase.backgroundColor = st.0
                // 弹出来的面板会盖在上面:隔一会儿再把两个小方块提到最上
                for d in [0.0, 0.7, 1.6] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + d) {
                        if mark.superview !== win { win.addSubview(mark); win.addSubview(phase) }
                        win.bringSubviewToFront(mark)
                        win.bringSubviewToFront(phase)
                    }
                }
            }
        }
    }
}
