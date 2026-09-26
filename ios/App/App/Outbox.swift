import Foundation
import UIKit
import Capacitor


struct LXStagedAtt {
    let bytes: Data
    let name: String
    let mime: String
    let kind: String
    let width: Int
    let height: Int
    var duration: Int = 0
    var thumbB64: String = ""

    var echoURL: String {
        if kind == "image", !thumbB64.isEmpty { return "data:\(mime);base64,\(thumbB64)" }
        return "pending://" + (name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "file")
    }
}

final class LXOutbox {
    static let shared = LXOutbox()
    private init() {}

    private(set) var staged: [LXStagedAtt] = []
    var original = false
    private(set) var quoteId: Int64 = 0
    private(set) var quoteFrom = ""
    private(set) var quoteText = ""

    private let maxBytes = 10 * 1024 * 1024


    func addPicked(_ files: [[String: Any]]) {
        for f in files {
            guard let b64 = f["data"] as? String, let d = Data(base64Encoded: b64) else { continue }
            if d.count > maxBytes { toast("文件太大（上限 10MB）"); continue }
            let kind = (f["kind"] as? String) ?? "file"
            var a = LXStagedAtt(bytes: d,
                                name: (f["name"] as? String) ?? "file",
                                mime: (f["mime"] as? String) ?? "application/octet-stream",
                                kind: kind,
                                width: (f["width"] as? NSNumber)?.intValue ?? 0,
                                height: (f["height"] as? NSNumber)?.intValue ?? 0)
            if kind == "image" { a.thumbB64 = LXOutbox.thumb(d) }
            staged.append(a)
        }
        syncCard()
    }

    func removeAtt(_ i: Int) {
        guard i >= 0, i < staged.count else { return }
        staged.remove(at: i)
        syncCard()
    }

    func setQuote(id: Int64, from: String, text: String, session: String) {
        quoteId = id
        quoteFrom = from
        quoteText = text
        let shown = from == "human" ? "我" : LXNick.of(session: session)
        DispatchQueue.main.async {
            NativeInputPlugin.live?.setQuote(on: true, name: shown, text: text)
        }
    }

    func clearQuote() {
        quoteId = 0; quoteFrom = ""; quoteText = ""
        DispatchQueue.main.async {
            NativeInputPlugin.live?.setQuote(on: false, name: "", text: "")
        }
    }

    private func syncCard() {
        let items: [Any] = staged.map { ["kind": $0.kind, "name": $0.name, "thumb": $0.thumbB64] }
        DispatchQueue.main.async { NativeInputPlugin.live?.rebuildAtts(items) }
    }

    static func thumb(_ d: Data, side: CGFloat = 360) -> String {
        guard let img = UIImage(data: d) else { return "" }
        let w = img.size.width, h = img.size.height
        guard w > 0, h > 0 else { return "" }
        let r = min(1, side / max(w, h))
        let size = CGSize(width: max(1, (w * r).rounded()), height: max(1, (h * r).rounded()))
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.72)?.base64EncodedString() ?? ""
    }


    func send(text raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let atts = staged
        guard !text.isEmpty || !atts.isEmpty else { return }
        let q: [String: Any]? = quoteId > 0
            ? ["id": NSNumber(value: quoteId), "from": quoteFrom, "text": quoteText] : nil

        staged = []
        clearQuote()
        DispatchQueue.main.async {
            NativeInputPlugin.live?.clearText()
            NativeInputPlugin.live?.rebuildAtts([])
        }

        deliver(text: text, atts: atts, quote: q)
    }

    func sendVoice(_ d: Data, mime: String, duration: Int) {
        guard d.count > 2000, duration > 0 else { toast("太短了，没发出去"); return }
        guard d.count <= maxBytes else { toast("录音太大，发不了"); return }
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-").prefix(19)
        let ext = mime.contains("mp4") || mime.contains("m4a") || mime.contains("aac") ? "m4a" : "webm"
        var a = LXStagedAtt(bytes: d, name: "voice-\(stamp).\(ext)", mime: mime,
                            kind: "audio", width: 0, height: 0)
        a.duration = duration
        deliver(text: "", atts: [a], quote: nil)
    }

    // MARK: 0925 发送管道(根治"发出去又被吞")
    // 每条发送 = 一张单子(cid):先把文字、引用、附件字节落盘,再上传/发送,真发出去才删单子。
    // 上传走系统后台 URLSession(切出 App 也继续传);失败自动重试;还不行就在气泡下标红"没发出去 · 点这里重发"。
    // 服务器按 cid 幂等(重发不会变两条),App 按 cid 认回自己那条气泡。

    private lazy var dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let d = base.appendingPathComponent("lx-outbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private func jobURL(_ cid: String) -> URL { dir.appendingPathComponent(cid + ".json") }
    private func attURL(_ cid: String, _ i: Int) -> URL { dir.appendingPathComponent("\(cid)-\(i).bin") }
    private func loadJob(_ cid: String) -> [String: Any]? {
        guard let d = try? Data(contentsOf: jobURL(cid)) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
    private func saveJob(_ j: [String: Any]) {
        guard let cid = j["cid"] as? String, let d = try? JSONSerialization.data(withJSONObject: j) else { return }
        try? d.write(to: jobURL(cid), options: .atomic)
    }
    private func dropJob(_ cid: String) {
        let n = ((loadJob(cid)?["atts"] as? [Any]) ?? []).count
        for i in 0..<max(n, 1) { try? FileManager.default.removeItem(at: attURL(cid, i)) }
        try? FileManager.default.removeItem(at: jobURL(cid))
    }
    private func allJobs() -> [[String: Any]] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } }
            .sorted { (($0["ts"] as? Double) ?? 0) < (($1["ts"] as? Double) ?? 0) }
    }
    private func echoAtts(_ j: [String: Any]) -> [LXAtt] {
        ((j["atts"] as? [[String: Any]]) ?? []).map { m in
            let name = (m["name"] as? String) ?? "file"
            let mime = (m["mime"] as? String) ?? ""
            let kind = (m["kind"] as? String) ?? "file"
            let thumb = (m["thumb"] as? String) ?? ""
            let url = (kind == "image" && !thumb.isEmpty) ? "data:\(mime);base64,\(thumb)"
                : "pending://" + (name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "file")
            return LXAtt(kind: kind, url: url, name: name, mime: mime,
                         size: (m["size"] as? Int) ?? 0, duration: (m["duration"] as? Int) ?? 0)
        }
    }

    private var running = Set<String>()
    private var failedCids = Set<String>()

    private func deliver(text: String, atts: [LXStagedAtt], quote: [String: Any]?) {
        guard let plug = ChatListPlugin.live else { return }
        let sid = plug.data.session
        let cid = UUID().uuidString
        var metas: [[String: Any]] = []
        for (i, a) in atts.enumerated() {
            try? a.bytes.write(to: attURL(cid, i), options: .atomic)
            metas.append(["name": a.name, "mime": a.mime, "kind": a.kind, "width": a.width, "height": a.height,
                          "duration": a.duration, "thumb": a.thumbB64, "size": a.bytes.count])
        }
        let ts = Date().timeIntervalSince1970
        var job: [String: Any] = ["cid": cid, "text": text, "sid": sid, "atts": metas,
                                  "uploaded": [Any](repeating: NSNull(), count: metas.count), "ts": ts]
        if let quote { job["quote"] = quote }
        saveJob(job)
        plug.echo(text: text, atts: echoAtts(job), session: sid, cid: cid)
        run(cid)
    }

    /// 点红字重发
    func retry(_ cid: String) {
        failedCids.remove(cid)
        ChatListPlugin.live?.echoFailed(cid: cid, failed: false)
        run(cid)
    }

    /// 打开/切到一个对话时:把盘上还没发完的单子挂回来(气泡按原来的时间),没在跑、也没标失败的接着发
    func reinject(session sid: String) {
        guard let plug = ChatListPlugin.live else { return }
        for j in allJobs() {
            guard let cid = j["cid"] as? String, ((j["sid"] as? String) ?? "") == sid else { continue }
            if plug.data.hasDelivered(cid: cid) {          // 上次其实发成功了,只是没来得及删单子
                dropJob(cid); plug.data.settleEcho(cid: cid); continue
            }
            if !plug.data.hasOptimistic(cid: cid) {
                let ts = Date(timeIntervalSince1970: (j["ts"] as? Double) ?? Date().timeIntervalSince1970)
                plug.echo(text: (j["text"] as? String) ?? "", atts: echoAtts(j), session: sid, cid: cid, ts: ts)
                if failedCids.contains(cid) { plug.echoFailed(cid: cid, failed: true) }
            }
            if !running.contains(cid) && !failedCids.contains(cid) { run(cid) }
        }
    }

    private func run(_ cid: String) {
        guard !running.contains(cid), let job0 = loadJob(cid) else { return }
        running.insert(cid)
        Task { [weak self] in
            guard let self else { return }
            var job = job0
            let ok = await self.process(&job)
            await MainActor.run {
                self.running.remove(cid)
                if ok {
                    self.dropJob(cid)
                    ChatListPlugin.live?.data.settleEcho(cid: cid)
                } else {
                    self.failedCids.insert(cid)
                    ChatListPlugin.live?.echoFailed(cid: cid, failed: true)
                    self.toast("没发出去，点气泡下面的红字可以重发")
                }
            }
        }
    }

    private func process(_ j: inout [String: Any]) async -> Bool {
        let cid = (j["cid"] as? String) ?? ""
        let metas = (j["atts"] as? [[String: Any]]) ?? []
        var uploaded = (j["uploaded"] as? [Any]) ?? []
        while uploaded.count < metas.count { uploaded.append(NSNull()) }
        for (i, m) in metas.enumerated() where !(uploaded[i] is [String: Any]) {
            guard let obj = await uploadWithRetry(cid: cid, i: i, meta: m) else { return false }
            uploaded[i] = obj
            j["uploaded"] = uploaded
            saveJob(j)
        }
        let finals = uploaded.compactMap { $0 as? [String: Any] }
        if !finals.isEmpty {
            let real = finals.map { f in
                LXAtt(kind: (f["kind"] as? String) ?? "file",
                      url: (f["url"] as? String) ?? "",
                      name: (f["name"] as? String) ?? "file",
                      mime: (f["mime"] as? String) ?? "",
                      size: (f["size"] as? NSNumber)?.intValue ?? 0,
                      duration: (f["duration"] as? NSNumber)?.intValue ?? 0)
            }
            await MainActor.run { ChatListPlugin.live?.echoUpdate(cid: cid, atts: real) }
        }
        let sid = (j["sid"] as? String) ?? ""
        var body: [String: Any] = ["text": (j["text"] as? String) ?? "", "cid": cid]
        if !sid.isEmpty, sid != "__legacy__" { body["api_session"] = sid }
        if !finals.isEmpty { body["attachments"] = finals }
        if let q = j["quote"] { body["quote"] = q }
        for delay in [0.0, 2.0, 5.0] {
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            if await postSend(body) {
                if let data = ChatListPlugin.live?.data, data.session == sid { await data.refetchSince() }
                return true
            }
        }
        return false
    }

    private func uploadWithRetry(cid: String, i: Int, meta: [String: Any]) async -> [String: Any]? {
        let name = (meta["name"] as? String) ?? "file"
        let mime = (meta["mime"] as? String) ?? ""
        let q = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "file"
        guard let url = URL(string: LustreConfig.apiBase + "/app/upload?name=" + q) else { return nil }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue(mime.isEmpty ? "application/octet-stream" : mime, forHTTPHeaderField: "Content-Type")
        let file = attURL(cid, i)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        for delay in [0.0, 2.0, 6.0] {
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            guard let res = try? await LXUploader.shared.upload(r, file: file),
                  (200..<300).contains(res.0),
                  var obj = (try? JSONSerialization.jsonObject(with: res.1)) as? [String: Any],
                  (obj["url"] as? String)?.isEmpty == false else { continue }
            if let w = meta["width"] as? Int, w > 0 { obj["width"] = w }
            if let h = meta["height"] as? Int, h > 0 { obj["height"] = h }
            if let d = meta["duration"] as? Int, d > 0 { obj["duration"] = d }
            return obj
        }
        return nil
    }

    private func postSend(_ body: [String: Any]) async -> Bool {
        guard let url = URL(string: LustreConfig.apiBase + "/app/send"),
              let payload = try? JSONSerialization.data(withJSONObject: body) else { return false }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.timeoutInterval = 30
        r.httpBody = payload
        guard let (_, resp) = try? await URLSession.shared.data(for: r),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return false }
        return true
    }

    private func toast(_ t: String) {
        DispatchQueue.main.async { ChatListPlugin.live?.outboxToast(t) }
    }
}

enum LXUsage {
    private static let key = "lx.usage.sessions"
    static var sessions: [String: [String: Any]] = {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Any]]) ?? [:]
    }()

    static func model(for sid: String) -> String {
        var v: [String: Any]?
        if sid.isEmpty || sid == "__legacy__" { v = sessions["书房"] }
        else if sid == "yan-main" { v = sessions["卧室"] }
        else { v = sessions.first(where: { $0.key.hasPrefix("room:" + sid + ":") })?.value }
        return (v?["model"] as? String) ?? ""
    }

    static var onLoaded: (() -> Void)?

    static func refresh() {
        guard let u = URL(string: LustreConfig.origin + "/chat/usage.json?t=\(Int(Date().timeIntervalSince1970))") else { return }
        var r = URLRequest(url: u)
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.timeoutInterval = 12
        URLSession.shared.dataTask(with: r) { d, _, _ in
            guard let d, let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                  let ss = o["sessions"] as? [String: [String: Any]], !ss.isEmpty else { return }
            sessions = ss
            UserDefaults.standard.set(ss, forKey: key)
            DispatchQueue.main.async { onLoaded?() }
        }.resume()
    }

    static func ctx(for sid: String) -> (text: String, pct: Int)? {
        var v: [String: Any]?
        if sid.isEmpty || sid == "__legacy__" { v = sessions["书房"] }
        else if sid == "yan-main" { v = sessions["卧室"] }
        else { v = sessions.first(where: { $0.key.hasPrefix("room:" + sid + ":") })?.value }
        guard let v,
              let ctx = (v["ctx"] as? NSNumber)?.doubleValue, ctx > 0 else { return nil }
        let limit = (v["limit"] as? NSNumber)?.doubleValue ?? 0
        let pct = min(100, (v["pct"] as? NSNumber)?.intValue
                      ?? Int((ctx * 100 / max(1, limit)).rounded()))
        return (RPSpec.tok(ctx) + " / " + RPSpec.tok(limit) + " · \(pct)%", pct)
    }
}


/// 0925:附件走系统后台上传——切出 App、锁屏,系统接着传;传完(哪怕 App 被挂起过)回调照样到
final class LXUploader: NSObject, URLSessionDataDelegate {
    static let shared = LXUploader()
    static let sessionId = "lx.upload.bg"
    var bgDone: (() -> Void)?
    private let lock = NSLock()
    private var conts: [Int: CheckedContinuation<(Int, Data), Error>] = [:]
    private var bodies: [Int: Data] = [:]
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.background(withIdentifier: Self.sessionId)
        c.isDiscretionary = false
        c.sessionSendsLaunchEvents = true
        c.timeoutIntervalForRequest = 90
        c.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()
    func wake() { _ = session }

    func upload(_ req: URLRequest, file: URL) async throws -> (Int, Data) {
        try await withCheckedThrowingContinuation { cont in
            let t = session.uploadTask(with: req, fromFile: file)
            lock.lock(); conts[t.taskIdentifier] = cont; bodies[t.taskIdentifier] = Data(); lock.unlock()
            t.resume()
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock(); bodies[dataTask.taskIdentifier, default: Data()].append(data); lock.unlock()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let cont = conts.removeValue(forKey: task.taskIdentifier)
        let body = bodies.removeValue(forKey: task.taskIdentifier) ?? Data()
        lock.unlock()
        guard let cont else { return }
        if let error { cont.resume(throwing: error); return }
        cont.resume(returning: ((task.response as? HTTPURLResponse)?.statusCode ?? 0, body))
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async { self.bgDone?(); self.bgDone = nil }
    }
}
