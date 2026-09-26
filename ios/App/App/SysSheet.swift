import UIKit
import Capacitor
import CoreLocation
import EventKit
import HealthKit
import LocalAuthentication
import UserNotifications



struct LXSysRow {
    let sel: String, icon: String, icText: String, name: String, sub: String, val: String
    let on: Bool, isStatic: Bool, chev: Bool, dot: String
}
struct LXSysGroup { let title: String; let rows: [LXSysRow] }
struct LXSysSpec {
    let groups: [LXSysGroup]
    let note: String
    let sig: String
    static let key = "lx.sys.spec"
    static func from(_ d: [String: Any]) -> LXSysSpec {
        var gs: [LXSysGroup] = []
        for g in (d["groups"] as? [[String: Any]]) ?? [] {
            var rows: [LXSysRow] = []
            for r in (g["rows"] as? [[String: Any]]) ?? [] {
                rows.append(LXSysRow(sel: r["sel"] as? String ?? "", icon: r["icon"] as? String ?? "",
                                     icText: r["icText"] as? String ?? "", name: r["name"] as? String ?? "",
                                     sub: r["sub"] as? String ?? "", val: r["val"] as? String ?? "",
                                     on: (r["on"] as? Bool) ?? false, isStatic: (r["static"] as? Bool) ?? false,
                                     chev: (r["chev"] as? Bool) ?? false, dot: r["dot"] as? String ?? ""))
            }
            gs.append(LXSysGroup(title: g["title"] as? String ?? "", rows: rows))
        }
        let sig = (try? JSONSerialization.data(withJSONObject: d)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return LXSysSpec(groups: gs, note: d["note"] as? String ?? "", sig: sig)
    }
    static func load() -> LXSysSpec { from(UserDefaults.standard.dictionary(forKey: key) ?? [:]) }
    static func save(_ d: [String: Any]) { UserDefaults.standard.set(d, forKey: key) }
}


enum LXSysIcons {
    private static var cache: [String: UIImage] = [:]
    static func image(_ key: String) -> UIImage? {
        if let c = cache[key] { return c }
        var stroke: CGFloat = 1.7
        var size: CGFloat = 17
        let parts: [LXSVG.Part]
        switch key {
        case "nativeinput":
            stroke = 1.6
            parts = [.rect(3, 6.5, 18, 11, 2.4), .path("M6.5 10h.01M10 10h.01M13.5 10h.01M17 10h.01M6.5 13h.01M17 13h.01M9 14.5h6")]
        case "nativechat":
            stroke = 1.6
            parts = [.path("M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"), .path("M8 9.5h8M8 13h5")]
        case "mirror":
            stroke = 1.6
            parts = [.path("M12 3v10M12 13l-3.5-3.5M12 13l3.5-3.5"), .path("M4.5 16.5v1.8A1.7 1.7 0 0 0 6.2 20h11.6a1.7 1.7 0 0 0 1.7-1.7v-1.8")]
        case "location":  parts = [.path("M21 3L3 10.2l7.6 2.9 2.9 7.6z")]
        case "calendar":  parts = [.rect(3.2, 5, 17.6, 15.6, 3), .path("M3.2 9.6h17.6M8 3v3.6M16 3v3.6")]
        case "reminders": parts = [.path("M4 7.4L5.6 9l3-3.2M4 16.4L5.6 18l3-3.2M12.4 7h7.4M12.4 16.2h7.4")]
        case "lock":      parts = [.rect(4.2, 10.4, 15.6, 10.4, 2.8), .path("M8 10.4V7.6a4 4 0 0 1 8 0v2.8")]
        case "bell":      parts = [.path("M18 9.4a6 6 0 1 0-12 0c0 5.1-2 6.6-2 6.6h16s-2-1.5-2-6.6"), .path("M13.7 20a2 2 0 0 1-3.4 0")]
        case "wire":      parts = [.path("M7 4v5a5 5 0 0 0 10 0V4"), .path("M4.6 4h4.8M14.6 4h4.8"), .path("M12 14v6")]
        case "bg":        parts = [.path("M20 11a8 8 0 1 0-.6 4"), .path("M20 4.5V11h-6")]
        case "health":    parts = [.path("M12 20.4S3.6 15.3 3.6 9.6A4.6 4.6 0 0 1 12 7a4.6 4.6 0 0 1 8.4 2.6c0 5.7-8.4 10.8-8.4 10.8Z")]
        case "phone.in", "phone.out", "phone.miss", "doc":
            stroke = 1.6
            let handset = LXSVG.Part.path("M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.6a2 2 0 0 1-.5 2.1L8 9.7a16 16 0 0 0 6.3 6.3l1.3-1.3a2 2 0 0 1 2.1-.5c.8.3 1.7.6 2.6.7a2 2 0 0 1 1.7 2z")
            switch key {
            case "phone.in":   parts = [handset, .path("M16 2v6h6M22 2l-6 6")]
            case "phone.out":  parts = [handset, .path("M23 1l-6 6M17 1h6v6")]
            case "phone.miss": parts = [handset, .path("M23 1l-6 6M17 1l6 6")]
            default:           parts = [.path("M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"), .path("M14 2v6h6M16 13H8M16 17H8M10 9H8")]
            }
        case "chev":      stroke = 2;   size = 16; parts = [.path("M9 6l6 6-6 6")]
        case "close":     stroke = 2.2; size = 17; parts = [.path("M18 6L6 18M6 6l12 12")]
        case "refresh":   stroke = 1.8; size = 19; parts = [.path("M20 11a8 8 0 1 0-.6 4"), .path("M20 4.5V11h-6")]
        default: return nil
        }
        let img = LXSVG.icon(parts, size: size, stroke: stroke, box: 24)
        cache[key] = img
        return img
    }
}


struct LXSysTint {
    let page, card, hairline, text, soft, faint, accent, track, closeBg, handle, dotOff: UIColor
    static func cur() -> LXSysTint {
        let t = RPSpec.cur
        let day = RPSpec.moonState == "day"
        return LXSysTint(page: t.page, card: t.card, hairline: t.cardBorder, text: t.text, soft: t.faint,
                         faint: t.fainter, accent: t.icon, track: t.statBg,
                         closeBg: day ? .white : t.card,
                         handle: t.fainter,
                         dotOff: UIColor(red: 0xC2/255, green: 0x50/255, blue: 0x4F/255, alpha: 1))
    }
}


final class LXSysRowView: UIControl {
    let row: LXSysRow
    private let icBox = UIView(), icV = UIImageView(), icL = UILabel()
    private let nameL = UILabel(), subL = UILabel(), valL = UILabel(), chevV = UIImageView(), dotV = UIView()
    let sep = UIView()
    private var tint: LXSysTint
    init(_ r: LXSysRow, tint: LXSysTint, first: Bool) {
        row = r; self.tint = tint
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isEnabled = !r.isStatic
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.isUserInteractionEnabled = false
        sep.isHidden = first
        addSubview(sep)
        icBox.translatesAutoresizingMaskIntoConstraints = false
        icBox.layer.cornerRadius = 9
        icBox.isUserInteractionEnabled = false
        addSubview(icBox)
        icV.translatesAutoresizingMaskIntoConstraints = false
        icV.contentMode = .center
        icBox.addSubview(icV)
        icL.translatesAutoresizingMaskIntoConstraints = false
        icL.textAlignment = .center
        icL.font = LXDrawerTint.font(r.icText.count <= 1 ? 13 : 11.5, wght: 600)
        icL.text = r.icText
        icBox.addSubview(icL)
        if let img = LXSysIcons.image(r.icon), r.icText.isEmpty { icV.image = img }
        icL.isHidden = r.icText.isEmpty
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.font = LXDrawerTint.font(15.5)
        nameL.text = r.name
        nameL.numberOfLines = 1
        subL.translatesAutoresizingMaskIntoConstraints = false
        subL.font = LXDrawerTint.font(12)
        subL.numberOfLines = 0
        let ps = NSMutableParagraphStyle(); ps.minimumLineHeight = 15; ps.maximumLineHeight = 15
        subL.attributedText = NSAttributedString(string: r.sub, attributes: [.paragraphStyle: ps, .font: LXDrawerTint.font(12)])
        subL.isHidden = r.sub.isEmpty
        let col = UIStackView(arrangedSubviews: [nameL, subL])
        col.translatesAutoresizingMaskIntoConstraints = false
        col.axis = .vertical
        col.spacing = 1
        col.isUserInteractionEnabled = false
        addSubview(col)
        valL.translatesAutoresizingMaskIntoConstraints = false
        valL.font = LXDrawerTint.font(14)
        valL.text = r.val
        valL.setContentCompressionResistancePriority(.required, for: .horizontal)
        valL.setContentHuggingPriority(.required, for: .horizontal)
        valL.textAlignment = .right
        valL.isHidden = r.val.isEmpty
        addSubview(valL)
        chevV.translatesAutoresizingMaskIntoConstraints = false
        chevV.contentMode = .center
        chevV.image = LXSysIcons.image("chev")
        chevV.alpha = 0.6
        chevV.isHidden = !r.chev
        addSubview(chevV)
        dotV.translatesAutoresizingMaskIntoConstraints = false
        dotV.layer.cornerRadius = 3.5
        dotV.isHidden = r.dot.isEmpty
        addSubview(dotV)
        let tail: UIView? = r.chev ? chevV : (r.dot.isEmpty ? nil : dotV)
        let wantH = heightAnchor.constraint(equalToConstant: 54)
        wantH.priority = .defaultLow
        var cons: [NSLayoutConstraint] = [
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54), wantH,
            sep.topAnchor.constraint(equalTo: topAnchor),
            sep.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 58),
            sep.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sep.heightAnchor.constraint(equalToConstant: 1),
            icBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            icBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            icBox.widthAnchor.constraint(equalToConstant: 30),
            icBox.heightAnchor.constraint(equalToConstant: 30),
            icV.centerXAnchor.constraint(equalTo: icBox.centerXAnchor),
            icV.centerYAnchor.constraint(equalTo: icBox.centerYAnchor),
            icL.centerXAnchor.constraint(equalTo: icBox.centerXAnchor),
            icL.centerYAnchor.constraint(equalTo: icBox.centerYAnchor),
            col.leadingAnchor.constraint(equalTo: icBox.trailingAnchor, constant: 12),
            col.centerYAnchor.constraint(equalTo: centerYAnchor),
            col.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 8),
            col.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            valL.centerYAnchor.constraint(equalTo: centerYAnchor),
            valL.leadingAnchor.constraint(equalTo: col.trailingAnchor, constant: 12),
            chevV.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevV.widthAnchor.constraint(equalToConstant: 16),
            chevV.heightAnchor.constraint(equalToConstant: 16),
            chevV.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            dotV.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotV.widthAnchor.constraint(equalToConstant: 7),
            dotV.heightAnchor.constraint(equalToConstant: 7),
            dotV.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ]
        if let tail = tail {
            cons.append(valL.trailingAnchor.constraint(equalTo: tail.leadingAnchor, constant: -12))
        } else {
            cons.append(valL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16))
        }
        NSLayoutConstraint.activate(cons)
        recolor(tint)
        if !r.sel.isEmpty {
            addTarget(self, action: #selector(tapped), for: .touchUpInside)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    var onTap: ((String) -> Void)?
    @objc private func tapped() { onTap?(row.sel) }
    override var isHighlighted: Bool {
        didSet { backgroundColor = (isHighlighted && !row.isStatic) ? tint.track : .clear }
    }
    func recolor(_ t: LXSysTint) {
        tint = t
        sep.backgroundColor = t.hairline
        icBox.backgroundColor = t.track
        icV.tintColor = t.soft
        icL.textColor = t.soft
        nameL.textColor = t.text
        subL.textColor = t.faint
        valL.textColor = row.on ? t.accent : t.faint.withAlphaComponent(0.75)
        chevV.tintColor = t.faint
        dotV.backgroundColor = row.dot == "on" ? t.accent : t.dotOff
    }
}


final class LXSysSheetView: UIView {
    var onAct: ((String) -> Void)?
    private let scrim = UIView()
    private let sheet = UIView()
    private let sheetTintV = UIView()
    private let handle = UIView()
    private let closeB = UIButton(type: .custom)
    private let refreshB = UIButton(type: .custom)
    private let titleL = UILabel()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var sheetBottom: NSLayoutConstraint!
    private var tint = LXSysTint.cur()
    private var spec = LXSysSpec.load()
    private var rows: [LXSysRowView] = []
    private var groupLs: [UILabel] = []
    private var cards: [UIView] = []
    private let noteL = UILabel()

    var title = "Settings" { didSet { titleL.text = title } }
    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.backgroundColor = UIColor(white: 0, alpha: 0.34)
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(closeTap)))
        addSubview(scrim)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        sheet.layer.cornerRadius = 26
        sheet.layer.cornerCurve = .continuous
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheet.clipsToBounds = true
        addSubview(sheet)
        // 0925 她的单:底部小卡统一模型小卡的底(玻璃 + LXSheetInk.tint),不再纯黑
        let glassFx: UIVisualEffect
        if #available(iOS 26.0, *) { glassFx = UIGlassEffect() }
        else { glassFx = UIBlurEffect(style: LXSheetInk.dark ? .systemThickMaterialDark : .systemThickMaterialLight) }
        let glass = UIVisualEffectView(effect: glassFx)
        glass.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        for v in [glass, sheetTintV] as [UIView] {
            v.isUserInteractionEnabled = false
            v.translatesAutoresizingMaskIntoConstraints = false
            sheet.addSubview(v)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: sheet.topAnchor), v.bottomAnchor.constraint(equalTo: sheet.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: sheet.leadingAnchor), v.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            ])
        }
        handle.translatesAutoresizingMaskIntoConstraints = false
        handle.layer.cornerRadius = 1
        sheet.addSubview(handle)
        for b in [closeB, refreshB] {
            b.translatesAutoresizingMaskIntoConstraints = false
            b.imageView?.contentMode = .center
            sheet.addSubview(b)
        }
        closeB.setImage(LXSysIcons.image("close"), for: .normal)
        closeB.layer.cornerRadius = 16
        closeB.addTarget(self, action: #selector(closeTap), for: .touchUpInside)
        refreshB.setImage(LXSysIcons.image("refresh"), for: .normal)
        refreshB.addTarget(self, action: #selector(refreshTap), for: .touchUpInside)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        titleL.font = LXDrawerTint.font(17, wght: 600)
        titleL.textAlignment = .center
        titleL.text = title
        sheet.addSubview(titleL)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        sheet.addSubview(scroll)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        scroll.addSubview(stack)
        noteL.translatesAutoresizingMaskIntoConstraints = false
        noteL.numberOfLines = 0
        noteL.setContentCompressionResistancePriority(.required, for: .vertical)
        sheetBottom = sheet.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: topAnchor), scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.leadingAnchor.constraint(equalTo: leadingAnchor), scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheetBottom,
            sheet.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.84),
            handle.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 12),
            handle.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
            handle.widthAnchor.constraint(equalToConstant: 36),
            handle.heightAnchor.constraint(equalToConstant: 2),
            closeB.topAnchor.constraint(equalTo: handle.bottomAnchor, constant: 19),
            closeB.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 18),
            closeB.widthAnchor.constraint(equalToConstant: 32),
            closeB.heightAnchor.constraint(equalToConstant: 32),
            refreshB.centerYAnchor.constraint(equalTo: closeB.centerYAnchor),
            refreshB.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -18),
            refreshB.widthAnchor.constraint(equalToConstant: 34),
            refreshB.heightAnchor.constraint(equalToConstant: 34),
            titleL.centerYAnchor.constraint(equalTo: closeB.centerYAnchor),
            titleL.leadingAnchor.constraint(equalTo: closeB.trailingAnchor),
            titleL.trailingAnchor.constraint(equalTo: refreshB.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: closeB.bottomAnchor, constant: 7),
            scroll.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: sheet.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        let fit = scroll.heightAnchor.constraint(equalTo: stack.heightAnchor, constant: 0)
        fit.priority = UILayoutPriority(500)
        fit.isActive = true
        recolor()
        rebuild()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        scroll.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: safeAreaInsets.bottom + 6, right: 0)
    }

    @objc private func closeTap() { onAct?("close") }
    @objc private func refreshTap() {
        let spin = CABasicAnimation(keyPath: "transform.rotation")
        spin.fromValue = 0; spin.toValue = CGFloat.pi * 2; spin.duration = 0.9
        refreshB.imageView?.layer.add(spin, forKey: "spin")
        onAct?("refresh")
    }

    func apply(_ s: LXSysSpec) {
        guard s.sig != spec.sig || rows.isEmpty else { return }
        spec = s
        rebuild()
    }
    func retheme() { tint = LXSysTint.cur(); recolor() }

    private func recolor() {
        sheet.backgroundColor = .clear
        sheetTintV.backgroundColor = LXSheetInk.tint
        handle.backgroundColor = tint.handle
        closeB.backgroundColor = tint.closeBg
        closeB.tintColor = tint.text
        refreshB.tintColor = tint.soft
        titleL.textColor = tint.text
        noteL.textColor = tint.faint
        for l in groupLs { l.textColor = tint.faint }
        for c in cards { c.backgroundColor = tint.card; c.layer.borderColor = tint.hairline.cgColor }
        for r in rows { r.recolor(tint) }
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rows = []; groupLs = []; cards = []
        for (gi, g) in spec.groups.enumerated() {
            let gl = UILabel()
            gl.translatesAutoresizingMaskIntoConstraints = false
            gl.setContentCompressionResistancePriority(.required, for: .vertical)
            gl.font = LXDrawerTint.font(13)
            gl.attributedText = NSAttributedString(string: g.title, attributes: [.kern: 0.13, .font: LXDrawerTint.font(13)])
            let gw = UIView(); gw.translatesAutoresizingMaskIntoConstraints = false
            gw.addSubview(gl)
            NSLayoutConstraint.activate([
                gl.topAnchor.constraint(equalTo: gw.topAnchor, constant: gi == 0 ? 6 : 18),
                gl.bottomAnchor.constraint(equalTo: gw.bottomAnchor, constant: -8),
                gl.leadingAnchor.constraint(equalTo: gw.leadingAnchor, constant: 4),
                gl.trailingAnchor.constraint(equalTo: gw.trailingAnchor, constant: -4),
            ])
            stack.addArrangedSubview(gw)
            groupLs.append(gl)
            let card = UIView()
            card.translatesAutoresizingMaskIntoConstraints = false
            card.layer.cornerRadius = 22
            card.layer.cornerCurve = .continuous
            card.layer.borderWidth = 1
            card.clipsToBounds = true
            let col = UIStackView()
            col.translatesAutoresizingMaskIntoConstraints = false
            col.axis = .vertical
            card.addSubview(col)
            NSLayoutConstraint.activate([
                col.topAnchor.constraint(equalTo: card.topAnchor), col.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                col.leadingAnchor.constraint(equalTo: card.leadingAnchor), col.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            ])
            for (ri, r) in g.rows.enumerated() {
                let rv = LXSysRowView(r, tint: tint, first: ri == 0)
                rv.onTap = { [weak self] sel in self?.onAct?(sel) }
                col.addArrangedSubview(rv)
                rows.append(rv)
            }
            stack.addArrangedSubview(card)
            cards.append(card)
        }
        let ps = NSMutableParagraphStyle(); ps.minimumLineHeight = 19.8; ps.maximumLineHeight = 19.8
        noteL.attributedText = NSAttributedString(string: spec.note, attributes: [.paragraphStyle: ps, .font: LXDrawerTint.font(12)])
        let nw = UIView(); nw.translatesAutoresizingMaskIntoConstraints = false
        nw.addSubview(noteL)
        NSLayoutConstraint.activate([
            noteL.topAnchor.constraint(equalTo: nw.topAnchor, constant: 14),
            noteL.bottomAnchor.constraint(equalTo: nw.bottomAnchor, constant: -30),
            noteL.leadingAnchor.constraint(equalTo: nw.leadingAnchor, constant: 6),
            noteL.trailingAnchor.constraint(equalTo: nw.trailingAnchor, constant: -6),
        ])
        stack.addArrangedSubview(nw)
        recolor()
    }

    func present() {
        layoutIfNeeded()
        let h = sheet.bounds.height
        sheetBottom.constant = h
        scrim.alpha = 0
        layoutIfNeeded()
        UIView.animate(withDuration: 0.16) { self.scrim.alpha = 1 }
        UIView.animate(withDuration: 0.26, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.sheetBottom.constant = 0
            self.layoutIfNeeded()
        }
    }
    func dismiss(_ done: @escaping () -> Void) {
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn], animations: {
            self.sheetBottom.constant = self.sheet.bounds.height
            self.scrim.alpha = 0
            self.layoutIfNeeded()
        }, completion: { _ in done() })
    }

    func probe() -> String {
        "groups=\(spec.groups.count) rows=\(rows.count) sheet=\(Int(sheet.frame.minY)),\(Int(sheet.bounds.height)) first=\(rows.first.map { "\(Int($0.frame.height))h" } ?? "-")"
    }
}


@objc(SysPlugin)
public class SysPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SysPlugin"
    public let jsName = "SysSheet"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "sysSpec", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sysOpen", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sysClose", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sysStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sysPage", returnType: CAPPluginReturnPromise),
    ]
    static weak var live: SysPlugin?
    var sheet: LXSysSheetView?
    var spec = LXSysSpec.load()

    var page: LXSysSheetView?
    var pageKind = ""
    private var pageData: [String: Any] = [:]

    func openPage(_ kind: String) {
        guard kind == "calls" || kind == "artifacts", let host = bridge?.viewController?.view else { return }
        pageKind = kind
        let v: LXSysSheetView
        if let p = page { v = p } else {
            v = LXSysSheetView()
            v.onAct = { [weak self] sel in self?.pageAct(sel) }
            host.addSubview(v)
            LXStage.settle(host)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: host.topAnchor), v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: host.leadingAnchor), v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            ])
            page = v
        }
        v.title = kind == "calls" ? "Call log" : "Artifacts"
        if let data = UserDefaults.standard.data(forKey: "lx.page." + kind),
           let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            v.apply(LXSysSpec.from(pageSpec(kind, d)))
        } else {
            v.apply(LXSysSpec.from(["groups": [], "note": "Loading…", "k": kind]))
        }
        host.bringSubviewToFront(v)
        v.present()
        fetchPage(kind)
    }
    func closePage() {
        guard let v = page else { return }
        page = nil
        v.dismiss { v.removeFromSuperview() }
    }
    private func fetchPage(_ kind: String) {
        let path = kind == "calls" ? "/app/calls" : "/app/artifacts"
        guard let url = URL(string: LustreConfig.apiBase + path) else { return }
        var r = URLRequest(url: url)
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 15
        URLSession.shared.dataTask(with: r) { [weak self] data, _, _ in
            guard let data = data, let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
            UserDefaults.standard.set(data, forKey: "lx.page." + kind)
            DispatchQueue.main.async {
                guard let s = self, s.pageKind == kind, let v = s.page else { return }
                v.apply(LXSysSpec.from(s.pageSpec(kind, d)))
            }
        }.resume()
    }
    private func pageSpec(_ kind: String, _ d: [String: Any]) -> [String: Any] {
        pageData = d
        let tz = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let isoF = ISO8601DateFormatter(); isoF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoP = ISO8601DateFormatter()
        func date(_ s: Any?) -> Date? { guard let s = s as? String else { return nil }; return isoF.date(from: s) ?? isoP.date(from: s) }
        func fmt(_ f: String) -> DateFormatter { let x = DateFormatter(); x.locale = Locale(identifier: "en_US"); x.timeZone = tz; x.dateFormat = f; return x }
        let dayF = fmt("EEE, MMM d"), yearF = fmt("MMM d, yyyy"), timeF = fmt("HH:mm")
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        func dayTitle(_ dt: Date) -> String {
            if cal.isDateInToday(dt) { return "Today" }
            if cal.isDateInYesterday(dt) { return "Yesterday" }
            return cal.isDate(dt, equalTo: Date(), toGranularity: .year) ? dayF.string(from: dt) : yearF.string(from: dt)
        }
        var groups: [[String: Any]] = []
        var curTitle = ""
        var rows: [[String: Any]] = []
        func flush() { if !rows.isEmpty { groups.append(["title": curTitle, "rows": rows]); rows = [] } }
        if kind == "calls" {
            let list = (d["calls"] as? [[String: Any]]) ?? []
            for (i, c) in list.enumerated() {
                guard let dt = date(c["ts"]) else { continue }
                let t = dayTitle(dt)
                if t != curTitle { flush(); curTitle = t }
                let sid = (c["sid"] as? String) ?? ""
                let peer = LXNick.of(session: sid)
                let by = (c["by"] as? String) ?? "you"
                let status = (c["status"] as? String) ?? "ended"
                let dur = (c["duration"] as? NSNumber)?.intValue ?? 0
                let icon = status == "missed" ? "phone.miss" : (by == "ai" ? "phone.in" : "phone.out")
                let name = status == "missed" ? "Missed · \(peer)" : (by == "ai" ? "\(peer) called you" : "You called \(peer)")
                let val = status == "missed" ? "Missed" : (status == "declined" ? "Declined" : String(format: "%d:%02d", dur / 60, dur % 60))
                rows.append(["sel": "jump:\(i)", "icon": icon, "name": name, "sub": timeF.string(from: dt), "val": val, "chev": true])
            }
            flush()
            return ["groups": groups, "k": kind,
                    "note": groups.isEmpty ? "No calls yet." : "\(list.count) calls · tap one to jump to it in the chat"]
        }
        let list = (d["artifacts"] as? [[String: Any]]) ?? []
        for (i, a) in list.enumerated() {
            guard let dt = date(a["ts"]) else { continue }
            let t = dayTitle(dt)
            if t != curTitle { flush(); curTitle = t }
            let size = (a["size"] as? NSNumber)?.doubleValue ?? 0
            let sz = size >= 1_048_576 ? String(format: "%.1f MB", size / 1_048_576)
                   : (size >= 1024 ? String(format: "%.0f KB", size / 1024) : (size > 0 ? "\(Int(size)) B" : ""))
            let name = (a["name"] as? String) ?? "File"
            let ext = (name as NSString).pathExtension.uppercased()
            rows.append(["sel": "file:\(i)", "icon": "doc", "name": name,
                         "sub": timeF.string(from: dt) + (sz.isEmpty ? "" : " · " + sz), "val": ext, "chev": true])
        }
        flush()
        return ["groups": groups, "k": kind,
                "note": groups.isEmpty ? "No documents from Lustre yet." : "\(list.count) documents · tap one to open"]
    }
    private func pageAct(_ sel: String) {
        if sel == "close" { closePage(); return }
        if sel == "refresh" { fetchPage(pageKind); return }
        if sel.hasPrefix("jump:"), let i = Int(sel.dropFirst(5)),
           let list = pageData["calls"] as? [[String: Any]], i < list.count {
            let c = list[i]
            let sid = (c["sid"] as? String) ?? ""
            let id = (c["jump_id"] as? NSNumber)?.int64Value ?? 0
            closePage()
            if LustreConfig.webless {
                if let chat = ChatListPlugin.live {
                    if !sid.isEmpty, sid != chat.data.session { chat.switchTo(sid) }
                    LXDrawer.hide()
                    if id > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { chat.jumpToMessage(id) }
                    }
                }
                return
            }
            notifyListeners("sysAct", data: ["sel": "jump", "sid": sid, "id": NSNumber(value: id)])
            return
        }
        if sel.hasPrefix("file:"), let i = Int(sel.dropFirst(5)),
           let list = pageData["artifacts"] as? [[String: Any]], i < list.count {
            let a = list[i]
            closePage()
            if LustreConfig.webless {
                let mime = (a["mime"] as? String) ?? ""
                let att = LXAtt(kind: mime.hasPrefix("image/") ? "image" : "file",
                                url: (a["url"] as? String) ?? "",
                                name: (a["name"] as? String) ?? "文件",
                                mime: mime, size: 0, duration: 0)
                if let full = att.fullURL {
                    if att.kind == "image", let host = ChatListPlugin.live?.container?.superview {
                        LXLightbox.show(full, host: host)
                    } else {
                        LXFilePreview.shared.open(url: full, name: att.name)
                    }
                }
                return
            }
            notifyListeners("sysAct", data: ["sel": "file", "url": (a["url"] as? String) ?? "",
                                             "name": (a["name"] as? String) ?? "文件", "mime": (a["mime"] as? String) ?? ""])
            return
        }
    }
    @objc func sysPage(_ call: CAPPluginCall) {
        let kind = call.getString("kind") ?? ""
        DispatchQueue.main.async { self.openPage(kind); call.resolve(["ok": self.page != nil]) }
    }

    public override func load() { Self.live = self }

    func open() {
        guard let host = bridge?.viewController?.view else { return }
        if let v = sheet { v.apply(spec); return }
        let v = LXSysSheetView()
        v.onAct = { [weak self] sel in
            guard let s = self else { return }
            if sel == "close" { s.close(notify: true); return }
            if LustreConfig.webless {
                if sel == "refresh" { s.refreshNative(); return }
                LXSysNative.act(sel, host: s.bridge?.viewController?.view) { [weak s] in s?.refreshNative() }
                return
            }
            s.notifyListeners("sysAct", data: ["sel": sel])
        }
        host.addSubview(v)
        LXStage.settle(host)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: host.topAnchor), v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            v.leadingAnchor.constraint(equalTo: host.leadingAnchor), v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
        ])
        sheet = v
        v.apply(spec)
        v.present()
        if LustreConfig.webless { refreshNative() }
    }
    func refreshNative() {
        LXSysNative.build { [weak self] d in
            guard let s = self else { return }
            LXSysSpec.save(d)
            s.spec = LXSysSpec.from(d)
            s.sheet?.apply(s.spec)
        }
    }
    func close(notify: Bool) {
        guard let v = sheet else { return }
        sheet = nil
        v.dismiss { v.removeFromSuperview() }
        if notify { notifyListeners("sysAct", data: ["sel": "close"]) }
    }
    func retheme() { sheet?.retheme() }
    var isShowing: Bool { sheet != nil }

    @objc func sysSpec(_ call: CAPPluginCall) {
        var d: [String: Any] = [:]
        for (k, v) in call.options ?? [:] { if let ks = k as? String { d[ks] = v } }
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d),
              let clean = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            call.resolve(["ok": false]); return
        }
        DispatchQueue.main.async {
            let incoming = LXSysSpec.from(clean)
            let incomingRows = incoming.groups.reduce(0) { $0 + $1.rows.count }
            let haveRows = self.spec.groups.reduce(0) { $0 + $1.rows.count }
            if incomingRows == 0 && haveRows > 0 { call.resolve(["ok": true, "ignored": true]); return }
            LXSysSpec.save(clean)
            self.spec = incoming
            self.sheet?.apply(self.spec)
            call.resolve(["ok": true, "showing": self.isShowing])
        }
    }
    @objc func sysOpen(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.open(); call.resolve(["ok": true]) }
    }
    @objc func sysClose(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.close(notify: false); call.resolve(["ok": true]) }
    }
    @objc func sysStatus(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["showing": self.isShowing, "groups": self.spec.groups.count, "probe": self.sheet?.probe() ?? ""])
        }
    }
}


enum LXSysNative {
    private static let locText = ["always": "Always", "whenInUse": "While using", "denied": "Never",
                                  "restricted": "Restricted", "notDetermined": "Not asked"]
    private static let ekText = ["full": "Read & write", "writeOnly": "Write only", "denied": "Denied",
                                 "restricted": "Restricted", "notDetermined": "Not asked"]

    private static func row(_ sel: String, _ icon: String, _ name: String, val: String = "", sub: String = "",
                            on: Bool = false, chev: Bool = true, isStatic: Bool = false,
                            icText: String = "", dot: String = "") -> [String: Any] {
        ["sel": sel, "icon": icon, "icText": icText, "name": name, "sub": sub, "val": val,
         "on": on, "static": isStatic, "chev": chev, "dot": dot]
    }

    private static func req(_ path: String, _ method: String = "GET", _ body: [String: Any]? = nil) -> URLRequest? {
        guard !LustreConfig.secret.isEmpty, let url = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 12)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        }
        return r
    }

    private static func getJSON(_ path: String, _ done: @escaping ([String: Any]?) -> Void) {
        guard let r = req(path) else { done(nil); return }
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200
            done(ok ? (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) : nil)
        }.resume()
    }

    private static func whenShort(_ t: Date) -> String {
        let min = Int(Date().timeIntervalSince(t) / 60)
        if min < 1 { return "just now" }
        if min < 60 { return "\(min)m ago" }
        let hr = min / 60
        if hr < 24 { return "\(hr)h ago" }
        return "\(hr / 24)d ago"
    }

    static func build(_ done: @escaping ([String: Any]) -> Void) {
        let g = DispatchGroup()
        var perm: [[String: Any]] = [], app: [[String: Any]] = [], api: [[String: Any]] = []
        var conns: [[String: Any]] = [], note = ""

        g.enter()
        DispatchQueue.main.async {
            let ls: CLAuthorizationStatus
            if #available(iOS 14.0, *) { ls = CLLocationManager().authorizationStatus }
            else { ls = CLLocationManager.authorizationStatus() }
            let loc: String
            switch ls {
            case .authorizedAlways: loc = "always"
            case .authorizedWhenInUse: loc = "whenInUse"
            case .denied: loc = "denied"
            case .restricted: loc = "restricted"
            case .notDetermined: loc = "notDetermined"
            @unknown default: loc = "unknown"
            }
            func ek(_ s: EKAuthorizationStatus) -> String {
                if #available(iOS 17.0, *) {
                    switch s {
                    case .fullAccess: return "full"
                    case .writeOnly: return "writeOnly"
                    case .denied: return "denied"
                    case .restricted: return "restricted"
                    case .notDetermined: return "notDetermined"
                    default: return "unknown"
                    }
                }
                switch s {
                case .authorized: return "full"
                case .denied: return "denied"
                case .restricted: return "restricted"
                case .notDetermined: return "notDetermined"
                default: return "unknown"
                }
            }
            let cal = ek(EKEventStore.authorizationStatus(for: .event))
            let rem = ek(EKEventStore.authorizationStatus(for: .reminder))
            var rows = [
                row("perm:location", "location", "Location", val: locText[loc] ?? "Unknown",
                    on: loc == "always" || loc == "whenInUse"),
                row("perm:calendar", "calendar", "Calendar", val: ekText[cal] ?? "Unknown",
                    on: cal == "full" || cal == "writeOnly"),
                row("perm:reminders", "reminders", "Reminders", val: ekText[rem] ?? "Unknown",
                    on: rem == "full" || rem == "writeOnly"),
            ]
            guard HKHealthStore.isHealthDataAvailable() else {
                rows.append(row("perm:health", "health", "Health", val: "Unavailable"))
                perm = rows; g.leave(); return
            }
            let store = HKHealthStore()
            let types = HealthPlugin.readTypeSet()
            store.getRequestStatusForAuthorization(toShare: [], read: types) { st, _ in
                HealthPlugin.collect(store: store) { out in
                    DispatchQueue.main.async {
                        if !out.isEmpty {
                            rows.append(row("perm:health", "health", "Health", val: "Allowed",
                                            sub: "\(types.count) data types", on: true))
                        } else if st == .shouldRequest {
                            rows.append(row("perm:health", "health", "Health", val: "Not asked"))
                        } else {
                            rows.append(row("perm:health", "health", "Health", val: "No data",
                                            sub: "Either all off, or these types are empty"))
                        }
                        perm = rows; g.leave()
                    }
                }
            }
        }

        g.enter()
        UNUserNotificationCenter.current().getNotificationSettings { _ in
            DispatchQueue.main.async {
                var rows: [[String: Any]] = []
                let m = MirrorSync.shared.status()
                let mb = Double((m["bytes"] as? Int64) ?? 0) / 1048576
                let last = (m["last"] as? Double) ?? 0
                let running = (m["running"] as? Bool) ?? false
                let size = mb >= 1024 ? String(format: "%.1f GB", mb / 1024) : "\(Int(mb.rounded())) MB"
                rows.append(row("app:mirror", "mirror", "Local mirror",
                                val: running ? "Syncing…" : (mb > 0 ? size : "Off"),
                                sub: "Tap to sync · last " + (last > 0 ? whenShort(Date(timeIntervalSince1970: last)) : "never"),
                                on: mb > 0))
                app = rows; g.leave()
            }
        }

        g.enter()
        getJSON("/app/brain") { d in
            let desktop = (d?["target"] as? String ?? "desktop") != "loop"
            api = [row("api:connection", "wire", "Connection", val: desktop ? "Desktop" : "API",
                       sub: desktop ? "On \(LXNick.yan)'s line" : "On a third-party model", on: desktop)]
            g.leave()
        }

        g.enter()
        getJSON("/app/connectors") { d in
            if let list = d?["connectors"] as? [[String: Any]] {
                for c in list {
                    let status = c["status"] as? String ?? ""
                    let up = status == "up" || status == "linked"
                    let text = status == "up" ? "Connected" : (status == "down" ? "Down" : "Linked")
                    let name = c["name"] as? String ?? ""
                    conns.append(row("", "", name, val: text, sub: c["detail"] as? String ?? "", on: up,
                                     chev: false, isStatic: true,
                                     icText: String(name.prefix(1)).uppercased(), dot: up ? "on" : "off"))
                }
                let selfHosted = list.filter { ($0["scope"] as? String) == "self" }.count
                note = "\(list.count) connectors · \(selfHosted) self-hosted, \(list.count - selfHosted) from claude.ai."
                if list.isEmpty { conns = [row("", "", "Nothing found", chev: false, isStatic: true)] }
            } else {
                conns = [row("", "", "Server not responding", chev: false, isStatic: true)]
            }
            g.leave()
        }

        g.notify(queue: .main) {
            done(["groups": [["title": "Permissions", "rows": perm], ["title": "App", "rows": app],
                             ["title": "API", "rows": api], ["title": "Connectors", "rows": conns]],
                  "note": note])
        }
    }

    static func act(_ sel: String, host: UIView?, refresh: @escaping () -> Void) {
        let openSettings = {
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        }
        switch sel {
        case "perm:location", "perm:calendar", "perm:reminders", "perm:health", "app:bell":
            openSettings()
        case "app:lock":
            let on = !LockGate.shared.enabled
            let ctx = LAContext(); var err: NSError?
            guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
                LXToast.show("这台设备没有可用的面容ID或密码", host: host); return
            }
            ctx.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: on ? "打开 Lustre 的面容 ID 锁" : "关掉 Lustre 的面容 ID 锁") { ok, _ in
                DispatchQueue.main.async { if ok { LockGate.shared.enabled = on }; refresh() }
            }
        case "app:bg":
            if BackgroundSync.shared.enabled {
                BackgroundSync.shared.enabled = false
                BGTaskSchedulerCancelAll()
                refresh()
            } else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                    DispatchQueue.main.async {
                        BackgroundSync.shared.enabled = true
                        BackgroundSync.shared.schedule()
                        refresh()
                    }
                }
            }
        case "app:mirror":
            LXToast.show("开始同步,首次记得连WiFi", host: host)
            MirrorSync.shared.run(progress: { _ in }, done: { _, _ in DispatchQueue.main.async { refresh() } })
            refresh()
        case "api:connection":
            getJSON("/app/brain") { d in
                let next = (d?["target"] as? String ?? "desktop") == "loop" ? "desktop" : "loop"
                guard let r = req("/app/brain", "POST", ["target": next]) else { return }
                URLSession.shared.dataTask(with: r) { _, resp, _ in
                    let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200
                    DispatchQueue.main.async {
                        LXToast.show(ok ? (next == "loop" ? "已切到 API" : "已切到 Desktop") : "切换失败", host: host)
                        refresh()
                    }
                }.resume()
            }
        default:
            break
        }
    }
}
