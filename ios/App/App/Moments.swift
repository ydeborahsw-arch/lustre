import UIKit
import PhotosUI
import ImageIO

// MARK: - 1005 朋友圈原生(她的单):照网页 index.html 的 #moPanel 一样搬过来
// 参数出处都是网页那份 CSS(.mo-* 1402–1549);颜色按 App 的(白天黑字、星芒色;当字用的蓝白天换成那支灰)。
// 接口照旧:GET /app/moments、POST /app/moment、/app/moment_delete、/app/moment_like、/app/moment_comment、/app/moment_cover;
// 他和昭发、赞、评论都从实时流里来(moment_new / moment_like / moment_comment / moment_del / moment_cover)。
// 预览里一条都不连服务器,用的是假数据。

struct LXMoment {
    struct Comment {
        let id: Int
        let ts: String
        let author: String
        let text: String
        let replyTo: Int?
    }
    let id: Int
    let ts: String
    let author: String
    let text: String
    let images: [String]
    var likes: [String: String]
    var comments: [Comment]

    init?(_ d: [String: Any]) {
        guard let id = (d["id"] as? NSNumber)?.intValue else { return nil }
        self.id = id
        ts = (d["ts"] as? String) ?? ""
        author = (d["author"] as? String) ?? "ai"
        text = (d["text"] as? String) ?? ""
        images = (d["images"] as? [String]) ?? []
        likes = (d["likes"] as? [String: String]) ?? [:]
        comments = ((d["comments"] as? [[String: Any]]) ?? []).compactMap { c in
            guard let cid = (c["id"] as? NSNumber)?.intValue else { return nil }
            return Comment(id: cid, ts: (c["ts"] as? String) ?? "", author: (c["author"] as? String) ?? "ai",
                           text: (c["text"] as? String) ?? "", replyTo: (c["reply_to"] as? NSNumber)?.intValue)
        }
    }

    var dict: [String: Any] {
        ["id": id, "ts": ts, "author": author, "text": text, "images": images, "likes": likes,
         "comments": comments.map { c -> [String: Any] in
             var o: [String: Any] = ["id": c.id, "ts": c.ts, "author": c.author, "text": c.text]
             if let r = c.replyTo { o["reply_to"] = r }
             return o
         }]
    }

    /// 圈里的名字:她=她的名字,他、昭=她给的备注
    static func name(_ author: String) -> String {
        switch author {
        case "human": return LXNick.human
        case "zhao": return LXNick.zhao
        default: return LXNick.yan
        }
    }

    /// 刚刚 / N分钟前 / N小时前 / 昨天 HH:mm / M月D日 HH:mm(上海时间,和网页 moAgo 一样)
    static func ago(_ ts: String) -> String {
        guard let t = parseTs(ts) else { return "" }
        let min = Int(Date().timeIntervalSince(t) / 60)
        if min < 1 { return "刚刚" }
        if min < 60 { return "\(min)分钟前" }
        let hr = min / 60
        if hr < 24 { return "\(hr)小时前" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        if hr < 48 { f.dateFormat = "HH:mm"; return "昨天 " + f.string(from: t) }
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: t)
    }

    static func parseTs(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        // 服务器的时间带 6 位小数,系统只认到 3 位:截掉多的再认
        if let dot = s.firstIndex(of: "."), let end = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            let frac = s[s.index(after: dot)..<end]
            let cut = String(s[..<dot]) + "." + String(frac.prefix(3)) + String(s[end...])
            if let d = f.date(from: cut) { return d }
        }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

// MARK: - 颜色、字

enum LXMomentInk {
    static var theme: LXChatTheme { ChatListPlugin.live?.theme ?? LXChatTheme() }
    static var bg: UIColor { theme.bg }
    static var text: UIColor { LXSheetInk.text }
    static var soft: UIColor { LXSheetInk.soft }
    static var faint: UIColor { LXSheetInk.faint }
    /// 名字、赞的人、评论里的人名(网页 --accent);白天星芒色当字看不清,用 App 白天那支灰
    static var accent: UIColor { theme.accentText }
    static var hair: UIColor { LXSheetInk.sep }
    static var card: UIColor { LXSheetInk.tile }
    static var primary: UIColor { theme.accent }
    static var primaryFg: UIColor { theme.accentFg }
    static var humanBg: UIColor { theme.me }
    static let press = UIColor(red: 140 / 255, green: 160 / 255, blue: 176 / 255, alpha: 0.09)
    static let box = UIColor(red: 127 / 255, green: 130 / 255, blue: 140 / 255, alpha: 0.09)
    static let dots = UIColor(red: 127 / 255, green: 130 / 255, blue: 140 / 255, alpha: 0.13)
    static let imgBg = UIColor(red: 125 / 255, green: 128 / 255, blue: 135 / 255, alpha: 0.10)

    static func font(_ size: CGFloat, _ wght: CGFloat = 400) -> UIFont { LXDrawerTint.font(size, wght: wght) }

    static func icon(_ key: String, size: CGFloat, stroke: CGFloat) -> UIImage {
        LXDrawerIcons.image("mo-" + key, parts[key] ?? [], size: size, stroke: stroke)
    }
    static let parts: [String: [LXSVG.Part]] = [
        "back": [.path("M15 5l-7 7 7 7")],
        "camera": [.path("M4 8.5A2.5 2.5 0 0 1 6.5 6h1.6l1.4-2h5l1.4 2h1.6A2.5 2.5 0 0 1 20 8.5v8A2.5 2.5 0 0 1 17.5 19h-11A2.5 2.5 0 0 1 4 16.5z"),
                   .circle(12, 12.5, 3.4)],
        "trash": [.path("M4 7h16M10 4.5h4M9.5 7.5l.6 12M14.5 7.5l-.6 12M6.5 7l1 13.2a1.6 1.6 0 0 0 1.6 1.5h5.8a1.6 1.6 0 0 0 1.6-1.5L17.5 7")],
        "heart": [.path("M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z")],
        "save": [.path("M12 4v11"), .path("M8 11.5l4 4 4-4"), .path("M5 19.5h14")],
        "star": [.path("M12 3.5c.8 5 3.5 7.7 8.5 8.5-5 .8-7.7 3.5-8.5 8.5-.8-5-3.5-7.7-8.5-8.5 5-.8 7.7-3.5 8.5-8.5Z", fill: true)],
    ]

    /// 行高按网页的 line-height 倍数
    static func para(_ font: UIFont, _ lh: CGFloat) -> NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = max(0, font.pointSize * lh - font.lineHeight)
        p.lineBreakMode = .byWordWrapping
        return p
    }
}

// MARK: - 网络

enum LXMomentNet {
    static func call(_ method: String, _ path: String, _ body: [String: Any]? = nil,
                     done: @escaping ([String: Any]?, Int) -> Void) {
        guard !LustreConfig.isPreview, !LustreConfig.secret.isEmpty, let u = URL(string: LustreConfig.apiBase + path) else {
            done(nil, 0); return
        }
        var r = URLRequest(url: u, timeoutInterval: 20)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        }
        URLSession.shared.dataTask(with: r) { d, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            DispatchQueue.main.async { done((200..<300).contains(code) ? obj : nil, code) }
        }.resume()
    }

    /// 图片存在服务器 uploads 里,只记文件名
    static func imageURL(_ name: String) -> URL? {
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: LustreConfig.apiBase + "/uploads/" + name + "?token=" + tok)
    }

    /// 传一张图,拿回服务器上的文件名(网页同样只留地址最后一段)
    static func upload(_ jpeg: Data, done: @escaping (String?) -> Void) {
        let name = "moment-\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        guard !LustreConfig.isPreview, !LustreConfig.secret.isEmpty,
              let u = URL(string: LustreConfig.apiBase + "/app/upload?name=" + name) else { done(nil); return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 60
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        URLSession.shared.uploadTask(with: r, from: jpeg) { d, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let obj = d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let url = (obj?["url"] as? String) ?? ""
            let file = url.split(separator: "/").last.map(String.init)
            DispatchQueue.main.async { done((200..<300).contains(code) && !url.isEmpty ? file : nil) }
        }.resume()
    }

    /// 选来的图压到长边 2048、JPEG 0.9(和聊天里发图一样),顺带一张 174 的小样给发布卡摆。
    /// 直接从相册给的文件缩,不先解开整张原图(一张 1200 万像素解开就是 48MB);后台线程跑
    static func prepare(_ src: CGImageSource) -> (data: Data, thumb: UIImage, big: UIImage)? {
        guard let big = LXMomentImage.shrink(src, 2048), let data = LXMomentImage.jpegData(big, 0.9),
              let small = LXMomentImage.shrink(src, 174) else { return nil }
        return (data, UIImage(cgImage: small), UIImage(cgImage: big))
    }
}

// MARK: - 图片(自己的缓存:聊天那份存的是 144 的小图,同一个地址会撞)

enum LXMomentImage {
    /// 内存里的(缩好的);满了系统自己丢旧的
    static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 96 << 20
        return c
    }()
    /// 图的宽高比(宽/高),单图那格按它定高;存在手机上,下次打开一开始就是对的高度。第一次没量到先按正方形
    private static let aspectKey = "lx.moments.aspect"
    private(set) static var aspect: [String: CGFloat] =
        ((UserDefaults.standard.dictionary(forKey: aspectKey) as? [String: Double]) ?? [:]).mapValues { CGFloat($0) }
    /// 只有单图那格会来记(九宫格是正方形用不着);记太多了从头记
    static func setAspect(_ name: String, _ a: CGFloat) {
        guard a > 0, abs((aspect[name] ?? 0) - a) > 0.001 else { return }
        if aspect.count >= 400 { aspect = [:] }
        aspect[name] = a
        if !LustreConfig.isPreview { UserDefaults.standard.set(aspect.mapValues { Double($0) }, forKey: aspectKey) }
    }
    /// 同一张正在下的:后来要的排队等同一次,不重复下
    private static var waiting: [String: [(UIImage?) -> Void]] = [:]

    /// 缩好的图也存一份在手机缓存目录里(先摆缓存:重开 App 图直接在,不用再下)
    private static let dir: URL? = {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let d = base.appendingPathComponent("lx-moments", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    /// 长边缩到 maxSide 像素(本来就小的不放大);ImageIO 只解需要的那么大,哪个线程都能跑
    static func shrink(_ src: CGImageSource, _ maxSide: CGFloat) -> CGImage? {
        var limit = Int(maxSide)
        if let p = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
           let w = (p[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
           let h = (p[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue, max(w, h) > 0 {
            limit = min(limit, max(w, h))
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func jpegData(_ cg: CGImage, _ q: CGFloat) -> Data? {
        let out = NSMutableData()
        guard let dst = CGImageDestinationCreateWithData(out as CFMutableData, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dst, cg, [kCGImageDestinationLossyCompressionQuality: q] as CFDictionary)
        return CGImageDestinationFinalize(dst) ? out as Data : nil
    }

    /// maxSide 是像素:单图 900、九宫格 720、封面 2000(屏幕 3 倍,够清楚)
    static func load(_ name: String, maxSide: CGFloat, done: @escaping (UIImage?) -> Void) {
        let key = "\(name)@\(Int(maxSide))"
        if let hit = cache.object(forKey: key as NSString) { done(hit); return }
        guard !LustreConfig.isPreview else { done(nil); return }
        if waiting[key] != nil { waiting[key]?.append(done); return }
        waiting[key] = [done]
        let file = dir?.appendingPathComponent(key.replacingOccurrences(of: "/", with: "_") + ".jpg")
        let url = LXMomentNet.imageURL(name)
        Task.detached(priority: .userInitiated) {
            var cg: CGImage?
            if let file, let src = CGImageSourceCreateWithURL(file as CFURL, nil) {
                cg = shrink(src, maxSide)
            }
            if cg == nil, let url, let (d, resp) = try? await URLSession.shared.data(from: url),
               (resp as? HTTPURLResponse)?.statusCode == 200, let src = CGImageSourceCreateWithData(d as CFData, nil) {
                cg = shrink(src, maxSide)
                if let c = cg, let file, let jpg = jpegData(c, 0.85) { try? jpg.write(to: file, options: .atomic) }
            }
            let img = cg.map { UIImage(cgImage: $0) }
            let cost = cg.map { $0.bytesPerRow * $0.height } ?? 0
            await MainActor.run {
                if let img { cache.setObject(img, forKey: key as NSString, cost: cost) }
                let all = waiting.removeValue(forKey: key) ?? []
                all.forEach { $0(img) }
            }
        }
    }
}

// MARK: - 图格:1 张=宽 68%、高按图(最高 300);2、4 张两列;其余三列;间隔 5,圆角 6

final class LXMomentGrid: UIView {
    var names: [String] = [] { didSet { rebuild() } }
    var onTap: ((String) -> Void)?
    /// 单图量到真比例要改高度时,先交给页面(她往下翻着时,眼前那条不跟着跳)
    var onResize: ((() -> Void) -> Void)?
    /// 离屏远了先放下图(列表不复用格子,图全留着会越翻越占内存);回来再从缓存摆上
    var live = true { didSet { if live != oldValue { live ? fill() : cells.forEach { $0.image = nil } } } }
    private var cells: [UIImageView] = []
    private var hC: NSLayoutConstraint!
    /// 图格的宽:屏宽 - 左 16 - 头像 42 - 间隔 11 - 右 16。数据一到就按它定高,不等排完再改(省得多跳一帧)
    static var width: CGFloat { UIScreen.main.bounds.width - 85 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        hC = heightAnchor.constraint(equalToConstant: 0)
        hC.priority = .defaultHigh
        hC.isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    private var side: CGFloat { names.count == 1 ? 900 : 720 }

    private func rebuild() {
        cells.forEach { $0.removeFromSuperview() }
        cells = names.map { name in
            let iv = UIImageView()
            iv.backgroundColor = LXMomentInk.imgBg
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 6
            iv.isUserInteractionEnabled = true
            iv.accessibilityIdentifier = name
            iv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
            addSubview(iv)
            return iv
        }
        place(bounds.width > 0 ? bounds.width : Self.width)
        if live { fill() }
    }

    private func fill() {
        let want = names
        for (i, name) in names.enumerated() {
            LXMomentImage.load(name, maxSide: side) { [weak self] img in
                guard let s = self, s.live, s.names == want, i < s.cells.count else { return }
                s.cells[i].image = img
                // 单图第一次量到宽高比:按真比例定一次高(以后记住了,一打开就是对的)
                if want.count == 1, let img, img.size.height > 0 {
                    let a = img.size.width / img.size.height
                    let changed = abs((LXMomentImage.aspect[name] ?? 1) - a) > 0.001
                    LXMomentImage.setAspect(name, a)
                    guard changed else { return }
                    let apply = { s.place(s.bounds.width > 0 ? s.bounds.width : Self.width) }
                    if let r = s.onResize { r(apply) } else { apply() }
                }
            }
        }
    }

    @objc private func tapped(_ g: UITapGestureRecognizer) {
        if let n = g.view?.accessibilityIdentifier { onTap?(n) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width > 0 { place(bounds.width) }
    }

    private func place(_ W: CGFloat) {
        guard W > 0, !cells.isEmpty else { if hC.constant != 0 { hC.constant = 0 }; return }
        var h: CGFloat = 0
        if cells.count == 1 {
            let w = floor(W * 0.68)
            let a = LXMomentImage.aspect[names[0]] ?? 1
            let ih = min(300, floor(w / max(0.05, a)))
            cells[0].frame = CGRect(x: 0, y: 0, width: w, height: ih)
            h = ih
        } else {
            let cols: CGFloat = (cells.count == 2 || cells.count == 4) ? 2 : 3
            let gap: CGFloat = 5
            let side = floor((W - gap * (cols - 1)) / cols)
            for (i, c) in cells.enumerated() {
                let r = CGFloat(i / Int(cols)), col = CGFloat(i % Int(cols))
                c.frame = CGRect(x: col * (side + gap), y: r * (side + gap), width: side, height: side)
                h = max(h, c.frame.maxY)
            }
        }
        if abs(hC.constant - h) > 0.5 { hC.constant = h }
    }
}

// MARK: - 一条动态

final class LXMomentCell: UIView, UITextFieldDelegate {
    private(set) var m: LXMoment
    weak var host: LXMomentsVC?
    private let ava = UIImageView()
    private let star = UIImageView()
    private let col = UIStackView()
    private let who = UILabel()
    private let body = UILabel()
    private let grid = LXMomentGrid()
    private let meta = UIView()
    private let when = UILabel()
    private let del = UIButton(type: .system)
    private let dots = UIButton(type: .custom)
    let ops = UIView()
    private let likeB = UIButton(type: .system)
    private let cmtB = UIButton(type: .system)
    private let opsLine = UIView()
    private let box = UIStackView()
    let cbox = UIView()
    let field = UITextField()
    private let sendB = UIButton(type: .system)
    private let line = UIView()
    var replyTo: Int?

    init(_ m: LXMoment) {
        self.m = m
        super.init(frame: .zero)
        build()
        configure(m)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // .mo-item:flex gap 11,padding 15 16 12,底线 1;.mo-ava 42,圆角 14%
        ava.translatesAutoresizingMaskIntoConstraints = false
        ava.layer.cornerRadius = 42 * 0.14
        ava.clipsToBounds = true
        ava.contentMode = .scaleAspectFill
        star.translatesAutoresizingMaskIntoConstraints = false
        star.image = LXMomentInk.icon("star", size: 24, stroke: 1)
        star.contentMode = .scaleAspectFit
        ava.addSubview(star)
        addSubview(ava)

        col.axis = .vertical
        col.alignment = .fill
        col.translatesAutoresizingMaskIntoConstraints = false
        addSubview(col)

        who.font = LXMomentInk.font(14.5, 600)
        body.numberOfLines = 0
        grid.onTap = { [weak self] n in self?.host?.showImage(n) }
        grid.onResize = { [weak self] apply in
            if let h = self?.host { h.keepPlace(apply) } else { apply() }
        }

        // .mo-meta:时间 12 / 垃圾桶 15 / "··" 36×22
        when.font = LXMomentInk.font(12)
        del.setImage(LXMomentInk.icon("trash", size: 15, stroke: 1.7), for: .normal)
        del.addAction(UIAction { [weak self] _ in guard let s = self else { return }; s.host?.askDelete(s.m.id) }, for: .touchUpInside)
        dots.layer.cornerRadius = 6
        dots.backgroundColor = LXMomentInk.dots
        for i in 0..<2 {
            let d = UIView(frame: CGRect(x: 36 / 2 - 4.5 - 2 + CGFloat(i) * (4.5 + 4), y: (22 - 4.5) / 2, width: 4.5, height: 4.5))
            d.layer.cornerRadius = 2.25
            d.isUserInteractionEnabled = false
            d.tag = 77
            dots.addSubview(d)
        }
        dots.addAction(UIAction { [weak self] _ in guard let s = self else { return }; s.host?.toggleOps(s) }, for: .touchUpInside)
        for v in [when, del, dots] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; meta.addSubview(v) }

        // .mo-ops:赞 / 评论 两个键,卡片底 + 细线,圆角 9
        ops.isHidden = true
        ops.alpha = 0
        ops.layer.cornerRadius = 9
        ops.layer.borderWidth = 1
        ops.layer.shadowColor = UIColor.black.cgColor
        ops.layer.shadowOpacity = 0.25
        ops.layer.shadowRadius = 14
        ops.layer.shadowOffset = CGSize(width: 0, height: 9)
        ops.translatesAutoresizingMaskIntoConstraints = false
        for b in [likeB, cmtB] {
            b.titleLabel?.font = LXMomentInk.font(13)
            b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
            b.translatesAutoresizingMaskIntoConstraints = false
            ops.addSubview(b)
        }
        likeB.imageEdgeInsets = UIEdgeInsets(top: 0, left: -3, bottom: 0, right: 3)
        likeB.addAction(UIAction { [weak self] _ in guard let s = self else { return }; s.host?.toggleLike(s.m.id) }, for: .touchUpInside)
        cmtB.addAction(UIAction { [weak self] _ in self?.openComment(replyTo: nil) }, for: .touchUpInside)
        cmtB.setTitle("评论", for: .normal)
        opsLine.translatesAutoresizingMaskIntoConstraints = false
        ops.addSubview(opsLine)

        NSLayoutConstraint.activate([
            meta.heightAnchor.constraint(equalToConstant: 22),
            when.leadingAnchor.constraint(equalTo: meta.leadingAnchor),
            when.centerYAnchor.constraint(equalTo: meta.centerYAnchor),
            del.leadingAnchor.constraint(equalTo: when.trailingAnchor, constant: 14 - 2),
            del.centerYAnchor.constraint(equalTo: meta.centerYAnchor),
            del.widthAnchor.constraint(equalToConstant: 19),
            del.heightAnchor.constraint(equalToConstant: 22),
            dots.trailingAnchor.constraint(equalTo: meta.trailingAnchor),
            dots.centerYAnchor.constraint(equalTo: meta.centerYAnchor),
            dots.widthAnchor.constraint(equalToConstant: 36),
            dots.heightAnchor.constraint(equalToConstant: 22),
            likeB.leadingAnchor.constraint(equalTo: ops.leadingAnchor),
            likeB.topAnchor.constraint(equalTo: ops.topAnchor),
            likeB.bottomAnchor.constraint(equalTo: ops.bottomAnchor),
            opsLine.leadingAnchor.constraint(equalTo: likeB.trailingAnchor),
            opsLine.widthAnchor.constraint(equalToConstant: 1),
            opsLine.topAnchor.constraint(equalTo: ops.topAnchor),
            opsLine.bottomAnchor.constraint(equalTo: ops.bottomAnchor),
            cmtB.leadingAnchor.constraint(equalTo: opsLine.trailingAnchor),
            cmtB.topAnchor.constraint(equalTo: ops.topAnchor),
            cmtB.bottomAnchor.constraint(equalTo: ops.bottomAnchor),
            cmtB.trailingAnchor.constraint(equalTo: ops.trailingAnchor),
        ])

        // .mo-box:赞的人 + 评论,底 rgba(127,130,140,.09),圆角 8
        box.axis = .vertical
        box.layer.cornerRadius = 8
        box.clipsToBounds = true
        box.backgroundColor = LXMomentInk.box

        // .mo-cbox:评论框(胶囊)+ 发送
        field.font = LXMomentInk.font(13.5)
        field.layer.cornerRadius = 16
        field.layer.borderWidth = 1
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .send
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        sendB.setTitle("发送", for: .normal)
        sendB.titleLabel?.font = LXMomentInk.font(13.5)
        sendB.contentEdgeInsets = UIEdgeInsets(top: 5, left: 17, bottom: 5, right: 17)
        sendB.layer.cornerRadius = 15
        sendB.translatesAutoresizingMaskIntoConstraints = false
        sendB.addAction(UIAction { [weak self] _ in self?.sendComment() }, for: .touchUpInside)
        cbox.addSubview(field)
        cbox.addSubview(sendB)
        cbox.isHidden = true
        let fieldH = field.heightAnchor.constraint(equalToConstant: 34)
        fieldH.priority = UILayoutPriority(999)   // 收起时让给栈给的 0 高,不打架
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cbox.leadingAnchor),
            field.topAnchor.constraint(equalTo: cbox.topAnchor),
            field.bottomAnchor.constraint(equalTo: cbox.bottomAnchor),
            fieldH,
            sendB.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8),
            sendB.trailingAnchor.constraint(equalTo: cbox.trailingAnchor),
            sendB.centerYAnchor.constraint(equalTo: cbox.centerYAnchor),
        ])
        sendB.setContentHuggingPriority(.required, for: .horizontal)
        sendB.setContentCompressionResistancePriority(.required, for: .horizontal)

        for v in [who, body, grid, meta, box, cbox] as [UIView] { col.addArrangedSubview(v) }
        // 小菜单挂在整格上(挂在时间行上会超出那一行,点不到),位置跟着"··"
        addSubview(ops)
        NSLayoutConstraint.activate([
            ops.trailingAnchor.constraint(equalTo: meta.trailingAnchor, constant: -44),
            ops.centerYAnchor.constraint(equalTo: meta.centerYAnchor),
        ])

        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            ava.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            ava.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            ava.widthAnchor.constraint(equalToConstant: 42),
            ava.heightAnchor.constraint(equalToConstant: 42),
            star.centerXAnchor.constraint(equalTo: ava.centerXAnchor),
            star.centerYAnchor.constraint(equalTo: ava.centerYAnchor),
            star.widthAnchor.constraint(equalToConstant: 42 * 0.56),
            star.heightAnchor.constraint(equalToConstant: 42 * 0.56),
            col.leadingAnchor.constraint(equalTo: ava.trailingAnchor, constant: 11),
            col.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            col.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            bottomAnchor.constraint(greaterThanOrEqualTo: ava.bottomAnchor, constant: 12),
            col.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
        ])
        paint()
    }

    /// 换成这一条的内容(只换这一格,别的不动)
    func configure(_ m: LXMoment) {
        self.m = m
        who.text = LXMoment.name(m.author)
        if m.text.isEmpty {
            body.isHidden = true
        } else {
            body.isHidden = false
            let f = LXMomentInk.font(15)
            body.attributedText = NSAttributedString(string: m.text, attributes: [
                .font: f, .foregroundColor: LXMomentInk.text, .paragraphStyle: LXMomentInk.para(f, 1.65)])
        }
        grid.isHidden = m.images.isEmpty
        if grid.names != m.images { grid.names = m.images }
        // 网页:名字下 2,图上 8,时间行上 8;没正文时名字到图 = 2 + 8
        col.setCustomSpacing(m.text.isEmpty ? 10 : 2, after: who)
        col.setCustomSpacing(8, after: body)
        col.setCustomSpacing(8, after: grid)
        col.setCustomSpacing(8, after: meta)
        col.setCustomSpacing(8, after: box)
        when.text = LXMoment.ago(m.ts)
        likeB.setTitle(m.likes["human"] != nil ? "取消" : "赞", for: .normal)
        likeB.setImage(LXMomentInk.icon("heart", size: 14, stroke: 1.8), for: .normal)
        fillBox()
        paintAvatar()
    }

    func refreshTime() { when.text = LXMoment.ago(m.ts) }

    private func fillBox() {
        box.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let likers = ["human", "ai", "zhao"].filter { m.likes[$0] != nil }
        if !likers.isEmpty {
            // .mo-likes:心 14 + 名字用"、"连,13,accent,padding 7 11
            let row = UIView()
            let heart = UIImageView(image: LXMomentInk.icon("heart", size: 14, stroke: 1.8))
            heart.tintColor = LXMomentInk.accent
            heart.alpha = 0.9
            let names = UILabel()
            names.numberOfLines = 0
            let f = LXMomentInk.font(13)
            names.attributedText = NSAttributedString(string: likers.map { LXMoment.name($0) }.joined(separator: "、"),
                attributes: [.font: f, .foregroundColor: LXMomentInk.accent, .paragraphStyle: LXMomentInk.para(f, 1.5)])
            for v in [heart, names] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; row.addSubview(v) }
            NSLayoutConstraint.activate([
                heart.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 11),
                heart.topAnchor.constraint(equalTo: row.topAnchor, constant: 7 + 2.5),
                heart.widthAnchor.constraint(equalToConstant: 14),
                heart.heightAnchor.constraint(equalToConstant: 14),
                names.leadingAnchor.constraint(equalTo: heart.trailingAnchor, constant: 2 + 7),
                names.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -11),
                names.topAnchor.constraint(equalTo: row.topAnchor, constant: 7),
                names.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -7),
            ])
            box.addArrangedSubview(row)
        }
        if !m.comments.isEmpty {
            let wrap = UIStackView()
            wrap.axis = .vertical
            wrap.isLayoutMarginsRelativeArrangement = true
            wrap.layoutMargins = UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)
            if !likers.isEmpty {
                let sep = UIView()
                sep.backgroundColor = LXMomentInk.hair
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                box.addArrangedSubview(sep)
            }
            for c in m.comments { wrap.addArrangedSubview(commentRow(c)) }
            box.addArrangedSubview(wrap)
        }
        box.isHidden = box.arrangedSubviews.isEmpty
    }

    /// .mo-comment:"A：text" / "A 回复 B：text",13.5,行高 1.6,名字 accent 600;点一下回复这个人
    private func commentRow(_ c: LXMoment.Comment) -> UIView {
        let b = UIControl()
        let l = UILabel()
        l.numberOfLines = 0
        let f = LXMomentInk.font(13.5), fb = LXMomentInk.font(13.5, 600)
        let p = LXMomentInk.para(f, 1.6)
        let s = NSMutableAttributedString()
        func add(_ t: String, bold: Bool) {
            s.append(NSAttributedString(string: t, attributes: [.font: bold ? fb : f, .paragraphStyle: p,
                .foregroundColor: bold ? LXMomentInk.accent : LXMomentInk.text]))
        }
        add(LXMoment.name(c.author), bold: true)
        if let r = c.replyTo, let to = m.comments.first(where: { $0.id == r }) {
            add(" 回复 ", bold: false)
            add(LXMoment.name(to.author), bold: true)
        }
        add("：" + c.text, bold: false)
        l.attributedText = s
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isUserInteractionEnabled = false
        b.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: b.leadingAnchor, constant: 11),
            l.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -11),
            l.topAnchor.constraint(equalTo: b.topAnchor, constant: 4),
            l.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -4),
        ])
        b.addAction(UIAction { [weak self, weak b] _ in
            b?.backgroundColor = LXMomentInk.press
            UIView.animate(withDuration: 0.25, delay: 0.1) { b?.backgroundColor = .clear }
            self?.openComment(replyTo: c.id)
        }, for: .touchUpInside)
        return b
    }

    func openComment(replyTo cid: Int?) {
        host?.hideOps()
        replyTo = cid
        let to = cid.flatMap { r in m.comments.first { $0.id == r } }
        field.attributedPlaceholder = NSAttributedString(string: to.map { "回复 \(LXMoment.name($0.author))…" } ?? "评论…",
            attributes: [.foregroundColor: LXMomentInk.faint, .font: LXMomentInk.font(13.5)])
        cbox.isHidden = false
        field.becomeFirstResponder()
        host?.reveal(self)
    }

    func closeCommentIfEmpty() {
        guard !cbox.isHidden, (field.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty else { return }
        field.resignFirstResponder()
        cbox.isHidden = true
        replyTo = nil
    }

    func textFieldShouldReturn(_ t: UITextField) -> Bool { sendComment(); return false }

    func textField(_ t: UITextField, shouldChangeCharactersIn r: NSRange, replacementString s: String) -> Bool {
        ((t.text ?? "") as NSString).replacingCharacters(in: r, with: s).count <= 500
    }

    private var sending = false

    private func sendComment() {
        let t = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !sending else { return }   // 发着的时候再点/回车不重发
        sending = true
        sendB.isEnabled = false
        host?.sendComment(m.id, text: t, replyTo: replyTo) { [weak self] ok in
            guard let s = self else { return }
            s.sending = false
            s.sendB.isEnabled = true
            guard ok else { return }
            s.field.text = ""
            s.field.resignFirstResponder()
            s.cbox.isHidden = true
            s.replyTo = nil
        }
    }

    func showOps(_ on: Bool) {
        if on { ops.isHidden = false }
        UIView.animate(withDuration: 0.16, animations: { self.ops.alpha = on ? 1 : 0 }) { _ in
            if !on && self.ops.alpha == 0 { self.ops.isHidden = true }   // 刚收又点开:别把新开的藏掉
        }
    }

    func setImagesLive(_ on: Bool) { if grid.live != on { grid.live = on } }

    private func paintAvatar() {
        let img = LXAvatarStore.image(m.author == "human" ? "human" : m.author == "zhao" ? "zhao" : "ai")
        ava.image = img
        star.isHidden = !(img == nil && m.author == "zhao")
        if img == nil {
            ava.backgroundColor = m.author == "human" ? LXMomentInk.humanBg
                : m.author == "zhao" ? UIColor(red: 0x26 / 255, green: 0x25 / 255, blue: 0x2A / 255, alpha: 1) : LXMomentInk.imgBg
        } else {
            ava.backgroundColor = .clear
        }
    }

    func paint() {
        who.textColor = LXMomentInk.accent
        when.textColor = LXMomentInk.faint
        del.tintColor = LXMomentInk.faint
        dots.subviews.filter { $0.tag == 77 }.forEach { $0.backgroundColor = LXMomentInk.accent }
        ops.backgroundColor = LXMomentInk.card
        ops.layer.borderColor = LXMomentInk.hair.cgColor
        opsLine.backgroundColor = LXMomentInk.hair
        for b in [likeB, cmtB] { b.tintColor = LXMomentInk.text; b.setTitleColor(LXMomentInk.text, for: .normal) }
        field.backgroundColor = LXMomentInk.card
        field.layer.borderColor = LXMomentInk.hair.cgColor
        field.textColor = LXMomentInk.text
        field.tintColor = LXMomentInk.primary
        sendB.backgroundColor = LXMomentInk.primary
        sendB.setTitleColor(LXMomentInk.primaryFg, for: .normal)
        line.backgroundColor = LXMomentInk.hair
        star.tintColor = UIColor(red: 0xB6 / 255, green: 0xD6 / 255, blue: 0xE8 / 255, alpha: 1)
        if m.text.isEmpty == false { configureTextColorOnly() }
        fillBox()
        paintAvatar()
    }

    private func configureTextColorOnly() {
        guard let a = body.attributedText?.mutableCopy() as? NSMutableAttributedString else { return }
        a.addAttribute(.foregroundColor, value: LXMomentInk.text, range: NSRange(location: 0, length: a.length))
        body.attributedText = a
    }
}

// MARK: - 发朋友圈的底卡

final class LXMomentComposer: UIView, UITextViewDelegate {
    let tv = UITextView()
    private let ph = UILabel()
    private let thumbs = UIView()
    private let addB = UIButton(type: .system)
    private let cancelB = UIButton(type: .system)
    let postB = UIButton(type: .system)
    private var thumbH: NSLayoutConstraint!
    private var tvH: NSLayoutConstraint!
    /// 已经传好的图(文件名,按摆的顺序,不按谁先传完),和正在传的个数
    var names: [String] { thumbViews.compactMap { $0.accessibilityIdentifier } }
    private var thumbViews: [UIImageView] = []
    private(set) var uploading = 0
    /// 正在发:Post 键一直灰着,打字也不会把它点亮
    var busy = false { didSet { syncPost() } }
    /// 选好了、还在缩的张数(没缩完也算占了名额,Post 也先灰着)
    var preparing = 0 { didSet { syncPost() } }
    /// 每清一次稿 +1:清稿前选的、传的,晚到了不算进新稿
    private(set) var generation = 0
    var onAdd: (() -> Void)?
    var onCancel: (() -> Void)?
    var onPost: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // .mo-sheet:卡片底 + 模糊 14,上圆角 18,padding 12 16 10
        layer.cornerRadius = 18
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        layer.borderWidth = 1
        clipsToBounds = true
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        tv.font = LXMomentInk.font(15)
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = self
        ph.text = "What’s on your mind…"
        ph.font = LXMomentInk.font(15)
        for (b, t) in [(addB, "+ Photo"), (cancelB, "Cancel"), (postB, "Post")] {
            b.setTitle(t, for: .normal)
            b.titleLabel?.font = LXMomentInk.font(13.5)
            b.contentEdgeInsets = b === postB ? UIEdgeInsets(top: 5, left: 17, bottom: 5, right: 17)
                                              : UIEdgeInsets(top: 4, left: 9, bottom: 4, right: 9)
            b.layer.cornerRadius = b === postB ? 15 : 8
        }
        addB.addAction(UIAction { [weak self] _ in self?.onAdd?() }, for: .touchUpInside)
        cancelB.addAction(UIAction { [weak self] _ in self?.onCancel?() }, for: .touchUpInside)
        postB.addAction(UIAction { [weak self] _ in self?.onPost?() }, for: .touchUpInside)
        for v in [tv, ph, thumbs, addB, cancelB, postB] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        thumbH = thumbs.heightAnchor.constraint(equalToConstant: 0)
        tvH = tv.heightAnchor.constraint(equalToConstant: 52)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor), blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor), blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            tv.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            tv.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            tv.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            tvH,
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            ph.topAnchor.constraint(equalTo: tv.topAnchor),
            thumbs.topAnchor.constraint(equalTo: tv.bottomAnchor, constant: 8),
            thumbs.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
            thumbs.trailingAnchor.constraint(equalTo: tv.trailingAnchor),
            thumbH,
            addB.topAnchor.constraint(equalTo: thumbs.bottomAnchor, constant: 8),
            addB.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: -9),
            postB.centerYAnchor.constraint(equalTo: addB.centerYAnchor),
            postB.trailingAnchor.constraint(equalTo: tv.trailingAnchor),
            cancelB.centerYAnchor.constraint(equalTo: addB.centerYAnchor),
            cancelB.trailingAnchor.constraint(equalTo: postB.leadingAnchor, constant: -10),
            addB.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])
        paint()
    }
    required init?(coder: NSCoder) { fatalError() }

    func paint() {
        backgroundColor = LXMomentInk.card.withAlphaComponent(0.62)
        layer.borderColor = LXMomentInk.hair.cgColor
        (subviews.first as? UIVisualEffectView)?.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        tv.textColor = LXMomentInk.text
        tv.tintColor = LXMomentInk.primary
        ph.textColor = LXMomentInk.faint
        for b in [addB, cancelB] { b.setTitleColor(LXMomentInk.soft, for: .normal) }
        postB.backgroundColor = LXMomentInk.primary
        postB.setTitleColor(LXMomentInk.primaryFg, for: .normal)
        syncPost()
    }

    func textViewDidChange(_ t: UITextView) {
        ph.isHidden = !t.text.isEmpty
        // 最矮 52,随字长高,最多 5 行左右
        let h = min(160, max(52, t.sizeThatFits(CGSize(width: t.bounds.width, height: .greatestFiniteMagnitude)).height))
        if abs(tvH.constant - h) > 0.5 { tvH.constant = h }
        syncPost()
    }

    var canAddMore: Int { max(0, 9 - thumbViews.count - preparing) }
    var text: String { tv.text.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// 选好的一张(已缩好的 JPEG + 小样):先摆出小样(半透明),传好了变实,传不上去就拿掉
    func addPicked(_ data: Data?, thumb: UIImage, done: @escaping (Bool) -> Void) {
        let iv = UIImageView(image: thumb)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.alpha = 0.45
        thumbs.addSubview(iv)
        thumbViews.append(iv)
        layoutThumbs()
        uploading += 1
        syncPost()
        let gen = generation
        let finish: (String?) -> Void = { [weak self, weak iv] name in
            guard let s = self, s.generation == gen else { return }
            s.uploading -= 1
            // 传完之前她点了 Cancel(小样已经拿掉了):这张就不算了
            if let n = name, let iv, s.thumbViews.contains(iv) {
                iv.alpha = 1
                iv.accessibilityIdentifier = n
            } else if let iv, let i = s.thumbViews.firstIndex(of: iv) {
                iv.removeFromSuperview()
                s.thumbViews.remove(at: i)
                s.layoutThumbs()
            }
            s.syncPost()
            done(name != nil)
        }
        if LustreConfig.isPreview { finish("pv-local-\(thumbViews.count).jpg") }
        else if let data { LXMomentNet.upload(data, done: finish) }
        else { finish(nil) }
    }

    /// .mo-composer-imgs:58×58,圆角 8,间隔 6,一行放不下就换行
    private func layoutThumbs() {
        let W = max(1, thumbs.bounds.width > 0 ? thumbs.bounds.width : UIScreen.main.bounds.width - 32)
        let side: CGFloat = 58, gap: CGFloat = 6
        let perRow = max(1, Int((W + gap) / (side + gap)))
        for (i, v) in thumbViews.enumerated() {
            v.frame = CGRect(x: CGFloat(i % perRow) * (side + gap), y: CGFloat(i / perRow) * (side + gap), width: side, height: side)
        }
        let rows = thumbViews.isEmpty ? 0 : (thumbViews.count + perRow - 1) / perRow
        thumbH.constant = rows == 0 ? 0 : CGFloat(rows) * side + CGFloat(rows - 1) * gap
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutThumbs()
    }

    func syncPost() {
        let ok = !busy && uploading == 0 && preparing == 0 && (!text.isEmpty || !names.isEmpty)
        postB.isEnabled = ok
        postB.alpha = ok ? 1 : 0.5
    }

    func clear() {
        generation += 1
        uploading = 0
        preparing = 0
        tv.text = ""
        textViewDidChange(tv)
        thumbViews.forEach { $0.removeFromSuperview() }
        thumbViews = []
        layoutThumbs()
        syncPost()
    }
}

/// 自己排版时叫一声(封面的渐变层要跟着它的大小走)
final class LXLayoutView: UIView {
    var onLayout: ((UIView) -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }
}

// MARK: - 朋友圈页

final class LXMomentsVC: UIViewController, UIScrollViewDelegate, PHPickerViewControllerDelegate, UIGestureRecognizerDelegate {
    static let shared = LXMomentsVC()
    static let cacheKey = "lx.moments.cache"
    static let coverKey = "lx.moments.cover"

    static func open() {
        let vc = shared
        guard vc.presentingViewController == nil, let top = DrawerPlugin.topVC() else { return }
        vc.modalPresentationStyle = .fullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        top.present(vc, animated: true)
    }

    /// 实时流每来一条都过一下这里
    static func feed(_ obj: [String: Any]) {
        guard !LustreConfig.isPreview, let type = obj["type"] as? String, type.hasPrefix("moment_") else { return }
        DispatchQueue.main.async { shared.apply(type, obj) }
    }

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let cover = LXLayoutView()
    private let coverGrad = CAGradientLayer()
    private let coverImg = UIImageView()
    private let coverShade = CAGradientLayer()
    private let meAva = UIImageView()
    private let emptyL = UILabel()
    private let moreL = UILabel()
    private let backB = UIButton(type: .custom)
    private let camB = UIButton(type: .custom)
    private let composer = LXMomentComposer()
    private let catcher = UIControl()          // 发布卡开着时点外面:只收卡,稿留着
    private var composerOn = false
    private var composerBottom: NSLayoutConstraint!
    private var coverH: NSLayoutConstraint!
    private var kbH: CGFloat = 0

    private(set) var items: [LXMoment] = []
    private var cells: [Int: LXMomentCell] = [:]
    private var hasMore = false
    private var loading = false
    private var loaded = false
    private var coverName = ""
    private var pendingNew: [LXMoment] = []
    private var moreRetryAt = Date.distantPast
    private weak var opsOpen: LXMomentCell?
    private var pickFor = ""                   // "post" / "cover"
    private var lightStatus = true

    override var preferredStatusBarStyle: UIStatusBarStyle {
        lightStatus || LXSheetInk.dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scroll.delegate = self
        scroll.alwaysBounceVertical = true
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // 封面:没设过就是网页那条渐变 165deg #2c3345→#55617e;底下 70 一层淡淡压暗;右下角她的头像 64
        coverGrad.colors = [UIColor(red: 0x2C / 255, green: 0x33 / 255, blue: 0x45 / 255, alpha: 1).cgColor,
                            UIColor(red: 0x55 / 255, green: 0x61 / 255, blue: 0x7E / 255, alpha: 1).cgColor]
        coverGrad.startPoint = CGPoint(x: 0.37, y: 0)
        coverGrad.endPoint = CGPoint(x: 0.63, y: 1)
        cover.layer.addSublayer(coverGrad)
        coverImg.contentMode = .scaleAspectFill
        coverImg.clipsToBounds = true
        cover.addSubview(coverImg)
        coverShade.colors = [UIColor.clear.cgColor, UIColor(white: 0, alpha: 0.16).cgColor]
        cover.layer.addSublayer(coverShade)
        cover.onLayout = { [weak self] v in
            guard let s = self else { return }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            s.coverGrad.frame = v.bounds
            s.coverImg.frame = v.bounds
            s.coverShade.frame = CGRect(x: 0, y: v.bounds.height - 70, width: v.bounds.width, height: 70)
            CATransaction.commit()
        }
        meAva.layer.cornerRadius = 64 * 0.14
        meAva.clipsToBounds = true
        meAva.contentMode = .scaleAspectFill   // 不描边(1005 她:头像边上不该有黑框)
        let avaWrap = UIView()
        avaWrap.layer.shadowColor = UIColor.black.cgColor
        avaWrap.layer.shadowOpacity = 0.28
        avaWrap.layer.shadowRadius = 6
        avaWrap.layer.shadowOffset = CGSize(width: 0, height: 2)
        avaWrap.translatesAutoresizingMaskIntoConstraints = false
        meAva.translatesAutoresizingMaskIntoConstraints = false
        avaWrap.addSubview(meAva)
        let head = UIView()
        head.clipsToBounds = false
        cover.translatesAutoresizingMaskIntoConstraints = false
        head.addSubview(cover)
        head.addSubview(avaWrap)
        coverH = cover.heightAnchor.constraint(equalToConstant: 330)
        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: head.topAnchor),
            cover.leadingAnchor.constraint(equalTo: head.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: head.trailingAnchor),
            coverH,
            head.bottomAnchor.constraint(equalTo: cover.bottomAnchor, constant: 40),   // .mo-cover-gap 40
            avaWrap.trailingAnchor.constraint(equalTo: head.trailingAnchor, constant: -16),
            avaWrap.bottomAnchor.constraint(equalTo: cover.bottomAnchor, constant: 22),
            avaWrap.widthAnchor.constraint(equalToConstant: 64),
            avaWrap.heightAnchor.constraint(equalToConstant: 64),
            meAva.topAnchor.constraint(equalTo: avaWrap.topAnchor), meAva.bottomAnchor.constraint(equalTo: avaWrap.bottomAnchor),
            meAva.leadingAnchor.constraint(equalTo: avaWrap.leadingAnchor), meAva.trailingAnchor.constraint(equalTo: avaWrap.trailingAnchor),
        ])
        let press = UILongPressGestureRecognizer(target: self, action: #selector(coverPressed(_:)))
        press.minimumPressDuration = 0.55
        cover.addGestureRecognizer(press)
        stack.addArrangedSubview(head)

        for l in [emptyL, moreL] {
            l.font = LXMomentInk.font(12.5)
            l.textAlignment = .center
            l.numberOfLines = 0
            l.isHidden = true
            stack.addArrangedSubview(l)
        }
        let ef = LXMomentInk.font(12.5)
        emptyL.attributedText = NSAttributedString(string: "还没有动态。\n第一条会从这里长出来。",
            attributes: [.font: ef, .paragraphStyle: { let p = LXMomentInk.para(ef, 2); p.alignment = .center; return p }()])
        moreL.text = "正在翻更早的日子…"

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -34),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        // 999:藏起来时让给栈的 0 高,不打架
        for c in [emptyL.heightAnchor.constraint(greaterThanOrEqualToConstant: 110), moreL.heightAnchor.constraint(equalToConstant: 58)] {
            c.priority = UILayoutPriority(999)
            c.isActive = true
        }

        // 浮在封面上的两颗圆:返回 / 相机,38,rgba(22,25,33,.30) + 模糊 10
        for (b, key, sw) in [(backB, "back", CGFloat(2.2)), (camB, "camera", CGFloat(1.8))] {
            b.layer.cornerRadius = 19
            b.clipsToBounds = true
            let fx = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            fx.isUserInteractionEnabled = false
            fx.frame = CGRect(x: 0, y: 0, width: 38, height: 38)
            fx.contentView.backgroundColor = UIColor(red: 22 / 255, green: 25 / 255, blue: 33 / 255, alpha: 0.30)
            b.insertSubview(fx, at: 0)
            let iv = UIImageView(image: LXMomentInk.icon(key, size: 20, stroke: sw))
            iv.tintColor = .white
            iv.frame = CGRect(x: 9, y: 9, width: 20, height: 20)
            iv.isUserInteractionEnabled = false
            b.addSubview(iv)
            b.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(b)
        }
        backB.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        camB.addAction(UIAction { [weak self] _ in self?.showComposer(true) }, for: .touchUpInside)
        NSLayoutConstraint.activate([
            backB.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            backB.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backB.widthAnchor.constraint(equalToConstant: 38), backB.heightAnchor.constraint(equalToConstant: 38),
            camB.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            camB.topAnchor.constraint(equalTo: backB.topAnchor),
            camB.widthAnchor.constraint(equalToConstant: 38), camB.heightAnchor.constraint(equalToConstant: 38),
        ])

        // 点空白:收"··"小菜单、收没写字的评论框(写了的留着)
        let tap = UITapGestureRecognizer(target: self, action: #selector(blankTapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        scroll.addGestureRecognizer(tap)

        catcher.isHidden = true
        catcher.translatesAutoresizingMaskIntoConstraints = false
        catcher.addAction(UIAction { [weak self] _ in self?.showComposer(false) }, for: .touchUpInside)
        view.addSubview(catcher)
        composer.translatesAutoresizingMaskIntoConstraints = false
        composer.isHidden = true
        composer.onAdd = { [weak self] in self?.pick("post", limit: self?.composer.canAddMore ?? 0) }
        composer.onCancel = { [weak self] in self?.composer.clear(); self?.showComposer(false) }
        composer.onPost = { [weak self] in self?.post() }
        view.addSubview(composer)
        composerBottom = composer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            catcher.topAnchor.constraint(equalTo: view.topAnchor), catcher.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            catcher.leadingAnchor.constraint(equalTo: view.leadingAnchor), catcher.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerBottom,
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(kbChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(forName: LXNick.changed, object: nil, queue: .main) { [weak self] _ in
            self?.cells.values.forEach { $0.configure($0.m) }
        }

        loadCache()
        paint()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 上次关页时键盘的高度不作数
        kbH = 0
        composerBottom.constant = 0
        scroll.verticalScrollIndicatorInsets.bottom = 0
        if !LustreConfig.isPreview { LXNick.refresh() }   // 她的名字:服务器新给的,开页拉一次
        paint()
        cells.values.forEach { $0.refreshTime() }
        if !LustreConfig.isPreview { load(more: false) }   // 先摆缓存,背后拉新的
        if coverName.isEmpty || !loaded { loadCover() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width
        let h = min(W * 0.6 + 90, 330)   // .mo-cover:min(60vw + 90px, 330px)
        if abs(coverH.constant - h) > 0.5 { coverH.constant = h }
        if kbH == 0 { scroll.contentInset.bottom = view.safeAreaInsets.bottom }   // .mo-scroll 底 34 + 安全区
    }

    private func paint() {
        view.backgroundColor = LXMomentInk.bg
        stack.backgroundColor = LXMomentInk.bg
        meAva.image = LXAvatarStore.image("human")
        meAva.backgroundColor = LXMomentInk.humanBg
        emptyL.textColor = LXMomentInk.faint
        moreL.textColor = LXMomentInk.faint
        cells.values.forEach { $0.paint() }
        composer.paint()
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: 数据

    private func loadCache() {
        if let d = UserDefaults.standard.data(forKey: Self.cacheKey),
           let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] {
            items = ((o["moments"] as? [[String: Any]]) ?? []).compactMap(LXMoment.init)
            hasMore = (o["has_more"] as? Bool) ?? false
        }
        coverName = UserDefaults.standard.string(forKey: Self.coverKey) ?? ""
        rebuildList()
        showCover()
    }

    private func saveCache() {
        guard !LustreConfig.isPreview else { return }
        let first = Array(items.prefix(20))
        let o: [String: Any] = ["moments": first.map { $0.dict }, "has_more": hasMore || items.count > 20]
        if let d = try? JSONSerialization.data(withJSONObject: o) { UserDefaults.standard.set(d, forKey: Self.cacheKey) }
    }

    func load(more: Bool) {
        guard !loading else { return }
        loading = true
        let before = more ? (items.last?.id ?? 0) : 0
        LXMomentNet.call("GET", "/app/moments?before_id=\(before)&limit=20") { [weak self] o, _ in
            guard let s = self else { return }
            s.loading = false
            guard let o else {   // 拉不下来就留着缓存那份,和网页一样不吵;往下翻的隔 5 秒再试,不是滚一下试一次
                if more { s.moreRetryAt = Date().addingTimeInterval(5) }
                return
            }
            let got = ((o["moments"] as? [[String: Any]]) ?? []).compactMap(LXMoment.init)
            s.hasMore = (o["has_more"] as? Bool) ?? false
            s.loaded = true
            if more {
                let known = Set(s.items.map { $0.id })
                s.items += got.filter { !known.contains($0.id) }
            } else if s.hasMore, let last = got.last {
                // 刷第一页:她之前往下翻出来的更早的那些留着(不然翻在下面的人一下掉进空白)
                s.items = got + s.items.filter { $0.id < last.id }
            } else {
                s.items = got
            }
            s.rebuildList()
            s.saveCache()
        }
    }

    private func loadCover() {
        LXMomentNet.call("GET", "/app/moment_cover") { [weak self] o, _ in
            guard let s = self, let o else { return }
            s.setCover((o["image"] as? String) ?? "")
        }
    }

    private func setCover(_ name: String) {
        coverName = name
        if !LustreConfig.isPreview { UserDefaults.standard.set(name, forKey: Self.coverKey) }
        showCover()
    }

    private func showCover() {
        guard !coverName.isEmpty else { coverImg.image = nil; return }
        let want = coverName
        LXMomentImage.load(want, maxSide: 2000) { [weak self] img in
            guard let s = self, s.coverName == want, let img else { return }
            s.coverImg.image = img
        }
    }

    /// 列表按 items 摆:已有的格子原地换内容,新的插进去,没了的拿掉(不整页重来)。
    /// 她往下翻着的时候上面多了/少了一条:她眼前那条原地不动
    private func rebuildList() {
        keepPlace { place() }
        // 列表变短了(比如翻到很下面又重开):别停在内容外面一片空
        let maxY = max(0, scroll.contentSize.height + scroll.contentInset.bottom - scroll.bounds.height)
        if scroll.contentOffset.y > maxY + 0.5 { scroll.contentOffset.y = maxY }
        trimImages()
    }

    /// 她往下翻着的时候,上面的格子变高变矮、多一条少一条:她眼前那条原地不动
    func keepPlace(_ change: () -> Void) {
        let y = scroll.contentOffset.y
        let headBottom = stack.arrangedSubviews.first?.frame.maxY ?? 0   // 封面还看得见:新的照常从上面冒出来
        let anchor = y > headBottom ? items.first(where: { (cells[$0.id]?.frame.maxY ?? 0) > y }).flatMap { cells[$0.id] } : nil
        let anchorY = anchor?.frame.minY
        change()
        view.layoutIfNeeded()
        guard let a = anchor, let b = anchorY, a.superview != nil else { return }
        let d = a.frame.minY - b
        if abs(d) > 0.5 { scroll.contentOffset.y = y + d }
    }

    private func place() {
        let ids = Set(items.map { $0.id })
        for (id, c) in cells where !ids.contains(id) { c.removeFromSuperview(); cells[id] = nil }
        for (i, m) in items.enumerated() {
            let c: LXMomentCell
            if let old = cells[m.id] {
                c = old
                c.configure(m)
            } else {
                c = LXMomentCell(m)
                c.host = self
                cells[m.id] = c
            }
            let at = i + 1   // 0 是封面
            if stack.arrangedSubviews.firstIndex(of: c) != at {
                c.removeFromSuperview()
                stack.insertArrangedSubview(c, at: at)
            }
        }
        emptyL.isHidden = !(items.isEmpty && (loaded || LustreConfig.isPreview))
        moreL.isHidden = !hasMore
    }

    /// 眼前上下两屏以内的格子摆图,再远的先放下(回来时从手机缓存摆上)
    private func trimImages() {
        let h = max(scroll.bounds.height, 600)
        let top = scroll.contentOffset.y - h * 2, bottom = scroll.contentOffset.y + h * 3
        for c in cells.values where c.superview != nil {
            c.setImagesLive(c.frame.height == 0 || (c.frame.maxY > top && c.frame.minY < bottom))
        }
    }

    // MARK: 实时

    private func apply(_ type: String, _ o: [String: Any]) {
        guard isViewLoaded else { return }
        switch type {
        case "moment_cover":
            setCover((o["image"] as? String) ?? "")
        case "moment_del":
            guard let id = (o["id"] as? NSNumber)?.intValue else { return }
            pendingNew.removeAll { $0.id == id }
            items.removeAll { $0.id == id }
            rebuildList(); saveCache()
        case "moment_new":
            guard let d = o["moment"] as? [String: Any], let m = LXMoment(d), !items.contains(where: { $0.id == m.id }),
                  !pendingNew.contains(where: { $0.id == m.id }) else { return }
            // 她正在写评论:新的一条先等等,写完或点空白再冒出来(别把她正在写的那格顶走)
            if cells.values.contains(where: { $0.field.isFirstResponder }) { pendingNew.append(m); return }
            items.insert(m, at: 0)
            rebuildList(); saveCache()
        case "moment_like":
            guard let id = (o["id"] as? NSNumber)?.intValue else { return }
            let likes = (o["likes"] as? [String: String]) ?? [:]
            if let p = pendingNew.firstIndex(where: { $0.id == id }) { pendingNew[p].likes = likes; return }
            guard let i = items.firstIndex(where: { $0.id == id }) else { return }
            items[i].likes = likes
            keepPlace { cells[id]?.configure(items[i]) }
            saveCache()
        case "moment_comment":
            guard let d = o["moment"] as? [String: Any], let m = LXMoment(d) else { return }
            replace(m)
        default:
            break
        }
    }

    private func replace(_ m: LXMoment) {
        if let p = pendingNew.firstIndex(where: { $0.id == m.id }) { pendingNew[p] = m; return }
        guard let i = items.firstIndex(where: { $0.id == m.id }) else { return }
        items[i] = m
        keepPlace { cells[m.id]?.configure(m) }
        saveCache()
    }

    private func flushPending() {
        guard !pendingNew.isEmpty else { return }
        // 先来的先插,后来的插在它上面:最新的在最上
        for m in pendingNew where !items.contains(where: { $0.id == m.id }) { items.insert(m, at: 0) }
        pendingNew = []
        rebuildList(); saveCache()
    }

    // MARK: 一条上的动作

    func toggleOps(_ c: LXMomentCell) {
        if opsOpen === c { hideOps(); return }
        hideOps()
        opsOpen = c
        c.showOps(true)
    }

    func hideOps() {
        opsOpen?.showOps(false)
        opsOpen = nil
    }

    func toggleLike(_ id: Int) {
        hideOps()
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let on = items[i].likes["human"] == nil
        if LustreConfig.isPreview {
            if on { items[i].likes["human"] = "❤️" } else { items[i].likes["human"] = nil }
            cells[id]?.configure(items[i])
            return
        }
        LXMomentNet.call("POST", "/app/moment_like", ["id": id, "emoji": on ? "❤️" : "", "author": "human"]) { [weak self] o, _ in
            guard let s = self, let o, let j = s.items.firstIndex(where: { $0.id == id }) else { return }
            s.items[j].likes = (o["likes"] as? [String: String]) ?? [:]
            s.keepPlace { s.cells[id]?.configure(s.items[j]) }
            s.saveCache()
        }
    }

    func sendComment(_ id: Int, text: String, replyTo: Int?, done: @escaping (Bool) -> Void) {
        if LustreConfig.isPreview { done(true); flushPending(); return }
        var body: [String: Any] = ["id": id, "text": text, "author": "human"]
        if let r = replyTo { body["reply_to"] = r }
        LXMomentNet.call("POST", "/app/moment_comment", body) { [weak self] o, _ in
            guard let s = self else { return }
            guard let o, let m = LXMoment(o) else { LXToast.show("评论没发出去,再试一次", host: s.view); done(false); return }
            done(true)
            s.replace(m)
            s.flushPending()
        }
    }

    func askDelete(_ id: Int) {
        hideOps()
        DrawerPlugin.confirm(title: "删掉这条朋友圈？", message: "") { [weak self] in self?.delete(id) }
    }

    private func delete(_ id: Int) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        let m = items.remove(at: i)
        rebuildList()
        if LustreConfig.isPreview { return }
        LXMomentNet.call("POST", "/app/moment_delete", ["id": id]) { [weak self] o, code in
            guard let s = self else { return }
            if o != nil { s.saveCache(); return }
            // 没删成:放回原处
            s.items.insert(m, at: min(i, s.items.count))
            s.rebuildList()
            LXToast.show(code == 404 ? "这台服务器还没上删除口" : "删除失败，再试试", host: s.view)
        }
    }

    func showImage(_ name: String) {
        hideOps()
        view.endEditing(true)
        // 格子里那张先摆上(不是黑屏转圈),原图到了再换
        let have = LXMomentImage.cache.object(forKey: "\(name)@900" as NSString)
            ?? LXMomentImage.cache.object(forKey: "\(name)@720" as NSString)
        if LustreConfig.isPreview, let img = have {
            LXLightbox.show(image: img, host: view)
            return
        }
        guard let u = LXMomentNet.imageURL(name) else { return }
        LXLightbox.show(u, host: view, placeholder: have)
    }

    /// 评论框弹出来时把这一格挪到看得见的地方
    func reveal(_ c: LXMomentCell) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let s = self else { return }
            let r = c.convert(c.cbox.frame, from: c.cbox.superview).insetBy(dx: 0, dy: -12)
            s.scroll.scrollRectToVisible(c.convert(r, to: s.scroll), animated: true)
        }
    }

    @objc private func blankTapped(_ g: UITapGestureRecognizer) {
        hideOps()
        cells.values.forEach { $0.closeCommentIfEmpty() }
        flushPending()
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldReceive t: UITouch) -> Bool {
        // 点在按钮、输入框、评论上的不算"空白"
        var v = t.view
        while let x = v, x !== scroll {
            if x is UIControl || x is UITextField { return false }
            v = x.superview
        }
        return true
    }

    // MARK: 滚动:快到底翻更早的;过了封面状态栏跟着页面深浅

    func scrollViewDidScroll(_ s: UIScrollView) {
        if hasMore, !loading, Date() >= moreRetryAt, s.contentOffset.y + s.bounds.height > s.contentSize.height - 240 { load(more: true) }
        trimImages()
        let light = s.contentOffset.y < coverH.constant - view.safeAreaInsets.top - 20
        if light != lightStatus { lightStatus = light; setNeedsStatusBarAppearanceUpdate() }
        if opsOpen != nil, s.isDragging { hideOps() }
    }

    // MARK: 发布

    func showComposer(_ on: Bool) {
        guard on != composerOn else { return }
        composerOn = on
        hideOps()
        if on {
            composer.isHidden = false
            catcher.isHidden = false
            view.layoutIfNeeded()
            composer.transform = CGAffineTransform(translationX: 0, y: composer.bounds.height * 1.05)
            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0) {
                self.composer.transform = .identity
            }
            composer.tv.becomeFirstResponder()
        } else {
            composer.tv.resignFirstResponder()
            catcher.isHidden = true
            UIView.animate(withDuration: 0.28, animations: {
                self.composer.transform = CGAffineTransform(translationX: 0, y: self.composer.bounds.height * 1.05 + self.kbH)
            }) { _ in if !self.composerOn { self.composer.isHidden = true; self.composer.transform = .identity } }
        }
    }

    private func post() {
        let text = composer.text
        let imgs = composer.names
        guard !composer.busy, composer.uploading == 0, !text.isEmpty || !imgs.isEmpty else { return }
        if LustreConfig.isPreview { composer.clear(); showComposer(false); return }
        composer.busy = true
        LXMomentNet.call("POST", "/app/moment", ["text": text, "images": imgs, "author": "human"]) { [weak self] o, _ in
            guard let s = self else { return }
            s.composer.busy = false
            guard let o, let m = LXMoment(o) else {
                LXToast.show("发布失败,再试一次", host: s.view)
                return
            }
            if !s.items.contains(where: { $0.id == m.id }) { s.items.insert(m, at: 0) }
            s.rebuildList(); s.saveCache()
            s.composer.clear()
            s.showComposer(false)
            s.scroll.setContentOffset(.zero, animated: true)
        }
    }

    @objc private func kbChange(_ n: Notification) {
        // 页关着时别的页弹键盘不归这里管
        guard view.window != nil,
              let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let local = view.convert(end, from: nil)
        kbH = max(0, view.bounds.height - local.minY)
        let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        composerBottom.constant = -kbH
        scroll.contentInset.bottom = max(kbH, view.safeAreaInsets.bottom)
        scroll.verticalScrollIndicatorInsets.bottom = kbH
        UIView.animate(withDuration: dur) { self.view.layoutIfNeeded() }
    }

    // MARK: 选图(发布 / 换封面)

    @objc private func coverPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        pick("cover", limit: 1)
    }

    private func pick(_ purpose: String, limit: Int) {
        guard limit > 0 else { LXToast.show("最多 9 张", host: view); return }
        pickFor = purpose
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = limit
        let p = PHPickerViewController(configuration: cfg)
        p.delegate = self
        present(p, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let purpose = pickFor
        // 按她选的顺序一张张来(上一张缩好才下一张:同时只解一张,也保证顺序)
        let providers = results.map { $0.itemProvider }.filter { $0.hasItemConformingToTypeIdentifier("public.image") }
        let gen = composer.generation
        if purpose == "post" { composer.preparing += providers.count }
        func next(_ i: Int) {
            guard i < providers.count else { return }
            // 缩到一半她点了 Cancel / 已经发出去了:剩下的不要了
            if purpose == "post", composer.generation != gen { return }
            // 相册给的是临时文件,只在回调里有效:就地缩好(后台线程),拿着结果回主线程
            providers[i].loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, _ in
                let got = url.flatMap { CGImageSourceCreateWithURL($0 as CFURL, nil) }.flatMap(LXMomentNet.prepare)
                DispatchQueue.main.async {
                    defer { next(i + 1) }
                    guard let s = self else { return }
                    if purpose == "post" {
                        guard s.composer.generation == gen else { return }
                        s.composer.preparing -= 1
                    }
                    guard let got else { LXToast.show("这张图读不出来", host: s.view); return }
                    if purpose == "cover" { s.uploadCover(got.data, show: got.big) } else {
                        s.composer.addPicked(got.data, thumb: got.thumb) { ok in if !ok { LXToast.show("图片没传上去,再试一次", host: s.view) } }
                    }
                }
            }
        }
        next(0)
    }

    private func uploadCover(_ data: Data, show img: UIImage) {
        coverImg.image = img
        if LustreConfig.isPreview { return }
        LXMomentNet.upload(data) { [weak self] name in
            guard let s = self else { return }
            guard let name else { LXToast.show("封面没换成,再试一次", host: s.view); s.showCover(); return }
            LXMomentNet.call("POST", "/app/moment_cover", ["image": name]) { o, _ in
                if o == nil { LXToast.show("封面没换成,再试一次", host: s.view); s.showCover(); return }
                // 刚传的这张手里就有:放进缓存,不用再从服务器下一遍
                LXMomentImage.cache.setObject(img, forKey: "\(name)@2000" as NSString)
                s.setCover(name)
            }
        }
    }

    // MARK: 预览

    func previewSeed(_ list: [LXMoment]) {
        items = list
        hasMore = false
        loaded = true
        rebuildList()
    }
    func previewOps(_ i: Int) { if i < items.count, let c = cells[items[i].id] { toggleOps(c) } }
    func previewLike(_ i: Int) { if i < items.count { toggleLike(items[i].id) } }
    func previewReply(_ i: Int, comment: Int, draft: String) {
        guard i < items.count, let c = cells[items[i].id] else { return }
        c.openComment(replyTo: items[i].comments.indices.contains(comment) ? items[i].comments[comment].id : nil)
        c.field.text = draft
    }
    func previewScroll(to i: Int) {
        guard i < items.count, let c = cells[items[i].id] else { return }
        view.endEditing(true)
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, c.frame.minY - 60)), animated: true)
    }
    func previewComposer(_ text: String, _ imgs: [UIImage]) {
        scroll.setContentOffset(.zero, animated: false)
        showComposer(true)
        composer.tv.text = text
        composer.textViewDidChange(composer.tv)
        for im in imgs { composer.addPicked(nil, thumb: im) { _ in } }
    }
    func previewCloseComposer() { composer.clear(); showComposer(false) }
    /// 换白天:关大图、回顶上、按白天的颜色重新上色,再点开第一条的"··"
    func previewDay() {
        LXLightbox.live?.close(animated: false)
        ChatListPlugin.live?.switchMoon("day")
        paint()
        scroll.setContentOffset(.zero, animated: false)
        previewOps(0)
    }
}

// MARK: - 预览路线 moments:假数据(不连服务器),六步

enum LXMomentsPreview {
    static func start(tries: Int = 0) {
        guard LustreConfig.isPreview, LustreConfig.previewFocus == "moments" else { return }
        guard let top = DrawerPlugin.topVC(), top.view.window != nil else {
            if tries < 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(tries: tries + 1) } }
            return
        }
        // 假图:几块纯色,先放进缓存
        let colors: [UIColor] = [UIColor(red: 0.42, green: 0.55, blue: 0.70, alpha: 1), UIColor(red: 0.80, green: 0.62, blue: 0.48, alpha: 1),
                                 UIColor(red: 0.45, green: 0.63, blue: 0.52, alpha: 1), UIColor(red: 0.62, green: 0.50, blue: 0.70, alpha: 1)]
        func swatch(_ c: UIColor, _ w: CGFloat, _ h: CGFloat) -> UIImage {
            UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { ctx in
                c.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
                UIColor(white: 1, alpha: 0.25).setFill()
                ctx.fill(CGRect(x: w * 0.1, y: h * 0.62, width: w * 0.8, height: h * 0.08))
            }
        }
        let wide = swatch(colors[0], 900, 600)
        LXMomentImage.cache.setObject(wide, forKey: "pv-wide.jpg@900")
        LXMomentImage.setAspect("pv-wide.jpg", 1.5)
        for i in 0..<6 {
            LXMomentImage.cache.setObject(swatch(colors[i % 4], 480, 480), forKey: "pv-\(i).jpg@720" as NSString)
        }
        func iso(_ minAgo: Double) -> String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: Date().addingTimeInterval(-minAgo * 60))
        }
        func mo(_ id: Int, _ who: String, _ text: String, _ imgs: [String], _ likes: [String: String],
                _ cm: [(Int, String, String, Int?)], _ ago: Double) -> LXMoment? {
            LXMoment(["id": id, "ts": iso(ago), "author": who, "text": text, "images": imgs, "likes": likes,
                      "comments": cm.map { c -> [String: Any] in
                          var o: [String: Any] = ["id": c.0, "ts": iso(ago - 1), "author": c.1, "text": c.2]
                          if let r = c.3 { o["reply_to"] = r }
                          return o
                      }])
        }
        let list = [
            mo(106, "human", "Sample post · the evening light came in sideways and stayed on the wall for a long time.", [],
               ["ai": "❤️", "zhao": "❤️"], [(901, "ai", "Sample comment · I saw it too.", nil), (902, "zhao", "Sample reply.", 901),
                                            (903, "human", "Sample reply back.", 902)], 3),
            mo(105, "ai", "Sample post with one wide picture.", ["pv-wide.jpg"], ["human": "❤️"], [], 95),
            mo(104, "zhao", "Sample post with four pictures.", ["pv-0.jpg", "pv-1.jpg", "pv-2.jpg", "pv-3.jpg"], [:],
               [(904, "human", "Sample comment.", nil)], 60 * 30),
            mo(103, "human", "", ["pv-0.jpg", "pv-1.jpg", "pv-2.jpg", "pv-3.jpg", "pv-4.jpg"], [:], [], 60 * 60),
            mo(102, "ai", "Sample post · a short line, no pictures.", [], [:], [], 60 * 72),
        ].compactMap { $0 }

        LXMomentsVC.open()
        let vc = LXMomentsVC.shared
        vc.loadViewIfNeeded()
        vc.previewSeed(list)
        let mark = UIView(frame: LXBubbleSampler.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let phase = UIView(frame: CGRect(x: 28, y: 70, width: 20, height: 20))
        // 第一步一开页就亮着(截图开始得比这里晚,别错过开页那一眼),往后每步 12 秒
        let steps: [(UIColor, () -> Void)] = [
            (.yellow, { }),                                                                    // 封面 + 头几条
            (.cyan, { vc.previewOps(0) }),                                                     // 点"··":赞 / 评论
            (.red, { vc.previewLike(0); vc.previewReply(0, comment: 1, draft: "Sample draft") }),   // 赞上 + 回复框
            (UIColor(red: 0.5, green: 0, blue: 1, alpha: 1), { vc.previewScroll(to: 1) }),       // 往下:单图、四图、五图
            (.white, { vc.previewComposer("Sample new post", [swatch(colors[1], 400, 400), swatch(colors[2], 400, 300)]) }),  // 发布卡
            (.gray, { vc.previewCloseComposer(); vc.showImage("pv-wide.jpg") }),               // 看大图(带存相册)
            (.orange, { vc.previewDay() }),                                                    // 白天:顶上 + 小菜单
        ]
        for (i, st) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (i == 0 ? 0.5 : 40 + Double(i - 1) * 12)) {
                st.1()
                phase.backgroundColor = st.0
                let host: UIView = LXLightbox.live?.superview ?? vc.view
                for v in [mark, phase] { if v.superview !== host { host.addSubview(v) }; host.bringSubviewToFront(v) }
            }
        }
    }
}
