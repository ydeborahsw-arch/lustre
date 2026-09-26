import Foundation
import UIKit
import Capacitor
import EventKit



func homePop(_ v: UIView) {
    UIView.animate(withDuration: 0.09, animations: { v.transform = CGAffineTransform(scaleX: 0.86, y: 0.86) }) { _ in
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.6,
                       options: [.allowUserInteraction], animations: { v.transform = .identity })
    }
}

struct HomeTheme {
    var bg = UIColor(red: 0.043, green: 0.055, blue: 0.078, alpha: 1)
    var text = UIColor.white
    var textSoft = UIColor(white: 0.78, alpha: 1)
    var textFaint = UIColor(white: 0.55, alpha: 1)
    var accent = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
    var accentFg = UIColor.black
    var cardBg = UIColor(white: 0.10, alpha: 1)
    var hairline = UIColor(white: 1, alpha: 0.09)
    var segTrack = UIColor(white: 0.16, alpha: 1)
    var sliderThumb = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
    var sendBg = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
    var rowPress = UIColor(white: 1, alpha: 0.06)
    var sidePad: CGFloat = 14

    static func col(_ s: String?, _ fb: UIColor) -> UIColor {
        guard var v = s?.trimmingCharacters(in: .whitespaces), v.hasPrefix("#") else { return fb }
        v.removeFirst()
        if v.count == 3 { v = v.map { "\($0)\($0)" }.joined() }
        var a: CGFloat = 1
        if v.count == 8 {
            let n = UInt64(v.suffix(2), radix: 16) ?? 255
            a = CGFloat(n) / 255; v = String(v.prefix(6))
        }
        guard v.count == 6, let n = UInt64(v, radix: 16) else { return fb }
        return UIColor(red: CGFloat((n >> 16) & 255) / 255, green: CGFloat((n >> 8) & 255) / 255,
                       blue: CGFloat(n & 255) / 255, alpha: a)
    }

    static let themeKeys = ["bg", "fg", "textSoft", "faint", "accent", "accentFg", "cardBg",
                            "hairline", "hairlineA", "segTrack", "sliderThumb", "sendBg",
                            "rowPress", "sidePad"]
    static func snapshot(_ call: CAPPluginCall) -> [String: Any] {
        var d: [String: Any] = [:]
        for k in themeKeys { if let v = call.options?[k] { d[k] = v } }
        d["flameURL"] = call.getString("flameURL") ?? ""
        if let w = call.getFloat("drawerW") { d["drawerW"] = NSNumber(value: w) }
        return d
    }
    static func from(dict d: [String: Any]) -> HomeTheme {
        var t = HomeTheme()
        func S(_ k: String) -> String? { d[k] as? String }
        t.bg = col(S("bg"), t.bg)
        t.text = col(S("fg"), t.text)
        t.textSoft = col(S("textSoft"), t.textSoft)
        t.textFaint = col(S("faint"), t.textFaint)
        t.accent = col(S("accent"), t.accent)
        t.accentFg = col(S("accentFg"), t.accentFg)
        t.cardBg = col(S("cardBg"), t.cardBg)
        if let h = S("hairline") {
            let a = (d["hairlineA"] as? NSNumber)?.doubleValue ?? 1
            t.hairline = col(h, t.hairline).withAlphaComponent(CGFloat(a))
        }
        t.segTrack = col(S("segTrack"), t.segTrack)
        t.sliderThumb = col(S("sliderThumb"), t.sliderThumb)
        t.sendBg = col(S("sendBg"), t.sendBg)
        t.rowPress = col(S("rowPress"), t.rowPress)
        if let p = (d["sidePad"] as? NSNumber)?.doubleValue { t.sidePad = CGFloat(p) }
        return t
    }
    static func from(_ call: CAPPluginCall) -> HomeTheme { from(dict: snapshot(call)) }
    static func sig(_ d: [String: Any]) -> String {
        d.keys.sorted().map { k -> String in
            let v = d[k]
            if let n = v as? NSNumber { return "\(k)=\(String(format: "%.3f", n.doubleValue))" }
            return "\(k)=\(String(describing: v ?? ""))"
        }.joined(separator: "|")
    }

    static let stDeep = UIColor(red: 0.357, green: 0.561, blue: 0.710, alpha: 1)
    static let stRem  = UIColor(red: 0.561, green: 0.722, blue: 0.831, alpha: 1)
    static let stCore = UIColor(red: 0.451, green: 0.498, blue: 0.561, alpha: 1)
    static let mens   = UIColor(red: 0.851, green: 0.545, blue: 0.651, alpha: 1)
}


enum HomeNet {
    static func get(_ path: String, timeout: Double = 20, done: @escaping ([String: Any]?) -> Void) {
        guard !LustreConfig.secret.isEmpty,
              let url = URL(string: LustreConfig.apiBase + path) else { done(nil); return }
        var r = URLRequest(url: url, timeoutInterval: timeout)
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            let obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }
    static func post(_ path: String, _ body: [String: Any]) {
        guard !LustreConfig.secret.isEmpty,
              let url = URL(string: LustreConfig.apiBase + path) else { return }
        var r = URLRequest(url: url, timeoutInterval: 20)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r).resume()
    }
}

@inline(__always) func moonEase(_ t: Double) -> Double { 1 - pow(1 - t, 7) }
let homeCurveA = CGPoint(x: 0.19, y: 1)
let homeCurveB = CGPoint(x: 0.22, y: 1)

final class HomeRoller {
    private var vals: [String: Double] = [:]
    private var links: [String: CADisplayLink] = [:]
    private final class Tick {
        let from: Double, to: Double, dur: Double, t0: CFTimeInterval
        let apply: (Double) -> Void
        init(from: Double, to: Double, dur: Double, apply: @escaping (Double) -> Void) {
            self.from = from; self.to = to; self.dur = dur; self.t0 = CACurrentMediaTime(); self.apply = apply
        }
        @objc func step(_ l: CADisplayLink) {
            let p = min(1, (CACurrentMediaTime() - t0) / dur)
            apply(from + (to - from) * moonEase(p))
            if p >= 1 { l.invalidate() }
        }
    }
    private static var persisted: [String: Double] = [:]
    func roll(key: String, to target: Double, dur: Double = 1.6, apply: @escaping (Double) -> Void) {
        links[key]?.invalidate()
        let from = vals[key] ?? Self.persisted[key] ?? 0
        vals[key] = target
        Self.persisted[key] = target
        if from == target || UIAccessibility.isReduceMotionEnabled { apply(target); return }
        let tick = Tick(from: from, to: target, dur: dur, apply: apply)
        let link = CADisplayLink(target: tick, selector: #selector(Tick.step(_:)))
        link.add(to: .main, forMode: .common)
        links[key] = link
    }
    func set(key: String, to target: Double, apply: (Double) -> Void) {
        links[key]?.invalidate()
        links[key] = nil
        vals[key] = target
        Self.persisted[key] = target
        apply(target)
    }
}

let homeEnterA = CGPoint(x: 0.16, y: 1)
let homeEnterB = CGPoint(x: 0.3, y: 1)

enum HomeReveal {
    private final class Run {
        weak var label: UILabel?
        let overlay: UIView
        let mask: CALayer?
        var animators: [UIViewPropertyAnimator] = []
        init(label: UILabel, overlay: UIView) {
            self.label = label
            self.overlay = overlay
            self.mask = label.layer.mask
        }
    }
    private static func glyphImage(_ lm: NSLayoutManager, _ range: NSRange, _ origin: CGPoint,
                                   _ size: CGSize, _ scale: CGFloat) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = scale
        f.opaque = false
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in
            lm.drawGlyphs(forGlyphRange: range, at: origin)
        }
    }
    private static var runs: [ObjectIdentifier: Run] = [:]

    static func finish(_ label: UILabel) {
        guard let run = runs.removeValue(forKey: ObjectIdentifier(label)) else { return }
        run.animators.forEach { $0.stopAnimation(true) }
        run.overlay.removeFromSuperview()
        run.label?.layer.mask = run.mask
    }

    static func rise(_ label: UILabel, stagger: Double, delay: Double, steps: Int? = nil) {
        finish(label)
        // 0925 录屏:字换过以后标签还是旧宽度,真标签露出来就成了"7h3…"。先把排版落定再量。
        UIView.performWithoutAnimation {
            label.superview?.superview?.layoutIfNeeded()
            label.superview?.layoutIfNeeded()
        }
        guard !UIAccessibility.isReduceMotionEnabled, let host = label.superview,
              label.bounds.width > 0, label.bounds.height > 0,
              let src = label.attributedText, src.length > 0,
              !src.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let full = NSRange(location: 0, length: src.length)
        let text = NSMutableAttributedString(string: src.string)
        if let f = label.font { text.addAttribute(.font, value: f, range: full) }
        if let c = label.textColor { text.addAttribute(.foregroundColor, value: c, range: full) }
        src.enumerateAttributes(in: full) { a, r, _ in text.addAttributes(a, range: r) }
        var bare: [NSRange] = []
        text.enumerateAttribute(.paragraphStyle, in: full) { v, r, _ in if v == nil { bare.append(r) } }
        let ps = NSMutableParagraphStyle()
        ps.alignment = label.textAlignment
        ps.lineBreakMode = .byWordWrapping
        bare.forEach { text.addAttribute(.paragraphStyle, value: ps, range: $0) }
        let storage = NSTextStorage(attributedString: text)
        let lm = NSLayoutManager()
        let tc = NSTextContainer(size: CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
        tc.lineFragmentPadding = 0
        tc.maximumNumberOfLines = label.numberOfLines
        lm.addTextContainer(tc)
        storage.addLayoutManager(lm)
        lm.ensureLayout(for: tc)
        defer { withExtendedLifetime(storage) {} }
        let laid = lm.characterRange(forGlyphRange: lm.glyphRange(for: tc), actualGlyphRange: nil)
        let used = lm.usedRect(for: tc)
        guard laid.length == storage.length, used.height <= label.bounds.height + 0.5 else { return }
        let dy = (label.bounds.height - used.height) / 2
        let scale = label.window?.screen.scale ?? UIScreen.main.scale

        let overlay = UIView(frame: label.frame)
        overlay.isUserInteractionEnabled = false
        overlay.backgroundColor = .clear
        host.insertSubview(overlay, aboveSubview: label)
        if !label.translatesAutoresizingMaskIntoConstraints {
            overlay.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: label.leadingAnchor),
                overlay.topAnchor.constraint(equalTo: label.topAnchor),
                overlay.widthAnchor.constraint(equalTo: label.widthAnchor),
                overlay.heightAnchor.constraint(equalTo: label.heightAnchor),
            ])
        }

        let run = Run(label: label, overlay: overlay)
        let ns = storage.string as NSString
        var pieces: [NSRange] = []
        ns.enumerateSubstrings(in: full, options: .byComposedCharacterSequences) { _, r, _, _ in pieces.append(r) }
        var tail: UIViewPropertyAnimator?
        var tailAt = -1.0
        for (i, r) in pieces.enumerated() {
            if ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            let gr = lm.glyphRange(forCharacterRange: r, actualCharacterRange: nil)
            guard gr.length > 0 else { continue }
            let box = lm.boundingRect(forGlyphRange: gr, in: tc)
            let line = lm.lineFragmentRect(forGlyphAt: gr.location, effectiveRange: nil)
            let em = (storage.attribute(.font, at: r.location, effectiveRange: nil) as? UIFont)?.pointSize
                ?? label.font.pointSize
            let pad = ceil(em * 0.4)
            let x0 = floor((box.minX - pad) * scale) / scale
            let y0 = floor((line.minY + dy - pad) * scale) / scale
            let frame = CGRect(x: x0, y: y0, width: ceil(box.width + pad * 2) + 1,
                               height: ceil(line.height + pad * 2) + 1)
            let g = UIImageView(image: glyphImage(lm, gr, CGPoint(x: -x0, y: dy - y0), frame.size, scale))
            g.frame = frame
            g.isUserInteractionEnabled = false
            g.alpha = 0
            g.transform = CGAffineTransform(translationX: 0, y: em * 0.5)
            overlay.addSubview(g)
            let a = UIViewPropertyAnimator(duration: 0.28, controlPoint1: CGPoint(x: 0.2, y: 0.7),
                                           controlPoint2: CGPoint(x: 0.2, y: 1)) {
                g.alpha = 1
                g.transform = .identity
            }
            let start = delay + Double(min(i, steps ?? Int.max)) * stagger
            run.animators.append(a)
            if start >= tailAt { tail = a; tailAt = start }
            a.startAnimation(afterDelay: start)
        }
        guard let last = tail else { overlay.removeFromSuperview(); return }
        let key = ObjectIdentifier(label)
        last.addCompletion { _ in
            if HomeReveal.runs[key] === run { HomeReveal.finish(label) }
        }
        let hide = CALayer()
        hide.frame = .zero
        label.layer.mask = hide
        runs[key] = run
    }
}


class HomeCard: UIView {
    let content = UIView()
    private var skel: UIView?
    func showSkeleton() {
        guard skel == nil else { return }
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        var prev: UIView? = nil
        for (i, wf) in [1.0, 0.82, 0.58].enumerated() {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = UIColor(red: 223/255.0, green: 227/255.0, blue: 238/255.0, alpha: 0.08)
            bar.layer.cornerRadius = 7
            v.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: v.leadingAnchor),
                bar.widthAnchor.constraint(equalTo: v.widthAnchor, multiplier: CGFloat(wf)),
                bar.heightAnchor.constraint(equalToConstant: 14),
                bar.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? v.topAnchor, constant: prev == nil ? 0 : 10),
            ])
            if i == 2 { bar.bottomAnchor.constraint(lessThanOrEqualTo: v.bottomAnchor).isActive = true }
            prev = bar
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0; pulse.toValue = 0.45
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        v.layer.add(pulse, forKey: "skelPulse")
        content.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: content.topAnchor, constant: 32),
            v.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        skel = v
    }
    func revealContent() {
        guard let s = skel else { return }
        skel = nil
        UIView.animate(withDuration: 0.32, animations: { s.alpha = 0 }) { _ in s.removeFromSuperview() }
    }
    weak var riseTitle: UILabel?
    private var veilStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
    func materialize(delay: Double) {
        // 0925 录屏:卡片本体是液态玻璃,整张卡 alpha<1 时玻璃被画成平的灰块,alpha 回到 1 才"亮"——入场一闪一闪。
        // 玻璃壳从第一帧就在(参考录屏里卡也不挪位),只让卡里的内容淡出来。
        content.alpha = 0
        let a = UIViewPropertyAnimator(duration: 0.7, controlPoint1: homeEnterA, controlPoint2: homeEnterB) {
            self.content.alpha = 1
        }
        a.startAnimation(afterDelay: delay)
    }
    init(theme: HomeTheme, pad: UIEdgeInsets = UIEdgeInsets(top: 13, left: 14, bottom: 14, right: 14)) {
        super.init(frame: .zero)
        var w: CGFloat = 0
        theme.bg.getWhite(&w, alpha: nil)
        veilStyle = w < 0.5 ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
        let glass: UIVisualEffectView
        var liquid = false
        if #available(iOS 26.0, *) {
            let g = UIGlassEffect()
            g.tintColor = theme.cardBg.withAlphaComponent(0.18)
            glass = UIVisualEffectView(effect: g)
            glass.overrideUserInterfaceStyle = w < 0.5 ? .dark : .light
            glass.cornerConfiguration = .uniformCorners(radius: .fixed(20))
            liquid = true
        } else {
            glass = UIVisualEffectView(effect: UIBlurEffect(style: w < 0.5 ? .systemThinMaterialDark : .systemThinMaterialLight))
        }
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.isUserInteractionEnabled = false
        addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: topAnchor), glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor), glass.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        var ca: CGFloat = 1
        theme.cardBg.getWhite(nil, alpha: &ca)
        backgroundColor = liquid ? .clear : theme.cardBg.withAlphaComponent(min(ca, 0.42))
        clipsToBounds = true
        layer.cornerRadius = 20
        layer.borderWidth = liquid ? 0 : 1
        layer.borderColor = theme.hairline.cgColor
        layer.cornerCurve = .continuous
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: pad.top),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad.left),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad.right),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad.bottom),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

func homeCardHead(_ title: String, theme: HomeTheme) -> (row: UIStackView, when: UILabel) {
    let t = UILabel()
    t.text = title
    t.font = LXDrawerTint.font(15, wght: 600)
    t.textColor = theme.text
    let w = UILabel()
    w.font = LXDrawerTint.font(11)
    w.textColor = theme.textFaint
    w.textAlignment = .right
    let row = UIStackView(arrangedSubviews: [t, w])
    row.axis = .horizontal
    row.alignment = .firstBaseline
    row.distribution = .fill
    t.setContentHuggingPriority(.defaultLow, for: .horizontal)
    // 0925 录屏:入场时标题被右边的"Updated …"挤成"V…"(两边抗压缩一样高,系统随便挤一个)
    t.setContentCompressionResistancePriority(.required, for: .horizontal)
    w.setContentCompressionResistancePriority(UILayoutPriority(700), for: .horizontal)
    w.lineBreakMode = .byTruncatingHead
    return (row, w)
}


final class HVCard: HomeCard {
    private let theme: HomeTheme
    private let roller: HomeRoller
    private let whenLab: UILabel
    private let dayLab = UILabel()
    private let bigLab = UILabel()
    private let stages = UIView()
    private let stageBar = UIStackView()
    private let legend = UIStackView()
    private let barsRow = UIStackView()
    private let emptyLab = UILabel()
    private let stats = UIStackView()
    private var days: [[String: Any]] = []
    private var selIdx = 0
    private var stageSig = ""
    private var stageDate = ""
    private var stageRevealed = false

    init(theme: HomeTheme, roller: HomeRoller) {
        self.theme = theme
        self.roller = roller
        let head = homeCardHead("Vitals", theme: theme)
        self.whenLab = head.when
        super.init(theme: theme)
        riseTitle = head.row.arrangedSubviews.first as? UILabel

        let sleepRow = UIStackView()
        sleepRow.axis = .horizontal
        sleepRow.alignment = .firstBaseline
        sleepRow.spacing = 7
        dayLab.font = LXDrawerTint.font(12.5)
        dayLab.textColor = theme.textSoft
        bigLab.font = LXDrawerTint.font(23, wght: 600)
        bigLab.setContentCompressionResistancePriority(.required, for: .horizontal)
        bigLab.textColor = theme.text
        sleepRow.addArrangedSubview(dayLab)
        sleepRow.addArrangedSubview(bigLab)
        sleepRow.addArrangedSubview(UIView())

        stageBar.axis = .horizontal
        stageBar.spacing = 2
        stageBar.distribution = .fill
        stageBar.layer.cornerRadius = 5
        stageBar.clipsToBounds = true
        legend.axis = .horizontal
        legend.distribution = .equalSpacing
        let stStack = UIStackView(arrangedSubviews: [stageBar, legend])
        stStack.axis = .vertical
        stStack.spacing = 6
        stages.translatesAutoresizingMaskIntoConstraints = false
        stStack.translatesAutoresizingMaskIntoConstraints = false
        stages.addSubview(stStack)
        NSLayoutConstraint.activate([
            stageBar.heightAnchor.constraint(equalToConstant: 9),
            stStack.topAnchor.constraint(equalTo: stages.topAnchor),
            stStack.leadingAnchor.constraint(equalTo: stages.leadingAnchor),
            stStack.trailingAnchor.constraint(equalTo: stages.trailingAnchor),
            stStack.bottomAnchor.constraint(equalTo: stages.bottomAnchor),
        ])

        barsRow.axis = .horizontal
        barsRow.spacing = 8
        barsRow.alignment = .bottom
        barsRow.distribution = .fillEqually
        emptyLab.font = LXDrawerTint.font(12.5)
        emptyLab.textColor = theme.textFaint
        emptyLab.numberOfLines = 0
        emptyLab.text = "趋势图还在攒数据,手机每天上报一次就多一根柱。"
        emptyLab.isHidden = true

        let rule = UIView()
        rule.backgroundColor = theme.hairline
        rule.heightAnchor.constraint(equalToConstant: 1).isActive = true

        stats.axis = .horizontal
        stats.distribution = .equalCentering
        stats.spacing = 6

        let col = UIStackView(arrangedSubviews: [head.row, sleepRow, stages, barsRow, emptyLab, rule, stats])
        col.axis = .vertical
        col.setCustomSpacing(10, after: head.row)
        col.setCustomSpacing(9, after: sleepRow)
        col.setCustomSpacing(14, after: stages)
        col.setCustomSpacing(14, after: barsRow)
        col.setCustomSpacing(12, after: emptyLab)
        col.setCustomSpacing(11, after: rule)
        col.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: content.topAnchor),
            col.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            col.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private static let WD = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private func fmtHM(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int(((hours - Double(h)) * 60).rounded())
        return m > 0 ? "\(h)h\(String(format: "%02d", m))m" : "\(h)h"
    }
    private func hm(_ m: Int) -> String {
        m >= 60 ? "\(m / 60)h\(String(format: "%02d", m % 60))m" : "\(m)m"
    }

    private var renderSig = ""
    var enterPending = false
    private var enterLive = false
    private var hasData = false
    func render(latest: [String: Any], days rawDays: [[String: Any]], whenTxt: String) {
        let obj: [String: Any] = ["l": latest, "d": rawDays]
        if JSONSerialization.isValidJSONObject(obj),
           let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) {
            let sig = String(decoding: data, as: UTF8.self) + "|" + whenTxt
            if sig == renderSig { return }
            renderSig = sig
        }
        if !whenTxt.isEmpty { whenLab.text = whenTxt }
        days = rawDays.filter { (($0["sleepHours"] as? NSNumber)?.doubleValue ?? 0) > 0 }
        selIdx = max(0, days.count - 1)
        showDay(days.isEmpty ? nil : days[selIdx], user: false)
        renderBars()
        renderStats(latest)
        if !days.isEmpty || !latest.isEmpty { hasData = true }
        if enterPending, enterLive, hasData { playEntrance(delay: 0) }
    }

    func beginEntrance(delay: Double) {
        enterLive = true
        if enterPending, hasData { playEntrance(delay: delay) }
    }

    private func playEntrance(delay: Double) {
        enterPending = false
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let root: UIView = (window as UIView?) ?? superview ?? self
        root.layoutIfNeeded()
        HomeReveal.rise(bigLab, stagger: 0.11, delay: delay)
        for case let col as UIStackView in stats.arrangedSubviews {
            guard let v = col.arrangedSubviews.first as? UILabel else { continue }
            let s = v.attributedText?.string ?? ""
            let n = s.firstIndex(of: " ").map { s.distance(from: s.startIndex, to: $0) } ?? s.count
            HomeReveal.rise(v, stagger: 0.11, delay: delay, steps: n)
        }
        if !barsRow.isHidden {
            for box in barsRow.arrangedSubviews {
                guard let fill = box.subviews.first?.subviews.first else { continue }
                let h = fill.bounds.height
                guard h > 0 else { continue }
                let k: CGFloat = 0.001
                fill.transform = CGAffineTransform(translationX: 0, y: h * (1 - k) / 2).scaledBy(x: 1, y: k)
                let a = UIViewPropertyAnimator(duration: 0.6, controlPoint1: homeEnterA, controlPoint2: homeEnterB) {
                    fill.transform = .identity
                }
                a.startAnimation(afterDelay: delay)
            }
        }
        if !stages.isHidden, stageBar.bounds.width > 0 {
            let mask = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
            mask.backgroundColor = .black
            stageBar.mask = mask
            let a = UIViewPropertyAnimator(duration: 0.65, controlPoint1: homeEnterA, controlPoint2: homeEnterB) {
                mask.frame = CGRect(x: 0, y: 0, width: max(320, self.stageBar.bounds.width), height: 20)
            }
            a.addCompletion { [weak self] _ in
                guard let s = self, s.stageBar.mask === mask else { return }
                s.stageBar.mask = nil
            }
            a.startAnimation(afterDelay: delay)
        }
    }

    private func showDay(_ rec: [String: Any]?, user: Bool) {
        guard let rec else {
            HomeReveal.finish(bigLab)
            bigLab.text = "没读到"; dayLab.text = "—"; stages.isHidden = true; return
        }
        let date = (rec["date"] as? String) ?? ""
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        if let d = df.date(from: date) {
            dayLab.text = Self.WD[cal.component(.weekday, from: d) - 1]
        } else { dayLab.text = "—" }
        let sleepMin = ((rec["sleepHours"] as? NSNumber)?.doubleValue ?? 0) * 60
        let paint: (Double) -> Void = { [weak self] v in
            guard let s = self else { return }
            let t = s.fmtHM(v / 60)
            guard t != s.bigLab.text else { return }
            HomeReveal.finish(s.bigLab)
            s.bigLab.text = t
            UIView.performWithoutAnimation { s.bigLab.superview?.layoutIfNeeded() }
        }
        if user { roller.roll(key: "sleepBig", to: sleepMin.rounded(), dur: 1.4, apply: paint) }
        else { roller.set(key: "sleepBig", to: sleepMin.rounded(), apply: paint) }
        renderStages(rec, animate: user)
    }

    private func renderStages(_ rec: [String: Any], animate: Bool) {
        let deep = Int(((rec["sleepDeepMin"] as? NSNumber)?.doubleValue ?? 0).rounded())
        let rem = Int(((rec["sleepRemMin"] as? NSNumber)?.doubleValue ?? 0).rounded())
        let core = Int(((rec["sleepCoreMin"] as? NSNumber)?.doubleValue ?? 0).rounded())
        let awake = Int(((rec["sleepAwakeMin"] as? NSNumber)?.doubleValue ?? 0).rounded())
        let segs = rec["sleepSegments"] as? [[String: Any]] ?? []
        let awakeN = segs.filter { ($0["t"] as? String) == "awake" }.count
        let tot = deep + rem + core
        if tot == 0 { stages.isHidden = true; stageSig = ""; return }
        stages.isHidden = false
        let sig = "\(rec["date"] ?? ""):\(deep):\(rem):\(core):\(awake):\(awakeN)"
        if sig == stageSig, !stageBar.arrangedSubviews.isEmpty { return }
        let dateKey = "\(rec["date"] ?? "")"
        let changedOnly = dateKey == stageDate && stageRevealed
        stageSig = sig
        stageDate = dateKey
        stageBar.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let pcts = [max(0.02, Double(deep) / Double(tot)), max(0.02, Double(rem) / Double(tot)),
                    max(0.02, Double(core) / Double(tot))]
        let cols = [HomeTheme.stDeep, HomeTheme.stRem, HomeTheme.stCore]
        var lastMult: NSLayoutConstraint?
        for (i, p) in pcts.enumerated() {
            let seg = UIView()
            seg.backgroundColor = cols[i]
            stageBar.addArrangedSubview(seg)
            if i > 0, let first = stageBar.arrangedSubviews.first {
                let c = seg.widthAnchor.constraint(equalTo: first.widthAnchor, multiplier: p / pcts[0])
                c.isActive = true
                lastMult = c
            }
        }
        _ = lastMult
        if animate, !changedOnly, !UIAccessibility.isReduceMotionEnabled {
            stageRevealed = true
            let mask = UIView(frame: .zero)
            mask.backgroundColor = .black
            stageBar.mask = mask
            stageBar.layoutIfNeeded()
            mask.frame = CGRect(x: 0, y: 0, width: 0, height: 20)
            let anim = UIViewPropertyAnimator(duration: 1.0, controlPoint1: CGPoint(x: 0.33, y: 1), controlPoint2: CGPoint(x: 0.68, y: 1)) {
                mask.frame = CGRect(x: 0, y: 0, width: max(320, self.stageBar.bounds.width), height: 20)
            }
            anim.addCompletion { _ in self.stageBar.mask = nil }
            anim.startAnimation()
        } else {
            stageRevealed = true
            stageBar.mask = nil
        }
        legend.arrangedSubviews.forEach { $0.removeFromSuperview() }
        func dot(_ c: UIColor, hollow: Bool = false) -> NSAttributedString {
            let r = NSTextAttachment()
            let img = UIGraphicsImageRenderer(size: CGSize(width: 7, height: 7)).image { ctx in
                let path = UIBezierPath(ovalIn: CGRect(x: hollow ? 0.7 : 0, y: hollow ? 0.7 : 0,
                                                       width: hollow ? 5.6 : 7, height: hollow ? 5.6 : 7))
                if hollow {
                    ctx.cgContext.setStrokeColor(theme.textFaint.cgColor)
                    path.lineWidth = 1.4
                    path.stroke()
                } else {
                    ctx.cgContext.setFillColor(c.cgColor)
                    path.fill()
                }
            }
            r.image = img
            r.bounds = CGRect(x: 0, y: -0.5, width: 7, height: 7)
            return NSAttributedString(attachment: r)
        }
        func chunk(_ name: String, _ v: String) -> NSAttributedString {
            let s = NSMutableAttributedString(string: " \(name) ",
                attributes: [.font: LXDrawerTint.font(10), .foregroundColor: theme.textFaint])
            s.append(NSAttributedString(string: v,
                attributes: [.font: LXDrawerTint.font(10, wght: 600), .foregroundColor: theme.textSoft]))
            return s
        }
        func seg(_ d: NSAttributedString, _ name: String, _ v: String) -> UILabel {
            let l = UILabel()
            let s = NSMutableAttributedString()
            s.append(d)
            s.append(chunk(name, v))
            l.attributedText = s
            l.adjustsFontSizeToFitWidth = true
            return l
        }
        legend.addArrangedSubview(seg(dot(HomeTheme.stDeep), "Deep", hm(deep)))
        legend.addArrangedSubview(seg(dot(HomeTheme.stRem), "REM", hm(rem)))
        legend.addArrangedSubview(seg(dot(HomeTheme.stCore), "Core", hm(core)))
        if awake > 0 {
            legend.addArrangedSubview(seg(dot(.clear, hollow: true), "Awake", hm(awake) + (awakeN > 0 ? "·\(awakeN)x" : "")))
        }
    }

    private func renderBars() {
        barsRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        emptyLab.isHidden = !days.isEmpty
        barsRow.isHidden = days.isEmpty
        guard !days.isEmpty else { return }
        let maxH = max(days.map { (($0["sleepHours"] as? NSNumber)?.doubleValue ?? 0) }.max() ?? 8, 8)
        for (i, d) in days.enumerated() {
            let h = (d["sleepHours"] as? NSNumber)?.doubleValue ?? 0
            let pct = max(0.06, (h / maxH))
            let day = Int(String((d["date"] as? String ?? "").suffix(2))) ?? 0
            barsRow.addArrangedSubview(makeBar(i: i, pct: pct, label: "\(day)"))
        }
    }

    private func makeBar(i: Int, pct: Double, label: String) -> UIControl {
        let box = UIControl()
        let colV = UIView()
        colV.backgroundColor = theme.segTrack
        colV.layer.cornerRadius = 7
        colV.clipsToBounds = true
        colV.isUserInteractionEnabled = false
        let fill = UIView()
        fill.backgroundColor = i == selIdx ? theme.accent : theme.sliderThumb
        fill.layer.cornerRadius = 7
        let lab = UILabel()
        lab.text = label
        lab.font = LXDrawerTint.font(10.5, wght: i == selIdx ? 700 : 400)
        lab.textColor = i == selIdx ? theme.accent : theme.textFaint
        lab.textAlignment = .center
        lab.isUserInteractionEnabled = false
        [colV, fill, lab].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        colV.addSubview(fill)
        box.addSubview(colV)
        box.addSubview(lab)
        NSLayoutConstraint.activate([
            colV.topAnchor.constraint(equalTo: box.topAnchor),
            colV.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            colV.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            colV.heightAnchor.constraint(equalToConstant: 64),
            fill.leadingAnchor.constraint(equalTo: colV.leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: colV.trailingAnchor),
            fill.bottomAnchor.constraint(equalTo: colV.bottomAnchor),
            fill.heightAnchor.constraint(equalTo: colV.heightAnchor, multiplier: pct),
            lab.topAnchor.constraint(equalTo: colV.bottomAnchor, constant: 6),
            lab.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            lab.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        box.tag = i
        box.addTarget(self, action: #selector(barTap(_:)), for: .touchUpInside)
        return box
    }

    @objc private func barTap(_ b: UIControl) {
        guard b.tag != selIdx, b.tag < days.count else { return }
        selIdx = b.tag
        renderBars()
        showDay(days[selIdx], user: true)
    }

    func previewSelectBar(_ i: Int) {
        guard i < days.count, i != selIdx else { return }
        selIdx = i
        renderBars()
        showDay(days[selIdx], user: true)
    }

    private func renderStats(_ latest: [String: Any]) {
        stats.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let prev: [String: Any]? = days.count >= 2 ? days[days.count - 2] : nil
        func delta(_ k: String) -> Double {
            guard let p = (prev?[k] as? NSNumber)?.doubleValue, p != 0 else { return 0 }
            return ((latest[k] as? NSNumber)?.doubleValue ?? 0) - p
        }
        func num(_ k: String, _ digits: Int) -> (String, Double?) {
            guard let v = (latest[k] as? NSNumber)?.doubleValue else { return ("—", nil) }
            return (String(format: "%.\(digits)f", v), v)
        }
        let steps = (latest["stepsToday"] as? NSNumber)?.doubleValue
        let stepsTxt = steps.map { f -> String in
            let n = NumberFormatter(); n.numberStyle = .decimal
            return n.string(from: NSNumber(value: Int(f.rounded()))) ?? "—"
        } ?? "—"
        let items: [(String, Double?, String, String, Double, Bool)] = [
            (stepsTxt, steps, "steps", "Steps", delta("stepsToday"), true),
            (num("activeKcalToday", 0).0, num("activeKcalToday", 0).1, "kcal", "Active", delta("activeKcalToday"), false),
            (num("restingHeartRate", 0).0, num("restingHeartRate", 0).1, "bpm", "Resting HR", delta("restingHeartRate"), false),
            (num("hrvSDNN", 0).0, num("hrvSDNN", 0).1, "ms", "HRV", delta("hrvSDNN"), false),
        ]
        for (i, it) in items.enumerated() {
            stats.addArrangedSubview(makeStat(key: "hv\(i)", txt: it.0, val: it.1, unit: it.2,
                                              label: it.3, delta: it.4, grouped: it.5))
        }
    }

    private func makeStat(key: String, txt: String, val: Double?, unit: String,
                          label: String, delta: Double, grouped: Bool) -> UIView {
        let v = UILabel()
        v.textAlignment = .center
        let l = UILabel()
        l.font = LXDrawerTint.font(10.5)
        l.textColor = theme.textFaint
        l.text = label
        l.textAlignment = .center
        func paint(_ s: String) {
            let m = NSMutableAttributedString(string: s,
                attributes: [.font: LXDrawerTint.font(16.5, wght: 600), .foregroundColor: theme.text])
            m.append(NSAttributedString(string: " " + unit,
                attributes: [.font: LXDrawerTint.font(11), .foregroundColor: theme.textSoft]))
            if delta > 0 {
                m.append(NSAttributedString(string: " ▲",
                    attributes: [.font: LXDrawerTint.font(11), .foregroundColor: theme.accent]))
            } else if delta < 0 {
                m.append(NSAttributedString(string: " ▼",
                    attributes: [.font: LXDrawerTint.font(11), .foregroundColor: theme.textFaint]))
            }
            v.attributedText = m
        }
        if let val {
            let fmt = NumberFormatter()
            if grouped { fmt.numberStyle = .decimal }
            roller.set(key: key, to: val) { x in
                paint(grouped ? (fmt.string(from: NSNumber(value: Int(x.rounded()))) ?? "") : String(Int(x.rounded())))
            }
        } else { paint("—") }
        let col = UIStackView(arrangedSubviews: [v, l])
        col.axis = .vertical
        col.spacing = 2
        return col
    }
}


final class HCCard: HomeCard {
    private let theme: HomeTheme
    // 0925 录屏:月份标题原来是按钮自带的标签。入场量尺寸时它还没排到最终宽度,打字动画就按"Sept…r 2026"
    // (靠左、中间省略)打出来,打完换回真标签时跳成居中的全称。改成自己的标签:宽度就是字本身的宽(不压缩)、
    // 用约束居中,打字层钉在它身上——两者永远在同一个位置、同一个宽度。
    private let titleBtn = UIControl()
    private let titleL = UILabel()
    private let prevBtn = UIButton(type: .custom)
    private let nextBtn = UIButton(type: .custom)
    private let gridBox = UIView()
    private let grid = UIStackView()
    private let diaryBox = UIView()
    private let diaryStack = UIStackView()
    private var gridCollapse: NSLayoutConstraint!
    private var diaryCollapse: NSLayoutConstraint!
    private var folded = true
    private var ym: (y: Int, m: Int)
    private var daysSet: Set<String> = []
    private var mensSet: Set<String> = []
    private var selIso = ""
    var onLongPress: ((String) -> Void)?
    var onHaptic: ((String) -> Void)?
    private var pressTimer: Timer?
    private var longFired = false

    static var todayIso: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return df.string(from: Date())
    }

    private static let MONTHS = ["January", "February", "March", "April", "May", "June", "July",
                                 "August", "September", "October", "November", "December"]
    private static let MONTHS_S = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let DOW = ["S", "M", "T", "W", "T", "F", "S"]
    private static let DOW_FULL = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(theme: HomeTheme) {
        self.theme = theme
        let t = Self.todayIso.split(separator: "-")
        self.ym = (Int(t[0]) ?? 2026, (Int(t[1]) ?? 1) - 1)
        super.init(theme: theme, pad: UIEdgeInsets(top: 9, left: 13, bottom: 9, right: 13))
        riseTitle = titleL

        for (btn, s) in [(prevBtn, "‹"), (nextBtn, "›")] {
            btn.setTitle(s, for: .normal)
            btn.titleLabel?.font = LXDrawerTint.font(26)
            btn.setTitleColor(theme.text, for: .normal)
            btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
        }
        titleL.translatesAutoresizingMaskIntoConstraints = false
        titleL.font = LXDrawerTint.font(15, wght: 600)
        titleL.textColor = theme.text
        titleL.textAlignment = .center
        titleL.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleL.setContentHuggingPriority(.required, for: .horizontal)
        titleBtn.addSubview(titleL)
        NSLayoutConstraint.activate([
            titleL.centerXAnchor.constraint(equalTo: titleBtn.centerXAnchor),
            titleL.centerYAnchor.constraint(equalTo: titleBtn.centerYAnchor),
            titleL.leadingAnchor.constraint(greaterThanOrEqualTo: titleBtn.leadingAnchor),
        ])
        titleBtn.isAccessibilityElement = true
        titleBtn.accessibilityTraits = .button
        prevBtn.addTarget(self, action: #selector(prevM), for: .touchUpInside)
        nextBtn.addTarget(self, action: #selector(nextM), for: .touchUpInside)
        titleBtn.addTarget(self, action: #selector(toggleFold), for: .touchUpInside)
        let head = UIStackView(arrangedSubviews: [prevBtn, titleBtn, nextBtn])
        head.axis = .horizontal
        head.distribution = .fill
        titleBtn.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        head.heightAnchor.constraint(equalToConstant: 34).isActive = true
        for btn in [prevBtn, titleBtn, nextBtn] {
            btn.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        }

        grid.axis = .vertical
        grid.spacing = 2
        grid.translatesAutoresizingMaskIntoConstraints = false
        gridBox.clipsToBounds = true
        gridBox.addSubview(grid)
        gridCollapse = gridBox.heightAnchor.constraint(equalToConstant: 0)
        gridCollapse.priority = .required
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: gridBox.topAnchor, constant: 4),
            grid.leadingAnchor.constraint(equalTo: gridBox.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: gridBox.trailingAnchor),
        ])
        let gb = grid.bottomAnchor.constraint(equalTo: gridBox.bottomAnchor)
        gb.priority = .defaultHigh
        gb.isActive = true
        gridCollapse.isActive = folded

        diaryBox.clipsToBounds = true
        diaryStack.axis = .vertical
        diaryStack.translatesAutoresizingMaskIntoConstraints = false
        diaryBox.addSubview(diaryStack)
        diaryCollapse = diaryBox.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            diaryStack.topAnchor.constraint(equalTo: diaryBox.topAnchor),
            diaryStack.leadingAnchor.constraint(equalTo: diaryBox.leadingAnchor),
            diaryStack.trailingAnchor.constraint(equalTo: diaryBox.trailingAnchor),
        ])
        let db = diaryStack.bottomAnchor.constraint(equalTo: diaryBox.bottomAnchor)
        db.priority = .defaultHigh
        db.isActive = true
        diaryCollapse.isActive = true

        let col = UIStackView(arrangedSubviews: [head, gridBox, diaryBox])
        col.axis = .vertical
        col.setCustomSpacing(2, after: head)
        col.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: content.topAnchor),
            col.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            col.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let lp = UILongPressGestureRecognizer(target: self, action: #selector(gridPress(_:)))
        lp.minimumPressDuration = 0.46
        grid.addGestureRecognizer(lp)
        rebuildGrid()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setData(days: Set<String>, mens: Set<String>) {
        daysSet = days
        mensSet = mens
        rebuildGrid()
    }

    @objc private func prevM() { ym = ym.m == 0 ? (ym.y - 1, 11) : (ym.y, ym.m - 1); rebuildGrid() }
    @objc private func nextM() { ym = ym.m == 11 ? (ym.y + 1, 0) : (ym.y, ym.m + 1); rebuildGrid() }

    private var enclosingScroll: UIScrollView? {
        var v: UIView? = superview
        while let cur = v { if let s = cur as? UIScrollView { return s }; v = cur.superview }
        return nil
    }
    private func shrinkGuard(_ shrink: CGFloat, _ anim: UIViewPropertyAnimator) {
        guard shrink > 0.5, let sv = enclosingScroll else { return }
        let maxAfter = sv.contentSize.height - shrink + sv.adjustedContentInset.bottom - sv.bounds.height
        let over = sv.contentOffset.y - max(maxAfter, -sv.adjustedContentInset.top)
        guard over > 0.5 else { return }
        sv.contentInset.bottom += over
        anim.addAnimations { sv.contentOffset.y -= over }
        anim.addCompletion { _ in sv.contentInset.bottom -= over }
    }

    @objc private func toggleFold() {
        folded.toggle()
        let shrink = folded ? gridBox.bounds.height : 0
        gridCollapse.isActive = folded
        let anim = UIViewPropertyAnimator(duration: 0.65, controlPoint1: homeCurveA, controlPoint2: homeCurveB) {
            self.grid.alpha = self.folded ? 0 : 1
            self.window?.layoutIfNeeded()
        }
        shrinkGuard(shrink, anim)
        anim.startAnimation()
    }

    private var gridFading = false
    private static var diaryInflight: Set<String> = []
    private func prefetchMonth() {
        let ym0 = String(format: "%04d-%02d", ym.y, ym.m + 1)
        for iso in daysSet where iso.hasPrefix(ym0) && Self.diaryCache[iso] == nil && !Self.diaryInflight.contains(iso) {
            Self.diaryInflight.insert(iso)
            HomeNet.get("/app/diary?date=\(iso)") { obj in
                DispatchQueue.main.async {
                    Self.diaryInflight.remove(iso)
                    guard let obj = obj, Self.diaryCache[iso] == nil else { return }
                    let entry = obj["entry"] as? [String: Any] ?? [:]
                    Self.diaryCache[iso] = (entry["ai"] as? String) ?? (entry["human"] as? String) ?? ""
                }
            }
        }
    }

    private func rebuildGrid() {
        prefetchMonth()
        if gridFading { rebuildGridNow(); return }
        gridFading = true
        UIView.transition(with: grid, duration: 0.22, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
            self.rebuildGridNow()
        }, completion: { _ in self.gridFading = false })
    }
    private func rebuildGridNow() {
        titleL.text = "\(Self.MONTHS[ym.m]) \(ym.y)"
        titleBtn.accessibilityLabel = titleL.text
        UIView.performWithoutAnimation { titleBtn.superview?.layoutIfNeeded() }
        grid.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let dowRow = UIStackView()
        dowRow.axis = .horizontal
        dowRow.distribution = .fillEqually
        for d in Self.DOW {
            let l = UILabel()
            l.text = d
            l.font = LXDrawerTint.font(11)
            l.textColor = theme.textFaint
            l.textAlignment = .center
            dowRow.addArrangedSubview(l)
        }
        grid.addArrangedSubview(dowRow)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comp = DateComponents()
        comp.year = ym.y; comp.month = ym.m + 1; comp.day = 1
        guard let first = cal.date(from: comp),
              let range = cal.range(of: .day, in: .month, for: first) else { return }
        let startDow = cal.component(.weekday, from: first) - 1
        let todayIso = Self.todayIso
        var cells: [UIView] = []
        for _ in 0..<startDow { cells.append(UIView()) }
        for d in 1...range.count {
            let iso = String(format: "%04d-%02d-%02d", ym.y, ym.m + 1, d)
            cells.append(makeDay(d: d, iso: iso, has: daysSet.contains(iso),
                                 today: iso == todayIso, sel: iso == selIso, mens: mensSet.contains(iso)))
        }
        while cells.count % 7 != 0 { cells.append(UIView()) }
        for row in stride(from: 0, to: cells.count, by: 7) {
            let r = UIStackView(arrangedSubviews: Array(cells[row..<row + 7]))
            r.axis = .horizontal
            r.distribution = .fillEqually
            grid.addArrangedSubview(r)
        }
    }

    private func makeDay(d: Int, iso: String, has: Bool, today: Bool, sel: Bool, mens: Bool) -> UIView {
        let wrap = UIView()
        let b = DayCell()
        b.iso = iso
        b.isEnabled = has
        b.setTitle("\(d)", for: .normal)
        b.titleLabel?.font = LXDrawerTint.font(13, wght: (has || sel) ? (sel ? 700 : 600) : 400)
        b.setTitleColor(sel ? theme.accent : (has ? theme.text : theme.textFaint), for: .normal)
        b.layer.cornerRadius = 13.5
        b.pressColor = theme.rowPress
        if today {
            b.layer.borderWidth = 1.5
            b.layer.borderColor = theme.accent.cgColor
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(b)
        NSLayoutConstraint.activate([
            b.widthAnchor.constraint(equalToConstant: 30),
            b.heightAnchor.constraint(equalToConstant: 27),
            b.centerXAnchor.constraint(equalTo: wrap.centerXAnchor),
            b.topAnchor.constraint(equalTo: wrap.topAnchor),
            b.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])
        if has {
            let dot = UIView()
            dot.backgroundColor = theme.accent
            dot.layer.cornerRadius = 1.75
            dot.isUserInteractionEnabled = false
            dot.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 3.5),
                dot.heightAnchor.constraint(equalToConstant: 3.5),
                dot.centerXAnchor.constraint(equalTo: b.centerXAnchor),
                dot.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -2),
            ])
        }
        if mens {
            let dot = UIView()
            dot.backgroundColor = HomeTheme.mens
            dot.layer.cornerRadius = 2
            dot.isUserInteractionEnabled = false
            dot.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 4),
                dot.heightAnchor.constraint(equalToConstant: 4),
                dot.centerXAnchor.constraint(equalTo: b.centerXAnchor),
                dot.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -1),
            ])
        }
        b.addTarget(self, action: #selector(dayTap(_:)), for: .touchUpInside)
        return wrap
    }

    final class DayCell: UIButton {
        var iso = ""
        var pressColor = UIColor.clear
        override var isHighlighted: Bool {
            didSet { backgroundColor = isHighlighted && isEnabled ? pressColor : .clear }
        }
    }

    @objc private func dayTap(_ b: DayCell) {
        if longFired { longFired = false; return }
        if selIso == b.iso, diaryCollapse.isActive == false {
            closeDiary()
            return
        }
        selIso = b.iso
        applySelection()
        openDiary(b.iso)
    }

    private func applySelection() {
        for row in grid.arrangedSubviews.compactMap({ $0 as? UIStackView }) {
            for wrap in row.arrangedSubviews {
                guard let b = wrap.subviews.compactMap({ $0 as? DayCell }).first else { continue }
                let sel = b.iso == selIso
                let has = b.isEnabled
                b.titleLabel?.font = LXDrawerTint.font(13, wght: (has || sel) ? (sel ? 700 : 600) : 400)
                b.setTitleColor(sel ? theme.accent : (has ? theme.text : theme.textFaint), for: .normal)
            }
        }
    }

    private var diaryAnim: UIViewPropertyAnimator?
    private func closeDiary() {
        selIso = ""
        applySelection()
        let shrink = diaryBox.bounds.height
        diaryCollapse.isActive = true
        diaryAnim?.stopAnimation(true)
        let a = UIViewPropertyAnimator(duration: 0.65, controlPoint1: homeCurveA, controlPoint2: homeCurveB) {
            self.diaryStack.alpha = 0
            self.window?.layoutIfNeeded()
        }
        shrinkGuard(shrink, a)
        a.startAnimation()
        diaryAnim = a
    }

    private static func prettyDow(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return iso }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents(); c.year = p[0]; c.month = p[1]; c.day = p[2]
        guard let d = cal.date(from: c) else { return iso }
        return "\(DOW_FULL[cal.component(.weekday, from: d) - 1]), \(MONTHS_S[p[1] - 1]) \(p[2])"
    }

    private static var diaryCache: [String: String] = [:]
    private var diaryReq = 0
    private weak var diaryBody: UILabel?
    private func openDiary(_ iso: String) {
        diaryReq += 1
        let req = diaryReq
        if let cached = Self.diaryCache[iso] { presentDiary(iso, text: cached); return }
        var presented = false
        let fallback = DispatchWorkItem { [weak self] in
            guard let s = self, s.diaryReq == req, !presented else { return }
            presented = true
            s.presentDiary(iso, text: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: fallback)
        HomeNet.get("/app/diary?date=\(iso)") { [weak self] obj in
            DispatchQueue.main.async {
                guard let s = self else { return }
                let entry = obj?["entry"] as? [String: Any] ?? [:]
                let txt = (entry["ai"] as? String) ?? (entry["human"] as? String) ?? ""
                if obj != nil { Self.diaryCache[iso] = txt }
                guard s.diaryReq == req else { return }
                fallback.cancel()
                if presented { s.fillDiary(txt) } else { presented = true; s.presentDiary(iso, text: txt) }
            }
        }
    }

    private func diaryBodyStyle(_ body: UILabel, _ txt: String?) {
        guard let txt = txt else {
            body.font = LXDrawerTint.font(13); body.textColor = theme.textFaint; body.text = "读取中…"; return
        }
        if txt.isEmpty {
            body.font = LXDrawerTint.font(13); body.textColor = theme.textFaint; body.text = "这天他还没写。"; return
        }
        let ps = NSMutableParagraphStyle()
        ps.lineHeightMultiple = 1.45
        body.attributedText = NSAttributedString(string: txt,
            attributes: [.font: LXDrawerTint.font(14), .foregroundColor: theme.text, .paragraphStyle: ps])
    }

    private func fillDiary(_ txt: String) {
        guard let body = diaryBody else { return }
        UIView.transition(with: body, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
            self.diaryBodyStyle(body, txt)
        })
        UIViewPropertyAnimator(duration: 0.5, controlPoint1: homeCurveA, controlPoint2: homeCurveB) {
            self.window?.layoutIfNeeded()
        }.startAnimation()
    }

    private func presentDiary(_ iso: String, text: String?) {
        let oldPads = diaryStack.arrangedSubviews
        let pad = UIView()
        let line = UIView()
        line.backgroundColor = theme.hairline
        let dot = UIView()
        dot.layer.cornerRadius = 4
        dot.layer.borderWidth = 1.5
        dot.layer.borderColor = theme.textFaint.cgColor
        let date = UILabel()
        date.text = Self.prettyDow(iso)
        date.font = LXDrawerTint.font(13.5)
        date.textColor = theme.text
        let body = UILabel()
        body.numberOfLines = 0
        body.contentMode = .topLeft
        diaryBodyStyle(body, text)
        diaryBody = body
        [line, dot, date, body].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        pad.translatesAutoresizingMaskIntoConstraints = false
        pad.addSubview(line); pad.addSubview(dot); pad.addSubview(date); pad.addSubview(body)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: pad.topAnchor, constant: 14),
            line.leadingAnchor.constraint(equalTo: pad.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: pad.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            dot.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 16),
            dot.leadingAnchor.constraint(equalTo: pad.leadingAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            date.centerYAnchor.constraint(equalTo: dot.centerYAnchor),
            date.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            body.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 7),
            body.leadingAnchor.constraint(equalTo: pad.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: pad.trailingAnchor),
            body.bottomAnchor.constraint(equalTo: pad.bottomAnchor),
        ])
        diaryAnim?.stopAnimation(true)
        if !diaryCollapse.isActive {
            let oldH = diaryBox.bounds.height
            UIView.transition(with: diaryStack, duration: 0.3, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                oldPads.forEach { $0.removeFromSuperview() }
                self.diaryStack.addArrangedSubview(pad)
            })
            UIView.performWithoutAnimation { self.diaryBox.layoutIfNeeded() }
            let a = UIViewPropertyAnimator(duration: 0.65, controlPoint1: homeCurveA, controlPoint2: homeCurveB) {
                self.window?.layoutIfNeeded()
            }
            shrinkGuard(oldH - diaryStack.bounds.height, a)
            a.startAnimation()
            diaryAnim = a
        } else {
            oldPads.forEach { $0.removeFromSuperview() }
            diaryStack.addArrangedSubview(pad)
            UIView.performWithoutAnimation { self.diaryBox.layoutIfNeeded() }
            diaryStack.alpha = 0
            diaryCollapse.isActive = false
            let a = UIViewPropertyAnimator(duration: 0.65, controlPoint1: homeCurveA, controlPoint2: homeCurveB) {
                self.diaryStack.alpha = 1
                self.window?.layoutIfNeeded()
            }
            a.startAnimation()
            diaryAnim = a
        }
    }

    func previewReveal() {
        if folded { toggleFold() }
        let ym0 = String(format: "%04d-%02d", ym.y, ym.m + 1)
        if let iso = daysSet.filter({ $0.hasPrefix(ym0) }).sorted().last {
            selIso = iso
            rebuildGrid()
            openDiary(iso)
        }
    }

    func previewFlipPrev() { prevM() }

    @objc private func gridPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        let pt = g.location(in: grid)
        guard let cell = findDay(in: grid, at: pt), cell.isEnabled else { return }
        longFired = true
        onHaptic?("medium")
        onLongPress?(cell.iso)
    }
    private func findDay(in v: UIView, at pt: CGPoint) -> DayCell? {
        for sub in v.subviews {
            let p = v.convert(pt, to: sub)
            if let d = sub as? DayCell, sub.bounds.contains(p) { return d }
            if sub.bounds.contains(p), let found = findDay(in: sub, at: p) { return found }
        }
        return nil
    }
}


final class HMCard: HomeCard {
    private let titleLab = UILabel()
    private let textLab = UILabel()
    init(theme: HomeTheme, square: Bool = true) {
        let head = homeCardHead("Memory", theme: theme)
        super.init(theme: theme)
        riseTitle = head.row.arrangedSubviews.first as? UILabel
        titleLab.font = LXDrawerTint.font(13.5, wght: 600)
        titleLab.textColor = theme.textSoft
        titleLab.setContentCompressionResistancePriority(.required, for: .vertical)
        head.row.setContentCompressionResistancePriority(.required, for: .vertical)
        textLab.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        textLab.font = LXDrawerTint.font(12.5)
        textLab.textColor = theme.textFaint
        textLab.numberOfLines = 6
        let col = UIStackView(arrangedSubviews: [head.row, titleLab, textLab, UIView()])
        col.axis = .vertical
        col.setCustomSpacing(8, after: head.row)
        col.setCustomSpacing(6, after: titleLab)
        col.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: content.topAnchor),
            col.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            col.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func render(title: String, text: String) {
        titleLab.text = title
        let ps = NSMutableParagraphStyle()
        ps.lineHeightMultiple = 1.35
        ps.lineBreakMode = .byTruncatingTail
        textLab.attributedText = NSAttributedString(string: text,
            attributes: [.font: LXDrawerTint.font(12.5),
                         .foregroundColor: textLab.textColor ?? .gray, .paragraphStyle: ps])
    }
}


final class HTCard: HomeCard {
    private let theme: HomeTheme
    private let listStack = UIStackView()
    private let input = UITextField()
    private let sendBtn = UIButton(type: .custom)
    private let emptyLab = UILabel()
    private let store = EKEventStore()
    private var items: [(id: String, title: String, sub: String, done: Bool)] = []
    var onHaptic: ((String) -> Void)?

    init(theme: HomeTheme) {
        self.theme = theme
        let head = homeCardHead("To Do", theme: theme)
        super.init(theme: theme)
        riseTitle = head.row.arrangedSubviews.first as? UILabel
        listStack.axis = .vertical
        emptyLab.font = LXDrawerTint.font(12)
        emptyLab.textColor = theme.textFaint
        emptyLab.numberOfLines = 0
        emptyLab.text = "今天没有待办。手机\"提醒事项\"里加的、\(LXNick.yan)给你记的,都会出现在这。"

        let addRow = UIView()
        let topLine = UIView()
        topLine.backgroundColor = theme.hairline
        input.font = LXDrawerTint.font(13)
        input.textColor = theme.text
        input.attributedPlaceholder = NSAttributedString(string: "记一条…",
            attributes: [.foregroundColor: theme.textFaint])
        input.returnKeyType = .done
        input.delegate = self
        input.addTarget(self, action: #selector(inputChanged), for: .editingChanged)
        sendBtn.backgroundColor = theme.segTrack
        sendBtn.tintColor = theme.textSoft
        sendBtn.layer.cornerRadius = 13
        sendBtn.setImage(UIImage(systemName: "arrow.up",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)), for: .normal)
        sendBtn.addTarget(self, action: #selector(addTap), for: .touchUpInside)
        [topLine, input, sendBtn].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addRow.translatesAutoresizingMaskIntoConstraints = false
        addRow.addSubview(topLine); addRow.addSubview(input); addRow.addSubview(sendBtn)
        NSLayoutConstraint.activate([
            topLine.topAnchor.constraint(equalTo: addRow.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: addRow.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: addRow.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1),
            input.topAnchor.constraint(equalTo: topLine.bottomAnchor, constant: 9),
            input.leadingAnchor.constraint(equalTo: addRow.leadingAnchor),
            input.bottomAnchor.constraint(equalTo: addRow.bottomAnchor),
            sendBtn.leadingAnchor.constraint(equalTo: input.trailingAnchor, constant: 8),
            sendBtn.trailingAnchor.constraint(equalTo: addRow.trailingAnchor),
            sendBtn.centerYAnchor.constraint(equalTo: input.centerYAnchor),
            sendBtn.widthAnchor.constraint(equalToConstant: 26),
            sendBtn.heightAnchor.constraint(equalToConstant: 26),
        ])

        let scroll = LXVerticalScroll()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceHorizontal = false
        scroll.isDirectionalLockEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        listStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(listStack)
        NSLayoutConstraint.activate([
            listStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            listStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            listStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            listStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        let col = UIStackView(arrangedSubviews: [head.row, scroll, addRow])
        col.axis = .vertical
        col.setCustomSpacing(8, after: head.row)
        col.setCustomSpacing(8, after: scroll)
        col.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: content.topAnchor),
            col.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            col.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func inputChanged() {
        let on = !(input.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        sendBtn.backgroundColor = on ? theme.sendBg : theme.segTrack
        sendBtn.tintColor = on ? theme.accentFg : theme.textSoft
    }

    func load() {
        let go: (Bool, Error?) -> Void = { [weak self] ok, _ in
            guard let s = self, ok else { return }
            s.fetchList()
        }
        if #available(iOS 17.0, *) { store.requestFullAccessToReminders(completion: go) }
        else { store.requestAccess(to: .reminder, completion: go) }
    }

    private func fetchList() {
        let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil,
                                                         calendars: nil)
        store.fetchReminders(matching: pred) { [weak self] rems in
            guard let s = self else { return }
            let df = DateFormatter()
            df.dateFormat = "M/d HH:mm"
            df.timeZone = TimeZone(identifier: "Asia/Shanghai")
            let out: [(String, String, String, Bool)] = (rems ?? []).prefix(12).map { r in
                var sub = r.calendar?.title ?? ""
                if let dc = r.dueDateComponents, let d = Calendar.current.date(from: dc) {
                    sub = df.string(from: d)
                }
                return (r.calendarItemIdentifier, r.title ?? "", sub, false)
            }
            DispatchQueue.main.async {
                s.items = out
                s.renderList()
            }
        }
    }

    private func renderList() {
        revealContent()
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let open = items.filter { !$0.done }
        if open.isEmpty { listStack.addArrangedSubview(emptyLab); return }
        for (i, it) in open.enumerated() {
            listStack.addArrangedSubview(makeRow(it, divider: i > 0))
        }
    }

    private func makeRow(_ it: (id: String, title: String, sub: String, done: Bool), divider: Bool) -> UIView {
        let row = UIView()
        if divider {
            let l = UIView()
            l.backgroundColor = theme.hairline
            l.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: row.topAnchor),
                l.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 29),
                l.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                l.heightAnchor.constraint(equalToConstant: 1),
            ])
        }
        let box = UIButton(type: .custom)
        box.layer.cornerRadius = 10
        box.layer.borderWidth = 1.6
        box.layer.borderColor = (it.done ? theme.accent : theme.textFaint).cgColor
        box.backgroundColor = it.done ? theme.accent : .clear
        if it.done {
            box.setImage(UIImage(systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .heavy)), for: .normal)
            box.tintColor = .black
        }
        box.accessibilityLabel = it.id
        box.addTarget(self, action: #selector(boxTap(_:)), for: .touchUpInside)
        let title = UILabel()
        title.numberOfLines = 0
        if it.done {
            title.attributedText = NSAttributedString(string: it.title, attributes: [
                .font: LXDrawerTint.font(13.5), .foregroundColor: theme.textFaint,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue])
        } else {
            title.font = LXDrawerTint.font(13.5)
            title.textColor = theme.text
            title.text = it.title
        }
        let sub = UILabel()
        sub.font = LXDrawerTint.font(11.5)
        sub.textColor = theme.textFaint
        sub.text = it.sub
        sub.isHidden = it.sub.isEmpty
        let copyCol = UIStackView(arrangedSubviews: [title, sub])
        copyCol.axis = .vertical
        copyCol.spacing = 3
        [box, copyCol].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        row.addSubview(box); row.addSubview(copyCol)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
            box.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            box.widthAnchor.constraint(equalToConstant: 20),
            box.heightAnchor.constraint(equalToConstant: 20),
            copyCol.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            copyCol.leadingAnchor.constraint(equalTo: box.trailingAnchor, constant: 9),
            copyCol.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            copyCol.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
        ])
        return row
    }

    @objc private func boxTap(_ b: UIButton) {
        guard let id = b.accessibilityLabel,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].done = true
        homePop(b)
        onHaptic?("success")
        b.backgroundColor = theme.accent
        b.layer.borderColor = theme.accent.cgColor
        b.setImage(UIImage(systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .heavy)), for: .normal)
        b.tintColor = .black
        if let row = b.superview,
           let col = row.subviews.compactMap({ $0 as? UIStackView }).first,
           let title = col.arrangedSubviews.first as? UILabel {
            let strike = UIView()
            strike.backgroundColor = theme.textFaint
            strike.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(strike)
            let w = strike.widthAnchor.constraint(equalToConstant: 0)
            NSLayoutConstraint.activate([
                strike.leadingAnchor.constraint(equalTo: title.leadingAnchor),
                strike.centerYAnchor.constraint(equalTo: title.centerYAnchor),
                strike.heightAnchor.constraint(equalToConstant: 1.5),
                w,
            ])
            row.layoutIfNeeded()
            w.constant = min(title.intrinsicContentSize.width, title.bounds.width)
            UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut]) {
                row.layoutIfNeeded()
                title.textColor = self.theme.textFaint
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let s = self else { return }
                UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
                    row.alpha = 0
                    row.isHidden = true
                    s.listStack.layoutIfNeeded()
                    s.window?.layoutIfNeeded()
                }, completion: { _ in s.renderList() })
            }
        } else {
            UIView.transition(with: self, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                self.renderList()
            }
        }
        if let r = store.calendarItem(withIdentifier: id) as? EKReminder {
            r.isCompleted = true
            try? store.save(r, commit: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let s = self else { return }
            s.items.removeAll { $0.id == id }
            UIView.transition(with: s, duration: 0.3, options: [.transitionCrossDissolve, .allowUserInteraction]) {
                s.renderList()
            }
        }
    }

    func previewInject() {
        items = [("pv-1", "买猫粮", "9/3 18:00", false),
                 ("pv-2", "给\(LXNick.yan)留言", "提醒事项", true)]
        renderList()
    }

    @objc private func addTap() {
        let title = (input.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        input.text = ""
        inputChanged()
        let rem = EKReminder(eventStore: store)
        rem.title = title
        rem.calendar = store.defaultCalendarForNewReminders()
        try? store.save(rem, commit: true)
        HomeNet.post("/app/todo_note", ["text": title])
        onHaptic?("light")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.load() }
    }
}

extension HTCard: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        addTap()
        return true
    }
}


final class HCSheet: UIView {
    private let theme: HomeTheme
    private let scrim = UIControl()
    private let sheet = UIScrollView()
    private let stack = UIStackView()
    private var sheetBottom: NSLayoutConstraint!

    init(theme: HomeTheme) {
        self.theme = theme
        super.init(frame: .zero)
        isHidden = true
        scrim.backgroundColor = UIColor(white: 0, alpha: 0.34)
        scrim.addTarget(self, action: #selector(close), for: .touchUpInside)
        // 0925 她的单:底部升起的小卡统一用模型小卡的底(玻璃 + LXSheetInk.tint),钉在滚动框上不跟内容滚
        sheet.backgroundColor = .clear
        sheet.clipsToBounds = true
        let glassFx: UIVisualEffect
        if #available(iOS 26.0, *) { glassFx = UIGlassEffect() }
        else { glassFx = UIBlurEffect(style: LXSheetInk.dark ? .systemThickMaterialDark : .systemThickMaterialLight) }
        let glass = UIVisualEffectView(effect: glassFx)
        glass.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        let tintV = UIView(); tintV.backgroundColor = LXSheetInk.tint
        for v in [glass, tintV] as [UIView] {
            v.isUserInteractionEnabled = false
            v.translatesAutoresizingMaskIntoConstraints = false
            sheet.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: sheet.frameLayoutGuide.topAnchor),
                v.bottomAnchor.constraint(equalTo: sheet.frameLayoutGuide.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: sheet.frameLayoutGuide.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: sheet.frameLayoutGuide.trailingAnchor),
            ])
        }
        sheet.layer.cornerRadius = 26
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.layer.cornerCurve = .continuous
        stack.axis = .vertical
        [scrim, sheet, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(scrim)
        addSubview(sheet)
        sheet.addSubview(stack)
        sheetBottom = sheet.topAnchor.constraint(equalTo: bottomAnchor)
        let fitH = sheet.heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 32)
        fitH.priority = UILayoutPriority(749)
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: topAnchor),
            scrim.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.76),
            fitH,
            stack.topAnchor.constraint(equalTo: sheet.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: sheet.contentLayoutGuide.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: sheet.contentLayoutGuide.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: sheet.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: sheet.frameLayoutGuide.widthAnchor, constant: -36),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc func close() { isHidden = true }

    func probeScroll() -> String {
        layoutIfNeeded()
        let ch = sheet.contentSize.height, fh = sheet.bounds.height
        sheet.setContentOffset(CGPoint(x: 0, y: 50), animated: false)
        let held = sheet.contentOffset.y
        sheet.setContentOffset(.zero, animated: false)
        return "contentH=\(Int(ch)) frameH=\(Int(fh)) 滚50读回=\(Int(held)) 可滚=\(ch > fh + 1)"
    }

    private static let MONTHS_S = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private func pretty(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return iso }
        return "\(Self.MONTHS_S[p[1] - 1]) \(p[2]), \(p[0])"
    }

    private func lab(_ txt: String, size: CGFloat, weight: UIFont.Weight = .regular,
                     color: UIColor, lines: Int = 0) -> UILabel {
        let l = UILabel()
        l.text = txt
        l.font = LXDrawerTint.font(size, wght: weight == .bold ? 700 : (weight == .semibold ? 600 : (weight == .medium ? 500 : 400)))
        l.textColor = color
        l.numberOfLines = lines
        return l
    }

    func open(iso: String) {
        isHidden = false
        // 玻璃铁律:不许让整张卡半透明(会压成灰块)——只淡入遮罩,卡从屏幕底整张滑上来
        scrim.alpha = 0
        UIView.animate(withDuration: 0.22) { self.scrim.alpha = 1 }
        sheet.transform = CGAffineTransform(translationX: 0, y: max(bounds.height, 400))
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.85,
                       initialSpringVelocity: 0.35, options: [.allowUserInteraction]) {
            self.sheet.transform = .identity
        }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let handle = UIView()
        handle.backgroundColor = theme.textFaint.withAlphaComponent(0.4)
        handle.layer.cornerRadius = 2.5
        let hWrap = UIView()
        handle.translatesAutoresizingMaskIntoConstraints = false
        hWrap.addSubview(handle)
        NSLayoutConstraint.activate([
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 5),
            handle.centerXAnchor.constraint(equalTo: hWrap.centerXAnchor),
            handle.topAnchor.constraint(equalTo: hWrap.topAnchor),
            handle.bottomAnchor.constraint(equalTo: hWrap.bottomAnchor, constant: -6),
        ])
        stack.addArrangedSubview(hWrap)
        let title = lab(pretty(iso), size: 17, weight: .semibold, color: theme.text)
        stack.addArrangedSubview(title)
        stack.setCustomSpacing(2, after: title)
        let sub = lab("Loading…", size: 12.5, color: theme.textFaint)
        stack.addArrangedSubview(sub)
        stack.setCustomSpacing(14, after: sub)

        let today = HCCard.todayIso
        let df = ISO8601DateFormatter()
        let diff: Int = {
            guard let a = df.date(from: iso + "T00:00:00Z"),
                  let b = df.date(from: today + "T00:00:00Z") else { return 0 }
            return max(0, Int(b.timeIntervalSince(a) / 86400))
        }()
        HomeNet.get("/app/tm_stats?days=\(diff)&session_id=yan-main") { [weak self] st in
            guard let s = self, !s.isHidden else { return }
            sub.text = (diff == 0 ? "Today" : "\(diff) days ago") + " · with \(LXNick.yan)"
            let total = (st?["total"] as? NSNumber)?.intValue ?? 0
            let human = (st?["human"] as? NSNumber)?.intValue ?? 0
            let mins = (st?["duration_min"] as? NSNumber)?.doubleValue ?? 0
            let hours = (mins / 6).rounded() / 10
            let grid = UIStackView()
            grid.axis = .horizontal
            grid.distribution = .fillEqually
            grid.spacing = 8
            for (v, name) in [("\(total)", "Messages"), ("\(human)", "From you"),
                              (hours == hours.rounded() ? "\(Int(hours))" : "\(hours)", "Hours")] {
                let cell = UIView()
                cell.backgroundColor = s.theme.segTrack
                cell.layer.cornerRadius = 14
                let b = s.lab(v, size: 18, color: s.theme.text)
                b.textAlignment = .center
                let sp = s.lab(name, size: 11, color: s.theme.textFaint)
                sp.textAlignment = .center
                let c = UIStackView(arrangedSubviews: [b, sp])
                c.axis = .vertical
                c.spacing = 3
                c.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(c)
                NSLayoutConstraint.activate([
                    c.topAnchor.constraint(equalTo: cell.topAnchor, constant: 11),
                    c.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                    c.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                    c.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -11),
                ])
                grid.addArrangedSubview(cell)
            }
            s.stack.addArrangedSubview(grid)
            let kws = (st?["keywords"] as? [String]) ?? []
            if !kws.isEmpty {
                s.stack.setCustomSpacing(14, after: grid)
                let kwRow = HCFlowRow(theme: s.theme, words: kws)
                s.stack.addArrangedSubview(kwRow)
            }
            s.loadLog(iso: iso, diff: diff)
        }
    }

    private func loadLog(iso: String, diff: Int) {
        let holder = UIStackView()
        holder.axis = .vertical
        holder.spacing = 12
        let line = UIView()
        line.backgroundColor = theme.hairline
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last ?? stack)
        stack.addArrangedSubview(line)
        stack.setCustomSpacing(14, after: line)
        stack.addArrangedSubview(holder)
        holder.addArrangedSubview(lab("Loading…", size: 13, color: theme.textFaint))
        HomeNet.get("/app/timemachine?days=\(diff)&session_id=yan-main", timeout: 45) { [weak self] obj in
            guard let s = self, !s.isHidden else { return }
            holder.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let msgs = (obj?["messages"] as? [[String: Any]]) ?? []
            if LustreConfig.isPreview { HomePlugin.probeStatic("home-log", "nil=\(obj == nil) msgs=\(msgs.count)") }
            if obj == nil {
                holder.addArrangedSubview(s.lab("读不出来。", size: 13, color: s.theme.textFaint))
                return
            }
            let shown = msgs.suffix(3000)
            if msgs.count > shown.count {
                holder.addArrangedSubview(s.lab("只显示了最后 \(shown.count) 条,这天一共 \(msgs.count) 条。",
                                                size: 13, color: s.theme.textFaint))
            }
            if shown.isEmpty {
                holder.addArrangedSubview(s.lab("这天没有留下对话。", size: 13, color: s.theme.textFaint))
                return
            }
            let tdf = DateFormatter()
            tdf.dateFormat = "HH:mm"
            tdf.timeZone = TimeZone(identifier: "Asia/Shanghai")
            let idf = ISO8601DateFormatter()
            idf.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let idf2 = ISO8601DateFormatter()
            let all = NSMutableAttributedString()
            let tPS = NSMutableParagraphStyle()
            tPS.paragraphSpacingBefore = 12
            tPS.paragraphSpacing = 3
            let bPS = NSMutableParagraphStyle()
            bPS.lineHeightMultiple = 1.25
            var first = true
            for m in shown {
                let from = (m["from"] as? String) ?? ""
                var body = ((m["text"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if body.isEmpty {
                    let meta = m["meta"] as? [String: Any]
                    if let atts = meta?["attachments"] as? [[String: Any]], !atts.isEmpty { body = "[image]" }
                }
                if body.isEmpty { continue }
                let ts = (m["ts"] as? String) ?? ""
                let tsPlain = ts.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
                let d = idf.date(from: ts) ?? idf2.date(from: ts) ?? idf2.date(from: tsPlain)
                let t = d.map { tdf.string(from: $0) } ?? ""
                let tg = ((m["meta"] as? [String: Any])?["door"] as? String) == "tg"
                let who = (from == "human" ? "you" : LXNick.yan) + (tg ? " · TG" : "")
                let ps = first ? { let p = tPS.mutableCopy() as! NSMutableParagraphStyle; p.paragraphSpacingBefore = 0; return p }() : tPS
                first = false
                all.append(NSAttributedString(string: "\(t) · \(who)\n", attributes: [
                    .font: LXDrawerTint.font(10.5), .foregroundColor: s.theme.textFaint,
                    .kern: 0.2, .paragraphStyle: ps]))
                all.append(NSAttributedString(string: body + "\n", attributes: [
                    .font: LXDrawerTint.font(14),
                    .foregroundColor: from == "human" ? s.theme.text : s.theme.textSoft,
                    .paragraphStyle: bPS]))
            }
            let logL = UITextView()
            logL.isEditable = false
            logL.isSelectable = true
            logL.isScrollEnabled = false
            logL.backgroundColor = .clear
            logL.textContainerInset = .zero
            logL.textContainer.lineFragmentPadding = 0
            logL.attributedText = all
            holder.addArrangedSubview(logL)
        }
    }
}

final class HCFlowRow: UIView {
    init(theme: HomeTheme, words: [String]) {
        super.init(frame: .zero)
        var x: CGFloat = 0, y: CGFloat = 0
        let maxW = UIScreen.main.bounds.width - 36 - 36
        var lastH: CGFloat = 0
        for w in words {
            let l = UILabel()
            l.text = w
            l.font = LXDrawerTint.font(12.5)
            l.textColor = theme.textSoft
            l.backgroundColor = theme.segTrack
            l.layer.cornerRadius = 12
            l.layer.masksToBounds = true
            l.textAlignment = .center
            let size = l.intrinsicContentSize
            let bw = size.width + 22, bh = size.height + 10
            if x + bw > maxW, x > 0 { x = 0; y += bh + 7 }
            l.frame = CGRect(x: x, y: y, width: bw, height: bh)
            addSubview(l)
            x += bw + 7
            lastH = bh
        }
        heightAnchor.constraint(equalToConstant: max(0, y + lastH)).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
}


final class HomeView: UIView {
    let theme: HomeTheme
    let roller = HomeRoller()
    let vitals: HVCard
    let calCard: HCCard
    let memCard: HMCard
    let todoCard: HTCard
    let sheet: HCSheet
    private let scroll = UIScrollView()
    private let flameBtn = UIButton(type: .custom)
    var onAct: ((String) -> Void)?

    init(theme: HomeTheme, flameURL: String) {
        self.theme = theme
        vitals = HVCard(theme: theme, roller: roller)
        calCard = HCCard(theme: theme)
        memCard = HMCard(theme: theme)
        todoCard = HTCard(theme: theme)
        sheet = HCSheet(theme: theme)
        super.init(frame: .zero)
        backgroundColor = theme.bg
        vitals.showSkeleton()
        memCard.showSkeleton()
        todoCard.showSkeleton()

        let menuBtn = UIButton(type: .system)
        menuBtn.setImage(UIImage(systemName: "line.3.horizontal",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)), for: .normal)
        menuBtn.tintColor = theme.text
        menuBtn.addAction(UIAction { [weak self] _ in self?.onAct?("menu") }, for: .touchUpInside)
        let title = UILabel()
        title.text = "Home"
        title.font = LXDrawerTint.font(17, wght: 600)
        title.textColor = theme.text
        flameBtn.addAction(UIAction { [weak self] _ in self?.onAct?("chat") }, for: .touchUpInside)
        if let u = URL(string: flameURL) {
            URLSession.shared.dataTask(with: u) { d, _, _ in
                guard let d, let img = UIImage(data: d) else { return }
                DispatchQueue.main.async { self.flameBtn.setImage(img, for: .normal) }
            }.resume()
        }
        flameBtn.imageView?.contentMode = .scaleAspectFit
        let bar = UIView()
        [menuBtn, title, flameBtn].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        bar.addSubview(menuBtn); bar.addSubview(title); bar.addSubview(flameBtn)
        NSLayoutConstraint.activate([
            bar.heightAnchor.constraint(equalToConstant: 56),
            menuBtn.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: theme.sidePad - 6),
            menuBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            menuBtn.widthAnchor.constraint(equalToConstant: 40),
            menuBtn.heightAnchor.constraint(equalToConstant: 40),
            title.leadingAnchor.constraint(equalTo: menuBtn.trailingAnchor, constant: 10),
            title.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            flameBtn.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -(theme.sidePad - 6)),
            flameBtn.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            flameBtn.widthAnchor.constraint(equalToConstant: 48),
            flameBtn.heightAnchor.constraint(equalToConstant: 48),
        ])

        let squares = UIStackView(arrangedSubviews: [memCard, todoCard])
        squares.axis = .horizontal
        squares.distribution = .fillEqually
        squares.spacing = 11
        memCard.widthAnchor.constraint(equalTo: memCard.heightAnchor).isActive = true

        let col = UIStackView(arrangedSubviews: [vitals, calCard, squares])
        col.axis = .vertical
        col.spacing = 11
        col.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(col)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        bar.translatesAutoresizingMaskIntoConstraints = false
        sheet.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar); addSubview(scroll); addSubview(sheet)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: bar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            col.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 1),
            col.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: theme.sidePad),
            col.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -theme.sidePad),
            col.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -52),
            col.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -theme.sidePad * 2),
            sheet.topAnchor.constraint(equalTo: topAnchor),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        calCard.onLongPress = { [weak self] iso in self?.sheet.open(iso: iso) }
        let hap: (String) -> Void = { kind in
            switch kind {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            default: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        calCard.onHaptic = hap
        todoCard.onHaptic = hap
        scroll.keyboardDismissMode = .interactive
        let kbTap = UITapGestureRecognizer(target: self, action: #selector(bgTapDismiss))
        kbTap.cancelsTouchesInView = false
        scroll.addGestureRecognizer(kbTap)
        NotificationCenter.default.addObserver(self, selector: #selector(kbShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func kbShow(_ n: Notification) {
        guard let f = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        scroll.contentInset.bottom = f.height
        scroll.verticalScrollIndicatorInsets.bottom = f.height
        DispatchQueue.main.async {
            let target = self.todoCard.convert(self.todoCard.bounds, to: self.scroll)
            self.scroll.scrollRectToVisible(target.insetBy(dx: 0, dy: -12), animated: true)
        }
    }
    @objc private func kbHide() {
        scroll.contentInset.bottom = 0
        scroll.verticalScrollIndicatorInsets.bottom = 0
    }

    @objc private func bgTapDismiss() { endEditing(true) }

    private var enterArmed = false
    func prepareEnter() {
        enterArmed = true
        vitals.enterPending = true
    }

    func playEnter() {
        if !enterArmed { prepareEnter() }
        let cards: [HomeCard] = [vitals, calCard, memCard, todoCard]
        let still = UIAccessibility.isReduceMotionEnabled
        if !still { (superview ?? self).layoutIfNeeded() }
        for (i, c) in cards.enumerated() {
            let d = Double(i) * 0.05
            c.transform = .identity
            if still { c.alpha = 1; continue }
            c.materialize(delay: d)
            if let t = c.riseTitle { HomeReveal.rise(t, stagger: 0.04, delay: d + 0.12) }
        }
        vitals.beginEntrance(delay: 0.2)
    }

    private static func cacheSave(_ key: String, _ d: [String: Any]?) {
        guard let d = d, let data = try? JSONSerialization.data(withJSONObject: d) else { return }
        UserDefaults.standard.set(data, forKey: "lx.home." + key)
    }
    private static func cacheLoad(_ key: String) -> [String: Any]? {
        guard let data = UserDefaults.standard.data(forKey: "lx.home." + key) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func applyObmem(_ d: [String: Any]?) {
        memCard.revealContent()
        memCard.render(title: (d?["title"] as? String) ?? "",
                       text: (d?["text"] as? String) ?? "今天还没抽到,晚点再来。")
    }
    private func applyVitals(_ d: [String: Any]?, daily dd: [String: Any]?, tm td: [String: Any]?) {
        let latest = ((d?["health"] as? [String: Any])?["data"] as? [String: Any]) ?? [:]
        var whenTxt = ""
        if let up = d?["updated_at"] as? String {
            let idf = ISO8601DateFormatter()
            idf.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let df = DateFormatter()
            df.dateFormat = "'Updated' M/d HH:mm"
            df.timeZone = TimeZone(identifier: "Asia/Shanghai")
            if let dt = idf.date(from: up) ?? ISO8601DateFormatter().date(from: up) {
                whenTxt = df.string(from: dt)
            }
        }
        var mens = Set<String>()
        if let hist = latest["menstrualHistory"] as? [[String: Any]] {
            let df2 = DateFormatter()
            df2.dateFormat = "yyyy-MM-dd"
            df2.timeZone = TimeZone(identifier: "Asia/Shanghai")
            for r in hist {
                guard let s0 = (r["s"] as? NSNumber)?.doubleValue,
                      let e0 = (r["e"] as? NSNumber)?.doubleValue else { continue }
                var t = s0
                while t <= e0 { mens.insert(df2.string(from: Date(timeIntervalSince1970: t))); t += 86400 }
                mens.insert(df2.string(from: Date(timeIntervalSince1970: e0)))
            }
        }
        let days = (dd?["days"] as? [[String: Any]]) ?? []
        vitals.revealContent()
        vitals.render(latest: latest, days: days, whenTxt: whenTxt)
        let tdays = Set((td?["days"] as? [String]) ?? [])
        calCard.setData(days: tdays, mens: mens)
    }

    func renderCached() {
        if let ob = Self.cacheLoad("obmem") { applyObmem(ob) }
        if let vi = Self.cacheLoad("vitals") {
            applyVitals(vi, daily: Self.cacheLoad("daily"), tm: Self.cacheLoad("tmdays"))
        }
    }

    func loadAll() {
        HomeNet.get("/app/obmem") { [weak self] d in
            Self.cacheSave("obmem", d)
            self?.gated { self?.applyObmem(d) }
        }
        HomeNet.get("/app/vitals") { [weak self] d in
            guard let s = self else { return }
            Self.cacheSave("vitals", d)
            HomeNet.get("/app/vitals/daily?days=7") { dd in
                Self.cacheSave("daily", dd)
                HomeNet.get("/app/tm_days?session_id=yan-main") { td in
                    Self.cacheSave("tmdays", td)
                    s.gated { s.applyVitals(d, daily: dd, tm: td) }
                }
            }
        }
        todoCard.load()
    }

    private var renderGateOpen = false
    private var pendingRenders: [() -> Void] = []
    func gated(_ block: @escaping () -> Void) {
        if renderGateOpen { block() } else { pendingRenders.append(block) }
    }
    func openRenderGate() {
        renderGateOpen = true
        let blocks = pendingRenders
        pendingRenders = []
        blocks.forEach { $0() }
    }
}


public class HomePlugin: CAPPlugin, CAPBridgedPlugin, UIGestureRecognizerDelegate {
    public let identifier = "HomePlugin"
    public let jsName = "HomePage"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "homeEnable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "homeDisable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "homeHide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "homeStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "homeSettle", returnType: CAPPluginReturnPromise),
    ]
    var home: HomeView?
    private var pendingMenuOpen = false
    private var webReady = false {
        didSet { if webReady, pendingMenuOpen { pendingMenuOpen = false; openHomeDrawer() } }
    }
    func openHomeDrawer() {
        LXDrawer.show(host: bridge?.viewController?.view)
        LXDrawer.place(below: home)
        notifyListeners("homeAct", data: ["act": "edgeBegin"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let s = self else { return }
            s.notifyListeners("homeAct", data: ["act": "edgeBegin"])
            s.settleHome(open: true)
        }
    }
    private var bootT: Date?
    var drawerW: CGFloat = 300
    static let themeCacheKey = "lustre.home.theme"
    private var lastPayload: [String: Any] = [:]

    func attachEarly(host: UIView, payload: [String: Any]) {
        bootT = Date()
        if LustreConfig.webless { webReady = true }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.webReady = true } }
        lastPayload = payload
        if let w = (payload["drawerW"] as? NSNumber)?.doubleValue, w > 100 { drawerW = CGFloat(w) }
        attach(host: host, theme: HomeTheme.from(dict: payload),
               flame: (payload["flameURL"] as? String) ?? "", enter: true, deferLoad: true)
    }

    private func attach(host: UIView, theme: HomeTheme, flame: String, enter: Bool, deferLoad: Bool) {
        // 预览路线 composer 只拍输入栏:首页不上来(它晚到会盖住聊天页)
        if LustreConfig.isPreview && LustreConfig.previewFocus == "composer" { return }
        var ghost: UIView? = nil
        for sub in host.subviews where sub is HomeView {
            if ghost == nil, !sub.isHidden, sub.alpha > 0.01,
               let snap = sub.snapshotView(afterScreenUpdates: false) {
                snap.frame = sub.frame
                snap.transform = sub.transform
                snap.isUserInteractionEnabled = false
                snap.tag = 7719
                ghost = snap
            }
            sub.removeFromSuperview()
        }
        startLiveWatch(host: host)
        let v = HomeView(theme: theme, flameURL: flame)
        v.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: host.topAnchor),
            v.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        host.bringSubviewToFront(v)
        LXStage.settle(host)
        v.onAct = { [weak self] act in
            guard let s = self else { return }
            if act == "menu" {
                if !s.webReady {
                    s.pendingMenuOpen = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    return
                }
                s.openHomeDrawer()
            } else if act == "chat", LustreConfig.webless {
                ChatListPlugin.live?.switchTo("yan-main")
                s.leaveHome()
                NativeInputPlugin.live?.setCardHidden(false)
            } else {
                s.notifyListeners("homeAct", data: ["act": act])
            }
        }
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(self.homeEdgePan(_:)))
        edge.edges = .left
        v.addGestureRecognizer(edge)
        let closePan = UIPanGestureRecognizer(target: self, action: #selector(self.homeClosePan(_:)))
        closePan.delegate = self
        v.addGestureRecognizer(closePan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.homeBgTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        v.addGestureRecognizer(tap)
        home = v
        if let g = ghost {
            // 新 Home 不做透明度渐变(液态玻璃卡在 alpha<1 时会变平再"亮"起来),改成旧画面盖在上面淡出
            host.insertSubview(g, aboveSubview: v)
            UIView.animate(withDuration: 0.22, animations: { g.alpha = 0 }) { _ in
                g.removeFromSuperview()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak g] in
                g?.removeFromSuperview()
            }
        }
        if enter { v.prepareEnter() }
        v.renderCached()
        v.loadAll()
        if deferLoad {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak v] in v?.openRenderGate() }
        } else {
            v.openRenderGate()
        }
        if enter { v.playEnter() }
        lxProbeStack(host, "attach末")
    }

    @objc func homeEnable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let b = self.bootT {
                self.bootT = nil
                Self.probeStatic("boot-timing", "网页醒来耗时=\(String(format: "%.1f", Date().timeIntervalSince(b)))s")
            }
            self.webReady = true
            guard let host = self.bridge?.viewController?.view else { call.resolve(["ok": false]); return }
            lxProbeStack(host, "homeEnable入口")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { lxProbeStack(host, "醒来+0.5s") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { lxProbeStack(host, "醒来+1.5s") }
            let payload = HomeTheme.snapshot(call)
            UserDefaults.standard.set(payload, forKey: Self.themeCacheKey)
            if let w = call.getFloat("drawerW"), w > 100 { self.drawerW = CGFloat(w) }
            if let v = self.home, v.superview === host,
               HomeTheme.sig(self.lastPayload) == HomeTheme.sig(payload) {
                for sub in host.subviews where sub is HomeView && sub !== v { sub.removeFromSuperview() }
                host.bringSubviewToFront(v)
                LXStage.settle(host)
                v.loadAll()
                lxProbeStack(host, "收养后")
                call.resolve(["ok": true, "ver": 1, "adopted": true])
                return
            }
            self.lastPayload = payload
            let firstBirth = self.home == nil
            self.attach(host: host, theme: HomeTheme.from(dict: payload),
                        flame: (payload["flameURL"] as? String) ?? "", enter: firstBirth, deferLoad: false)
            lxProbeStack(host, "换新后(sig不同)")
            call.resolve(["ok": true, "ver": 1])
        }
    }

    public func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if g is UITapGestureRecognizer { return (home?.transform.tx ?? 0) > 0 }
        return true
    }

    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if let p = g as? UIPanGestureRecognizer, !(p is UIScreenEdgePanGestureRecognizer), let v = home, p.view === v {
            guard v.transform.tx > 0 else { return false }
            let vel = p.velocity(in: v)
            return abs(vel.x) > abs(vel.y)
        }
        return true
    }

    @objc func homeEdgePan(_ g: UIScreenEdgePanGestureRecognizer) {
        guard webReady, let v = home else { return }
        switch g.state {
        case .began:
            home?.endEditing(true)
            LXDrawer.show(host: bridge?.viewController?.view)
            LXDrawer.place(below: v)
            notifyListeners("homeAct", data: ["act": "edgeBegin"])
            edgeBeginResends = 0
        case .changed:
            let x = min(max(0, g.translation(in: v).x), drawerW)
            v.transform = CGAffineTransform(translationX: x, y: 0)
            if x > 30, edgeBeginResends < 4 {
                edgeBeginResends += 1
                notifyListeners("homeAct", data: ["act": "edgeBegin"])
            }
        case .ended, .cancelled, .failed:
            let x = min(max(0, g.translation(in: v).x), drawerW)
            let vx = g.velocity(in: v).x
            let open = vx > 350 ? true : (vx < -350 ? false : x > drawerW / 2)
            settleHome(open: open)
        default: break
        }
    }

    private var homeBaseTx: CGFloat = 0
    @objc func homeClosePan(_ g: UIPanGestureRecognizer) {
        guard let v = home else { return }
        switch g.state {
        case .began:
            homeBaseTx = v.transform.tx
        case .changed:
            let x = min(max(0, homeBaseTx + g.translation(in: v).x), drawerW)
            let tf = CGAffineTransform(translationX: x, y: 0)
            v.transform = tf
            LXVoiceDock.shared?.transform = tf
            LXCallPill.shared?.transform = tf
        case .ended, .cancelled, .failed:
            let x = v.transform.tx
            let vx = g.velocity(in: v).x
            settleHome(open: vx > 350 ? true : (vx < -350 ? false : x > drawerW / 2))
        default: break
        }
    }

    func settleHome(open: Bool, notify: Bool = true) {
        guard let v = home else { return }
        let tf = open ? CGAffineTransform(translationX: drawerW, y: 0) : .identity
        let a = UIViewPropertyAnimator(duration: 0.28,
            controlPoint1: CGPoint(x: 0.22, y: 1), controlPoint2: CGPoint(x: 0.36, y: 1)) {
            v.transform = tf
            LXVoiceDock.shared?.transform = tf
            LXCallPill.shared?.transform = tf
        }
        if !open { a.addCompletion { _ in LXDrawer.hide() } }
        a.startAnimation()
        if notify { notifyListeners("homeAct", data: ["act": "edgeSettled", "open": open]) }
    }

    @objc private func homeBgTap() {
        if (home?.transform.tx ?? 0) > 0 { settleHome(open: false) }
    }

    @objc func homeSettle(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.settleHome(open: call.getBool("open") ?? false, notify: false)
            call.resolve(["ok": true])
        }
    }

    func previewDismissEarly() {
        guard LustreConfig.isPreview else { return }
        if let host = bridge?.viewController?.view {
            for sub in host.subviews where sub is HomeView { sub.removeFromSuperview() }
        }
        home?.removeFromSuperview()
        home = nil
        // 开首页时藏了输入栏,正常关首页会放回来;这条捷径以前漏了,预览里聊天页一直没有输入栏
        NativeInputPlugin.live?.setCardHidden(false)
    }

    func openHomeNative() {
        guard let host = bridge?.viewController?.view else { return }
        let cached = UserDefaults.standard.dictionary(forKey: HomePlugin.themeCacheKey) ?? [:]
        NativeInputPlugin.live?.setCardHidden(true)
        attachEarly(host: host, payload: cached)
    }

    func leaveHome() {
        DispatchQueue.main.async {
            if let host = self.bridge?.viewController?.view {
                for sub in host.subviews where sub is HomeView { sub.removeFromSuperview() }
            }
            self.home?.removeFromSuperview()
            self.home = nil
            LXDrawer.hide()
        }
    }

    @objc func homeDisable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let host = self.bridge?.viewController?.view {
                for sub in host.subviews where sub is HomeView { sub.removeFromSuperview() }
            }
            self.home?.removeFromSuperview()
            self.home = nil
            LXDrawer.hide()
            call.resolve(["ok": true])
        }
    }

    @objc func homeHide(_ call: CAPPluginCall) {
        let hide = call.getBool("on") ?? true
        DispatchQueue.main.async {
            let holding = self.homeDrawerOpen
            self.home?.isHidden = hide
            if hide, !holding { LXDrawer.hide() }
            LXStage.settle(self.bridge?.viewController?.view)
            call.resolve(["ok": true])
        }
    }

    @objc func homeStatus(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["on": self.home != nil && !(self.home?.isHidden ?? true)])
        }
    }

    static weak var live: HomePlugin?
    var homeDrawerOpen: Bool { !(home?.isHidden ?? true) && (home?.transform.tx ?? 0) > 0 }
    override public func load() {
        Self.live = self
        // composer 路线只拍输入栏:下面这套首页自检 62 秒后会铺满全屏,不跑
        guard LustreConfig.isPreview, LustreConfig.previewFocus != "composer" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 62) { [weak self] in
            guard let s = self, let host = s.bridge?.viewController?.view else { return }
            let v = HomeView(theme: HomeTheme(), flameURL: "")
            v.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: host.topAnchor),
                v.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
            s.home = v
            v.loadAll()
            v.playEnter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { v.openRenderGate() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                let cards = [v.vitals.bounds.size, v.calCard.bounds.size,
                             v.memCard.bounds.size, v.todoCard.bounds.size]
                let desc = cards.map { "\(Int($0.width))x\(Int($0.height))" }.joined(separator: " ")
                let calH = Int(v.calCard.bounds.height.rounded())
                s.homeProbe("home-check", desc + (calH == 54 ? " 日历收起54✓" : " 日历收起\(calH)✗应54"))
                let realHome = s.home
                let mockHost = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
                s.attach(host: mockHost, theme: HomeTheme(), flame: "", enter: false, deferLoad: true)
                s.attach(host: mockHost, theme: HomeTheme(), flame: "", enter: false, deferLoad: true)
                let alive = mockHost.subviews.filter { $0 is HomeView }.count
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak s] in
                    guard let s = s else { return }
                    let after = mockHost.subviews.filter { $0 is HomeView }.count
                    let extras = mockHost.subviews.count - after
                    s.homeProbe("home-dual", (alive == 1 && after == 1 && extras == 0)
                                ? "单实例OK 连环换新活=1 残影焚尽"
                                : "BAD 即时活=\(alive) 后活=\(after) 残=\(extras)")
                    s.home = realHome
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { v.calCard.previewReveal() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    v.calCard.previewFlipPrev()
                    v.vitals.previewSelectBar(0)
                    v.todoCard.previewInject()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 16) {
                    v.sheet.open(iso: HCCard.todayIso)
                }
                func sheetCheckWhenLoaded(_ tries: Int) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        let r = v.sheet.probeScroll()
                        if r.contains("可滚=true") || tries >= 15 {
                            Self.probeStatic("sheet-scroll", r + " 等了\(tries * 2)s")
                        } else {
                            sheetCheckWhenLoaded(tries + 1)
                        }
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 18) { sheetCheckWhenLoaded(0) }
            }
        }
    }

    private func homeProbe(_ tag: String, _ extra: String) { Self.probeStatic(tag, extra) }

    private var liveWatchTimer: Timer?
    private var dupStreak = 0
    private var edgeBeginResends = 0
    private func startLiveWatch(host: UIView) {
        guard liveWatchTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self, weak host] _ in
            guard let s = self, let h = host else { return }
            let homes = h.subviews.filter { $0 is HomeView }
            let ghosts = h.subviews.filter { $0.tag == 7719 }
            if homes.count <= 1 && ghosts.isEmpty { s.dupStreak = 0; return }
            s.dupStreak += 1
            guard s.dupStreak <= 3 else { return }
            var desc: [String] = []
            for (i, v0) in (homes + ghosts).enumerated() {
                let kind = v0.tag == 7719 ? "残影" : (v0 === s.home ? "现任" : "孤儿")
                desc.append("[\(i)]\(kind) x=\(Int(v0.frame.minX)) tx=\(Int(v0.transform.tx)) a=\(String(format: "%.2f", v0.alpha)) hid=\(v0.isHidden)")
            }
            s.homeProbe("home-live", "双份现场! 活=\(homes.count) 残=\(ghosts.count) " + desc.joined(separator: " "))
        }
        t.tolerance = 2
        liveWatchTimer = t
    }

    static func probeStatic(_ tag: String, _ extra: String) {
        guard let u = URL(string: LustreConfig.apiBase + "/app/kbdebug") else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["tag": "echo-native", "step": tag, "extra": extra])
        URLSession.shared.dataTask(with: r).resume()
    }
}


struct RPTint {
    let page, card, cardBorder, text, faint, fainter, icon, fill, track, statBg, press: UIColor
    let shadowA: Float
}
enum RPSpec {
    static var moonState: String = UserDefaults.standard.string(forKey: "lx.rp.moon") ?? "moon" {
        didSet { UserDefaults.standard.set(moonState, forKey: "lx.rp.moon") }
    }
    static let tints: [String: RPTint] = [
        "day": RPTint(
            page: UIColor(red: 0xE9/255, green: 0xF2/255, blue: 0xFB/255, alpha: 1),
            card: UIColor(white: 1, alpha: 0.58),
            cardBorder: UIColor(red: 122/255, green: 140/255, blue: 158/255, alpha: 0.22),
            text: UIColor(red: 0x2A/255, green: 0x3A/255, blue: 0x4D/255, alpha: 1),
            faint: UIColor(red: 0x64/255, green: 0x79/255, blue: 0x8D/255, alpha: 1),
            fainter: UIColor(red: 0x92/255, green: 0xA6/255, blue: 0xB8/255, alpha: 1),
            icon: UIColor(red: 0x61/255, green: 0x8F/255, blue: 0xBD/255, alpha: 1),
            fill: UIColor(red: 0x61/255, green: 0x8F/255, blue: 0xBD/255, alpha: 1),
            track: UIColor(red: 143/255, green: 162/255, blue: 176/255, alpha: 0.28),
            statBg: UIColor(red: 140/255, green: 160/255, blue: 176/255, alpha: 0.11),
            press: UIColor(white: 0, alpha: 0.06),
            shadowA: 0.12),
        "half": RPTint(
            page: UIColor(red: 0x19/255, green: 0x19/255, blue: 0x17/255, alpha: 1),
            card: UIColor(red: 38/255, green: 38/255, blue: 36/255, alpha: 0.62),
            cardBorder: UIColor(white: 1, alpha: 0.08),
            text: UIColor(red: 0xE9/255, green: 0xE5/255, blue: 0xDC/255, alpha: 1),
            faint: UIColor(red: 0xA5/255, green: 0xA1/255, blue: 0x98/255, alpha: 1),
            fainter: UIColor(red: 0x6E/255, green: 0x6B/255, blue: 0x64/255, alpha: 1),
            icon: UIColor(red: 0xDA/255, green: 0x7A/255, blue: 0x55/255, alpha: 1),
            fill: UIColor(red: 0xDA/255, green: 0x7A/255, blue: 0x55/255, alpha: 1),
            track: UIColor(white: 1, alpha: 0.14),
            statBg: UIColor(white: 1, alpha: 0.10),
            press: UIColor(white: 1, alpha: 0.06),
            shadowA: 0.55),
        "moon": RPTint(
            page: UIColor.black,
            card: UIColor(red: 38/255, green: 37/255, blue: 42/255, alpha: 1),
            cardBorder: UIColor(red: 242/255, green: 244/255, blue: 248/255, alpha: 0.07),
            text: UIColor(red: 227/255, green: 226/255, blue: 231/255, alpha: 1),
            faint: UIColor(red: 165/255, green: 176/255, blue: 198/255, alpha: 1),
            fainter: UIColor(red: 113/255, green: 126/255, blue: 151/255, alpha: 1),
            icon: UIColor(red: 169/255, green: 217/255, blue: 238/255, alpha: 1),
            fill: UIColor(red: 182/255, green: 214/255, blue: 232/255, alpha: 1),
            track: UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.14),
            statBg: UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10),
            press: UIColor(white: 1, alpha: 0.06),
            shadowA: 0.55),
    ]
    static var cur: RPTint { tints[moonState] ?? tints["moon"]! }
    static var page: UIColor { cur.page }
    static var card: UIColor { cur.card }
    static var cardBorder: UIColor { cur.cardBorder }
    static var text: UIColor { cur.text }
    static var faint: UIColor { cur.faint }
    static var fainter: UIColor { cur.fainter }
    static var icon: UIColor { cur.icon }
    static var fill: UIColor { cur.fill }
    static let fillWarn = UIColor(red: 0xCF/255, green: 0x8D/255, blue: 0x5A/255, alpha: 1)
    static let fillHot = UIColor(red: 0xCF/255, green: 0x5A/255, blue: 0x5A/255, alpha: 1)
    static var track: UIColor { cur.track }
    static var statBg: UIColor { cur.statBg }
    static var press: UIColor { cur.press }

    static func tok(_ n: Double) -> String {
        if n >= 1_000_000 {
            let v = n / 1_000_000
            let s = String(format: "%.1f", v)
            return (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + "M"
        }
        if n >= 1_000 { return String(format: "%.0fk", n / 1_000) }
        return String(format: "%.0f", n)
    }
    static func reset(_ iso: String?) -> String {
        guard let iso = iso, !iso.isEmpty else { return "" }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        guard let t0 = f.date(from: iso) ?? f2.date(from: iso) else { return "" }
        let t = Date(timeIntervalSince1970: ((t0.timeIntervalSince1970 + 30) / 60).rounded(.down) * 60)
        let mins = max(0, Int((t0.timeIntervalSinceNow / 60).rounded()))
        if mins < 100 { return "resets in \(mins)m" }
        let df = DateFormatter(); df.dateFormat = "EEE HH:mm"; df.locale = Locale(identifier: "en_US")
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return "resets " + df.string(from: t)
    }
}

final class RPUsageRow: UIView {
    private let nameL = UILabel(), valL = UILabel()
    private let track = UIView(), fill = UIView()
    private var fillW: NSLayoutConstraint!
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for l in [nameL, valL] { l.translatesAutoresizingMaskIntoConstraints = false; l.font = LXDrawerTint.font(12.5) }
        nameL.textColor = RPSpec.faint
        valL.textColor = RPSpec.text
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = RPSpec.track
        track.layer.cornerRadius = 3.5; track.clipsToBounds = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.layer.cornerRadius = 3.5
        addSubview(nameL); addSubview(valL); addSubview(track); track.addSubview(fill)
        fillW = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            nameL.topAnchor.constraint(equalTo: topAnchor),
            nameL.leadingAnchor.constraint(equalTo: leadingAnchor),
            valL.topAnchor.constraint(equalTo: topAnchor),
            valL.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.topAnchor.constraint(equalTo: nameL.bottomAnchor, constant: 5),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.heightAnchor.constraint(equalToConstant: 7),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fillW,
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(_ name: String, pct: Int, resetTxt: String) { set(name, pct: pct, valueTxt: "\(pct)% · \(resetTxt)") }
    func set(_ name: String, pct: Int, valueTxt: String) {
        nameL.text = name
        valL.text = valueTxt
        fill.backgroundColor = pct >= 85 ? RPSpec.fillHot : (pct >= 65 ? RPSpec.fillWarn : RPSpec.fill)
        layoutIfNeeded()
        let w = track.bounds.width * CGFloat(min(100, pct)) / 100
        fillW.constant = w
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.9,
                       initialSpringVelocity: 0.2, options: [.allowUserInteraction]) { self.track.layoutIfNeeded() }
    }
}

final class RPActionRow: UIControl {
    let nameL = UILabel(), valL = UILabel()
    private let iconV = UIImageView()
    let sep = UIView()
    init(icon: UIImage?, name: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 54).isActive = true
        layer.cornerRadius = 12
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.backgroundColor = RPSpec.cardBorder
        sep.isUserInteractionEnabled = false
        addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])
        iconV.translatesAutoresizingMaskIntoConstraints = false
        iconV.image = icon; iconV.tintColor = RPSpec.icon; iconV.contentMode = .center
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.font = LXDrawerTint.font(14); nameL.textColor = RPSpec.text; nameL.text = name
        valL.translatesAutoresizingMaskIntoConstraints = false
        valL.font = LXDrawerTint.font(12.5); valL.textColor = RPSpec.fainter
        for v in [iconV, nameL, valL] { v.isUserInteractionEnabled = false; addSubview(v) }
        NSLayoutConstraint.activate([
            iconV.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconV.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconV.widthAnchor.constraint(equalToConstant: 21),
            iconV.heightAnchor.constraint(equalToConstant: 21),
            nameL.leadingAnchor.constraint(equalTo: iconV.trailingAnchor, constant: 10),
            nameL.centerYAnchor.constraint(equalTo: centerYAnchor),
            valL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            valL.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    var menuItems: [UIMenuElement] = [] {
        didSet {
            isContextMenuInteractionEnabled = !menuItems.isEmpty
            showsMenuAsPrimaryAction = !menuItems.isEmpty
        }
    }
    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                         configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard !menuItems.isEmpty else { return nil }
        let items = menuItems
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in UIMenu(children: items) }
    }
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? RPSpec.press : .clear }
    }
}

final class RPanelView: UIView {
    var onAct: ((String) -> Void)?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var rowSession = RPUsageRow(), rowWeekAll = RPUsageRow(), rowFable = RPUsageRow()
    private var rowEleven = RPUsageRow()
    private let backBtn = UIButton(type: .custom), moonBtn = UIButton(type: .custom)
    private let fableTitleDefault = "Weekly · Fable"
    private var statBs: [UILabel] = [], statSs: [UILabel] = []
    private let updatedL = UILabel()
    let rowsById: [(String, String)] = [
        ("chatAvatarsRow", "Message avatars"),
        ("avatarMenu", "Change avatar"),
        ("wallMenu", "Chat background"),
    ]
    var actionRows: [RPActionRow] = []

    private static func glyph(_ draw: (CGContext, CGRect) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 19, height: 19)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(1.7); c.setLineCap(.round); c.setLineJoin(.round)
            draw(c, CGRect(x: 0, y: 0, width: 19, height: 19))
        }.withRenderingMode(.alwaysTemplate)
    }
    static let iPerson = glyph { c, _ in
        c.strokeEllipse(in: CGRect(x: 6.2, y: 2.5, width: 6.6, height: 6.6))
        c.move(to: CGPoint(x: 3.2, y: 16.5))
        c.addCurve(to: CGPoint(x: 15.8, y: 16.5), control1: CGPoint(x: 5.5, y: 11.5), control2: CGPoint(x: 13.5, y: 11.5))
        c.strokePath()
    }
    static let iPersonPlus = glyph { c, _ in
        c.strokeEllipse(in: CGRect(x: 5.2, y: 2.5, width: 6.2, height: 6.2))
        c.move(to: CGPoint(x: 2.5, y: 16.5))
        c.addCurve(to: CGPoint(x: 14, y: 16.5), control1: CGPoint(x: 4.5, y: 11.8), control2: CGPoint(x: 12, y: 11.8))
        c.strokePath()
        c.move(to: CGPoint(x: 15.5, y: 6)); c.addLine(to: CGPoint(x: 15.5, y: 10))
        c.move(to: CGPoint(x: 13.5, y: 8)); c.addLine(to: CGPoint(x: 17.5, y: 8))
        c.strokePath()
    }
    static let iWall = glyph { c, _ in
        c.stroke(CGRect(x: 2.5, y: 3.5, width: 14, height: 12), width: 1.7)
        c.strokeEllipse(in: CGRect(x: 5.5, y: 6, width: 2.4, height: 2.4))
        c.move(to: CGPoint(x: 4.5, y: 13.5))
        c.addLine(to: CGPoint(x: 8.5, y: 9.5)); c.addLine(to: CGPoint(x: 11.5, y: 12.5))
        c.addLine(to: CGPoint(x: 13.5, y: 10.5)); c.addLine(to: CGPoint(x: 16, y: 13))
        c.strokePath()
    }
    static let iReset = glyph { c, _ in
        c.addArc(center: CGPoint(x: 9.5, y: 9.5), radius: 6.2, startAngle: -.pi * 0.4, endAngle: .pi * 1.15, clockwise: false)
        c.strokePath()
        c.move(to: CGPoint(x: 11.2, y: 1.6)); c.addLine(to: CGPoint(x: 12.4, y: 4.6)); c.addLine(to: CGPoint(x: 9.2, y: 5.4))
        c.strokePath()
    }
    static let iBack = glyph { c, _ in
        c.move(to: CGPoint(x: 12, y: 3)); c.addLine(to: CGPoint(x: 6, y: 9.5)); c.addLine(to: CGPoint(x: 12, y: 16))
        c.strokePath()
    }
    private static func moonGlyph(_ draw: (CGContext) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 21, height: 21)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.white.cgColor); c.setFillColor(UIColor.white.cgColor)
            c.setLineWidth(1.4875); c.setLineCap(.round); c.setLineJoin(.round)
            draw(c)
        }.withRenderingMode(.alwaysTemplate)
    }
    private static func crescent(_ c: CGContext) {
        c.move(to: CGPoint(x: 18.375, y: 11.2))
        c.addArc(center: CGPoint(x: 10.534, y: 10.466), radius: 7.875,
                 startAngle: 0.0934, endAngle: 4.6191, clockwise: false)
        c.addArc(center: CGPoint(x: 14.700, y: 6.300), radius: 6.125,
                 startAngle: 3.7851, endAngle: 0.9273, clockwise: true)
        c.closePath()
    }
    static let iMoonDay  = moonGlyph { c in crescent(c); c.strokePath() }
    static let iMoonHalf = moonGlyph { c in crescent(c); c.drawPath(using: .fillStroke) }
    static let iMoonFull = moonGlyph { c in c.fillEllipse(in: CGRect(x: 2.975, y: 2.975, width: 15.05, height: 15.05)) }
    static func moonIcon(_ st: String) -> UIImage {
        st == "day" ? iMoonDay : (st == "half" ? iMoonHalf : iMoonFull)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = RPSpec.page

        let back = backBtn, moon = moonBtn
        back.translatesAutoresizingMaskIntoConstraints = false
        back.setImage(Self.iBack.withConfiguration(UIImage.SymbolConfiguration(pointSize: 19)), for: .normal)
        back.setImage(Self.iBack, for: .normal)
        back.tintColor = RPSpec.text
        back.layer.cornerRadius = 20
        back.addAction(UIAction { [weak self] _ in self?.onAct?("back") }, for: .touchUpInside)
        moon.translatesAutoresizingMaskIntoConstraints = false
        moon.setImage(Self.moonIcon(RPSpec.moonState), for: .normal)
        moon.tintColor = RPSpec.faint
        moon.addAction(UIAction { [weak self] _ in self?.onAct?("moon") }, for: .touchUpInside)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.alwaysBounceHorizontal = false
        scroll.isDirectionalLockEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 22
        addSubview(back); addSubview(moon); addSubview(scroll); scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            back.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 15),
            back.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            back.widthAnchor.constraint(equalToConstant: 40),
            back.heightAnchor.constraint(equalToConstant: 40),
            moon.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            moon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            moon.widthAnchor.constraint(equalToConstant: 33),
            moon.heightAnchor.constraint(equalToConstant: 33),
            scroll.topAnchor.constraint(equalTo: back.bottomAnchor, constant: 6),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -64),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        stack.addArrangedSubview(buildUsageCard())
        stack.addArrangedSubview(buildMiniCard())
    }
    required init?(coder: NSCoder) { fatalError() }

    private func card() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = RPSpec.card
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1
        v.layer.borderColor = RPSpec.cardBorder.cgColor
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = RPSpec.cur.shadowA
        v.layer.shadowOffset = CGSize(width: 0, height: 10)
        v.layer.shadowRadius = 14
        return v
    }

    private func buildUsageCard() -> UIView {
        let cardV = card()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LXDrawerTint.font(12.5)
        label.textColor = RPSpec.faint
        label.attributedText = NSAttributedString(string: "Usage", attributes: [.kern: 0.125])
        let inner = UIStackView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.axis = .vertical
        inner.spacing = 12
        for r in [rowSession, rowWeekAll, rowFable, rowEleven] { inner.addArrangedSubview(r) }
        let statsRow = UIStackView()
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        statsRow.axis = .horizontal
        statsRow.spacing = 8
        statsRow.distribution = .fillEqually
        for cap in ["5h window", "Today", "This week"] {
            let box = UIView()
            box.translatesAutoresizingMaskIntoConstraints = false
            box.backgroundColor = RPSpec.statBg
            box.layer.cornerRadius = 11
            let b = UILabel(); b.font = LXDrawerTint.font(14.5); b.textColor = RPSpec.text
            let s = UILabel(); s.font = LXDrawerTint.font(10.5); s.textColor = RPSpec.fainter
            s.text = cap
            for l in [b, s] { l.translatesAutoresizingMaskIntoConstraints = false; l.textAlignment = .center; box.addSubview(l) }
            NSLayoutConstraint.activate([
                b.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
                b.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 4),
                b.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -4),
                s.topAnchor.constraint(equalTo: b.bottomAnchor, constant: 2),
                s.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 4),
                s.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -4),
                s.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
            ])
            statBs.append(b); statSs.append(s)
            statsRow.addArrangedSubview(box)
        }
        updatedL.translatesAutoresizingMaskIntoConstraints = false
        updatedL.font = LXDrawerTint.font(11)
        updatedL.textColor = RPSpec.fainter
        for v in [label, inner, statsRow, updatedL] { cardV.addSubview(v) }
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: cardV.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
            inner.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 11),
            inner.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
            inner.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -15),
            statsRow.topAnchor.constraint(equalTo: inner.bottomAnchor, constant: 12),
            statsRow.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
            statsRow.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -15),
            statsRow.heightAnchor.constraint(equalToConstant: 54),
            updatedL.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: 9),
            updatedL.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
            updatedL.bottomAnchor.constraint(equalTo: cardV.bottomAnchor, constant: -14),
        ])
        return cardV
    }

    private func buildMiniCard() -> UIView {
        let cardV = card()
        let inner = UIStackView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.axis = .vertical
        let icons: [UIImage] = [Self.iPerson, Self.iPersonPlus, Self.iWall]
        for (i, (wid, name)) in rowsById.enumerated() {
            let row = RPActionRow(icon: icons[i], name: name)
            row.valL.text = wid == "chatAvatarsRow" ? "Off" : "Default"
            func item(_ title: String, _ sf: String, _ act: String) -> UIAction {
                UIAction(title: title, image: UIImage(systemName: sf)) { [weak self] _ in self?.onAct?(act) }
            }
            switch wid {
            case "avatarMenu":
                row.menuItems = [item("My avatar", "person", "customAvatarHumanRow"),
                                 item("Lustre avatar", "person.fill", "customAvatarAiRow"),
                                 item("Lucid avatar", "sparkle", "customAvatarZhaoRow")]
            case "wallMenu":
                row.menuItems = [item("Choose photo", "photo", "customWallRow"),
                                 item("Reset to default", "arrow.counterclockwise", "customWallReset")]
            default:
                row.addAction(UIAction { [weak self] _ in
                    homePop(row)
                    self?.onAct?(wid)
                }, for: .touchUpInside)
            }
            actionRows.append(row)
            inner.addArrangedSubview(row)
        }
        actionRows.last?.sep.isHidden = true
        cardV.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: cardV.topAnchor, constant: 1),
            inner.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 10),
            inner.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -10),
            inner.bottomAnchor.constraint(equalTo: cardV.bottomAnchor, constant: -1),
        ])
        return cardV
    }

    var usageRowsVisible: Int { [rowSession, rowWeekAll, rowFable, rowEleven].filter { !$0.isHidden }.count }

    func renderUsage(_ d: [String: Any]) {
        let off = (d["official"] as? [String: Any]) ?? [:]
        func row(_ r: RPUsageRow, _ label: String, _ key: String) {
            guard let o = off[key] as? [String: Any], let p = o["pct"] as? NSNumber else { r.isHidden = true; return }
            r.isHidden = false
            r.set(label, pct: min(100, Int(p.doubleValue.rounded())), resetTxt: RPSpec.reset(o["resets_at"] as? String))
        }
        row(rowSession, "Current session", "session")
        row(rowWeekAll, "Weekly · all models", "week_all")
        let fname = (off["week_fable_name"] as? String) ?? "Fable"
        row(rowFable, "Weekly · \(fname)", "week_fable")
        if let e = d["eleven"] as? [String: Any], let p = e["pct"] as? NSNumber {
            let used = (e["used"] as? NSNumber)?.doubleValue ?? 0
            let lim = (e["limit"] as? NSNumber)?.doubleValue ?? 0
            var rs = ""
            if let iso = e["resets_at"] as? String, let t = ISO8601DateFormatter().date(from: iso) {
                let df = DateFormatter(); df.dateFormat = "MMM d"; df.locale = Locale(identifier: "en_US")
                df.timeZone = TimeZone(identifier: "Asia/Shanghai")
                rs = " · resets " + df.string(from: t)
            }
            rowEleven.isHidden = false
            rowEleven.set("ElevenLabs · voice", pct: min(100, Int(p.doubleValue.rounded())),
                          valueTxt: "\(RPSpec.tok(used)) / \(RPSpec.tok(lim)) · \(Int(p.doubleValue.rounded()))%\(rs)")
        } else { rowEleven.isHidden = true }
        let vals: [Double] = [
            (d["window_5h"] as? NSNumber)?.doubleValue ?? 0,
            (d["today"] as? NSNumber)?.doubleValue ?? 0,
            (d["week"] as? NSNumber)?.doubleValue ?? 0,
        ]
        for (i, v) in vals.enumerated() where i < statBs.count { statBs[i].text = RPSpec.tok(v) }
        if let up = d["updated"] as? String {
            let f = ISO8601DateFormatter()
            let df = DateFormatter(); df.dateFormat = "HH:mm"
            df.timeZone = TimeZone(identifier: "Asia/Shanghai")
            if let t = f.date(from: up) { updatedL.text = "Updated " + df.string(from: t) + " · native" }
        }
    }

    func retheme() {
        backgroundColor = RPSpec.page
        backBtn.tintColor = RPSpec.text
        moonBtn.setImage(Self.moonIcon(RPSpec.moonState), for: .normal)
        moonBtn.tintColor = RPSpec.faint
        let keepOffset = scroll.contentOffset
        let keepVals = actionRows.map { $0.valL.text }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        statBs = []; statSs = []; actionRows = []
        rowSession = RPUsageRow(); rowWeekAll = RPUsageRow(); rowFable = RPUsageRow(); rowEleven = RPUsageRow()
        stack.addArrangedSubview(buildUsageCard())
        stack.addArrangedSubview(buildMiniCard())
        for (i, v) in keepVals.enumerated() where i < actionRows.count {
            if let v = v { actionRows[i].valL.text = v }
        }
        if let cached = UserDefaults.standard.data(forKey: "lx.rp.usage"),
           let d = (try? JSONSerialization.jsonObject(with: cached)) as? [String: Any] {
            renderUsage(d)
        }
        layoutIfNeeded()
        scroll.contentOffset = keepOffset
    }

    func fetchUsage() {
        if let cached = UserDefaults.standard.data(forKey: "lx.rp.usage"),
           let d0 = (try? JSONSerialization.jsonObject(with: cached)) as? [String: Any] {
            renderUsage(d0)
        }
        guard let url = URL(string: LustreConfig.origin + "/chat/usage.json?t=\(Int(Date().timeIntervalSince1970))") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
            UserDefaults.standard.set(data, forKey: "lx.rp.usage")
            DispatchQueue.main.async { self?.renderUsage(d) }
        }.resume()
    }
}


final class LXVerticalScroll: UIScrollView {
    override var contentOffset: CGPoint {
        get { super.contentOffset }
        set { super.contentOffset = CGPoint(x: 0, y: newValue.y) }
    }
    override var contentSize: CGSize {
        get { super.contentSize }
        set { super.contentSize = CGSize(width: min(newValue.width, bounds.width), height: newValue.height) }
    }
}
