import UIKit
import UniformTypeIdentifiers
import ImageIO

/// 1001 她要的"分享进来":在微信/文件/相册里点"分享"选 Lustre,弹这个小面板——上面是要发的东西,可以加一句话,
/// 下面两个按钮,发给主线或发给他。直接走 relay 的上传和发送,不打开 App。
/// 地址、密码、名字全是占位符,编译时由 inject.py 填;名字开面板时再按服务器上的备注换
final class ShareViewController: UIViewController, UITextViewDelegate {
    private static let apiBase = "__LX_ORIGIN__/relay"
    private static let auth = "__LX_AUTH__"
    /// relay 单个附件上限 10MB(RELAY_MAX_UPLOAD_BYTES),超过的在面板上直接说,不去撞
    private static let maxBytes = 10 * 1024 * 1024
    /// 照 App:按钮底色用星芒色,字用正文那支近黑
    private static let star = UIColor(red: 0xB6 / 255, green: 0xD6 / 255, blue: 0xE8 / 255, alpha: 1)
    private static let ink = UIColor(red: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255, alpha: 1)

    private struct Item {
        let url: URL
        let name: String
        let mime: String
        let isImage: Bool
    }

    private var items: [Item] = []
    private var tooBig: [String] = []
    private var sending = false
    private var mainName = String(repeating: "__LX_ZHAO__", count: 2)
    private var yanName = "__LX_YAN__"

    private let stripScroll = UIScrollView()
    private let strip = UIStackView()
    private let textV = UITextView()
    private let phL = UILabel()
    private let statusL = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let mainB = UIButton(type: .system)
    private let yanB = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        refreshButtons()
        loadNames()
        loadItems()
    }

    // MARK: 面板

    private func buildUI() {
        let cancelB = UIButton(type: .system)
        cancelB.setTitle("取消", for: .normal)
        cancelB.titleLabel?.font = .systemFont(ofSize: 17)
        cancelB.addTarget(self, action: #selector(cancelTap), for: .touchUpInside)
        let titleL = UILabel()
        titleL.text = "Lustre"
        titleL.font = .systemFont(ofSize: 17, weight: .semibold)
        titleL.textAlignment = .center

        stripScroll.showsHorizontalScrollIndicator = false
        strip.axis = .horizontal
        strip.spacing = 10
        strip.alignment = .center
        strip.translatesAutoresizingMaskIntoConstraints = false
        stripScroll.addSubview(strip)

        textV.font = .systemFont(ofSize: 16)
        textV.backgroundColor = .secondarySystemBackground
        textV.layer.cornerRadius = 12
        textV.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textV.delegate = self
        phL.text = "加一句话(可以不填)"
        phL.font = .systemFont(ofSize: 16)
        phL.textColor = .placeholderText

        statusL.font = .systemFont(ofSize: 13)
        statusL.textColor = .secondaryLabel
        statusL.numberOfLines = 0
        spinner.hidesWhenStopped = true

        for b in [mainB, yanB] {
            b.backgroundColor = Self.star
            b.setTitleColor(Self.ink, for: .normal)
            b.setTitleColor(Self.ink.withAlphaComponent(0.35), for: .disabled)
            b.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            b.titleLabel?.lineBreakMode = .byTruncatingTail
            b.layer.cornerRadius = 14
            b.layer.cornerCurve = .continuous
        }
        mainB.addTarget(self, action: #selector(mainTap), for: .touchUpInside)
        yanB.addTarget(self, action: #selector(yanTap), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [mainB, yanB])
        buttons.axis = .horizontal
        buttons.spacing = 12
        buttons.distribution = .fillEqually
        let statusRow = UIStackView(arrangedSubviews: [spinner, statusL])
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center

        for v in [cancelB, titleL, stripScroll, textV, phL, statusRow, buttons] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            cancelB.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            cancelB.topAnchor.constraint(equalTo: g.topAnchor, constant: 10),
            titleL.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleL.centerYAnchor.constraint(equalTo: cancelB.centerYAnchor),

            stripScroll.topAnchor.constraint(equalTo: cancelB.bottomAnchor, constant: 14),
            stripScroll.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            stripScroll.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            stripScroll.heightAnchor.constraint(equalToConstant: 84),
            strip.leadingAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            strip.trailingAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            strip.topAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.topAnchor),
            strip.bottomAnchor.constraint(equalTo: stripScroll.contentLayoutGuide.bottomAnchor),
            strip.heightAnchor.constraint(equalTo: stripScroll.frameLayoutGuide.heightAnchor),

            textV.topAnchor.constraint(equalTo: stripScroll.bottomAnchor, constant: 12),
            textV.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            textV.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            textV.heightAnchor.constraint(equalToConstant: 110),
            phL.leadingAnchor.constraint(equalTo: textV.leadingAnchor, constant: 13),
            phL.topAnchor.constraint(equalTo: textV.topAnchor, constant: 10),

            statusRow.topAnchor.constraint(equalTo: textV.bottomAnchor, constant: 10),
            statusRow.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 18),
            statusRow.trailingAnchor.constraint(lessThanOrEqualTo: g.trailingAnchor, constant: -18),

            buttons.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            buttons.heightAnchor.constraint(equalToConstant: 50),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: statusRow.bottomAnchor, constant: 12),
            // 键盘起来时按钮跟着往上,不被挡住
            buttons.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12),
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        phL.isHidden = !textView.text.isEmpty
        refreshButtons()
    }

    private func refreshButtons() {
        mainB.setTitle("发给 " + mainName, for: .normal)
        yanB.setTitle("发给 " + yanName, for: .normal)
        let hasText = !textV.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ok = !sending && (!items.isEmpty || hasText)
        mainB.isEnabled = ok
        yanB.isEnabled = ok
    }

    private func setStatus(_ s: String, busy: Bool) {
        DispatchQueue.main.async {
            self.statusL.text = s
            if busy { self.spinner.startAnimating() } else { self.spinner.stopAnimating() }
        }
    }

    private func tile(for it: Item) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 10
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.backgroundColor = .secondarySystemBackground
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: it.isImage ? 72 : 120),
            v.heightAnchor.constraint(equalToConstant: 72),
        ])
        if it.isImage, let img = Self.thumb(it.url) {
            let iv = UIImageView(image: img)
            iv.contentMode = .scaleAspectFill
            iv.translatesAutoresizingMaskIntoConstraints = false
            v.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: v.leadingAnchor), iv.trailingAnchor.constraint(equalTo: v.trailingAnchor),
                iv.topAnchor.constraint(equalTo: v.topAnchor), iv.bottomAnchor.constraint(equalTo: v.bottomAnchor),
            ])
        } else {
            let icon = UIImageView(image: UIImage(systemName: "doc.fill"))
            icon.tintColor = .secondaryLabel
            icon.contentMode = .scaleAspectFit
            let nameL = UILabel()
            nameL.text = it.name
            nameL.font = .systemFont(ofSize: 11)
            nameL.textColor = .label
            nameL.numberOfLines = 2
            nameL.lineBreakMode = .byTruncatingMiddle
            nameL.textAlignment = .center
            for s in [icon, nameL] as [UIView] { s.translatesAutoresizingMaskIntoConstraints = false; v.addSubview(s) }
            NSLayoutConstraint.activate([
                icon.topAnchor.constraint(equalTo: v.topAnchor, constant: 10),
                icon.centerXAnchor.constraint(equalTo: v.centerXAnchor),
                icon.heightAnchor.constraint(equalToConstant: 22),
                nameL.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
                nameL.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 6),
                nameL.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -6),
            ])
        }
        return v
    }

    // MARK: 读分享进来的东西

    /// 一个一个读:分享扩展内存只有一百来兆,九张大图同时解码会被系统杀掉
    private func loadItems() {
        let providers = ((extensionContext?.inputItems as? [NSExtensionItem]) ?? []).flatMap { $0.attachments ?? [] }
        var got: [Item] = []
        var texts: [String] = []
        var big: [String] = []
        setStatus("正在读取…", busy: true)
        func finish() {
            self.items = got
            self.tooBig = big
            let t = texts.filter { !$0.isEmpty }.joined(separator: "\n")
            if !t.isEmpty { self.textV.text = t }
            self.phL.isHidden = !self.textV.text.isEmpty
            for it in self.items { self.strip.addArrangedSubview(self.tile(for: it)) }
            self.stripScroll.isHidden = self.items.isEmpty
            if !big.isEmpty {
                self.setStatus("超过 10MB 发不了:" + big.joined(separator: "、"), busy: false)
            } else if self.items.isEmpty && t.isEmpty {
                self.setStatus("没读到能发的东西", busy: false)
            } else {
                self.setStatus("", busy: false)
            }
            self.refreshButtons()
        }
        func step(_ i: Int) {
            guard i < providers.count else { DispatchQueue.main.async { finish() }; return }
            Self.load(providers[i]) { item, text, tooBigName in
                if let item { got.append(item) }
                if let text { texts.append(text) }
                if let n = tooBigName { big.append(n) }
                step(i + 1)
            }
        }
        step(0)
    }

    /// 面板上的小图:只解一张 216 像素的缩略图,不把 2560 的原图整张放进内存
    private static func thumb(_ url: URL) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 216,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary).map { UIImage(cgImage: $0) }
    }

    /// 一个分享项:图片转成 JPEG(长边最多 2560);别的文件原样;网址和文字放进那句话里
    private static func load(_ p: NSItemProvider, done: @escaping (Item?, String?, String?) -> Void) {
        let image = UTType.image.identifier
        if p.hasItemConformingToTypeIdentifier(image) {
            p.loadFileRepresentation(forTypeIdentifier: image) { url, _ in
                if let url, let it = jpeg(from: url, name: p.suggestedName) { done(it, nil, nil); return }
                // 截图编辑器之类只给 UIImage,不给文件
                p.loadItem(forTypeIdentifier: image, options: nil) { obj, _ in
                    if let img = obj as? UIImage { done(jpeg(image: img, name: p.suggestedName), nil, nil) }
                    else if let u = obj as? URL { done(jpeg(from: u, name: p.suggestedName), nil, nil) }
                    else if let d = obj as? Data, let img = UIImage(data: d) { done(jpeg(image: img, name: p.suggestedName), nil, nil) }
                    else { done(nil, nil, nil) }
                }
            }
            return
        }
        if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { obj, _ in
                guard let u = obj as? URL else { done(nil, nil, nil); return }
                let ok = u.startAccessingSecurityScopedResource()
                defer { if ok { u.stopAccessingSecurityScopedResource() } }
                let r = copyIn(u, name: u.lastPathComponent)
                done(r.0, nil, r.1)
            }
            return
        }
        if let t = p.registeredTypeIdentifiers.first(where: { id in
            guard let u = UTType(id) else { return false }
            return u.conforms(to: .data) && !u.conforms(to: .url) && !u.conforms(to: .text)
        }) {
            p.loadFileRepresentation(forTypeIdentifier: t) { url, _ in
                guard let url else { done(nil, nil, nil); return }
                var name = url.lastPathComponent
                if let s = p.suggestedName, !s.isEmpty {
                    let ext = url.pathExtension.isEmpty ? (UTType(t)?.preferredFilenameExtension ?? "") : url.pathExtension
                    name = (s as NSString).pathExtension.isEmpty && !ext.isEmpty ? s + "." + ext : s
                }
                let r = copyIn(url, name: name)
                done(r.0, nil, r.1)
            }
            return
        }
        if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { obj, _ in
                done(nil, (obj as? URL)?.absoluteString, nil)
            }
            return
        }
        if p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            p.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { obj, _ in
                if let s = obj as? String { done(nil, s, nil) }
                else if let d = obj as? Data { done(nil, String(data: d, encoding: .utf8), nil) }
                else { done(nil, nil, nil) }
            }
            return
        }
        done(nil, nil, nil)
    }

    private static func scratch(_ name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent(safe.isEmpty ? "file" : safe)
    }

    /// 文件拷进自己的临时目录(给的地址出了回调就失效);超过上限的只回名字
    private static func copyIn(_ src: URL, name: String) -> (Item?, String?) {
        let size = (try? FileManager.default.attributesOfItem(atPath: src.path)[.size] as? Int) ?? 0
        if size > maxBytes { return (nil, name) }
        let dst = scratch(name)
        do { try FileManager.default.copyItem(at: src, to: dst) } catch { return (nil, nil) }
        let mime = UTType(filenameExtension: dst.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return (Item(url: dst, name: dst.lastPathComponent, mime: mime, isImage: false), nil)
    }

    private static func jpegName(_ s: String?) -> String {
        let base = ((s ?? "") as NSString).deletingPathExtension
        return (base.isEmpty ? "photo" : base) + ".jpg"
    }

    private static func jpeg(from url: URL, name: String?) -> Item? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2560,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return jpeg(image: UIImage(cgImage: cg), name: name ?? url.lastPathComponent)
    }

    private static func jpeg(image: UIImage, name: String?) -> Item? {
        var img = image
        let longest = max(img.size.width * img.scale, img.size.height * img.scale)
        if longest > 2560 {
            let k = 2560 / longest
            let size = CGSize(width: img.size.width * img.scale * k, height: img.size.height * img.scale * k)
            let fmt = UIGraphicsImageRendererFormat()
            fmt.scale = 1
            img = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        }
        guard let data = img.jpegData(compressionQuality: 0.85), data.count <= maxBytes else { return nil }
        let dst = scratch(jpegName(name))
        do { try data.write(to: dst) } catch { return nil }
        return Item(url: dst, name: dst.lastPathComponent, mime: "image/jpeg", isImage: true)
    }

    // MARK: 名字(服务器上的备注)

    private func loadNames() {
        guard let u = URL(string: Self.apiBase + "/app/nicknames") else { return }
        var r = URLRequest(url: u, timeoutInterval: 8)
        r.setValue("Bearer " + Self.auth, forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: r) { data, _, _ in
            guard let data, let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let z = o["zhao"] as? String, !z.isEmpty { self.mainName = z }
                if let y = o["yan"] as? String, !y.isEmpty { self.yanName = y }
                self.refreshButtons()
            }
        }.resume()
    }

    // MARK: 发

    @objc private func mainTap() { send(line: "") }
    @objc private func yanTap() { send(line: "yan-main") }

    @objc private func cancelTap() {
        extensionContext?.cancelRequest(withError: NSError(domain: "lustre.share", code: 0))
    }

    private struct ShareError: LocalizedError {
        let errorDescription: String?
        init(_ s: String) { errorDescription = s }
    }

    private func send(line: String) {
        guard !sending else { return }
        sending = true
        refreshButtons()
        textV.resignFirstResponder()
        let text = textV.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let todo = items
        Task {
            do {
                var atts: [[String: Any]] = []
                for (i, it) in todo.enumerated() {
                    setStatus(todo.count > 1 ? "上传 \(i + 1)/\(todo.count)…" : "上传中…", busy: true)
                    atts.append(try await Self.upload(it))
                }
                setStatus("发送中…", busy: true)
                var body: [String: Any] = ["text": text, "cid": UUID().uuidString, "attachments": atts]
                if !line.isEmpty { body["api_session"] = line }
                try await Self.post(body)
                setStatus("已发送", busy: false)
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { self.extensionContext?.completeRequest(returningItems: nil) }
            } catch {
                setStatus("没发出去:" + error.localizedDescription, busy: false)
                await MainActor.run {
                    self.sending = false
                    self.refreshButtons()
                }
            }
        }
    }

    private static func upload(_ it: Item) async throws -> [String: Any] {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        let q = it.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? "file"
        guard let u = URL(string: apiBase + "/app/upload?name=" + q) else { throw ShareError("地址不对") }
        var r = URLRequest(url: u, timeoutInterval: 120)
        r.httpMethod = "POST"
        r.setValue("Bearer " + auth, forHTTPHeaderField: "Authorization")
        r.setValue(it.mime, forHTTPHeaderField: "Content-Type")
        let (data, resp) = try await URLSession.shared.upload(for: r, fromFile: it.url)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200, let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], o["url"] != nil else {
            throw ShareError(code == 413 ? "\(it.name) 太大" : "上传失败(\(code))")
        }
        return o
    }

    private static func post(_ body: [String: Any]) async throws {
        guard let u = URL(string: apiBase + "/app/send") else { throw ShareError("地址不对") }
        var r = URLRequest(url: u, timeoutInterval: 30)
        r.httpMethod = "POST"
        r.setValue("Bearer " + auth, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, resp) = try await URLSession.shared.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw ShareError("发送失败(\(code))") }
    }
}
