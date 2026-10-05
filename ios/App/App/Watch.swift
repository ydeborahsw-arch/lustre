import UIKit
import WebKit
import CryptoKit
import AVFoundation

// MARK: - 共看(1003 她的单)
// App 里开 B 站网页,她登自己的号看。播放器走到哪、这一段的台词,攒成一包递进他那条线(/app/yan_note:只进他终端,
// 她的聊天里不冒气泡);他回她的话在画面上飘成弹幕。节奏是她定的:按真在播的时间每 3 分钟一包(2–5 分钟可调),
// 或者台词攒到约 450 字先发;开始、看完各一条;暂停停住 5 秒以上提醒他一次;拖进度不单独叫他,写进下一包。
// 预览里一条都不往外发,只显示在屏幕底下的调试条上;真聊天也一句都不上画面。

enum LXWatchNet {
    /// 递给他的自动纸条
    static func note(_ text: String) {
        if LustreConfig.isPreview { LXWatchVC.shared.previewLog(text); return }
        HomeNet.post("/app/yan_note", ["text": String(text.prefix(500))])
    }

    /// 她在共看页里说的话 = 普通聊天消息;context 是给他看的"看到哪了",不进她的气泡
    static func send(text: String, context: String, attachments: [[String: Any]] = [], done: @escaping (Bool) -> Void) {
        if LustreConfig.isPreview {
            LXWatchVC.shared.previewLog("[她] " + text + (context.isEmpty ? "" : "\n" + context))
            done(true)
            return
        }
        guard !LustreConfig.secret.isEmpty, let u = URL(string: LustreConfig.apiBase + "/app/send") else { done(false); return }
        var body: [String: Any] = ["text": text, "api_session": "yan-main", "cid": UUID().uuidString]
        if !context.isEmpty { body["context"] = context }
        if !attachments.isEmpty { body["attachments"] = attachments }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 30
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r) { _, resp, _ in
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { done(ok) }
        }.resume()
    }

    /// 截图先传上去,拿回来的那份就是附件(和聊天里发图同一个接口)
    static func upload(_ jpeg: Data, size: CGSize, done: @escaping ([String: Any]?) -> Void) {
        put(jpeg, name: "watch-\(Int(Date().timeIntervalSince1970)).jpg", mime: "image/jpeg",
            extra: ["width": Int(size.width), "height": Int(size.height)], done: done)
    }

    /// 语音同理:传上去拿回附件,带上时长(和聊天里发语音一样的气泡)
    static func uploadVoice(_ m4a: Data, duration: Int, done: @escaping ([String: Any]?) -> Void) {
        put(m4a, name: "voice-\(Int(Date().timeIntervalSince1970)).m4a", mime: "audio/mp4", extra: ["duration": duration], done: done)
    }

    private static func put(_ data: Data, name: String, mime: String, extra: [String: Any], done: @escaping ([String: Any]?) -> Void) {
        guard !LustreConfig.isPreview, !LustreConfig.secret.isEmpty,
              let u = URL(string: LustreConfig.apiBase + "/app/upload?name=" + name) else { done(nil); return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.timeoutInterval = 60
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue(mime, forHTTPHeaderField: "Content-Type")
        URLSession.shared.uploadTask(with: r, from: data) { data, resp, _ in
            var obj = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if !(200..<300).contains(code) || ((obj?["url"] as? String) ?? "").isEmpty { obj = nil }
            if obj != nil { for (k, v) in extra { obj?[k] = v } }
            DispatchQueue.main.async { done(obj) }
        }.resume()
    }
}

// MARK: - 共看页的"发语音":开着回声消除录,手机外放的视频声音尽量不进录音

final class LXWatchRec {
    enum Start { case ok, denied, failed }
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var url: URL?
    private var t0 = Date()
    private var startedAt = Date.distantPast

    var isOn: Bool { file != nil }
    var elapsed: TimeInterval { isOn ? Date().timeIntervalSince(t0) : 0 }

    init() {
        // 录到一半网页放视频把声音设置改成"只放不录",或者耳机、蓝牙换了:设置拿回来,接着录进同一个文件
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] n in
            guard let s = self, s.isOn else { return }
            let why = (n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue ?? 0
            guard why == AVAudioSession.RouteChangeReason.categoryChange.rawValue,
                  AVAudioSession.sharedInstance().category != .playAndRecord else { return }
            s.reconnect()
        }
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let s = self, s.isOn, Date().timeIntervalSince(s.startedAt) > 1 else { return }   // 自己刚开的那一下不算
            s.reconnect()
        }
    }

    func start(_ done: @escaping (Start) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { done(granted ? (self.begin() ? .ok : .failed) : .denied) }
        }
    }

    private func setSession() throws {
        LXRadioAudio.yieldToMic()
        let ses = AVAudioSession.sharedInstance()
        try ses.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try ses.setActive(true)
    }

    private func begin() -> Bool {
        guard file == nil else { return true }
        do {
            try setSession()
            let input = engine.inputNode
            if !input.isVoiceProcessingEnabled { try input.setVoiceProcessingEnabled(true) }
            if #available(iOS 17.0, *) {
                var duck = input.voiceProcessingOtherAudioDuckingConfiguration   // 只减回声,不把视频的声音压小
                duck.duckingLevel = .min
                input.voiceProcessingOtherAudioDuckingConfiguration = duck
            }
            _ = engine.mainMixerNode   // 回声消除要收、放两头都在
            let rate = input.outputFormat(forBus: 0).sampleRate
            guard rate > 0 else { restore(); return false }
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("lx-watch-voice.m4a")
            try? FileManager.default.removeItem(at: u)
            let f = try AVAudioFile(forWriting: u, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate,
                                                             AVNumberOfChannelsKey: 1],
                                    commonFormat: .pcmFormatFloat32, interleaved: false)
            file = f
            url = u
            try run(f)
            t0 = Date()
            return true
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            file = nil
            url = nil
            restore()
            return false
        }
    }

    /// 收音接到文件上:只要第一声道;采样率和文件对不上(换了耳机)的那几段不写,免得写坏
    private func run(_ f: AVAudioFile) throws {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        let mono = f.processingFormat
        input.installTap(onBus: 0, bufferSize: 2048, format: fmt) { buf, _ in
            guard buf.format.sampleRate == mono.sampleRate, let src = buf.floatChannelData?[0],
                  let out = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: buf.frameLength),
                  let dst = out.floatChannelData?[0] else { return }
            out.frameLength = buf.frameLength
            memcpy(dst, src, Int(buf.frameLength) * MemoryLayout<Float>.size)
            try? f.write(from: out)
        }
        engine.prepare()
        startedAt = Date()
        try engine.start()
    }

    private func reconnect() {
        guard let f = file else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try setSession()
            try run(f)
        } catch {
            engine.inputNode.removeTap(onBus: 0)   // 接不回来:录到的那段还在,点发送照样发
        }
    }

    /// 停下;返回录好的文件和时长(没在录就是 nil)
    @discardableResult
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard file != nil, let u = url else { return nil }
        let d = Date().timeIntervalSince(t0)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        url = nil
        restore()
        return (url: u, duration: d)
    }

    /// 不停用整个声音会话(网页里的视频也在里面,一停视频就断声),改回只放不录交还给网页;正在通话就不动
    private func restore() {
        guard !LXCallSession.shared.isActive else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
    }
}

// MARK: - 进度和台词怎么攒、什么时候递

struct LXWLine {
    let from: Double
    let text: String
}

final class LXWatchTracker {
    var onNote: (String) -> Void = { _ in }
    private(set) var key = ""
    var title = ""
    var duration: Double = 0
    var lines: [LXWLine] = []
    private var cursor: Double = 0          // 台词收到这里为止
    private var pending: [String] = []      // 收了还没递的台词
    private var events: [String] = []       // 拖动、继续:写进下一包
    private var playedSince: Double = 0     // 上一包以来真在播的秒数
    private var playedTotal: Double = 0     // 这个视频开播以来在播的秒数
    private var lastT: Double = 0
    private(set) var playing = false
    private var started = false
    private var startSent = false
    private var didEnd = false
    private var pauseNotified = false
    private var pauseQueued = false
    private var lastPauseNote: Date?
    private var pauseWork: DispatchWorkItem?
    private var startWork: DispatchWorkItem?
    private var sent: [Date] = []

    var intervalMin: Double {
        let v = UserDefaults.standard.double(forKey: "lx.watch.interval")
        return (2...5).contains(v) ? v : 3
    }
    var position: Double { lastT }

    func reset(key: String, title: String) {
        pauseWork?.cancel()
        startWork?.cancel()
        self.key = key
        self.title = title
        duration = 0
        lines = []
        cursor = 0
        pending = []
        events = []
        playedSince = 0
        playedTotal = 0
        lastT = 0
        playing = false
        started = false
        startSent = false
        didEnd = false
        pauseNotified = false
        pauseQueued = false
        lastPauseNote = nil
    }

    func play(at t: Double) {
        pauseWork?.cancel()
        pauseQueued = false
        if pauseNotified { events.append("从 \(Self.fmt(t)) 继续"); pauseNotified = false }
        if started && abs(t - lastT) >= 3 { jump(to: t) }
        playing = true
        didEnd = false
        lastT = t
        if !started {
            started = true
            cursor = t
            // 标题和字幕要一两秒才取到:最多等 4 秒再报"开始",取到了就马上报
            let w = DispatchWorkItem { [weak self] in self?.sendStart() }
            startWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: w)
        }
    }

    /// 标题和字幕取完了(取没取到都算)
    func metaReady() {
        if started, !startSent { startWork?.cancel(); sendStart() }
    }

    func time(_ t: Double, duration d: Double) {
        if d > 0, d.isFinite { duration = d }
        // 停着的时候拖进度:也要记下来,不然接着放时会把跳过的那段台词当成看过
        guard playing else {
            if started && abs(t - lastT) >= 3 { jump(to: t) }
            lastT = t
            return
        }
        let dt = t - lastT
        if dt > 0 && dt < 3 {
            playedSince += dt
            playedTotal += dt
            collect(to: t)
        } else if abs(dt) >= 3 {
            jump(to: t)
        }
        lastT = t
        maybeFlush()
    }

    func seeked(to t: Double) {
        if started && abs(t - lastT) >= 3 { jump(to: t) }
        lastT = t
    }

    private func jump(to t: Double) {
        // 刚开播那几秒 B 站自己跳到上次看到的地方,不算她拖
        if playedTotal >= 5 { events.append("从 \(Self.fmt(lastT)) 拖到 \(Self.fmt(t))") }
        cursor = t
    }

    func pause(at t: Double) {
        guard playing else { return }
        if t > lastT && t - lastT < 3 { collect(to: t) }
        playing = false
        lastT = t
        pauseWork?.cancel()
        pauseQueued = true
        let w = DispatchWorkItem { [weak self] in self?.sendPause(left: false) }
        pauseWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: w)
    }

    func ended(at t: Double) {
        pauseWork?.cancel()
        pauseQueued = false
        collect(to: max(t, lastT) + 1)
        playing = false
        guard started, !didEnd else { return }
        didEnd = true
        if !startSent { startWork?.cancel(); sendStart() }
        emit("〔共看·看完〕\(title)" + evText())
        started = false
        startSent = false
    }

    /// 网页里的视频没了,或者她点去了另一个视频
    func gone() {
        guard started, !didEnd else { return }
        if !startSent {
            startWork?.cancel()
            started = false
            return
        }
        if playing || pauseQueued {
            pauseWork?.cancel()
            pauseQueued = false
            playing = false
            sendPause(left: true)
        }
        started = false
        startSent = false
    }

    /// 她打字、截图时带过去的"看到哪了";带过去的台词就算递过了,计时从头算
    func context() -> String {
        guard started, !key.isEmpty else { return "" }
        var s = "〔共看〕她正在看\(title),\(playing ? "播到" : "停在") \(Self.fmt(lastT))" + evText()
        if !pending.isEmpty { s += "。刚才的台词:\n" + pending.joined(separator: "\n") }
        pending = []
        events = []
        playedSince = 0
        return Self.fit(s)
    }

    private func sendStart() {
        guard started, !startSent else { return }
        startSent = true
        var s = "〔共看·开始〕她在 App 里开始看\(title)"
        var bits: [String] = []
        if duration > 0 { bits.append("全长 \(Self.fmt(duration))") }
        if lastT >= 5 { bits.append("从 \(Self.fmt(lastT)) 开始") }
        if !bits.isEmpty { s += "(" + bits.joined(separator: ",") + ")" }
        s += lines.isEmpty ? "。这个视频没读到字幕,只报进度。" : "。"
        s += "这是她手机自动发来的,不是她打的字。你回她的话会在她的画面上飘成弹幕,也照常进聊天记录;不想说可以不回。"
        emit(s, withLines: false)
    }

    private func sendPause(left: Bool) {
        pauseQueued = false
        guard !playing, !didEnd, startSent else { return }
        // 一分钟里停了又停,只提醒一次(没提醒的那次,接着放也就不写"继续")
        if !left, let l = lastPauseNote, Date().timeIntervalSince(l) < 60 { return }
        if emit("〔共看·暂停〕\(title) 停在 \(Self.fmt(lastT))" + (left ? "(离开了这个视频)" : "") + evText()) {
            lastPauseNote = Date()
            pauseNotified = !left
        }
        playedSince = 0
    }

    private func collect(to t: Double) {
        guard t > cursor else { return }
        for l in lines where l.from >= cursor && l.from < t { pending.append(l.text) }
        if pending.count > 80 { pending.removeFirst(pending.count - 80) }
        cursor = t
    }

    private func maybeFlush() {
        guard startSent, !lines.isEmpty else { return }      // 没字幕就不按时间叫他,只报开始/暂停/看完
        let chars = pending.reduce(0) { $0 + $1.count + 1 }
        guard playedSince >= intervalMin * 60 || chars >= 450 else { return }
        emit("〔共看〕\(title) 看到 \(Self.fmt(lastT))" + evText())
        playedSince = 0
    }

    private func evText() -> String { events.isEmpty ? "" : "(" + events.joined(separator: ";") + ")" }

    /// 带台词的那几种(withLines)把攒着的台词和拖动记录一起递出去;开始那条不带
    @discardableResult
    private func emit(_ head: String, withLines: Bool = true) -> Bool {
        var s = head
        if withLines {
            if !pending.isEmpty { s += "\n" + pending.joined(separator: "\n") }
            pending = []
            events = []
        }
        // 防出错刷屏:一小时最多 40 条,超了这条就不递了
        let now = Date()
        sent = sent.filter { now.timeIntervalSince($0) < 3600 }
        guard sent.count < 40 else { return false }
        sent.append(now)
        onNote(Self.fit(s))
        return true
    }

    /// 一条纸条最多 500 字:台词多了从最早的那句往后丢
    static func fit(_ s: String) -> String {
        guard s.count > 500 else { return s }
        var parts = s.components(separatedBy: "\n")
        while parts.count > 2, parts.joined(separator: "\n").count > 496 { parts.remove(at: 1) }
        if parts.count > 1 { parts.insert("…", at: 1) }
        return String(parts.joined(separator: "\n").prefix(500))
    }

    static func fmt(_ t: Double) -> String {
        let s = Int(max(0, t.isFinite ? t : 0))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - 去 B 站取标题和字幕(请求都在网页里发,带她自己的登录,不出手机)

final class LXWatchBili {
    weak var web: WKWebView?
    private static var mixin: (key: String, day: String)?
    private static let tab = [46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12,
                              38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57,
                              62, 11, 36, 20, 34, 44, 52]
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~")

    struct Info {
        var title: String
        var aid: Int
        var cid: Int
        var ep: Int?
        var duration: Double
    }

    func fetchJSON(_ url: String, _ done: @escaping ([String: Any]?) -> Void) {
        guard let web = web else { done(nil); return }
        web.callAsyncJavaScript("const r = await fetch(u, {credentials: 'include'}); return await r.text();",
                                arguments: ["u": url], in: nil, in: .defaultClient) { res in
            if case .success(let v) = res, let s = v as? String, let d = s.data(using: .utf8),
               let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                done(o)
                return
            }
            // 网页里取不到(跨域之类)再从 App 直接取一次;字幕文件本身不用登录
            guard let u = URL(string: url) else { done(nil); return }
            var r = URLRequest(url: u, timeoutInterval: 15)
            r.setValue(LXWatchVC.mobileUA, forHTTPHeaderField: "User-Agent")
            r.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            URLSession.shared.dataTask(with: r) { data, _, _ in
                let o = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                DispatchQueue.main.async { done(o) }
            }.resume()
        }
    }

    /// 地址 → 哪个视频:BV 号(带 p 分集)或番剧 ep 号
    static func key(of u: URL) -> (key: String, bv: String?, p: Int, ep: Int?)? {
        let parts = u.path.split(separator: "/").map(String.init)
        let p = Int(URLComponents(url: u, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "p" }?.value ?? "") ?? 1
        if let bv = parts.first(where: { $0.hasPrefix("BV") && $0.count == 12 }) { return ("\(bv)#\(p)", bv, p, nil) }
        if let e = parts.first(where: { $0.hasPrefix("ep") && Int($0.dropFirst(2)) != nil }), let n = Int(e.dropFirst(2)) { return ("ep\(n)", nil, 1, n) }
        if let s = parts.first(where: { $0.hasPrefix("ss") && Int($0.dropFirst(2)) != nil }) { return (s, nil, 1, nil) }
        return nil
    }

    func resolve(bv: String?, p: Int, ep: Int?, done: @escaping (Info?) -> Void) {
        if let bv = bv {
            fetchJSON("https://api.bilibili.com/x/web-interface/view?bvid=" + bv) { o in
                guard let d = o?["data"] as? [String: Any], let aid = (d["aid"] as? NSNumber)?.intValue else { done(nil); return }
                let pages = (d["pages"] as? [[String: Any]]) ?? []
                let pg = pages.first { ($0["page"] as? NSNumber)?.intValue == p } ?? pages.first
                guard let cid = (pg?["cid"] as? NSNumber)?.intValue ?? (d["cid"] as? NSNumber)?.intValue else { done(nil); return }
                var title = "《\((d["title"] as? String) ?? "")》"
                if pages.count > 1, let part = pg?["part"] as? String, !part.isEmpty { title += " P\(p) \(part)" }
                let dur = (pg?["duration"] as? NSNumber)?.doubleValue ?? (d["duration"] as? NSNumber)?.doubleValue ?? 0
                done(Info(title: title, aid: aid, cid: cid, ep: nil, duration: dur))
            }
        } else if let ep = ep {
            fetchJSON("https://api.bilibili.com/pgc/view/web/season?ep_id=\(ep)") { o in
                guard let r = o?["result"] as? [String: Any] else { done(nil); return }
                let eps = (r["episodes"] as? [[String: Any]]) ?? []
                guard let e = eps.first(where: { (($0["ep_id"] ?? $0["id"]) as? NSNumber)?.intValue == ep }),
                      let aid = (e["aid"] as? NSNumber)?.intValue, let cid = (e["cid"] as? NSNumber)?.intValue else { done(nil); return }
                var title = "《\((r["season_title"] as? String) ?? (r["title"] as? String) ?? "")》"
                if let st = e["show_title"] as? String, !st.isEmpty {
                    title += st
                } else {
                    let n = (e["title"] as? String) ?? ""
                    let lt = (e["long_title"] as? String) ?? ""
                    title += (Int(n) != nil ? "第\(n)话" : n) + (lt.isEmpty ? "" : " " + lt)
                }
                let ms = (e["duration"] as? NSNumber)?.doubleValue ?? 0
                done(Info(title: title, aid: aid, cid: cid, ep: ep, duration: ms / 1000))
            }
        } else {
            done(nil)
        }
    }

    func subtitles(_ info: Info, done: @escaping ([LXWLine]) -> Void) {
        var p = ["aid": String(info.aid), "cid": String(info.cid)]
        if let ep = info.ep { p["ep_id"] = String(ep) }
        signed("https://api.bilibili.com/x/player/wbi/v2", p) { url in
            guard let url = url else { done([]); return }
            self.fetchJSON(url) { o in
                let sub = (o?["data"] as? [String: Any])?["subtitle"] as? [String: Any]
                let list = (sub?["subtitles"] as? [[String: Any]]) ?? []
                func lan(_ d: [String: Any]) -> String { (d["lan"] as? String) ?? "" }
                // 人工中文字幕优先,其次 AI 中文,再其次随便一份
                let pick = list.first { lan($0).hasPrefix("zh") } ?? list.first { lan($0).hasPrefix("ai-zh") } ?? list.first
                guard var su = pick?["subtitle_url"] as? String, !su.isEmpty else { done([]); return }
                if su.hasPrefix("//") { su = "https:" + su } else if su.hasPrefix("http:") { su = "https:" + su.dropFirst(5) }
                self.fetchJSON(su) { j in
                    let body = (j?["body"] as? [[String: Any]]) ?? []
                    done(body.compactMap { b -> LXWLine? in
                        guard let f = (b["from"] as? NSNumber)?.doubleValue, let c = b["content"] as? String else { return nil }
                        return LXWLine(from: f, text: c.replacingOccurrences(of: "\n", with: " "))
                    }.sorted { $0.from < $1.from })
                }
            }
        }
    }

    /// B 站播放器接口要的 wbi 签名:参数排好序拼上当天的混合钥匙取 md5
    private func signed(_ base: String, _ params: [String: String], _ done: @escaping (String?) -> Void) {
        mixinKey { key in
            guard let key = key else { done(nil); return }
            var p = params
            p["wts"] = String(Int(Date().timeIntervalSince1970))
            let q = p.keys.sorted().map { k -> String in
                let v = (p[k] ?? "").filter { !"!'()*".contains($0) }
                return k + "=" + (v.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? v)
            }.joined(separator: "&")
            let md5 = Insecure.MD5.hash(data: Data((q + key).utf8)).map { String(format: "%02x", $0) }.joined()
            done(base + "?" + q + "&w_rid=" + md5)
        }
    }

    private func mixinKey(_ done: @escaping (String?) -> Void) {
        let day = String(Int(Date().timeIntervalSince1970 / 86400))
        if let m = Self.mixin, m.day == day { done(m.key); return }
        fetchJSON("https://api.bilibili.com/x/web-interface/nav") { o in
            let w = (o?["data"] as? [String: Any])?["wbi_img"] as? [String: Any]
            func stem(_ s: Any?) -> String {
                let last = ((s as? String) ?? "").split(separator: "/").last.map(String.init) ?? ""
                return last.components(separatedBy: ".").first ?? ""
            }
            let raw = Array(stem(w?["img_url"]) + stem(w?["sub_url"]))
            guard raw.count >= 64 else { done(nil); return }
            let key = String(Self.tab.map { raw[$0] }.prefix(32))
            Self.mixin = (key, day)
            done(key)
        }
    }
}

// MARK: - 弹幕层:他的话从右往左飘,不碰 B 站自己的弹幕

final class LXWDanmaku: UIView {
    private var laneFree: [CFTimeInterval] = []
    private let laneH: CGFloat = 28

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func shoot(_ text: String) {
        for (i, p) in Self.chunks(text).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.1) { [weak self] in self?.fly(p) }
        }
    }

    /// 长回复按句子切开,一句一条
    static func chunks(_ s: String) -> [String] {
        var out: [String] = []
        var cur = ""
        for ch in s.replacingOccurrences(of: "\n", with: " ") {
            cur.append(ch)
            if ("。！？!?…~～".contains(ch) && cur.count >= 6) || cur.count >= 28 {
                out.append(cur.trimmingCharacters(in: .whitespaces))
                cur = ""
            }
        }
        out.append(cur.trimmingCharacters(in: .whitespaces))
        return out.filter { !$0.isEmpty }
    }

    private func fly(_ text: String) {
        guard bounds.width > 40, bounds.height > 20 else { return }
        let lanes = max(1, Int((bounds.height * 0.7) / laneH))
        if laneFree.count != lanes { laneFree = Array(repeating: 0, count: lanes) }
        let now = CACurrentMediaTime()
        let lane = laneFree.firstIndex { $0 <= now } ?? laneFree.indices.min { laneFree[$0] < laneFree[$1] } ?? 0
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor(white: 0, alpha: 0.6),
            .strokeWidth: -2.5,
        ])
        l.sizeToFit()
        let w = l.bounds.width
        l.frame.origin = CGPoint(x: bounds.width, y: 6 + CGFloat(lane) * laneH)
        addSubview(l)
        let speed: CGFloat = 120
        laneFree[lane] = now + Double((w + 24) / speed)     // 同一条道等前一条整个露出来再放下一条
        UIView.animate(withDuration: Double((bounds.width + w) / speed), delay: 0, options: [.curveLinear], animations: {
            l.frame.origin.x = -w
        }, completion: { _ in l.removeFromSuperview() })
    }
}

/// 网页消息口不强持有页面
private final class LXWWeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ t: WKScriptMessageHandler) { target = t }
    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        target?.userContentController(c, didReceive: m)
    }
}

// MARK: - 共看页

final class LXWatchVC: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate,
                       UIGestureRecognizerDelegate {
    static let shared = LXWatchVC()
    static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
    static let home = "https://m.bilibili.com/"

    static func open() {
        let vc = shared
        guard vc.presentingViewController == nil else { return }
        vc.modalPresentationStyle = .fullScreen
        vc.modalPresentationCapturesStatusBarAppearance = true
        vc.openedAt = Date()
        DrawerPlugin.topVC()?.present(vc, animated: true)
    }

    /// 聊天推流每来一条都过一下这里:共看页开着时,他那条线的正式回复飘成弹幕
    static func feed(_ obj: [String: Any]) {
        guard !LustreConfig.isPreview else { return }       // 预览:真聊天一句都不许上画面
        let vc = shared
        guard vc.isViewLoaded, vc.presentingViewController != nil, obj["id"] is NSNumber,
              let m = LXChatData.parse(obj), m.from == "ai", m.kind == "reply", m.session == "yan-main",
              m.id > vc.lastFeedId, m.ts > vc.openedAt.addingTimeInterval(-5) else { return }
        vc.lastFeedId = m.id
        vc.danmaku.shoot(m.text)
    }

    private var web: WKWebView!
    private let topBar = UIView()
    private let backBtn = UIButton(type: .system)
    private let titleL = UILabel()
    private let fullBtn = UIButton(type: .system)
    private let moreBtn = UIButton(type: .system)
    private let closeBtn = UIButton(type: .system)
    let danmaku = LXWDanmaku()
    private let bar = UIView()
    private let barLine = UIView()
    private let field = UITextField()
    private let sendBtn = UIButton(type: .system)
    private let shotBtn = UIButton(type: .system)
    private let floatBar = UIStackView()     // 横屏时点一下画面出来:退出横屏 / 说话 / 截图
    private let tracker = LXWatchTracker()
    private let bili = LXWatchBili()
    private var videoRect: CGRect = .zero    // 网页里视频的位置(网页视口坐标)
    private(set) var landscape = false
    private var talking = false              // 横屏里把输入栏叫出来了
    private var kbH: CGFloat = 0
    private var lastFeedId: Int64 = 0
    private var openedAt = Date()
    private var floatHide: DispatchWorkItem?
    private var urlObs: NSKeyValueObservation?
    private var backObs: NSKeyValueObservation?
    private let debugL = UILabel()           // 预览:本来要递给他的纸条显示在这里
    var simulating = false
    // 1003 她:看的时候不停下来打字——话筒点开选"发语音"或"语音通话"(和聊天页一样),都开回声消除
    private let micBtn = UIButton(type: .system)
    private let floatMic = UIButton(type: .system)
    private let recL = UILabel()             // 录音时占输入框的位置:● 0:07 · 说完点右边发送
    private let rec = LXWatchRec()
    private var recTick: Timer?
    private let callChip = UIView()          // 通话条:竖屏在顶栏标题的位置,横屏浮在左上
    private let callL = UILabel()
    private let callMute = UIButton(type: .system)
    private let callEnd = UIButton(type: .system)
    private var callTick: Timer?
    private var callShown = false
    private var previewRec = false           // 预览:假装在录 / 在通话,只画样子
    private var previewCall = false
    private var recording: Bool { rec.isOn || previewRec }

    /// 共看页正摆在屏幕上
    static var isShowing: Bool { shared.isViewLoaded && shared.view.window != nil }

    /// 通话里她每说一句,共看页开着就带上"看到哪了"(和打字一样;带过去的台词就算递过了)
    static func callContext(sid: String) -> String? {
        guard isShowing, sid == "yan-main" else { return nil }
        let c = shared.tracker.context()
        return c.isEmpty ? nil : c
    }

    /// 通话开始、挂断(包括别处挂的、他打进来接起的)都叫一下
    static func callChanged() {
        guard isShowing else { return }
        shared.syncCall()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { landscape ? .landscape : .portrait }
    override var prefersStatusBarHidden: Bool { landscape }
    override var prefersHomeIndicatorAutoHidden: Bool { landscape }
    override var preferredStatusBarStyle: UIStatusBarStyle { LXSheetInk.dark ? .lightContent : .darkContent }

    private var desktop: Bool {
        get { UserDefaults.standard.bool(forKey: "lx.watch.desktop") }
        set { UserDefaults.standard.set(newValue, forKey: "lx.watch.desktop") }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.allowsPictureInPictureMediaPlayback = false
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let uc = WKUserContentController()
        uc.addUserScript(WKUserScript(source: Self.js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        uc.add(LXWWeakHandler(self), name: "lxw")
        cfg.userContentController = uc
        web = WKWebView(frame: .zero, configuration: cfg)
        web.customUserAgent = desktop ? Self.desktopUA : Self.mobileUA
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.isOpaque = false
        web.backgroundColor = .black
        view.addSubview(web)
        bili.web = web
        tracker.onNote = { LXWatchNet.note($0) }
        urlObs = web.observe(\.url, options: [.new]) { [weak self] w, _ in
            DispatchQueue.main.async { if let u = w.url { self?.noteURL(u, pageTitle: w.title ?? "") } }
        }
        backObs = web.observe(\.canGoBack, options: [.new]) { [weak self] w, _ in
            DispatchQueue.main.async { self?.backBtn.alpha = w.canGoBack ? 1 : 0.3 }
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(webTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        web.addGestureRecognizer(tap)

        view.addSubview(danmaku)

        // 顶栏:‹ 网页后退 / 标题 / 横屏 / 更多 / 回聊天的圆 ×(和共读同一种)
        func sym(_ b: UIButton, _ name: String, _ pt: CGFloat = 17) {
            b.setImage(UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: pt, weight: .medium)), for: .normal)
        }
        sym(backBtn, "chevron.left")
        backBtn.addAction(UIAction { [weak self] _ in if self?.web.canGoBack == true { self?.web.goBack() } }, for: .touchUpInside)
        backBtn.alpha = 0.3
        titleL.font = .systemFont(ofSize: 15, weight: .semibold)
        titleL.textAlignment = .center
        titleL.text = "Watch"
        sym(fullBtn, "arrow.up.left.and.arrow.down.right", 15)
        fullBtn.addAction(UIAction { [weak self] _ in self?.setLandscape(true) }, for: .touchUpInside)
        sym(moreBtn, "ellipsis")
        moreBtn.showsMenuAsPrimaryAction = true
        sym(closeBtn, "xmark", 15)
        closeBtn.layer.cornerRadius = 18
        closeBtn.layer.borderWidth = 1
        closeBtn.addAction(UIAction { [weak self] _ in self?.close() }, for: .touchUpInside)
        for v in [backBtn, titleL, fullBtn, moreBtn, closeBtn] as [UIView] { topBar.addSubview(v) }
        view.addSubview(topBar)

        // 底栏:截图 / 跟他说… / 话筒(有字时换成发送);录音时:取消 / ● 时长 / 发送
        sym(shotBtn, "camera", 18)
        shotBtn.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            if s.recording { s.cancelRec() } else { s.takeShot() }
        }, for: .touchUpInside)
        field.placeholder = "跟他说…"
        field.font = .systemFont(ofSize: 16)
        field.layer.cornerRadius = 18
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .send
        field.delegate = self
        sym(sendBtn, "arrow.up.circle.fill", 30)
        sendBtn.addAction(UIAction { [weak self] _ in
            guard let s = self else { return }
            if s.recording { s.finishRec() } else { s.sendTyped() }
        }, for: .touchUpInside)
        field.addAction(UIAction { [weak self] _ in self?.syncSend() }, for: .editingChanged)
        sym(micBtn, "mic", 20)
        micBtn.showsMenuAsPrimaryAction = true
        micBtn.menu = micMenu()
        recL.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        recL.isHidden = true
        for v in [barLine, shotBtn, field, recL, micBtn, sendBtn] as [UIView] { bar.addSubview(v) }
        view.addSubview(bar)

        // 横屏的小按钮
        floatBar.axis = .horizontal
        floatBar.spacing = 12
        for (name, act) in [("arrow.down.right.and.arrow.up.left", #selector(exitLandscape)), ("text.bubble", #selector(startTalk)),
                            ("camera", #selector(shotTapped))] {
            let b = UIButton(type: .system)
            sym(b, name, 17)
            b.tintColor = .white
            b.backgroundColor = UIColor(white: 0, alpha: 0.45)
            b.layer.cornerRadius = 20
            b.widthAnchor.constraint(equalToConstant: 40).isActive = true
            b.heightAnchor.constraint(equalToConstant: 40).isActive = true
            b.addTarget(self, action: act, for: .touchUpInside)
            floatBar.addArrangedSubview(b)
        }
        sym(floatMic, "mic", 17)
        floatMic.tintColor = .white
        floatMic.backgroundColor = UIColor(white: 0, alpha: 0.45)
        floatMic.layer.cornerRadius = 20
        floatMic.widthAnchor.constraint(equalToConstant: 40).isActive = true
        floatMic.heightAnchor.constraint(equalToConstant: 40).isActive = true
        floatMic.showsMenuAsPrimaryAction = true
        floatMic.menu = micMenu()
        floatBar.insertArrangedSubview(floatMic, at: 2)
        floatBar.isHidden = true
        view.addSubview(floatBar)

        // 通话条:时长 · 在听/在想/在说 / 静音 / 挂断
        callChip.layer.cornerRadius = 17
        callChip.isHidden = true
        callL.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        callMute.addAction(UIAction { [weak self] _ in
            LXCallSession.shared.toggleMute()
            self?.syncCall()
        }, for: .touchUpInside)
        sym(callEnd, "phone.down.fill", 13)
        callEnd.tintColor = .white
        callEnd.backgroundColor = .systemRed
        callEnd.layer.cornerRadius = 13
        callEnd.addAction(UIAction { [weak self] _ in
            LXCallSession.shared.hangUp()
            self?.syncCall()
        }, for: .touchUpInside)
        for v in [callL, callMute, callEnd] as [UIView] { callChip.addSubview(v) }
        view.addSubview(callChip)

        if LustreConfig.isPreview {
            debugL.numberOfLines = 0
            debugL.font = .systemFont(ofSize: 11)
            debugL.textColor = .white
            debugL.backgroundColor = UIColor(white: 0, alpha: 0.78)
            view.addSubview(debugL)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(kbChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        applyTheme()
        refreshMenu()
        syncSend()
        if !LustreConfig.isPreview, let u = URL(string: Self.home) { web.load(URLRequest(url: u)) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LXCallSession.shared.refreshEcho()   // 正在通话时进来:收音换成带回声消除的
        syncCall()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        LXCallSession.shared.refreshEcho()   // 出去了:没有视频在放,收音换回原样
        callTick?.invalidate(); callTick = nil
    }

    private func applyTheme() {
        let dark = LXSheetInk.dark
        view.backgroundColor = dark ? .black : .white
        topBar.backgroundColor = view.backgroundColor
        bar.backgroundColor = view.backgroundColor
        barLine.backgroundColor = LXSheetInk.sep
        for b in [backBtn, fullBtn, moreBtn, shotBtn, micBtn] { b.tintColor = LXSheetInk.icon }
        recL.textColor = LXSheetInk.text
        paintCallChip()
        titleL.textColor = LXSheetInk.text
        closeBtn.tintColor = LXSheetInk.icon
        closeBtn.backgroundColor = LXSheetInk.tile
        closeBtn.layer.borderColor = LXSheetInk.sep.cgColor
        sendBtn.tintColor = LXSheetInk.star
        field.backgroundColor = LXSheetInk.chip
        field.textColor = LXSheetInk.text
        field.tintColor = LXSheetInk.star
        setNeedsStatusBarAppearanceUpdate()
    }

    private func refreshMenu() {
        let cur = tracker.intervalMin
        let steps = [2.0, 3, 4, 5].map { m in
            UIAction(title: "\(Int(m)) 分钟", state: m == cur ? .on : .off) { [weak self] _ in
                UserDefaults.standard.set(m, forKey: "lx.watch.interval")
                self?.refreshMenu()
            }
        }
        let every = UIMenu(title: "台词每几分钟递给他一次", options: .displayInline, children: steps)
        let pc = UIAction(title: "电脑版网页", state: desktop ? .on : .off) { [weak self] _ in
            guard let s = self else { return }
            s.desktop.toggle()
            s.web.customUserAgent = s.desktop ? Self.desktopUA : Self.mobileUA
            s.web.reload()
            s.refreshMenu()
        }
        let home = UIAction(title: "回到 B 站首页") { [weak self] _ in
            if let u = URL(string: Self.home) { self?.web.load(URLRequest(url: u)) }
        }
        let reload = UIAction(title: "刷新") { [weak self] _ in self?.web.reload() }
        moreBtn.menu = UIMenu(children: [every, pc, home, reload])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let W = view.bounds.width, H = view.bounds.height
        let st = view.safeAreaInsets
        let barH: CGFloat = 52
        if landscape {
            topBar.isHidden = true
            web.frame = view.bounds
            bar.isHidden = !(talking || recording)
            let bottom = kbH > 0 ? H - kbH : H - st.bottom
            bar.frame = CGRect(x: 0, y: bottom - barH, width: W, height: barH)
            floatBar.sizeToFit()
            let fs = floatBar.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            floatBar.frame = CGRect(x: W - st.right - 16 - fs.width, y: H - st.bottom - 16 - fs.height, width: fs.width, height: fs.height)
        } else {
            topBar.isHidden = false
            bar.isHidden = false
            topBar.frame = CGRect(x: 0, y: st.top, width: W, height: 44)
            let bottom = kbH > 0 ? H - kbH : H - st.bottom
            bar.frame = CGRect(x: 0, y: bottom - barH, width: W, height: barH + (kbH > 0 ? 0 : st.bottom))
            web.frame = CGRect(x: 0, y: topBar.frame.maxY, width: W, height: max(0, bar.frame.minY - topBar.frame.maxY))
        }
        backBtn.frame = CGRect(x: 4, y: 0, width: 44, height: 44)
        closeBtn.frame = CGRect(x: W - 16 - 36, y: 4, width: 36, height: 36)
        moreBtn.frame = CGRect(x: closeBtn.frame.minX - 8 - 40, y: 0, width: 40, height: 44)
        fullBtn.frame = CGRect(x: moreBtn.frame.minX - 40, y: 0, width: 40, height: 44)
        titleL.frame = CGRect(x: 52, y: 0, width: max(0, fullBtn.frame.minX - 52 - 4), height: 44)
        barLine.frame = CGRect(x: 0, y: 0, width: W, height: 0.5)
        shotBtn.frame = CGRect(x: 8 + st.left, y: 4, width: 44, height: 44)
        sendBtn.frame = CGRect(x: W - st.right - 8 - 44, y: 4, width: 44, height: 44)
        micBtn.frame = sendBtn.frame
        field.frame = CGRect(x: shotBtn.frame.maxX + 4, y: 8, width: max(0, sendBtn.frame.minX - 4 - shotBtn.frame.maxX - 4), height: 36)
        recL.frame = field.frame.insetBy(dx: 14, dy: 0)
        layoutDanmaku()
        layoutCallChip()
        if LustreConfig.isPreview {
            let h: CGFloat = 150
            debugL.frame = CGRect(x: 0, y: (landscape ? H : bar.frame.minY) - h, width: W, height: h)
            view.bringSubviewToFront(debugL)
        }
        view.bringSubviewToFront(floatBar)
    }

    /// 弹幕盖在网页里视频的位置上;横屏盖满整屏;找不到视频就盖网页顶上一块
    private func layoutDanmaku() {
        if landscape {
            danmaku.frame = view.bounds
        } else {
            let wf = web.frame
            var r = videoRect.offsetBy(dx: wf.minX, dy: wf.minY).intersection(wf)
            if videoRect.width < 80 || videoRect.height < 60 || r.isNull || r.height < 60 {
                r = CGRect(x: wf.minX, y: wf.minY, width: wf.width, height: min(wf.height, wf.width * 9 / 16))
            }
            danmaku.frame = r
        }
        view.bringSubviewToFront(danmaku)
    }

    // MARK: 网页那边报来的

    func userContentController(_ c: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let d = msg.body as? [String: Any], let ev = d["ev"] as? String else { return }
        func num(_ k: String) -> Double { (d[k] as? NSNumber)?.doubleValue ?? 0 }
        if ev == "rect" {
            videoRect = CGRect(x: num("x"), y: num("y"), width: num("w"), height: num("h"))
            layoutDanmaku()
            return
        }
        if ev == "fs" { setLandscape(true); return }
        if simulating { return }
        if let s = d["url"] as? String, let u = URL(string: s) { noteURL(u, pageTitle: (d["title"] as? String) ?? "") }
        let t = num("t")
        switch ev {
        case "play": tracker.play(at: t)
        case "pause": tracker.pause(at: t)
        case "time": tracker.time(t, duration: num("d"))
        case "seeked": tracker.seeked(to: t)
        case "ended": tracker.ended(at: t)
        case "gone": tracker.gone()
        default: break
        }
    }

    /// 换了视频:重新认是哪部、取标题和字幕
    private func noteURL(_ u: URL, pageTitle: String) {
        guard !simulating, let k = LXWatchBili.key(of: u), k.key != tracker.key else { return }
        tracker.gone()
        let fallback = Self.cleanTitle(pageTitle)
        tracker.reset(key: k.key, title: fallback.isEmpty ? "一个视频" : "《\(fallback)》")
        titleL.text = fallback.isEmpty ? "Watch" : fallback
        let key = k.key
        bili.resolve(bv: k.bv, p: k.p, ep: k.ep) { [weak self] info in
            guard let s = self, s.tracker.key == key else { return }
            guard let info = info else { s.tracker.metaReady(); return }
            s.tracker.title = info.title
            if info.duration > 0 { s.tracker.duration = info.duration }
            s.titleL.text = info.title.replacingOccurrences(of: "《", with: "").replacingOccurrences(of: "》", with: " ")
            s.bili.subtitles(info) { lines in
                guard s.tracker.key == key else { return }
                s.tracker.lines = lines
                s.tracker.metaReady()
            }
        }
    }

    static func cleanTitle(_ t: String) -> String {
        var s = t
        for cut in ["_哔哩哔哩", "-哔哩哔哩", "_bilibili", "-bilibili", "_番剧"] {
            if let r = s.range(of: cut) { s = String(s[..<r.lowerBound]) }
        }
        return s.trimmingCharacters(in: .whitespaces)
    }

    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        // 网页里"打开 App"之类的跳转不放行,留在这里看
        let s = a.request.url?.scheme?.lowercased() ?? ""
        guard ["http", "https", "about", "blob", "data"].contains(s) else { decisionHandler(.cancel); return }
        // 1003 她:一点播放就跳进了 B 站 App——B 站的 https 链接是"通用链接",手机装了 B 站就会被系统直接拉过去。
        // WebKit 有一档"放行,但不试着开 App"(值 = allow + 2),用它就一直留在我们这页里
        decisionHandler(WKNavigationActionPolicy(rawValue: WKNavigationActionPolicy.allow.rawValue + 2) ?? .allow)
    }

    func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if a.targetFrame == nil, let u = a.request.url { w.load(URLRequest(url: u)) }
        return nil
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

    // MARK: 横屏

    func setLandscape(_ on: Bool) {
        guard on != landscape else { return }
        landscape = on
        talking = false
        view.endEditing(true)
        floatBar.isHidden = true
        web.evaluateJavaScript("window.__lxwFull && window.__lxwFull(\(on))", completionHandler: nil)
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
            view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: on ? .landscapeRight : .portrait)) { _ in }
        } else {
            UIDevice.current.setValue((on ? UIInterfaceOrientation.landscapeRight : .portrait).rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        paintCallChip()
        view.setNeedsLayout()
    }

    @objc private func exitLandscape() { setLandscape(false) }

    @objc private func webTapped() {
        guard landscape, !talking, !recording else { return }
        floatBar.isHidden = false
        floatHide?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.floatBar.isHidden = true }
        floatHide = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    @objc private func startTalk() {
        talking = true
        floatBar.isHidden = true
        view.setNeedsLayout()
        field.becomeFirstResponder()
    }

    @objc private func shotTapped() { takeShot() }

    @objc private func kbChange(_ n: Notification) {
        guard let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let local = view.convert(end, from: nil)
        kbH = max(0, view.bounds.height - local.minY)
        if kbH == 0, landscape { talking = false }
        let dur = (n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        UIView.animate(withDuration: dur) {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    // MARK: 说话、截图

    func textFieldShouldReturn(_ t: UITextField) -> Bool {
        sendTyped()
        return false
    }

    private func sendTyped() {
        let s = (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        field.text = ""
        syncSend()
        let ctx = tracker.context()
        LXWatchNet.send(text: s, context: ctx) { [weak self] ok in
            self?.toast(ok ? "发过去了" : "没发出去,再试一次")
            if !ok, self?.field.text?.isEmpty == true { self?.field.text = s; self?.syncSend() }
        }
        if landscape { talking = false; view.endEditing(true); view.setNeedsLayout() }
    }

    /// 输入框有字=发送键,没字=话筒;录音时=发送(点了就发这段语音)
    private func syncSend() {
        let has = !(field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rec = recording
        sendBtn.isHidden = !(has || rec)
        micBtn.isHidden = has || rec
        field.isHidden = rec
        recL.isHidden = !rec
        shotBtn.setImage(UIImage(systemName: rec ? "xmark" : "camera",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)), for: .normal)
    }

    /// 话筒点开:发语音 / 语音通话(和聊天页那个一样);通话中两样都先停用
    private func micMenu() -> UIMenu {
        UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] done in
            self?.floatHide?.cancel()   // 横屏小按钮 3 秒自动收,菜单开着时别收
            let busy = LXCallSession.shared.isActive || (self?.recording ?? false)
            let voice = UIAction(title: "发语音", image: UIImage(systemName: "mic"),
                                 attributes: busy ? .disabled : []) { _ in self?.startRec() }
            let call = UIAction(title: LXCallSession.shared.isActive ? "通话中" : "语音通话", image: UIImage(systemName: "phone"),
                                attributes: busy ? .disabled : []) { _ in self?.startCall() }
            done([voice, call])
        }])
    }

    // MARK: 语音通话(就是聊天页那个通话;从这里打出去不弹大通话页,这页上一条通话条)

    private func startCall() {
        guard !LustreConfig.isPreview, !LXCallSession.shared.isActive else { return }
        floatBar.isHidden = true
        LXCallSession.shared.startOutgoing(sid: "yan-main", quiet: true)
        syncCall()
    }

    func syncCall() {
        let s = LXCallSession.shared
        let on = s.isActive || previewCall
        if on {
            let state: String
            if previewCall { state = "在听" }
            else {
                switch s.phase {
                case .connecting: state = "接通中"
                case .listening: state = s.muted ? "静音中" : "在听"
                case .thinking: state = "在想"
                case .speaking: state = "在说"
                }
            }
            callL.text = (previewCall ? "00:42" : s.elapsedText) + " · " + state
            callMute.setImage(UIImage(systemName: s.muted ? "mic.slash.fill" : "mic.fill",
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)), for: .normal)
            if callTick == nil {
                callTick = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.syncCall() }
            }
        } else {
            callTick?.invalidate(); callTick = nil
        }
        guard on != callShown else { layoutCallChip(); return }
        callShown = on
        callChip.isHidden = !on
        view.setNeedsLayout()
    }

    private func paintCallChip() {
        let fg: UIColor = landscape ? .white : LXSheetInk.text
        callChip.backgroundColor = landscape ? UIColor(white: 0, alpha: 0.45) : LXSheetInk.chip
        callL.textColor = fg
        callMute.tintColor = fg
    }

    /// 竖屏:顶栏标题那块换成通话条;横屏:浮在左上角
    private func layoutCallChip() {
        titleL.isHidden = callShown && !landscape
        guard callShown else { return }
        // 宽度按最宽的那种量一次,状态字两个三个来回换时通话条不跳
        let probe = UILabel()
        probe.font = callL.font
        probe.text = "00:00 · 接通中"
        let lw = ceil(max(probe.sizeThatFits(CGSize(width: 240, height: 34)).width,
                          callL.sizeThatFits(CGSize(width: 240, height: 34)).width))
        let w: CGFloat = lw + 82
        let h: CGFloat = 34
        let st = view.safeAreaInsets
        if landscape {
            callChip.frame = CGRect(x: st.left + 16, y: max(st.top, 12), width: w, height: h)
        } else {
            let mid = topBar.frame.minX + titleL.frame.midX
            callChip.frame = CGRect(x: max(52, mid - w / 2), y: topBar.frame.minY + 5, width: w, height: h)
        }
        callL.frame = CGRect(x: 12, y: 0, width: lw, height: h)
        callMute.frame = CGRect(x: callL.frame.maxX + 6, y: 2, width: 30, height: 30)
        callEnd.frame = CGRect(x: w - 4 - 26, y: 4, width: 26, height: 26)
        view.bringSubviewToFront(callChip)
    }

    // MARK: 发语音:开回声消除录,点发送就传上去,和打字一样带上看到哪了

    private func startRec() {
        guard !recording, !LXCallSession.shared.isActive else { return }
        if LustreConfig.isPreview { previewRec = true; enterRecUI(); return }
        rec.start { [weak self] res in
            guard let s = self else { return }
            switch res {
            case .ok: s.enterRecUI()
            case .denied: s.toast("录不了音,去 设置 里给 App 打开麦克风")
            case .failed: s.toast("录音没开起来,再点一次试试")
            }
        }
    }

    private func enterRecUI() {
        view.endEditing(true)
        talking = false
        floatBar.isHidden = true
        syncSend()
        renderRec()
        recTick?.invalidate()
        recTick = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.renderRec() }
        view.setNeedsLayout()
    }

    private func exitRecUI() {
        recTick?.invalidate(); recTick = nil
        previewRec = false
        syncSend()
        view.setNeedsLayout()
    }

    private func renderRec() {
        let sec = previewRec ? 7 : Int(rec.elapsed)
        let s = NSMutableAttributedString(string: "● ", attributes: [.foregroundColor: UIColor.systemRed])
        s.append(NSAttributedString(string: String(format: "%d:%02d · 说完点右边发送", sec / 60, sec % 60),
                                    attributes: [.foregroundColor: LXSheetInk.text]))
        recL.attributedText = s
    }

    private func cancelRec() {
        if let r = rec.stop() { try? FileManager.default.removeItem(at: r.url) }
        exitRecUI()
    }

    private func finishRec() {
        if previewRec {
            exitRecUI()
            LXWatchNet.send(text: "[语音 0:07]", context: tracker.context()) { _ in }
            return
        }
        guard let r = rec.stop() else { exitRecUI(); return }
        exitRecUI()
        let secs = Int(r.duration.rounded())
        // 文件收尾要一点点时间,稍等再读
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            let data = try? Data(contentsOf: r.url)
            try? FileManager.default.removeItem(at: r.url)
            guard let s = self else { return }
            guard let d = data, d.count > 2000, secs >= 1 else { s.toast("太短了,没发出去"); return }
            s.toast("正在发…")
            LXWatchNet.uploadVoice(d, duration: secs) { att in
                guard let att else { s.toast("没发出去,再试一次"); return }
                LXWatchNet.send(text: "", context: s.tracker.context(), attachments: [att]) { ok in
                    s.toast(ok ? "发过去了" : "没发出去,再试一次")
                }
            }
        }
    }

    /// 先试从网页里把这一帧画下来(视频允许的话是真画面);不行再截网页上视频那一块
    private func takeShot() {
        let js = """
        const v = document.querySelector('video');
        if (!v || !v.videoWidth) return '';
        const c = document.createElement('canvas');
        c.width = v.videoWidth; c.height = v.videoHeight;
        c.getContext('2d').drawImage(v, 0, 0, c.width, c.height);
        return c.toDataURL('image/jpeg', 0.85);
        """
        web.callAsyncJavaScript(js, arguments: [:], in: nil, in: .defaultClient) { [weak self] res in
            if case .success(let v) = res, let s = v as? String, let r = s.range(of: "base64,"),
               let d = Data(base64Encoded: String(s[r.upperBound...])), let img = UIImage(data: d) {
                self?.sendShot(img, how: "画面")
                return
            }
            self?.snapshotShot()
        }
    }

    private func snapshotShot() {
        let cfg = WKSnapshotConfiguration()
        if videoRect.width > 80, videoRect.height > 60 { cfg.rect = videoRect.intersection(web.bounds) }
        web.takeSnapshot(with: cfg) { [weak self] img, _ in
            guard let self = self else { return }
            guard let img = img else { self.toast("没截到"); return }
            self.sendShot(img, how: "网页")
        }
    }

    private func sendShot(_ img: UIImage, how: String) {
        // 视频那块截出来全黑(iOS 不让截正在放的视频)就别发一张黑图给他
        if Self.isBlack(img) {
            if LustreConfig.isPreview { previewLog("截图[\(how)] \(Int(img.size.width))×\(Int(img.size.height)) 全黑,没发") }
            toast("视频画面截不到,截出来是黑的")
            return
        }
        flash()
        if LustreConfig.isPreview {
            previewLog("截图[\(how)] \(Int(img.size.width))×\(Int(img.size.height)) 有画面")
            return
        }
        guard let jpeg = img.jpegData(compressionQuality: 0.85) else { return }
        let caption = "截图 · " + LXWatchTracker.fmt(tracker.position)
        LXWatchNet.upload(jpeg, size: img.size) { [weak self] att in
            guard let self = self else { return }
            guard let att = att else { self.toast("截图没传上去"); return }
            LXWatchNet.send(text: caption, context: self.tracker.context(), attachments: [att]) { ok in
                self.toast(ok ? "截图发给他了" : "截图没发出去")
            }
        }
    }

    static func isBlack(_ img: UIImage) -> Bool {
        guard let cg = img.cgImage else { return true }
        let w = 24, h = 24
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return false }
        var sum = 0
        for i in 0..<(w * h) { sum += Int(px[i * 4]) + Int(px[i * 4 + 1]) + Int(px[i * 4 + 2]) }
        return sum / (w * h * 3) < 8
    }

    private func flash() {
        let f = UIView(frame: danmaku.frame)
        f.backgroundColor = .white
        f.isUserInteractionEnabled = false
        view.addSubview(f)
        UIView.animate(withDuration: 0.35, animations: { f.alpha = 0 }, completion: { _ in f.removeFromSuperview() })
    }

    private func toast(_ s: String) {
        let l = UILabel()
        l.text = s
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = .white
        l.backgroundColor = UIColor(white: 0, alpha: 0.7)
        l.textAlignment = .center
        l.layer.cornerRadius = 16
        l.clipsToBounds = true
        let w = min(view.bounds.width - 40, l.intrinsicContentSize.width + 32)
        l.frame = CGRect(x: (view.bounds.width - w) / 2, y: (landscape ? view.bounds.height : bar.frame.minY) - 56, width: w, height: 32)
        view.addSubview(l)
        UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: { l.alpha = 0 }, completion: { _ in l.removeFromSuperview() })
    }

    private func close() {
        web.evaluateJavaScript("document.querySelectorAll('video').forEach(function (v) { v.pause(); })", completionHandler: nil)
        view.endEditing(true)
        if recording { cancelRec() }   // 录到一半的语音不发;通话不挂,回到聊天页上是那颗小胶囊
        if landscape {
            setLandscape(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.dismiss(animated: true) }
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: 预览

    func previewLog(_ s: String) {
        // 最新的在上面,留前一条对照
        let old = debugL.text ?? ""
        debugL.text = String((s + (old.isEmpty ? "" : "\n— — —\n" + old)).prefix(700))
        view.setNeedsLayout()
    }

    func previewLoad(_ url: String) {
        if let u = URL(string: url) { web.load(URLRequest(url: u)) }
    }

    func previewPlay() {
        web.evaluateJavaScript("var v = document.querySelector('video'); if (v) { v.muted = true; v.play(); }", completionHandler: nil)
    }

    /// 模拟一段"在播":不等真视频,按 20 倍速喂进度和样板台词,看纸条拼得对不对
    func previewSimulate() {
        simulating = true
        tracker.reset(key: "sample", title: "《样片》第1话 雨夜")
        tracker.lines = (0..<60).map { LXWLine(from: Double($0) * 4 + 1, text: "样片第\($0 + 1)句台词,雨下得很大") }
        tracker.play(at: 0)
        tracker.metaReady()
        for i in 1...100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { self.tracker.time(Double(i) * 2, duration: 1420) }
        }
    }

    func previewPause() { tracker.pause(at: tracker.position) }

    func previewType(_ s: String) {
        field.becomeFirstResponder()
        field.text = s
        syncSend()
    }

    func previewCallOn(_ on: Bool) { previewCall = on; syncCall() }
    func previewFloat() { webTapped() }
    func previewRecOn() { startRec() }
    func previewRecSend() { finishRec() }

    func previewSend() { sendTyped() }

    func previewShot() { takeShot() }

    // MARK: 注进网页的脚本

    static let js = """
    (function () {
      if (window.__lxw) return; window.__lxw = 1;
      var post = function (o) { try { window.webkit.messageHandlers.lxw.postMessage(o); } catch (e) {} };
      // 1003 她:不要"打开 App"那些。B 站手机网页在播放器上盖了一层罩子(点播放其实点的是它,它把人送去 App),
      // 还有顶上 Download App、"Open the App to watch more"、"点我去App发弹幕"、"App内观看更流畅"、卡片角上的 App 小标
      var noApp = '.player-mask,.open-app.weakened,.open-app-img,[class*="openapp"],[class*="callapp"],' +
        '[class*="launchapp"],[class*="launch-app"]{display:none!important}';
      var addNoApp = function () {
        if (document.getElementById('lxw-noapp')) return;
        var root = document.head || document.documentElement;
        if (!root) return;   // 太早了还没有页面骨架:等下面定时器再补
        var st = document.createElement('style'); st.id = 'lxw-noapp'; st.textContent = noApp;
        root.appendChild(st);
      };
      addNoApp();
      document.addEventListener('DOMContentLoaded', addNoApp);
      // 剩下包着"去 App"的那层(推荐视频卡片等):有网页地址就在这页里打开,没有就什么都不做
      document.addEventListener('click', function (e) {
        var el = e.target && e.target.closest ? e.target.closest('m-open-app') : null;
        if (!el) return;
        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
        var u = el.getAttribute('universallink') || '';
        var ok = u.indexOf('https://m.bilibili.com/') === 0 || u.indexOf('https://www.bilibili.com/') === 0;
        if (ok && u !== location.href) location.href = u;
      }, true);
      var v = null, lastT = -1, lastRect = '', lastUrl = '';
      var info = function (ev) {
        return { ev: ev, t: v ? v.currentTime : 0, d: v && isFinite(v.duration) ? v.duration : 0,
                 url: location.href, title: document.title };
      };
      var rect = function () {
        if (!v) return;
        var r = v.getBoundingClientRect();
        var s = [r.left, r.top, r.width, r.height].map(Math.round).join(',');
        if (s !== lastRect) { lastRect = s; post({ ev: 'rect', x: r.left, y: r.top, w: r.width, h: r.height }); }
      };
      var hook = function (nv) {
        v = nv; lastT = -1; lastRect = '';
        v.setAttribute('playsinline', ''); v.setAttribute('webkit-playsinline', '');
        ['play', 'pause', 'seeked', 'ended'].forEach(function (e) {
          v.addEventListener(e, function () { post(info(e)); });
        });
        v.addEventListener('timeupdate', function () {
          if (Math.abs(v.currentTime - lastT) >= 1) { lastT = v.currentTime; post(info('time')); }
        });
        if (!v.paused) post(info('play'));
        rect();
      };
      setInterval(function () {
        addNoApp();   // B 站页面会把 head 里后加的样式整个换掉,掉了就再补
        var nv = document.querySelector('video');
        if (nv && nv !== v) hook(nv);
        if (!nv && v) { v = null; post({ ev: 'gone', url: location.href, title: document.title }); }
        rect();
        if (location.href !== lastUrl) { lastUrl = location.href; post({ ev: 'url', url: lastUrl, title: document.title }); }
      }, 700);
      window.addEventListener('scroll', rect, { passive: true });
      // 系统自带的全屏会把弹幕层挡掉:换成 App 自己的横屏
      var fs = function () { post({ ev: 'fs' }); return Promise.resolve(); };
      HTMLVideoElement.prototype.webkitEnterFullscreen = fs;
      HTMLVideoElement.prototype.webkitEnterFullScreen = fs;
      Element.prototype.requestFullscreen = fs;
      Element.prototype.webkitRequestFullscreen = fs;
      Element.prototype.webkitRequestFullScreen = fs;
      // 横屏:把播放器(视频连同它自己的控制条)铺满整屏
      window.__lxwFull = function (on) {
        var st = document.getElementById('lxw-full');
        if (!st) {
          st = document.createElement('style'); st.id = 'lxw-full';
          st.textContent = '[data-lxw-full]{position:fixed!important;left:0!important;top:0!important;width:100vw!important;' +
            'height:100vh!important;max-width:none!important;max-height:none!important;margin:0!important;transform:none!important;' +
            'z-index:2147483647!important;background:#000!important}' +
            '[data-lxw-full] video{width:100%!important;height:100%!important;object-fit:contain!important}' +
            'html.lxw-full,html.lxw-full body{overflow:hidden!important}';
          (document.head || document.documentElement).appendChild(st);
        }
        document.querySelectorAll('[data-lxw-full]').forEach(function (e) { e.removeAttribute('data-lxw-full'); });
        document.documentElement.classList.toggle('lxw-full', !!on);
        if (!on || !v) return;
        var r0 = v.getBoundingClientRect(), el = v, p = v.parentElement;
        while (p && p !== document.body) {
          var r = p.getBoundingClientRect();
          if (Math.abs(r.width - r0.width) < 4 && r.height - r0.height < 60) { el = p; p = p.parentElement; } else break;
        }
        el.setAttribute('data-lxw-full', '');
      };
    })();
    """
}

// MARK: - 预览路线 watch:开一个不用登录的公开视频;进度和台词用模拟的,纸条只显示在调试条上

enum LXWatchPreview {
    static func start(tries: Int = 0) {
        guard LustreConfig.isPreview, LustreConfig.previewFocus == "watch" else { return }
        guard let top = DrawerPlugin.topVC(), top.view.window != nil else {
            if tries < 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(tries: tries + 1) } }
            return
        }
        LXWatchVC.open()
        let vc = LXWatchVC.shared
        vc.loadViewIfNeeded()
        vc.previewLoad("https://m.bilibili.com/video/BV1GJ411x7h7")
        let mark = UIView(frame: LXBubbleSampler.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let phase = UIView(frame: CGRect(x: 28, y: 70, width: 20, height: 20))
        let steps: [(UIColor, () -> Void)] = [
            (.yellow, { }),                                                                     // 页面打开,底栏是话筒
            (.cyan, { vc.previewPlay(); vc.previewCallOn(true)                                  // 弹幕 + 竖屏通话条
                      vc.danmaku.shoot("这一段我也想看。她回头的时候。找到你了") }),
            (.red, { vc.previewSimulate() }),                                                   // 开始 + 一包台词
            (UIColor(red: 0.5, green: 0, blue: 1, alpha: 1), { vc.previewPause() }),             // 暂停 5 秒后提醒
            (.white, { vc.setLandscape(true); vc.danmaku.shoot("横屏也飘得过去吗。")             // 横屏:通话条左上 + 小按钮带话筒
                       DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { vc.previewFloat() } }),
            (.gray, { vc.setLandscape(false); vc.previewCallOn(false); vc.previewType("刚才那句好好哭") }),   // 打字,话筒换成发送
            (.orange, { vc.previewSend(); vc.view.endEditing(true); vc.previewShot() }),        // 发出去带进度 + 截图
            (.green, { vc.previewRecOn()                                                        // 发语音:录音条,8 秒后发
                       DispatchQueue.main.asyncAfter(deadline: .now() + 8) { vc.previewRecSend() } }),
        ]
        for (i, st) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6 + Double(i) * 16) {
                st.1()
                phase.backgroundColor = st.0
                if mark.superview !== vc.view { vc.view.addSubview(mark); vc.view.addSubview(phase) }
                vc.view.bringSubviewToFront(mark)
                vc.view.bringSubviewToFront(phase)
            }
        }
    }
}
