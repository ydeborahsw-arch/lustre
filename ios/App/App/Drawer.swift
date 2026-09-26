import Foundation
import UIKit
import Capacitor



enum LXSVG {
    private static let tokenRe = try! NSRegularExpression(
        pattern: "([MmLlHhVvCcSsQqTtAaZz])|([-+]?(?:[0-9]*\\.[0-9]+|[0-9]+\\.?)(?:[eE][-+]?[0-9]+)?)")

    static func path(_ d: String) -> CGMutablePath {
        let p = CGMutablePath()
        let ns = d as NSString
        var toks: [String] = []
        for m in tokenRe.matches(in: d, range: NSRange(location: 0, length: ns.length)) {
            toks.append(ns.substring(with: m.range))
        }
        var i = 0
        var cmd = "M"
        var cur = CGPoint.zero, start = CGPoint.zero
        var lastC: CGPoint? = nil, lastQ: CGPoint? = nil
        var bad = false
        func num() -> CGFloat {
            guard i < toks.count, let v = Double(toks[i]) else { bad = true; return 0 }
            i += 1
            return CGFloat(v)
        }
        func hasNum() -> Bool { i < toks.count && Double(toks[i]) != nil }
        func pt(_ rel: Bool) -> CGPoint {
            let x = num(), y = num()
            return rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }
        while i < toks.count && !bad {
            if Double(toks[i]) == nil { cmd = toks[i]; i += 1 }
            let rel = cmd == cmd.lowercased()
            var keepC = false, keepQ = false
            switch cmd.uppercased() {
            case "M":
                cur = pt(rel); start = cur; p.move(to: cur)
                cmd = rel ? "l" : "L"
            case "L":
                cur = pt(rel); p.addLine(to: cur)
            case "H":
                let x = num(); cur.x = rel ? cur.x + x : x; p.addLine(to: cur)
            case "V":
                let y = num(); cur.y = rel ? cur.y + y : y; p.addLine(to: cur)
            case "C":
                let c1 = pt(rel), c2 = pt(rel), e = pt(rel)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastC = c2; keepC = true
            case "S":
                let c1 = lastC.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = pt(rel), e = pt(rel)
                p.addCurve(to: e, control1: c1, control2: c2); cur = e; lastC = c2; keepC = true
            case "Q":
                let c1 = pt(rel), e = pt(rel)
                p.addQuadCurve(to: e, control: c1); cur = e; lastQ = c1; keepQ = true
            case "T":
                let c1 = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let e = pt(rel)
                p.addQuadCurve(to: e, control: c1); cur = e; lastQ = c1; keepQ = true
            case "A":
                let rx = num(), ry = num(), rot = num(), large = num() != 0, sweep = num() != 0
                let e = pt(rel)
                arc(p, from: cur, to: e, rx: rx, ry: ry, rotDeg: rot, large: large, sweep: sweep)
                cur = e
            case "Z":
                p.closeSubpath(); cur = start
                if hasNum() { cmd = rel ? "l" : "L" }
            default:
                bad = true
            }
            if !keepC { lastC = nil }
            if !keepQ { lastQ = nil }
        }
        return p
    }

    private static func arc(_ p: CGMutablePath, from p0: CGPoint, to p1: CGPoint,
                            rx rx0: CGFloat, ry ry0: CGFloat, rotDeg: CGFloat, large: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { p.addLine(to: p1); return }
        let phi = rotDeg * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p = cosP * dx2 + sinP * dy2
        let y1p = -sinP * dx2 + cosP * dy2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = (large != sweep ? 1 : -1) * sqrt(max(0, den == 0 ? 0 : num / den))
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(max(-1, min(1, len == 0 ? 1 : dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let t1 = ang(1, 0, ux, uy)
        var dt = ang(ux, uy, vx, vy)
        if !sweep && dt > 0 { dt -= 2 * .pi } else if sweep && dt < 0 { dt += 2 * .pi }
        let segs = max(1, Int(ceil(abs(dt) / (.pi / 2))))
        let delta = dt / CGFloat(segs)
        let t = 4 / 3 * tan(delta / 4)
        func e(_ a: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(a) * cosP - ry * sin(a) * sinP,
                    y: cy + rx * cos(a) * sinP + ry * sin(a) * cosP)
        }
        func ed(_ a: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(a) * cosP - ry * cos(a) * sinP,
                    y: -rx * sin(a) * sinP + ry * cos(a) * cosP)
        }
        var a = t1
        for _ in 0..<segs {
            let b = a + delta
            let pa = e(a), pb = e(b), da = ed(a), db = ed(b)
            p.addCurve(to: pb,
                       control1: CGPoint(x: pa.x + t * da.x, y: pa.y + t * da.y),
                       control2: CGPoint(x: pb.x - t * db.x, y: pb.y - t * db.y))
            a = b
        }
    }

    enum Part {
        case path(String, alpha: CGFloat = 1, fill: Bool = false)
        case circle(CGFloat, CGFloat, CGFloat, alpha: CGFloat = 1, fill: Bool = false)
        case rect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)
    }

    static func icon(_ parts: [Part], size: CGFloat, stroke: CGFloat = 1.6, box: CGFloat = 24) -> UIImage {
        let k = size / box
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let c = ctx.cgContext
            c.scaleBy(x: k, y: k)
            c.setLineWidth(stroke); c.setLineCap(.round); c.setLineJoin(.round)
            c.setStrokeColor(UIColor.white.cgColor); c.setFillColor(UIColor.white.cgColor)
            for part in parts {
                var alpha: CGFloat = 1, fill = false
                let cg: CGPath
                switch part {
                case .path(let d, let a, let f):
                    cg = path(d); alpha = a; fill = f
                case .circle(let cx, let cy, let r, let a, let f):
                    cg = CGPath(ellipseIn: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r), transform: nil)
                    alpha = a; fill = f
                case .rect(let x, let y, let w, let h, let rx):
                    cg = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: rx, cornerHeight: rx, transform: nil)
                }
                c.setAlpha(alpha)
                c.addPath(cg)
                if fill { c.fillPath() } else { c.strokePath() }
            }
        }.withRenderingMode(.alwaysTemplate)
    }
}


enum LXDrawerIcons {
    static let menus: [String: [LXSVG.Part]] = [
        "chat": [.path("M21 11.5a8.5 8.5 0 0 1-12.3 7.6L3 21l1.9-5.7A8.5 8.5 0 1 1 21 11.5Z")],
        "moments": [.circle(12, 12, 8.5), .path("M12 3.5a14 14 0 0 1 0 17M4 9h16M4 15h16", alpha: 0.6)],
        "timemachine": [.circle(12, 13, 7.5), .path("M12 9.5V13l2.4 1.6M12 2.5v3M9.5 3h5")],
        "archive": [.path("M11 4a7 7 0 1 0 4.9 12L21 21"), .path("M11 8v3l2 2")],
        "calls": [.path("M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.6a2 2 0 0 1-.5 2.1L8 9.7a16 16 0 0 0 6.3 6.3l1.3-1.3a2 2 0 0 1 2.1-.5c.8.3 1.7.6 2.6.7a2 2 0 0 1 1.7 2z")],
        "artifacts": [.path("M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"), .path("M14 2v6h6M16 13H8M16 17H8M10 9H8")],
        "gallery": [.path("M12 3l2.2 4.5 5 .7-3.6 3.5.9 4.9L12 14.3 7.5 16.6l.9-4.9L4.8 8.2l5-.7z")],
        "memory": [.path("M12 3.5c.8 5 3.5 7.7 8.5 8.5-5 .8-7.7 3.5-8.5 8.5-.8-5-3.5-7.7-8.5-8.5 5-.8 7.7-3.5 8.5-8.5Z")],
        "library": [.path("M12 6.5c-1.8-1.6-4.2-2-7-1.4v12.4c2.8-.6 5.2-.2 7 1.4 1.8-1.6 4.2-2 7-1.4V5.1c-2.8-.6-5.2-.2-7 1.4Z"), .path("M12 6.5V19")],
        "terminal": [.rect(3, 4.5, 18, 15, 2.4), .path("M7 9l3 3-3 3M12.5 15H17")],
        "__stub__": [.path("M14.5 4.5l5 5-9.8 9.8-5.5.7.7-5.5z"), .path("M12.5 6.5l5 5")],
        "movie": [.rect(3, 5, 18, 14, 2.4), .path("M7.5 5v14M16.5 5v14M3 9.5h4.5M3 14.5h4.5M16.5 9.5H21M16.5 14.5H21")],
        "album": [.rect(3, 4.5, 18, 15, 2.4), .circle(8.5, 10, 1.6), .path("M21 16l-4.6-4.6L7 21")],
        "tides": [.path("M3 8.5c1.8-2.2 3.6-2.2 5.4 0s3.6 2.2 5.4 0 3.6-2.2 5.4 0"),
                  .path("M3 13c1.8-2.2 3.6-2.2 5.4 0s3.6 2.2 5.4 0 3.6-2.2 5.4 0"),
                  .path("M3 17.5c1.8-2.2 3.6-2.2 5.4 0s3.6 2.2 5.4 0 3.6-2.2 5.4 0")],
        "room": [.path("M5 21V9a7 7 0 0 1 14 0v12"), .path("M4 21h16"), .circle(15, 13, 0.95, fill: true)],
    ]
    static let strokeOf: [String: CGFloat] = ["memory": 1.5]
    static let gear: [LXSVG.Part] = [
        .circle(12, 12, 3.05),
        .path("M18.9 14.2a1.55 1.55 0 0 0 .31 1.71l.06.06a1.85 1.85 0 1 1-2.62 2.62l-.06-.06a1.55 1.55 0 0 0-1.71-.31 1.55 1.55 0 0 0-.94 1.42v.16a1.85 1.85 0 1 1-3.7 0v-.09a1.55 1.55 0 0 0-1.01-1.42 1.55 1.55 0 0 0-1.71.31l-.06.06a1.85 1.85 0 1 1-2.62-2.62l.06-.06a1.55 1.55 0 0 0 .31-1.71 1.55 1.55 0 0 0-1.42-.94h-.16a1.85 1.85 0 1 1 0-3.7h.09a1.55 1.55 0 0 0 1.42-1.01 1.55 1.55 0 0 0-.31-1.71l-.06-.06a1.85 1.85 0 1 1 2.62-2.62l.06.06a1.55 1.55 0 0 0 1.71.31h.07a1.55 1.55 0 0 0 .94-1.42v-.16a1.85 1.85 0 1 1 3.7 0v.09a1.55 1.55 0 0 0 .94 1.42 1.55 1.55 0 0 0 1.71-.31l.06-.06a1.85 1.85 0 1 1 2.62 2.62l-.06.06a1.55 1.55 0 0 0-.31 1.71v.07a1.55 1.55 0 0 0 1.42.94h.16a1.85 1.85 0 1 1 0 3.7h-.09a1.55 1.55 0 0 0-1.42.94Z"),
    ]
    static let pin: [LXSVG.Part] = [.path("M16 3l5 5-6.5 2.5L12 17l-2.5-4.5L3 15l5-5-2-6 6 2z", alpha: 0.55, fill: true)]
    static let cross: [LXSVG.Part] = [.path("M18 6L6 18M6 6l12 12")]

    private static var cache: [String: UIImage] = [:]
    static func image(_ key: String, _ parts: [LXSVG.Part], size: CGFloat, stroke: CGFloat) -> UIImage {
        let k = "\(key)@\(size)/\(stroke)"
        if let im = cache[k] { return im }
        let im = LXSVG.icon(parts, size: size, stroke: stroke)
        cache[k] = im
        return im
    }
    static func menuIcon(_ key: String) -> UIImage {
        let parts = menus[key] ?? []
        return image("m:" + key, parts, size: 20, stroke: strokeOf[key] ?? 1.6)
    }
}


struct LXDrawerTint {
    let wall: [UIColor], wallStops: [NSNumber]
    let text, soft, faint, hairline, segTrack, cardBg, composerBg, accent, bg, cardLine: UIColor
    let pillBg, pillFg, title, icon, shadow: UIColor
    let popShadowA: Float

    private static func hex(_ v: UInt32, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }
    static let tints: [String: LXDrawerTint] = [
        "day": LXDrawerTint(
            wall: [hex(0xF6FBFF), hex(0xE2F2FF), hex(0xDEEAF6), hex(0xD9E7F5)], wallStops: [0, 0.42, 0.74, 1],
            text: hex(0x2A3A4D), soft: hex(0x64798D), faint: hex(0x92A6B8),
            hairline: UIColor(red: 122/255, green: 140/255, blue: 158/255, alpha: 0.22),
            segTrack: UIColor(red: 140/255, green: 160/255, blue: 176/255, alpha: 0.11),
            cardBg: UIColor(white: 1, alpha: 0.58), composerBg: hex(0xF4F8FB), accent: hex(0x618FBD),
            bg: hex(0xE9F2FB), cardLine: UIColor(red: 150/255, green: 168/255, blue: 182/255, alpha: 0.12),
            pillBg: hex(0xC8D8E8), pillFg: hex(0x2A3A4D),
            title: hex(0x2A3A4D), icon: hex(0x64798D),
            shadow: UIColor(red: 74/255, green: 93/255, blue: 108/255, alpha: 0.10), popShadowA: 0.14),
        "half": LXDrawerTint(
            wall: [hex(0x1B1B19), hex(0x1B1B19)], wallStops: [0, 1],
            text: hex(0xE9E5DC), soft: hex(0xA5A198), faint: hex(0x6E6B64),
            hairline: UIColor(white: 1, alpha: 0.08), segTrack: UIColor(white: 1, alpha: 0.10),
            cardBg: UIColor(red: 38/255, green: 38/255, blue: 36/255, alpha: 0.62), composerBg: hex(0x202020), accent: hex(0xDA7A55),
            bg: hex(0x191917), cardLine: UIColor(white: 1, alpha: 0.07),
            pillBg: hex(0xF2EFE9), pillFg: hex(0x1A1A18),
            title: hex(0xE9E5DC), icon: hex(0xA5A198),
            shadow: UIColor(white: 0, alpha: 0.55), popShadowA: 0.14),
        "moon": LXDrawerTint(
            wall: [UIColor.black, UIColor.black], wallStops: [0, 1],
            text: hex(0xE3E2E7), soft: hex(0xA5B0C6), faint: hex(0x717E97),
            hairline: UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10),
            segTrack: UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10),
            cardBg: hex(0x26252A), composerBg: UIColor.black, accent: hex(0xA9D9EE),
            bg: UIColor.black, cardLine: UIColor(red: 242/255, green: 244/255, blue: 248/255, alpha: 0.07),
            pillBg: hex(0xF2EFE9), pillFg: hex(0x1A1A18),
            title: hex(0xD7EAF8), icon: hex(0xD7EAF8),
            shadow: UIColor(red: 3/255, green: 6/255, blue: 12/255, alpha: 0.72), popShadowA: 0.14),
    ]
    static func of(_ moon: String) -> LXDrawerTint { tints[moon] ?? tints["moon"]! }

    static func font(_ size: CGFloat, wght: CGFloat = 400) -> UIFont {
        guard let base = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: size) else {
            return .systemFont(ofSize: size, weight: wght >= 600 ? .semibold : (wght >= 500 ? .medium : .regular))
        }
        var attrs: [UIFontDescriptor.AttributeName: Any] = [
            .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "PingFangSC-Regular"])],
        ]
        if wght != 400 {
            attrs[UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)] =
                [NSNumber(value: 0x77676874): NSNumber(value: Double(wght))]
        }
        return UIFont(descriptor: base.fontDescriptor.addingAttributes(attrs), size: size)
    }
}


struct LXDrawerSpec {
    var w: CGFloat = 300
    var title = "__LX_TITLE__"
    var since = ""
    var days: Int? = nil
    var noteText = ""
    var noteTs = ""
    var items: [(menu: String, name: String)] = [
        ("moments", "Moments"), ("archive", "Archive"),
        ("calls", "Call log"), ("artifacts", "Artifacts"),
        ("gallery", "Gallery"), ("memory", "Memory"), ("library", "Library"), ("terminal", "Terminal"),
    ]
    var sessions: [(sid: String, title: String, active: Bool, pinned: Bool, cat: String)] = []
    var hasAva = false
    var sig = "default"

    static let nativeMenus: Set<String> = ["calls", "artifacts", "terminal", "archive"]

    static let key = "lx.drawer.spec"
    static func from(_ d: [String: Any]) -> LXDrawerSpec {
        var s = LXDrawerSpec()
        if let w = (d["w"] as? NSNumber)?.doubleValue, w > 100 { s.w = CGFloat(w) }
        if let t = d["title"] as? String, !t.isEmpty { s.title = t }
        s.since = (d["since"] as? String) ?? ""
        if let n = d["days"] as? NSNumber { s.days = n.intValue }
        if LustreConfig.webless, let n = daysSince(s.since) { s.days = n }
        s.noteText = (d["noteText"] as? String) ?? ""
        s.noteTs = (d["noteTs"] as? String) ?? ""
        if let arr = d["items"] as? [[String: Any]], !arr.isEmpty {
            s.items = arr.compactMap { (r: [String: Any]) -> (menu: String, name: String)? in
                guard let m = r["menu"] as? String, !m.isEmpty else { return nil }
                return (menu: m, name: (r["name"] as? String) ?? m)
            }
        }
        if LustreConfig.webless { s.items = s.items.filter { nativeMenus.contains($0.menu) } }
        if let arr = d["sessions"] as? [[String: Any]] {
            s.sessions = arr.compactMap { (r: [String: Any]) -> (sid: String, title: String, active: Bool, pinned: Bool, cat: String)? in
                guard let id = r["sid"] as? String else { return nil }
                return (sid: id, title: (r["title"] as? String) ?? "新对话",
                        active: (r["active"] as? Bool) ?? false, pinned: (r["pinned"] as? Bool) ?? false,
                        cat: (r["cat"] as? String) ?? "")
            }
        }
        s.hasAva = (d["hasAva"] as? Bool) ?? false
        if let data = try? JSONSerialization.data(withJSONObject: d, options: [.sortedKeys]),
           let str = String(data: data, encoding: .utf8) { s.sig = str }
        return s
    }
    static func load() -> LXDrawerSpec {
        if let data = UserDefaults.standard.data(forKey: key),
           let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] { return from(d) }
        var s = LXDrawerSpec()
        if LustreConfig.webless { s.items = s.items.filter { nativeMenus.contains($0.menu) } }
        return s
    }
    static func daysSince(_ since: String) -> Int? {
        let parts = since.split(whereSeparator: { $0 == "/" || $0 == "-" || $0 == "." }).compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let start = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        let today = cal.startOfDay(for: Date())
        return max(0, cal.dateComponents([.day], from: start, to: today).day ?? 0)
    }
    static func save(_ d: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(d), let data = try? JSONSerialization.data(withJSONObject: d) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum LXSessionsAPI {
    private static func req(_ path: String, _ method: String = "GET", _ body: [String: Any]? = nil) -> URLRequest? {
        guard let u = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: u)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 15
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private static func esc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? s
    }

    static func refreshNote() {
        guard let r = req("/app/note") else { return }
        URLSession.shared.dataTask(with: r) { d, _, _ in
            guard let d, let obj = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return }
            var tsTxt = ""
            if let raw = obj["ts"] as? String, !raw.isEmpty {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let dt = f1.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
                    let df = DateFormatter()
                    df.dateFormat = "M/d HH:mm"
                    df.timeZone = TimeZone(identifier: "Asia/Shanghai")
                    tsTxt = df.string(from: dt)
                }
            }
            applyNote((obj["text"] as? String) ?? "", tsTxt)
        }.resume()
    }
    static func setNote(_ text: String) {
        applyNote(text, "")
        guard let r = req("/app/note", "POST", ["text": text]) else { return }
        URLSession.shared.dataTask(with: r).resume()
    }
    private static func applyNote(_ text: String, _ ts: String) {
        DispatchQueue.main.async {
            var d: [String: Any] = [:]
            if let old = UserDefaults.standard.data(forKey: LXDrawerSpec.key),
               let o = (try? JSONSerialization.jsonObject(with: old)) as? [String: Any] { d = o }
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if (d["noteText"] as? String) == t, (d["noteTs"] as? String) == ts { return }
            d["noteText"] = t
            d["noteTs"] = ts
            LXDrawer.update(d)
        }
    }
    static func refresh() {
        if LustreConfig.webless { refreshNote() }
        guard let r = req("/app/sessions") else { return }
        URLSession.shared.dataTask(with: r) { d, _, _ in
            guard let d,
                  let obj = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let arr = obj["sessions"] as? [[String: Any]] else { return }
            apply(arr)
        }.resume()
    }

    static var personaBySid: [String: String] = UserDefaults.standard
        .dictionary(forKey: "lx.personaBySid") as? [String: String] ?? [:]
    static var modelBySid: [String: String] = UserDefaults.standard
        .dictionary(forKey: "lx.modelBySid") as? [String: String] ?? [:]

    static func apply(_ arr: [[String: Any]]) {
        var pm: [String: String] = [:]
        var mm: [String: String] = [:]
        for s in arr {
            if let id = s["id"] as? String, let p = s["persona"] as? String { pm[id] = p }
            if let id = s["id"] as? String, let m = s["model"] as? String, !m.isEmpty { mm[id] = m }
        }
        if !mm.isEmpty {
            modelBySid = mm
            UserDefaults.standard.set(mm, forKey: "lx.modelBySid")
            DispatchQueue.main.async { NativeInputPlugin.live?.refreshModelTitle() }
        }
        if !pm.isEmpty {
            personaBySid = pm
            UserDefaults.standard.set(pm, forKey: "lx.personaBySid")
        }
        let active = ChatListPlugin.live?.data.session
            ?? UserDefaults.standard.string(forKey: "lx.sessionPick") ?? "__legacy__"
        func row(_ id: String, _ title: String, _ pinned: Bool) -> [String: Any] {
            ["sid": id, "title": title, "active": id == active, "pinned": pinned, "cat": title]
        }
        let real = arr.compactMap { s -> (id: String, title: String, pinned: Bool)? in
            guard let id = s["id"] as? String, !id.isEmpty else { return nil }
            return (id, (s["title"] as? String) ?? "新对话",
                    ((s["pinned"] as? NSNumber)?.intValue ?? 0) != 0)
        }
        // 0925:两位的对话标题跟备注走(设过备注就用备注)
        var rows: [[String: Any]] = real.filter { $0.id == "yan-main" }.map { row($0.id, LXNick.yanSet ?? $0.title, $0.pinned) }
        rows.append(row("__legacy__", LXNick.zhaoSet ?? "__LX_ZHAO2__", false))
        rows += real.filter { $0.id != "yan-main" }.map { row($0.id, $0.title, $0.pinned) }
        DispatchQueue.main.async {
            var d: [String: Any] = [:]
            if let old = UserDefaults.standard.data(forKey: LXDrawerSpec.key),
               let o = (try? JSONSerialization.jsonObject(with: old)) as? [String: Any] { d = o }
            d["sessions"] = rows
            LXDrawer.update(d)
        }
    }

    static func markActive(_ sid: String) {
        DispatchQueue.main.async {
            guard let old = UserDefaults.standard.data(forKey: LXDrawerSpec.key),
                  var d = (try? JSONSerialization.jsonObject(with: old)) as? [String: Any],
                  var rows = d["sessions"] as? [[String: Any]], !rows.isEmpty else { return }
            for i in rows.indices { rows[i]["active"] = ((rows[i]["sid"] as? String) ?? "") == sid }
            d["sessions"] = rows
            LXDrawer.update(d)
        }
    }

    static func rememberModel(_ sid: String, _ model: String) {
        modelBySid[sid] = model
        UserDefaults.standard.set(modelBySid, forKey: "lx.modelBySid")
    }

    static func pin(_ sid: String, on: Bool) { patch(sid, ["pinned": on ? 1 : 0]) }
    static func rename(_ sid: String, title: String) { patch(sid, ["title": title]) }

    private static func patch(_ sid: String, _ body: [String: Any]) {
        guard let r = req("/app/sessions/" + esc(sid), "PATCH", body) else { return }
        URLSession.shared.dataTask(with: r) { d, _, _ in take(d) }.resume()
    }

    static func delete(_ sid: String) {
        guard let r = req("/app/sessions/" + esc(sid), "DELETE") else { return }
        URLSession.shared.dataTask(with: r) { d, _, _ in
            take(d)
            if ChatListPlugin.live?.data.session == sid {
                DispatchQueue.main.async { ChatListPlugin.live?.switchTo("__legacy__") }
            }
        }.resume()
    }

    static func create(title: String) { create(body: ["title": title, "kind": "cc"]) }
    static func create(kind: String) {
        switch kind {
        case "zhao": create(body: ["title": "书房 · 新对话", "activate": true, "persona": "zhao"])
        case "api":
            DrawerPlugin.askText(title: "模型名(智谱开放平台的模型ID)", text: "glm-4.6") { t in
                let m = t.trimmingCharacters(in: .whitespaces)
                create(body: ["kind": "api", "model": m.isEmpty ? "glm-4.6" : m, "activate": true])
            }
        default: create(body: ["title": "卧室 · 新对话", "activate": true, "persona": "yan"])
        }
    }
    static func create(body: [String: Any]) {
        guard let r = req("/app/sessions", "POST", body) else { return }
        URLSession.shared.dataTask(with: r) { d, _, _ in
            take(d)
            guard let d,
                  let obj = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return }
            let sid = (obj["active_session"] as? String)
                ?? ((obj["created"] as? [String: Any])?["id"] as? String) ?? ""
            guard !sid.isEmpty else { return }
            DispatchQueue.main.async { ChatListPlugin.live?.switchTo(sid) }
        }.resume()
    }

    private static func take(_ d: Data?) {
        guard let d, let obj = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let arr = obj["sessions"] as? [[String: Any]] else { refresh(); return }
        apply(arr)
    }
}


final class LXDrawerItem: UIControl {
    let nameL = UILabel()
    private let iconV = UIImageView()
    init(icon: UIImage, name: String, tint: LXDrawerTint) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        layer.cornerRadius = 10
        iconV.translatesAutoresizingMaskIntoConstraints = false
        iconV.image = icon; iconV.tintColor = tint.icon; iconV.contentMode = .center
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.font = LXDrawerTint.font(15, wght: 500); nameL.textColor = tint.text; nameL.text = name
        for v in [iconV, nameL] { v.isUserInteractionEnabled = false; addSubview(v) }
        NSLayoutConstraint.activate([
            iconV.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconV.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconV.widthAnchor.constraint(equalToConstant: 20),
            iconV.heightAnchor.constraint(equalToConstant: 20),
            nameL.leadingAnchor.constraint(equalTo: iconV.trailingAnchor, constant: 12),
            nameL.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameL.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(white: 0, alpha: 0.05) : .clear }
    }
}

final class LXDrawerSessionRow: UIControl {
    let sid: String, cat: String, pinned: Bool
    private let nameL = UILabel(), pinV = UIImageView()
    private let activeBg: UIColor?
    init(sid: String, title: String, active: Bool, pinned: Bool, cat: String, tint: LXDrawerTint) {
        self.sid = sid; self.cat = cat; self.pinned = pinned
        activeBg = active ? tint.segTrack : nil
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 38).isActive = true
        layer.cornerRadius = 10
        backgroundColor = activeBg ?? .clear
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.font = LXDrawerTint.font(14, wght: 500); nameL.textColor = tint.text; nameL.text = title
        nameL.lineBreakMode = .byTruncatingTail
        pinV.translatesAutoresizingMaskIntoConstraints = false
        pinV.image = LXDrawerIcons.image("pin", LXDrawerIcons.pin, size: 13, stroke: 0)
        pinV.tintColor = tint.faint; pinV.isHidden = !pinned
        for v in [nameL, pinV] { v.isUserInteractionEnabled = false; addSubview(v) }
        NSLayoutConstraint.activate([
            nameL.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            nameL.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinV.leadingAnchor.constraint(equalTo: nameL.trailingAnchor, constant: 10),
            pinV.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pinV.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinV.widthAnchor.constraint(equalToConstant: pinned ? 13 : 0),
            pinV.heightAnchor.constraint(equalToConstant: 13),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? UIColor(white: 0, alpha: 0.04) : (activeBg ?? .clear) }
    }
}

final class LXDrawerPop: UIView {
    init(tint: LXDrawerTint, header: String?, entries: [(label: String, danger: Bool, act: () -> Void)], shadowA: Float) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor(red: 74/255, green: 93/255, blue: 108/255, alpha: 1).cgColor
        layer.shadowOpacity = shadowA; layer.shadowOffset = CGSize(width: 0, height: 8); layer.shadowRadius = 12
        let inner = UIStackView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        inner.axis = .vertical
        inner.backgroundColor = tint.bg
        inner.layer.cornerRadius = 12; inner.clipsToBounds = true
        inner.layer.borderWidth = 1; inner.layer.borderColor = tint.cardLine.cgColor
        addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: topAnchor), inner.bottomAnchor.constraint(equalTo: bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: leadingAnchor), inner.trailingAnchor.constraint(equalTo: trailingAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: header == nil ? 120 : 128),
        ])
        if let h = header, !h.isEmpty {
            let l = UILabel()
            l.font = LXDrawerTint.font(11); l.textColor = tint.faint; l.text = h
            let wrap = UIView(); wrap.translatesAutoresizingMaskIntoConstraints = false
            l.translatesAutoresizingMaskIntoConstraints = false
            wrap.addSubview(l)
            NSLayoutConstraint.activate([
                l.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 9),
                l.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
                l.trailingAnchor.constraint(lessThanOrEqualTo: wrap.trailingAnchor, constant: -14),
                l.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -5),
            ])
            inner.addArrangedSubview(wrap)
        }
        for (i, e) in entries.enumerated() {
            if i > 0 {
                let sep = UIView(); sep.translatesAutoresizingMaskIntoConstraints = false
                sep.backgroundColor = tint.hairline
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                inner.addArrangedSubview(sep)
            }
            let b = UIButton(type: .custom)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.contentHorizontalAlignment = .left
            b.contentEdgeInsets = UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 16)
            b.titleLabel?.font = LXDrawerTint.font(14)
            b.setTitle(e.label, for: .normal)
            b.setTitleColor(e.danger ? UIColor(red: 0xC0/255, green: 0x53/255, blue: 0x3F/255, alpha: 1) : tint.text, for: .normal)
            let act = e.act
            b.addAction(UIAction { _ in act() }, for: .touchUpInside)
            inner.addArrangedSubview(b)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class LXDrawerNoteInner: UIView {
    let shape = CAShapeLayer(), border = CAShapeLayer()
    var onPath: ((CGPath) -> Void)?
    private var lastSize = CGSize.zero
    override func layoutSubviews() {
        super.layoutSubviews()
        let r = bounds
        guard r.width > 1, r.height > 1, r.size != lastSize else { return }
        lastSize = r.size
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: r.width - 14, y: 0))
        path.addArc(withCenter: CGPoint(x: r.width - 14, y: 14), radius: 14, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: r.width, y: r.height - 14))
        path.addArc(withCenter: CGPoint(x: r.width - 14, y: r.height - 14), radius: 14, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: 14, y: r.height))
        path.addArc(withCenter: CGPoint(x: 14, y: r.height - 14), radius: 14, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: 4))
        path.addArc(withCenter: CGPoint(x: 4, y: 4), radius: 4, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        path.close()
        shape.path = path.cgPath; border.path = path.cgPath
        onPath?(path.cgPath)
    }
}


final class LXDrawerView: UIView {
    var onAct: ((String, String) -> Void)?
    private let page = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let bar = UIView()
    private var pageW: NSLayoutConstraint!
    private var barBottomC: NSLayoutConstraint!
    private(set) var tint = LXDrawerTint.of("moon")
    private(set) var spec = LXDrawerSpec()
    private var sig = ""
    private var popOverlay: UIControl?
    private var noteTextL: UILabel?
    private var noteMoreL: UILabel?
    private var noteExpanded = false
    private(set) var titleL: UILabel?
    private(set) var firstItem: UIView?
    private(set) var sessionsHead: UIView?
    private(set) var pill: UIView?
    private(set) var gear: UIView?

    override class var layerClass: AnyClass { CAGradientLayer.self }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        page.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        scroll.contentInsetAdjustmentBehavior = .never
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(page); page.addSubview(scroll); scroll.addSubview(stack); page.addSubview(bar)
        pageW = page.widthAnchor.constraint(equalToConstant: 300)
        barBottomC = bar.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -50)
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: leadingAnchor),
            page.topAnchor.constraint(equalTo: topAnchor),
            page.bottomAnchor.constraint(equalTo: bottomAnchor),
            pageW,
            scroll.topAnchor.constraint(equalTo: page.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: page.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: page.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: page.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
            bar.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 22),
            bar.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -22),
            bar.heightAnchor.constraint(equalToConstant: 48),
            barBottomC,
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        applyInsets()
    }
    private func applyInsets() {
        let oldTop = scroll.contentInset.top
        let atTop = scroll.contentOffset.y <= -oldTop + 1
        scroll.contentInset = UIEdgeInsets(top: safeAreaInsets.top + 20, left: 0, bottom: safeAreaInsets.bottom + 86, right: 0)
        barBottomC.constant = -(safeAreaInsets.bottom + 16)
        if atTop { scrollToTop() }
    }
    func scrollToTop() {
        scroll.setContentOffset(CGPoint(x: 0, y: -scroll.contentInset.top), animated: false)
    }

    func apply(_ s: LXDrawerSpec, moon: String) {
        LXAvatarStore.loadDisk()
        let ava = LXAvatarStore.images["human"]
        let newSig = s.sig + "|" + moon + "|" + (ava == nil ? "-" : "A\(Int(ava!.size.width))")
        guard newSig != sig else { return }
        sig = newSig
        tint = LXDrawerTint.of(moon)
        spec = s
        pageW.constant = s.w
        if let g = layer as? CAGradientLayer {
            g.colors = tint.wall.map { $0.cgColor }
            g.locations = tint.wallStops
            g.startPoint = CGPoint(x: 0.5, y: 0); g.endPoint = CGPoint(x: 0.5, y: 1)
        }
        rebuild(avatar: ava)
    }

    private func rebuild(avatar: UIImage?) {
        dismissPop()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        bar.subviews.forEach { $0.removeFromSuperview() }
        titleL = nil; firstItem = nil; sessionsHead = nil; pill = nil; gear = nil
        noteTextL = nil; noteMoreL = nil; noteExpanded = false

        let head = UIView(); head.translatesAutoresizingMaskIntoConstraints = false
        head.heightAnchor.constraint(equalToConstant: 8).isActive = true
        stack.addArrangedSubview(head)

        stack.addArrangedSubview(buildHero())
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(buildList())
        stack.addArrangedSubview(buildSessions())
        buildBar(avatar: avatar)
        applyInsets()
    }

    private func buildHero() -> UIView {
        let hero = UIView(); hero.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel(); title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 26, weight: .medium)
        title.textColor = tint.title
        title.attributedText = NSAttributedString(string: spec.title, attributes: [.kern: -0.26])
        title.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(titleTap))
        title.addGestureRecognizer(tap)
        titleL = title
        let since = UILabel(); since.translatesAutoresizingMaskIntoConstraints = false
        since.font = LXDrawerTint.font(12); since.textColor = tint.faint; since.text = spec.since
        let days = UIView(); days.translatesAutoresizingMaskIntoConstraints = false
        let num = UILabel(); num.translatesAutoresizingMaskIntoConstraints = false
        num.font = LXDrawerTint.font(22, wght: 500); num.textColor = tint.text
        num.text = spec.days.map { String($0) } ?? ""
        let lab = UILabel(); lab.translatesAutoresizingMaskIntoConstraints = false
        lab.font = LXDrawerTint.font(12); lab.textColor = tint.faint; lab.text = "Days together"
        days.addSubview(num); days.addSubview(lab)
        days.isHidden = spec.days == nil
        hero.addSubview(title); hero.addSubview(since); hero.addSubview(days)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: hero.topAnchor),
            title.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -8),
            title.heightAnchor.constraint(equalToConstant: 31),
            since.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            since.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            since.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            since.heightAnchor.constraint(equalToConstant: 18),
            days.topAnchor.constraint(equalTo: since.bottomAnchor, constant: 8),
            days.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            days.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            days.heightAnchor.constraint(equalToConstant: 24),
            days.bottomAnchor.constraint(equalTo: hero.bottomAnchor),
            num.leadingAnchor.constraint(equalTo: days.leadingAnchor),
            num.topAnchor.constraint(equalTo: days.topAnchor),
            num.heightAnchor.constraint(equalToConstant: 22),
            lab.leadingAnchor.constraint(equalTo: num.trailingAnchor, constant: 6),
            lab.lastBaselineAnchor.constraint(equalTo: num.lastBaselineAnchor),
        ])
        if !spec.noteText.isEmpty { hero.addSubview(buildNote(in: hero)) }
        return hero
    }

    private func buildNote(in hero: UIView) -> UIView {
        let W = UIScreen.main.bounds.width
        let noteW = min(0.44 * W, 180)
        let top = -min(38, max(24, 0.08 * W))
        let box = UIView(); box.translatesAutoresizingMaskIntoConstraints = false
        box.layer.shadowColor = tint.shadow.withAlphaComponent(1).cgColor
        box.layer.shadowOpacity = Float(tint.shadow.cgColor.alpha)
        box.layer.shadowOffset = CGSize(width: 0, height: 18); box.layer.shadowRadius = 23
        let inner = LXDrawerNoteInner(); inner.translatesAutoresizingMaskIntoConstraints = false
        inner.backgroundColor = tint.composerBg
        inner.border.fillColor = nil; inner.border.strokeColor = tint.hairline.cgColor; inner.border.lineWidth = 2
        inner.layer.mask = inner.shape
        inner.layer.addSublayer(inner.border)
        inner.onPath = { [weak box] p in box?.layer.shadowPath = p }
        box.addSubview(inner)
        let pin = UIView(); pin.translatesAutoresizingMaskIntoConstraints = false
        pin.backgroundColor = tint.accent; pin.layer.cornerRadius = 6.5
        pin.layer.shadowColor = UIColor.black.cgColor; pin.layer.shadowOpacity = 0.25
        pin.layer.shadowOffset = CGSize(width: 0, height: 2); pin.layer.shadowRadius = 2
        box.addSubview(pin)
        let label = UILabel(); label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LXDrawerTint.font(10); label.textColor = tint.faint
        label.attributedText = NSAttributedString(string: "便签", attributes: [.kern: 1.4])
        let text = UILabel(); text.translatesAutoresizingMaskIntoConstraints = false
        text.font = LXDrawerTint.font(13); text.textColor = tint.text
        text.numberOfLines = 5; text.lineBreakMode = .byTruncatingTail
        let ps = NSMutableParagraphStyle(); ps.minimumLineHeight = 20.8; ps.maximumLineHeight = 20.8
        text.attributedText = NSAttributedString(string: spec.noteText, attributes: [.paragraphStyle: ps])
        let more = UILabel(); more.translatesAutoresizingMaskIntoConstraints = false
        more.font = LXDrawerTint.font(10); more.textColor = tint.faint
        more.attributedText = NSAttributedString(string: "…点开看全部", attributes: [.kern: 1.0])
        let ts = UILabel(); ts.translatesAutoresizingMaskIntoConstraints = false
        ts.font = LXDrawerTint.font(10); ts.textColor = tint.faint; ts.textAlignment = .right; ts.text = spec.noteTs
        let del = UIButton(type: .custom); del.translatesAutoresizingMaskIntoConstraints = false
        del.setImage(LXDrawerIcons.image("x", LXDrawerIcons.cross, size: 12, stroke: 2.5), for: .normal)
        del.tintColor = tint.faint; del.alpha = 0.5
        del.addAction(UIAction { [weak self] _ in self?.onAct?("noteDel", "") }, for: .touchUpInside)
        for v in [label, text, more, ts, del] { inner.addSubview(v) }
        let textW = noteW - 28
        let full = (spec.noteText as NSString).boundingRect(with: CGSize(width: textW, height: 10_000),
                                                             options: [.usesLineFragmentOrigin], attributes: [.font: text.font!, .paragraphStyle: ps], context: nil).height
        more.isHidden = full <= 5 * 20.8 + 2
        noteTextL = text; noteMoreL = more
        NSLayoutConstraint.activate([
            box.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -8),
            box.topAnchor.constraint(equalTo: hero.topAnchor, constant: top),
            box.widthAnchor.constraint(equalToConstant: noteW),
            inner.topAnchor.constraint(equalTo: box.topAnchor), inner.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            inner.leadingAnchor.constraint(equalTo: box.leadingAnchor), inner.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            pin.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 10),
            pin.topAnchor.constraint(equalTo: box.topAnchor, constant: -7),
            pin.widthAnchor.constraint(equalToConstant: 13), pin.heightAnchor.constraint(equalToConstant: 13),
            label.topAnchor.constraint(equalTo: inner.topAnchor, constant: 13),
            label.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 14),
            text.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            text.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 14),
            text.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -14),
            more.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 3),
            more.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            ts.topAnchor.constraint(equalTo: more.isHidden ? text.bottomAnchor : more.bottomAnchor, constant: 6),
            ts.leadingAnchor.constraint(equalTo: text.leadingAnchor),
            ts.trailingAnchor.constraint(equalTo: text.trailingAnchor),
            ts.bottomAnchor.constraint(equalTo: inner.bottomAnchor, constant: -11),
            del.trailingAnchor.constraint(equalTo: inner.trailingAnchor, constant: -6),
            del.topAnchor.constraint(equalTo: inner.topAnchor, constant: 6),
            del.widthAnchor.constraint(equalToConstant: 20), del.heightAnchor.constraint(equalToConstant: 20),
        ])
        box.transform = CGAffineTransform(rotationAngle: 2.2 * .pi / 180)
        let tap = UITapGestureRecognizer(target: self, action: #selector(noteTap))
        box.addGestureRecognizer(tap)
        return box
    }
    @objc private func noteTap() {
        noteExpanded.toggle()
        noteTextL?.numberOfLines = noteExpanded ? 0 : 5
        if noteExpanded { noteMoreL?.isHidden = true }
        else if let t = noteTextL, let m = noteMoreL {
            let ps = NSMutableParagraphStyle(); ps.minimumLineHeight = 20.8; ps.maximumLineHeight = 20.8
            let full = (spec.noteText as NSString).boundingRect(with: CGSize(width: t.bounds.width, height: 10_000),
                                                                 options: [.usesLineFragmentOrigin], attributes: [.font: t.font!, .paragraphStyle: ps], context: nil).height
            m.isHidden = full <= 5 * 20.8 + 2
        }
    }
    @objc private func titleTap() { onAct?("title", "") }

    private func buildList() -> UIView {
        let list = UIView(); list.translatesAutoresizingMaskIntoConstraints = false
        let line = UIView(); line.translatesAutoresizingMaskIntoConstraints = false
        line.backgroundColor = tint.hairline
        let items = UIStackView(); items.translatesAutoresizingMaskIntoConstraints = false
        items.axis = .vertical; items.spacing = 2
        for it in spec.items {
            let row = LXDrawerItem(icon: LXDrawerIcons.menuIcon(it.menu), name: it.name, tint: tint)
            let key = it.menu
            row.addAction(UIAction { [weak self] _ in self?.onAct?("menu", key) }, for: .touchUpInside)
            items.addArrangedSubview(row)
            if firstItem == nil { firstItem = row }
        }
        list.addSubview(line); list.addSubview(items)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: list.topAnchor),
            line.leadingAnchor.constraint(equalTo: list.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: list.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            items.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 8),
            items.leadingAnchor.constraint(equalTo: list.leadingAnchor, constant: 4),
            items.trailingAnchor.constraint(equalTo: list.trailingAnchor, constant: -4),
            items.bottomAnchor.constraint(equalTo: list.bottomAnchor),
        ])
        return list
    }

    private func buildSessions() -> UIView {
        let sec = UIView(); sec.translatesAutoresizingMaskIntoConstraints = false
        let head = UIView(); head.translatesAutoresizingMaskIntoConstraints = false
        let t = UILabel(); t.translatesAutoresizingMaskIntoConstraints = false
        t.font = LXDrawerTint.font(12, wght: 500); t.textColor = tint.faint; t.text = "Chat"
        head.addSubview(t)
        sessionsHead = head
        let rows = UIStackView(); rows.translatesAutoresizingMaskIntoConstraints = false
        rows.axis = .vertical; rows.spacing = 1
        for s in spec.sessions {
            let row = LXDrawerSessionRow(sid: s.sid, title: s.title, active: s.active, pinned: s.pinned, cat: s.cat, tint: tint)
            let sid = s.sid
            row.addAction(UIAction { [weak self] _ in self?.onAct?("session", sid) }, for: .touchUpInside)
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(rowLongPress(_:)))
            lp.minimumPressDuration = 0.52
            row.addGestureRecognizer(lp)
            rows.addArrangedSubview(row)
        }
        sec.addSubview(head); sec.addSubview(rows)
        NSLayoutConstraint.activate([
            head.topAnchor.constraint(equalTo: sec.topAnchor),
            head.leadingAnchor.constraint(equalTo: sec.leadingAnchor, constant: 4),
            head.trailingAnchor.constraint(equalTo: sec.trailingAnchor, constant: -4),
            head.heightAnchor.constraint(equalToConstant: 30),
            t.leadingAnchor.constraint(equalTo: head.leadingAnchor, constant: 12),
            t.topAnchor.constraint(equalTo: head.topAnchor, constant: 4),
            t.heightAnchor.constraint(equalToConstant: 18),
            rows.topAnchor.constraint(equalTo: head.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: head.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: head.trailingAnchor),
            rows.bottomAnchor.constraint(equalTo: sec.bottomAnchor),
        ])
        return sec
    }

    @objc private func rowLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let row = g.view as? LXDrawerSessionRow else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let sid = row.sid
        let entries: [(label: String, danger: Bool, act: () -> Void)] = [
            (row.pinned ? "取消置顶" : "置顶", false, { [weak self] in self?.dismissPop(); self?.onAct?("dsact", "pin:" + sid) }),
            // 0925 她的单:长按不给删除,怕误触删掉两位;只留置顶/重命名
            ("重命名", false, { [weak self] in self?.dismissPop(); self?.onAct?("dsact", "rename:" + sid) }),
        ]
        let pop = LXDrawerPop(tint: tint, header: row.cat, entries: entries, shadowA: 0.16)
        let r = row.convert(row.bounds, to: page)
        let top = min(r.maxY + 4, page.bounds.height - 150)
        let left = min(r.minX, UIScreen.main.bounds.width - 140)
        showPop(pop, constraints: { p in [
            p.topAnchor.constraint(equalTo: page.topAnchor, constant: top),
            p.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: left),
        ] })
    }

    private func buildBar(avatar: UIImage?) {
        let g = UIButton(type: .custom); g.translatesAutoresizingMaskIntoConstraints = false
        g.backgroundColor = tint.cardBg
        g.layer.cornerRadius = 24
        g.layer.shadowColor = UIColor(red: 74/255, green: 93/255, blue: 108/255, alpha: 1).cgColor
        g.layer.shadowOpacity = 0.16; g.layer.shadowOffset = CGSize(width: 0, height: 6); g.layer.shadowRadius = 9
        if let a = avatar, spec.hasAva {
            let iv = UIImageView(image: a); iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill; iv.layer.cornerRadius = 24; iv.clipsToBounds = true
            iv.isUserInteractionEnabled = false
            g.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: g.topAnchor), iv.bottomAnchor.constraint(equalTo: g.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: g.leadingAnchor), iv.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            ])
        } else {
            g.setImage(LXDrawerIcons.image("gear", LXDrawerIcons.gear, size: 21, stroke: 1.6), for: .normal)
            g.tintColor = tint.icon
        }
        g.addAction(UIAction { [weak self] _ in homePop(g); self?.onAct?("gear", "") }, for: .touchUpInside)
        let p = UIButton(type: .custom); p.translatesAutoresizingMaskIntoConstraints = false
        p.backgroundColor = tint.pillBg
        p.layer.cornerRadius = 24
        p.layer.shadowColor = UIColor(red: 74/255, green: 93/255, blue: 108/255, alpha: 1).cgColor
        p.layer.shadowOpacity = 0.22; p.layer.shadowOffset = CGSize(width: 0, height: 8); p.layer.shadowRadius = 12
        p.titleLabel?.font = LXDrawerTint.font(16, wght: 600)
        p.setTitle("＋\u{00A0}New chat", for: .normal)
        p.setTitleColor(tint.pillFg, for: .normal)
        p.contentEdgeInsets = UIEdgeInsets(top: 0, left: 26, bottom: 0, right: 26)
        p.addAction(UIAction { [weak self] _ in self?.toggleNewPop() }, for: .touchUpInside)
        bar.addSubview(g); bar.addSubview(p)
        NSLayoutConstraint.activate([
            g.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            g.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            g.widthAnchor.constraint(equalToConstant: 48), g.heightAnchor.constraint(equalToConstant: 48),
            p.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            p.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            p.heightAnchor.constraint(equalToConstant: 48),
        ])
        gear = g; pill = p
    }

    private func toggleNewPop() {
        if popOverlay != nil { dismissPop(); return }
        let kinds: [(String, String)] = [("zhao", "书房 · " + LXNick.zhao), ("cc", "卧室 · " + LXNick.yan), ("api", "API 对话")]
        let entries: [(label: String, danger: Bool, act: () -> Void)] = kinds.map { k in
            (k.1, false, { [weak self] in self?.dismissPop(); self?.onAct?("new", k.0) })
        }
        let pop = LXDrawerPop(tint: tint, header: nil, entries: entries, shadowA: 0.14)
        showPop(pop, constraints: { p in [
            p.centerXAnchor.constraint(equalTo: page.centerXAnchor),
            p.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -58),
        ] })
    }
    private func showPop(_ pop: LXDrawerPop, constraints: (UIView) -> [NSLayoutConstraint]) {
        dismissPop()
        let ov = UIControl(); ov.translatesAutoresizingMaskIntoConstraints = false
        ov.addAction(UIAction { [weak self] _ in self?.dismissPop() }, for: .touchUpInside)
        page.addSubview(ov); page.addSubview(pop)
        NSLayoutConstraint.activate([
            ov.topAnchor.constraint(equalTo: page.topAnchor), ov.bottomAnchor.constraint(equalTo: page.bottomAnchor),
            ov.leadingAnchor.constraint(equalTo: page.leadingAnchor), ov.trailingAnchor.constraint(equalTo: page.trailingAnchor),
        ] + constraints(pop))
        popOverlay = ov
    }
    func dismissPop() {
        guard let ov = popOverlay else { return }
        page.subviews.filter { $0 is LXDrawerPop }.forEach { $0.removeFromSuperview() }
        ov.removeFromSuperview()
        popOverlay = nil
    }

    func probeFrames() -> String {
        layoutIfNeeded()
        func f(_ v: UIView?, _ name: String) -> String {
            guard let v = v else { return "\(name)=nil" }
            let r = v.convert(v.bounds, to: self)
            return "\(name)@\(Int(r.minX.rounded())),\(Int(r.minY.rounded())) \(Int(r.width.rounded()))x\(Int(r.height.rounded()))"
        }
        return "safeTop=\(Int(safeAreaInsets.top)) pageW=\(Int(page.bounds.width)) " +
            [f(titleL, "title"), f(firstItem, "item0"), f(sessionsHead, "sessHead"), f(gear, "gear"), f(pill, "pill")].joined(separator: " ")
    }
}


/// 0925 她定的死规矩:往右滑能打开的,往左滑就能关上——抽屉页本身往左滑也收起(聊天页或 Home 哪个开着收哪个)。
final class LXDrawerSwipe: NSObject, UIGestureRecognizerDelegate {
    static let shared = LXDrawerSwipe()
    private var homeMode = false
    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let p = g as? UIPanGestureRecognizer, let v = p.view else { return false }
        let vel = p.velocity(in: v)
        return vel.x < 0 && abs(vel.x) > abs(vel.y) * 1.2
    }
    @objc func onPan(_ g: UIPanGestureRecognizer) {
        if g.state == .began { homeMode = HomePlugin.live?.homeDrawerOpen ?? false }
        if homeMode { HomePlugin.live?.homeClosePan(g) } else { ChatListPlugin.live?.closePanH(g) }
    }
}

enum LXDrawer {
    static var view: LXDrawerView?
    static var onAct: ((String, String) -> Void)?
    static var spec: LXDrawerSpec = LXDrawerSpec.load()

    static func show(host: UIView?) {
        guard let host = host else { return }
        LXSessionsAPI.refresh()
        let v: LXDrawerView
        if let ex = view, ex.superview === host {
            v = ex
        } else {
            view?.removeFromSuperview()
            v = LXDrawerView()
            v.onAct = { a, b in onAct?(a, b) }
            let swipe = UIPanGestureRecognizer(target: LXDrawerSwipe.shared, action: #selector(LXDrawerSwipe.onPan(_:)))
            swipe.delegate = LXDrawerSwipe.shared
            v.addGestureRecognizer(swipe)
            if let hv = host.subviews.first(where: { $0 is HomeView && !$0.isHidden }) {
                host.insertSubview(v, belowSubview: hv)
            } else {
                host.insertSubview(v, at: min(1, host.subviews.count))
            }
            LXStage.settle(host)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: host.topAnchor),
                v.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
            ])
            view = v
        }
        v.apply(spec, moon: RPSpec.moonState)
        if v.isHidden {
            v.isHidden = false
            v.scrollToTop()
        }
    }
    static func hide() {
        guard let v = view, !v.isHidden else { return }
        v.dismissPop()
        v.isHidden = true
    }
    static func place(below top: UIView?) {
        guard let v = view, let host = v.superview, let top = top, top.superview === host, top !== v else { return }
        host.insertSubview(v, belowSubview: top)
        LXStage.settle(host)
    }
    static var isShowing: Bool { !(view?.isHidden ?? true) }
    /// 0926:点通知进对话——和点这里的一行是同一个动作(切窗、收抽屉、离开 Home)
    static func pick(_ sid: String) {
        if let go = onAct { go("session", sid) } else { ChatListPlugin.live?.switchTo(sid) }
    }
    static func update(_ d: [String: Any]) {
        LXDrawerSpec.save(d)
        spec = LXDrawerSpec.from(d)
        if let v = view, !v.isHidden { v.apply(spec, moon: RPSpec.moonState) }
    }
}


@objc(DrawerPlugin)
public class DrawerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "DrawerPlugin"
    public let jsName = "Drawer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "drawerSpec", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "drawerStatus", returnType: CAPPluginReturnPromise),
    ]
    static weak var live: DrawerPlugin?
    private static let overlayMenus: Set<String> = ["moments", "timemachine", "archive", "gallery", "memory", "library", "terminal", "album"]

    public override func load() {
        Self.live = self
        LXDrawer.onAct = { [weak self] act, arg in
            if act == "menu", Self.overlayMenus.contains(arg), !(LustreConfig.webless && LXDrawerSpec.nativeMenus.contains(arg)) { LXDrawer.hide() }
            if act == "gear" { SysPlugin.live?.open() }
            if act == "title", LustreConfig.webless { HomePlugin.live?.openHomeNative(); return }
            if act == "menu", arg == "calls" || arg == "artifacts" { SysPlugin.live?.openPage(arg); return }
            if act == "menu", arg == "archive", LustreConfig.webless {
                let vc = LXArchiveVC()
                vc.modalPresentationStyle = .fullScreen
                DrawerPlugin.topVC()?.present(vc, animated: true)
                return
            }
            if act == "menu", arg == "terminal", LustreConfig.webless {
                let vc = LXTerminalVC()
                vc.modalPresentationStyle = .fullScreen
                DrawerPlugin.topVC()?.present(vc, animated: true)
                return
            }
            if act == "session" {
                ChatListPlugin.live?.switchTo(arg)
                self?.notifyListeners("drawerAct", data: ["act": "sessionPicked", "arg": arg])
                return
            }
            if act == "dsact" {
                let i = arg.firstIndex(of: ":")
                guard let i else { return }
                let kind = String(arg[arg.startIndex..<i])
                let sid = String(arg[arg.index(after: i)...])
                switch kind {
                case "pin":
                    let on = LXDrawer.spec.sessions.first(where: { $0.sid == sid })?.pinned ?? false
                    LXSessionsAPI.pin(sid, on: !on)
                case "rename" where sid == "yan-main" || sid == "__legacy__":
                    // 0925:两位的对话名就是备注——在这改等于改备注(来电、通知、App 里全跟着变)
                    let who = sid == "yan-main" ? "yan" : "zhao"
                    DrawerPlugin.askText(title: "改备注", text: who == "yan" ? LXNick.yan : LXNick.zhao) { t in
                        guard !t.isEmpty else { return }
                        LXNick.set(who, t) { _ in }
                    }
                case "rename":
                    let cur = LXDrawer.spec.sessions.first(where: { $0.sid == sid })?.title ?? ""
                    DrawerPlugin.askText(title: "重命名", text: cur) { t in
                        guard !t.isEmpty else { return }
                        LXSessionsAPI.rename(sid, title: t)
                    }
                case "delete":
                    DrawerPlugin.confirm(title: "删除这个对话？",
                                         message: "消息记录会保留，但列表里就没有了。") {
                        LXSessionsAPI.delete(sid)
                    }
                default: break
                }
                return
            }
            if act == "new" {
                if LustreConfig.webless { LXSessionsAPI.create(kind: arg); return }
                DrawerPlugin.askText(title: "新对话", text: "") { t in
                    LXSessionsAPI.create(title: t)
                }
                return
            }
            if act == "noteDel", LustreConfig.webless {
                LXSessionsAPI.setNote("")
                return
            }
            self?.notifyListeners("drawerAct", data: ["act": act, "arg": arg])
        }
    }

    static func previewProbe() {
        let fr = LXDrawer.view?.probeFrames() ?? "view=nil"
        let n = LXDrawer.spec
        HomePlugin.probeStatic("drawer-check", "showing=\(LXDrawer.isShowing) moon=\(RPSpec.moonState) items=\(n.items.count) sessions=\(n.sessions.count) days=\(n.days ?? -1) title=\(n.title) " + fr)
    }

    static func topVC() -> UIViewController? {
        var vc = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }

    static func askText(title: String, text: String, done: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            let a = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            a.addTextField { $0.text = text; $0.clearButtonMode = .whileEditing }
            a.addAction(UIAlertAction(title: "取消", style: .cancel))
            a.addAction(UIAlertAction(title: "好", style: .default) { _ in
                done((a.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            })
            topVC()?.present(a, animated: true)
        }
    }

    static func confirm(title: String, message: String, done: @escaping () -> Void) {
        DispatchQueue.main.async {
            let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "取消", style: .cancel))
            a.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in done() })
            topVC()?.present(a, animated: true)
        }
    }

    @objc func drawerSpec(_ call: CAPPluginCall) {
        var d: [String: Any] = [:]
        for (k, v) in call.options ?? [:] { if let ks = k as? String { d[ks] = v } }
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d),
              let clean = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            call.resolve(["ok": false]); return
        }
        DispatchQueue.main.async {
            LXDrawer.update(clean)
            call.resolve(["ok": true, "showing": LXDrawer.isShowing])
        }
    }

    @objc func drawerStatus(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["attached": LXDrawer.view != nil, "showing": LXDrawer.isShowing, "sig": LXDrawer.spec.sig.count])
        }
    }
}
