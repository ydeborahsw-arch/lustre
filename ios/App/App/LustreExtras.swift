import Foundation
import Capacitor
import UIKit
import LocalAuthentication
import UserNotifications
import BackgroundTasks
import HealthKit
import WebKit
import AVFoundation


enum QuickAction {
    static var pending: String?
    static func fire(_ type: String) { pending = type; deliver() }
    static func deliver(_ attempt: Int = 0) {
        guard let type = pending else { return }
        let id = type.components(separatedBy: ".").last ?? type
        if LustreConfig.webless {
            DispatchQueue.main.async {
                guard let chat = ChatListPlugin.live, chat.table != nil, let home = HomePlugin.live else { retry(attempt); return }
                pending = nil
                switch id {
                case "home": home.openHomeNative()
                case "read": break
                default:
                    chat.switchTo("yan-main")
                }
            }
            return
        }
        DispatchQueue.main.async {
            guard let wv = topWebView() else { retry(attempt); return }
            wv.evaluateJavaScript("window.__quickAction ? (window.__quickAction('\(id)'), true) : false") { res, _ in
                if (res as? Bool) == true { pending = nil } else { retry(attempt) }
            }
        }
    }
    private static func retry(_ attempt: Int) {
        guard attempt < 20 else { pending = nil; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { deliver(attempt + 1) }
    }
    private static func topWebView() -> WKWebView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let ws = scene as? UIWindowScene else { continue }
            for window in ws.windows {
                var stack: [UIView] = [window]
                while let v = stack.popLast() {
                    if let wv = v as? WKWebView { return wv }
                    stack.append(contentsOf: v.subviews)
                }
            }
        }
        return nil
    }
}


enum LXSheetInk {
    private static func hex(_ v: Int, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
    }
    private static var m: String { RPSpec.moonState }
    static var dark: Bool { m != "day" }
    static var text: UIColor { m == "day" ? hex(0x2A3A4D) : m == "half" ? hex(0xE9E5DC) : UIColor(white: 0.95, alpha: 1) }
    static var icon: UIColor { m == "day" ? hex(0x2A3A4D) : m == "half" ? hex(0xE9E5DC) : UIColor(white: 0.9, alpha: 1) }
    static var soft: UIColor { m == "day" ? hex(0x64798D) : m == "half" ? hex(0xA5A198) : UIColor(red: 0.55, green: 0.6, blue: 0.7, alpha: 1) }
    static var faint: UIColor { m == "day" ? hex(0x92A6B8) : m == "half" ? hex(0x6E6B64) : UIColor(red: 0.47, green: 0.52, blue: 0.61, alpha: 1) }
    static var sep: UIColor { m == "day" ? hex(0x7A8C9E, 0.22) : UIColor(white: 1, alpha: m == "half" ? 0.08 : 0.10) }
    static var chip: UIColor { m == "day" ? UIColor(white: 0, alpha: 0.06) : UIColor(white: 1, alpha: 0.08) }
    static var track: UIColor { m == "day" ? UIColor(white: 0, alpha: 0.08) : UIColor(white: 1, alpha: 0.13) }
    static var tile: UIColor { m == "day" ? hex(0xFFFFFF, 0.9) : m == "half" ? hex(0x262624) : UIColor(red: 0.118, green: 0.118, blue: 0.125, alpha: 1) }
    static var star: UIColor { m == "moon" ? hex(0xB6D6E8) : hex(0xD97757) }
    static var tint: UIColor { m == "day" ? hex(0xF4F8FB, 0.72) : m == "half" ? hex(0x191917, 0.62) : UIColor(red: 0.043, green: 0.043, blue: 0.047, alpha: 0.62) }
}

final class LXCardSheet: UIView {
    static func anthro(_ size: CGFloat, semibold: Bool = false) -> UIFont {
        let base = LXBubbleCell.bodyFont().withSize(size)
        if semibold, let d = base.fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }

    let content = UIStackView()
    private let panel = UIView()
    private let scrim = UIControl()
    private var onDismiss: (() -> Void)?

    /// build:升起之前先把内容放进 content(这样升起的距离按装满后的高度算)
    init(host: UIView, title: String, onDismiss: (() -> Void)? = nil, build: ((LXCardSheet) -> Void)? = nil) {
        super.init(frame: host.bounds)
        self.onDismiss = onDismiss
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrim.frame = bounds
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrim.backgroundColor = UIColor(white: 0, alpha: 0.45)
        scrim.alpha = 0
        scrim.addAction(UIAction { [weak self] _ in self?.dismissSheet() }, for: .touchUpInside)
        addSubview(scrim)
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = .clear
        panel.layer.cornerRadius = 24
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.clipsToBounds = true
        let glassFx: UIVisualEffect
        if #available(iOS 26.0, *) { glassFx = UIGlassEffect() }
        else { glassFx = UIBlurEffect(style: LXSheetInk.dark ? .systemThickMaterialDark : .systemThickMaterialLight) }
        let glass = UIVisualEffectView(effect: glassFx)
        glass.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        glass.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(glass)
        let tintV = UIView()
        tintV.translatesAutoresizingMaskIntoConstraints = false
        tintV.backgroundColor = LXSheetInk.tint
        panel.addSubview(tintV)
        addSubview(panel)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: panel.topAnchor), glass.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: panel.leadingAnchor), glass.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            tintV.topAnchor.constraint(equalTo: panel.topAnchor), tintV.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            tintV.leadingAnchor.constraint(equalTo: panel.leadingAnchor), tintV.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
        ])
        let grab = UIView()
        grab.translatesAutoresizingMaskIntoConstraints = false
        grab.backgroundColor = UIColor(white: 0.55, alpha: 0.6)
        grab.layer.cornerRadius = 2.5
        panel.addSubview(grab)
        let xBtn = UIButton(type: .system)
        xBtn.translatesAutoresizingMaskIntoConstraints = false
        xBtn.backgroundColor = LXSheetInk.chip
        xBtn.layer.cornerRadius = 18
        xBtn.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
        xBtn.tintColor = LXSheetInk.icon
        xBtn.addAction(UIAction { [weak self] _ in self?.dismissSheet() }, for: .touchUpInside)
        panel.addSubview(xBtn)
        let titleL = UILabel()
        titleL.translatesAutoresizingMaskIntoConstraints = false
        titleL.text = title
        titleL.font = LXCardSheet.anthro(17, semibold: true)
        titleL.textColor = LXSheetInk.text
        titleL.textAlignment = .center
        panel.addSubview(titleL)
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 10
        panel.addSubview(content)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor),
            grab.topAnchor.constraint(equalTo: panel.topAnchor, constant: 8),
            grab.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            grab.widthAnchor.constraint(equalToConstant: 40),
            grab.heightAnchor.constraint(equalToConstant: 5),
            xBtn.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            xBtn.topAnchor.constraint(equalTo: panel.topAnchor, constant: 26),
            xBtn.widthAnchor.constraint(equalToConstant: 36),
            xBtn.heightAnchor.constraint(equalToConstant: 36),
            titleL.centerYAnchor.constraint(equalTo: xBtn.centerYAnchor),
            titleL.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            content.topAnchor.constraint(equalTo: xBtn.bottomAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: panel.safeAreaLayoutGuide.bottomAnchor, constant: -14),
        ])
        build?(self)
        host.window?.endEditing(true)      // 底部小卡升起前先收键盘,不然卡片在键盘后面
        host.addSubview(self)
        layoutIfNeeded()
        panel.transform = CGAffineTransform(translationX: 0, y: panel.bounds.height == 0 ? 500 : panel.bounds.height)
        UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.86, initialSpringVelocity: 0.6) {
            self.panel.transform = .identity
            self.scrim.alpha = 1
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func dismissSheet() {
        onDismiss?()
        UIView.animate(withDuration: 0.22, animations: {
            self.panel.transform = CGAffineTransform(translationX: 0, y: self.panel.bounds.height + 40)
            self.scrim.alpha = 0
        }) { _ in self.removeFromSuperview() }
    }

    static func cardBox() -> UIStackView {
        let v = UIStackView()
        v.axis = .vertical
        v.backgroundColor = LXSheetInk.tile
        v.layer.cornerRadius = 18
        v.clipsToBounds = true
        v.isLayoutMarginsRelativeArrangement = true
        v.layoutMargins = .zero
        return v
    }
    static func sep() -> UIView {
        let wrap = UIView()
        let s = UIView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.backgroundColor = LXSheetInk.chip
        wrap.addSubview(s)
        NSLayoutConstraint.activate([
            wrap.heightAnchor.constraint(equalToConstant: 1),
            s.topAnchor.constraint(equalTo: wrap.topAnchor),
            s.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
            s.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            s.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
        ])
        return wrap
    }
}


enum LXFakeCall {
    static func make(_ method: String, _ opts: [String: Any]) -> CAPPluginCall {
        CAPPluginCall(callbackId: "lx-native", methodName: method, options: opts,
                      success: { _, _ in }, error: { _ in })
    }
    static func clean(_ call: CAPPluginCall) -> [String: Any] {
        var d: [String: Any] = [:]
        for (k, v) in call.options ?? [:] { if let ks = k as? String { d[ks] = v } }
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d),
              let clean = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return clean
    }
    static func save(_ call: CAPPluginCall, _ key: String) {
        let d = clean(call)
        guard !d.isEmpty, let data = try? JSONSerialization.data(withJSONObject: d) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    static func load(_ key: String) -> [String: Any] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return [:] }
        return o
    }
}

enum LustreConfig {
    static let origin = "__LX_ORIGIN__"
    static let apiBase = "__LX_ORIGIN__/relay"

    private static var config: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "capacitor.config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }()

    static var secret: String = {
        if let lx = config["lustre"] as? [String: Any],
           let a = lx["auth"] as? String, !a.isEmpty { return a }
        guard let server = config["server"] as? [String: Any],
              let s = server["url"] as? String,
              let comps = URLComponents(string: s),
              let auth = comps.queryItems?.first(where: { $0.name == "auth" })?.value
        else { return "" }
        return auth
    }()

    static var webless: Bool = {
        guard let server = config["server"] as? [String: Any],
              let s = server["url"] as? String else { return true }
        return s.isEmpty
    }()

    static var isPreview: Bool = {
        if let lx = config["lustre"] as? [String: Any], lx["preview"] as? Bool == true { return true }
        guard let url = Bundle.main.url(forResource: "capacitor.config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let server = obj["server"] as? [String: Any],
              let s = server["url"] as? String else { return false }
        return s.contains("nativechat=1")
    }()
}

final class MirrorSync {
    static let shared = MirrorSync()
    static let lastKey = "lustre.mirror.last"
    private(set) var running = false

    var dir: URL {
        let d = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mirror", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func status() -> [String: Any] {
        var total: Int64 = 0
        if let en = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let u as URL in en {
                let n = (try? u.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                total += Int64(n)
            }
        }
        return ["bytes": total,
                "last": UserDefaults.standard.double(forKey: MirrorSync.lastKey),
                "running": running]
    }

    private func req(_ path: String) -> URLRequest? {
        guard !LustreConfig.secret.isEmpty, let url = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 60)
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        return r
    }

    func run(progress: @escaping (String) -> Void, done: @escaping (Bool, String) -> Void) {
        guard !running else { done(false, "already running"); return }
        running = true
        guard let mreq = req("/app/mirror/manifest") else { running = false; done(false, "no config"); return }
        URLSession.shared.dataTask(with: mreq) { data, _, _ in
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = obj["files"] as? [[String: Any]] else {
                self.running = false; done(false, "manifest failed"); return
            }
            self.step(files, 0, 0, progress, done)
        }.resume()
    }

    private func step(_ files: [[String: Any]], _ i: Int, _ grabbed: Int64,
                      _ progress: @escaping (String) -> Void, _ done: @escaping (Bool, String) -> Void) {
        if i >= files.count {
            running = false
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: MirrorSync.lastKey)
            done(true, "\(files.count) files · +\(grabbed / 1024)KB")
            return
        }
        let fid = (files[i]["id"] as? String) ?? ""
        let size = ((files[i]["size"] as? NSNumber)?.int64Value) ?? 0
        let mtime = ((files[i]["mtime"] as? NSNumber)?.doubleValue) ?? 0
        let safe = fid.components(separatedBy: "/").filter { $0 != ".." && !$0.isEmpty }.joined(separator: "/")
        let local = dir.appendingPathComponent(safe)
        try? FileManager.default.createDirectory(at: local.deletingLastPathComponent(), withIntermediateDirectories: true)
        var have: Int64 = 0
        if let a = try? FileManager.default.attributesOfItem(atPath: local.path),
           let n = a[.size] as? NSNumber { have = n.int64Value }

        if !isAppendOnly(fid) {
            if FileManager.default.fileExists(atPath: local.path), have == size, savedMtime(fid) == mtime {
                step(files, i + 1, grabbed, progress, done); return
            }
            let part = local.appendingPathExtension("part")
            try? FileManager.default.removeItem(at: part)
            pullWhole(files, i, fid, size, mtime, local, part, 0, grabbed, 0, progress, done)
            return
        }

        if have == size { step(files, i + 1, grabbed, progress, done); return }
        if have > size { try? FileManager.default.removeItem(at: local); have = 0 }
        pull(files, i, fid, size, local, have, grabbed, 0, progress, done)
    }

    private func isAppendOnly(_ fid: String) -> Bool {
        return fid.hasPrefix("transcripts-")
    }

    private static let mtimeKey = "lustre.mirror.mtimes"

    private func savedMtime(_ fid: String) -> Double {
        let d = UserDefaults.standard.dictionary(forKey: MirrorSync.mtimeKey) as? [String: Double] ?? [:]
        return d[fid] ?? 0
    }

    private func setMtime(_ fid: String, _ v: Double) {
        var d = UserDefaults.standard.dictionary(forKey: MirrorSync.mtimeKey) as? [String: Double] ?? [:]
        d[fid] = v
        UserDefaults.standard.set(d, forKey: MirrorSync.mtimeKey)
    }

    private func pullWhole(_ files: [[String: Any]], _ i: Int, _ fid: String, _ size: Int64, _ mtime: Double,
                           _ local: URL, _ part: URL, _ got: Int64, _ grabbed: Int64, _ tries: Int,
                           _ progress: @escaping (String) -> Void, _ done: @escaping (Bool, String) -> Void) {
        if got >= size {
            if FileManager.default.fileExists(atPath: part.path) {
                try? FileManager.default.removeItem(at: local)
                try? FileManager.default.moveItem(at: part, to: local)
                setMtime(fid, mtime)
            }
            step(files, i + 1, grabbed, progress, done); return
        }
        let q = fid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fid
        guard let freq = req("/app/mirror/file?id=\(q)&from=\(got)&limit=8388608") else {
            try? FileManager.default.removeItem(at: part)
            step(files, i + 1, grabbed, progress, done); return
        }
        let pct = size > 0 ? Int(got * 100 / size) : 0
        progress("\(i + 1)/\(files.count) \(fid) \(pct)%")
        URLSession.shared.downloadTask(with: freq) { tmp, resp, _ in
            defer { if let tmp { try? FileManager.default.removeItem(at: tmp) } }
            var added: Int64 = 0
            if let tmp, let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 {
                if !FileManager.default.fileExists(atPath: part.path) {
                    FileManager.default.createFile(atPath: part.path, contents: nil)
                }
                if let out = try? FileHandle(forWritingTo: part),
                   let inp = InputStream(url: tmp) {
                    out.seekToEndOfFile()
                    inp.open()
                    var buf = [UInt8](repeating: 0, count: 512 * 1024)
                    while inp.hasBytesAvailable {
                        let n = inp.read(&buf, maxLength: buf.count)
                        if n <= 0 { break }
                        out.write(Data(bytes: buf, count: n))
                        added += Int64(n)
                    }
                    inp.close()
                    try? out.close()
                }
            }
            if added > 0 {
                self.pullWhole(files, i, fid, size, mtime, local, part, got + added, grabbed + added, 0, progress, done)
            } else if tries < 2 {
                self.pullWhole(files, i, fid, size, mtime, local, part, got, grabbed, tries + 1, progress, done)
            } else {
                try? FileManager.default.removeItem(at: part)
                self.step(files, i + 1, grabbed, progress, done)
            }
        }.resume()
    }

    private func pull(_ files: [[String: Any]], _ i: Int, _ fid: String, _ size: Int64, _ local: URL,
                      _ have: Int64, _ grabbed: Int64, _ tries: Int,
                      _ progress: @escaping (String) -> Void, _ done: @escaping (Bool, String) -> Void) {
        if have >= size { step(files, i + 1, grabbed, progress, done); return }
        let q = fid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fid
        guard let freq = req("/app/mirror/file?id=\(q)&from=\(have)&limit=8388608") else {
            step(files, i + 1, grabbed, progress, done); return
        }
        let pct = size > 0 ? Int(have * 100 / size) : 0
        progress("\(i + 1)/\(files.count) \(fid) \(pct)%")
        URLSession.shared.downloadTask(with: freq) { tmp, resp, _ in
            defer { if let tmp { try? FileManager.default.removeItem(at: tmp) } }
            var added: Int64 = 0
            if let tmp, let code = (resp as? HTTPURLResponse)?.statusCode, code == 200 {
                if !FileManager.default.fileExists(atPath: local.path) {
                    FileManager.default.createFile(atPath: local.path, contents: nil)
                }
                if let out = try? FileHandle(forWritingTo: local),
                   let inp = InputStream(url: tmp) {
                    out.seekToEndOfFile()
                    inp.open()
                    var buf = [UInt8](repeating: 0, count: 512 * 1024)
                    while inp.hasBytesAvailable {
                        let n = inp.read(&buf, maxLength: buf.count)
                        if n <= 0 { break }
                        out.write(Data(bytes: buf, count: n))
                        added += Int64(n)
                    }
                    inp.close()
                    try? out.close()
                }
            }
            if added > 0 {
                self.pull(files, i, fid, size, local, have + added, grabbed + added, 0, progress, done)
            } else if tries < 2 {
                self.pull(files, i, fid, size, local, have, grabbed, tries + 1, progress, done)
            } else {
                self.step(files, i + 1, grabbed, progress, done)
            }
        }.resume()
    }
}


final class LockGate {
    static let shared = LockGate()
    static let key = "lustre.lock.on"

    private var cover: UIView?
    private var authing = false

    var enabled: Bool {
        get { false }
        set { UserDefaults.standard.set(newValue, forKey: LockGate.key) }
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first
    }

    func coverNow() {
        guard enabled, cover == nil, let w = keyWindow else { return }
        let v = UIView(frame: w.bounds)
        v.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let lock = UILabel()
        lock.text = "🔒"
        lock.font = .systemFont(ofSize: 44)
        lock.textAlignment = .center
        lock.frame = v.bounds
        lock.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.addSubview(lock)
        w.addSubview(v)
        cover = v
    }

    func unlockIfNeeded() {
        guard enabled else { uncover(); return }
        guard cover != nil, !authing else { return }
        authing = true
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "解锁 Lustre") { ok, _ in
            DispatchQueue.main.async {
                self.authing = false
                if ok { self.uncover() }
            }
        }
    }

    private func uncover() {
        cover?.removeFromSuperview()
        cover = nil
    }
}


final class HealthWatch {
    static let shared = HealthWatch()
    private var started = false
    private let lock = NSLock()
    private var lastUp = Date.distantPast

    private var pending: [HKQuantityType] = []

    static let logKey = "lustre.hw.log"
    static func note(_ ev: String, _ detail: String = "") {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "MM-dd HH:mm:ss"
        var log = UserDefaults.standard.stringArray(forKey: logKey) ?? []
        log.append("\(f.string(from: Date())) \(ev) \(detail)".trimmingCharacters(in: .whitespaces))
        UserDefaults.standard.set(Array(log.suffix(120)), forKey: logKey)
    }
    static func envTag() -> String {
        func tag() -> String {
            let app = UIApplication.shared
            let st: String
            switch app.applicationState {
            case .active: st = "active"
            case .inactive: st = "inactive"
            case .background: st = "bg"
            @unknown default: st = "?"
            }
            return "state=\(st) unlocked=\(app.isProtectedDataAvailable)"
        }
        if Thread.isMainThread { return tag() }
        var s = ""
        DispatchQueue.main.sync { s = tag() }
        return s
    }
    private static func shortId(_ id: String) -> String {
        id.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
    }

    private let ids = ["HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierStepCount",
                       "HKQuantityTypeIdentifierOxygenSaturation", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
                       "HKQuantityTypeIdentifierRespiratoryRate", "HKQuantityTypeIdentifierAppleSleepingWristTemperature"]

    func start() {
        guard !started, HKHealthStore.isHealthDataAvailable() else { return }
        started = true
        Self.note("start", Self.envTag())
        let store = BackgroundSync.shared.store
        for id in ids {
            guard let qt = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) else { continue }
            let q = HKObserverQuery(sampleType: qt, predicate: nil) { [weak self] _, done, err in
                Self.note("fire", "\(Self.shortId(id)) \(Self.envTag()) \(err.map { "err=\($0.localizedDescription)" } ?? "")")
                self?.uploadThrottled { done() }
            }
            store.execute(q)
            enable(qt, id: id)
        }
    }

    private func enable(_ qt: HKQuantityType, id: String) {
        BackgroundSync.shared.store.enableBackgroundDelivery(for: qt, frequency: .immediate) { [weak self] ok, err in
            Self.note(ok ? "enable+" : "enable-", "\(Self.shortId(id)) \(err?.localizedDescription ?? "")")
            guard !ok, let s = self else { return }
            s.lock.lock()
            if !s.pending.contains(qt) { s.pending.append(qt) }
            s.lock.unlock()
        }
    }

    func retryPending() {
        lock.lock()
        let todo = pending
        pending = []
        lock.unlock()
        guard !todo.isEmpty else { return }
        Self.note("retry", "\(todo.count)项 \(Self.envTag())")
        for qt in todo { enable(qt, id: qt.identifier) }
    }

    private func uploadThrottled(_ done: @escaping () -> Void) {
        lock.lock()
        let go = Date().timeIntervalSince(lastUp) > 90
        if go { lastUp = Date() }
        lock.unlock()
        guard go else { Self.note("skip", "90秒内已传过"); done(); return }
        BackgroundSync.shared.pushHealth { done() }
    }
}

final class BackgroundSync {
    static let shared = BackgroundSync()
    static let taskId = "__LX_BUNDLE__.refresh"
    static let onKey = "lustre.bg.on"
    static let seenKey = "lustre.bg.lastSeenId"
    static let ranKey = "lustre.bg.lastRun"

    let store = HKHealthStore()

    var enabled: Bool {
        get { true }
        set { UserDefaults.standard.set(newValue, forKey: BackgroundSync.onKey) }
    }

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundSync.taskId, using: nil) { task in
            self.handle(task as? BGAppRefreshTask)
        }
    }

    func schedule() {
        guard enabled else { return }
        let req = BGAppRefreshTaskRequest(identifier: BackgroundSync.taskId)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    func handle(_ task: BGAppRefreshTask?) {
        schedule()
        guard let task = task else { return }
        let work = DispatchWorkItem { }
        task.expirationHandler = { work.cancel() }
        run { task.setTaskCompleted(success: true) }
    }

    func run(_ done: @escaping () -> Void) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: BackgroundSync.ranKey)
        let group = DispatchGroup()
        group.enter(); checkMessages { group.leave() }
        group.enter(); pushHealth { group.leave() }
        group.notify(queue: .main) { done() }
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest? {
        guard !LustreConfig.secret.isEmpty, let url = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 20)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = b
        }
        return r
    }

    func checkMessages(_ done: @escaping () -> Void) {
        let seen = UserDefaults.standard.integer(forKey: BackgroundSync.seenKey)
        guard let req = request("/app/history?since=\(seen)&limit=20") else { done(); return }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            defer { done() }
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let msgs = obj["messages"] as? [[String: Any]] else { return }
            var maxId = seen
            var newest: String?
            for m in msgs {
                let id = (m["id"] as? Int) ?? 0
                if id > maxId { maxId = id }
                let from = (m["from"] as? String) ?? ""
                let kind = (m["kind"] as? String) ?? ""
                if from != "human" && (kind == "reply" || kind == "user") {
                    let t = (m["text"] as? String) ?? ""
                    if !t.isEmpty { newest = t }
                }
            }
            guard maxId > seen else { return }
            UserDefaults.standard.set(maxId, forKey: BackgroundSync.seenKey)
            guard seen > 0, let text = newest else { return }
            let fresh = msgs.filter { (($0["from"] as? String) ?? "") != "human" && (($0["id"] as? Int) ?? 0) > seen }.count
            guard !ApnsToken.serverPushOwns else { return }
            self.notify(text, badge: max(1, fresh))
        }.resume()
    }

    func notify(_ text: String, badge: Int = 0) {
        let c = UNMutableNotificationContent()
        c.title = LXNick.yan
        c.body = String(text.prefix(120))
        c.sound = .default
        if badge > 0 { c.badge = NSNumber(value: badge) }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func pushHealth(_ done: @escaping () -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { HealthWatch.note("push", "本机无健康数据"); done(); return }
        HealthPlugin.collect(store: store) { snap in
            HealthWatch.note("read", "\(snap.count)项 \(HealthWatch.envTag())")
            guard !snap.isEmpty else { done(); return }
            let log = UserDefaults.standard.stringArray(forKey: HealthWatch.logKey) ?? []
            guard let body = try? JSONSerialization.data(withJSONObject: ["health": snap, "hwlog": log]),
                  let req = self.request("/app/vitals", method: "POST", body: body) else { done(); return }
            URLSession.shared.dataTask(with: req) { _, resp, _ in
                if (resp as? HTTPURLResponse)?.statusCode == 200 {
                    let keep = (UserDefaults.standard.stringArray(forKey: HealthWatch.logKey) ?? []).suffix(5)
                    UserDefaults.standard.set(Array(keep), forKey: HealthWatch.logKey)
                    HealthWatch.shared.retryPending()
                }
                done()
            }.resume()
        }
    }
}

enum ImeLine {
    static let key = "imeLineMode"
    static let color = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
    static var mode = UserDefaults.standard.integer(forKey: key)
    private(set) static var installed = false
    static var lastProbe = "(还没打过字)"
    private(set) static var hooked: [String] = []

    static func apply(_ m: Int, on view: UIView?) {
        mode = m
        UserDefaults.standard.set(m, forKey: key)
        if let v = view {
            paint(v, m == 1 ? color : nil)
            if m >= 1 { paintUnderline(v) } else { restore(v) }
        }
    }
    static func paint(_ v: UIView, _ c: UIColor?) {
        v.tintColor = c
        v.subviews.forEach { paint($0, c) }
    }

    static func install() {
        guard !installed, let cls = NSClassFromString("WKContentView") else { return }
        installed = true
        swap(cls, "setAttributedMarkedText:selectedRange:", #selector(NSObject.lx_setAttributedMarkedText(_:selectedRange:)))
        swap(cls, "setMarkedText:selectedRange:", #selector(NSObject.lx_setMarkedText(_:selectedRange:)))
        for name in ["_UITextUnderlineView", "_UITextSelectionRangeView"] {
            guard let c = NSClassFromString(name) else { continue }
            let block: @convention(block) (AnyObject) -> UIColor = { _ in
                ImeLine.mode >= 1 ? ImeLine.color : UIColor(red: 0, green: 0.569, blue: 1, alpha: 1)
            }
            if class_addMethod(c, NSSelectorFromString("tintColor"), imp_implementationWithBlock(block), "@@:") {
                hooked.append(name + ".tintColor")
            } else if let orig = class_getInstanceMethod(c, NSSelectorFromString("tintColor")) {
                method_setImplementation(orig, imp_implementationWithBlock(block))
                hooked.append(name + ".tintColor(替换)")
            }
        }
    }
    private static func swap(_ cls: AnyClass, _ origName: String, _ newSel: Selector) {
        guard let orig = class_getInstanceMethod(cls, NSSelectorFromString(origName)),
              let repl = class_getInstanceMethod(NSObject.self, newSel) else { return }
        hooked.append(origName)
        if class_addMethod(cls, newSel, method_getImplementation(repl), method_getTypeEncoding(repl)),
           let added = class_getInstanceMethod(cls, newSel) {
            method_exchangeImplementations(orig, added)
        } else {
            method_exchangeImplementations(orig, repl)
        }
    }
    static let overlayName = "lx.star"
    static func paintUnderline(_ root: UIView, _ depth: Int = 0) {
        guard depth < 7 else { return }
        for v in root.subviews {
            if String(describing: type(of: v)).contains("TextUnderlineView") { restyle(v) }
            paintUnderline(v, depth + 1)
        }
    }
    private static func restyle(_ host: UIView) {
        host.layer.sublayers?.filter { $0.name == overlayName }.forEach { $0.removeFromSuperlayer() }
        var rects: [CGRect] = []
        if host.subviews.isEmpty {
            if host.bounds.height <= 5, host.bounds.width > 0 {
                host.layer.contents = nil
                rects = [host.bounds]
            }
        } else {
            for sub in host.subviews {
                sub.isHidden = true
                if sub.frame.width > 0 { rects.append(sub.frame) }
            }
        }
        for r in rects {
            let l = CALayer()
            l.name = overlayName
            l.frame = r
            l.backgroundColor = color.cgColor
            l.cornerRadius = min(r.height / 2, 2)
            l.zPosition = 999
            host.layer.addSublayer(l)
        }
    }
    static func restore(_ root: UIView, _ depth: Int = 0) {
        guard depth < 7 else { return }
        for v in root.subviews {
            if String(describing: type(of: v)).contains("TextUnderlineView") {
                v.layer.sublayers?.filter { $0.name == overlayName }.forEach { $0.removeFromSuperlayer() }
                v.subviews.forEach { $0.isHidden = false }
            }
            restore(v, depth + 1)
        }
    }
    static func stainSoon(_ v: NSObject) {
        guard let view = v as? UIView else { return }
        DispatchQueue.main.async { if mode >= 1 { paintUnderline(view) } else { restore(view) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { if mode >= 1 { paintUnderline(view) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { if mode >= 1 { paintUnderline(view) } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            let snap = probeColors(view)
            if !snap.isEmpty { lastProbe = snap }
        }
    }
    static func probeColors(_ root: UIView, _ d: Int = 0) -> String {
        guard d < 7 else { return "" }
        var out: [String] = []
        for v in root.subviews {
            let t = String(describing: type(of: v))
            if t.contains("TextUnderlineView") {
                let mine = (v.layer.sublayers ?? []).filter { $0.name == overlayName }.count
                out.append(String(format: "%@ %.0fx%.0f 子视图=%d 我们的层=%d",
                                  t, v.bounds.width, v.bounds.height, v.subviews.count, mine))
                for sub in v.subviews {
                    out.append(String(format: "  · %@ (%.0f,%.0f %.0fx%.0f) hidden=%@ contents=%@",
                                      String(describing: type(of: sub)),
                                      sub.frame.origin.x, sub.frame.origin.y,
                                      sub.frame.width, sub.frame.height,
                                      sub.isHidden ? "Y" : "N",
                                      sub.layer.contents == nil ? "无" : "有"))
                }
            }
            let deeper = probeColors(v, d + 1)
            if !deeper.isEmpty { out.append(deeper) }
        }
        return out.joined(separator: "\n")
    }

    static func highlighted(_ s: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: s)
        guard m.length > 0 else { return m }
        let all = NSRange(location: 0, length: m.length)
        m.removeAttribute(.underlineStyle, range: all)
        m.removeAttribute(.underlineColor, range: all)
        let alpha: CGFloat = mode == 1 ? 0.30 : (mode == 2 ? 0.45 : 0.62)
        m.addAttribute(.backgroundColor, value: color.withAlphaComponent(alpha), range: all)
        return m
    }

    static func tinted(_ s: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: s)
        guard m.length > 0 else { return m }
        let all = NSRange(location: 0, length: m.length)
        m.addAttribute(.underlineColor, value: color, range: all)
        if m.attribute(.underlineStyle, at: 0, effectiveRange: nil) == nil {
            m.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: all)
        }
        return m
    }
}

extension NSObject {
    @objc func lx_setAttributedMarkedText(_ s: NSAttributedString?, selectedRange r: NSRange) {
        let out = (ImeLine.mode >= 1 && s != nil && s!.length > 0) ? ImeLine.highlighted(s!) : s
        self.lx_setAttributedMarkedText(out, selectedRange: r)
    }
    @objc func lx_setMarkedText(_ t: String?, selectedRange r: NSRange) {
        if ImeLine.mode >= 1, let str = t, !str.isEmpty,
           self.responds(to: #selector(NSObject.lx_setAttributedMarkedText(_:selectedRange:))) {
            self.lx_setAttributedMarkedText(ImeLine.highlighted(NSAttributedString(string: str)), selectedRange: r)
            return
        }
        self.lx_setMarkedText(t, selectedRange: r)
    }
}

enum ImeDiag {
    static func report(_ webView: UIView?) -> String {
        var L: [String] = []
        L.append("iOS \(UIDevice.current.systemVersion)  mode=\(ImeLine.mode)  壳=g2")
        L.append("installed=\(ImeLine.installed) hooked=\(ImeLine.hooked.isEmpty ? "无" : ImeLine.hooked.joined(separator: ","))")
        for n in ["WKContentView", "WKApplicationStateTrackingView", "WKWebView"] {
            L.append("类 \(n): \(NSClassFromString(n) == nil ? "找不到" : "在")")
        }
        let setMarked = NSSelectorFromString("setMarkedText:selectedRange:")
        let setAttr = NSSelectorFromString("setAttributedMarkedText:selectedRange:")
        func walk(_ v: UIView, _ d: Int) {
            let t = String(describing: type(of: v))
            var flags: [String] = []
            if v.responds(to: setMarked) { flags.append("setMarkedText") }
            if v.responds(to: setAttr) { flags.append("setAttributedMarkedText") }
            if v.isFirstResponder { flags.append("焦点在此") }
            L.append(String(repeating: "· ", count: d) + t + (flags.isEmpty ? "" : "  ← " + flags.joined(separator: "+")))
            v.subviews.forEach { walk($0, d + 1) }
        }
        if let wv = webView { walk(wv, 0) } else { L.append("拿不到 webView") }
        func hue(_ c: UIColor?) -> String {
            guard let c else { return "nil" }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "#%02X%02X%02X@%.2f", Int(r*255), Int(g*255), Int(b*255), a)
        }
        func probe(_ v: UIView, _ d: Int) {
            guard d < 6 else { return }
            for s in v.subviews {
                let t = String(describing: type(of: s))
                if t.contains("TextUnderline") || t.contains("SelectionRange") || t.contains("MarkedText") {
                    L.append("色 \(t): tint=\(hue(s.tintColor)) bg=\(hue(s.backgroundColor)) layer=\(s.layer.backgroundColor.map { hue(UIColor(cgColor: $0)) } ?? "nil")")
                }
                probe(s, d + 1)
            }
        }
        if let wv = webView { probe(wv, 0) }
        L.append("── 打字那一刻采到的 ──")
        L.append(ImeLine.lastProbe)
        return L.joined(separator: "\n")
    }
}

final class LXShadowView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }
}

@objc(NativeInputPlugin)
public class NativeInputPlugin: CAPPlugin, CAPBridgedPlugin, UITextViewDelegate {
    public let identifier = "NativeInputPlugin"
    public let jsName = "NativeInput"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "enable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setFrame", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setStyle", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setVisible", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "focusInput", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "blurInput", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cardEnable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cardDisable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cardState", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cardSuspend", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cardHide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "modelSpec", returnType: CAPPluginReturnPromise)
    ]

    var tv: LXTextView?
    var kbTokens: [NSObjectProtocol] = []

    static weak var live: NativeInputPlugin?

    var card: UIView?
    var cardBlur: UIVisualEffectView?
    var cardHeightC: NSLayoutConstraint?
    var sendBtn: UIButton?
    var plusBtn: UIButton?
    var micBtn: UIButton?
    var modelBtn: UIButton?
    var cardMinH: CGFloat = 96
    var cardMaxH: CGFloat = 220
    var cardTint: UIView?
    var attsRow: UIScrollView?
    var attsStack: UIStackView?
    var attsHC: NSLayoutConstraint?
    var tvTopC: NSLayoutConstraint?
    var attsCount = 0
    var phLabel: UILabel?
    var sendHasText = false
    var modelFgC = UIColor.white
    var effortFgC = UIColor(red: 0.47, green: 0.52, blue: 0.61, alpha: 1)
    var accentC: UIColor?
    var quoteBar: UIView?
    var quoteAccentV: UIView?
    var quoteNameL: UILabel?
    var quoteTextL: UILabel?
    var quoteXBtn: UIButton?
    var quoteHC: NSLayoutConstraint?
    var quoteTopC: NSLayoutConstraint?
    var quoteIsOn = false
    var recorder: AVAudioRecorder?
    var recTimer: Timer?
    var recT0: Date?
    var recURL: URL?
    var recCancelBtn: UIButton?
    var micWC: NSLayoutConstraint?
    var chipFgC = UIColor(white: 0.82, alpha: 1)

    @objc func enable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if self.tv == nil {
                let t = LXTextView()
                t.owner = self
                t.delegate = self
                t.backgroundColor = .clear
                t.textColor = UIColor(red: 0xE3/255, green: 0xE2/255, blue: 0xE7/255, alpha: 1)
                t.tintColor = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
                t.keyboardAppearance = .dark
                t.textContainerInset = UIEdgeInsets(top: 9, left: 0, bottom: 9, right: 0)
                t.textContainer.lineFragmentPadding = 0
                t.showsVerticalScrollIndicator = false
                t.isHidden = true
                self.bridge?.webView?.addSubview(t)
                self.tv = t
                self.hookKeyboard()
            }
            self.applyStyle(call)
            call.resolve(["ok": true])
        }
    }

    @objc func disable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.tv?.resignFirstResponder()
            self.tv?.removeFromSuperview()
            self.tv = nil
            self.card?.removeFromSuperview()
            self.card = nil; self.cardBlur = nil; self.cardShadow = nil; self.cardHeightC = nil
            self.plusBtn = nil; self.micBtn = nil; self.sendBtn = nil; self.modelBtn = nil
            self.cardTint = nil; self.attsRow = nil; self.attsStack = nil
            self.attsHC = nil; self.tvTopC = nil; self.attsCount = 0
            self.phLabel = nil; self.sendHasText = false
            self.teardownCardExtras()
            for tk in self.kbTokens { NotificationCenter.default.removeObserver(tk) }
            self.kbTokens = []
            call.resolve(["ok": true])
        }
    }

    func applyStyle(_ call: CAPPluginCall) {
        guard let t = tv else { return }
        if let hex = call.getString("color"), let c = NativeInputPlugin.color(hex) { t.textColor = c }
        let size = CGFloat(call.getFloat("fontSize") ?? 16)
        t.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: size)
            ?? UIFont.systemFont(ofSize: size)
        let padTop = CGFloat(call.getFloat("padTop") ?? 9)
        let padBottom = call.getFloat("padBottom").map { CGFloat($0) } ?? padTop
        let padLeft = CGFloat(call.getFloat("padLeft") ?? 2)
        let padRight = CGFloat(call.getFloat("padRight") ?? 2)
        t.textContainerInset = UIEdgeInsets(top: padTop, left: padLeft,
                                            bottom: padBottom, right: padRight)
        layoutPlaceholder()
    }
    @objc func setStyle(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.applyStyle(call); call.resolve(["ok": true]) }
    }

    @objc func setFrame(_ call: CAPPluginCall) {
        let x = CGFloat(call.getFloat("x") ?? 0), y = CGFloat(call.getFloat("y") ?? 0)
        let w = CGFloat(call.getFloat("width") ?? 0), h = CGFloat(call.getFloat("height") ?? 0)
        DispatchQueue.main.async {
            self.tv?.frame = CGRect(x: x, y: y, width: w, height: h)
            call.resolve(["ok": true])
        }
    }

    @objc func setVisible(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async {
            self.tv?.isHidden = !on
            if !on { self.tv?.resignFirstResponder() }
            call.resolve(["ok": true])
        }
    }

    @objc func focusInput(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.tv?.becomeFirstResponder(); call.resolve(["ok": true]) }
    }
    @objc func blurInput(_ call: CAPPluginCall) {
        DispatchQueue.main.async { self.tv?.resignFirstResponder(); call.resolve(["ok": true]) }
    }
    @objc func getText(_ call: CAPPluginCall) {
        DispatchQueue.main.async { call.resolve(["text": self.tv?.text ?? ""]) }
    }
    @objc func setText(_ call: CAPPluginCall) {
        let s = call.getString("text") ?? ""
        DispatchQueue.main.async {
            self.tv?.text = s
            self.pushChange()
            self.tv?.layoutIfNeeded()
            self.updateCardHeight()
            call.resolve(["ok": true])
        }
    }
    @objc func clear(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.clearText()
            call.resolve(["ok": true])
        }
    }

    func clearText() {
        tv?.text = ""
        pushChange()
        tv?.layoutIfNeeded()
        updateCardHeight()
    }

    func pickInto(_ id: String) {
        let orig = LXOutbox.shared.original
        PickerPlugin.pickNative(id, original: orig) { files in
            LXOutbox.shared.addPicked(files)
        }
    }

    static let cardEnableKey = "lx.card.enable"
    static let cardStateKey = "lx.card.state"

    func cardBootNative() {
        LXUsage.refresh()
        LXSessionsAPI.refresh()
        LXUsage.onLoaded = { [weak self] in self?.refreshModelTitle(); self?.refreshCtxLive() }
        cardEnable(LXFakeCall.make("cardEnable", LXFakeCall.load(NativeInputPlugin.cardEnableKey)))
        var st = LXFakeCall.load(NativeInputPlugin.cardStateKey)
        if (st["ph"] as? String)?.isEmpty != false { st["ph"] = "Chat with Claude" }
        if modelSpecD["models"] == nil { modelSpecD = NativeInputPlugin.nativeModelSpec() }
        if (st["modelName"] as? String)?.isEmpty != false {
            st["modelName"] = modelSpecD["modelName"] ?? ""
            st["modelEffort"] = modelSpecD["effortLabel"] ?? ""
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.cardState(LXFakeCall.make("cardState", st))
        }
    }

    @objc func cardEnable(_ call: CAPPluginCall) {
        LXFakeCall.save(call, NativeInputPlugin.cardEnableKey)
        DispatchQueue.main.async {
            guard #available(iOS 15.0, *),
                  let host = self.bridge?.viewController?.view else {
                call.resolve(["ok": false]); return
            }
            if self.tv == nil {
                let t = LXTextView()
                t.owner = self
                t.delegate = self
                t.backgroundColor = .clear
                t.tintColor = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
                t.keyboardAppearance = .dark
                t.textContainer.lineFragmentPadding = 0
                t.showsVerticalScrollIndicator = false
                self.tv = t
                self.hookKeyboard()
            }
            guard let t = self.tv else { call.resolve(["ok": false]); return }
            t.isHidden = false
            t.isScrollEnabled = true
            let homeOnStage = host.subviews.contains(where: { $0 is HomeView && !$0.isHidden })
            let hidden = (call.getBool("hidden") ?? homeOnStage) || homeOnStage
            self.overlayHidden = hidden
            if self.card != nil {
                if hidden || !self.tvCardConstraints.isEmpty { self.card?.isHidden = hidden }
                self.applyStyle(call); self.applyCardTheme(call)
                call.resolve(["ok": true]); return
            }

            let radius = CGFloat(call.getFloat("radius") ?? 22)
            let marginX = CGFloat(call.getFloat("marginX") ?? 10)
            let gapBottom = CGFloat(call.getFloat("gapBottom") ?? 8)
            self.cardMinH = CGFloat(call.getFloat("minH") ?? 96)
            self.cardMaxH = CGFloat(call.getFloat("maxH") ?? 220)

            let cardV = UIView()
            cardV.translatesAutoresizingMaskIntoConstraints = false
            cardV.layer.cornerRadius = radius
            cardV.layer.cornerCurve = .continuous
            cardV.clipsToBounds = false
            let shadowV = LXShadowView()
            shadowV.translatesAutoresizingMaskIntoConstraints = false
            shadowV.isUserInteractionEnabled = false
            shadowV.layer.cornerRadius = radius
            shadowV.layer.shadowOffset = CGSize(width: 0, height: 6)
            shadowV.layer.shadowRadius = 9
            cardV.addSubview(shadowV)
            let cardFx: UIVisualEffect
            if #available(iOS 26.0, *) { cardFx = UIGlassEffect() } else { cardFx = UIBlurEffect(style: .systemThickMaterialDark) }
            let blur = UIVisualEffectView(effect: cardFx)
            blur.translatesAutoresizingMaskIntoConstraints = false
            blur.layer.cornerRadius = radius
            blur.layer.cornerCurve = .continuous
            blur.clipsToBounds = true
            if #available(iOS 26.0, *) { blur.cornerConfiguration = .uniformCorners(radius: .fixed(radius)) }
            cardV.addSubview(blur)
            let tint = UIView(); tint.translatesAutoresizingMaskIntoConstraints = false
            tint.layer.cornerRadius = radius
            tint.layer.cornerCurve = .continuous
            tint.clipsToBounds = true
            cardV.addSubview(tint)
            NSLayoutConstraint.activate([
                tint.topAnchor.constraint(equalTo: cardV.topAnchor),
                tint.bottomAnchor.constraint(equalTo: cardV.bottomAnchor),
                tint.leadingAnchor.constraint(equalTo: cardV.leadingAnchor),
                tint.trailingAnchor.constraint(equalTo: cardV.trailingAnchor),
                shadowV.topAnchor.constraint(equalTo: cardV.topAnchor),
                shadowV.bottomAnchor.constraint(equalTo: cardV.bottomAnchor),
                shadowV.leadingAnchor.constraint(equalTo: cardV.leadingAnchor),
                shadowV.trailingAnchor.constraint(equalTo: cardV.trailingAnchor)])
            self.cardTint = tint
            self.cardShadow = shadowV
            if #available(iOS 26.0, *) { cardV.layer.borderWidth = 0 }
            else { cardV.layer.borderWidth = 1 }

            let chip = UIColor(white: 1, alpha: 0.09)
            let mkIcon = { (name: String) -> UIButton in
                let b = UIButton(type: .system)
                b.translatesAutoresizingMaskIntoConstraints = false
                b.setImage(UIImage(systemName: name, withConfiguration:
                    UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)), for: .normal)
                b.tintColor = UIColor(white: 0.82, alpha: 1)
                b.backgroundColor = chip
                b.layer.cornerRadius = 17
                return b
            }
            let plus = mkIcon("plus")
            plus.setImage(NativeInputPlugin.plusIcon(), for: .normal)
            let mic = mkIcon("mic")
            mic.setImage(NativeInputPlugin.micIcon(), for: .normal)

            mic.titleLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            let recX = UIButton(type: .system)
            recX.translatesAutoresizingMaskIntoConstraints = false
            recX.setImage(UIImage(systemName: "xmark", withConfiguration:
                UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
            recX.tintColor = UIColor(white: 0.82, alpha: 1)
            recX.backgroundColor = chip
            recX.layer.cornerRadius = 17
            recX.isHidden = true
            recX.addAction(UIAction { [weak self] _ in self?.recStop(send: false) }, for: .touchUpInside)
            self.recCancelBtn = recX
            let model = UIButton(type: .system)
            model.translatesAutoresizingMaskIntoConstraints = false
            model.titleLabel?.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 13) ?? UIFont.systemFont(ofSize: 13)
            model.backgroundColor = chip
            model.layer.cornerRadius = 17
            // 0925 她说字没上下对称:量她截图,大写字母正中但 p 的下伸把视觉重心往下拖——整体上提 1pt(光学居中)
            model.contentEdgeInsets = UIEdgeInsets(top: 0, left: 13, bottom: 2, right: 13)
            let send = UIButton(type: .system)
            send.translatesAutoresizingMaskIntoConstraints = false
            send.layer.cornerRadius = 17
            send.backgroundColor = UIColor(red: 0xD7/255, green: 0xEA/255, blue: 0xF8/255, alpha: 1)
            send.tintColor = .black

            send.addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                LXOutbox.shared.send(text: s.tv?.text ?? "")
            }, for: .touchUpInside)
            plus.addAction(UIAction { [weak self] _ in self?.showPlusSheet() }, for: .touchUpInside)
            model.addAction(UIAction { [weak self] _ in self?.showModelSheet() }, for: .touchUpInside)
            mic.addAction(UIAction { [weak self] _ in
                guard let s = self else { return }
                if s.recorder != nil { s.recStop(send: true) } else { s.showMicMiniMenu() }
            }, for: .touchUpInside)
            self.plusBtn = plus; self.micBtn = mic; self.sendBtn = send; self.modelBtn = model

            t.translatesAutoresizingMaskIntoConstraints = false
            t.removeFromSuperview()
            let row = UIScrollView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.showsHorizontalScrollIndicator = false
            row.isHidden = true
            let stack = UIStackView()
            stack.axis = .horizontal
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(stack)
            cardV.addSubview(row)
            self.attsRow = row
            self.attsStack = stack
            let qb = UIView()
            qb.translatesAutoresizingMaskIntoConstraints = false
            qb.layer.cornerRadius = 12
            qb.layer.cornerCurve = .continuous
            qb.layer.borderWidth = 1
            qb.clipsToBounds = true
            qb.isHidden = true
            qb.backgroundColor = UIColor(white: 0x12/255, alpha: 1)
            qb.layer.borderColor = UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10).cgColor
            let qa = UIView(); qa.translatesAutoresizingMaskIntoConstraints = false
            qa.backgroundColor = UIColor(red: 0xA9/255, green: 0xD9/255, blue: 0xEE/255, alpha: 1)
            qb.addSubview(qa)
            let qn = UILabel()
            qn.translatesAutoresizingMaskIntoConstraints = false
            qn.textColor = UIColor(red: 0xA9/255, green: 0xD9/255, blue: 0xEE/255, alpha: 1)
            qn.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .semibold)
            let qt = UILabel()
            qt.translatesAutoresizingMaskIntoConstraints = false
            qt.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 12.5) ?? UIFont.systemFont(ofSize: 12.5)
            qt.textColor = UIColor(red: 0xA5/255, green: 0xB0/255, blue: 0xC6/255, alpha: 1)
            qt.lineBreakMode = .byTruncatingTail
            let qx = UIButton(type: .system)
            qx.translatesAutoresizingMaskIntoConstraints = false
            qx.setImage(UIImage(systemName: "xmark", withConfiguration:
                UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)), for: .normal)
            qx.addAction(UIAction { [weak self] _ in
                LXOutbox.shared.clearQuote()
            }, for: .touchUpInside)
            qb.addSubview(qn); qb.addSubview(qt); qb.addSubview(qx)
            cardV.addSubview(qb)
            self.quoteBar = qb; self.quoteAccentV = qa
            self.quoteNameL = qn; self.quoteTextL = qt; self.quoteXBtn = qx
            cardV.addSubview(t)
            for b in [plus, model, mic, send, recX] { cardV.addSubview(b) }
            host.addSubview(cardV)
            LXStage.settle(host)
            cardV.isHidden = hidden
            self.card = cardV
            self.cardBlur = blur
            NativeInputPlugin.live = self

            let hC = cardV.heightAnchor.constraint(equalToConstant: self.cardMinH)
            self.cardHeightC = hC
            let rowH = row.heightAnchor.constraint(equalToConstant: 0)
            self.attsHC = rowH
            let qbTop = qb.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 0)
            let qbH = qb.heightAnchor.constraint(equalToConstant: 0)
            self.quoteTopC = qbTop; self.quoteHC = qbH
            let micW = mic.widthAnchor.constraint(equalToConstant: 34)
            self.micWC = micW
            NSLayoutConstraint.activate([
                blur.topAnchor.constraint(equalTo: cardV.topAnchor),
                blur.bottomAnchor.constraint(equalTo: cardV.bottomAnchor),
                blur.leadingAnchor.constraint(equalTo: cardV.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: cardV.trailingAnchor),
                row.topAnchor.constraint(equalTo: cardV.topAnchor, constant: 6),
                row.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
                row.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -15),
                rowH,
                stack.topAnchor.constraint(equalTo: row.contentLayoutGuide.topAnchor),
                stack.bottomAnchor.constraint(equalTo: row.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: row.contentLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: row.contentLayoutGuide.trailingAnchor),
                stack.heightAnchor.constraint(equalTo: row.frameLayoutGuide.heightAnchor),
                cardV.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: marginX),
                cardV.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -marginX),
                cardV.bottomAnchor.constraint(equalTo: host.keyboardLayoutGuide.topAnchor, constant: -gapBottom),
                hC,
                plus.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 10),
                plus.bottomAnchor.constraint(equalTo: cardV.bottomAnchor, constant: -8),
                plus.widthAnchor.constraint(equalToConstant: 34),
                plus.heightAnchor.constraint(equalToConstant: 34),
                model.leadingAnchor.constraint(equalTo: plus.trailingAnchor, constant: 7),
                model.centerYAnchor.constraint(equalTo: plus.centerYAnchor),
                model.heightAnchor.constraint(equalToConstant: 34),
                send.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -10),
                send.centerYAnchor.constraint(equalTo: plus.centerYAnchor),
                send.widthAnchor.constraint(equalToConstant: 34),
                send.heightAnchor.constraint(equalToConstant: 34),
                mic.trailingAnchor.constraint(equalTo: send.leadingAnchor, constant: -8),
                mic.centerYAnchor.constraint(equalTo: plus.centerYAnchor),
                micW,
                mic.heightAnchor.constraint(equalToConstant: 34),
                recX.trailingAnchor.constraint(equalTo: mic.leadingAnchor, constant: -8),
                recX.centerYAnchor.constraint(equalTo: plus.centerYAnchor),
                recX.widthAnchor.constraint(equalToConstant: 34),
                recX.heightAnchor.constraint(equalToConstant: 34),
                qbTop,
                qbH,
                qb.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
                qb.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -15),
                qa.leadingAnchor.constraint(equalTo: qb.leadingAnchor),
                qa.topAnchor.constraint(equalTo: qb.topAnchor),
                qa.bottomAnchor.constraint(equalTo: qb.bottomAnchor),
                qa.widthAnchor.constraint(equalToConstant: 3),
                qn.topAnchor.constraint(equalTo: qb.topAnchor, constant: 6),
                qn.leadingAnchor.constraint(equalTo: qb.leadingAnchor, constant: 13),
                qn.trailingAnchor.constraint(equalTo: qx.leadingAnchor, constant: -6),
                qt.topAnchor.constraint(equalTo: qn.bottomAnchor, constant: 1),
                qt.leadingAnchor.constraint(equalTo: qn.leadingAnchor),
                qt.trailingAnchor.constraint(equalTo: qn.trailingAnchor),
                qx.trailingAnchor.constraint(equalTo: qb.trailingAnchor, constant: -6),
                qx.centerYAnchor.constraint(equalTo: qb.centerYAnchor),
                qx.widthAnchor.constraint(equalToConstant: 26),
                qx.heightAnchor.constraint(equalToConstant: 26)
            ])
            self.tvCardConstraints = self.tvConstraintsInCard(t, cardV)
            NSLayoutConstraint.activate(self.tvCardConstraints)
            self.ensurePlaceholder()
            if let ph = call.getString("ph") { self.phLabel?.text = ph }
            self.applyStyle(call)
            self.applyCardTheme(call)
            let mn = call.getString("modelName") ?? call.getString("model") ?? ""
            if mn.isEmpty {
                self.refreshModelTitle()
            } else {
                self.setModelTitle(name: mn, effort: call.getString("modelEffort") ?? "")
            }
            self.updateSendIcon()
            self.updateCardHeight()
            call.resolve(["ok": true, "v": 4])
        }
    }

    func tvConstraintsInCard(_ t: UITextView, _ cardV: UIView) -> [NSLayoutConstraint] {
        guard let plus = plusBtn else { return [] }
        let topRef = quoteBar?.bottomAnchor ?? attsRow?.bottomAnchor ?? cardV.topAnchor
        let hasStuff = attsCount > 0 || quoteIsOn
        let top = t.topAnchor.constraint(equalTo: topRef, constant: hasStuff ? 5 : (attsRow == nil ? 6 : 0))
        tvTopC = top
        return [
            top,
            t.leadingAnchor.constraint(equalTo: cardV.leadingAnchor, constant: 15),
            t.trailingAnchor.constraint(equalTo: cardV.trailingAnchor, constant: -15),
            t.bottomAnchor.constraint(equalTo: plus.topAnchor, constant: -2)
        ]
    }

    @objc func cardDisable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            if let t = self.tv, let web = self.bridge?.webView, self.card != nil {
                t.removeFromSuperview()
                t.translatesAutoresizingMaskIntoConstraints = true
                web.addSubview(t)
            }
            self.card?.removeFromSuperview()
            self.card = nil; self.cardBlur = nil; self.cardShadow = nil; self.cardHeightC = nil
            self.plusBtn = nil; self.micBtn = nil; self.sendBtn = nil; self.modelBtn = nil
            self.cardTint = nil; self.attsRow = nil; self.attsStack = nil
            self.attsHC = nil; self.tvTopC = nil; self.attsCount = 0
            self.phLabel?.removeFromSuperview(); self.phLabel = nil
            self.sendHasText = false
            self.teardownCardExtras()
            call.resolve(["ok": true])
        }
    }

    func teardownCardExtras() {
        if recorder != nil { recStop(send: false) }
        quoteBar = nil; quoteAccentV = nil; quoteNameL = nil; quoteTextL = nil; quoteXBtn = nil
        quoteHC = nil; quoteTopC = nil; quoteIsOn = false
        recCancelBtn = nil; micWC = nil
    }

    func setCardHidden(_ on: Bool) {
        DispatchQueue.main.async {
            self.overlayHidden = on
            self.card?.isHidden = on
            self.card?.alpha = 1
        }
    }

    @objc func cardHide(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async {
            self.overlayHidden = on
            self.card?.isHidden = on
            self.card?.alpha = 1
            call.resolve(["ok": true])
        }
    }

    var tvCardConstraints: [NSLayoutConstraint] = []
    var overlayHidden = false
    var cardShadow: LXShadowView?
    private func homeUp() -> Bool {
        (bridge?.viewController?.view?.subviews ?? []).contains { $0 is HomeView && !$0.isHidden }
    }
    @objc func cardSuspend(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async {
            guard let cardV = self.card, let t = self.tv else { call.resolve(["ok": true]); return }
            if on {
                if !cardV.isHidden {
                    cardV.isHidden = true
                    NSLayoutConstraint.deactivate(self.tvCardConstraints)
                    self.tvCardConstraints = []
                    self.tvTopC = nil
                    t.removeFromSuperview()
                    t.translatesAutoresizingMaskIntoConstraints = true
                    self.bridge?.webView?.addSubview(t)
                    self.phLabel?.isHidden = true
                }
            } else {
                if cardV.isHidden {
                    t.removeFromSuperview()
                    t.translatesAutoresizingMaskIntoConstraints = false
                    cardV.addSubview(t)
                    self.tvCardConstraints = self.tvConstraintsInCard(t, cardV)
                    NSLayoutConstraint.activate(self.tvCardConstraints)
                    cardV.isHidden = self.overlayHidden || self.homeUp()
                    self.phLabel?.isHidden = !(t.text ?? "").isEmpty
                    self.updateCardHeight()
                }
            }
            call.resolve(["ok": true])
        }
    }

    @objc func cardState(_ call: CAPPluginCall) {
        LXFakeCall.save(call, NativeInputPlugin.cardStateKey)
        DispatchQueue.main.async {
            if call.getString("bg") != nil || call.getBool("kbDark") != nil { self.applyCardTheme(call) }
            if let name = call.getString("modelName") {
                self.setModelTitle(name: name, effort: call.getString("modelEffort") ?? "")
            } else if let label = call.getString("model") {
                self.setModelTitle(name: label, effort: "")
            }
            self.syncSendIcon()
            if let ph = call.getString("ph") { self.phLabel?.text = ph; self.layoutPlaceholder() }
            _ = call.getArray("atts")
            _ = call.getBool("quoteOn")
            call.resolve(["ok": true])
        }
    }

    func setQuote(on: Bool, name: String, text: String) {
        quoteIsOn = on
        if on { quoteNameL?.text = name; quoteTextL?.text = text }
        quoteBar?.isHidden = !on
        quoteTopC?.constant = on ? 6 : 0
        quoteHC?.constant = on ? 42 : 0
        tvTopC?.constant = (attsCount > 0 || on) ? 5 : 0
        updateCardHeight()
        card?.superview?.layoutIfNeeded()
    }

    func applyCardTheme(_ call: CAPPluginCall) {
        if let hex = call.getString("bg"), let c = NativeInputPlugin.color(hex) {
            var a = CGFloat(call.getFloat("bgAlpha") ?? 0.55)
            if #available(iOS 26.0, *) { a = 0 }
            cardTint?.backgroundColor = c.withAlphaComponent(a)
        }
        if let bhex = call.getString("border"), let bc = NativeInputPlugin.color(bhex) {
            card?.layer.borderColor = bc.withAlphaComponent(CGFloat(call.getFloat("borderAlpha") ?? 0.35)).cgColor
        }
        if let shex = call.getString("sendBg"), let sc = NativeInputPlugin.color(shex) { sendBtn?.backgroundColor = sc }
        if let sfhex = call.getString("sendFg"), let sfc = NativeInputPlugin.color(sfhex) { sendBtn?.tintColor = sfc }
        if let chex = call.getString("color"), let cc = NativeInputPlugin.color(chex) { tv?.textColor = cc }
        if let phex = call.getString("phColor"), let pc = NativeInputPlugin.color(phex) { phLabel?.textColor = pc }
        if let mhex = call.getString("modelFg"), let mc = NativeInputPlugin.color(mhex) { modelFgC = mc }
        if let ehex = call.getString("effortFg"), let ec = NativeInputPlugin.color(ehex) { effortFgC = ec }
        if let ahex = call.getString("accent"), let ac = NativeInputPlugin.color(ahex) {
            quoteAccentV?.backgroundColor = ac
            quoteNameL?.textColor = ac
            accentC = ac
        }
        if let qhex = call.getString("quoteBg"), let qc = NativeInputPlugin.color(qhex) {
            quoteBar?.backgroundColor = qc.withAlphaComponent(CGFloat(call.getFloat("quoteBgA") ?? 1))
        }
        if let lhex = call.getString("quoteLine"), let lc = NativeInputPlugin.color(lhex) {
            quoteBar?.layer.borderColor = lc.withAlphaComponent(CGFloat(call.getFloat("quoteLineA") ?? 1)).cgColor
        }
        if let shex = call.getString("textSoft"), let sc = NativeInputPlugin.color(shex) { quoteTextL?.textColor = sc }
        if let fhex = call.getString("textFaint"), let fc = NativeInputPlugin.color(fhex) { quoteXBtn?.tintColor = fc }
        if let dark = call.getBool("kbDark") {
            if #available(iOS 26.0, *) {
                cardBlur?.overrideUserInterfaceStyle = dark ? .dark : .light
                if !(cardBlur?.effect is UIGlassEffect) { cardBlur?.effect = UIGlassEffect() }
                cardTint?.backgroundColor = .clear
                card?.layer.borderWidth = 0
                cardShadow?.isHidden = true
            } else {
                cardBlur?.effect = UIBlurEffect(style: dark ? .systemThickMaterialDark : .systemThinMaterialLight)
            }
            cardShadow?.layer.shadowColor = (dark ? UIColor.black : UIColor(red: 35/255, green: 45/255, blue: 55/255, alpha: 1)).cgColor
            cardShadow?.layer.shadowOpacity = dark ? 0.30 : 0.07
            let chip = dark ? UIColor(white: 1, alpha: 0.09) : UIColor(white: 0, alpha: 0.06)
            let fg = dark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.32, alpha: 1)
            chipFgC = fg
            for b in [plusBtn, recCancelBtn] { b?.backgroundColor = chip; b?.tintColor = fg }
            if let m = micBtn { m.backgroundColor = chip; if recorder == nil { m.tintColor = fg } }
            modelBtn?.backgroundColor = chip
            let want: UIKeyboardAppearance = dark ? .dark : .light
            if let t = tv, t.keyboardAppearance != want {
                t.keyboardAppearance = want
                if t.isFirstResponder { t.reloadInputViews() }
            }
        }
    }

    func micDeniedToast() {
        DispatchQueue.main.async {
            LXToast.show("麦克风权限没开：设置→隐私与安全性→麦克风→Lustre", host: self.card?.superview)
        }
    }

    func refreshModelTitle() {
        modelSpecD = NativeInputPlugin.nativeModelSpec()
        setModelTitle(name: (modelSpecD["modelName"] as? String) ?? "",
                      effort: (modelSpecD["effortLabel"] as? String) ?? "")
    }

    func setModelTitle(name: String, effort: String) {
        guard let b = modelBtn else { return }
        b.isHidden = name.isEmpty
        let name = NativeInputPlugin.prettyModel(name)
        let f = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 13) ?? UIFont.systemFont(ofSize: 13)
        let a = NSMutableAttributedString(string: name, attributes: [.font: f, .foregroundColor: modelFgC])
        if !effort.isEmpty {
            a.append(NSAttributedString(string: " " + effort, attributes: [.font: f, .foregroundColor: effortFgC]))
        }
        b.setAttributedTitle(a, for: .normal)
    }

    func updateSendIcon() {
        sendBtn?.setImage(sendHasText ? NativeInputPlugin.arrowIcon(size: 20) : NativeInputPlugin.waveIcon(), for: .normal)
    }

    static func arrowIcon(size: CGFloat = 17) -> UIImage {
        let s = size / 24.0
        let r = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return r.image { ctx in
            let c = ctx.cgContext
            c.setLineCap(.round)
            c.setLineJoin(.round)
            c.setLineWidth(1.7 * s)
            c.setStrokeColor(UIColor.black.cgColor)
            c.move(to: CGPoint(x: 12 * s, y: 20.5 * s))
            c.addLine(to: CGPoint(x: 12 * s, y: 4 * s))
            c.strokePath()
            c.move(to: CGPoint(x: 5 * s, y: 11 * s))
            c.addLine(to: CGPoint(x: 12 * s, y: 4 * s))
            c.addLine(to: CGPoint(x: 19 * s, y: 11 * s))
            c.strokePath()
        }.withRenderingMode(.alwaysTemplate)
    }

    static func waveIcon() -> UIImage {
        let W: CGFloat = 18, H: CGFloat = 18
        let heights: [CGFloat] = [3.8, 8.3, 16.5, 8.3, 3.8]
        let pitch: CGFloat = 3.55, stroke: CGFloat = 1.45
        let r = UIGraphicsImageRenderer(size: CGSize(width: W, height: H))
        return r.image { ctx in
            let c = ctx.cgContext
            c.setLineCap(.round)
            c.setLineWidth(stroke)
            c.setStrokeColor(UIColor.black.cgColor)
            let x0 = (W - pitch * 4) / 2
            for (i, h) in heights.enumerated() {
                let x = x0 + pitch * CGFloat(i)
                c.move(to: CGPoint(x: x, y: (H - h) / 2))
                c.addLine(to: CGPoint(x: x, y: (H + h) / 2))
            }
            c.strokePath()
        }.withRenderingMode(.alwaysTemplate)
    }
    static func plusIcon(size: CGFloat = 20.5) -> UIImage {
        let s = size / 24.0
        let r = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return r.image { ctx in
            let c = ctx.cgContext
            c.setLineCap(.round)
            c.setLineWidth(1.8 * s)
            c.setStrokeColor(UIColor.black.cgColor)
            c.move(to: CGPoint(x: 12 * s, y: 5 * s)); c.addLine(to: CGPoint(x: 12 * s, y: 19 * s))
            c.move(to: CGPoint(x: 5 * s, y: 12 * s)); c.addLine(to: CGPoint(x: 19 * s, y: 12 * s))
            c.strokePath()
        }.withRenderingMode(.alwaysTemplate)
    }
    static func micIcon(size: CGFloat = 22) -> UIImage {
        let s = size / 24.0
        let r = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return r.image { _ in
            let p = UIBezierPath()
            p.lineWidth = 1.6 * s
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            let body = UIBezierPath(roundedRect: CGRect(x: 9 * s, y: 3 * s, width: 6 * s, height: 12 * s), cornerRadius: 3 * s)
            body.lineWidth = 1.6 * s
            UIColor.black.setStroke()
            body.stroke()
            p.addArc(withCenter: CGPoint(x: 12 * s, y: 11 * s), radius: 7 * s,
                     startAngle: .pi, endAngle: 0, clockwise: false)
            p.move(to: CGPoint(x: 12 * s, y: 18 * s))
            p.addLine(to: CGPoint(x: 12 * s, y: 21 * s))
            p.stroke()
        }.withRenderingMode(.alwaysTemplate)
    }

    func ensurePlaceholder() {
        guard phLabel == nil, let t = tv else { return }
        let l = UILabel()
        l.font = t.font
        l.textColor = LXSheetInk.faint
        l.text = "Chat with Claude"
        t.addSubview(l)
        phLabel = l
        layoutPlaceholder()
    }
    func layoutPlaceholder() {
        guard let t = tv, let l = phLabel else { return }
        l.font = t.font
        l.sizeToFit()
        l.frame.origin = CGPoint(x: t.textContainerInset.left, y: t.textContainerInset.top)
        if card != nil, !cardV_suspended() { l.isHidden = !(t.text ?? "").isEmpty }
    }
    func cardV_suspended() -> Bool { return card?.isHidden ?? true }

    func rebuildAtts(_ atts: [Any]) {
        guard let stack = attsStack, let row = attsRow, let hC = attsHC else { return }
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        let items = atts.compactMap { $0 as? [String: Any] }
        attsCount = items.count
        for (i, it) in items.enumerated() { stack.addArrangedSubview(makeAttChip(index: i, item: it)) }
        row.isHidden = items.isEmpty
        hC.constant = items.isEmpty ? 0 : 66
        tvTopC?.constant = (items.count > 0 || quoteIsOn) ? 5 : 0
        syncSendIcon()
        updateCardHeight()
        card?.superview?.layoutIfNeeded()
    }

    func makeAttChip(index: Int, item: [String: Any]) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.widthAnchor.constraint(equalToConstant: 66).isActive = true

        let thumb = UIView()
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.layer.cornerRadius = 12
        thumb.layer.cornerCurve = .continuous
        thumb.clipsToBounds = true
        thumb.backgroundColor = LXSheetInk.chip
        thumb.layer.borderWidth = 0.7
        thumb.layer.borderColor = LXSheetInk.sep.cgColor
        wrap.addSubview(thumb)

        let kind = (item["kind"] as? String) ?? "file"
        let b64 = (item["thumb"] as? String) ?? ""
        if kind == "image", !b64.isEmpty, let d = Data(base64Encoded: b64), let img = UIImage(data: d) {
            let iv = UIImageView(image: img)
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            thumb.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.topAnchor.constraint(equalTo: thumb.topAnchor),
                iv.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
                iv.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: thumb.trailingAnchor)])
        } else {
            let icon = UIImageView(image: UIImage(systemName: "doc", withConfiguration:
                UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)))
            icon.tintColor = LXSheetInk.icon
            icon.translatesAutoresizingMaskIntoConstraints = false
            let lab = UILabel()
            lab.text = String(((item["name"] as? String) ?? "file").prefix(14))
            lab.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 8.5) ?? UIFont.systemFont(ofSize: 8.5)
            lab.textColor = LXSheetInk.soft
            lab.textAlignment = .center
            lab.numberOfLines = 2
            lab.lineBreakMode = .byCharWrapping
            lab.translatesAutoresizingMaskIntoConstraints = false
            thumb.addSubview(icon); thumb.addSubview(lab)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
                icon.topAnchor.constraint(equalTo: thumb.topAnchor, constant: 10),
                lab.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 3),
                lab.leadingAnchor.constraint(equalTo: thumb.leadingAnchor, constant: 3),
                lab.trailingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: -3)])
        }

        let x = UIButton(type: .system)
        x.translatesAutoresizingMaskIntoConstraints = false
        x.backgroundColor = UIColor(white: 0.95, alpha: 1)
        x.tintColor = .black
        x.layer.cornerRadius = 10
        x.setImage(UIImage(systemName: "xmark", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)), for: .normal)
        x.layer.shadowColor = UIColor.black.cgColor
        x.layer.shadowOpacity = 0.35; x.layer.shadowRadius = 2
        x.layer.shadowOffset = CGSize(width: 0, height: 1)
        x.addAction(UIAction { [weak self] _ in
            LXOutbox.shared.removeAtt(index)
        }, for: .touchUpInside)
        wrap.addSubview(x)

        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            thumb.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 8),
            thumb.widthAnchor.constraint(equalToConstant: 58),
            thumb.heightAnchor.constraint(equalToConstant: 58),
            x.centerXAnchor.constraint(equalTo: thumb.trailingAnchor, constant: -3),
            x.centerYAnchor.constraint(equalTo: thumb.topAnchor, constant: 3),
            x.widthAnchor.constraint(equalToConstant: 20),
            x.heightAnchor.constraint(equalToConstant: 20)])
        return wrap
    }

    func buildMicMenu() -> UIMenu {
        let call = UIAction(title: "语音通话", image: UIImage(systemName: "phone")) { [weak self] _ in
            if LustreConfig.webless { LXCallSession.shared.startOutgoing() } else { self?.notifyListeners("cardAction", data: ["id": "call"]) }
        }
        let rec = UIAction(title: "发语音", image: UIImage(systemName: "mic")) { [weak self] _ in
            self?.recStart()
        }
        return UIMenu(children: [call, rec])
    }

    private var miniMenu: UIView?
    var modelSpecD: [String: Any] = {
        guard let d = UserDefaults.standard.data(forKey: NativeInputPlugin.modelSpecKey),
              let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              (o["models"] as? [Any])?.isEmpty == false else { return [:] }
        return o
    }()

    @objc func modelSpec(_ call: CAPPluginCall) {
        var d: [String: Any] = [:]
        if let m = call.getArray("models") { d["models"] = m }
        if let e = call.getArray("efforts") { d["efforts"] = e }
        if let v = call.getString("ctxText") { d["ctxText"] = v }
        if let v = call.getFloat("ctxPct") { d["ctxPct"] = NSNumber(value: v) }
        if let v = call.getString("ctxFill") { d["ctxFill"] = v }
        if let v = call.getString("effortLabel") { d["effortLabel"] = v }
        if let v = call.getString("compactSub") { d["compactSub"] = v }
        if let v = call.getBool("plusOriginal") { d["plusOriginal"] = v }
        modelSpecD = d
        if JSONSerialization.isValidJSONObject(d),
           let data = try? JSONSerialization.data(withJSONObject: d) {
            UserDefaults.standard.set(data, forKey: NativeInputPlugin.modelSpecKey)
        }
        DispatchQueue.main.async { self.refreshSheetLive() }
        call.resolve(["ok": true])
    }

    static let modelSpecKey = "lx.model.spec"
    static let effortKey = "lx.effort"

    static let modelNames: [(val: String, name: String)] = [
        ("claude-fable-5-1", "Fable 5.1"), ("claude-opus-5-5", "Opus 5.5"),
        ("claude-opus-5", "Opus 5"), ("claude-opus-4-6", "Opus 4.6"),
        ("claude-opus-4-5", "Opus 4.5"), ("claude-sonnet-4-6", "Sonnet 4.6"),
    ]

    static func prettyModel(_ raw: String) -> String {
        let base = raw.replacingOccurrences(of: "[1m]", with: "")
        if let n = modelNames.first(where: { $0.val == base })?.name { return n }
        guard base.hasPrefix("claude-") else { return raw }
        var parts = base.dropFirst(7).split(separator: "-").map(String.init)
        if let last = parts.last, last.count == 8, Int(last) != nil { parts.removeLast() }
        guard let fam = parts.first, parts.count > 1 else { return raw }
        return fam.prefix(1).uppercased() + fam.dropFirst() + " " + parts.dropFirst().joined(separator: ".")
    }
    static let effortNames: [(val: String, name: String)] = [
        ("low", "Low"), ("medium", "Medium"), ("high", "High"), ("xhigh", "X-High"), ("max", "Max"),
    ]

    static func nativeModelSpec(for line: String? = nil) -> [String: Any] {
        let sid = line ?? ChatListPlugin.live?.data.session ?? "__legacy__"
        let cur = LXSessionsAPI.modelBySid[sid].flatMap { $0.isEmpty ? nil : $0 }
            ?? LXUsage.model(for: sid)
        let eff = UserDefaults.standard.string(forKey: effortKey) ?? "max"
        let models: [[String: Any]] = modelNames.map {
            ["val": $0.val, "name": $0.name, "active": $0.val == cur.replacingOccurrences(of: "[1m]", with: "")]
        }
        let efforts: [[String: Any]] = effortNames.map {
            ["val": $0.val, "name": $0.name, "active": $0.val == eff]
        }
        let curName = cur.isEmpty ? "" : prettyModel(cur)
        let effName = effortNames.first(where: { $0.val == eff })?.name ?? eff
        var out: [String: Any] = ["models": models, "efforts": efforts,
                                  "effortLabel": effName, "modelName": curName]
        if let c = LXUsage.ctx(for: sid) {
            out["ctxText"] = c.text
            out["ctxPct"] = NSNumber(value: c.pct)
            out["ctxFill"] = c.pct >= 85 ? "#CF5A5A" : (c.pct >= 65 ? "#CF8D5A" : "#A9D9EE")
        }
        return out
    }

    func ccCommand(_ kind: String, _ value: String) {
        guard let u = URL(string: LustreConfig.apiBase + "/app/cc_command") else { return }
        var body: [String: Any] = ["kind": kind, "value": value]
        let sid = ChatListPlugin.live?.data.session ?? ""
        if !sid.isEmpty, sid != "__legacy__" { body["session_id"] = sid }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r).resume()
    }

    struct MiniRow {
        var icon: String? = nil
        var title: String
        var sub: String? = nil
        var checked = false
        var separatorAfter = false
        var action: () -> Void
    }

    func showMiniPanel(anchor: UIView?, rows: [MiniRow]) {
        guard miniMenu == nil, let host = card?.superview, let anchorV = anchor else { return }
        let overlay = UIControl(frame: host.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addAction(UIAction { [weak self] _ in self?.hideMicMiniMenu() }, for: .touchUpInside)
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 14
        panel.clipsToBounds = true
        let blurFx: UIVisualEffect
        if #available(iOS 26.0, *) { blurFx = UIGlassEffect() }
        else { blurFx = UIBlurEffect(style: .systemThickMaterialDark) }
        let blur = UIVisualEffectView(effect: blurFx)
        blur.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(blur)
        let col = UIStackView()
        col.axis = .vertical
        col.translatesAutoresizingMaskIntoConstraints = false
        for r in rows {
            let b = UIButton(type: .system)
            var cfg = UIButton.Configuration.plain()
            if let ic = r.icon {
                cfg.image = UIImage(systemName: ic, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular))
                cfg.imagePadding = 10
            }
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: r.checked ? 8 : 16)
            var titleA = AttributedString(r.title, attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 15), .foregroundColor: LXSheetInk.text]))
            if let sub = r.sub, !sub.isEmpty {
                titleA += AttributedString("\n")
                titleA += AttributedString(sub, attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: 11.5), .foregroundColor: LXSheetInk.soft]))
            }
            cfg.attributedTitle = titleA
            cfg.titleLineBreakMode = .byWordWrapping
            b.configuration = cfg
            b.tintColor = LXSheetInk.text
            b.contentHorizontalAlignment = .leading
            if r.checked {
                let chk = UIImageView(image: UIImage(systemName: "checkmark",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)))
                chk.tintColor = LXSheetInk.star
                chk.translatesAutoresizingMaskIntoConstraints = false
                b.addSubview(chk)
                NSLayoutConstraint.activate([
                    chk.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -14),
                    chk.centerYAnchor.constraint(equalTo: b.centerYAnchor),
                ])
            }
            let act = r.action
            b.addAction(UIAction { [weak self] _ in self?.hideMicMiniMenu(); act() }, for: .touchUpInside)
            col.addArrangedSubview(b)
            if r.separatorAfter {
                let sep = UIView()
                sep.backgroundColor = LXSheetInk.sep
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                col.addArrangedSubview(sep)
            }
        }
        panel.addSubview(col)
        overlay.addSubview(panel)
        host.addSubview(overlay)
        let af = anchorV.convert(anchorV.bounds, to: host)
        var cons: [NSLayoutConstraint] = [
            blur.topAnchor.constraint(equalTo: panel.topAnchor), blur.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: panel.leadingAnchor), blur.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            col.topAnchor.constraint(equalTo: panel.topAnchor, constant: 4),
            col.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4),
            col.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            panel.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            panel.bottomAnchor.constraint(equalTo: host.topAnchor, constant: af.minY - 8),
        ]
        if af.midX < host.bounds.width / 2 {
            cons.append(panel.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: max(10, af.minX)))
        } else {
            cons.append(panel.trailingAnchor.constraint(equalTo: host.leadingAnchor, constant: min(host.bounds.width - 10, af.maxX)))
        }
        NSLayoutConstraint.activate(cons)
        panel.transform = CGAffineTransform(translationX: 0, y: 6).scaledBy(x: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3,
                       options: [.allowUserInteraction]) {
            panel.transform = .identity
        }
        miniMenu = overlay
    }

    private weak var sheetRef: LXCardSheet?
    private weak var originalCheckRef: UIImageView?
    // 模型卡 Context 行:数字 + 进度条宽度约束,外加它是哪条线的(用量按会话分开回来)
    private weak var ctxValueRef: UILabel?
    private weak var ctxWidthRef: NSLayoutConstraint?
    private var ctxSid = "__legacy__"

    private func sheetRow(title: String, sub: String? = nil, icon: String? = nil,
                          checked: Bool = false, chevron: Bool = false, value: String? = nil,
                          action: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .custom)
        b.contentHorizontalAlignment = .leading
        let h = UIStackView()
        h.translatesAutoresizingMaskIntoConstraints = false
        h.axis = .horizontal
        h.alignment = .center
        h.spacing = 12
        h.isUserInteractionEnabled = false
        if let ic = icon {
            let iv = UIImageView(image: UIImage(systemName: ic,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)))
            iv.tintColor = LXSheetInk.icon
            iv.setContentHuggingPriority(.required, for: .horizontal)
            h.addArrangedSubview(iv)
        }
        let col = UIStackView()
        col.axis = .vertical
        col.spacing = 2
        let t = UILabel()
        t.text = title
        t.font = LXBubbleCell.bodyFont().withSize(15)
        t.textColor = checked ? LXSheetInk.star : LXSheetInk.text
        col.addArrangedSubview(t)
        if let s = sub, !s.isEmpty {
            let sl = UILabel()
            sl.text = s
            sl.font = LXBubbleCell.bodyFont().withSize(12.5)
            sl.textColor = LXSheetInk.soft
            col.addArrangedSubview(sl)
        }
        h.addArrangedSubview(col)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        h.addArrangedSubview(spacer)
        if let v = value {
            let vl = UILabel()
            vl.text = v
            vl.font = LXCardSheet.anthro(15)
            vl.textColor = LXSheetInk.soft
            h.addArrangedSubview(vl)
        }
        if checked {
            let c = UIImageView(image: UIImage(systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)))
            c.tintColor = LXSheetInk.star
            h.addArrangedSubview(c)
        }
        if chevron {
            let c = UIImageView(image: UIImage(systemName: "chevron.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)))
            c.tintColor = LXSheetInk.faint
            h.addArrangedSubview(c)
        }
        b.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: b.topAnchor, constant: 10),
            h.bottomAnchor.constraint(equalTo: b.bottomAnchor, constant: -10),
            h.leadingAnchor.constraint(equalTo: b.leadingAnchor, constant: 16),
            h.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -16),
        ])
        b.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return b
    }

    func showPlusSheet() {
        guard sheetRef == nil, let host = card?.superview else { return }
        tv?.resignFirstResponder()
        let sheet = LXCardSheet(host: host, title: "Add to Chat")
        func tile(_ title: String, _ icon: String, _ id: String) -> UIButton {
            let b = UIButton(type: .custom)
            b.backgroundColor = LXSheetInk.tile
            b.layer.cornerRadius = 18
            let col = UIStackView()
            col.translatesAutoresizingMaskIntoConstraints = false
            col.axis = .vertical
            col.alignment = .center
            col.spacing = 8
            col.isUserInteractionEnabled = false
            let iv = UIImageView(image: UIImage(systemName: icon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .light)))
            iv.tintColor = LXSheetInk.text
            let tl = UILabel()
            tl.text = title
            tl.font = LXBubbleCell.bodyFont().withSize(15)
            tl.textColor = LXSheetInk.text
            col.addArrangedSubview(iv)
            col.addArrangedSubview(tl)
            b.addSubview(col)
            NSLayoutConstraint.activate([
                col.centerXAnchor.constraint(equalTo: b.centerXAnchor),
                col.centerYAnchor.constraint(equalTo: b.centerYAnchor),
                b.heightAnchor.constraint(equalToConstant: 92),
            ])
            b.addAction(UIAction { [weak self] _ in
                self?.sheetRef?.dismissSheet()
                self?.pickInto(id)
            }, for: .touchUpInside)
            return b
        }
        let tiles = UIStackView(arrangedSubviews: [tile("Camera", "camera", "addCamera"),
                                                   tile("Photos", "photo.on.rectangle", "addPhotos")])
        tiles.axis = .horizontal
        tiles.distribution = .fillEqually
        tiles.spacing = 10
        sheet.content.addArrangedSubview(tiles)
        let box = LXCardSheet.cardBox()
        box.addArrangedSubview(sheetRow(title: "Add files", icon: "arrow.up.doc", chevron: true) { [weak self] in
            self?.sheetRef?.dismissSheet()
            self?.pickInto("addFiles")
        })
        box.addArrangedSubview(LXCardSheet.sep())
        let orig = (modelSpecD["plusOriginal"] as? Bool) ?? false
        let ob = UIButton(type: .custom)
        let oh = UIStackView()
        oh.translatesAutoresizingMaskIntoConstraints = false
        oh.axis = .horizontal
        oh.alignment = .center
        oh.spacing = 12
        oh.isUserInteractionEnabled = false
        let oc = UIImageView(image: UIImage(systemName: orig ? "checkmark.circle.fill" : "circle",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)))
        oc.tintColor = LXSheetInk.icon
        originalCheckRef = oc
        let ol = UILabel()
        ol.text = "Original"
        ol.font = LXBubbleCell.bodyFont().withSize(15)
        ol.textColor = LXSheetInk.text
        oh.addArrangedSubview(oc)
        oh.addArrangedSubview(ol)
        ob.addSubview(oh)
        NSLayoutConstraint.activate([
            oh.topAnchor.constraint(equalTo: ob.topAnchor, constant: 10),
            oh.bottomAnchor.constraint(equalTo: ob.bottomAnchor, constant: -10),
            oh.leadingAnchor.constraint(equalTo: ob.leadingAnchor, constant: 16),
            oh.trailingAnchor.constraint(lessThanOrEqualTo: ob.trailingAnchor, constant: -16),
        ])
        ob.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            let cur = (s.modelSpecD["plusOriginal"] as? Bool) ?? false
            s.modelSpecD["plusOriginal"] = !cur
            s.refreshSheetLive()
            LXOutbox.shared.original = !cur
        }, for: .touchUpInside)
        box.addArrangedSubview(ob)
        sheet.content.addArrangedSubview(box)
        host.addSubview(sheet)
        sheetRef = sheet
    }

    func showModelSheet() {
        LXUsage.refresh()
        if modelSpecD["models"] == nil || LustreConfig.webless {
            var d = NativeInputPlugin.nativeModelSpec()
            for (k, v) in modelSpecD where d[k] == nil { d[k] = v }
            modelSpecD = d
        }
        guard sheetRef == nil, let host = card?.superview else {
            return
        }
        tv?.resignFirstResponder()
        guard (modelSpecD["models"] as? [Any])?.isEmpty == false else {
            notifyListeners("cardAction", data: ["id": "model"])
            return
        }
        let sheet = LXCardSheet(host: host, title: "Select model")
        buildModelMain(into: sheet)
        host.addSubview(sheet)
        sheetRef = sheet
    }

    /// Context 行的数字、进度条比例和颜色:建卡和用量刷新共用这一份,两边不会算岔
    private static func ctxRow(_ d: [String: Any]) -> (text: String, mult: CGFloat, fill: UIColor)? {
        guard let t = d["ctxText"] as? String, !t.isEmpty else { return nil }
        let pct = CGFloat(min(100, max(0, (d["ctxPct"] as? NSNumber)?.doubleValue ?? 0))) / 100
        let fill = (d["ctxFill"] as? String).flatMap(NativeInputPlugin.color)
            ?? UIColor(red: 0.85, green: 0.60, blue: 0.34, alpha: 1)
        return (t, max(0.01, pct), fill)
    }

    private func buildModelMain(into sheet: LXCardSheet) {
        sheet.content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let ctx = NativeInputPlugin.ctxRow(modelSpecD) {
            let box = LXCardSheet.cardBox()
            let wrap = UIView()
            let lab = UILabel()
            lab.translatesAutoresizingMaskIntoConstraints = false
            lab.text = "Context"
            lab.font = LXCardSheet.anthro(15)
            lab.textColor = LXSheetInk.soft
            let val = UILabel()
            val.translatesAutoresizingMaskIntoConstraints = false
            val.text = ctx.text
            val.font = LXCardSheet.anthro(14)
            val.textColor = LXSheetInk.text
            let track = UIView()
            track.translatesAutoresizingMaskIntoConstraints = false
            track.backgroundColor = LXSheetInk.track
            track.layer.cornerRadius = 3
            let fill = UIView()
            fill.translatesAutoresizingMaskIntoConstraints = false
            fill.backgroundColor = ctx.fill
            fill.layer.cornerRadius = 3
            track.addSubview(fill)
            wrap.addSubview(lab); wrap.addSubview(val); wrap.addSubview(track)
            let fillW = fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: ctx.mult)
            NSLayoutConstraint.activate([
                lab.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 12),
                lab.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
                val.centerYAnchor.constraint(equalTo: lab.centerYAnchor),
                val.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
                track.topAnchor.constraint(equalTo: lab.bottomAnchor, constant: 9),
                track.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
                track.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
                track.heightAnchor.constraint(equalToConstant: 6),
                track.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -13),
                fill.topAnchor.constraint(equalTo: track.topAnchor),
                fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
                fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
                fillW,
            ])
            ctxValueRef = val
            ctxWidthRef = fillW
            ctxSid = ChatListPlugin.live?.data.session ?? "__legacy__"
            box.addArrangedSubview(wrap)
            sheet.content.addArrangedSubview(box)
        }
        let mbox = LXCardSheet.cardBox()
        let models = (modelSpecD["models"] as? [Any]) ?? []
        for (i, m) in models.enumerated() {
            guard let d = m as? [String: Any], let vid = d["val"] as? String else { continue }
            mbox.addArrangedSubview(sheetRow(title: (d["name"] as? String) ?? vid,
                                             sub: nil,
                                             checked: (d["active"] as? Bool) ?? false) { [weak self] in
                guard let s = self else { return }
                if let arr = s.modelSpecD["models"] as? [[String: Any]] {
                    s.modelSpecD["models"] = arr.map { row -> [String: Any] in
                        var r = row; r["active"] = (r["val"] as? String) == vid; return r
                    }
                }
                s.sheetRef?.dismissSheet()
                s.ccCommand("model", vid)
                LXSessionsAPI.rememberModel(ChatListPlugin.live?.data.session ?? "__legacy__", vid)
            })
            if i < models.count - 1 { mbox.addArrangedSubview(LXCardSheet.sep()) }
        }
        sheet.content.addArrangedSubview(mbox)
        let ebox = LXCardSheet.cardBox()
        ebox.addArrangedSubview(sheetRow(title: "Effort", chevron: true,
                                         value: (modelSpecD["effortLabel"] as? String) ?? "") { [weak self, weak sheet] in
            guard let s = self, let sh = sheet else { return }
            s.buildEffortPage(into: sh)
        })
        sheet.content.addArrangedSubview(ebox)
        let cbox = LXCardSheet.cardBox()
        cbox.addArrangedSubview(sheetRow(title: "Compact") { [weak self] in
            self?.sheetRef?.dismissSheet()
            self?.ccCommand("compact", "")
        })
        sheet.content.addArrangedSubview(cbox)
    }

    private func buildEffortPage(into sheet: LXCardSheet) {
        sheet.content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let back = LXCardSheet.cardBox()
        back.addArrangedSubview(sheetRow(title: "‹ Effort", value: "") { [weak self, weak sheet] in
            guard let s = self, let sh = sheet else { return }
            s.buildModelMain(into: sh)
        })
        sheet.content.addArrangedSubview(back)
        let ebox = LXCardSheet.cardBox()
        let efforts = (modelSpecD["efforts"] as? [Any]) ?? []
        for (i, e) in efforts.enumerated() {
            guard let d = e as? [String: Any], let vid = d["val"] as? String else { continue }
            let label = (d["label"] as? String) ?? vid
            ebox.addArrangedSubview(sheetRow(title: label,
                                             checked: (d["active"] as? Bool) ?? false) { [weak self] in
                guard let s = self else { return }
                if let arr = s.modelSpecD["efforts"] as? [[String: Any]] {
                    s.modelSpecD["efforts"] = arr.map { row -> [String: Any] in
                        var r = row; r["active"] = (r["val"] as? String) == vid; return r
                    }
                }
                s.modelSpecD["effortLabel"] = label
                s.sheetRef?.dismissSheet()
                s.ccCommand("effort", vid)
                UserDefaults.standard.set(vid, forKey: NativeInputPlugin.effortKey)
            })
            if i < efforts.count - 1 { ebox.addArrangedSubview(LXCardSheet.sep()) }
        }
        sheet.content.addArrangedSubview(ebox)
    }

    func refreshSheetLive() {
        if let oc = originalCheckRef {
            let orig = (modelSpecD["plusOriginal"] as? Bool) ?? false
            oc.image = UIImage(systemName: orig ? "checkmark.circle.fill" : "circle",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))

        }
    }

    /// 0925:用量刷新回来,开着的模型卡只原地换 Context 的数字、进度条宽度和颜色——不重建、不动画
    private func refreshCtxLive() {
        guard sheetRef != nil, let v = ctxValueRef, let w = ctxWidthRef,
              let fill = w.firstItem as? UIView, let track = w.secondItem as? UIView,
              let c = NativeInputPlugin.ctxRow(NativeInputPlugin.nativeModelSpec(for: ctxSid)) else { return }
        if v.text != c.text { v.text = c.text }
        fill.backgroundColor = c.fill
        if w.multiplier != c.mult {
            w.isActive = false
            let nw = fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: c.mult)
            nw.isActive = true
            ctxWidthRef = nw
        }
        UIView.performWithoutAnimation { v.superview?.layoutIfNeeded() }
    }

    func showMicMiniMenu() {
        guard miniMenu == nil, let host = card?.superview, let anchor = micBtn else { return }
        let overlay = UIControl(frame: host.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addAction(UIAction { [weak self] _ in self?.hideMicMiniMenu() }, for: .touchUpInside)
        let panel = UIView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.layer.cornerRadius = 14
        panel.clipsToBounds = true
        let blurFx: UIVisualEffect
        if #available(iOS 26.0, *) { blurFx = UIGlassEffect() }
        else { blurFx = UIBlurEffect(style: .systemThickMaterialDark) }
        let blur = UIVisualEffectView(effect: blurFx)
        blur.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(blur)
        let col = UIStackView()
        col.axis = .vertical
        col.translatesAutoresizingMaskIntoConstraints = false
        func row(_ title: String, _ icon: String, _ act: @escaping () -> Void) -> UIButton {
            let b = UIButton(type: .system)
            var cfg = UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular))
            cfg.imagePadding = 10
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 16)
            cfg.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 15), .foregroundColor: LXSheetInk.text]))
            b.configuration = cfg
            b.tintColor = LXSheetInk.text
            b.contentHorizontalAlignment = .leading
            b.addAction(UIAction { [weak self] _ in self?.hideMicMiniMenu(); act() }, for: .touchUpInside)
            return b
        }
        col.addArrangedSubview(row("发语音", "mic") { [weak self] in self?.recStart() })
        col.addArrangedSubview(row("语音通话", "phone") { [weak self] in
            if LustreConfig.webless { LXCallSession.shared.startOutgoing() } else { self?.notifyListeners("cardAction", data: ["id": "call"]) }
        })
        panel.addSubview(col)
        overlay.addSubview(panel)
        host.addSubview(overlay)
        let af = anchor.convert(anchor.bounds, to: host)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: panel.topAnchor), blur.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: panel.leadingAnchor), blur.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            col.topAnchor.constraint(equalTo: panel.topAnchor, constant: 4),
            col.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -4),
            col.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            col.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            panel.trailingAnchor.constraint(equalTo: host.leadingAnchor, constant: af.maxX),
            panel.bottomAnchor.constraint(equalTo: host.topAnchor, constant: af.minY - 8),
        ])
        panel.transform = CGAffineTransform(translationX: 0, y: 6).scaledBy(x: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.3,
                       options: [.allowUserInteraction]) {
            panel.transform = .identity
        }
        miniMenu = overlay
    }
    func hideMicMiniMenu() {
        let m = miniMenu; miniMenu = nil
        UIView.animate(withDuration: 0.15, animations: { m?.alpha = 0 }) { _ in m?.removeFromSuperview() }
    }

    func recStart() {
        guard recorder == nil else { return }
        let sess = AVAudioSession.sharedInstance()
        sess.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.notifyListeners("recDenied", data: [:]); self.micDeniedToast(); return }
                do {
                    try sess.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                    try sess.setActive(true)
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent("lx-rec.m4a")
                    try? FileManager.default.removeItem(at: url)
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderBitRateKey: 64000
                    ]
                    let r = try AVAudioRecorder(url: url, settings: settings)
                    r.record()
                    self.recorder = r
                    self.recURL = url
                    self.recT0 = Date()
                    self.enterRecUI()
                } catch {
                    self.notifyListeners("recDenied", data: ["err": "\(error)"])
                    self.micDeniedToast()
                }
            }
        }
    }

    func recStop(send: Bool) {
        guard let r = recorder else { return }
        let dur = r.currentTime
        r.stop()
        recorder = nil
        exitRecUI()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let url = recURL
        recURL = nil
        guard send, let u = url else {
            if let u = url { try? FileManager.default.removeItem(at: u) }
            return
        }
        if let d = try? Data(contentsOf: u) {
            LXOutbox.shared.sendVoice(d, mime: "audio/mp4", duration: Int(dur.rounded()))
        }
        try? FileManager.default.removeItem(at: u)
    }

    func enterRecUI() {
        guard let mic = micBtn else { return }
        hideMicMiniMenu()
        mic.tintColor = .systemRed
        mic.setTitle(" 0:00", for: .normal)
        micWC?.constant = 78
        recCancelBtn?.isHidden = false
        card?.superview?.layoutIfNeeded()
        recTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let t0 = self.recT0 else { return }
            let s = Int(Date().timeIntervalSince(t0))
            self.micBtn?.setTitle(String(format: " %d:%02d", s / 60, s % 60), for: .normal)
        }
    }

    func exitRecUI() {
        recTimer?.invalidate(); recTimer = nil
        recT0 = nil
        guard let mic = micBtn else { return }
        mic.setTitle(nil, for: .normal)
        mic.tintColor = chipFgC
        micWC?.constant = 34
        recCancelBtn?.isHidden = true
        card?.superview?.layoutIfNeeded()
    }

    func updateCardHeight() {
        guard let t = tv, let hC = cardHeightC else { return }
        let trayH = (attsHC?.constant ?? 0) + (quoteTopC?.constant ?? 0)
                  + (quoteHC?.constant ?? 0) + (tvTopC?.constant ?? 0)
        let chrome: CGFloat = 6 + 2 + 8 + 34 + trayH
        let want = min(cardMaxH, max(cardMinH, t.contentSize.height + chrome))
        if abs(hC.constant - want) > 0.5 {
            hC.constant = want
            card?.superview?.layoutIfNeeded()
        }
        t.scrollRangeToVisible(t.selectedRange)
    }

    public func textViewDidChange(_ textView: UITextView) { pushChange(); updateCardHeight() }
    func pushChange() {
        guard let t = tv else { return }
        if card != nil, !cardV_suspended() { phLabel?.isHidden = !(t.text ?? "").isEmpty }
        syncSendIcon()
        notifyListeners("textChanged", data: [
            "text": t.text ?? "",
            "height": Double(t.contentSize.height)
        ])
    }

    func syncSendIcon() {
        let has = !((tv?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || !LXOutbox.shared.staged.isEmpty
        if has != sendHasText {
            sendHasText = has
            updateSendIcon()
        }
    }
    public func textViewDidBeginEditing(_ textView: UITextView) {
        notifyListeners("focusChanged", data: ["focused": true])
    }
    public func textViewDidEndEditing(_ textView: UITextView) {
        notifyListeners("focusChanged", data: ["focused": false])
    }

    func hookKeyboard() {
        let nc = NotificationCenter.default
        let handler: (Notification) -> Void = { [weak self] note in
            guard let self, self.tv != nil else { return }
            guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            let screenH = UIScreen.main.bounds.height
            let h = max(0, screenH - end.origin.y)
            let inset = self.bridge?.webView?.safeAreaInsets.bottom ?? 0
            self.notifyListeners("keyboard", data: ["height": Double(h), "inset": Double(inset)])
        }
        kbTokens.append(nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main, using: handler))
        kbTokens.append(nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main, using: handler))
    }

    static func color(_ hex: String) -> UIColor? {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                       green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

class LXTextView: UITextView {
    weak var owner: NativeInputPlugin?
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        contentInsetAdjustmentBehavior = .never
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard (text ?? "").isEmpty else { return }
        if contentOffset != .zero { contentOffset = .zero }
        owner?.layoutPlaceholder()
    }
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)), UIPasteboard.general.hasImages { return true }
        return super.canPerformAction(action, withSender: sender)
    }
    override func paste(_ sender: Any?) {
        let pb = UIPasteboard.general
        if pb.hasImages, let img = pb.image, let data = img.jpegData(compressionQuality: 0.9) {
            let f: [String: Any] = ["data": data.base64EncodedString(), "mime": "image/jpeg",
                                    "name": "pasted.jpg", "kind": "image",
                                    "width": Int(img.size.width), "height": Int(img.size.height)]
            if LustreConfig.webless {
                LXOutbox.shared.addPicked([f])
            } else {
                owner?.notifyListeners("pasteImage", data: f)
            }
            return
        }
        super.paste(sender)
    }
}

enum ApnsToken {
    private static let key = "lustre.apns.registered"
    static var latest: String? {
        didSet {
            guard let t = latest, !t.isEmpty else { return }
            UserDefaults.standard.set(t, forKey: key)
            if LustreConfig.webless { upload(t) }
        }
    }
    private static let sentKey = "lustre.apns.sent"
    static func upload(_ t: String) {
        guard UserDefaults.standard.string(forKey: sentKey) != t,
              let u = URL(string: LustreConfig.apiBase + "/app/apns_token") else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["token": t])
        URLSession.shared.dataTask(with: r) { _, resp, _ in
            if (resp as? HTTPURLResponse)?.statusCode == 200 { UserDefaults.standard.set(t, forKey: sentKey) }
        }.resume()
    }
    static var serverPushOwns: Bool {
        if let t = latest, !t.isEmpty { return true }
        return !(UserDefaults.standard.string(forKey: key) ?? "").isEmpty
    }
}

// 0925 她的单:给两位随时改备注。所有显示名字的地方都读这里;没设过就用原来的名字。
// 存在服务器 /app/nicknames(来电、通知也用它),本机留一份缓存开机就有。
enum LXNick {
    private static let key = "lx.nicknames"
    private static var cache: [String: String] =
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    static let changed = Notification.Name("lx.nick.changed")

    static var zhaoSet: String? { let v = cache["zhao"] ?? ""; return v.isEmpty ? nil : v }
    static var yanSet: String? { let v = cache["yan"] ?? ""; return v.isEmpty ? nil : v }
    static var zhao: String { zhaoSet ?? String(repeating: "__LX_ZHAO__", count: 2) }
    static var yan: String { yanSet ?? "__LX_YAN__" }
    /// 按会话认人:他那条线 / 昭这条(空或 __legacy__) / 其余新会话
    static func of(session sid: String) -> String {
        if sid == "yan-main" { return yan }
        if sid.isEmpty || sid == "__legacy__" { return zhao }
        return "Lustre"
    }

    private static func store(_ d: [String: String]) {
        guard d != cache else { return }
        cache = d
        UserDefaults.standard.set(d, forKey: key)
        DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) }
    }
    private static func req(_ method: String, _ body: [String: Any]? = nil) -> URLRequest? {
        guard !LustreConfig.secret.isEmpty, let u = URL(string: LustreConfig.apiBase + "/app/nicknames") else { return nil }
        var r = URLRequest(url: u, timeoutInterval: 12)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        if let b = body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: b)
        }
        return r
    }
    private static func parse(_ data: Data?) -> [String: String]? {
        guard let data, let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return ["zhao": (o["zhao"] as? String) ?? "", "yan": (o["yan"] as? String) ?? ""]
    }
    static func refresh() {
        guard let r = req("GET") else { return }
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            guard (resp as? HTTPURLResponse)?.statusCode == 200, let d = parse(data) else { return }
            store(d)
        }.resume()
    }
    /// who: "zhao" / "yan";空字符串 = 恢复默认名字
    static func set(_ who: String, _ name: String, done: @escaping (Bool) -> Void) {
        guard let r = req("POST", [who: name.trimmingCharacters(in: .whitespacesAndNewlines)]) else { done(false); return }
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            if ok, let d = parse(data) { store(d) }
            DispatchQueue.main.async { done(ok) }
        }.resume()
    }
}
