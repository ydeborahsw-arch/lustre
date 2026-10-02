import UIKit
import CoreText
import UniformTypeIdentifiers

// 1001 她:"把共读系统原生化。阅读页面细节一比一复刻,彻底原生化"。
// 原稿 = 网页阅读器 /read/(anno.js + anno.css)。这里的每个数字都从那两份文件抄来,注释里写着出处的类名。
// 网页住在 iframe 里:iframe 顶边让过了状态栏,里面 env(safe-area-*) 全是 0。原生这边顶上同样从安全区下沿算起,
// 底下按 CSS 原本写的 env(safe-area-inset-bottom) 把真实的安全区加回去(网页里它恰好是 0)。

fileprivate func crHex(_ v: Int, _ a: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
fileprivate func crRGBA(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat) -> UIColor {
    UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: a)
}

/// anno.css 的配色 token。底子是 :root(纸黄);其余几套只盖掉自己写了的那几项,没写的照样继承纸黄
/// (所以蓝灰里他的划线仍是纸黄那支橙——网页就是这样)。
struct LXCRTheme {
    var id = "paper"
    var bg = crHex(0xf5efe2), bgDeep = crHex(0xece4d4)
    var surface = crHex(0xfcfaf5), surface2 = crHex(0xece4d4), surface3 = crHex(0xdfd5c2)
    var ink1 = crHex(0x1a1510), ink2 = crHex(0x4a3f30), ink3 = crHex(0x6e6248), ink4 = crHex(0xa89878)
    var accent = crHex(0xa85a1a), accentSoft = crRGBA(168, 90, 26, 0.10), accentDeep = crHex(0x7a3d10)
    var jade = crHex(0x4a6e4a), jadeSoft = crRGBA(74, 110, 74, 0.12), vermillion = crHex(0x8b2c1f)
    var border = crRGBA(26, 21, 16, 0.14), borderSoft = crRGBA(26, 21, 16, 0.08), borderStrong = crRGBA(26, 21, 16, 0.30)
    var hlButter = crRGBA(74, 110, 74, 0.18), hlButterStrong = crRGBA(74, 110, 74, 0.28)
    var hlClaude = crRGBA(168, 90, 26, 0.16), hlClaudeStrong = crRGBA(168, 90, 26, 0.26)
    var selection = crRGBA(168, 90, 26, 0.20)                 // ::selection
    var vocabLine = crRGBA(139, 44, 31, 0.85)                 // .vocab-underline
    var dark: Bool { id == "night" || id == "moon" }

    /// THEMES(anno.js 56):设置面板圆点的顺序
    static let all: [(id: String, label: String)] = [("mist", "蓝灰"), ("moon", "满月"), ("paper", "纸黄"),
                                                     ("white", "纯白"), ("green", "护眼"), ("night", "夜黑")]

    static func of(_ id: String) -> LXCRTheme {
        var t = LXCRTheme()
        t.id = id
        switch id {
        case "night":   // .night-mode
            t.bg = crHex(0x1c1916); t.bgDeep = crHex(0x161310)
            t.surface = crHex(0x262220); t.surface2 = crHex(0x302b28); t.surface3 = crHex(0x3c3632)
            t.ink1 = crHex(0xe8dcc4); t.ink2 = crHex(0xb5a688); t.ink3 = crHex(0x8f8268); t.ink4 = crHex(0x564c3a)
            t.accent = crHex(0xc8864a); t.accentSoft = crRGBA(200, 134, 74, 0.12); t.accentDeep = crHex(0xa86e30)
            t.jade = crHex(0x7ca06a); t.jadeSoft = crRGBA(124, 160, 106, 0.14); t.vermillion = crHex(0xb04a3a)
            t.border = crRGBA(156, 138, 108, 0.35); t.borderSoft = crRGBA(156, 138, 108, 0.20); t.borderStrong = crRGBA(156, 138, 108, 0.50)
            t.hlButter = crRGBA(124, 160, 106, 0.20); t.hlButterStrong = crRGBA(124, 160, 106, 0.32)
            t.hlClaude = crRGBA(200, 134, 74, 0.18); t.hlClaudeStrong = crRGBA(200, 134, 74, 0.30)
            t.selection = crRGBA(200, 134, 74, 0.25)
            t.vocabLine = crRGBA(176, 74, 58, 0.85)
        case "white":   // body.theme-white
            t.bg = crHex(0xffffff); t.bgDeep = crHex(0xf4f4f4)
            t.surface = crHex(0xffffff); t.surface2 = crHex(0xf2f2f2); t.surface3 = crHex(0xe6e6e6)
            t.ink1 = crHex(0x16181c); t.ink2 = crHex(0x2f3338); t.ink3 = crHex(0x6b7078); t.ink4 = crHex(0xa3a8b0)
            t.border = crRGBA(20, 22, 26, 0.12); t.borderSoft = crRGBA(20, 22, 26, 0.07)
        case "mist":    // body.theme-mist:她截图里取的色
            t.bg = crHex(0xdae5eb); t.bgDeep = crHex(0xcfdde5)
            t.surface = crHex(0xe6eef3); t.surface2 = crHex(0xd0dde5); t.surface3 = crHex(0xbccdd8)
            t.ink1 = crHex(0x22303a); t.ink2 = crHex(0x2e2e2e); t.ink3 = crHex(0x5b6f7c); t.ink4 = crHex(0x8ea3b0)
            t.accent = crHex(0x3d7f9e); t.accentSoft = crRGBA(61, 127, 158, 0.12); t.accentDeep = crHex(0x2b6280)
            t.jade = crHex(0x4a7a63); t.jadeSoft = crRGBA(74, 122, 99, 0.14)
            t.border = crRGBA(34, 48, 58, 0.14); t.borderSoft = crRGBA(34, 48, 58, 0.08)
            t.hlButter = crRGBA(157, 195, 214, 0.55); t.hlButterStrong = crRGBA(157, 195, 214, 0.75)
            t.selection = crHex(0x9dc3d6)
        case "moon":    // body.theme-moon:银焰星海图取色,冰蓝焰心
            t.bg = crHex(0x05070c); t.bgDeep = crHex(0x010204)
            t.surface = crHex(0x101620); t.surface2 = crHex(0x171f2c); t.surface3 = crHex(0x222d3d)
            t.ink1 = crHex(0xe8f2f8); t.ink2 = crHex(0xbfcedb); t.ink3 = crHex(0x8a9aab); t.ink4 = crHex(0x566472)
            t.accent = crHex(0x7fd4f5); t.accentSoft = crRGBA(127, 212, 245, 0.14); t.accentDeep = crHex(0x4aa8cf)
            t.jade = crHex(0x8fe3e0); t.jadeSoft = crRGBA(143, 227, 224, 0.16); t.vermillion = crHex(0xb98a95)
            t.border = crRGBA(150, 200, 230, 0.20); t.borderSoft = crRGBA(150, 200, 230, 0.11); t.borderStrong = crRGBA(150, 200, 230, 0.36)
            t.hlButter = crRGBA(143, 227, 224, 0.24); t.hlButterStrong = crRGBA(143, 227, 224, 0.38)
            t.hlClaude = crRGBA(127, 212, 245, 0.22); t.hlClaudeStrong = crRGBA(127, 212, 245, 0.36)
            t.selection = crRGBA(127, 212, 245, 0.34)
        case "green":   // body.theme-green
            t.bg = crHex(0xcfe0cb); t.bgDeep = crHex(0xc2d6bd)
            t.surface = crHex(0xd8e8d4); t.surface2 = crHex(0xc8dcc3); t.surface3 = crHex(0xb7cfb1)
            t.ink1 = crHex(0x1d2a1b); t.ink2 = crHex(0x2c3d29); t.ink3 = crHex(0x55684f); t.ink4 = crHex(0x86957f)
            t.border = crRGBA(29, 42, 27, 0.16); t.borderSoft = crRGBA(29, 42, 27, 0.09)
        default:
            t.id = "paper"
        }
        return t
    }
}

/// --font-display / --font-mono 两个变量是同一串:-apple-system 打头,中文落到 PingFang SC
enum LXCRFont {
    static func f(_ size: CGFloat, _ w: Int = 400) -> UIFont {
        let weight: UIFont.Weight = w >= 700 ? .bold : w >= 600 ? .semibold : w >= 500 ? .medium : w >= 400 ? .regular : .light
        let pf = w >= 600 ? "PingFangSC-Semibold" : w >= 500 ? "PingFangSC-Medium" : w >= 400 ? "PingFangSC-Regular" : "PingFangSC-Light"
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let d = base.fontDescriptor.addingAttributes([.cascadeList: [UIFontDescriptor(fontAttributes: [.name: pf])]])
        return UIFont(descriptor: d, size: size)
    }
    /// font-style: italic:拉丁走 SF 斜体,中文 PingFang 没有斜体,浏览器给它合成倾斜——这里一样合成
    static func italic(_ size: CGFloat, _ w: Int = 400) -> UIFont {
        let up = f(size, w)
        guard let d = up.fontDescriptor.withSymbolicTraits(.traitItalic) else { return up }
        return UIFont(descriptor: d, size: size)
    }
}

/// CSS 行盒:每行高 L,基线 = 半行距 + 主字体上沿(浏览器把多出来的行距上下平分)
fileprivate func crBaseline(_ f: UIFont, _ lh: CGFloat) -> CGFloat { (lh - (f.ascender - f.descender)) / 2 + f.ascender }

fileprivate func crAttr(_ s: String, _ f: UIFont, _ c: UIColor, kern: CGFloat = 0, oblique: Bool = false) -> NSAttributedString {
    var a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: c]
    if kern != 0 { a[.kern] = kern }
    if oblique { a[.obliqueness] = 0.2 }
    return NSAttributedString(string: s, attributes: a)
}

/// white-space: normal:连续的空白(空格/换行/制表)并成一个空格,头尾的去掉;全角空格不算
fileprivate func crCollapse(_ s: String) -> String {
    let one = s.replacingOccurrences(of: "[ \\t\\n\\r\\f]+", with: " ", options: .regularExpression)
    return one.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\u{0C}"))
}

/// anno.js 的 SVG 图标照原样画:stroke 端点默认平头、拐角默认尖角(不是 LXSVG.icon 那套圆头)
fileprivate func crIcon(_ paths: [String], box: CGFloat = 16, size: CGFloat, stroke: CGFloat, color: UIColor,
                        fill: Bool = false, extra: ((CGContext) -> Void)? = nil) -> UIImage {
    let k = size / box
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
        let c = ctx.cgContext
        c.scaleBy(x: k, y: k)
        c.setLineWidth(stroke)
        c.setLineCap(.butt); c.setLineJoin(.miter)
        c.setStrokeColor(color.cgColor); c.setFillColor(color.cgColor)
        for d in paths {
            c.addPath(LXSVG.path(d))
            if fill { c.drawPath(using: .fillStroke) } else { c.strokePath() }
        }
        extra?(c)
    }
}

/// 单行字:CoreText 直接按给定基线画(UILabel 遇到中文回落字体会自己把行撑高,基线就漂了)
final class LXCRLine: UIView {
    var text: NSAttributedString = NSAttributedString() { didSet { line = nil; setNeedsDisplay() } }
    var baseline: CGFloat = 0 { didSet { setNeedsDisplay() } }
    var align: NSTextAlignment = .left { didSet { setNeedsDisplay() } }
    var truncate = true
    private var line: CTLine?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    static func width(_ a: NSAttributedString) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(a as CFAttributedString), nil, nil, nil))
    }
    var textWidth: CGFloat { Self.width(text) }

    override func draw(_ rect: CGRect) {
        guard let c = UIGraphicsGetCurrentContext(), text.length > 0 else { return }
        var l = line ?? CTLineCreateWithAttributedString(text as CFAttributedString)
        var w = CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
        if truncate && w > bounds.width + 0.5 {
            let attrs = text.attributes(at: max(0, text.length - 1), effectiveRange: nil)
            let dots = CTLineCreateWithAttributedString(NSAttributedString(string: "\u{2026}", attributes: attrs) as CFAttributedString)
            if let t = CTLineCreateTruncatedLine(l, Double(bounds.width), .end, dots) { l = t }
            w = CGFloat(CTLineGetTypographicBounds(l, nil, nil, nil))
        }
        line = l
        let x: CGFloat = align == .center ? (bounds.width - w) / 2 : align == .right ? bounds.width - w : 0
        c.saveGState()
        c.textMatrix = .identity
        c.translateBy(x: 0, y: bounds.height)
        c.scaleBy(x: 1, y: -1)
        c.textPosition = CGPoint(x: x, y: bounds.height - baseline)
        CTLineDraw(l, c)
        c.restoreGState()
    }
}

extension NSAttributedString.Key {
    static let lxcrMark = NSAttributedString.Key("lxcr.mark")     // <mark class="hl"> 的底色
    static let lxcrVocab = NSAttributedString.Key("lxcr.vocab")   // .vocab-underline
}

/// mark.hl:上下各 1px 内边距、2px 圆角;hl-both 是上半她的色、下半他的色(linear-gradient 50% 硬分界)
final class LXCRMark: NSObject {
    let upper: UIColor
    let lower: UIColor?
    init(_ upper: UIColor, _ lower: UIColor? = nil) { self.upper = upper; self.lower = lower }
}

/// 多行字的 CSS 排法:每行高固定 L,基线放在半行距 + 主字体上沿;标记底色只盖字身(上沿到下沿再各加 1px),不铺满整行
final class LXCRLayout: NSLayoutManager, NSLayoutManagerDelegate {
    var lineH: CGFloat = 20
    var asc: CGFloat = 16
    var desc: CGFloat = 4
    var baseline: CGFloat { (lineH - (asc + desc)) / 2 + asc }

    override init() { super.init(); delegate = self }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ f: UIFont, lineHeight: CGFloat) { lineH = lineHeight; asc = f.ascender; desc = -f.descender }

    func layoutManager(_ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<CGRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<CGRect>, baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
        lineFragmentRect.pointee.size.height = lineH
        lineFragmentUsedRect.pointee.size.height = lineH
        baselineOffset.pointee = baseline
        return true
    }

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let ts = textStorage, let tc = textContainers.first, let c = UIGraphicsGetCurrentContext() else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        ts.enumerateAttribute(.lxcrMark, in: chars, options: []) { v, range, _ in
            guard let m = v as? LXCRMark else { return }
            self.eachLineBox(range, tc) { b, base in
                let top = base - self.asc - 1, bot = base + self.desc + 1
                let box = CGRect(x: b.minX + origin.x, y: top + origin.y, width: b.width, height: bot - top)
                c.saveGState()
                c.addPath(UIBezierPath(roundedRect: box, cornerRadius: 2).cgPath)
                c.clip()
                if let lower = m.lower {
                    c.setFillColor(m.upper.cgColor); c.fill(CGRect(x: box.minX, y: box.minY, width: box.width, height: box.height / 2))
                    c.setFillColor(lower.cgColor); c.fill(CGRect(x: box.minX, y: box.midY, width: box.width, height: box.height / 2))
                } else {
                    c.setFillColor(m.upper.cgColor); c.fill(box)
                }
                c.restoreGState()
            }
        }
        // text-decoration: underline 2px,text-underline-offset 2px(画在字的下面,跟浏览器一样先画线后画字)
        ts.enumerateAttribute(.lxcrVocab, in: chars, options: []) { v, range, _ in
            guard let col = v as? UIColor else { return }
            self.eachLineBox(range, tc) { b, base in
                c.setFillColor(col.cgColor)
                c.fill(CGRect(x: b.minX + origin.x, y: base + 2 + origin.y, width: b.width, height: 2))
            }
        }
    }

    /// 一段字符在每一行上占的横向范围 + 那一行的基线 y
    private func eachLineBox(_ range: NSRange, _ tc: NSTextContainer, _ body: (CGRect, CGFloat) -> Void) {
        let gr = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        // 系统把这个回调标成会逃逸,其实是同步跑完的
        withoutActuallyEscaping(body) { body in
            enumerateLineFragments(forGlyphRange: gr) { rect, _, _, lineGR, _ in
                let inter = NSIntersectionRange(gr, lineGR)
                guard inter.length > 0 else { return }
                let b = self.boundingRect(forGlyphRange: inter, in: tc)
                body(b, rect.minY + self.baseline)
            }
        }
    }
}

/// 一块多行字(不可交互):自己持有 TextKit 那一套,按 LXCRLayout 的 CSS 行距排
final class LXCRText: UIView {
    let storage = NSTextStorage()
    let layout = LXCRLayout()
    let container = NSTextContainer(size: CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))

    override init(frame: CGRect) {
        super.init(frame: frame)
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ a: NSAttributedString, font: UIFont, lineHeight: CGFloat) {
        layout.set(font, lineHeight: lineHeight)
        storage.setAttributedString(a)
        setNeedsDisplay()
    }
    /// 给定宽度排出来的高度(行数 × 行高)
    func height(for w: CGFloat) -> CGFloat {
        container.size = CGSize(width: max(1, w), height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        return ceil(layout.usedRect(for: container).height * 2) / 2
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(container.size.width - bounds.width) > 0.25 {
            container.size = CGSize(width: max(1, bounds.width), height: .greatestFiniteMagnitude)
            setNeedsDisplay()
        }
    }
    override func draw(_ rect: CGRect) {
        let gr = layout.glyphRange(for: container)
        layout.drawBackground(forGlyphRange: gr, at: .zero)
        layout.drawGlyphs(forGlyphRange: gr, at: .zero)
    }
}

/// 正文段落用的字框:平时不接手势(长按/点按归整页),"划重点"那一段才打开系统选字
final class LXCRTextView: UITextView {
    let storage: NSTextStorage
    let crLayout: LXCRLayout

    init() {
        let ts = NSTextStorage()
        let lm = LXCRLayout()
        let tc = NSTextContainer(size: CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        tc.lineFragmentPadding = 0
        tc.widthTracksTextView = true
        lm.addTextContainer(tc)
        ts.addLayoutManager(lm)
        storage = ts
        crLayout = lm
        super.init(frame: .zero, textContainer: tc)
        isEditable = false
        isScrollEnabled = false
        textContainerInset = .zero
        backgroundColor = .clear
        isSelectable = false
        isUserInteractionEnabled = false
        dataDetectorTypes = []
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 选字时只出我们自己的小工具条(高亮/生词/复制),系统那排菜单不要
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
    @available(iOS 16.0, *)
    override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? { nil }
}

// MARK: - 数据

struct LXCRBook {
    var id: String
    var title: String
    var paraCount: Int
    var annotCount: Int
    var progressPage: Int
    var updatedAt: String
    var createdAt: String
    var dict: [String: Any]

    init?(_ d: [String: Any]) {
        guard let id = d["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        title = (d["title"] as? String) ?? ""
        paraCount = (d["paragraph_count"] as? NSNumber)?.intValue ?? 0
        annotCount = (d["annotation_count"] as? NSNumber)?.intValue ?? 0
        let p = d["progress"] as? [String: Any]
        progressPage = (p?["page"] as? NSNumber)?.intValue ?? 0
        updatedAt = (p?["updated_at"] as? String) ?? ""
        createdAt = (d["created_at"] as? String) ?? ""
        dict = d
    }
}

struct LXCRAnnot {
    var id: String
    var pid: Int
    var type: String
    var text: String
    var author: String
    var created: String
    var highlightId: String?
    var replyTo: String?
    var isClaude: Bool { author == "Claude" }

    init?(_ d: [String: Any]) {
        guard let pid = (d["paragraph_id"] as? NSNumber)?.intValue ?? Int((d["paragraph_id"] as? String) ?? "") else { return nil }
        id = (d["id"] as? String) ?? ((d["id"] as? NSNumber)?.stringValue ?? "")
        self.pid = pid
        type = (d["type"] as? String) ?? "highlight"
        text = (d["text"] as? String) ?? ""
        author = (d["author"] as? String) ?? ""
        created = (d["created_at"] as? String) ?? ""
        highlightId = d["highlight_id"] as? String
        replyTo = d["reply_to"] as? String
    }
}

struct LXCRToc {
    var title: String
    var pid: Int
    var level: Int
}

struct LXCRPara {
    var id: Int
    var text: String
    var page: Int
}

/// 设置都记在本机(网页记在 localStorage:marginalia-theme / -fontsize / -lh)
enum LXCRPrefs {
    static var theme: String {
        get { UserDefaults.standard.string(forKey: "lx.cr.theme") ?? "mist" }
        set { UserDefaults.standard.set(newValue, forKey: "lx.cr.theme") }
    }
    static var fontSize: CGFloat {
        get { let v = UserDefaults.standard.double(forKey: "lx.cr.fs"); return v >= 13 ? CGFloat(v) : 17 }
        set { UserDefaults.standard.set(Double(newValue), forKey: "lx.cr.fs") }
    }
    static var lineHeight: CGFloat {
        get { let v = UserDefaults.standard.double(forKey: "lx.cr.lh"); return v > 1 ? CGFloat(v) : 1.9 }
        set { UserDefaults.standard.set(Double(newValue), forKey: "lx.cr.lh") }
    }
    /// 她在共读里的署名(服务器给她的批注写的作者名),第一次见到就记下,筛选按钮用
    static var me: String {
        get { UserDefaults.standard.string(forKey: "lx.cr.me") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lx.cr.me") }
    }
    static var books: [[String: Any]] {
        get {
            guard let d = UserDefaults.standard.data(forKey: "lx.cr.books"),
                  let a = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]] else { return [] }
            return a
        }
        set {
            if let d = try? JSONSerialization.data(withJSONObject: newValue) { UserDefaults.standard.set(d, forKey: "lx.cr.books") }
        }
    }
}

// MARK: - 接口(/marginalia/api,?auth= 进门,和终端同一把钥匙)

enum LXCRAPI {
    static var fake: Bool { LustreConfig.isPreview }

    static func url(_ path: String) -> URL? {
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: LustreConfig.origin + "/marginalia/api" + path + (path.contains("?") ? "&" : "?") + "auth=" + tok)
    }

    static func call(_ method: String, _ path: String, _ body: [String: Any]? = nil, timeout: TimeInterval = 20,
                     _ done: @escaping (Any?, Int) -> Void) {
        if fake {
            let r = LXCRFake.handle(method, path, body)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { done(r, r == nil ? 404 : 200) }
            return
        }
        guard let u = url(path) else { done(nil, 0); return }
        var r = URLRequest(url: u)
        r.httpMethod = method
        r.timeoutInterval = timeout
        r.cachePolicy = .reloadIgnoringLocalCacheData
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        }
        URLSession.shared.dataTask(with: r) { d, resp, _ in
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0, options: [.fragmentsAllowed]) }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async { done(code >= 200 && code < 300 ? obj : nil, code) }
        }.resume()
    }

    /// 加一本书:multipart 传 /upload-book(nginx 放到 160m)
    static func upload(_ file: URL, _ done: @escaping ([String: Any]?, String?) -> Void) {
        if fake { DispatchQueue.main.async { done(nil, "预览里不传书") }; return }
        guard let u = url("/upload-book"), let data = try? Data(contentsOf: file) else { done(nil, "读不到这个文件"); return }
        let boundary = "lxcr-" + UUID().uuidString
        var body = Data()
        let name = file.lastPathComponent.replacingOccurrences(of: "\"", with: "")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 300
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        URLSession.shared.uploadTask(with: r, from: body) { d, _, err in
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async {
                if let e = err { done(nil, e.localizedDescription) } else { done(obj, nil) }
            }
        }.resume()
    }

    /// 戳一戳:她按的按钮、署她的名,递进他那条线(网页走的是外壳的 /app/send,同一个接口)
    static func poke(_ text: String, _ done: @escaping (Int) -> Void) {
        if fake { DispatchQueue.main.async { done(200) }; return }
        guard !LustreConfig.secret.isEmpty, let u = URL(string: LustreConfig.apiBase + "/app/send") else { done(0); return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 20
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text, "api_session": "yan-main"])
        URLSession.shared.dataTask(with: r) { _, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async { done(code) }
        }.resume()
    }
}

// MARK: - 预览用的假书(模拟器自检只摆这本,不碰她的书和他们俩的弹幕)

enum LXCRFake {
    static var books: [[String: Any]] = []
    static var paras: [[Int: String]] = []
    static var annots: [String: [[String: Any]]] = [:]
    static var tocs: [String: [[String: Any]]] = [:]
    static var marks: [String: Int] = [:]
    static var progress: [String: Int] = [:]
    static var vocab: [String: [[String: Any]]] = [:]
    private static var ready = false

    private static let lines = [
        "雨是从傍晚开始下的,先是细细的一层,落在窗台上几乎听不见,后来才慢慢密起来,把对面楼的灯一盏一盏洇开。",
        "她把书翻到折角的那一页,手指压着那一行没动,像是在等一个人把下一句念出来。",
        "楼下有人推着车走过,轮子碾过积水,声音一路拖到街角才断。",
        "\u{3000}\u{3000}这一段故意用全角空格开头,看看缩进是不是原样留着。",
        "Watch the sky, a long English line sits here to check how Latin text wraps next to Chinese characters without spaces.",
        "灯芯短了一截,火苗矮下去又跳起来,墙上的影子跟着晃了一下。",
        "她想,有些话不用说完,留一半在纸上,另一半总会有人接住。",
        "窗外的雨声忽大忽小,像有人在很远的地方一遍一遍地翻同一页书。",
    ]

    static func setup() {
        guard !ready else { return }
        ready = true
        var p: [Int: String] = [:]
        var toc: [[String: Any]] = []
        var n = 0
        for ch in 1...4 {
            n += 1
            toc.append(["title": "第\(ch)章 样章\(ch)", "paragraph_id": n, "level": 0])
            for i in 0..<14 {
                p[n] = lines[(ch * 3 + i) % lines.count] + (i % 4 == 0 ? lines[(i + 1) % lines.count] : "")
                n += 1
            }
        }
        paras = [p]
        let now = ISO8601DateFormatter().string(from: Date())
        let a: [[String: Any]] = [
            ["id": "f1", "paragraph_id": 3, "type": "note", "text": "样板弹幕:这一句写得真好。", "author": "她", "created_at": now],
            ["id": "f2", "paragraph_id": 3, "type": "note", "text": "样板回话:嗯,我也停在这里了。", "author": "Claude", "created_at": now],
            ["id": "f3", "paragraph_id": 3, "type": "note", "text": "样板弹幕:第三条,看看列表怎么排。", "author": "她", "created_at": now],
            ["id": "f4", "paragraph_id": 6, "type": "highlight", "text": "灯芯短了一截", "author": "她", "created_at": now],
            ["id": "f5", "paragraph_id": 7, "type": "highlight", "text": "有些话不用说完", "author": "Claude", "created_at": now],
            ["id": "f6", "paragraph_id": 9, "type": "note", "text": "样板:只有他说话的一段。", "author": "Claude", "created_at": now],
            ["id": "f7", "paragraph_id": 18, "type": "comment", "text": "样板:另一章里的一条。", "author": "Claude", "created_at": now],
        ]
        annots["sample01"] = a
        tocs["sample01"] = toc
        progress["sample01"] = 1
        books = [
            ["id": "sample01", "title": "样书:雨夜读书", "paragraph_count": n - 1, "annotation_count": a.count,
             "has_bookmark": false, "progress": ["page": 1, "updated_at": now] as [String: Any], "created_at": now],
            ["id": "sample02", "title": "样书二:书名写得长一点,看看到了右边怎么折行", "paragraph_count": 0, "annotation_count": 0,
             "has_bookmark": false, "progress": NSNull(), "created_at": now],
        ]
    }

    /// 和服务器 computePages 同一个规矩:每页凑够约 800 字就断
    private static func pages(_ id: String) -> [[Int]] {
        guard id == "sample01", let p = paras.first else { return [] }
        var out: [[Int]] = []
        var cur: [Int] = []
        var chars = 0
        for k in p.keys.sorted() {
            let len = (p[k] ?? "").count
            if chars > 0 && chars + len > 800 { out.append(cur); cur = [k]; chars = len }
            else { cur.append(k); chars += len }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }

    static func handle(_ method: String, _ path: String, _ body: [String: Any]?) -> Any? {
        setup()
        let clean = path.components(separatedBy: "?").first ?? path
        let q = path.components(separatedBy: "?").dropFirst().first ?? ""
        let seg = clean.split(separator: "/").map(String.init)
        guard seg.first == "books" else { return nil }
        if seg.count == 1 { return books }
        let id = seg[1]
        if seg.count == 2 {
            if method == "DELETE" { return ["ok": true] }
            return books.first { ($0["id"] as? String) == id }
        }
        let pg = pages(id)
        switch seg[2] {
        case "pages":
            let n = Int(seg.count > 3 ? seg[3] : "1") ?? 1
            guard n >= 1 && n <= pg.count, let p = paras.first else { return nil }
            return ["page": n, "total_pages": pg.count, "paragraphs": pg[n - 1].map { ["id": $0, "text": p[$0] ?? ""] as [String: Any] }] as [String: Any]
        case "page-for":
            let pid = Int(seg.count > 3 ? seg[3] : "0") ?? 0
            return ["page": (pg.firstIndex { $0.contains(pid) } ?? 0) + 1]
        case "toc":
            return tocs[id] ?? []
        case "annotations":
            if method == "POST", let b = body {
                var a = b
                a["id"] = String(UUID().uuidString.prefix(8)).lowercased()
                a["author"] = "她"
                a["created_at"] = ISO8601DateFormatter().string(from: Date())
                annots[id, default: []].append(a)
                return a
            }
            if method == "DELETE", seg.count > 3 {
                annots[id] = (annots[id] ?? []).filter { ($0["id"] as? String) != seg[3] }
                return ["ok": true]
            }
            return annots[id] ?? []
        case "bookmarks":
            if method == "POST", let pid = (body?["paragraph_id"] as? NSNumber)?.intValue {
                if marks[id] == pid { marks[id] = nil; return ["action": "removed", "paragraph_id": pid] as [String: Any] }
                marks[id] = pid
                return ["action": "set", "paragraph_id": pid] as [String: Any]
            }
            return ["bookmark": marks[id].map { $0 as Any } ?? NSNull(), "page": NSNull()] as [String: Any]
        case "progress":
            progress[id] = (body?["page"] as? NSNumber)?.intValue ?? 1
            return ["page": progress[id] ?? 1]
        case "vocab":
            if method == "POST", var b = body {
                b["id"] = String(UUID().uuidString.prefix(8)).lowercased()
                vocab[id, default: []].append(b)
                return b
            }
            return vocab[id] ?? []
        case "search":
            let needle = (q.components(separatedBy: "=").last ?? "").removingPercentEncoding ?? ""
            guard needle.count >= 2, let p = paras.first else { return [] as [[String: Any]] }
            return p.keys.sorted().compactMap { k -> [String: Any]? in
                guard let t = p[k], t.contains(needle) else { return nil }
                return ["paragraph_id": k, "snippet": String(t.prefix(60))]
            }
        case "title":
            return ["ok": true]
        default:
            return nil
        }
    }
}

// MARK: - 小部件

/// --ease: cubic-bezier(0.16, 1, 0.3, 1)
fileprivate func crAnimate(_ d: TimeInterval, _ body: @escaping () -> Void, done: (() -> Void)? = nil) {
    let a = UIViewPropertyAnimator(duration: d, timingParameters:
        UICubicTimingParameters(controlPoint1: CGPoint(x: 0.16, y: 1), controlPoint2: CGPoint(x: 0.3, y: 1)))
    a.addAnimations(body)
    if let done = done { a.addCompletion { _ in done() } }
    a.startAnimation()
}

fileprivate func crShadow(_ l: CALayer, y: CGFloat, blur: CGFloat, a: Float) {
    l.shadowColor = UIColor.black.cgColor
    l.shadowOpacity = a
    l.shadowRadius = blur / 2
    l.shadowOffset = CGSize(width: 0, height: y)
}

/// 按下变色的块(网页里 :active 换底色那种)
class LXCRPress: UIControl {
    /// 长按出菜单后抬手那一下别再当成点按(网页 wireShelfLongPress 吃掉补发的 click)
    var longFired = false
    var normalBg: UIColor = .clear { didSet { if !isHighlighted { backgroundColor = normalBg } } }
    var pressedBg: UIColor?
    var pressedAlpha: CGFloat?
    override var isHighlighted: Bool {
        didSet {
            if let p = pressedBg { backgroundColor = isHighlighted ? p : normalBg }
            if let a = pressedAlpha { alpha = isHighlighted ? a : 1 }
        }
    }
}

/// .reader-topbar:左"‹ 书架/正文",中间书名,右边搜索
final class LXCRTopBar: UIView {
    let back = LXCRPress()
    private let backIcon = UIImageView()
    private let backLabel = LXCRLine()
    private let title = LXCRLine()
    let right = LXCRPress()
    private let rightLabel = LXCRLine()
    private var backW: CGFloat = 0
    private var rightW: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        back.addSubview(backIcon); back.addSubview(backLabel)
        right.addSubview(rightLabel)
        for v in [back, title, right] as [UIView] { addSubview(v) }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ t: LXCRTheme, back b: String, title tt: String, right r: String?) {
        backgroundColor = t.bg
        // .nav-back:10px 300 字距 .05em ink2;图标 10×10
        let bf = LXCRFont.f(10, 300)
        backLabel.text = crAttr(b, bf, t.ink2, kern: 0.5)
        backLabel.baseline = bf.ascender
        backIcon.image = crIcon(["M10 3L5 8l5 5"], size: 10, stroke: 1.2, color: t.ink2)
        backW = 10 + 4 + backLabel.textWidth
        // .reader-topbar-title:15px 500 ink1,行高 1.6
        let tf = LXCRFont.f(15, 500)
        title.text = crAttr(tt, tf, t.ink1)
        title.baseline = crBaseline(tf, 24)
        title.align = .center
        // 右边 .nav-btn.subtle,内联 font-size 11px
        if let r = r {
            let rf = LXCRFont.f(11, 300)
            rightLabel.text = crAttr(r, rf, t.ink3, kern: 0.55)
            rightLabel.baseline = rf.ascender
            rightW = rightLabel.textWidth
            right.isHidden = false
        } else {
            rightW = 0
            right.isHidden = true
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height, w = bounds.width
        let bh = LXCRFont.f(10, 300).lineHeight
        back.frame = CGRect(x: 20, y: (h - bh) / 2 - 8, width: backW, height: bh + 16)
        backIcon.frame = CGRect(x: 0, y: 8 + (bh - 10) / 2, width: 10, height: 10)
        backLabel.frame = CGRect(x: 14, y: 8, width: backW - 14 + 2, height: bh)
        let rh = LXCRFont.f(11, 300).lineHeight
        right.frame = CGRect(x: w - 20 - rightW, y: (h - rh) / 2 - 8, width: rightW, height: rh + 16)
        rightLabel.frame = CGRect(x: 0, y: 8, width: rightW + 2, height: rh)
        let x0 = 20 + backW + 40, x1 = w - 20 - rightW - 40
        title.frame = CGRect(x: x0, y: (h - 24) / 2, width: max(0, x1 - x0), height: 24)
    }
}

/// .anno-toast:底部 96px 居中的小药丸,1.8 秒收
final class LXCRToast {
    private static weak var live: UIView?
    static func show(_ text: String, in host: UIView, t: LXCRTheme) {
        live?.removeFromSuperview()
        let f = LXCRFont.f(13)
        let l = LXCRLine()
        l.text = crAttr(text, f, t.ink1)
        let lh = f.lineHeight * 1.0
        let w = ceil(l.textWidth) + 32 + 2, h = ceil(13 * 1.6) + 16 + 2
        let v = UIView(frame: CGRect(x: (host.bounds.width - w) / 2, y: host.bounds.height - 96 - h, width: w, height: h))
        v.backgroundColor = t.surface
        v.layer.cornerRadius = h / 2
        v.layer.borderWidth = 1
        v.layer.borderColor = t.border.cgColor
        crShadow(v.layer, y: 8, blur: 24, a: 0.18)
        v.isUserInteractionEnabled = false
        l.frame = CGRect(x: 17, y: 9, width: w - 34 + 2, height: 13 * 1.6)
        l.baseline = crBaseline(f, 13 * 1.6)
        _ = lh
        v.addSubview(l)
        host.addSubview(v)
        live = v
        v.alpha = 0
        v.transform = CGAffineTransform(translationX: 0, y: 6)
        crAnimate(0.18) { v.alpha = 1; v.transform = .identity }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak v] in
            guard let v = v else { return }
            crAnimate(0.18, { v.alpha = 0; v.transform = CGAffineTransform(translationX: 0, y: 6) }) { v.removeFromSuperview() }
        }
    }
}

// MARK: - 主控

final class LXCoReadVC: UIViewController, UIGestureRecognizerDelegate, UIDocumentPickerDelegate {
    /// 合上不卸载:读到哪页回来还在哪页(网页 iframe 同款)
    static let shared = LXCoReadVC()

    static func open() {
        let vc = shared
        guard vc.presentingViewController == nil else { return }
        vc.modalPresentationStyle = .fullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        DrawerPlugin.topVC()?.present(vc, animated: false)
    }

    var t = LXCRTheme.of(LXCRPrefs.theme)
    var fs: CGFloat = LXCRPrefs.fontSize
    var lh: CGFloat = LXCRPrefs.lineHeight

    enum Mode { case shelf, detail, reading, records }
    var mode: Mode = .shelf
    private var shownMode: Mode?

    // 书架
    var books: [LXCRBook] = []
    var shelfLoading = false
    let shelfScroll = UIScrollView()
    // 详情
    var detailBook: LXCRBook?
    var detailAnnots: [LXCRAnnot] = []
    var detailOpen = Set<Int>()
    let detailScroll = UIScrollView()
    // 阅读
    var book: LXCRBook?
    var paras: [LXCRPara] = []
    var annots: [LXCRAnnot] = []
    var toc: [LXCRToc] = []
    var vocab: [(word: String, pid: Int)] = []
    var bookmark: Int?
    var curPage = 1, totalPages = 0, pageMin = 1, pageMax = 1
    var stitching = false
    var loadGen = 0
    var heightCache: [Int: (text: CGFloat, head: CGFloat, left: CGFloat)] = [:]
    var chromeAnimating = false
    var readerLoading = false
    var chrome = false
    var selectPid: Int?
    let readerWrap = UIView()
    let table = UITableView(frame: .zero, style: .plain)
    let topBar = LXCRTopBar()
    let progTrack = UIView()
    let progFill = UIView()
    var bottomBar: LXCRBottomBar!
    let ribbon = UIImageView()
    let readerNote = LXCRLine()
    // 共读记录
    var annotFilter: String?
    let recordsWrap = UIView()
    let recTable = UITableView(frame: .zero, style: .plain)
    let recTop = LXCRTopBar()
    var recGroups: [(title: String, pid: Int, items: [LXCRAnnot])] = []
    // 浮层
    let nightToggle = LXCRPress()
    private let nightGlyph = LXCRLine()
    let handle = LXCRPress()
    private let handleBlur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let handleGlyph = LXCRLine()
    var ctxMenu: UIView?
    var ctxCatcher: UIControl?
    var cards: LXCRCards!
    var panels: LXCRPanels!

    var safeTop: CGFloat { view.safeAreaInsets.top }
    var safeBottom: CGFloat { view.safeAreaInsets.bottom }
    /// 网页 iframe 的视口:顶边在状态栏下沿,底边到屏幕底
    var frameH: CGFloat { view.bounds.height - safeTop }

    override var preferredStatusBarStyle: UIStatusBarStyle { t.dark ? .lightContent : .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        if LXCRAPI.fake { LXCRFake.setup() }
        for s in [shelfScroll, detailScroll] {
            s.contentInsetAdjustmentBehavior = .never
            s.alwaysBounceVertical = true
            view.addSubview(s)
        }
        readerWrap.clipsToBounds = true
        view.addSubview(readerWrap)
        table.contentInsetAdjustmentBehavior = .never
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.estimatedRowHeight = 0
        table.estimatedSectionHeaderHeight = 0
        table.estimatedSectionFooterHeight = 0
        table.dataSource = self
        table.delegate = self
        table.allowsSelection = false
        table.register(LXCRParaCell.self, forCellReuseIdentifier: "p")
        table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 16))     // .reader-folio padding-top 16
        table.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 100))    // padding-bottom 100
        readerWrap.addSubview(table)
        readerNote.isHidden = true
        readerWrap.addSubview(readerNote)
        bottomBar = LXCRBottomBar()
        readerWrap.addSubview(ribbon)
        readerWrap.addSubview(progTrack)
        progTrack.addSubview(progFill)
        readerWrap.addSubview(topBar)
        readerWrap.addSubview(bottomBar)
        topBar.back.addAction(UIAction { [weak self] _ in self?.backFromReader() }, for: .touchUpInside)
        topBar.right.addAction(UIAction { [weak self] _ in self?.panels.openSearch() }, for: .touchUpInside)
        bottomBar.onToc = { [weak self] in self?.panels.toggleToc() }
        bottomBar.onSettings = { [weak self] in self?.panels.toggleSettings() }
        bottomBar.onRecords = { [weak self] in self?.showRecords() }
        bottomBar.onPage = { [weak self] p in self?.goPage(p) }

        recordsWrap.clipsToBounds = true
        view.addSubview(recordsWrap)
        recTable.contentInsetAdjustmentBehavior = .never
        recTable.separatorStyle = .none
        recTable.backgroundColor = .clear
        recTable.estimatedRowHeight = 0
        recTable.estimatedSectionHeaderHeight = 0
        recTable.estimatedSectionFooterHeight = 0
        if #available(iOS 15.0, *) { recTable.sectionHeaderTopPadding = 0; table.sectionHeaderTopPadding = 0 }
        recTable.dataSource = self
        recTable.delegate = self
        recTable.register(LXCRRecordCell.self, forCellReuseIdentifier: "r")
        recordsWrap.addSubview(recTable)
        recordsWrap.addSubview(recTop)
        recTop.back.addAction(UIAction { [weak self] _ in self?.backToReader() }, for: .touchUpInside)

        // .night-toggle:右下 36px 圆钮(网页里按了只换一下符号、随即被配色盖回去,等于没用——照抄)
        nightToggle.layer.cornerRadius = 18
        nightToggle.layer.borderWidth = 0.5
        crShadow(nightToggle.layer, y: 2, blur: 8, a: 0.08)
        nightToggle.addSubview(nightGlyph)
        view.addSubview(nightToggle)

        // 外壳的回聊天把手 .reader-close:贴左缘中间的细长条
        handle.layer.cornerRadius = 8
        handle.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        handle.clipsToBounds = true
        handleBlur.isUserInteractionEnabled = false
        handle.addSubview(handleBlur)
        handle.addSubview(handleGlyph)
        handle.addAction(UIAction { [weak self] _ in self?.closeLibrary() }, for: .touchUpInside)
        // 按下时变宽到 18(.reader-close:active)
        handle.addAction(UIAction { [weak self] _ in self?.handleWidth(18) }, for: [.touchDown, .touchDragEnter])
        handle.addAction(UIAction { [weak self] _ in self?.handleWidth(14) }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        view.addSubview(handle)

        cards = LXCRCards(vc: self)
        panels = LXCRPanels(vc: self)

        let tap = UITapGestureRecognizer(target: self, action: #selector(readerTap(_:)))
        tap.delegate = self
        table.addGestureRecognizer(tap)
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(readerLongPress(_:)))
        lp.minimumPressDuration = 0.38          // anno.js initDmHandlers:380ms
        lp.allowableMovement = 8                // 挪 8px 以上算在滚页
        lp.delegate = self
        table.addGestureRecognizer(lp)

        applyTheme()
        switchTo(.shelf, animated: false)
        loadBooks()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
        if mode == .shelf { loadBooks() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width, H = view.bounds.height
        let body = CGRect(x: 0, y: safeTop, width: W, height: H - safeTop)
        if shelfScroll.frame != body { shelfScroll.frame = body; buildShelf() }
        if detailScroll.frame != body { detailScroll.frame = body; buildDetail() }
        if readerWrap.frame != body {
            let widthChanged = readerWrap.frame.width != W
            readerWrap.frame = body
            table.frame = readerWrap.bounds
            if widthChanged { heightCache.removeAll(); table.reloadData() }
        }
        layoutReaderChrome()
        if recordsWrap.frame != body {
            recordsWrap.frame = body
            recTop.frame = CGRect(x: 0, y: 0, width: W, height: 44)
            recTable.frame = CGRect(x: 0, y: 44, width: W, height: body.height - 44)
            recTable.reloadData()
        }
        nightToggle.frame = CGRect(x: W - 56, y: H - 56, width: 36, height: 36)
        nightGlyph.frame = nightToggle.bounds
        handle.frame = CGRect(x: 0, y: (H - 56) / 2, width: handleW, height: 56)
        handleBlur.frame = handle.bounds
        handleGlyph.frame = CGRect(x: 0, y: 0, width: handle.bounds.width - 2, height: 56)
        view.bringSubviewToFront(nightToggle)
        view.bringSubviewToFront(handle)
        panels.layout()
    }

    private var handleW: CGFloat = 14
    private func handleWidth(_ w: CGFloat) {
        handleW = w
        UIView.animate(withDuration: 0.16) {
            self.handle.frame.size.width = w
            self.handleBlur.frame = self.handle.bounds
            self.handleGlyph.frame = CGRect(x: 0, y: 0, width: w - 2, height: 56)
        }
    }

    // MARK: 配色

    func applyTheme() {
        view.backgroundColor = t.bg
        setNeedsStatusBarAppearanceUpdate()
        nightToggle.normalBg = t.surface
        nightToggle.layer.borderColor = t.border.cgColor
        let nf = LXCRFont.f(14)
        nightGlyph.text = crAttr(t.id == "night" ? "\u{263E}" : "\u{263C}", nf, t.ink3)
        nightGlyph.align = .center
        nightGlyph.baseline = (36 - nf.lineHeight) / 2 + nf.ascender
        let dark = LXSheetInk.dark
        handle.normalBg = dark ? UIColor(white: 1, alpha: 0.12) : crRGBA(120, 130, 150, 0.16)
        handle.pressedBg = dark ? UIColor(white: 1, alpha: 0.20) : crRGBA(120, 130, 150, 0.30)
        handleBlur.effect = UIBlurEffect(style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        handleBlur.alpha = 0.5
        let hf = LXCRFont.f(13)
        handleGlyph.text = crAttr("\u{2039}", hf, dark ? crRGBA(233, 229, 220, 0.72) : crRGBA(90, 100, 120, 0.75))
        handleGlyph.align = .center
        handleGlyph.baseline = (56 - hf.lineHeight) / 2 + hf.ascender
        topBar.configure(t, back: "书架", title: book?.title ?? "", right: "\u{26B2}")
        recTop.configure(t, back: "正文", title: "共读记录", right: nil)
        progTrack.backgroundColor = t.surface3
        progFill.backgroundColor = t.accent
        ribbon.image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 36)).image { _ in
            let p = LXSVG.path("M0 0h24v36l-12-8-12 8z")
            let c = UIGraphicsGetCurrentContext()
            c?.addPath(p); c?.setFillColor(t.accent.cgColor); c?.fillPath()
        }
        bottomBar.configure(t)
        cards?.applyTheme()
        panels?.applyTheme()
        buildShelf()
        buildDetail()
        heightCache.removeAll()
        table.reloadData()
        recTable.reloadData()
        table.indicatorStyle = t.dark ? .white : .black
        recTable.indicatorStyle = table.indicatorStyle
        shelfScroll.indicatorStyle = table.indicatorStyle
        detailScroll.indicatorStyle = table.indicatorStyle
    }

    func setTheme(_ id: String) {
        LXCRPrefs.theme = id
        let next = LXCRTheme.of(id)
        // body 有 0.35s 的底色过渡
        UIView.transition(with: view, duration: 0.35, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
            self.t = next
            self.applyTheme()
        })
    }

    // MARK: 换页面

    func switchTo(_ m: Mode, animated: Bool = true) {
        mode = m
        shelfScroll.isHidden = m != .shelf
        detailScroll.isHidden = m != .detail
        readerWrap.isHidden = m != .reading
        recordsWrap.isHidden = m != .records
        nightToggle.isHidden = m == .reading
        view.bringSubviewToFront(nightToggle)
        view.bringSubviewToFront(handle)
        // .fade-in 只在真的换了一个界面时播:上移 6px + 淡入 0.35s
        if animated, shownMode != m {
            let target: UIView? = m == .shelf ? shelfScroll : m == .detail ? detailScroll : m == .reading ? table : recTable
            if let v = target {
                v.alpha = 0
                v.transform = CGAffineTransform(translationX: 0, y: 6)
                crAnimate(0.35) { v.alpha = 1; v.transform = .identity }
            }
        }
        shownMode = m
    }

    func toast(_ s: String) { LXCRToast.show(s, in: view, t: t) }

    func closeLibrary() {
        cards.close()
        panels.closeAll()
        hideCtxMenu()
        dismiss(animated: false)
    }

    // MARK: 书架

    func loadBooks(silent: Bool = false) {
        if books.isEmpty {
            let cached = LXCRPrefs.books.compactMap(LXCRBook.init)
            if !cached.isEmpty && !LXCRAPI.fake { books = sortBooks(cached); buildShelf() }
        }
        if books.isEmpty && !silent { shelfLoading = true; buildShelf() }
        LXCRAPI.call("GET", "/books") { [weak self] obj, _ in
            guard let s = self else { return }
            s.shelfLoading = false
            if let arr = obj as? [[String: Any]] {
                if !LXCRAPI.fake { LXCRPrefs.books = arr }
                s.books = s.sortBooks(arr.compactMap(LXCRBook.init))
            }
            s.buildShelf()
        }
    }

    private func sortBooks(_ b: [LXCRBook]) -> [LXCRBook] {
        b.sorted { a, c in
            let at = a.updatedAt.isEmpty ? a.createdAt : a.updatedAt
            let ct = c.updatedAt.isEmpty ? c.createdAt : c.updatedAt
            return at > ct
        }
    }

    private var shelfViews: [UIView] = []

    func buildShelf() {
        guard isViewLoaded, shelfScroll.bounds.width > 0 else { return }
        shelfViews.forEach { $0.removeFromSuperview() }
        shelfViews.removeAll()
        let W = shelfScroll.bounds.width
        func add(_ v: UIView) { shelfScroll.addSubview(v); shelfViews.append(v) }
        // .shelf-head:顶 18、左右 4(加 .folio 的 16)、底 14;标题 26/600,计数 11px ink4,基线对齐
        let tf = LXCRFont.f(26, 600), cf = LXCRFont.f(11)
        let headLH: CGFloat = 26 * 1.6
        let title = LXCRLine(frame: CGRect(x: 20, y: 18, width: W - 40, height: headLH))
        title.text = crAttr("共读", tf, t.ink1)
        title.baseline = crBaseline(tf, headLH)
        add(title)
        let count = LXCRLine(frame: CGRect(x: 20, y: 18, width: W - 40, height: headLH))
        count.text = crAttr(books.isEmpty ? "" : "\(books.count) 本", cf, t.ink4)
        count.baseline = title.baseline
        count.align = .right
        add(count)
        var y = 18 + headLH + 14
        // .add-book-row:虚线框 1px、圆角 10、内边距 13/14,加号 16 accent,字 15
        let row = LXCRPress(frame: CGRect(x: 16, y: y, width: W - 32, height: 13 + 24 + 13 + 2))
        row.normalBg = t.surface
        row.pressedBg = t.surface2
        row.layer.cornerRadius = 10
        let dash = CAShapeLayer()
        dash.path = UIBezierPath(roundedRect: row.bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 9.5).cgPath
        dash.fillColor = UIColor.clear.cgColor
        dash.strokeColor = t.border.cgColor
        dash.lineWidth = 1
        dash.lineDashPattern = [3, 3]
        row.layer.addSublayer(dash)
        let plus = UIImageView(image: crIcon(["M8 3v10M3 8h10"], size: 16, stroke: 1.2, color: t.accent))
        plus.frame = CGRect(x: 15, y: (row.bounds.height - 16) / 2, width: 16, height: 16)
        row.addSubview(plus)
        let lf = LXCRFont.f(15)
        let label = LXCRLine(frame: CGRect(x: 15 + 16 + 9, y: 14, width: W - 100, height: 24))
        label.text = crAttr("加一本书", lf, t.ink2)
        label.baseline = crBaseline(lf, 24)
        row.addSubview(label)
        row.addAction(UIAction { [weak self] _ in self?.pickBook() }, for: .touchUpInside)
        add(row)
        y += row.bounds.height + 14
        if shelfLoading {
            y += addLoading("正在打开…", y: y, W: W, add: add)
        } else if books.isEmpty {
            y += addEmpty("书架还是空的", y: y, W: W, add: add)
        } else {
            y += 16
            for b in books {
                let card = bookCard(b, W: W)
                card.frame.origin.y = y
                add(card)
                y += card.bounds.height + 12
            }
            y -= 12
        }
        shelfScroll.contentSize = CGSize(width: W, height: y + 80)
    }

    /// .loading:9px 300 字距 2px 大写,上下 48
    func addLoading(_ s: String, y: CGFloat, W: CGFloat, add: (UIView) -> Void) -> CGFloat {
        let f = LXCRFont.f(9, 300)
        let l = LXCRLine(frame: CGRect(x: 16, y: y + 48, width: W - 32, height: 9 * 1.6))
        l.text = crAttr(s.uppercased(), f, t.ink3, kern: 2)
        l.baseline = crBaseline(f, 9 * 1.6)
        l.align = .center
        add(l)
        return 48 + 9 * 1.6 + 48
    }

    /// .empty-state:§ 28/300 + 下面 10px 300 字距 1.5 大写
    func addEmpty(_ s: String, y: CGFloat, W: CGFloat, add: (UIView) -> Void) -> CGFloat {
        let gf = LXCRFont.f(28, 300), tf = LXCRFont.f(10, 300)
        let g = LXCRLine(frame: CGRect(x: 16, y: y + 48, width: W - 32, height: 28 * 1.6))
        g.text = crAttr("§", gf, t.ink3)
        g.baseline = crBaseline(gf, 28 * 1.6)
        g.align = .center
        add(g)
        let l = LXCRLine(frame: CGRect(x: 16, y: y + 48 + 28 * 1.6 + 12, width: W - 32, height: 16))
        l.text = crAttr(s.uppercased(), tf, t.ink3, kern: 1.5)
        l.baseline = crBaseline(tf, 16)
        l.align = .center
        add(l)
        return 48 + 28 * 1.6 + 12 + 16 + 48
    }

    /// .book-card:底 surface、0.5px 边、圆角 4、内边距 13/14;书名 16/400 行高 1.45;meta 11.5/300
    private func bookCard(_ b: LXCRBook, W: CGFloat) -> UIView {
        let card = LXCRPress(frame: CGRect(x: 16, y: 0, width: W - 32, height: 10))
        card.normalBg = t.surface
        card.pressedBg = t.surface2
        card.layer.cornerRadius = 4
        card.layer.borderWidth = 0.5
        card.layer.borderColor = t.border.cgColor
        let inner = card.bounds.width - 1 - 28
        let tf = LXCRFont.f(16)
        let title = LXCRText()
        title.set(crAttr(b.title, tf, t.ink1), font: tf, lineHeight: 16 * 1.45)
        // .book-card-chevron 里的 svg 没写尺寸,网页实际渲染宽 0(量过)——箭头看不见,只占一行 9px 字的高
        let tw = inner - 8
        let th = title.height(for: tw)
        title.frame = CGRect(x: 14.5, y: 13.5, width: tw, height: th)
        card.addSubview(title)
        var y = 13.5 + max(th, 6 + 9 * 1.6) + 6
        // 网页书单里没有 total_pages 这个字段(接口叫 page_count),所以那一行只剩"N 条批注"、进度条不出——照原样
        if b.annotCount > 0 {
            let mf = LXCRFont.f(11.5, 300)
            let meta = LXCRLine(frame: CGRect(x: 14.5, y: y, width: inner, height: 11.5 * 1.6))
            meta.text = crAttr("\(b.annotCount) 条批注", mf, t.ink3, kern: 0.575)
            meta.baseline = crBaseline(mf, 11.5 * 1.6)
            card.addSubview(meta)
            y += 11.5 * 1.6 + 10
        }
        card.frame.size.height = y + 13.5
        card.addAction(UIAction { [weak self, weak card] _ in
            guard let s = self, let c = card, !c.longFired else { card?.longFired = false; return }
            s.openBook(b.id)
        }, for: .touchUpInside)
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(bookLongPress(_:)))
        lp.minimumPressDuration = 0.5           // 书架长按 500ms
        lp.allowableMovement = 10
        card.addGestureRecognizer(lp)
        card.accessibilityIdentifier = b.id
        return card
    }

    @objc private func bookLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let card = g.view as? LXCRPress, let id = card.accessibilityIdentifier else { return }
        card.longFired = true
        card.isHighlighted = false
        showCtxMenu(id, at: g.location(in: view))
    }

    // .ctx-menu:贴着手指出,手指在下半屏时往上让(top ≤ 视口高 −170,left ≤ 视口宽 −160)
    func showCtxMenu(_ id: String, at p: CGPoint) {
        hideCtxMenu()
        let catcher = UIControl(frame: view.bounds)
        catcher.addAction(UIAction { [weak self] _ in self?.hideCtxMenu() }, for: .touchDown)
        view.addSubview(catcher)
        ctxCatcher = catcher
        let f = LXCRFont.f(10, 300)
        let items: [(String, Bool, () -> Void)] = [
            ("详情与批注", false, { [weak self] in self?.openDetail(id) }),
            ("重命名", false, { [weak self] in self?.renameBook(id) }),
            ("删除", true, { [weak self] in self?.panels.confirm("删除这本书？", danger: "Delete") { self?.deleteBook(id) } }),
        ]
        let rowH = 8 + f.lineHeight + 8
        let w = max(140, items.map { 28 + LXCRLine.width(crAttr($0.0, f, t.ink2)) }.max() ?? 140)
        let menu = UIView()
        menu.backgroundColor = t.surface
        menu.layer.cornerRadius = 4
        menu.layer.borderWidth = 0.5
        menu.layer.borderColor = t.border.cgColor
        crShadow(menu.layer, y: 4, blur: 16, a: 0.12)
        var y: CGFloat = 4
        for (label, danger, act) in items {
            let b = LXCRPress(frame: CGRect(x: 0, y: y, width: w, height: rowH))
            b.normalBg = .clear
            b.pressedBg = t.accentSoft
            let l = LXCRLine(frame: CGRect(x: 14, y: 8, width: w - 28, height: f.lineHeight))
            l.text = crAttr(label, f, danger ? t.vermillion : t.ink2)
            l.baseline = f.ascender
            b.addSubview(l)
            b.addAction(UIAction { [weak self] _ in self?.hideCtxMenu(); act() }, for: .touchUpInside)
            menu.addSubview(b)
            y += rowH
        }
        let x = min(p.x, view.bounds.width - 160)
        let top = safeTop + min(p.y - safeTop, frameH - 170)
        menu.frame = CGRect(x: x, y: top, width: w, height: y + 4)
        view.addSubview(menu)
        ctxMenu = menu
    }

    func hideCtxMenu() {
        ctxMenu?.removeFromSuperview(); ctxMenu = nil
        ctxCatcher?.removeFromSuperview(); ctxCatcher = nil
    }

    func renameBook(_ id: String) {
        panels.prompt("New title:", value: "") { [weak self] name in
            guard let s = self, !name.isEmpty else { return }
            LXCRAPI.call("PUT", "/books/\(id)/title", ["title": name]) { _, _ in
                if s.book?.id == id { s.book?.title = name; s.topBar.configure(s.t, back: "书架", title: name, right: "\u{26B2}") }
                if s.detailBook?.id == id { s.detailBook?.title = name }
                s.loadBooks()
                s.buildDetail()
            }
        }
    }

    func deleteBook(_ id: String) {
        LXCRAPI.call("DELETE", "/books/\(id)") { [weak self] _, _ in
            guard let s = self else { return }
            s.detailBook = nil
            s.switchTo(.shelf)
            s.loadBooks()
        }
    }

    // 加一本书:.pdf / .txt / .epub
    func pickBook() {
        var types: [UTType] = [.pdf, .plainText, .text]
        if let epub = UTType(filenameExtension: "epub") { types.append(epub) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let u = urls.first else { return }
        shelfLoading = true
        buildShelf()
        LXCRAPI.upload(u) { [weak self] obj, err in
            guard let s = self else { return }
            if let obj = obj, (obj["ok"] as? Bool) == true {
                s.loadBooks()
            } else {
                s.shelfLoading = false
                s.buildShelf()
                let msg = err.map { "Upload failed: " + $0 } ?? ((obj?["error"] as? String) ?? "Upload failed")
                s.panels.alert(msg)
            }
        }
    }

    // MARK: 详情页(长按书 → 详情与批注)

    func openDetail(_ id: String) {
        LXCRAPI.call("GET", "/books") { [weak self] obj, _ in
            guard let s = self else { return }
            let list = ((obj as? [[String: Any]]) ?? []).compactMap(LXCRBook.init)
            guard let b = list.first(where: { $0.id == id }) else { return }
            LXCRAPI.call("GET", "/books/\(id)/annotations") { obj2, _ in
                s.detailBook = b
                s.detailAnnots = ((obj2 as? [[String: Any]]) ?? []).compactMap(LXCRAnnot.init)
                s.noteMe(s.detailAnnots)
                s.detailOpen.removeAll()
                s.buildDetail()
                s.detailScroll.contentOffset = .zero
                s.switchTo(.detail)
            }
        }
    }

    private var detailViews: [UIView] = []

    func buildDetail() {
        guard isViewLoaded, detailScroll.bounds.width > 0 else { return }
        detailViews.forEach { $0.removeFromSuperview() }
        detailViews.removeAll()
        guard let b = detailBook else { return }
        let W = detailScroll.bounds.width
        func add(_ v: UIView) { detailScroll.addSubview(v); detailViews.append(v) }
        let x0: CGFloat = 16, cw = W - 32
        // .page-header 上 56 下 20;.header-nav:"‹ SHELF" + 右边 Rename,下面空 20
        var y: CGFloat = 56
        let nav = LXCRTopBar()
        nav.backgroundColor = .clear
        nav.configure(t, back: "SHELF", title: "", right: nil)
        nav.backgroundColor = .clear
        let navH = LXCRFont.f(10, 300).lineHeight + 8      // 这里的 nav-back 没有内边距,行高由 Rename(上下 4)撑
        nav.frame = CGRect(x: x0 - 20, y: y, width: cw + 40, height: navH)
        nav.back.addAction(UIAction { [weak self] _ in self?.goShelf() }, for: .touchUpInside)
        add(nav)
        let rf = LXCRFont.f(10, 300)
        let ren = LXCRPress()
        let renL = LXCRLine()
        renL.text = crAttr("Rename", rf, t.ink3, kern: 0.5)
        renL.baseline = rf.ascender
        let rw = renL.textWidth
        ren.frame = CGRect(x: x0 + cw - rw, y: y + (navH - rf.lineHeight - 8) / 2, width: rw, height: rf.lineHeight + 8)
        renL.frame = CGRect(x: 0, y: 4, width: rw + 2, height: rf.lineHeight)
        ren.addSubview(renL)
        ren.pressedAlpha = 0.7
        ren.addAction(UIAction { [weak self] _ in self?.renameBook(b.id) }, for: .touchUpInside)
        add(ren)
        y += navH + 20 + 20
        // .detail-hero:书名斜体 500 26px(手机),行高 1.15,下 8;meta 9px 300 字距 1
        let tf = LXCRFont.italic(26, 500)
        let title = LXCRText()
        title.set(crAttr(b.title, tf, t.ink1, oblique: true), font: tf, lineHeight: 26 * 1.15)
        let th = title.height(for: cw)
        title.frame = CGRect(x: x0, y: y, width: cw, height: th)
        add(title)
        y += th + 8
        var meta: [String] = []
        if b.paraCount > 0 { meta.append("\(b.paraCount) \u{00B6}") }
        if !detailAnnots.isEmpty { meta.append("\(detailAnnots.count) notes") }
        if !meta.isEmpty {
            let mf = LXCRFont.f(9, 300)
            let m = LXCRLine(frame: CGRect(x: x0, y: y, width: cw, height: 9 * 1.6))
            m.text = crAttr(meta.joined(separator: " · "), mf, t.ink3, kern: 1)
            m.baseline = crBaseline(mf, 9 * 1.6)
            add(m)
            y += 9 * 1.6
        }
        y += 20
        // .continue-btn:墨色底、底色字、10px 500 字距 1.5 大写,内边距 14/18
        let cf = LXCRFont.f(10, 500)
        let cont = LXCRPress(frame: CGRect(x: x0, y: y, width: cw, height: 14 + cf.lineHeight + 14))
        cont.normalBg = t.ink1
        cont.pressedAlpha = 0.85
        cont.layer.cornerRadius = 4
        let page = max(1, b.progressPage)
        let cl = LXCRLine(frame: CGRect(x: 18, y: 14, width: cw - 60, height: cf.lineHeight))
        cl.text = crAttr(page > 1 ? "CONTINUE · P.\(page)" : "START READING", cf, t.bg, kern: 1.5)
        cl.baseline = cf.ascender
        cont.addSubview(cl)
        let arrow = UIImageView(image: crIcon(["M3 8h10M9 4l4 4-4 4"], size: 11, stroke: 1.2, color: t.bg))
        arrow.frame = CGRect(x: cw - 18 - 11, y: (cont.bounds.height - 11) / 2, width: 11, height: 11)
        cont.addSubview(arrow)
        cont.addAction(UIAction { [weak self] _ in self?.openBook(b.id) }, for: .touchUpInside)
        add(cont)
        y += cont.bounds.height + 16
        // .progress-card
        let pc = UIView(frame: CGRect(x: x0, y: y, width: cw, height: 10))
        pc.backgroundColor = t.surface
        pc.layer.cornerRadius = 4
        pc.layer.borderWidth = 0.5
        pc.layer.borderColor = t.border.cgColor
        var py: CGFloat = 16.5
        let hf = LXCRFont.f(15, 500)
        let ph = LXCRLine(frame: CGRect(x: 16.5, y: py, width: cw - 33, height: 24))
        ph.text = crAttr("Progress", hf, t.ink1)
        ph.baseline = crBaseline(hf, 24)
        pc.addSubview(ph)
        py += 24 + 14
        func progressRow(_ name: String, _ pct: String, _ color: UIColor, _ fill: CGFloat) {
            let lf = LXCRFont.f(13, 500), vf = LXCRFont.f(10, 300)
            let l = LXCRLine(frame: CGRect(x: 16.5, y: py, width: cw - 33, height: 13 * 1.6))
            l.text = crAttr(name, lf, t.ink1)
            l.baseline = crBaseline(lf, 13 * 1.6)
            pc.addSubview(l)
            let v = LXCRLine(frame: l.frame)
            v.text = crAttr(pct, vf, color)
            v.baseline = l.baseline
            v.align = .right
            pc.addSubview(v)
            py += 13 * 1.6 + 6
            let bar = UIView(frame: CGRect(x: 16.5, y: py, width: cw - 33, height: 5))
            bar.backgroundColor = t.surface3
            bar.layer.cornerRadius = 2.5
            bar.clipsToBounds = true
            let fv = UIView(frame: CGRect(x: 0, y: 0, width: bar.bounds.width * fill, height: 5))
            fv.backgroundColor = color
            fv.layer.cornerRadius = 2.5
            bar.addSubview(fv)
            pc.addSubview(bar)
            py += 5
        }
        // 网页这里拿书单的 total_pages 算百分比,书单里没有这个字段,所以她那行一直是 0%——照原样
        progressRow(meName, "p.\(page) · 0%", t.jade, 0)
        let mine = detailAnnots.filter { $0.isClaude }
        if let maxPid = mine.map({ $0.pid }).max(), maxPid > 0 {
            let pct = b.paraCount > 0 ? min(100, Int((Double(maxPid) / Double(b.paraCount) * 100).rounded())) : 0
            py += 12
            progressRow("Claude", "~\(pct)%", t.accent, CGFloat(pct) / 100)
        }
        py += 16.5
        pc.frame.size.height = py
        add(pc)
        y += py + 14
        // .annot-card
        let ac = UIView(frame: CGRect(x: x0, y: y, width: cw, height: 10))
        ac.backgroundColor = t.surface
        ac.layer.cornerRadius = 4
        ac.layer.borderWidth = 0.5
        ac.layer.borderColor = t.border.cgColor
        ac.clipsToBounds = true
        var ay: CGFloat = 16.5
        let at = LXCRLine(frame: CGRect(x: 16.5, y: ay, width: cw - 33, height: 24))
        at.text = crAttr("Annotations", hf, t.ink1)
        at.baseline = crBaseline(hf, 24)
        ac.addSubview(at)
        let an = LXCRLine(frame: at.frame)
        an.text = crAttr("\(detailAnnots.count)", LXCRFont.f(10, 300), t.ink3)
        an.baseline = at.baseline
        an.align = .right
        ac.addSubview(an)
        ay += 24 + 16
        let groups = Dictionary(grouping: detailAnnots, by: { $0.pid })
        if groups.isEmpty {
            let ef = LXCRFont.f(9, 300)
            let e = LXCRLine(frame: CGRect(x: 16.5, y: ay, width: cw - 33, height: 9 * 1.6))
            e.text = crAttr("no annotations yet", ef, t.ink3)
            e.baseline = crBaseline(ef, 9 * 1.6)
            ac.addSubview(e)
            ay += 9 * 1.6 + 16
        } else {
            for pid in groups.keys.sorted() {
                let items = groups[pid] ?? []
                let open = detailOpen.contains(pid)
                let sep = UIView(frame: CGRect(x: 0, y: ay, width: cw, height: 0.5))
                sep.backgroundColor = t.border
                ac.addSubview(sep)
                let gf = LXCRFont.f(11), nf = LXCRFont.f(9, 300)
                let rowH = 10 + gf.lineHeight + 10
                let tog = LXCRPress(frame: CGRect(x: 0, y: ay + 0.5, width: cw, height: rowH))
                tog.pressedBg = t.accentSoft
                let pl = LXCRLine(frame: CGRect(x: 16, y: 10, width: 120, height: gf.lineHeight))
                pl.text = crAttr("\u{00B6}\(pid)", gf, t.ink3, kern: 0.5)
                pl.baseline = gf.ascender
                tog.addSubview(pl)
                let chev = UIImageView(image: crIcon(["M3 6l5 5 5-5"], size: 8, stroke: 1.2, color: t.ink3))
                chev.frame = CGRect(x: cw - 16 - 8, y: (rowH - 8) / 2, width: 8, height: 8)
                if open { chev.transform = CGAffineTransform(rotationAngle: .pi) }
                tog.addSubview(chev)
                let nl = LXCRLine(frame: CGRect(x: cw - 16 - 8 - 8 - 60, y: 10, width: 60, height: gf.lineHeight))
                nl.text = crAttr("\(items.count)", nf, t.ink3)
                nl.baseline = pl.baseline
                nl.align = .right
                tog.addSubview(nl)
                tog.addAction(UIAction { [weak self] _ in
                    guard let s = self else { return }
                    if s.detailOpen.contains(pid) { s.detailOpen.remove(pid) } else { s.detailOpen.insert(pid) }
                    let off = s.detailScroll.contentOffset
                    s.buildDetail()
                    s.detailScroll.contentOffset = off
                }, for: .touchUpInside)
                ac.addSubview(tog)
                ay += 0.5 + rowH
                if open {
                    ay += detailGroupBody(items, in: ac, y: ay, w: cw) + 14
                }
            }
        }
        ac.frame.size.height = ay + 0.5
        add(ac)
        y += ac.bounds.height + 14
        // .delete-book-btn:9px 300 字距 1.5 大写,朱红半透明
        let df = LXCRFont.f(9, 300)
        let del = LXCRPress(frame: CGRect(x: x0, y: y + 20, width: cw, height: 16 + 9 * 1.6 + 16))
        del.alpha = 0.5
        let dl = LXCRLine(frame: CGRect(x: 0, y: 16, width: cw, height: 9 * 1.6))
        dl.text = crAttr("DELETE BOOK", df, t.vermillion, kern: 1.5)
        dl.baseline = crBaseline(df, 9 * 1.6)
        dl.align = .center
        del.addSubview(dl)
        del.addAction(UIAction { [weak self] _ in
            self?.panels.confirm("Delete this book permanently?", danger: "Delete") { self?.deleteBook(b.id) }
        }, for: .touchUpInside)
        add(del)
        y += 20 + del.bounds.height
        detailScroll.contentSize = CGSize(width: W, height: y + 80)
    }

    /// renderDetailGrouped:划线带它下面挂的话,其余单独的话一条一条
    private func detailGroupBody(_ items: [LXCRAnnot], in host: UIView, y y0: CGFloat, w: CGFloat) -> CGFloat {
        var y = y0
        let x0: CGFloat = 16, cw = w - 32
        let hls = items.filter { $0.type == "highlight" }
        let hlIds = Set(hls.map { $0.id })
        let notes = items.filter { $0.type != "highlight" }
        var linked: [String: [LXCRAnnot]] = [:]
        var standalone: [LXCRAnnot] = []
        for n in notes {
            if let r = n.replyTo, notes.contains(where: { $0.id == r }) { continue }
            if let h = n.highlightId, hlIds.contains(h) { linked[h, default: []].append(n) } else { standalone.append(n) }
        }
        func header(_ a: LXCRAnnot, x: CGFloat, y: CGFloat, w: CGFloat, reply: Bool) -> CGFloat {
            let af = LXCRFont.f(9, 500), df = LXCRFont.f(8, 300)
            let name = (reply ? "\u{21A9} " : "") + (a.isClaude ? LXNick.yan : meName)
            let n = LXCRLine(frame: CGRect(x: x, y: y, width: w, height: 9 * 1.6))
            n.text = crAttr(name, af, a.isClaude ? t.accent : t.jade)
            n.baseline = crBaseline(af, 9 * 1.6)
            host.addSubview(n)
            if a.created.count >= 10 {
                let d = LXCRLine(frame: CGRect(x: x + n.textWidth + 6, y: y, width: 100, height: 9 * 1.6))
                d.text = crAttr(String(a.created.prefix(10)), df, t.ink3)
                d.baseline = n.baseline
                host.addSubview(d)
            }
            return 9 * 1.6
        }
        func note(_ a: LXCRAnnot, x: CGFloat, y: CGFloat, w: CGFloat, hlText: String?) -> CGFloat {
            let f = LXCRFont.f(14)
            let tx = LXCRText()
            tx.set(crAttr(hlText != nil ? cleanNote(a.text, hlText) : a.text, f, t.ink1), font: f, lineHeight: 14 * 1.6)
            let h = tx.height(for: w)
            tx.frame = CGRect(x: x, y: y, width: w, height: h)
            host.addSubview(tx)
            return h
        }
        func reply(_ a: LXCRAnnot, depth: Int, x: CGFloat, w: CGFloat, hlText: String?) {
            let sep = UIView(frame: CGRect(x: x, y: y, width: w, height: 0.5))
            sep.backgroundColor = t.borderSoft
            host.addSubview(sep)
            let ix = x + (depth > 0 ? 12 : 0), iw = w - (depth > 0 ? 12 : 0)
            y += 0.5 + 4
            y += header(a, x: ix, y: y, w: iw, reply: depth > 0) + 2
            y += note(a, x: ix, y: y, w: iw, hlText: hlText) + 4
            for r in notes where r.replyTo == a.id { reply(r, depth: depth + 1, x: x, w: w, hlText: nil) }
        }
        var first = true
        for hl in hls {
            if !first { y += 10 }
            first = false
            let top = y
            let bx = x0 + 3 + 8, bw = cw - 11
            y += header(hl, x: bx, y: y, w: bw, reply: false) + 4
            // .annot-row-highlight:13px 内联底色(加强版),2/6 内边距
            let f = LXCRFont.f(13)
            let tx = LXCRText()
            let s = NSMutableAttributedString(attributedString: crAttr(hl.text, f, t.ink2))
            s.addAttribute(.lxcrMark, value: LXCRMark(hl.isClaude ? t.hlClaudeStrong : t.hlButterStrong), range: NSRange(location: 0, length: s.length))
            tx.set(s, font: f, lineHeight: 13 * 1.6)
            let h = tx.height(for: bw - 12)
            tx.frame = CGRect(x: bx + 6, y: y, width: bw - 12, height: h)
            host.addSubview(tx)
            y += h
            let kids = linked[hl.id] ?? []
            for n in kids where !kids.contains(where: { $0.id == n.replyTo }) { reply(n, depth: 0, x: bx, w: bw, hlText: hl.text) }
            let bar = UIView(frame: CGRect(x: x0, y: top, width: 3, height: y - top))
            bar.backgroundColor = (hl.isClaude ? t.accent : t.jade).withAlphaComponent(0.6)
            bar.layer.cornerRadius = 2
            host.addSubview(bar)
        }
        for a in standalone {
            if !first { y += 10 }
            first = false
            let top = y
            let bx = x0 + 3 + 8, bw = cw - 11
            y += header(a, x: bx, y: y, w: bw, reply: false) + 4
            if !a.text.isEmpty { y += note(a, x: bx, y: y, w: bw, hlText: nil) }
            let bar = UIView(frame: CGRect(x: x0, y: top, width: 3, height: y - top))
            bar.backgroundColor = (a.isClaude ? t.accent : t.jade).withAlphaComponent(0.6)
            bar.layer.cornerRadius = 2
            host.addSubview(bar)
        }
        return y - y0
    }

    /// cleanNoteText:去掉开头的「引文」和重复的划线原文
    func cleanNote(_ text: String, _ hl: String?) -> String {
        var s = text
        if let r = s.range(of: "^「[^」]*」\\s*", options: .regularExpression) { s.removeSubrange(r) }
        if let h = hl, !h.isEmpty, s.hasPrefix(h) {
            s = String(s.dropFirst(h.count))
            while let c = s.first, c.isWhitespace { s.removeFirst() }
        }
        return s
    }

    /// 她的署名:服务器给她的批注默认写的作者名(第一次见到就记住);没见过就叫"我"
    var meName: String { let m = LXCRPrefs.me; return m.isEmpty ? "我" : m }
    func noteMe(_ list: [LXCRAnnot]) {
        if let a = list.first(where: { !$0.isClaude && !$0.author.isEmpty }), a.author != LXCRPrefs.me, !LXCRAPI.fake {
            LXCRPrefs.me = a.author
        }
    }

    func goShelf() {
        detailBook = nil
        switchTo(.shelf)
        buildShelf()
        loadBooks(silent: !books.isEmpty)
    }
}


// MARK: - 底栏

/// .reader-bottombar:上面一行"第 N / M 页"+ 滑杆(同一个 flex 横排,宽度照 flex 收缩算),下面三个图标按钮
final class LXCRBottomBar: UIView {
    var onToc: (() -> Void)?
    var onSettings: (() -> Void)?
    var onRecords: (() -> Void)?
    var onPage: ((Int) -> Void)?
    private let hair = UIView()
    private let label = LXCRText()
    let slider = LXCRPageSlider()
    private var buttons: [(LXCRPress, UIImageView, LXCRLine)] = []
    private var t = LXCRTheme()
    private var cur = 1, total = 1
    private var labelSize = CGSize.zero
    var safeBottom: CGFloat = 0 { didSet { setNeedsLayout() } }

    private static let labelFont = LXCRFont.f(9, 300)
    private static let btnFont = LXCRFont.f(8, 300)

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(hair)
        addSubview(label)
        addSubview(slider)
        slider.addTarget(self, action: #selector(sliding), for: .valueChanged)
        slider.addTarget(self, action: #selector(slid), for: [.touchUpInside, .touchUpOutside])
        let specs: [(String, [String])] = [
            ("目录", ["M3 3h10M3 6.5h7M3 10h9M3 13.5h6"]),
            ("设置", ["M4 15L8 5h1l4 10", "M5.5 12h6", "M14 15l2-5h.5l2 5", "M14.8 13h3.5"]),
            ("共读记录", ["M6 6h8M6 9h8M6 12h5"]),
        ]
        for (i, s) in specs.enumerated() {
            let b = LXCRPress()
            let ic = UIImageView()
            let l = LXCRLine()
            b.addSubview(ic); b.addSubview(l)
            b.accessibilityLabel = s.0
            b.tag = i
            b.addAction(UIAction { [weak self] _ in
                switch i { case 0: self?.onToc?(); case 1: self?.onSettings?(); default: self?.onRecords?() }
            }, for: .touchUpInside)
            b.addTarget(self, action: #selector(press(_:)), for: [.touchDown, .touchDragEnter])
            b.addTarget(self, action: #selector(unpress(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
            addSubview(b)
            buttons.append((b, ic, l))
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ t: LXCRTheme) {
        self.t = t
        backgroundColor = t.bg
        hair.backgroundColor = t.borderSoft
        slider.configure(t)
        let specs: [(String, [String], CGFloat)] = [
            ("目录", ["M3 3h10M3 6.5h7M3 10h9M3 13.5h6"], 1),
            ("设置", ["M4 15L8 5h1l4 10", "M5.5 12h6", "M14 15l2-5h.5l2 5", "M14.8 13h3.5"], 1.2),
            ("共读记录", ["M6 6h8M6 9h8M6 12h5"], 1.2),
        ]
        for (i, s) in specs.enumerated() {
            let (b, ic, l) = buttons[i]
            let box: CGFloat = i == 0 ? 16 : 20
            ic.image = crIcon(s.1, box: box, size: 18, stroke: s.2, color: t.ink3, extra: i == 2 ? { c in
                c.addPath(UIBezierPath(roundedRect: CGRect(x: 3, y: 2, width: 14, height: 16), cornerRadius: 1.5).cgPath)
                c.strokePath()
            } : nil).withRenderingMode(.alwaysTemplate)
            ic.tintColor = t.ink3
            l.text = crAttr(s.0, Self.btnFont, t.ink3, kern: 0.5)
            l.baseline = Self.btnFont.ascender
        }
        setPage(cur, total)
    }

    /// .bottombar-btn:active → accent
    @objc private func press(_ b: LXCRPress) { tint(b.tag, t.accent) }
    @objc private func unpress(_ b: LXCRPress) { tint(b.tag, t.ink3) }
    private func tint(_ i: Int, _ c: UIColor) {
        let (_, ic, l) = buttons[i]
        ic.tintColor = c
        if let a = l.text.mutableCopy() as? NSMutableAttributedString {
            a.addAttribute(.foregroundColor, value: c, range: NSRange(location: 0, length: a.length))
            l.text = a
        }
    }

    func setPage(_ p: Int, _ n: Int, moveSlider: Bool = true) {
        cur = p; total = max(1, n)
        let s = crAttr("第 \(p) / \(n) 页", Self.labelFont, t.ink4, kern: 0.5)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        let m = NSMutableAttributedString(attributedString: s)
        m.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: m.length))
        label.set(m, font: Self.labelFont, lineHeight: 9 * 1.6)
        slider.minimumValue = 1
        slider.maximumValue = Float(max(1, n))
        if moveSlider && !slider.isTracking { slider.value = Float(p) }
        setNeedsLayout()
    }

    @objc private func sliding() {
        let v = Int(slider.value.rounded())
        let s = NSMutableAttributedString(attributedString: crAttr("第 \(v) / \(total) 页", Self.labelFont, t.ink4, kern: 0.5))
        let para = NSMutableParagraphStyle(); para.alignment = .center
        s.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: s.length))
        label.set(s, font: Self.labelFont, lineHeight: 9 * 1.6)
    }
    @objc private func slid() { onPage?(Int(slider.value.rounded())) }

    /// 页码行高(含上 4 的内边距)
    private var pageRowH: CGFloat { 4 + max(labelSize.height + 2, 6 + 3 + 2) }
    private var iconRowH: CGFloat { 6 + 6 + 18 + 2 + Self.btnFont.lineHeight + 6 + 10 }
    var barHeight: CGFloat { 0.5 + pageRowH + iconRowH + safeBottom }

    override func layoutSubviews() {
        super.layoutSubviews()
        let W = bounds.width
        hair.frame = CGRect(x: 0, y: 0, width: W, height: 0.5)
        // flex 横排:标签按自己的字宽、滑杆按 100% 宽一起挤,超出的部分按各自基础宽度的比例分摊(flex-shrink: 1)
        let inner = W - 40
        let maxW = label.storage.length > 0 ? LXCRLine.width(label.storage) : 0
        // 两项基础宽 = 字宽 + inner,超出 = 字宽;各自按基础宽占比让出去
        var lw = maxW - maxW * maxW / max(1, maxW + inner)
        // flex 项最窄只能缩到 min-content:最宽的那个词
        let words = label.storage.string.split(separator: " ").map(String.init)
        let minW = words.map { LXCRLine.width(crAttr($0, Self.labelFont, t.ink4, kern: 0.5)) }.max() ?? 0
        lw = min(maxW, max(minW, lw))
        let sw = inner - lw
        let lh = label.height(for: lw)
        labelSize = CGSize(width: lw, height: lh)
        let rowTop: CGFloat = 0.5 + 4
        let rowH = max(lh + 2, 11)
        label.frame = CGRect(x: 20, y: rowTop + (rowH - (lh + 2)) / 2, width: lw, height: lh)
        slider.frame = CGRect(x: 20 + lw, y: rowTop + (rowH - 11) / 2 + 6 - 8.5, width: sw, height: 20)
        // .reader-bottombar-icons:最宽 360 居中,内边距 6/20/10,space-around
        let iconTop = rowTop + rowH
        let rowW = min(W, 360), rowX = (W - rowW) / 2
        let avail = rowW - 40
        let widths = buttons.map { 12 + max(18, $0.2.textWidth) + 12 }
        let gap = (avail - widths.reduce(0, +)) / CGFloat(buttons.count)
        var x = rowX + 20 + gap / 2
        let bh = 6 + 18 + 2 + Self.btnFont.lineHeight + 6
        for (i, (b, ic, l)) in buttons.enumerated() {
            b.frame = CGRect(x: x, y: iconTop + 6, width: widths[i], height: bh)
            ic.frame = CGRect(x: (widths[i] - 18) / 2, y: 6, width: 18, height: 18)
            l.frame = CGRect(x: 0, y: 6 + 18 + 2, width: widths[i], height: Self.btnFont.lineHeight)
            l.align = .center
            x += widths[i] + gap
        }
    }
}

/// .page-slider:3px 轨道 surface3,拇指 16px accent + 2px 底色描边 + 小影子
final class LXCRPageSlider: UISlider {
    func configure(_ t: LXCRTheme) {
        let track = UIGraphicsImageRenderer(size: CGSize(width: 5, height: 3)).image { _ in
            t.surface3.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 5, height: 3), cornerRadius: 1.5).fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 2, bottom: 0, right: 2))
        setMinimumTrackImage(track, for: .normal)
        setMaximumTrackImage(track, for: .normal)
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 26, height: 26)).image { ctx in
            let c = ctx.cgContext
            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor(white: 0, alpha: 0.2).cgColor)
            t.surface.setFill()
            c.fillEllipse(in: CGRect(x: 3, y: 3, width: 20, height: 20))
            c.setShadow(offset: .zero, blur: 0, color: nil)
            t.accent.setFill()
            c.fillEllipse(in: CGRect(x: 5, y: 5, width: 16, height: 16))
        }
        setThumbImage(thumb, for: .normal)
        setThumbImage(thumb, for: .highlighted)
    }
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        CGRect(x: 0, y: (bounds.height - 3) / 2, width: bounds.width, height: 3)
    }
    /// 拇指的外沿(20px)在轨道两头之间走,和浏览器的 range 一样
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let span = maximumValue - minimumValue
        let f = span > 0 ? CGFloat((value - minimumValue) / span) : 0
        let x = (bounds.width - 20) * f
        return CGRect(x: x - 3, y: (bounds.height - 26) / 2, width: 26, height: 26)
    }
}

// MARK: - 段落格

final class LXCRParaCell: UITableViewCell {
    let box = UIView()
    let bar = UIView()
    let barLower = UIView()
    let head = LXCRText()
    let tv = LXCRTextView()
    var pid = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        for v in [box, head, tv, bar, barLower] as [UIView] { contentView.addSubview(v) }
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// 段落几何(cell 内坐标)
struct LXCRGeo {
    var headTop: CGFloat = 0
    var headH: CGFloat = 0
    var paraTop: CGFloat = 0
    var textH: CGFloat = 0
    var left: CGFloat = 32
    var total: CGFloat { paraTop + 8 + textH + 8 }
}

extension LXCoReadVC: UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {

    // MARK: 段落排版

    private static var measureView = LXCRText()
    private static var headMeasure = LXCRText()

    var textWidthBase: CGFloat { table.bounds.width }

    /// .paragraph 内边距 8/16(手机),加 .folio 的 16 → 字从 32 开始;有批注/书签的段左边多一条 2px 线,字从 36 开始
    func annotClass(_ pid: Int) -> (butter: Bool, claude: Bool) {
        var b = false, c = false
        for a in annots where a.pid == pid { if a.isClaude { c = true } else { b = true } }
        return (b, c)
    }

    func chapter(at pid: Int) -> LXCRToc? { toc.first { $0.pid == pid } }

    func paraAttr(_ p: LXCRPara) -> NSAttributedString {
        let f = LXCRFont.f(fs)
        let text = crCollapse(p.text)
        let s = NSMutableAttributedString(string: text, attributes: [.font: f, .foregroundColor: t.ink2])
        let ns = text as NSString
        // 划线:每条只认第一次出现的位置;两人重叠的字 = both
        let hls = annots.filter { $0.pid == p.id && $0.type == "highlight" && !$0.text.isEmpty }
        if !hls.isEmpty {
            var map = [UInt8](repeating: 0, count: ns.length)
            for h in hls {
                var r = ns.range(of: h.text)
                if r.location == NSNotFound { r = ns.range(of: crCollapse(h.text)) }
                guard r.location != NSNotFound else { continue }
                let bit: UInt8 = h.isClaude ? 2 : 1
                for i in r.location..<(r.location + r.length) { map[i] |= bit }
            }
            var i = 0
            while i < map.count {
                let k = map[i]
                var j = i
                while j < map.count && map[j] == k { j += 1 }
                if k != 0 {
                    let mark = k == 3 ? LXCRMark(t.hlButter, t.hlClaude) : LXCRMark(k == 2 ? t.hlClaude : t.hlButter)
                    s.addAttribute(.lxcrMark, value: mark, range: NSRange(location: i, length: j - i))
                }
                i = j
            }
        }
        // 生词:不分大小写,长的先配
        let words = vocab.filter { $0.pid == p.id }.map { $0.word }.filter { !$0.isEmpty }.sorted { $0.count > $1.count }
        if !words.isEmpty, let re = try? NSRegularExpression(pattern: "(" + words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|") + ")", options: [.caseInsensitive]) {
            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                s.addAttribute(.lxcrVocab, value: t.vocabLine, range: m.range)
            }
        }
        // 段尾弹幕小方块:只数"话"(note),不数划线;他说过话就换 accent 色
        let notes = annots.filter { $0.pid == p.id && $0.type == "note" }
        if !notes.isEmpty {
            s.append(badge(notes.count > 999 ? "999+" : "\(notes.count)", claude: notes.contains { $0.isClaude }))
        }
        return s
    }

    /// .dm-badge:最小宽 22、高 17、左外边距 5、内边距 0/4、1px 边、圆角 3、字 10px、比正文基线抬 2px
    func badge(_ n: String, claude: Bool) -> NSAttributedString {
        let f = LXCRFont.f(10)
        let col = claude ? t.accent : t.ink4
        let line = crAttr(n, f, col)
        let tw = LXCRLine.width(line)
        let bw = max(22, ceil(tw) + 8 + 2)
        let inner = 3.5 + crBaseline(f, 10)        // 小方块里数字的基线(离方块顶)
        let below = 17 - inner - 2                 // 方块底比正文基线低多少
        let img = UIGraphicsImageRenderer(size: CGSize(width: 5 + bw, height: 17)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor((claude ? t.accentSoft : t.borderSoft).cgColor)
            c.setLineWidth(1)
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 5.5, y: 0.5, width: bw - 1, height: 16), cornerRadius: 2.5).cgPath)
            c.strokePath()
            c.textMatrix = .identity
            c.translateBy(x: 0, y: 17)
            c.scaleBy(x: 1, y: -1)
            c.textPosition = CGPoint(x: 5 + (bw - tw) / 2, y: 17 - inner)
            CTLineDraw(CTLineCreateWithAttributedString(line as CFAttributedString), c)
        }
        let att = NSTextAttachment()
        att.image = img
        att.bounds = CGRect(x: 0, y: -below, width: 5 + bw, height: 17)
        let s = NSMutableAttributedString(attachment: att)
        s.addAttribute(.lxcrBadgeKey, value: true, range: NSRange(location: 0, length: s.length))
        return s
    }

    func paraHeights(_ p: LXCRPara) -> (text: CGFloat, head: CGFloat, left: CGFloat) {
        if let h = heightCache[p.id] { return h }
        let W = textWidthBase
        let ac = annotClass(p.id)
        let marked = ac.butter || ac.claude || bookmark == p.id
        let left: CGFloat = marked ? 36 : 32
        let mv = Self.measureView
        mv.set(paraAttr(p), font: LXCRFont.f(fs), lineHeight: fs * lh)
        let th = mv.height(for: W - left - 32)
        var hh: CGFloat = 0
        if let ch = chapter(at: p.id) {
            let hf = LXCRFont.f(fs + 5, 700)
            Self.headMeasure.set(crAttr(crCollapse(ch.title), hf, t.ink1), font: hf, lineHeight: (fs + 5) * 1.4)
            hh = Self.headMeasure.height(for: W - 72)
        }
        let r = (text: th, head: hh, left: left)
        heightCache[p.id] = r
        return r
    }

    func geo(_ row: Int) -> LXCRGeo {
        var g = LXCRGeo()
        guard row < paras.count else { return g }
        let p = paras[row]
        let h = paraHeights(p)
        g.left = h.left
        g.textH = h.text
        if chapter(at: p.id) != nil {
            // .chapter-head:上 54 下 26;它是长卷第一个元素时上边只有 10
            g.headTop = row == 0 ? 10 : 54
            g.headH = h.head
            g.paraTop = g.headTop + h.head + 26
        }
        return g
    }

    func numberOfSections(in tableView: UITableView) -> Int { tableView === recTable ? max(1, recGroups.count) : 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView === recTable { return recordRows(section) }
        return readerLoading ? 0 : paras.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView === recTable { return recordHeight(indexPath) }
        return geo(indexPath.row).total
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === recTable { return recordCell(indexPath) }
        let cell = tableView.dequeueReusableCell(withIdentifier: "p", for: indexPath) as! LXCRParaCell
        configure(cell, indexPath.row)
        return cell
    }

    func configure(_ cell: LXCRParaCell, _ row: Int) {
        guard row < paras.count else { return }
        let p = paras[row]
        let g = geo(row)
        let W = table.bounds.width
        cell.pid = p.id
        if let ch = chapter(at: p.id) {
            let hf = LXCRFont.f(fs + 5, 700)
            cell.head.isHidden = false
            cell.head.set(crAttr(crCollapse(ch.title), hf, t.ink1), font: hf, lineHeight: (fs + 5) * 1.4)
            cell.head.frame = CGRect(x: 36, y: g.headTop, width: W - 72, height: g.headH)
        } else {
            cell.head.isHidden = true
        }
        let boxH = 8 + g.textH + 8
        cell.box.frame = CGRect(x: 16, y: g.paraTop, width: W - 32, height: boxH)
        let active = cards.dmPid == p.id
        let selectable = selectPid == p.id
        cell.box.backgroundColor = active ? t.hlButter : (selectable ? t.accentSoft : .clear)
        cell.box.layer.cornerRadius = active ? 6 : 4
        let ac = annotClass(p.id)
        cell.bar.isHidden = !(ac.butter || ac.claude || bookmark == p.id)
        cell.barLower.isHidden = !(ac.butter && ac.claude)
        if ac.butter && ac.claude {
            cell.bar.backgroundColor = t.jade
            cell.barLower.backgroundColor = t.accent
            cell.bar.frame = CGRect(x: 16, y: g.paraTop, width: 2, height: boxH / 2)
            cell.barLower.frame = CGRect(x: 16, y: g.paraTop + boxH / 2, width: 2, height: boxH / 2)
        } else {
            cell.bar.backgroundColor = ac.butter ? t.jade : t.accent
            cell.bar.frame = CGRect(x: 16, y: g.paraTop, width: 2, height: boxH)
        }
        let tv = cell.tv
        tv.crLayout.set(LXCRFont.f(fs), lineHeight: fs * lh)
        tv.attributedText = paraAttr(p)
        tv.frame = CGRect(x: g.left, y: g.paraTop + 8, width: W - g.left - 32, height: g.textH)
        tv.isSelectable = selectable
        tv.isUserInteractionEnabled = selectable
        tv.delegate = selectable ? self : nil
        tv.tintColor = t.accent
        if !selectable && tv.selectedRange.length > 0 { tv.selectedRange = NSRange(location: 0, length: 0) }
    }

    func cell(for pid: Int) -> LXCRParaCell? {
        guard let i = paras.firstIndex(where: { $0.id == pid }) else { return nil }
        return table.cellForRow(at: IndexPath(row: i, section: 0)) as? LXCRParaCell
    }

    /// 这一段的方框(.paragraph)在长卷里的位置
    func paraRect(_ pid: Int) -> CGRect? {
        guard let i = paras.firstIndex(where: { $0.id == pid }) else { return nil }
        let r = table.rectForRow(at: IndexPath(row: i, section: 0))
        let g = geo(i)
        return CGRect(x: 16, y: r.minY + g.paraTop, width: table.bounds.width - 32, height: g.total - g.paraTop)
    }

    func paraTextOf(_ pid: Int) -> String { paras.first { $0.id == pid }?.text ?? "" }

    /// 只就地刷这几段(高度变了也一起挪),视线钉在当前顶上那段
    func refreshParas(_ pids: Set<Int>? = nil) {
        if let pids = pids { for p in pids { heightCache[p] = nil } } else { heightCache.removeAll() }
        reloadAnchored()
    }

    func reloadAnchored() {
        let vis = table.indexPathsForVisibleRows ?? []
        guard let ip = vis.first(where: { table.rectForRow(at: $0).maxY > table.contentOffset.y }), ip.row < paras.count else {
            table.reloadData(); cards.reposition(); return
        }
        let pid = paras[ip.row].id
        let before = table.rectForRow(at: ip).minY - table.contentOffset.y
        UIView.performWithoutAnimation {
            table.reloadData()
            table.layoutIfNeeded()
            if let i = paras.firstIndex(where: { $0.id == pid }) {
                let after = table.rectForRow(at: IndexPath(row: i, section: 0)).minY
                let maxY = max(0, table.contentSize.height - table.bounds.height)
                table.contentOffset = CGPoint(x: 0, y: min(max(0, after - before), maxY))
            }
        }
        cards.reposition()
        updateRibbon()
    }

    // MARK: 开书 / 翻页 / 缝页

    func openBook(_ id: String) {
        cards.close()
        func go(_ b: LXCRBook) {
            book = b
            curPage = max(1, b.progressPage)
            annots = []; vocab = []; toc = []; bookmark = nil
            selectPid = nil
            readerLoading = false   // 换书时上一本还在翻页:别让旧的"加载中"卡住新书
            heightCache.removeAll()
            topBar.configure(t, back: "书架", title: b.title, right: "\u{26B2}")
            if mode == .shelf { shelfLoading = true; buildShelf() }
            loadPage(b.id, curPage) { [weak self] ok in
                guard let s = self else { return }
                s.shelfLoading = false
                s.buildShelf()
                guard ok else { return }
                s.switchTo(.reading)
                UIView.performWithoutAnimation {
                    s.table.reloadData()
                    s.table.layoutIfNeeded()
                    s.table.contentOffset = .zero
                }
                s.layoutReaderChrome()
                s.fetchExtras(b.id)
                DispatchQueue.main.async { s.readerScrolled(force: true) }
            }
        }
        if let b = books.first(where: { $0.id == id }) ?? (detailBook?.id == id ? detailBook : nil) { go(b); return }
        LXCRAPI.call("GET", "/books/\(id)") { obj, _ in
            if let d = obj as? [String: Any], let b = LXCRBook(d) { go(b) }
        }
    }

    /// 正文先到就进门,批注/书签/目录并行补齐后就地补画(网页 openBook 同款)
    func fetchExtras(_ id: String) {
        var got = 0
        var a: [LXCRAnnot] = [], bm: Int? = nil, tc: [LXCRToc] = []
        let done = { [weak self] in
            got += 1
            guard got == 3, let s = self, s.book?.id == id else { return }
            s.annots = a
            s.noteMe(a)
            s.bookmark = bm
            s.toc = tc
            s.refreshParas()
            if s.mode == .records { s.buildRecords() }
        }
        LXCRAPI.call("GET", "/books/\(id)/annotations") { obj, _ in
            a = ((obj as? [[String: Any]]) ?? []).compactMap(LXCRAnnot.init); done()
        }
        LXCRAPI.call("GET", "/books/\(id)/bookmarks") { obj, _ in
            bm = ((obj as? [String: Any])?["bookmark"] as? NSNumber)?.intValue; done()
        }
        LXCRAPI.call("GET", "/books/\(id)/toc") { obj, _ in
            tc = ((obj as? [[String: Any]]) ?? []).compactMap { d in
                guard let pid = (d["paragraph_id"] as? NSNumber)?.intValue else { return nil }
                return LXCRToc(title: (d["title"] as? String) ?? "", pid: pid, level: (d["level"] as? NSNumber)?.intValue ?? 0)
            }
            done()
        }
    }

    private func parsePage(_ obj: Any?, _ page: Int) -> (paras: [LXCRPara], total: Int)? {
        guard let d = obj as? [String: Any], let arr = d["paragraphs"] as? [[String: Any]] else { return nil }
        let total = (d["total_pages"] as? NSNumber)?.intValue ?? 0
        let ps = arr.compactMap { p -> LXCRPara? in
            guard let id = (p["id"] as? NSNumber)?.intValue else { return nil }
            return LXCRPara(id: id, text: (p["text"] as? String) ?? "", page: page)
        }
        return (ps, total)
    }

    func loadPage(_ id: String, _ page: Int, _ done: @escaping (Bool) -> Void) {
        cards.close()
        selectPid = nil
        LXCRAPI.call("GET", "/books/\(id)/pages/\(page)") { [weak self] obj, _ in
            guard let s = self, s.book?.id == id else { return }
            guard let r = s.parsePage(obj, page) else {
                // 存的进度超出页数(书被重新分过页):退回第一页
                if page != 1 { s.curPage = 1; s.loadPage(id, 1, done) } else { done(false) }
                return
            }
            s.paras = r.paras
            s.totalPages = r.total
            s.curPage = page
            s.pageMin = page
            s.pageMax = page
            s.loadGen += 1
            s.saveProgress(page)
            s.updateProgressUi()
            done(true)
        }
    }

    func saveProgress(_ p: Int) {
        guard let id = book?.id else { return }
        LXCRAPI.call("PUT", "/books/\(id)/progress", ["page": p]) { _, _ in }
        if let i = books.firstIndex(where: { $0.id == id }) {
            books[i].progressPage = p
            books[i].updatedAt = ISO8601DateFormatter().string(from: Date())
        }
    }

    func goPage(_ p: Int, then: (() -> Void)? = nil) {
        guard let b = book, p >= 1, p <= max(1, totalPages), !readerLoading else { return }
        readerLoading = true
        showReaderNote("正在翻页…")
        table.reloadData()
        loadPage(b.id, p) { [weak self] ok in
            guard let s = self else { return }
            s.readerLoading = false
            s.showReaderNote(nil)
            UIView.performWithoutAnimation {
                s.table.reloadData()
                s.table.layoutIfNeeded()
                s.table.contentOffset = .zero
            }
            s.updateRibbon()
            then?()
            DispatchQueue.main.async { s.readerScrolled(force: true) }
        }
    }

    func showReaderNote(_ s: String?) {
        guard let s = s else { readerNote.isHidden = true; return }
        let f = LXCRFont.f(9, 300)
        readerNote.text = crAttr(s.uppercased(), f, t.ink3, kern: 2)
        readerNote.baseline = crBaseline(f, 9 * 1.6)
        readerNote.align = .center
        readerNote.frame = CGRect(x: 32, y: 16 + 48, width: table.bounds.width - 64, height: 9 * 1.6)
        readerNote.isHidden = false
        readerWrap.bringSubviewToFront(topBar)
        readerWrap.bringSubviewToFront(bottomBar)
    }

    /// 往后缝一页:接在长卷末尾
    func extendDown() {
        guard let b = book, !stitching, pageMax < totalPages else { return }
        stitching = true
        let next = pageMax + 1
        let gen = loadGen
        LXCRAPI.call("GET", "/books/\(b.id)/pages/\(next)") { [weak self] obj, _ in
            guard let s = self else { return }
            s.stitching = false
            guard s.book?.id == b.id, s.loadGen == gen, !s.readerLoading, let r = s.parsePage(obj, next) else { return }
            let have = Set(s.paras.map { $0.id })
            let add = r.paras.filter { !have.contains($0.id) }
            s.pageMax = next
            guard !add.isEmpty else { return }
            let start = s.paras.count
            s.paras += add
            UIView.performWithoutAnimation {
                s.table.insertRows(at: (start..<s.paras.count).map { IndexPath(row: $0, section: 0) }, with: .none)
            }
        }
    }

    /// 往前缝一页:加在头上会把下面全推走,用长卷总高的差把视线钉回原处
    func extendUp() {
        guard let b = book, !stitching, pageMin > 1 else { return }
        stitching = true
        let prev = pageMin - 1
        let gen = loadGen
        LXCRAPI.call("GET", "/books/\(b.id)/pages/\(prev)") { [weak self] obj, _ in
            guard let s = self else { return }
            s.stitching = false
            guard s.book?.id == b.id, s.loadGen == gen, !s.readerLoading, let r = s.parsePage(obj, prev) else { return }
            let have = Set(s.paras.map { $0.id })
            let add = r.paras.filter { !have.contains($0.id) }
            s.pageMin = prev
            guard !add.isEmpty else { return }
            s.cards.close()                         // 卡片按长卷坐标挂着,上面插内容它就飘了
            let before = s.table.contentSize.height
            let y = s.table.contentOffset.y
            s.paras = add + s.paras
            UIView.performWithoutAnimation {
                s.table.reloadData()
                s.table.layoutIfNeeded()
                s.table.contentOffset = CGPoint(x: 0, y: y + (s.table.contentSize.height - before))
            }
        }
    }

    private static var scrollTick = false
    private static var progressWork: DispatchWorkItem?

    /// 滚动:离底 1200 内缝下一页、离顶 600 内缝上一页;顶端那段在哪页就记哪页(停 1.2 秒才存)
    func readerScrolled(force: Bool = false) {
        guard mode == .reading, !readerLoading else { return }
        if Self.scrollTick && !force { return }
        Self.scrollTick = true
        DispatchQueue.main.asyncAfter(deadline: .now() + (force ? 0 : 0.12)) { [weak self] in
            Self.scrollTick = false
            guard let s = self else { return }
            let y = s.table.contentOffset.y
            let h = s.table.contentSize.height
            if y + s.table.bounds.height > h - 1200 { s.extendDown() }
            if y < 600 { s.extendUp() }
            let pg = s.currentPageFromView()
            if pg != s.curPage {
                s.curPage = pg
                s.updateProgressUi()
                Self.progressWork?.cancel()
                let w = DispatchWorkItem { [weak s] in s?.saveProgress(pg) }
                Self.progressWork = w
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: w)
            }
            s.updateRibbon()
        }
    }

    /// 视口顶端(往下 60 内)那一段
    func currentPidInView() -> Int {
        let y = table.contentOffset.y
        for ip in (table.indexPathsForVisibleRows ?? []).sorted() where ip.row < paras.count {
            if table.rectForRow(at: ip).maxY - y > 60 { return paras[ip.row].id }
        }
        return paras.first?.id ?? 0
    }

    func currentPageFromView() -> Int {
        let pid = currentPidInView()
        return paras.first { $0.id == pid }?.page ?? curPage
    }

    func updateProgressUi() {
        layoutReaderChrome()
        bottomBar.setPage(curPage, totalPages)
    }

    func updateRibbon() {
        let on = mode == .reading && bookmark != nil && paras.contains { $0.id == bookmark }
        let target: CGFloat = on ? 1 : 0
        guard ribbon.alpha != target else { return }
        crAnimate(0.3) {
            self.ribbon.alpha = target
            self.ribbon.transform = on ? .identity : CGAffineTransform(translationX: 0, y: -8)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === table { readerScrolled() }
    }

    // MARK: 上下栏

    func layoutReaderChrome() {
        guard isViewLoaded else { return }
        let W = readerWrap.bounds.width, H = readerWrap.bounds.height
        // 这几样身上挂着进出动画的位移,只改 bounds/center,不碰 frame
        func put(_ v: UIView, _ r: CGRect) {
            v.bounds = CGRect(origin: .zero, size: r.size)
            v.center = CGPoint(x: r.midX, y: r.midY)
        }
        put(topBar, CGRect(x: 0, y: 0, width: W, height: 44))
        put(progTrack, CGRect(x: 0, y: 44, width: W, height: 3))
        let pct = totalPages > 0 ? (Double(curPage) / Double(totalPages) * 100).rounded() / 100 : 0
        UIView.animate(withDuration: 0.35) { self.progFill.frame = CGRect(x: 0, y: 0, width: W * CGFloat(pct), height: 3) }
        bottomBar.safeBottom = safeBottom
        put(bottomBar, CGRect(x: 0, y: H - bottomBar.barHeight, width: W, height: bottomBar.barHeight))
        bottomBar.layoutIfNeeded()
        let bh = bottomBar.barHeight
        if abs(bottomBar.bounds.height - bh) > 0.5 { put(bottomBar, CGRect(x: 0, y: H - bh, width: W, height: bh)) }
        put(ribbon, CGRect(x: W - 24, y: 44, width: 24, height: 36))
        if !chromeAnimating { applyChrome(animated: false) }
    }

    /// 点正文 = 上下栏一起进出(.22s);进度条跟着顶栏走
    func applyChrome(animated: Bool) {
        let body = {
            self.topBar.alpha = self.chrome ? 1 : 0
            self.topBar.transform = self.chrome ? .identity : CGAffineTransform(translationX: 0, y: -44)
            self.progTrack.alpha = self.chrome ? 1 : 0
            self.progTrack.transform = self.chrome ? .identity : CGAffineTransform(translationX: 0, y: -6)
            self.bottomBar.alpha = self.chrome ? 1 : 0
            self.bottomBar.transform = self.chrome ? .identity : CGAffineTransform(translationX: 0, y: self.bottomBar.bounds.height)
        }
        topBar.isUserInteractionEnabled = chrome
        bottomBar.isUserInteractionEnabled = chrome
        if animated {
            chromeAnimating = true
            crAnimate(0.22, body) { self.chromeAnimating = false }
        } else { body() }
    }

    func setChrome(_ on: Bool) {
        chrome = on
        applyChrome(animated: true)
        if !on { panels.hideSettings(); panels.hideToc() }
    }

    func backFromReader() {
        panels.closeAll()
        cards.close()
        setChrome(false)
        goShelf()
    }

    // MARK: 手势

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let v = touch.view, cards.owns(v) { return false }
        return true
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard g.view === table else { return true }
        let p = g.location(in: table)
        // "划重点"那段把手势还给系统选字
        if let sp = selectPid, let c = cell(for: sp), c.tv.frame.contains(c.contentView.convert(p, from: table)) {
            return false
        }
        if g is UILongPressGestureRecognizer, badgeHit(p) != nil { return false }
        return true
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    @objc func readerTap(_ g: UITapGestureRecognizer) {
        let p = g.location(in: table)
        // 卡片开着:这一下归卡片(点外面=收);长按抬手补发的那一下 500ms 内不算
        if cards.isOpen {
            if Date().timeIntervalSince(cards.openedAt) < 0.5 { return }
            cards.close()
            return
        }
        if let pid = badgeHit(p) { cards.open(pid, mode: .list); return }
        if let hit = markHit(p) { panels.openAnnot(hit.pid, hl: hit.text); return }
        if panels.tocOpen || panels.settingsOpen { panels.hideToc(); panels.hideSettings(); return }
        if cards.selBarOpen { cards.clearSelection() }
        setChrome(!chrome)
    }

    @objc func readerLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        let p = g.location(in: table)
        guard let ip = table.indexPathForRow(at: p), ip.row < paras.count else { return }
        let para = paras[ip.row]
        guard para.id != selectPid, let r = paraRect(para.id), r.contains(p) else { return }
        cards.open(para.id, mode: .menu)
    }

    /// 点在段尾小方块上?(热区往外放 6)
    func badgeHit(_ p: CGPoint) -> Int? {
        for c in table.visibleCells.compactMap({ $0 as? LXCRParaCell }) where !c.tv.isHidden {
            let s = c.tv.textStorage
            guard s.length > 0 else { continue }
            var found: NSRange?
            s.enumerateAttribute(.lxcrBadgeKey, in: NSRange(location: 0, length: s.length)) { v, r, stop in
                if v != nil { found = r; stop.pointee = true }
            }
            guard let r = found else { continue }
            let lm = c.tv.layoutManager
            let gr = lm.glyphRange(forCharacterRange: r, actualCharacterRange: nil)
            var rect = lm.boundingRect(forGlyphRange: gr, in: c.tv.textContainer)
            rect.origin.x += 5; rect.size.width -= 5
            let inTable = c.tv.convert(rect, to: table).insetBy(dx: -6, dy: -6)
            if inTable.contains(p) { return c.pid }
        }
        return nil
    }

    /// 点在划线上?返回那一段和那一截同色的字(网页 mark.textContent)
    func markHit(_ p: CGPoint) -> (pid: Int, text: String)? {
        for c in table.visibleCells.compactMap({ $0 as? LXCRParaCell }) {
            let q = c.tv.convert(p, from: table)
            guard c.tv.bounds.contains(q) else { continue }
            let lm = c.tv.layoutManager
            let gi = lm.glyphIndex(for: q, in: c.tv.textContainer, fractionOfDistanceThroughGlyph: nil)
            let gr = lm.boundingRect(forGlyphRange: NSRange(location: gi, length: 1), in: c.tv.textContainer)
            guard gr.insetBy(dx: -2, dy: 0).contains(q) else { return nil }
            let ci = lm.characterIndexForGlyph(at: gi)
            let s = c.tv.textStorage
            guard ci < s.length else { return nil }
            var range = NSRange()
            guard s.attribute(.lxcrMark, at: ci, effectiveRange: &range) != nil else { return nil }
            return (c.pid, (s.string as NSString).substring(with: range))
        }
        return nil
    }

    // 划重点:选完字出小工具条
    func textViewDidChangeSelection(_ textView: UITextView) {
        cards.selectionChanged(textView)
    }
}

extension NSAttributedString.Key {
    static let lxcrBadgeKey = NSAttributedString.Key("lxcr.badge")
}

// MARK: - 共读记录

final class LXCRRecordCell: UITableViewCell {
    let card = UIView()
    let bar = UIView()
    let who = LXCRLine()
    let when = LXCRLine()
    let kind = UIView()
    let kindL = LXCRLine()
    let body = LXCRText()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(card)
        for v in [bar, who, when, kind, body] as [UIView] { card.addSubview(v) }
        kind.addSubview(kindL)
        card.layer.cornerRadius = 8
        card.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        card.clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
}

extension LXCoReadVC {
    func showRecords() {
        panels.hideSettings(); panels.hideToc()
        annotFilter = nil
        buildRecords()
        recTable.contentOffset = .zero
        switchTo(.records)
        // 兜底:批注之前没拉到就当场再拉一次
        if annots.isEmpty, let id = book?.id {
            LXCRAPI.call("GET", "/books/\(id)/annotations") { [weak self] obj, _ in
                guard let s = self, s.mode == .records else { return }
                let a = ((obj as? [[String: Any]]) ?? []).compactMap(LXCRAnnot.init)
                if !a.isEmpty { s.annots = a; s.buildRecords() }
            }
        }
    }

    func backToReader() {
        switchTo(.reading)
        layoutReaderChrome()
    }

    func chapterOfPara(_ pid: Int) -> LXCRToc? {
        var cur: LXCRToc?
        for t in toc { if t.pid <= pid { cur = t } else { break } }
        return cur
    }

    /// 分章节 · 章内按时间先后
    func buildRecords() {
        var list = annots
        if annotFilter == "butter" { list = list.filter { !$0.isClaude } }
        else if annotFilter == "claude" { list = list.filter { $0.isClaude } }
        var groups: [Int: (title: String, pid: Int, items: [LXCRAnnot])] = [:]
        for a in list {
            let ch = chapterOfPara(a.pid)
            let key = ch?.pid ?? 0
            if groups[key] == nil { groups[key] = (ch?.title ?? "正文", key, []) }
            groups[key]?.items.append(a)
        }
        recGroups = groups.values.sorted { $0.pid < $1.pid }.map { g in
            (g.title, g.pid, g.items.sorted { x, y in x.created != y.created ? x.created < y.created : x.id < y.id })
        }
        let hv = UIView(frame: CGRect(x: 0, y: 0, width: recTable.bounds.width, height: 12 + 12 + LXCRFont.f(9, 300).lineHeight + 8 + 12))
        buildFilter(hv)
        recTable.tableHeaderView = hv
        let empty = recGroups.isEmpty
        let fv = UIView(frame: CGRect(x: 0, y: 0, width: recTable.bounds.width, height: empty ? 0 : 80))
        if empty {
            var h: CGFloat = 0
            h = addEmptyTo(fv, "还没有人说话")
            fv.frame.size.height = h + 80
        }
        recTable.tableFooterView = fv
        recTable.reloadData()
    }

    private func addEmptyTo(_ host: UIView, _ s: String) -> CGFloat {
        addEmpty(s, y: 0, W: host.bounds.width) { host.addSubview($0) }
    }

    /// .overview-filter:全部 / 她 / 他,选中的反色
    private func buildFilter(_ hv: UIView) {
        let f = LXCRFont.f(9, 300)
        var x: CGFloat = 16
        let chips: [(String, String?)] = [("全部", nil), (meName, "butter"), (LXNick.yan, "claude")]
        for (label, val) in chips {
            let a = crAttr(label.uppercased(), f, annotFilter == val ? t.bg : t.ink3, kern: 1)
            let w = LXCRLine.width(a) + 16
            let b = LXCRPress(frame: CGRect(x: x, y: 12 + 12, width: w, height: 4 + f.lineHeight + 4))
            b.normalBg = annotFilter == val ? t.ink1 : .clear
            b.pressedBg = annotFilter == val ? t.ink1 : t.accentSoft
            b.layer.cornerRadius = 2
            let l = LXCRLine(frame: CGRect(x: 8, y: 4, width: w - 16 + 2, height: f.lineHeight))
            l.text = a
            l.baseline = f.ascender
            b.addSubview(l)
            b.addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                s.annotFilter = (val == s.annotFilter) ? nil : val
                s.buildRecords()
            }, for: .touchUpInside)
            hv.addSubview(b)
            x += w + 8
        }
    }

    func recordRows(_ section: Int) -> Int { section < recGroups.count ? recGroups[section].items.count : 0 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard tableView === recTable, section < recGroups.count else { return 0 }
        return 8 + 13 * 1.6 + 6 + 0.5
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard tableView === recTable, section < recGroups.count else { return 0 }
        return section == recGroups.count - 1 ? 22 : 22
    }

    /// .coread-chapter-title:吸在顶栏下面,13/600 ink3,底色同正文
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard tableView === recTable, section < recGroups.count else { return nil }
        let W = tableView.bounds.width
        let v = UIView(frame: CGRect(x: 0, y: 0, width: W, height: 8 + 13 * 1.6 + 6 + 0.5))
        let bgv = UIView(frame: CGRect(x: 16, y: 0, width: W - 32, height: v.bounds.height))
        bgv.backgroundColor = t.bg
        v.addSubview(bgv)
        let f = LXCRFont.f(13, 600)
        let l = LXCRLine(frame: CGRect(x: 16, y: 8, width: W - 32, height: 13 * 1.6))
        l.text = crAttr(recGroups[section].title, f, t.ink3)
        l.baseline = crBaseline(f, 13 * 1.6)
        v.addSubview(l)
        let hair = UIView(frame: CGRect(x: 16, y: v.bounds.height - 0.5, width: W - 32, height: 0.5))
        hair.backgroundColor = t.borderSoft
        v.addSubview(hair)
        return v
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        tableView === recTable ? UIView() : nil
    }

    private func recordBody(_ a: LXCRAnnot) -> (NSAttributedString, UIFont) {
        let f = LXCRFont.f(14.5)
        if a.type == "highlight" {
            let s = NSMutableAttributedString(attributedString: crAttr(a.text, f, t.ink2))
            s.addAttribute(.lxcrMark, value: LXCRMark(t.hlButter), range: NSRange(location: 0, length: s.length))
            return (s, f)
        }
        return (crAttr(cleanNote(a.text, nil), f, t.ink2), f)
    }

    func recordHeight(_ ip: IndexPath) -> CGFloat {
        guard ip.section < recGroups.count, ip.row < recGroups[ip.section].items.count else { return 0 }
        let a = recGroups[ip.section].items[ip.row]
        let W = recTable.bounds.width
        let (s, f) = recordBody(a)
        LXCoReadVC.recMeasure.set(s, font: f, lineHeight: 14.5 * 1.6)
        let bh = LXCoReadVC.recMeasure.height(for: W - 32 - 2 - 24)
        let metaH: CGFloat = a.type == "highlight" ? 9.5 * 1.6 + 4 : 10.5 * 1.6
        return 8 + 10 + metaH + 4 + bh + 10
    }
    static let recMeasure = LXCRText()

    func recordCell(_ ip: IndexPath) -> UITableViewCell {
        let c = recTable.dequeueReusableCell(withIdentifier: "r", for: ip) as! LXCRRecordCell
        guard ip.section < recGroups.count, ip.row < recGroups[ip.section].items.count else { return c }
        let a = recGroups[ip.section].items[ip.row]
        let W = recTable.bounds.width
        let h = recordHeight(ip)
        c.card.frame = CGRect(x: 16, y: 8, width: W - 32, height: h - 8)
        c.card.backgroundColor = t.surface
        c.bar.frame = CGRect(x: 0, y: 0, width: 2, height: h - 8)
        c.bar.backgroundColor = a.isClaude ? t.accent : t.jade
        let wf = LXCRFont.f(10.5), tf = LXCRFont.f(10), kf = LXCRFont.f(9.5)
        let metaH: CGFloat = a.type == "highlight" ? 9.5 * 1.6 + 4 : 10.5 * 1.6
        c.who.text = crAttr(a.isClaude ? LXNick.yan : meName, wf, a.isClaude ? t.accent : t.jade)
        c.who.frame = CGRect(x: 14, y: 10 + (metaH - 10.5 * 1.6) / 2, width: c.who.textWidth + 2, height: 10.5 * 1.6)
        c.who.baseline = crBaseline(wf, 10.5 * 1.6)
        c.when.text = crAttr(Self.fmtWhen(a.created), tf, t.ink4)
        c.when.frame = CGRect(x: c.who.frame.maxX - 2 + 8, y: 10 + (metaH - 16) / 2, width: c.when.textWidth + 2, height: 16)
        c.when.baseline = crBaseline(tf, 16)
        if a.type == "highlight" {
            c.kind.isHidden = false
            c.kindL.text = crAttr("划线", kf, t.ink4)
            c.kindL.baseline = crBaseline(kf, 9.5 * 1.6)
            let kw = c.kindL.textWidth + 10 + 2
            c.kind.frame = CGRect(x: c.when.frame.maxX - 2 + 8, y: 10, width: kw, height: 9.5 * 1.6 + 4)
            c.kind.layer.borderWidth = 1
            c.kind.layer.borderColor = t.borderSoft.cgColor
            c.kind.layer.cornerRadius = 3
            c.kindL.frame = CGRect(x: 6, y: 2, width: kw - 12 + 2, height: 9.5 * 1.6)
        } else {
            c.kind.isHidden = true
        }
        let (s, f) = recordBody(a)
        c.body.set(s, font: f, lineHeight: 14.5 * 1.6)
        c.body.frame = CGRect(x: 14, y: 10 + metaH + 4, width: W - 32 - 2 - 24, height: h - 8 - 10 - metaH - 4 - 10)
        return c
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard tableView === recTable, indexPath.section < recGroups.count, indexPath.row < recGroups[indexPath.section].items.count else { return }
        let a = recGroups[indexPath.section].items[indexPath.row]
        switchTo(.reading)
        layoutReaderChrome()
        jumpTo(a.pid, center: false)
    }

    func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        if tableView === recTable, let c = tableView.cellForRow(at: indexPath) as? LXCRRecordCell { c.card.backgroundColor = t.surface2 }
    }
    func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        if tableView === recTable, let c = tableView.cellForRow(at: indexPath) as? LXCRRecordCell { c.card.backgroundColor = t.surface }
    }

    /// 时间一律按北京算(她手机是美西时区);今天的只写"今天 HH:mm"
    static func fmtWhen(_ ts: String) -> String {
        guard !ts.isEmpty else { return "" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = iso.date(from: ts) ?? ISO8601DateFormatter().date(from: ts)
        guard let date = d else { return String(ts.prefix(16)) }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let c = cal.dateComponents([.month, .day, .hour, .minute], from: date)
        let hm = String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
        if cal.isDate(date, inSameDayAs: Date()) { return "今天 " + hm }
        return "\(c.month ?? 0)月\(c.day ?? 0)日 " + hm
    }

    /// 跳到某一段:先翻到它所在的页,再把它滚上来(目录/记录=顶上,搜索=正中)
    func jumpTo(_ pid: Int, center: Bool) {
        panels.hideToc()
        guard let id = book?.id else { return }
        LXCRAPI.call("GET", "/books/\(id)/page-for/\(pid)") { [weak self] obj, _ in
            guard let s = self, let page = ((obj as? [String: Any])?["page"] as? NSNumber)?.intValue else { return }
            s.goPage(page) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard let i = s.paras.firstIndex(where: { $0.id == pid }) else { return }
                    let r = s.table.rectForRow(at: IndexPath(row: i, section: 0))
                    let maxY = max(0, s.table.contentSize.height - s.table.bounds.height)
                    let y = center ? r.midY - s.table.bounds.height / 2 : r.minY
                    s.table.setContentOffset(CGPoint(x: 0, y: min(max(0, y), maxY)), animated: true)
                }
            }
        }
    }
}

// MARK: - 长按工具条 / 弹幕卡 / 划重点工具条

final class LXCRCards: NSObject, UITextViewDelegate {
    enum Mode { case menu, write, list }
    unowned let vc: LXCoReadVC
    private(set) var dmPid: Int?
    private(set) var mode: Mode = .menu
    private(set) var openedAt = Date.distantPast
    var isOpen: Bool { dmPid != nil }
    private var pinned = false
    private var kb: CGFloat = 0

    let card = UIView()
    private var input: UITextView?
    private var inputPh: UILabel?
    let selBar = UIView()
    private(set) var selBarOpen = false
    private var selTV: UITextView?

    init(vc: LXCoReadVC) {
        self.vc = vc
        super.init()
        card.layer.cornerCurve = .circular
        NotificationCenter.default.addObserver(self, selector: #selector(kbChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(kbChange(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        buildSelBar()
    }

    func owns(_ v: UIView) -> Bool { v.isDescendant(of: card) || v.isDescendant(of: selBar) }
    private var t: LXCRTheme { vc.t }

    func applyTheme() {
        buildSelBar()
        if let pid = dmPid { let m = mode; close(); open(pid, mode: m) }
    }

    // MARK: 开 / 关

    func open(_ pid: Int, mode m: Mode) {
        let wasPid = dmPid
        dmPid = pid
        mode = m
        openedAt = Date()
        card.subviews.forEach { $0.removeFromSuperview() }
        card.layer.sublayers?.filter { $0 is CAShapeLayer }.forEach { $0.removeFromSuperlayer() }
        input = nil; inputPh = nil
        pinned = false
        if m == .menu { buildMenu() } else { buildWrite() }
        vc.table.addSubview(card)
        crShadow(card.layer, y: m == .menu ? 8 : 10, blur: m == .menu ? 26 : 30, a: m == .menu ? 0.32 : 0.16)
        place()
        refreshActive(old: wasPid)
        // dmIn:0.16s 从上 4px 淡入
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: -4)
        crAnimate(0.16) { self.card.alpha = 1; self.card.transform = .identity }
        if m == .write {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.input?.becomeFirstResponder() }
        } else if m == .list {
            input?.resignFirstResponder()
        }
    }

    func close() {
        guard let pid = dmPid else { return }
        input?.resignFirstResponder()
        dmPid = nil
        pinned = false
        card.removeFromSuperview()
        card.transform = .identity
        refreshActive(old: pid)
    }

    /// 正在评的那一段点亮(.dm-active 底色 hl-butter,圆角 6)——只改颜色,不重排
    private func refreshActive(old: Int?) {
        for pid in [old, dmPid].compactMap({ $0 }) {
            guard let c = vc.cell(for: pid) else { continue }
            let active = dmPid == pid
            UIView.animate(withDuration: 0.18) {
                c.box.backgroundColor = active ? self.t.hlButter : (self.vc.selectPid == pid ? self.t.accentSoft : .clear)
            }
            c.box.layer.cornerRadius = active ? 6 : 4
        }
    }

    /// 段落挪了(缝页/补批注)以后,卡片跟着段落走
    func reposition() {
        guard isOpen, !pinned else { return }
        place()
        refreshActive(old: nil)
    }

    private func place() {
        guard let pid = dmPid, let r = vc.paraRect(pid) else { return }
        let W = vc.table.bounds.width
        if mode == .menu {
            // 浮在这段上方;顶上不够(离视口顶 < 10)就翻到下面。横向对准段落起点 +12,别越界
            let h = card.bounds.height, cw = card.bounds.width
            let vTop = r.minY - vc.table.contentOffset.y
            let top = vTop - h - 8 < 10 ? r.maxY + 8 : r.minY - h - 8
            let left = max(12, min(r.minX + 12, W - cw - 12))
            card.frame.origin = CGPoint(x: left, y: top)
        } else {
            card.frame = CGRect(x: 16, y: r.maxY + 6, width: W - 32, height: card.bounds.height)
        }
    }

    // MARK: 第一步:深色小工具条(弹幕 / 复制 / 戳一戳)

    private func buildMenu() {
        let tf = LXCRFont.f(11), icf = LXCRFont.f(13)
        let fg = crHex(0xf2f4f5)
        let items: [(String, String, () -> Void)] = [
            ("弹", "弹幕", { [weak self] in guard let s = self, let p = s.dmPid else { return }; s.open(p, mode: .write) }),
            ("\u{29C9}", "复制", { [weak self] in self?.copyPara() }),
            ("\u{1F449}", "戳一戳", { [weak self] in self?.poke() }),
        ]
        let itemH = 4 + 24 + 5 + tf.lineHeight + 4
        var x: CGFloat = 6
        for (i, it) in items.enumerated() {
            let label = crAttr(it.1, tf, fg)
            let w = max(62, 10 + max(24, LXCRLine.width(label)) + 10)
            let b = LXCRPress(frame: CGRect(x: x, y: 8, width: w, height: itemH))
            b.pressedAlpha = 0.6
            if i > 0 {
                let sep = UIView(frame: CGRect(x: 0, y: 0, width: 0.5, height: itemH))
                sep.backgroundColor = UIColor(white: 1, alpha: 0.14)
                b.addSubview(sep)
            }
            let ic = UIView(frame: CGRect(x: (w - 24) / 2, y: 4, width: 24, height: 24))
            ic.layer.borderWidth = 1
            ic.layer.borderColor = UIColor(white: 1, alpha: 0.55).cgColor
            ic.layer.cornerRadius = 4
            ic.isUserInteractionEnabled = false
            let gl = LXCRLine(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
            gl.text = crAttr(it.0, icf, fg)
            gl.align = .center
            gl.baseline = (22 - 13) / 2 + crBaseline(icf, 13) + 1
            ic.addSubview(gl)
            b.addSubview(ic)
            let l = LXCRLine(frame: CGRect(x: 0, y: 4 + 24 + 5, width: w, height: tf.lineHeight))
            l.text = label
            l.align = .center
            l.baseline = tf.ascender
            b.addSubview(l)
            b.addAction(UIAction { _ in it.2() }, for: .touchUpInside)
            card.addSubview(b)
            x += w + 2
        }
        let cw = x - 2 + 6
        card.bounds = CGRect(x: 0, y: 0, width: min(cw, vc.table.bounds.width - 32), height: 8 + itemH + 8)
        card.backgroundColor = crHex(0x2f3335)
        card.layer.cornerRadius = 12
        card.layer.borderWidth = 0
        crShadow(card.layer, y: 8, blur: 26, a: 0.32)
    }

    // MARK: 第二步:弹幕卡(这段所有的话 + 输入框 + 划重点/书签/收起)

    private func buildWrite() {
        guard let pid = dmPid else { return }
        // 挂在段下:左右各 16;钉在键盘上:左右各 12
        let cw = pinned ? vc.view.bounds.width - 24 : vc.table.bounds.width - 32
        let inner = cw - 2 - 24
        card.backgroundColor = t.surface
        card.layer.cornerRadius = 10
        card.layer.borderWidth = 1
        card.layer.borderColor = t.border.cgColor
        crShadow(card.layer, y: 10, blur: 30, a: 0.16)
        var y: CGFloat = 1 + 10
        let notes = vc.annots.filter { $0.pid == pid && $0.type == "note" }
        if !notes.isEmpty {
            let list = UIScrollView()
            list.showsVerticalScrollIndicator = true
            var ly: CGFloat = 0
            let wf = LXCRFont.f(10.5), xf = LXCRFont.f(13.5)
            for (i, n) in notes.enumerated() {
                let mine = !n.isClaude
                let who = crAttr(mine ? "我" : LXNick.yan, wf, mine ? t.jade : t.accent)
                let chipW = LXCRLine.width(who) + 10
                let chipH = 10.5 * 1.55 + 2
                let chip = UIView(frame: CGRect(x: 0, y: ly + 5, width: chipW, height: chipH))
                chip.backgroundColor = mine ? t.jadeSoft : t.accentSoft
                chip.layer.cornerRadius = 3
                let cl = LXCRLine(frame: CGRect(x: 5, y: 1, width: chipW - 10 + 2, height: 10.5 * 1.55))
                cl.text = who
                cl.baseline = crBaseline(wf, 10.5 * 1.55)
                chip.addSubview(cl)
                list.addSubview(chip)
                let tx = LXCRText()
                tx.set(crAttr(n.text, xf, t.ink2), font: xf, lineHeight: 13.5 * 1.55)
                let tw = inner - chipW - 7 - 7 - 20
                let th = tx.height(for: tw)
                tx.frame = CGRect(x: chipW + 7, y: ly + 5, width: tw, height: th)
                list.addSubview(tx)
                let del = UIButton(type: .custom)
                del.frame = CGRect(x: inner - 20, y: ly + 5, width: 20, height: 20)
                del.setImage(crIcon(["M4 4l8 8M12 4l-8 8"], size: 14, stroke: 1.2, color: t.ink4), for: .normal)
                del.addAction(UIAction { [weak self] _ in self?.deleteNote(n.id) }, for: .touchUpInside)
                list.addSubview(del)
                ly += 5 + max(chipH, th, 20) + 5
                if i < notes.count - 1 {
                    let hair = UIView(frame: CGRect(x: 0, y: ly, width: inner, height: 0.5))
                    hair.backgroundColor = t.borderSoft
                    list.addSubview(hair)
                    ly += 0.5
                }
            }
            let maxH = vc.frameH * 0.34
            list.frame = CGRect(x: 13, y: y, width: inner, height: min(ly, maxH))
            list.contentSize = CGSize(width: inner, height: ly)
            list.indicatorStyle = t.dark ? .white : .black
            card.addSubview(list)
            y += list.bounds.height + 8
        }
        // .dm-compose:输入框(一行高 40)+ 发送(34 高,底对齐)
        let sf = LXCRFont.f(14)
        let sendLabel = crAttr("发送", sf, .white)
        let sendW = 14 + LXCRLine.width(sendLabel) + 14
        let inH: CGFloat = 16 * 1.4 + 16 + 2
        // 发完一条/钉到键盘上重排时,输入框还用原来那个(焦点和键盘都不动)
        let tv: UITextView
        if let old = input {
            tv = old
        } else {
            let n = LXCRInput()
            n.setup(t)
            n.delegate = self
            card.addSubview(n)
            let ph = UILabel()
            ph.text = "说点什么…"
            ph.font = LXCRFont.f(16)
            ph.textColor = UIColor(white: 169 / 255, alpha: 1)
            ph.isUserInteractionEnabled = false
            n.addSubview(ph)
            inputPh = ph
            input = n
            tv = n
        }
        tv.frame = CGRect(x: 13, y: y, width: inner - 8 - sendW, height: inH)
        if let ph = inputPh {
            ph.frame = CGRect(x: 11, y: 9 + (22.4 - ph.font.lineHeight) / 2, width: tv.bounds.width - 20, height: ph.font.lineHeight)
        }
        let send = LXCRPress(frame: CGRect(x: 13 + inner - sendW, y: y + inH - 34, width: sendW, height: 34))
        send.normalBg = t.accent
        send.pressedBg = t.accentDeep
        send.layer.cornerRadius = 8
        let sl = LXCRLine(frame: send.bounds)
        sl.text = sendLabel
        sl.align = .center
        sl.baseline = (34 - sf.lineHeight) / 2 + sf.ascender
        send.addSubview(sl)
        send.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)
        card.addSubview(send)
        y += inH + 7
        // .dm-foot:11px ink3,收起靠右
        let ff = LXCRFont.f(11)
        let fh = 3 + ff.lineHeight + 3
        var fx: CGFloat = 13
        let tools: [(String, () -> Void)] = [
            ("划重点", { [weak self] in self?.markMode() }),
            (vc.bookmark == pid ? "取消书签" : "加书签", { [weak self] in self?.toggleBookmark() }),
        ]
        for (label, act) in tools {
            let b = footButton(label, ff, x: fx, y: y, h: fh, act)
            card.addSubview(b)
            fx += b.bounds.width + 14
        }
        let closeB = footButton("收起", ff, x: 0, y: y, h: fh) { [weak self] in self?.close() }
        closeB.frame.origin.x = 13 + inner - closeB.bounds.width
        card.addSubview(closeB)
        y += fh + 8 + 1
        card.bounds = CGRect(x: 0, y: 0, width: cw, height: y)
    }

    private func footButton(_ s: String, _ f: UIFont, x: CGFloat, y: CGFloat, h: CGFloat, _ act: @escaping () -> Void) -> UIView {
        let a = crAttr(s, f, t.ink3)
        let w = LXCRLine.width(a)
        let b = LXCRPress(frame: CGRect(x: x, y: y, width: w, height: h))
        let l = LXCRLine(frame: CGRect(x: 0, y: 3, width: w + 2, height: f.lineHeight))
        l.text = a
        l.baseline = f.ascender
        b.addSubview(l)
        b.addTarget(self, action: #selector(footDown(_:)), for: [.touchDown, .touchDragEnter])
        b.addTarget(self, action: #selector(footUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        b.addAction(UIAction { _ in act() }, for: .touchUpInside)
        return b
    }
    @objc private func footDown(_ b: UIView) { recolor(b, t.accent) }
    @objc private func footUp(_ b: UIView) { recolor(b, t.ink3) }
    private func recolor(_ b: UIView, _ c: UIColor) {
        guard let l = b.subviews.first as? LXCRLine, let m = l.text.mutableCopy() as? NSMutableAttributedString else { return }
        m.addAttribute(.foregroundColor, value: c, range: NSRange(location: 0, length: m.length))
        l.text = m
    }

    func textViewDidChange(_ textView: UITextView) {
        inputPh?.isHidden = !textView.text.isEmpty
    }
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let cur = textView.text as NSString? ?? ""
        return cur.length - range.length + (text as NSString).length <= 800      // maxlength 800
    }
    func textViewDidBeginEditing(_ textView: UITextView) { textView.layer.borderColor = t.accent.cgColor }
    func textViewDidEndEditing(_ textView: UITextView) { textView.layer.borderColor = t.border.cgColor }

    private func submit() {
        guard let pid = dmPid, let id = vc.book?.id, let tv = input else { return }
        let text = tv.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        tv.text = ""
        textViewDidChange(tv)
        LXCRAPI.call("POST", "/books/\(id)/annotations", ["paragraph_id": pid, "type": "note", "text": text]) { [weak self] obj, _ in
            guard let s = self, let d = obj as? [String: Any], let a = LXCRAnnot(d) else { return }
            s.vc.annots.append(a)
            s.vc.noteMe([a])
            s.vc.refreshParas([pid])
            if s.dmPid == pid { s.rebuild() }
        }
    }

    private func deleteNote(_ aid: String) {
        guard let pid = dmPid, let id = vc.book?.id else { return }
        LXCRAPI.call("DELETE", "/books/\(id)/annotations/\(aid)") { [weak self] _, _ in
            guard let s = self else { return }
            s.vc.annots.removeAll { $0.id == aid }
            s.vc.refreshParas([pid])
            if s.dmPid == pid { s.rebuild() }
        }
    }

    /// 发完一条/删一条/钉上键盘:只把卡片里的内容换掉,输入框原样留着(焦点和键盘不动)
    private func rebuild() {
        guard isOpen, mode != .menu else { return }
        let keep = input
        card.subviews.forEach { if $0 !== keep { $0.removeFromSuperview() } }
        buildWrite()
        if pinned { pinFrame() } else { place() }
    }

    private func copyPara() {
        guard let pid = dmPid else { return }
        let txt = vc.paraTextOf(pid)
        guard !txt.isEmpty else { return }
        UIPasteboard.general.string = txt
        vc.toast("已复制")
        close()
    }

    /// 戳一戳:把这一段递到他那条线上。是她按的按钮,内容署她的名
    private func poke() {
        guard let pid = dmPid else { return }
        let txt = vc.paraTextOf(pid)
        guard !txt.isEmpty else { return }
        let ns = txt as NSString
        let snippet = ns.length > 220 ? ns.substring(to: 220) + "…" : txt
        let title = vc.book?.title ?? ""
        let msg = "【共读·戳一戳】" + (title.isEmpty ? "" : "《\(title)》") + "\n" + snippet + "\n\n——我在这段戳了你一下。"
        vc.toast("戳过去了")
        LXCRAPI.poke(msg) { [weak self] code in
            if !(200..<300).contains(code) { self?.vc.toast(code > 0 ? "戳一戳没发出去(\(code))" : "戳一戳没发出去") }
        }
        close()
    }

    private func toggleBookmark() {
        guard let pid = dmPid else { return }
        vc.toggleBookmark(pid)
        close()
    }

    /// 划重点:这一段临时打开选字,选完出高亮工具条
    private func markMode() {
        guard let pid = dmPid else { return }
        let old = vc.selectPid
        vc.selectPid = pid
        close()
        var s: Set<Int> = [pid]
        if let o = old { s.insert(o) }
        vc.refreshParas(s)
        vc.toast("选中要划的字")
    }

    // MARK: 键盘:输入卡钉在键盘正上方,再把那一段滚到卡片上面

    @objc private func kbChange(_ n: Notification) {
        guard let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let local = vc.view.convert(end, from: nil)
        kb = n.name == UIResponder.keyboardWillHideNotification ? 0 : max(0, vc.view.bounds.maxY - local.minY)
        guard isOpen, mode != .menu, vc.presentingViewController != nil else { return }
        if kb > 0 { pin() } else { unpin() }
    }

    private func pin() {
        guard let pid = dmPid else { return }
        if !pinned {
            pinned = true
            vc.view.addSubview(card)
            crShadow(card.layer, y: -8, blur: 28, a: 0.20)
            rebuild()
        } else {
            pinFrame()
        }
        guard let r = vc.paraRect(pid) else { return }
        let cardTop = card.frame.minY - vc.safeTop
        let top = r.minY - vc.table.contentOffset.y, bot = r.maxY - vc.table.contentOffset.y
        let pad: CGFloat = 8
        var delta: CGFloat = 0
        if bot > cardTop - pad { delta = bot - (cardTop - pad) }
        if top - delta < pad { delta = top - pad }
        if abs(delta) > 1 {
            let maxY = max(0, vc.table.contentSize.height - vc.table.bounds.height)
            let y = min(max(0, vc.table.contentOffset.y + delta), maxY)
            vc.table.setContentOffset(CGPoint(x: 0, y: y), animated: true)
        }
    }

    private func pinFrame() {
        let W = vc.view.bounds.width
        card.frame = CGRect(x: 12, y: vc.view.bounds.height - kb - card.bounds.height, width: W - 24, height: card.bounds.height)
    }

    private func unpin() {
        guard pinned else { return }
        pinned = false
        vc.table.addSubview(card)
        crShadow(card.layer, y: 10, blur: 30, a: 0.16)
        rebuild()
    }

    // MARK: 划重点后的选字工具条(高亮 / 生词 / 复制)

    private var hlBtn = UIButton(type: .custom)
    private func buildSelBar() {
        selBar.subviews.forEach { $0.removeFromSuperview() }
        selBar.backgroundColor = t.surface
        selBar.layer.cornerRadius = 4
        selBar.layer.borderWidth = 0.5
        selBar.layer.borderColor = t.borderStrong.cgColor
        crShadow(selBar.layer, y: 4, blur: 16, a: 0.12)
        var x: CGFloat = 4.5
        func btn(_ w: CGFloat, _ img: UIImage, _ act: @escaping () -> Void) {
            let b = UIButton(type: .custom)
            b.frame = CGRect(x: x, y: 4.5, width: w, height: 32)
            b.setImage(img, for: .normal)
            b.layer.cornerRadius = 2
            b.addAction(UIAction { _ in act() }, for: .touchUpInside)
            selBar.addSubview(b)
            x += w + 2
        }
        btn(36, crIcon(["M2 13h12M4.5 10L8 3l3.5 7", "M5.5 8h5"], size: 16, stroke: 1.2, color: t.ink2)) { [weak self] in self?.selHighlight() }
        let sep = UIView(frame: CGRect(x: x + 2, y: 4.5 + 6, width: 1, height: 20))
        sep.backgroundColor = t.border
        selBar.addSubview(sep)
        x += 5 + 2
        btn(32, crIcon(["M5 5h6M5 8h4M5 11h5"], size: 16, stroke: 1, color: t.ink2, extra: { c in
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 2, y: 2, width: 12, height: 12), cornerRadius: 1.5).cgPath); c.strokePath()
        })) { [weak self] in self?.selVocab() }
        btn(32, crIcon(["M3 11V3h8"], size: 16, stroke: 1, color: t.ink2, extra: { c in
            c.addPath(UIBezierPath(roundedRect: CGRect(x: 5, y: 5, width: 8, height: 8), cornerRadius: 1).cgPath); c.strokePath()
        })) { [weak self] in self?.selCopy() }
        selBar.bounds = CGRect(x: 0, y: 0, width: x - 2 + 4.5, height: 41)
    }

    func selectionChanged(_ tv: UITextView) {
        selTV = tv
        let r = tv.selectedRange
        let text = r.length > 0 ? (tv.text as NSString).substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard !text.isEmpty, let range = tv.selectedTextRange else { hideSelBar(); return }
        let rects = tv.selectionRects(for: range).map { $0.rect }.filter { !$0.isEmpty }
        guard var u = rects.first else { hideSelBar(); return }
        for x in rects.dropFirst() { u = u.union(x) }
        let rect = tv.convert(u, to: vc.table)
        // 网页按 220 宽、40 高去摆(比真实宽度宽),所以条子会偏左一点——照原样
        let W = vc.table.bounds.width
        var left = rect.midX - 110
        left = max(8, min(left, W - 220 - 8))
        var top = rect.minY - 40 - 8
        if top < vc.table.contentOffset.y + 8 { top = rect.maxY + 8 }
        if selBar.superview !== vc.table { vc.table.addSubview(selBar) }
        selBar.frame.origin = CGPoint(x: left, y: top)
        if !selBarOpen {
            selBarOpen = true
            selBar.alpha = 0
            selBar.transform = CGAffineTransform(translationX: 0, y: 4)
            crAnimate(0.2) { self.selBar.alpha = 1; self.selBar.transform = .identity }
        }
    }

    func hideSelBar() {
        guard selBarOpen else { return }
        selBarOpen = false
        crAnimate(0.2, { self.selBar.alpha = 0; self.selBar.transform = CGAffineTransform(translationX: 0, y: 4) }) {
            if !self.selBarOpen { self.selBar.removeFromSuperview() }
        }
    }

    func clearSelection() {
        if let tv = selTV { tv.selectedRange = NSRange(location: 0, length: 0) }
        hideSelBar()
    }

    private func selected() -> (text: String, pid: Int)? {
        guard let tv = selTV, let pid = vc.selectPid else { return nil }
        let r = tv.selectedRange
        guard r.length > 0 else { return nil }
        let s = (tv.text as NSString).substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : (s, pid)
    }

    private func selHighlight() {
        guard let (text, pid) = selected() else { return }
        clearSelection()
        vc.toggleHighlight(pid, text)
    }

    private func selVocab() {
        guard let (text, pid) = selected() else { return }
        clearSelection()
        vc.panels.prompt("Note for \"\(text)\":", value: "") { [weak self] note in
            guard let s = self, let id = s.vc.book?.id else { return }
            LXCRAPI.call("POST", "/books/\(id)/vocab", ["word": text, "paragraph_id": pid, "note": note]) { obj, _ in
                guard obj != nil else { return }
                s.vc.vocab.append((text, pid))
                s.vc.refreshParas([pid])
            }
        }
    }

    private func selCopy() {
        guard let (text, _) = selected() else { return }
        UIPasteboard.general.string = text
        clearSelection()
    }
}

/// 弹幕输入框(.dm-input):16px、行高 1.4、内边距 8/10、1px 边、圆角 8,底色同正文
final class LXCRInput: UITextView {
    init() {
        let ts = NSTextStorage()
        let lm = LXCRLayout()
        let tc = NSTextContainer(size: CGSize(width: 100, height: CGFloat.greatestFiniteMagnitude))
        tc.lineFragmentPadding = 0
        tc.widthTracksTextView = true
        lm.addTextContainer(tc)
        ts.addLayoutManager(lm)
        storageRef = ts
        super.init(frame: .zero, textContainer: tc)
        let f = LXCRFont.f(16)
        lm.set(f, lineHeight: 16 * 1.4)
        font = f
        textContainerInset = UIEdgeInsets(top: 8 + 1, left: 10 + 1, bottom: 8 + 1, right: 10 + 1)
    }
    private let storageRef: NSTextStorage
    required init?(coder: NSCoder) { fatalError() }

    func setup(_ t: LXCRTheme) {
        backgroundColor = t.bg
        textColor = t.ink1
        tintColor = t.accent
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = t.border.cgColor
        keyboardAppearance = t.dark ? .dark : .light
        typingAttributes = [.font: LXCRFont.f(16), .foregroundColor: t.ink1]
    }
}

extension LXCoReadVC {
    func toggleBookmark(_ pid: Int) {
        guard let id = book?.id else { return }
        LXCRAPI.call("POST", "/books/\(id)/bookmarks", ["paragraph_id": pid]) { [weak self] obj, _ in
            guard let s = self, let d = obj as? [String: Any] else { return }
            let old = s.bookmark
            s.bookmark = (d["action"] as? String) == "set" ? pid : nil
            var ch: Set<Int> = [pid]
            if let o = old { ch.insert(o) }
            s.refreshParas(ch)
        }
    }

    func toggleHighlight(_ pid: Int, _ text: String) {
        guard let id = book?.id else { return }
        if let ex = annots.first(where: { $0.type == "highlight" && $0.text == text && $0.pid == pid && !$0.isClaude }) {
            LXCRAPI.call("DELETE", "/books/\(id)/annotations/\(ex.id)") { [weak self] _, _ in
                self?.annots.removeAll { $0.id == ex.id || $0.highlightId == ex.id }
                self?.refreshParas([pid])
            }
        } else {
            LXCRAPI.call("POST", "/books/\(id)/annotations", ["paragraph_id": pid, "type": "highlight", "text": text]) { [weak self] obj, _ in
                guard let s = self, let d = obj as? [String: Any], let a = LXCRAnnot(d) else { return }
                s.annots.append(a)
                s.refreshParas([pid])
            }
        }
    }
}

// MARK: - 面板:设置 / 目录 / 划线批注 / 搜索 / 对话框

final class LXCRPanels: NSObject, UITextFieldDelegate {
    unowned let vc: LXCoReadVC
    private var t: LXCRTheme { vc.t }

    let settings = UIView()
    private(set) var settingsOpen = false
    let tocScrim = UIControl()
    let tocPanel = UIView()
    private let tocList = UIScrollView()
    private(set) var tocOpen = false
    let annotBackdrop = UIControl()
    let annotPanel = UIScrollView()
    private var annotPid = 0
    private var annotHl: String?
    private(set) var annotOpen = false
    let search = UIView()
    private let searchField = UITextField()
    private let searchInfo = LXCRLine()
    private let searchResults = UIScrollView()
    private(set) var searchOpen = false
    private var searchWork: DispatchWorkItem?
    private var dialog: UIView?
    private var dialogField: UITextField?

    init(vc: LXCoReadVC) {
        self.vc = vc
        super.init()
        tocScrim.backgroundColor = UIColor(white: 0, alpha: 0.22)
        tocScrim.addAction(UIAction { [weak self] _ in self?.hideToc() }, for: .touchUpInside)
        annotBackdrop.backgroundColor = UIColor(white: 0, alpha: 0.25)
        annotBackdrop.addAction(UIAction { [weak self] _ in self?.closeAnnot() }, for: .touchUpInside)
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.autocorrectionType = .no
        searchField.spellCheckingType = .no
        searchField.autocapitalizationType = .none
        searchField.returnKeyType = .search
    }

    func applyTheme() {
        if settingsOpen { renderSettings() }
        if tocOpen { renderToc() }
        if annotOpen { renderAnnot() }
        if searchOpen { styleSearch() }
    }

    func layout() {
        if settingsOpen { renderSettings() }
        if tocOpen { tocScrim.frame = vc.view.bounds }
        if annotOpen { annotBackdrop.frame = vc.view.bounds }
    }

    func closeAll() {
        hideSettings()
        if tocOpen { hideToc() }
        if annotOpen { closeAnnot() }
        if searchOpen { closeSearch() }
    }

    // MARK: 设置(.read-settings):左右 12、离底 安全区+96、内边距 14/16、圆角 14

    func toggleSettings() {
        if settingsOpen { hideSettings(); return }
        hideToc()
        settingsOpen = true
        renderSettings()
        vc.readerWrap.addSubview(settings)
    }

    func hideSettings() {
        guard settingsOpen else { return }
        settingsOpen = false
        settings.removeFromSuperview()
    }

    private static let lhPresets: [CGFloat] = [1.5, 1.9, 2.2, 2.6]

    private func renderSettings() {
        settings.subviews.forEach { $0.removeFromSuperview() }
        let W = vc.readerWrap.bounds.width, H = vc.readerWrap.bounds.height
        let pw = W - 24
        settings.backgroundColor = t.surface
        settings.layer.cornerRadius = 14
        settings.layer.borderWidth = 1
        settings.layer.borderColor = t.border.cgColor
        crShadow(settings.layer, y: 14, blur: 40, a: 0.20)
        let lf = LXCRFont.f(12)
        let x0: CGFloat = 1 + 16, inner = pw - 2 - 32
        var y: CGFloat = 1 + 14
        func rowLabel(_ s: String, _ h: CGFloat) {
            let l = LXCRLine(frame: CGRect(x: x0, y: y + 9 + (h - 12 * 1.6) / 2, width: 30, height: 12 * 1.6))
            l.text = crAttr(s, lf, t.ink3)
            l.baseline = crBaseline(lf, 12 * 1.6)
            settings.addSubview(l)
        }
        // 字号:粗轨道滑杆(30 高、圆角 15)+ 右边数字
        rowLabel("字号", 30)
        let vf = LXCRFont.f(11)
        let valW: CGFloat = 26
        let sl = LXCRFontSlider(frame: CGRect(x: x0 + 30 + 12, y: y + 9, width: inner - 30 - 12 - 12 - valW, height: 30))
        sl.configure(t)
        sl.minimumValue = 13
        sl.maximumValue = 26
        sl.value = Float(vc.fs)
        let val = LXCRLine(frame: CGRect(x: x0 + inner - valW, y: y + 9 + (30 - 11 * 1.6) / 2, width: valW, height: 11 * 1.6))
        val.text = crAttr("\(Int(vc.fs))", vf, t.ink4)
        val.baseline = crBaseline(vf, 11 * 1.6)
        val.align = .right
        sl.addAction(UIAction { [weak self, weak sl, weak val] _ in
            guard let s = self, let sl = sl else { return }
            let v = CGFloat(sl.value.rounded())
            sl.value = Float(v)
            guard v != s.vc.fs else { return }
            s.vc.fs = v
            LXCRPrefs.fontSize = v
            val?.text = crAttr("\(Int(v))", vf, s.t.ink4)
            s.vc.refreshParas()
        }, for: .valueChanged)
        settings.addSubview(sl)
        settings.addSubview(val)
        y += 9 + 30 + 9
        // 间距:四档,图标是四道横线、间隔 1/2.5/4/5.5
        rowLabel("间距", 34)
        let segX = x0 + 30 + 12, segW = (inner - 30 - 12 - 8 * 3) / 4
        for (i, v) in Self.lhPresets.enumerated() {
            let on = abs(vc.lh - v) < 0.05
            let b = LXCRPress(frame: CGRect(x: segX + CGFloat(i) * (segW + 8), y: y + 9, width: segW, height: 34))
            b.normalBg = on ? t.surface : t.surface2
            b.layer.cornerRadius = 9
            b.layer.borderWidth = 1
            b.layer.borderColor = on ? t.ink3.cgColor : UIColor.clear.cgColor
            let gap: CGFloat = [1, 2.5, 4, 5.5][i]
            let total = 4 * 1.5 + 3 * gap
            var ly = (34 - total) / 2
            for _ in 0..<4 {
                let line = UIView(frame: CGRect(x: (segW - 16) / 2, y: ly, width: 16, height: 1.5))
                line.backgroundColor = t.ink3
                line.layer.cornerRadius = 0.75
                line.isUserInteractionEnabled = false
                b.addSubview(line)
                ly += 1.5 + gap
            }
            b.addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                s.vc.lh = v
                LXCRPrefs.lineHeight = v
                s.vc.refreshParas()
                s.renderSettings()
            }, for: .touchUpInside)
            settings.addSubview(b)
        }
        y += 9 + 34 + 9
        // 背景:一排色圆点 28px,选中的外面一圈 2px accent
        let dotsX = x0 + 30 + 12, dotsW = inner - 30 - 12
        var dx: CGFloat = 0, dy: CGFloat = 0
        var rows: CGFloat = 1
        var dotFrames: [CGRect] = []
        for _ in LXCRTheme.all {
            if dx > 0 && dx + 28 > dotsW { dx = 0; dy += 28 + 12; rows += 1 }
            dotFrames.append(CGRect(x: dotsX + dx, y: dy, width: 28, height: 28))
            dx += 28 + 13
        }
        let dotsH = rows * 28 + (rows - 1) * 12
        rowLabel("背景", dotsH)
        for (i, th) in LXCRTheme.all.enumerated() {
            var f = dotFrames[i]
            f.origin.y += y + 9
            let on = vc.t.id == th.id
            let d = UIButton(type: .custom)
            d.frame = f
            d.layer.cornerRadius = 14
            d.layer.borderWidth = on ? 0 : 1
            d.layer.borderColor = t.border.cgColor
            d.clipsToBounds = false
            let fill = UIView(frame: d.bounds)
            fill.layer.cornerRadius = 14
            fill.clipsToBounds = true
            fill.isUserInteractionEnabled = false
            let sw = LXCRTheme.of(th.id)
            if th.id == "moon" {
                let g = CAGradientLayer()
                g.type = .radial
                g.frame = fill.bounds
                g.colors = [crHex(0xeaf6ff).cgColor, crHex(0x9fd8f2).cgColor, crHex(0x3f7f9e).cgColor, crHex(0x05070c).cgColor]
                g.locations = [0, 0.18, 0.48, 1]
                g.startPoint = CGPoint(x: 0.5, y: 0.64)
                g.endPoint = CGPoint(x: 0.5 + 28.56 / 28, y: 0.64 + 20.56 / 28)
                fill.layer.addSublayer(g)
            } else {
                fill.backgroundColor = sw.bg
            }
            d.addSubview(fill)
            if on {
                let ring = CAShapeLayer()
                ring.path = UIBezierPath(ovalIn: d.bounds.insetBy(dx: -1, dy: -1)).cgPath
                ring.fillColor = UIColor.clear.cgColor
                ring.strokeColor = t.accent.cgColor
                ring.lineWidth = 2
                d.layer.addSublayer(ring)
            }
            d.accessibilityLabel = th.label
            d.addAction(UIAction { [weak self] _ in self?.vc.setTheme(th.id) }, for: .touchUpInside)
            settings.addSubview(d)
        }
        y += 9 + dotsH + 9
        let ph = y + 14 + 1
        settings.frame = CGRect(x: 12, y: H - (vc.safeBottom + 96) - ph, width: pw, height: ph)
    }

    // MARK: 目录(.toc-panel):从屏幕底升起盖住底栏,最高 70%,圆角 18;标题固定,只有列表滚

    func toggleToc() {
        if tocOpen { hideToc(); return }
        hideSettings()
        tocOpen = true
        tocScrim.frame = vc.view.bounds
        vc.view.addSubview(tocScrim)
        vc.view.addSubview(tocPanel)
        renderToc()
        tocScrim.alpha = 0
        let h = tocPanel.bounds.height
        tocPanel.transform = CGAffineTransform(translationX: 0, y: h)
        tocPanel.alpha = 0
        crAnimate(0.22) { self.tocScrim.alpha = 1 }
        crAnimate(0.28) { self.tocPanel.transform = .identity }
        crAnimate(0.2) { self.tocPanel.alpha = 1 }
        vc.view.bringSubviewToFront(vc.handle)
    }

    func hideToc() {
        guard tocOpen else { return }
        tocOpen = false
        let p = tocPanel, s = tocScrim
        crAnimate(0.22, { s.alpha = 0 }) { if !self.tocOpen { s.removeFromSuperview() } }
        crAnimate(0.2) { p.alpha = 0 }
        crAnimate(0.28, { p.transform = CGAffineTransform(translationX: 0, y: p.bounds.height) }) {
            if !self.tocOpen { p.removeFromSuperview(); p.transform = .identity }
        }
    }

    private func renderToc() {
        tocPanel.subviews.forEach { $0.removeFromSuperview() }
        tocList.subviews.forEach { $0.removeFromSuperview() }
        let W = vc.view.bounds.width, H = vc.view.bounds.height
        tocPanel.backgroundColor = t.surface
        tocPanel.layer.cornerRadius = 18
        tocPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        crShadow(tocPanel.layer, y: -14, blur: 40, a: 0.22)
        // 头:15/600"目录" + 30px 圆形关闭钮,底下 0.5px 线
        let tf = LXCRFont.f(15, 600)
        let headH: CGFloat = 14 + 30 + 10
        let title = LXCRLine(frame: CGRect(x: 18, y: 14 + (30 - 24) / 2, width: 100, height: 24))
        title.text = crAttr("目录", tf, t.ink1)
        title.baseline = crBaseline(tf, 24)
        tocPanel.addSubview(title)
        let close = LXCRPress(frame: CGRect(x: W - 18 - 30, y: 14, width: 30, height: 30))
        close.normalBg = t.surface2
        close.layer.cornerRadius = 15
        let cf = LXCRFont.f(15)
        let cl = LXCRLine(frame: close.bounds)
        cl.text = crAttr("\u{00D7}", cf, t.ink3)
        cl.align = .center
        cl.baseline = (30 - 15) / 2 + crBaseline(cf, 15)
        close.addSubview(cl)
        close.addAction(UIAction { [weak self] _ in self?.hideToc() }, for: .touchUpInside)
        tocPanel.addSubview(close)
        let hair = UIView(frame: CGRect(x: 0, y: headH, width: W, height: 0.5))
        hair.backgroundColor = t.borderSoft
        tocPanel.addSubview(hair)
        var y: CGFloat = 0
        var activeY: CGFloat?
        if vc.toc.isEmpty {
            let a = NSMutableAttributedString(attributedString: crAttr("这本书没有分章\n", LXCRFont.f(13.5), t.ink3))
            a.append(crAttr("用下面的进度条翻，或在共读记录里跳", LXCRFont.f(12), t.ink4))
            let ps = NSMutableParagraphStyle(); ps.alignment = .center
            a.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: a.length))
            let tx = LXCRText()
            tx.set(a, font: LXCRFont.f(13.5), lineHeight: 13.5 * 1.9)
            let h = tx.height(for: W - 36)
            tx.frame = CGRect(x: 18, y: 30, width: W - 36, height: h)
            tocList.addSubview(tx)
            y = 30 + h + 34
        } else {
            let cur = vc.chapterOfPara(vc.currentPidInView())
            for item in vc.toc {
                let lvl = min(item.level, 2)
                let f = LXCRFont.f(lvl == 0 ? 15 : (lvl == 1 ? 14 : 13), item.pid == cur?.pid ? 600 : 400)
                let active = item.pid == cur?.pid
                let col = active ? t.accent : (lvl == 0 ? t.ink2 : t.ink3)
                let px: CGFloat = lvl == 0 ? 20 : (lvl == 1 ? 36 : 52)
                let tx = LXCRText()
                tx.set(crAttr(crCollapse(item.title), f, col), font: f, lineHeight: f.lineHeight)
                let th = tx.height(for: W - px - 20)
                let row = LXCRPress(frame: CGRect(x: 0, y: y, width: W, height: 10 + th + 10 + 1))
                row.normalBg = active ? t.accentSoft : .clear
                row.pressedBg = t.accentSoft
                tx.frame = CGRect(x: px, y: 10, width: W - px - 20, height: th)
                row.addSubview(tx)
                let line = UIView(frame: CGRect(x: 0, y: row.bounds.height - 1, width: W, height: 1))
                line.backgroundColor = t.borderSoft
                row.addSubview(line)
                let pid = item.pid
                row.addAction(UIAction { [weak self] _ in self?.vc.jumpTo(pid, center: false) }, for: .touchUpInside)
                tocList.addSubview(row)
                if active { activeY = y }
                y += row.bounds.height
            }
            y += vc.safeBottom + 14
        }
        let maxH = (H - vc.safeTop) * 0.70
        let ph = min(maxH, headH + 0.5 + y)
        tocList.frame = CGRect(x: 0, y: headH + 0.5, width: W, height: ph - headH - 0.5)
        tocList.contentSize = CGSize(width: W, height: y)
        tocList.alwaysBounceVertical = true
        tocList.indicatorStyle = t.dark ? .white : .black
        tocPanel.addSubview(tocList)
        tocPanel.frame = CGRect(x: 0, y: H - ph, width: W, height: ph)
        let off = min(max(0, (activeY ?? 0) - 8), max(0, y - tocList.bounds.height))
        tocList.contentOffset = CGPoint(x: 0, y: off)
    }

    // MARK: 点划线 → 底部升起的批注面板(.annot-panel)

    func openAnnot(_ pid: Int, hl: String?) {
        annotPid = pid
        annotHl = hl
        annotOpen = true
        annotBackdrop.frame = vc.view.bounds
        vc.view.addSubview(annotBackdrop)
        vc.view.addSubview(annotPanel)
        renderAnnot()
        annotBackdrop.alpha = 0
        annotPanel.transform = CGAffineTransform(translationX: 0, y: annotPanel.bounds.height)
        crAnimate(0.25) { self.annotBackdrop.alpha = 1 }
        crAnimate(0.35) { self.annotPanel.transform = .identity }
    }

    func closeAnnot() {
        guard annotOpen else { return }
        annotOpen = false
        vc.view.endEditing(true)
        let p = annotPanel, b = annotBackdrop
        crAnimate(0.25, { b.alpha = 0 }) { if !self.annotOpen { b.removeFromSuperview() } }
        crAnimate(0.35, { p.transform = CGAffineTransform(translationX: 0, y: p.bounds.height) }) {
            if !self.annotOpen { p.removeFromSuperview(); p.transform = .identity }
        }
    }

    private var noteField: UITextField?

    private func renderAnnot() {
        annotPanel.subviews.forEach { $0.removeFromSuperview() }
        let W = vc.view.bounds.width, H = vc.view.bounds.height
        annotPanel.backgroundColor = t.surface
        annotPanel.layer.cornerRadius = 12
        annotPanel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        annotPanel.indicatorStyle = t.dark ? .white : .black
        let top = UIView(frame: CGRect(x: 0, y: 0, width: W, height: 0.5))
        top.backgroundColor = t.border
        annotPanel.addSubview(top)
        let handleBar = UIView(frame: CGRect(x: (W - 32) / 2, y: 10, width: 32, height: 4))
        handleBar.backgroundColor = t.surface3
        handleBar.layer.cornerRadius = 2
        annotPanel.addSubview(handleBar)
        var y: CGFloat = 14 + 12
        let hf = LXCRFont.f(9, 500)
        let title = LXCRLine(frame: CGRect(x: 20, y: y, width: 200, height: 22))
        title.text = crAttr("\u{00B6}\(annotPid)", hf, t.ink3, kern: 1.5)
        title.baseline = (22 - hf.lineHeight) / 2 + hf.ascender
        annotPanel.addSubview(title)
        let close = UIButton(type: .custom)
        close.frame = CGRect(x: W - 20 - 22, y: y, width: 22, height: 22)
        close.setImage(crIcon(["M4 4l8 8M12 4l-8 8"], size: 14, stroke: 1.2, color: t.ink3), for: .normal)
        close.addAction(UIAction { [weak self] _ in self?.closeAnnot() }, for: .touchUpInside)
        annotPanel.addSubview(close)
        y += 22 + 8
        if let hl = annotHl {
            let qf = LXCRFont.italic(15)
            let a = NSMutableAttributedString(attributedString: crAttr("\u{201C}", LXCRFont.f(20), t.ink4))
            a.append(NSAttributedString(string: "\u{2009}"))
            a.append(crAttr(hl, qf, t.ink2, oblique: true))
            let tx = LXCRText()
            tx.set(a, font: qf, lineHeight: 15 * 1.6)
            let h = tx.height(for: W - 40)
            tx.frame = CGRect(x: 20, y: y, width: W - 40, height: h)
            annotPanel.addSubview(tx)
            y += h + 12
            let hair = UIView(frame: CGRect(x: 0, y: y, width: W, height: 0.5))
            hair.backgroundColor = t.borderSoft
            annotPanel.addSubview(hair)
            y += 0.5 + 4
        }
        y += 8
        let all = vc.annots.filter { $0.pid == annotPid }
        let hls = all.filter { $0.type == "highlight" }
        let hlIds = Set(hls.map { $0.id })
        let notes = all.filter { $0.type == "note" }
        var linked: [String: [LXCRAnnot]] = [:]
        var standalone: [LXCRAnnot] = []
        for n in notes {
            if let h = n.highlightId, hlIds.contains(h) { linked[h, default: []].append(n) } else { standalone.append(n) }
        }
        let x0: CGFloat = 20, cw = W - 40
        let af = LXCRFont.f(8, 500), df = LXCRFont.f(7, 300)
        func author(_ a: LXCRAnnot, x: CGFloat, y: CGFloat, reply: Bool) -> CGFloat {
            let l = LXCRLine(frame: CGRect(x: x, y: y, width: cw, height: 8 * 1.6))
            l.text = crAttr((reply ? "\u{21A9} " : "") + (a.isClaude ? LXNick.yan : vc.meName).uppercased(), af, a.isClaude ? t.accent : t.jade, kern: 1)
            l.baseline = crBaseline(af, 8 * 1.6)
            annotPanel.addSubview(l)
            return 8 * 1.6 + 2
        }
        func date(_ a: LXCRAnnot, x: CGFloat, y: CGFloat) -> CGFloat {
            guard a.created.count >= 10 else { return 0 }
            let l = LXCRLine(frame: CGRect(x: x, y: y + 2, width: cw, height: 7 * 1.6))
            l.text = crAttr(String(a.created.prefix(10)), df, t.ink4)
            l.baseline = crBaseline(df, 7 * 1.6)
            annotPanel.addSubview(l)
            return 2 + 7 * 1.6
        }
        func delButton(_ a: LXCRAnnot, x: CGFloat, y: CGFloat) {
            guard !a.isClaude else { return }
            let b = UIButton(type: .custom)
            b.frame = CGRect(x: x, y: y, width: 18, height: 18)
            b.setTitle("\u{00D7}", for: .normal)
            b.titleLabel?.font = LXCRFont.f(16)
            b.setTitleColor(t.ink4.withAlphaComponent(0.5), for: .normal)
            b.setTitleColor(t.vermillion, for: .highlighted)
            b.addAction(UIAction { [weak self] _ in self?.confirmDelete(a) }, for: .touchUpInside)
            annotPanel.addSubview(b)
        }
        func noteBlock(_ n: LXCRAnnot, depth: Int, x: CGFloat, w: CGFloat, hlText: String?) {
            let sep = UIView(frame: CGRect(x: x, y: y, width: w, height: 0.5))
            sep.backgroundColor = t.borderSoft
            annotPanel.addSubview(sep)
            let ix = x + (depth > 0 ? 12 : 0), iw = w - (depth > 0 ? 12 : 0) - 24
            let top = y
            y += 0.5 + 6
            y += author(n, x: ix, y: y, reply: depth > 0)
            let f = LXCRFont.f(14)
            let tx = LXCRText()
            tx.set(crAttr(hlText != nil ? vc.cleanNote(n.text, hlText) : n.text, f, t.ink2), font: f, lineHeight: 14 * 1.6)
            let h = tx.height(for: iw)
            tx.frame = CGRect(x: ix, y: y, width: iw, height: h)
            annotPanel.addSubview(tx)
            y += h
            y += date(n, x: ix, y: y)
            y += 6
            delButton(n, x: x + w - 18, y: top + 6)
            for r in all where r.replyTo == n.id { noteBlock(r, depth: depth + 1, x: x, w: w, hlText: nil) }
        }
        for hl in hls {
            let top = y
            let bx = x0 + 3 + 10, bw = cw - 13
            y += 8
            y += author(hl, x: bx, y: y, reply: false)
            let f = LXCRFont.f(13)
            let s = NSMutableAttributedString(attributedString: crAttr(hl.text, f, t.ink2))
            s.addAttribute(.lxcrMark, value: LXCRMark(hl.isClaude ? t.hlClaudeStrong : t.hlButterStrong), range: NSRange(location: 0, length: s.length))
            let tx = LXCRText()
            tx.set(s, font: f, lineHeight: 13 * 1.6)
            let kids = linked[hl.id] ?? []
            let h = tx.height(for: bw - 8 - (kids.isEmpty ? 26 : 0))
            tx.frame = CGRect(x: bx + 4, y: y, width: bw - 8 - (kids.isEmpty ? 26 : 0), height: h)
            annotPanel.addSubview(tx)
            y += h
            y += date(hl, x: bx, y: y)
            y += 8
            if kids.isEmpty { delButton(hl, x: bx + bw - 18, y: top + 8) }
            for n in kids where !kids.contains(where: { $0.id == n.replyTo }) { noteBlock(n, depth: 0, x: bx, w: bw, hlText: hl.text) }
            let bar = UIView(frame: CGRect(x: x0, y: top, width: 3, height: y - top))
            bar.backgroundColor = (hl.isClaude ? t.accent : t.jade).withAlphaComponent(0.6)
            bar.layer.cornerRadius = 2
            annotPanel.addSubview(bar)
        }
        for a in standalone {
            let top = y
            let bx = x0 + 2 + 8, bw = cw - 10 - 26
            y += 8
            y += author(a, x: bx, y: y, reply: false)
            let f = LXCRFont.f(14)
            let tx = LXCRText()
            tx.set(crAttr(a.text, f, t.ink2), font: f, lineHeight: 14 * 1.6)
            let h = tx.height(for: bw)
            tx.frame = CGRect(x: bx, y: y, width: bw, height: h)
            annotPanel.addSubview(tx)
            y += h
            y += date(a, x: bx, y: y)
            y += 8
            let bar = UIView(frame: CGRect(x: x0, y: top + 8, width: 2, height: max(20, y - top - 16)))
            bar.backgroundColor = (a.isClaude ? t.accent : t.jade).withAlphaComponent(0.6)
            bar.layer.cornerRadius = 1
            annotPanel.addSubview(bar)
            delButton(a, x: x0 + cw - 8 - 18, y: top + 8)
        }
        if all.isEmpty {
            let ef = LXCRFont.f(9, 300)
            let e = LXCRLine(frame: CGRect(x: x0, y: y + 8, width: cw, height: 9 * 1.6))
            e.text = crAttr("no annotations yet", ef, t.ink4)
            e.baseline = crBaseline(ef, 9 * 1.6)
            annotPanel.addSubview(e)
            y += 8 + 9 * 1.6 + 8
        }
        y += 8 + 4
        // 输入行:边框 0.5、圆角 2;Send 是 9px 300 的小字钮
        let hair = UIView(frame: CGRect(x: 0, y: y, width: W, height: 0.5))
        hair.backgroundColor = t.borderSoft
        annotPanel.addSubview(hair)
        y += 0.5 + 8
        let sf = LXCRFont.f(9, 300)
        let sendA = crAttr("Send", sf, t.ink2, kern: 0.5)
        let sendW = 14 + LXCRLine.width(sendA) + 14 + 1
        let fh: CGFloat = 8 + LXCRFont.f(14).lineHeight + 8 + 1
        let field = UITextField(frame: CGRect(x: 20, y: y, width: W - 40 - 4 - sendW, height: fh))
        field.font = LXCRFont.f(14)
        field.textColor = t.ink1
        field.tintColor = t.accent
        field.backgroundColor = t.bg
        field.layer.borderWidth = 0.5
        field.layer.borderColor = t.border.cgColor
        field.layer.cornerRadius = 2
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10.5, height: 1)); field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 10.5, height: 1)); field.rightViewMode = .always
        field.attributedPlaceholder = crAttr("add a note...", LXCRFont.f(14), t.ink4)
        field.keyboardAppearance = t.dark ? .dark : .light
        field.returnKeyType = .send
        field.delegate = self
        field.tag = 71
        annotPanel.addSubview(field)
        noteField = field
        let send = LXCRPress(frame: CGRect(x: W - 20 - sendW, y: y, width: sendW, height: fh))
        send.normalBg = t.surface
        send.pressedBg = t.accent
        send.layer.borderWidth = 0.5
        send.layer.borderColor = t.border.cgColor
        send.layer.cornerRadius = 2
        let sl = LXCRLine(frame: send.bounds)
        sl.text = sendA
        sl.align = .center
        sl.baseline = (fh - sf.lineHeight) / 2 + sf.ascender
        send.addSubview(sl)
        send.addAction(UIAction { [weak self] _ in self?.submitNote() }, for: .touchUpInside)
        annotPanel.addSubview(send)
        y += fh + 12
        let maxH = (H - vc.safeTop) * 0.80
        let ph = min(maxH, y + vc.safeBottom)
        annotPanel.contentSize = CGSize(width: W, height: y + vc.safeBottom)
        annotPanel.frame = CGRect(x: 0, y: H - ph, width: W, height: ph)
    }

    private func submitNote() {
        guard let f = noteField, let id = vc.book?.id else { return }
        let text = (f.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        f.text = ""
        let pid = annotPid
        LXCRAPI.call("POST", "/books/\(id)/annotations", ["paragraph_id": pid, "type": "note", "text": text]) { [weak self] obj, _ in
            guard let s = self, let d = obj as? [String: Any], let a = LXCRAnnot(d) else { return }
            s.vc.annots.append(a)
            s.vc.refreshParas([pid])
            if s.annotOpen { s.renderAnnot() }
        }
    }

    /// 网页用的是系统 confirm():删划线 = 连同挂在下面的话一起删
    private func confirmDelete(_ a: LXCRAnnot) {
        let bundle = a.type == "highlight" || (a.type == "note" && a.highlightId != nil)
        let ac = UIAlertController(title: nil, message: bundle ? "Remove this annotation?" : "Delete this note?", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let s = self, let id = s.vc.book?.id else { return }
            LXCRAPI.call("DELETE", "/books/\(id)/annotations/\(a.id)") { obj, _ in
                let gone = Set(((obj as? [String: Any])?["deleted"] as? [String]) ?? [a.id])
                s.vc.annots.removeAll { gone.contains($0.id) }
                s.vc.refreshParas([a.pid])
                if s.vc.annots.contains(where: { $0.pid == s.annotPid }) { s.renderAnnot() } else { s.closeAnnot() }
            }
        })
        vc.present(ac, animated: true)
    }

    // MARK: 全书搜索(.search-panel):顶上一条,输入框 + Cancel,下面结果

    func openSearch() {
        searchOpen = true
        styleSearch()
        searchField.text = ""
        searchResults.subviews.forEach { $0.removeFromSuperview() }
        searchInfo.text = NSAttributedString()
        layoutSearch(results: 0)
        vc.view.addSubview(search)
        searchField.becomeFirstResponder()
    }

    func closeSearch() {
        searchOpen = false
        searchWork?.cancel()
        searchField.resignFirstResponder()
        search.removeFromSuperview()
    }

    private func styleSearch() {
        search.backgroundColor = t.surface
        if search.subviews.isEmpty {
            search.addSubview(searchField)
            search.addSubview(searchInfo)
            search.addSubview(searchResults)
            let hair = UIView()
            hair.tag = 9
            search.addSubview(hair)
            let cancel = UIButton(type: .custom)
            cancel.tag = 8
            cancel.addAction(UIAction { [weak self] _ in self?.closeSearch() }, for: .touchUpInside)
            search.addSubview(cancel)
        }
        search.viewWithTag(9)?.backgroundColor = t.border
        if let c = search.viewWithTag(8) as? UIButton {
            c.setAttributedTitle(crAttr("Cancel", LXCRFont.f(14), t.ink3), for: .normal)
        }
        searchField.font = LXCRFont.f(15)
        searchField.textColor = t.ink1
        searchField.tintColor = t.accent
        searchField.backgroundColor = t.bg
        searchField.layer.borderWidth = 1
        searchField.layer.borderColor = t.border.cgColor
        searchField.layer.cornerRadius = 8
        searchField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 13, height: 1)); searchField.leftViewMode = .always
        searchField.attributedPlaceholder = crAttr("Search...", LXCRFont.f(15), t.ink4)
        searchField.keyboardAppearance = t.dark ? .dark : .light
        searchResults.indicatorStyle = t.dark ? .white : .black
    }

    private func layoutSearch(results h: CGFloat) {
        let W = vc.view.bounds.width
        let fh = 8 + LXCRFont.f(15).lineHeight + 8 + 2
        let cancelW = LXCRLine.width(crAttr("Cancel", LXCRFont.f(14), t.ink3)) + 8
        searchField.frame = CGRect(x: 16, y: 8, width: W - 32 - 8 - cancelW, height: fh)
        search.viewWithTag(8)?.frame = CGRect(x: W - 16 - cancelW, y: 8, width: cancelW, height: fh)
        let infoH: CGFloat = searchInfo.text.length > 0 ? 4 + 9 * 1.6 : 0
        searchInfo.frame = CGRect(x: 16, y: 8 + fh + 4, width: W - 32, height: 9 * 1.6)
        searchInfo.baseline = crBaseline(LXCRFont.f(9), 9 * 1.6)
        searchInfo.isHidden = infoH == 0
        let maxH = (vc.view.bounds.height - vc.safeTop) * 0.6
        let rh = h > 0 ? min(h, maxH) : 0
        searchResults.frame = CGRect(x: 16, y: 8 + fh + infoH + 8, width: W - 32, height: rh)
        let total = 8 + fh + infoH + 8 + rh + 8
        search.frame = CGRect(x: 0, y: vc.safeTop, width: W, height: total)
        search.viewWithTag(9)?.frame = CGRect(x: 0, y: total - 1, width: W, height: 1)
    }

    @objc private func searchChanged() {
        searchWork?.cancel()
        let q = (searchField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if q.count < 2 {
            searchResults.subviews.forEach { $0.removeFromSuperview() }
            searchInfo.text = NSAttributedString()
            layoutSearch(results: 0)
            return
        }
        let w = DispatchWorkItem { [weak self] in self?.runSearch(q) }
        searchWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: w)
    }

    private func runSearch(_ q: String) {
        guard let id = vc.book?.id else { return }
        let f = LXCRFont.f(9)
        searchInfo.text = crAttr("searching...", f, t.ink4)
        layoutSearch(results: searchResults.bounds.height)
        let enc = q.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? q
        LXCRAPI.call("GET", "/books/\(id)/search?q=\(enc)") { [weak self] obj, code in
            guard let s = self, s.searchOpen else { return }
            guard let arr = obj as? [[String: Any]] else {
                s.searchInfo.text = crAttr("search failed", f, s.t.ink4)
                s.searchResults.subviews.forEach { $0.removeFromSuperview() }
                s.layoutSearch(results: 0)
                return
            }
            s.searchInfo.text = crAttr("\(arr.count) results", f, s.t.ink4)
            s.renderResults(arr, q)
        }
    }

    private func renderResults(_ arr: [[String: Any]], _ q: String) {
        searchResults.subviews.forEach { $0.removeFromSuperview() }
        let w = vc.view.bounds.width - 32
        var y: CGFloat = 0
        let pf = LXCRFont.f(9), tf = LXCRFont.f(14)
        let re = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: q), options: [.caseInsensitive])
        for r in arr {
            guard let pid = (r["paragraph_id"] as? NSNumber)?.intValue else { continue }
            let snip = (r["snippet"] as? String) ?? ""
            let row = LXCRPress(frame: CGRect(x: 0, y: y, width: w, height: 10))
            row.pressedBg = t.accentSoft
            let pl = LXCRLine(frame: CGRect(x: 0, y: 10, width: w, height: 9 * 1.6))
            pl.text = crAttr("\u{00B6}\(pid)", pf, t.ink4)
            pl.baseline = crBaseline(pf, 9 * 1.6)
            row.addSubview(pl)
            let s = NSMutableAttributedString(attributedString: crAttr(crCollapse(snip), tf, t.ink2))
            for m in re?.matches(in: s.string, range: NSRange(location: 0, length: (s.string as NSString).length)) ?? [] {
                s.addAttribute(.lxcrMark, value: LXCRMark(t.hlButterStrong), range: m.range)
                s.addAttribute(.foregroundColor, value: t.ink1, range: m.range)
            }
            let tx = LXCRText()
            tx.set(s, font: tf, lineHeight: 14 * 1.5)
            let h = tx.height(for: w)
            tx.frame = CGRect(x: 0, y: 10 + 9 * 1.6 + 2, width: w, height: h)
            row.addSubview(tx)
            row.frame.size.height = 10 + 9 * 1.6 + 2 + h + 10 + 1
            let hair = UIView(frame: CGRect(x: 0, y: row.bounds.height - 1, width: w, height: 1))
            hair.backgroundColor = t.borderSoft
            row.addSubview(hair)
            row.addAction(UIAction { [weak self] _ in
                self?.closeSearch()
                self?.vc.jumpTo(pid, center: true)
            }, for: .touchUpInside)
            searchResults.addSubview(row)
            y += row.bounds.height
        }
        searchResults.contentSize = CGSize(width: w, height: y)
        searchResults.contentOffset = .zero
        layoutSearch(results: y)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 71 { submitNote(); return false }
        if textField === dialogField { closeDialog(true); return false }
        return true
    }

    // MARK: 对话框(.dialog-overlay / .dialog-box)

    private var dialogDone: ((String) -> Void)?
    private var confirmDone: (() -> Void)?

    func prompt(_ message: String, value: String, _ done: @escaping (String) -> Void) {
        dialogDone = done
        confirmDone = nil
        showDialog(message, input: value, danger: nil)
    }

    func confirm(_ message: String, danger: String, _ done: @escaping () -> Void) {
        confirmDone = done
        dialogDone = nil
        showDialog(message, input: nil, danger: danger)
    }

    private func showDialog(_ message: String, input: String?, danger: String?) {
        dialog?.removeFromSuperview()
        let W = vc.view.bounds.width, H = vc.view.bounds.height
        let overlay = UIControl(frame: vc.view.bounds)
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.3)
        overlay.addAction(UIAction { [weak self] _ in self?.closeDialog(false) }, for: .touchUpInside)
        let bw = min(320, W * 0.9)
        let box = UIControl()
        box.backgroundColor = t.surface
        box.layer.cornerRadius = 4
        box.layer.borderWidth = 0.5
        box.layer.borderColor = t.border.cgColor
        let mf = LXCRFont.f(16)
        let msg = LXCRText()
        msg.set(crAttr(message, mf, t.ink1), font: mf, lineHeight: 16 * 1.5)
        let mh = msg.height(for: bw - 41)
        msg.frame = CGRect(x: 20.5, y: 20.5, width: bw - 41, height: mh)
        box.addSubview(msg)
        var y = 20.5 + mh + 16
        if let v = input {
            let f = UITextField(frame: CGRect(x: 20.5, y: y, width: bw - 41, height: 8 + LXCRFont.f(15).lineHeight + 8 + 1))
            f.text = v
            f.font = LXCRFont.f(15)
            f.textColor = t.ink1
            f.tintColor = t.accent
            f.backgroundColor = t.bg
            f.layer.borderWidth = 0.5
            f.layer.borderColor = t.border.cgColor
            f.layer.cornerRadius = 2
            f.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10.5, height: 1)); f.leftViewMode = .always
            f.keyboardAppearance = t.dark ? .dark : .light
            f.delegate = self
            box.addSubview(f)
            dialogField = f
            y += f.bounds.height + 16
        } else {
            dialogField = nil
        }
        let bf = LXCRFont.f(10, 300)
        let bh = 6 + bf.lineHeight + 6 + 1
        let labels: [(String, Int)] = [("Cancel", 0), (danger ?? "OK", danger != nil ? 2 : 1)]
        var bx = bw - 20.5
        for (label, kind) in labels.reversed() {
            let fg = kind == 0 ? t.ink2 : t.bg
            let a = crAttr(label, bf, fg, kern: 1)
            let w = 16 + LXCRLine.width(a) + 16 + 1
            bx -= w
            let b = LXCRPress(frame: CGRect(x: bx, y: y, width: w, height: bh))
            b.normalBg = kind == 0 ? t.surface : (kind == 1 ? t.ink1 : t.vermillion)
            if kind == 0 { b.pressedBg = t.surface2 } else { b.pressedAlpha = 0.85 }
            b.layer.borderWidth = 0.5
            b.layer.borderColor = (kind == 0 ? t.border : (kind == 1 ? t.ink1 : t.vermillion)).cgColor
            b.layer.cornerRadius = 2
            let l = LXCRLine(frame: b.bounds)
            l.text = a
            l.align = .center
            l.baseline = (bh - bf.lineHeight) / 2 + bf.ascender
            b.addSubview(l)
            b.addAction(UIAction { [weak self] _ in self?.closeDialog(kind != 0) }, for: .touchUpInside)
            box.addSubview(b)
            bx -= 8
        }
        y += bh + 20.5
        box.frame = CGRect(x: (W - bw) / 2, y: vc.safeTop + (H - vc.safeTop - y) / 2, width: bw, height: y)
        overlay.addSubview(box)
        vc.view.addSubview(overlay)
        dialog = overlay
        if let f = dialogField {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { f.becomeFirstResponder() }
            // 键盘起来时框子挪到键盘上方的正中
            NotificationCenter.default.addObserver(self, selector: #selector(dialogKb(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        }
    }

    @objc private func dialogKb(_ n: Notification) {
        guard let o = dialog, let box = o.subviews.first,
              let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let kbTop = vc.view.convert(end, from: nil).minY
        let avail = min(vc.view.bounds.height, kbTop) - vc.safeTop
        UIView.animate(withDuration: 0.25) {
            box.frame.origin.y = self.vc.safeTop + max(8, (avail - box.bounds.height) / 2)
        }
    }

    func closeDialog(_ ok: Bool) {
        guard let o = dialog else { return }
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        let val = dialogField?.text ?? ""
        dialogField?.resignFirstResponder()
        o.removeFromSuperview()
        dialog = nil
        dialogField = nil
        if ok {
            if let d = dialogDone { d(val) }
            if let c = confirmDone { c() }
        }
        dialogDone = nil
        confirmDone = nil
    }

    /// 网页 alert():系统弹窗
    func alert(_ s: String) {
        let ac = UIAlertController(title: nil, message: s, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        vc.present(ac, animated: true)
    }
}

/// .rs-slider:30 高的粗轨道(surface2、圆角 15),拇指 26px 白圆 + 1px 边 + 小影子,上下各让 2
final class LXCRFontSlider: UISlider {
    func configure(_ t: LXCRTheme) {
        let track = UIGraphicsImageRenderer(size: CGSize(width: 31, height: 30)).image { _ in
            t.surface2.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 31, height: 30), cornerRadius: 15).fill()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15))
        setMinimumTrackImage(track, for: .normal)
        setMaximumTrackImage(track, for: .normal)
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { ctx in
            let c = ctx.cgContext
            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor(white: 0, alpha: 0.18).cgColor)
            t.surface.setFill()
            c.fillEllipse(in: CGRect(x: 3, y: 3, width: 26, height: 26))
            c.setShadow(offset: .zero, blur: 0, color: nil)
            t.border.setStroke()
            c.setLineWidth(1)
            c.strokeEllipse(in: CGRect(x: 3.5, y: 3.5, width: 25, height: 25))
        }
        setThumbImage(thumb, for: .normal)
        setThumbImage(thumb, for: .highlighted)
    }
    override func trackRect(forBounds bounds: CGRect) -> CGRect { bounds }
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        let span = maximumValue - minimumValue
        let f = span > 0 ? CGFloat((value - minimumValue) / span) : 0
        return CGRect(x: (bounds.width - 26) * f - 3, y: 2 - 3, width: 32, height: 32)
    }
}

// MARK: - 预览路线 coread:只摆假书,一步一步拍

enum LXCRPreview {
    static func start(tries: Int = 0) {
        guard LustreConfig.isPreview, LustreConfig.previewFocus == "coread" else { return }
        guard let top = DrawerPlugin.topVC(), top.view.window != nil else {
            if tries < 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(tries: tries + 1) } }
            return
        }
        LXCoReadVC.open()
        let vc = LXCoReadVC.shared
        let mark = UIView(frame: LXBubbleSampler.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let phase = UIView(frame: CGRect(x: 28, y: 70, width: 20, height: 20))
        let steps: [(UIColor, () -> Void)] = [
            (.yellow, { vc.setThemeNow("mist") }),                                   // 书架
            (.cyan, {                                                               // 书架长按菜单
                if let card = vc.shelfScroll.subviews.first(where: { $0.accessibilityIdentifier == "sample01" }) {
                    vc.showCtxMenu("sample01", at: vc.view.convert(CGPoint(x: card.bounds.midX, y: card.bounds.midY), from: card))
                }
            }),
            (.red, { vc.hideCtxMenu(); vc.openBook("sample01") }),                  // 正文,上下栏收着
            (UIColor(red: 0.5, green: 0, blue: 1, alpha: 1), { vc.setChrome(true) }),  // 上下栏出来
            (.white, { vc.setChrome(false); vc.cards.open(3, mode: .menu) }),       // 长按小工具条
            (.gray, { vc.cards.open(3, mode: .list) }),                             // 点小方块:这段所有的话
            (.orange, { vc.cards.open(3, mode: .write) }),                          // 弹幕输入(键盘起来)
            (.green, { vc.cards.close(); vc.view.endEditing(true); vc.setChrome(true); vc.panels.toggleSettings() }),
            (.blue, { vc.setThemeNow("moon"); vc.panels.hideSettings(); vc.panels.toggleSettings() }),
            (UIColor(red: 0, green: 0.5, blue: 0.5, alpha: 1), { vc.panels.hideSettings(); vc.panels.toggleToc() }),
            (.brown, { vc.panels.hideToc(); vc.setThemeNow("paper"); vc.showRecords() }),
            (.black, { vc.backToReader(); vc.panels.openAnnot(6, hl: "灯芯短了一截") }),
            (UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1), { vc.panels.closeAnnot(); vc.panels.openSearch(); vc.panels.previewSearch("雨声") }),
            (UIColor(red: 0.6, green: 0.8, blue: 0.2, alpha: 1), { vc.panels.closeSearch(); vc.view.endEditing(true); vc.setThemeNow("night"); vc.setChrome(false) }),
            (UIColor(red: 0.2, green: 0.4, blue: 0.4, alpha: 1), { vc.setThemeNow("white"); vc.backFromReader(); vc.openDetail("sample01") }),
        ]
        for (i, st) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1 + Double(i) * 8) {
                st.1()
                phase.backgroundColor = st.0
                if mark.superview !== vc.view { vc.view.addSubview(mark); vc.view.addSubview(phase) }
                vc.view.bringSubviewToFront(mark)
                vc.view.bringSubviewToFront(phase)
            }
        }
    }
}

extension LXCRPanels {
    /// 预览:往搜索框里填一个词,走一遍真搜索
    func previewSearch(_ q: String) {
        searchField.text = q
        runSearch(q)
    }
}

extension LXCoReadVC {
    /// 预览里换配色不要过渡,截图时已经换好
    func setThemeNow(_ id: String) {
        LXCRPrefs.theme = id
        t = LXCRTheme.of(id)
        applyTheme()
    }
}
