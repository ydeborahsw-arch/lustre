import Foundation
import Capacitor
import UIKit
import WebKit
import AVFoundation
import MediaPlayer
import PhotosUI


struct LXAtt {
    let kind: String
    let url: String
    let name: String
    let mime: String
    let size: Int
    let duration: Int
    var fullURL: URL? {
        var s = url
        if s.hasPrefix("/"), let base = URL(string: LustreConfig.apiBase),
           let scheme = base.scheme, let host = base.host {
            s = "\(scheme)://\(host)" + s
        }
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("data:") || s.hasPrefix("file:") || s.hasPrefix("pending:") { return URL(string: s) }
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        s += (s.contains("?") ? "&" : "?") + "token=" + tok
        return URL(string: s)
    }
}

struct LXMsg {
    let id: Int64
    let from: String
    let kind: String
    var text: String
    let ts: Date
    let session: String
    let attCount: Int
    var durSec: Int = 0
    var atts: [LXAtt] = []
    var reactions: [String] = []
    var starred = false
    var approveLine: String? = nil
    var quoteName: String? = nil
    var quoteText: String? = nil
    var quoteId: Int64 = 0
    var servesId: Int64 = 0
    var echoId: Int64 = 0
    /// 0925:App 自己发出去的每一条带一个编号,服务器原样带回——一对一认回屏幕上那条(不再按"也带附件"瞎认)
    var cid: String = ""
    /// 0925:乐观气泡发送失败(自动重试过了),气泡下标红"没发出去 · 点这里重发"
    var failed = false
    /// 0925:拍一拍的动作——她在双击头像的卡里自己写的,空=拍了拍
    var patAct: String = ""
}

struct LXChatTheme {
    var bg = UIColor.black
    var me = UIColor(red: 0x26/255, green: 0x25/255, blue: 0x2A/255, alpha: 1)
    var meFg = UIColor.white
    var ai = UIColor.clear
    var aiFg = UIColor(white: 0xF5/255, alpha: 1)
    var faint = UIColor(red: 0x71/255, green: 0x7E/255, blue: 0x97/255, alpha: 1)
    var fn = UIColor(red: 0.843, green: 0.918, blue: 0.973, alpha: 1)
    var fnStar = UIColor(red: 0.714, green: 0.839, blue: 0.910, alpha: 1)
    var think = UIColor(red: 0.843, green: 0.918, blue: 0.973, alpha: 1)
    var accent = UIColor(red: 0.663, green: 0.851, blue: 0.933, alpha: 1)
    var avatars = false
    var thinkBody = UIColor(white: 0.69, alpha: 1)
    var hdrBtnBg = UIColor(white: 0x12/255, alpha: 1)
    var hdrBtnFg = UIColor.white
    var pillBg = UIColor(white: 0x12/255, alpha: 1)
    var pillFg = UIColor(red: 0.843, green: 0.918, blue: 0.973, alpha: 1)
    var hdrRing = UIColor(red: 0xD6/255, green: 0xDB/255, blue: 0xEA/255, alpha: 0.18)
    var hdrBtnSize: CGFloat = 32
    var pillH: CGFloat = 32
    var statusFs: CGFloat = 12
    var accentFg = UIColor(red: 0x05/255, green: 0x07/255, blue: 0x0B/255, alpha: 1)
    var hairline = UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10)
    var cardBg = UIColor(red: 0x26/255, green: 0x25/255, blue: 0x2A/255, alpha: 1)
    var segTrack = UIColor(red: 223/255, green: 227/255, blue: 238/255, alpha: 0.10)
    var menuBg = UIColor(white: 0x12/255, alpha: 1)

    static func cacheKey(_ moon: String) -> String { "lx.chatTheme." + moon }

    static func save(_ d: [String: Any], moon: String) {
        guard JSONSerialization.isValidJSONObject(d),
              let data = try? JSONSerialization.data(withJSONObject: d) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(moon))
    }

    mutating func loadCached(_ moon: String) {
        if let p = LXMoonPalette.chat[moon] { take(p) }
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey(moon)),
           let d = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] { take(d) }
        fnStar = Self.star(moon)
    }

    /// 0926 她:星芒色白天和月夜同一支浅蓝,只有半月是橙。按月相定死,网页传来的和旧缓存里存的都不认
    static func star(_ moon: String) -> UIColor {
        moon == "half" ? UIColor(red: 0xD9/255, green: 0x77/255, blue: 0x57/255, alpha: 1)
                       : UIColor(red: 0xB6/255, green: 0xD6/255, blue: 0xE8/255, alpha: 1)
    }

    mutating func take(_ call: CAPPluginCall) {
        var d: [String: Any] = [:]
        for (k, v) in call.options ?? [:] { if let ks = k as? String { d[ks] = v } }
        if JSONSerialization.isValidJSONObject(d),
           let data = try? JSONSerialization.data(withJSONObject: d),
           let clean = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let moon = (clean["moon"] as? String) ?? RPSpec.moonState
            Self.save(clean, moon: moon)
            take(clean)
            return
        }
        takeCall(call)
    }

    mutating func take(_ d: [String: Any]) {
        func str(_ k: String) -> String? { d[k] as? String }
        func num(_ k: String) -> CGFloat? { (d[k] as? NSNumber).map { CGFloat($0.doubleValue) } }
        if let v = str("bg"), let c = NativeInputPlugin.color(v) { bg = c }
        if let v = str("me"), let c = NativeInputPlugin.color(v) { me = c }
        if let v = str("meFg"), let c = NativeInputPlugin.color(v) { meFg = c }
        if let v = str("ai"), let c = NativeInputPlugin.color(v) { ai = c }
        if let v = str("aiFg"), let c = NativeInputPlugin.color(v) { aiFg = c }
        if let v = str("faint"), let c = NativeInputPlugin.color(v) { faint = c }
        if let v = str("fn"), let c = NativeInputPlugin.color(v) { fn = c }
        // fnStar 不从这里取:按月相定死,见 star(_:)
        if let v = str("think"), let c = NativeInputPlugin.color(v) { think = c }
        if let v = str("accent"), let c = NativeInputPlugin.color(v) { accent = c }
        if let v = str("thinkBody"), let c = NativeInputPlugin.color(v) { thinkBody = c }
        if let v = str("hdrBtnBg"), let c = NativeInputPlugin.color(v) { hdrBtnBg = c }
        if let v = str("hdrBtnFg"), let c = NativeInputPlugin.color(v) { hdrBtnFg = c }
        if let v = str("pillBg"), let c = NativeInputPlugin.color(v) { pillBg = c }
        if let v = str("pillFg"), let c = NativeInputPlugin.color(v) { pillFg = c }
        if let v = str("hdrRing"), let c = NativeInputPlugin.color(v) {
            hdrRing = c.withAlphaComponent(num("hdrRingA") ?? 0.18)
        }
        if let v = num("hdrBtnSize"), v > 10 { hdrBtnSize = v }
        if let v = num("pillH"), v > 10 { pillH = v }
        if let v = num("statusFs"), v > 5 { statusFs = v }
        if let v = str("accentFg"), let c = NativeInputPlugin.color(v) { accentFg = c }
        if let v = d["avatars"] as? Bool { avatars = v }
        if let v = str("hairline"), let c = NativeInputPlugin.color(v) {
            hairline = c.withAlphaComponent(num("hairlineA") ?? 1)
        }
        if let v = str("cardBg"), let c = NativeInputPlugin.color(v) { cardBg = c }
        if let v = str("segTrack"), let c = NativeInputPlugin.color(v) { segTrack = c }
        if let v = str("menuBg"), let c = NativeInputPlugin.color(v) { menuBg = c }
    }

    private mutating func takeCall(_ call: CAPPluginCall) {
        if let v = call.getString("bg"), let c = NativeInputPlugin.color(v) { bg = c }
        if let v = call.getString("me"), let c = NativeInputPlugin.color(v) { me = c }
        if let v = call.getString("meFg"), let c = NativeInputPlugin.color(v) { meFg = c }
        if let v = call.getString("ai"), let c = NativeInputPlugin.color(v) { ai = c }
        if let v = call.getString("aiFg"), let c = NativeInputPlugin.color(v) { aiFg = c }
        if let v = call.getString("faint"), let c = NativeInputPlugin.color(v) { faint = c }
        if let v = call.getString("fn"), let c = NativeInputPlugin.color(v) { fn = c }
        fnStar = Self.star(call.getString("moon") ?? RPSpec.moonState)
        if let v = call.getString("think"), let c = NativeInputPlugin.color(v) { think = c }
        if let v = call.getString("accent"), let c = NativeInputPlugin.color(v) { accent = c }
        if let v = call.getString("thinkBody"), let c = NativeInputPlugin.color(v) { thinkBody = c }
        if let v = call.getString("hdrBtnBg"), let c = NativeInputPlugin.color(v) { hdrBtnBg = c }
        if let v = call.getString("hdrBtnFg"), let c = NativeInputPlugin.color(v) { hdrBtnFg = c }
        if let v = call.getString("pillBg"), let c = NativeInputPlugin.color(v) { pillBg = c }
        if let v = call.getString("pillFg"), let c = NativeInputPlugin.color(v) { pillFg = c }
        if let v = call.getString("hdrRing"), let c = NativeInputPlugin.color(v) {
            hdrRing = c.withAlphaComponent(CGFloat(call.getFloat("hdrRingA") ?? 0.18))
        }
        if let v = call.getFloat("hdrBtnSize"), v > 10 { hdrBtnSize = CGFloat(v) }
        if let v = call.getFloat("pillH"), v > 10 { pillH = CGFloat(v) }
        if let v = call.getFloat("statusFs"), v > 5 { statusFs = CGFloat(v) }
        if let v = call.getString("accentFg"), let c = NativeInputPlugin.color(v) { accentFg = c }
        if let v = call.getBool("avatars") { avatars = v }
        if let v = call.getString("hairline"), let c = NativeInputPlugin.color(v) {
            hairline = c.withAlphaComponent(CGFloat(call.getFloat("hairlineA") ?? 1))
        }
        if let v = call.getString("cardBg"), let c = NativeInputPlugin.color(v) { cardBg = c }
        if let v = call.getString("segTrack"), let c = NativeInputPlugin.color(v) { segTrack = c }
        if let v = call.getString("menuBg"), let c = NativeInputPlugin.color(v) { menuBg = c }
    }
}

enum LXRow {
    case day(String)
    case msg(LXMsg, showTime: Bool, tail: Bool, grouped: Bool, afterThink: Bool)
    case thinkHead(LXMsg, open: Bool, label: String, live: Bool)
    case thinkBody(LXMsg)
    case typing
    case foot
}


final class LXChatData {
    var session: String = "__legacy__"
    private(set) var msgs: [LXMsg] = []
    private var idx: [Int64: LXMsg] = [:]
    private var order: [Int64] = []
    private var orderSet = Set<Int64>()
    private var pendServes: [Int64: [Int64]] = [:]
    private var placedServes = Set<Int64>()
    private(set) var rows: [LXRow] = []
    var draft: String = ""
    var typingOn = false
    var onTyping: ((Bool) -> Void)?
    var thinkDraft: String = ""
    var thinkStart: Date?
    var expandedThink = Set<Int64>()
    var thinkInSheet = false
    private(set) var lastVisible: [LXMsg] = []
    static let liveThinkId: Int64 = .max - 1
    var running = false
    var hasOlder = true
    var onReload: ((_ stick: Bool) -> Void)?
    private(set) var detached = false
    private var liveSnap: LXPlacementSnap?
    private var liveInbox: [LXMsg] = []
    private var liveMinId: Int64 = 0
    var onDetach: ((_ on: Bool, _ fresh: Int) -> Void)?
    private var olderTask: Task<Bool, Never>?
    private var newerTask: Task<Bool, Never>?
    var onDupe: ((String, String) -> Void)?
    var deletedIds: Set<Int64> = {
        Set((UserDefaults.standard.array(forKey: "lx.deletedIds") as? [NSNumber] ?? []).map { $0.int64Value })
    }()
    private var optimisticSeq: Int64 = 0
    func addOptimistic(text: String, atts: [LXAtt] = [], cid: String = "", ts: Date = Date()) {
        if !cid.isEmpty, hasOptimistic(cid: cid) { return }
        optimisticSeq += 1
        var m = LXMsg(id: Int64.max - 5000 + optimisticSeq, from: "human", kind: "user", text: text,
                      ts: ts, session: session == "__legacy__" ? "" : session, attCount: atts.count,
                      atts: atts)
        m.cid = cid
        idx[m.id] = m
        order.append(m.id)
        orderSet.insert(m.id)
        reproject()
        rebuild(stick: true)
    }

    private func optimisticId(cid: String) -> Int64? {
        guard !cid.isEmpty else { return nil }
        return order.last(where: { $0 > Int64.max - 5000 && idx[$0]?.cid == cid })
    }
    func hasOptimistic(cid: String) -> Bool { optimisticId(cid: cid) != nil }
    /// 服务器那条(带同一个 cid)已经在列表里了
    func hasDelivered(cid: String) -> Bool {
        guard !cid.isEmpty else { return false }
        return idx.values.contains { $0.cid == cid && $0.id < Int64.max - 5000 }
    }
    /// 服务器那条已经在了,还挂着的乐观气泡就收掉(防"发成功了但回执对不上"留下重影)
    func settleEcho(cid: String) {
        guard hasDelivered(cid: cid), let oid = optimisticId(cid: cid) else { return }
        removeIds([oid])
        rebuild(stick: false)
    }
    /// 附件传完:乐观气泡换上服务器地址(原来靠"同样文字+同样附件数"去猜是哪条)
    func updateOptimistic(cid: String, atts: [LXAtt]) {
        guard let oid = optimisticId(cid: cid), var e = idx[oid] else { return }
        e.atts = atts
        idx[oid] = e
        echoPending.insert(oid)
        reproject()
        rebuild(stick: true)
    }
    func setOptimisticFailed(cid: String, _ on: Bool) {
        guard let oid = optimisticId(cid: cid), var e = idx[oid], e.failed != on else { return }
        e.failed = on
        idx[oid] = e
        reproject()
        rebuild(stick: false)
    }

    func markDeleted(_ id: Int64) {
        deletedIds.insert(id)
        removeIds([id])
        UserDefaults.standard.set(Array(deletedIds.suffix(2000)).map { NSNumber(value: $0) }, forKey: "lx.deletedIds")
        rebuild(stick: false)
    }
    func patch(_ id: Int64, _ mutate: (inout LXMsg) -> Void) {
        guard var m = idx[id] else { return }
        mutate(&m)
        idx[id] = m
        reproject()
        rebuild(stick: false)
    }
    func post(_ path: String, _ body: [String: Any], done: ((Bool) -> Void)? = nil) {
        guard var r = req(path) else { done?(false); return }
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let ok: Bool
            if let (_, resp) = try? await URLSession.shared.data(for: r),
               (resp as? HTTPURLResponse)?.statusCode == 200 { ok = true } else { ok = false }
            await MainActor.run { done?(ok) }
        }
    }
    private var sseTask: Task<Void, Never>?
    private var lastId: Int64 = 0
    private var thinkTimer: Timer?
    private var heldOpenThink: Int64?
    private var holdTimer: Timer?
    private var liveThinkTs: Date?
    private var liveThinkStartId: Int64 = 0
    private var liveTurnWatermark: Int64 = 0
    var echoPending: Set<Int64> = []
    var liveRowIdx: Int = -1
    private var draftShown = 0
    private var thinkShown = 0
    private var pacer: Timer?

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return c
    }()
    static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "M月d日 EEE"
        return f
    }()
    static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func req(_ path: String) -> URLRequest? {
        guard let url = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: url)
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.timeoutInterval = 15
        return r
    }

    static func parse(_ d: [String: Any]) -> LXMsg? {
        guard let idn = d["id"] as? NSNumber, let text = d["text"] as? String,
              let from = d["from"] as? String, let kind = d["kind"] as? String,
              let tss = d["ts"] as? String else { return nil }
        let meta = d["meta"] as? [String: Any] ?? [:]
        if (meta["hidden_from_app"] as? Bool) == true { return nil }
        if kind == "call", (meta["call"] as? String) == "start" { return nil }
        if let cid = meta["call_id"] as? String, !cid.isEmpty, let v = meta["voice"] {
            let on = (v as? Bool) ?? ((v as? NSNumber)?.boolValue ?? !(((v as? String) ?? "").isEmpty))
            if on { return nil }
        }
        let date = iso.date(from: tss) ?? isoPlain.date(from: tss) ?? Date()
        let attArr = (meta["attachments"] as? [[String: Any]]) ?? []
        let atts = attArr.compactMap { a -> LXAtt? in
            guard let u = a["url"] as? String, !u.isEmpty else { return nil }
            return LXAtt(kind: (a["kind"] as? String) ?? "file", url: u,
                         name: (a["name"] as? String) ?? "文件",
                         mime: (a["mime"] as? String) ?? "",
                         size: (a["size"] as? NSNumber)?.intValue ?? 0,
                         duration: (a["duration"] as? NSNumber)?.intValue ?? 0)
        }
        let rx = (meta["reactions"] as? [String: Any])?.compactMap { $0.value as? String }.filter { !$0.isEmpty } ?? []
        var line: String? = nil
        if let w = meta["widget"] as? [String: Any], let u = w["url"] as? String, u.contains("/term/approve") {
            line = u.contains("line=yan") ? "yan" : "zhao"
        }
        var qName: String? = nil, qText: String? = nil
        var qId: Int64 = 0
        if let q = meta["quote"] as? [String: Any] {
            qName = ((q["from"] as? String) == "human") ? "我" : "TA"
            qText = String(((q["text"] as? String) ?? "").prefix(80))
            qId = (q["id"] as? NSNumber)?.int64Value ?? 0
        } else if let rt = (meta["reply_to"] as? NSNumber)?.int64Value {
            qName = "引用"
            qText = "较早的一条消息"
            qId = rt
        }
        return LXMsg(id: idn.int64Value, from: from, kind: kind, text: text,
                     ts: date, session: (meta["api_session"] as? String) ?? "", attCount: atts.count,
                     durSec: (meta["duration_sec"] as? NSNumber)?.intValue ?? 0,
                     atts: atts, reactions: rx,
                     starred: (meta["starred"] as? Bool) ?? false,
                     approveLine: line,
                     quoteName: qName, quoteText: qText, quoteId: qId,
                     servesId: (meta["serves_id"] as? NSNumber)?.int64Value ?? 0,
                     cid: (meta["cid"] as? String) ?? "",
                     patAct: (meta["act"] as? String) ?? "")
    }

    private func inSession(_ m: LXMsg) -> Bool {
        if session == "__legacy__" || session.isEmpty { return m.session.isEmpty }
        return m.session == session
    }
    private func renderable(_ m: LXMsg) -> Bool {
        if m.kind == "thinking" { return !m.text.isEmpty }
        if m.kind == "pat" { return true }
        return !m.text.isEmpty || m.attCount > 0
    }

    private func resetPlacement() {
        idx = [:]; order = []; orderSet = []; pendServes = [:]; placedServes = []
        msgs = []
    }

    func start(session sid: String) {
        session = sid
        running = true
        clearDetached(restore: false)
        resetPlacement()
        rows = []; draft = ""; draftShown = 0; typingOn = false; lastId = 0; hasOlder = true
        liveTurnWatermark = 0
        clearThink(); releaseHold(); expandedThink.removeAll()
        loadCacheAndShow()
        Task { [weak self] in
            await self?.fetchTail()
            // 0925:上次没发完/没发出去的单子(落在盘上)挂回这个对话
            await MainActor.run { if let s = self { LXOutbox.shared.reinject(session: s.session) } }
            self?.openSSE()
        }
        startHealPulse()
    }

    func stop() {
        running = false
        sseTask?.cancel(); sseTask = nil
        clearThink()
    }

    private struct LXPlacementSnap {
        var idx: [Int64: LXMsg]; var order: [Int64]; var orderSet: Set<Int64>
        var pend: [Int64: [Int64]]; var placed: Set<Int64>
    }
    private var sessionCache: [String: LXPlacementSnap] = [:]
    func switchSession(_ sid: String) {
        clearDetached(restore: true)
        sessionCache[session] = LXPlacementSnap(idx: idx, order: order, orderSet: orderSet,
                                                pend: pendServes, placed: placedServes)
        session = sid
        if let snap = sessionCache[sid] {
            idx = snap.idx; order = snap.order; orderSet = snap.orderSet
            pendServes = snap.pend; placedServes = snap.placed
            reproject()
        } else {
            resetPlacement()
            loadCacheAndShow()
        }
        rows = []; draft = ""; draftShown = 0; typingOn = false
        lastId = msgs.last?.id ?? 0
        hasOlder = true
        liveTurnWatermark = 0
        clearThink(); releaseHold(); expandedThink.removeAll()
        rebuild(stick: true)
        Task { [weak self] in await self?.fetchTail() }
    }

    private func getJSON(_ path: String) async -> [[String: Any]] {
        return await getJSONOpt(path) ?? []
    }
    private func getJSONOpt(_ path: String) async -> [[String: Any]]? {
        guard let r = req(path) else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: r),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["messages"] as? [[String: Any]] else { return nil }
        return arr
    }

    private func reconcile(_ parsed: [LXMsg]) {
        let ids = parsed.map { $0.id }
        guard let lo = ids.min(), let hi = ids.max() else { return }
        let have = Set(ids)
        let gone = Set(msgs.filter { inSession($0) && $0.id >= lo && $0.id <= hi && !have.contains($0.id) }.map { $0.id })
        removeIds(gone)
    }

    private func chatCacheURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let safe = session.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("lx-chat-\(safe).json")
    }
    private func saveChatCache(_ arr: [[String: Any]]) {
        guard let url = chatCacheURL() else { return }
        let tail = Array(arr.suffix(120))
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONSerialization.data(withJSONObject: tail) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
    func loadCacheAndShow() {
        guard let url = chatCacheURL(),
              let data = try? Data(contentsOf: url),
              let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return }
        let parsed = arr.compactMap(Self.parse).filter(inSession)
        guard !parsed.isEmpty else { return }
        merge(parsed)
        rebuild(stick: true)
    }

    func fetchTail() async {
        let sid = session
        let arr = await getJSON("/app/history?latest=1&limit=200&session_id=\(sid)")
        guard session == sid else { return }
        let parsed = arr.compactMap(Self.parse).filter(inSession)
        saveChatCache(arr)
        guard !detached else { return }
        await MainActor.run {
            guard !self.detached else { return }
            self.reconcile(parsed)
            self.merge(parsed)
            if LustreConfig.isPreview { self.injectPreviewShowcase() }
            self.rebuild(stick: true)
        }
    }

    private func injectPreviewShowcase() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if LustreConfig.previewFocus == "composer" { ChatListPlugin.live?.previewComposerTour() }
            else if LustreConfig.previewFocus == "bubbles" { ChatListPlugin.live?.previewBubbleSampler() }
            else { ChatListPlugin.live?.previewAvaTimeCheck() }
        }
        let base = (msgs.last?.id ?? 0) + 1000
        let now = Date()
        let session = (self.session == "__legacy__") ? "" : self.session
        func img(_ n: Int) -> LXAtt {
            LXAtt(kind: "image", url: "/relay/uploads/att-0yYO9xgNGzAkHw.jpg",
                  name: "photo-\(n).jpg", mime: "image/jpeg", size: 0, duration: 0)
        }
        var demo: [LXMsg] = []
        demo.append(LXMsg(id: base + 1, from: "human", kind: "user", text: "样板:连发第一条 正文emoji对照🔥❤️",
                          ts: now.addingTimeInterval(-300), session: session, attCount: 0))
        demo.append(LXMsg(id: base + 2, from: "human", kind: "user", text: "样板:连发第二条(行缝4/组尾角)",
                          ts: now.addingTimeInterval(-290), session: session, attCount: 0,
                          reactions: ["❤️"]))
        demo.append(LXMsg(id: base + 21, from: "human", kind: "user", text: "样板:带引用条的回复",
                          ts: now.addingTimeInterval(-286), session: session, attCount: 0,
                          quoteName: "TA", quoteText: "样板:被引用的那句原话,验左条圆角单行省略", quoteId: base + 1))
        demo.append(LXMsg(id: base + 22, from: "human", kind: "user", text: "嗯……",
                          ts: now.addingTimeInterval(-285), session: session, attCount: 0))
        demo.append(LXMsg(id: base + 3, from: "human", kind: "user", text: "",
                          ts: now.addingTimeInterval(-280), session: session, attCount: 4,
                          atts: [img(1), img(2), img(3), img(4)]))
        demo.append(LXMsg(id: base + 23, from: "human", kind: "user", text: "样板:图文一起发,玻璃要盖住图和这两行字,不许缩在上面",
                          ts: now.addingTimeInterval(-279), session: session, attCount: 1,
                          atts: [img(5)]))
        demo.append(LXMsg(id: base + 4, from: "human", kind: "user", text: "",
                          ts: now.addingTimeInterval(-270), session: session, attCount: 1,
                          atts: [LXAtt(kind: "audio", url: "/relay/uploads/att-lNNxh6FPWbAqZw.m4a",
                                       name: "voice.m4a", mime: "audio/mp4", size: 0, duration: 23)]))
        demo.append(LXMsg(id: base + 5, from: "ai", kind: "thinking",
                          text: "样板:冻结思考卡,验证标题到下面消息的贴卡距离。",
                          ts: now.addingTimeInterval(-265), session: session, attCount: 0, durSec: 12,
                          servesId: base + 6))
        demo.append(LXMsg(id: base + 5001, from: "ai", kind: "thinking",
                          text: "样板:同一轮的第二段思考,应该和上一段并进同一张卡。\n读心率:验证轨道上那枚爱心图标的大小。",
                          ts: now.addingTimeInterval(-263), session: session, attCount: 0, durSec: 8,
                          servesId: base + 6))
        demo.append(LXMsg(id: base + 6, from: "ai", kind: "reply", text: "样板:带文件卡和表情章的回复",
                          ts: now.addingTimeInterval(-260), session: session, attCount: 1,
                          atts: [LXAtt(kind: "file", url: "/relay/uploads/att-WdXNzCBJmtyKog.p8",
                                       name: "示例文件.docx", mime: "", size: 182734, duration: 0)],
                          reactions: ["🔥", "👀"], starred: true))
        merge(demo)
    }

    func refetchSince() async {
        guard !detached else { return }
        guard lastId > 0 else { await fetchTail(); return }
        let sid = session
        let arr = await getJSON("/app/history?since=\(lastId)&limit=500&session_id=\(sid)")
        if session == sid, !arr.isEmpty {
            let parsed = arr.compactMap(Self.parse).filter(inSession)
            if !parsed.isEmpty {
                await MainActor.run {
                    self.merge(parsed)
                    self.rebuild(stick: true)
                }
            }
        }
        await healTail()
    }

    private var healTimer: Timer?
    func startHealPulse() {
        guard healTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            Task { await s.healTail() }
        }
        t.tolerance = 5
        healTimer = t
    }

    func healTail() async {
        let sid = session
        let arr = await getJSON("/app/history?latest=1&limit=200&session_id=\(sid)")
        guard session == sid, !detached, !arr.isEmpty else { return }
        let parsed = arr.compactMap(Self.parse).filter(inSession)
        guard !parsed.isEmpty else { return }
        await MainActor.run {
            guard !self.detached else { return }
            self.reconcile(parsed)
            self.merge(parsed)
            self.rebuild(stick: false)
        }
    }

    func fetchOlder() async -> Bool {
        if let t = olderTask { return await t.value }
        let t = Task<Bool, Never> { [weak self] in
            guard let s = self else { return false }
            return await s.fetchOlderNow()
        }
        olderTask = t
        let ok = await t.value
        olderTask = nil
        return ok
    }
    private func fetchOlderNow() async -> Bool {
        guard hasOlder, let minId = msgs.first?.id, minId > 1 else { return false }
        let sid = session
        guard let arr = await getJSONOpt("/app/history?before=\(minId)&limit=200&session_id=\(sid)") else { return false }
        guard session == sid else { return false }
        let parsed = arr.compactMap(Self.parse).filter(inSession)
        if parsed.isEmpty { hasOlder = false; return false }
        await MainActor.run {
            self.merge(parsed)
            self.rebuild(stick: false)
        }
        return true
    }

    func fetchNewer() async -> Bool {
        if let t = newerTask { return await t.value }
        let t = Task<Bool, Never> { [weak self] in
            guard let s = self else { return false }
            return await s.fetchNewerNow()
        }
        newerTask = t
        let ok = await t.value
        newerTask = nil
        return ok
    }
    private func fetchNewerNow() async -> Bool {
        guard detached, let maxId = msgs.last?.id else { return false }
        let sid = session
        guard let arr = await getJSONOpt("/app/history?since=\(maxId)&limit=200&session_id=\(sid)") else { return false }
        guard session == sid, detached else { return false }
        let parsed = arr.compactMap(Self.parse).filter(inSession)
        await MainActor.run {
            guard self.detached else { return }
            let reached = arr.count < 200 || parsed.contains { $0.id >= self.liveMinId }
            self.merge(parsed)
            if reached { self.reattach() } else { self.rebuild(stick: false) }
        }
        return !parsed.isEmpty
    }

    func ensureLoaded(_ id: Int64) async -> Bool {
        if msgs.contains(where: { $0.id == id }) { return true }
        let sid = session
        async let oq = getJSONOpt("/app/history?before=\(id + 1)&limit=200&session_id=\(sid)")
        async let nq = getJSONOpt("/app/history?since=\(id)&limit=200&session_id=\(sid)")
        guard let o = await oq, let n = await nq, session == sid else { return false }
        let po = o.compactMap(Self.parse).filter(inSession)
        let pn = n.compactMap(Self.parse).filter(inSession)
        guard po.contains(where: { $0.id == id }) else { return false }
        let win = po + pn
        let lo = win.first?.id ?? id
        let hi = win.last?.id ?? id
        let tailReached = n.count < 200
        await MainActor.run {
            guard self.session == sid else { return }
            let overlapCurrent = self.msgs.contains { $0.id >= lo && $0.id <= hi }
            if !self.detached {
                if overlapCurrent || tailReached {
                    self.merge(win)
                    self.hasOlder = true
                    self.rebuild(stick: false)
                } else {
                    self.detach(window: win)
                }
            } else {
                let reachesLive = tailReached || (self.liveMinId > 0 && hi >= self.liveMinId)
                if reachesLive {
                    self.merge(win)
                    self.reattach()
                } else if overlapCurrent {
                    self.merge(win)
                    self.hasOlder = true
                    self.rebuild(stick: false)
                } else {
                    self.detach(window: win)
                }
            }
        }
        return msgs.contains(where: { $0.id == id })
    }

    func idBefore(_ id: Int64) async -> Int64? {
        let sid = session
        let arr = await getJSON("/app/history?before=\(id)&limit=1&session_id=\(sid)")
        return arr.compactMap(Self.parse).filter(inSession).last?.id
    }

    private func detach(window: [LXMsg]) {
        if !detached {
            liveSnap = LXPlacementSnap(idx: idx, order: order, orderSet: orderSet,
                                       pend: pendServes, placed: placedServes)
            liveMinId = msgs.first?.id ?? 0
            liveInbox = []
            detached = true
        }
        if typingOn { onTyping?(false) }
        draft = ""; draftShown = 0; typingOn = false; liveTurnWatermark = 0
        clearThink(); releaseHold()
        resetPlacement()
        merge(window)
        hasOlder = true
        rebuild(stick: false)
        onDetach?(true, liveInbox.count)
    }

    private func reattach() {
        guard detached else { return }
        var back: [LXMsg] = []
        if let s = liveSnap { back.append(contentsOf: s.idx.values) }
        back.append(contentsOf: liveInbox)
        detached = false
        liveSnap = nil; liveInbox = []; liveMinId = 0
        merge(back)
        hasOlder = true
        rebuild(stick: false)
        onDetach?(false, 0)
        Task { [weak self] in await self?.refetchSince() }
    }

    private func clearDetached(restore: Bool) {
        guard detached else { return }
        let snap = liveSnap
        let inbox = liveInbox
        detached = false
        liveSnap = nil; liveInbox = []; liveMinId = 0
        onDetach?(false, 0)
        guard restore else { return }
        resetPlacement()
        if let s = snap {
            idx = s.idx; order = s.order; orderSet = s.orderSet
            pendServes = s.pend; placedServes = s.placed
            reproject()
        }
        merge(inbox)
        hasOlder = true
    }

    func returnToLive() {
        guard detached else { return }
        clearDetached(restore: true)
        rebuild(stick: true)
        Task { [weak self] in await self?.refetchSince() }
    }


    private func insertionIndex(for id: Int64) -> Int {
        var i = order.count
        while i > 0 {
            let pid = order[i - 1]
            if pid > id { i -= 1; continue }
            if placedServes.contains(pid), let pm = idx[pid], pm.servesId > id { i -= 1; continue }
            break
        }
        return i
    }

    private func place(_ m: LXMsg) {
        guard !orderSet.contains(m.id) else { return }
        if m.kind == "thinking", m.servesId > 0 {
            if let at = order.firstIndex(of: m.servesId) {
                order.insert(m.id, at: at)
                placedServes.insert(m.id)
            } else {
                pendServes[m.servesId, default: []].append(m.id)
            }
            orderSet.insert(m.id)
            return
        }
        let at = insertionIndex(for: m.id)
        order.insert(m.id, at: at)
        orderSet.insert(m.id)
        if m.kind != "thinking", let cards = pendServes.removeValue(forKey: m.id) {
            var off = 0
            for cid in cards where idx[cid] != nil {
                order.insert(cid, at: at + off)
                placedServes.insert(cid)
                off += 1
            }
        }
    }

    private func relocate(_ cardId: Int64, before replyId: Int64) {
        guard !placedServes.contains(cardId), let from = order.firstIndex(of: cardId) else { return }
        guard let to = order.firstIndex(of: replyId) else {
            order.remove(at: from)
            pendServes[replyId, default: []].append(cardId)
            return
        }
        order.remove(at: from)
        order.insert(cardId, at: from < to ? to - 1 : to)
        placedServes.insert(cardId)
    }

    private func removeIds(_ gone: Set<Int64>) {
        guard !gone.isEmpty else { return }
        order.removeAll { gone.contains($0) }
        orderSet.subtract(gone)
        placedServes.subtract(gone)
        for k in pendServes.keys {
            pendServes[k]?.removeAll { gone.contains($0) }
            if pendServes[k]?.isEmpty == true { pendServes.removeValue(forKey: k) }
        }
        for g in gone { idx.removeValue(forKey: g) }
        reproject()
    }

    private func reproject() {
        msgs = idx.values.sorted { $0.id < $1.id }
    }

    func probeIngest(_ ms: [LXMsg]) { merge(ms) }
    func probeOrder() -> [Int64] { order }

    private func settleLiveState(_ fresh: [LXMsg], bumped: [LXMsg] = []) {
        for m in fresh where inSession(m) {
            if m.kind == "thinking" {
                guard m.from == "ai", m.id > liveTurnWatermark else { continue }
                let liveNow = thinkStart != nil || !thinkDraft.isEmpty
                if liveNow || liveTurnWatermark > 0 {
                    if liveNow { holdOpen(m.id) }
                    clearThink()
                }
            } else {
                if let held = heldOpenThink, m.id > held { releaseHold() }
                if m.from == "ai", m.kind == "reply", liveTurnWatermark > 0, m.id > liveTurnWatermark {
                    draft = ""; draftShown = 0; typingOn = false
                    liveTurnWatermark = 0
                }
                if m.from == "ai", m.kind == "reply", thinkStart != nil || !thinkDraft.isEmpty,
                   msgs.contains(where: { inSession($0) && $0.kind == "thinking" && $0.from == "ai"
                                          && $0.id > liveThinkStartId && $0.id < m.id }) {
                    clearThink()
                }
            }
        }
        for m in bumped where inSession(m) && m.kind == "thinking" && m.from == "ai" && m.id > liveThinkStartId {
            guard thinkStart != nil || !thinkDraft.isEmpty else { continue }
            let replied = msgs.contains { inSession($0) && $0.from == "ai" && $0.kind == "reply" && $0.id > m.id }
            if !replied { holdOpen(m.id) }
            clearThink()
        }
    }

    private func merge(_ incoming: [LXMsg]) {
        guard !incoming.isEmpty else { return }
        let humanIncoming = incoming.filter { $0.from == "human" }
        var adopted: [Int64: Int64] = [:]
        if !humanIncoming.isEmpty {
            for inc in humanIncoming {
                // 0925:按 cid 一对一认领;服务器那条没有 cid(老消息/别处发的)才退回"文字完全相同、且乐观那条也没 cid"
                guard let ei = order.lastIndex(where: { oid in
                    guard oid > Int64.max - 5000, let e = idx[oid] else { return false }
                    if !inc.cid.isEmpty { return e.cid == inc.cid }
                    return e.cid.isEmpty && !inc.text.isEmpty && e.text == inc.text
                }) else { continue }
                let eid = order[ei]
                if orderSet.contains(inc.id) {
                    order.remove(at: ei)
                } else {
                    order[ei] = inc.id
                    orderSet.insert(inc.id)
                }
                orderSet.remove(eid)
                idx.removeValue(forKey: eid)
                adopted[inc.id] = eid
            }
        }
        var fresh: [LXMsg] = []
        var bumped: [LXMsg] = []
        for m0 in incoming where !deletedIds.contains(m0.id) {
            var m = m0
            if let e = adopted[m.id] { m.echoId = e; echoPending.insert(m.id) }
            if let old = idx[m.id] {
                // 0925 录屏:同一条会被送来两遍(推送一遍、发完补拉一遍)。第二遍的副本不知道它就是屏幕上那个乐观气泡,
                // 把 echoId 冲掉 → 行 key 变了 → 表格把这一行删掉重建 → 新玻璃出场那一帧发白。认过的就一直认下去。
                if m.echoId == 0 { m.echoId = old.echoId }
                idx[m.id] = m
                if m.kind == "thinking" { bumped.append(m) }
                if m.kind == "thinking", m.servesId > 0, old.servesId <= 0 {
                    relocate(m.id, before: m.servesId)
                }
            } else {
                idx[m.id] = m
                fresh.append(m)
            }
        }
        for m in fresh.sorted(by: { $0.id < $1.id }) { place(m) }
        reproject()
        lastId = max(lastId, msgs.last?.id ?? 0)
        settleLiveState(fresh, bumped: bumped)
    }

    func thinkLabel(_ m: LXMsg, live: Bool) -> String {
        if live {
            let sec = max(1, Int(Date().timeIntervalSince(thinkStart ?? Date())))
            return "Thinking for \(sec)s…"
        }
        return m.durSec > 0 ? "Thought for \(m.durSec)s" : "Thought process"
    }


    func thinkingForGroup(startingAt id: Int64) -> [LXMsg] {
        guard var i0 = lastVisible.firstIndex(where: { $0.id == id }) else { return [] }
        // 0925:每条都有头像了——点的是组里后面几条时,先往回找到这一组的第一条
        while true {
            var p = i0 - 1
            while p >= 0, lastVisible[p].kind == "thinking" { p -= 1 }
            guard p >= 0, lastVisible[p].from == lastVisible[i0].from,
                  lastVisible[i0].ts.timeIntervalSince(lastVisible[p].ts) < 300 else { break }
            i0 = p
        }
        let head = lastVisible[i0]
        var out: [LXMsg] = []
        var j = i0 - 1
        var before: [LXMsg] = []
        while j >= 0, lastVisible[j].kind == "thinking" { before.insert(lastVisible[j], at: 0); j -= 1 }
        out += before
        var prev = head
        var k = i0 + 1
        var pending: [LXMsg] = []
        while k < lastVisible.count {
            let m = lastVisible[k]
            if m.kind == "thinking" { pending.append(m); k += 1; continue }
            guard m.from == head.from, m.ts.timeIntervalSince(prev.ts) < 300 else { break }
            out += pending; pending = []
            prev = m; k += 1
        }
        return out
    }

    func mergeTurnThinking(_ input: [LXMsg]) -> [LXMsg] {
        return input
    }

    static func patLine(_ m: LXMsg) -> String {
        let ai = LXNick.of(session: m.session)
        let t = m.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let act = m.patAct.isEmpty ? "拍了拍" : m.patAct
        let head = m.from == "human" ? "我\(act) \(ai)" : "\(ai) \(act)我"
        return t.isEmpty ? head : head + "：" + t
    }

    func rebuild(stick: Bool) {
        if let lts = liveThinkTs,
           msgs.contains(where: { inSession($0) && $0.kind == "thinking" && $0.ts >= lts }) {
            clearThink()
        }
        var out: [LXRow] = []
        let allVisible = mergeTurnThinking(order.compactMap { idx[$0] }.filter { inSession($0) && renderable($0) })
        lastVisible = allVisible
        let visible = thinkInSheet ? allVisible.filter { $0.kind != "thinking" } : allVisible
        let liveActive = (!thinkDraft.isEmpty || thinkStart != nil) && !thinkInSheet
        var liveAt: Int? = nil
        for (i, m) in visible.enumerated() {
            if liveActive, liveAt == nil, m.id > liveThinkStartId, m.kind != "thinking" { liveAt = out.count }
            if m.kind == "pat" {
                out.append(.day(Self.patLine(m) + "\u{1F}\(m.id)"))
                continue
            }
            if m.kind == "thinking" {
                let open = expandedThink.contains(m.id)
                out.append(.thinkHead(m, open: open, label: thinkLabel(m, live: false), live: false))
                if open { out.append(.thinkBody(m)) }
                continue
            }
            var tail = true
            var ni = i + 1
            while ni < visible.count, visible[ni].kind == "thinking" { ni += 1 }
            if ni < visible.count {
                let n = visible[ni]
                tail = n.from != m.from || n.ts.timeIntervalSince(m.ts) > 300
            }
            var grouped = false
            var afterThink = false
            if i > 0 {
                let p = visible[i - 1]
                grouped = p.from == m.from && p.kind != "thinking" && m.ts.timeIntervalSince(p.ts) < 300
                afterThink = p.kind == "thinking" && !expandedThink.contains(p.id)
            }
                out.append(.msg(m, showTime: tail, tail: tail, grouped: grouped, afterThink: afterThink))
        }
        liveRowIdx = -1
        if liveActive {
            let live = LXMsg(id: Self.liveThinkId, from: "ai", kind: "thinking",
                             text: String(thinkDraft.prefix(thinkShown)),
                             ts: Date(), session: session, attCount: 0)
            let open = expandedThink.contains(Self.liveThinkId)
            var liveRows: [LXRow] = [.thinkHead(live, open: open, label: thinkLabel(live, live: true), live: true)]
            if open { liveRows.append(.thinkBody(live)) }
            let at = liveAt ?? out.count
            out.insert(contentsOf: liveRows, at: at)
            liveRowIdx = at
        }
        if !draft.isEmpty {
            out.append(.msg(LXMsg(id: .max, from: "ai", kind: "reply",
                                  text: String(draft.prefix(draftShown)),
                                  ts: Date(), session: session, attCount: 0), showTime: false, tail: true, grouped: false, afterThink: false))
        }
        if draft.isEmpty && thinkDraft.isEmpty && !typingOn && !detached && !thinkInSheet,
           let last = visible.last(where: { $0.kind != "thinking" }), last.from == "ai", last.kind == "reply" {
            out.append(.foot)
        }
        rows = out
        if !quiet { onReload?(stick) }
    }

    private var quiet = false
    func rebuildQuiet() {
        quiet = true
        rebuild(stick: false)
        quiet = false
    }

    private func ensureThinkTimer() {
        guard thinkTimer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            if s.thinkStart == nil { s.thinkTimer?.invalidate(); s.thinkTimer = nil; return }
            s.rebuild(stick: true)
        }
        t.tolerance = 0.2
        thinkTimer = t
    }

    private func clearThink() {
        thinkDraft = ""; thinkStart = nil; thinkShown = 0; liveThinkTs = nil
        expandedThink.remove(Self.liveThinkId)
        thinkTimer?.invalidate(); thinkTimer = nil
    }

    private func holdOpen(_ id: Int64) {
        expandedThink.insert(id)
        heldOpenThink = id
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            guard let s = self else { return }
            s.releaseHold()
            s.rebuild(stick: false)
        }
    }

    private func releaseHold() {
        holdTimer?.invalidate(); holdTimer = nil
        if let h = heldOpenThink { expandedThink.remove(h); heldOpenThink = nil }
    }

    func clearDraftShown() { draftShown = 0 }


    func openSSE() {
        sseTask?.cancel()
        sseTask = Task { [weak self] in
            while true {
                guard let s = self, s.running, !Task.isCancelled else { break }
                guard var r = s.req("/app/stream") else { break }
                r.timeoutInterval = 3600
                do {
                    let (bytes, resp) = try await URLSession.shared.bytes(for: r)
                    guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                    await s.refetchSince()
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let body = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard let d = body.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { continue }
                        await MainActor.run { s.handle(obj) }
                    }
                } catch { }
                if Task.isCancelled { break }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func eventInSession(_ obj: [String: Any]) -> Bool {
        let es = (obj["api_session"] as? String) ?? ""
        if session == "__legacy__" || session.isEmpty { return es.isEmpty }
        return es == session
    }

    func handle(_ obj: [String: Any]) {
        if LXCallSession.shared.isActive { LXCallSession.shared.feed(obj) }
        if obj["type"] == nil, obj["id"] is NSNumber, obj["from"] is String {
            guard let m = Self.parse(obj), inSession(m) else { return }
            if detached {
                liveInbox.removeAll { $0.id == m.id }
                liveInbox.append(m)
                lastId = max(lastId, m.id)
                onDetach?(true, liveInbox.count)
                return
            }
            merge([m])
            rebuild(stick: true)
            return
        }
        guard let type = obj["type"] as? String else { return }
        if detached, type != "reaction" { return }
        switch type {
        case "reply_delta":
            guard eventInSession(obj) else { return }
            if (obj["done"] as? Bool) == true {
                draft = ""; draftShown = 0; typingOn = false
                rebuild(stick: true)
                return
            }
            if liveTurnWatermark == 0 { liveTurnWatermark = lastId }
            draft += (obj["text"] as? String) ?? ""
            ensurePacer()
        case "thinking_delta":
            guard eventInSession(obj) else { return }
            if (obj["done"] as? Bool) == true { return }
            if thinkStart == nil {
                if let tss = obj["ts"] as? String,
                   let dts = Self.iso.date(from: tss) ?? Self.isoPlain.date(from: tss),
                   msgs.contains(where: { inSession($0) && $0.from == "ai" && $0.kind == "reply" && $0.ts >= dts }) {
                    return
                }
                thinkStart = Date()
                if liveTurnWatermark == 0 { liveTurnWatermark = lastId }
                liveThinkTs = (obj["ts"] as? String).flatMap { Self.iso.date(from: $0) ?? Self.isoPlain.date(from: $0) } ?? Date()
                liveThinkStartId = msgs.last(where: { inSession($0) && $0.from == "human" })?.id ?? 0
                expandedThink.insert(Self.liveThinkId)
            }
            if (obj["snapshot"] as? Bool) == true {
                thinkDraft = (obj["text"] as? String) ?? ""
            } else {
                thinkDraft += (obj["text"] as? String) ?? ""
            }
            typingOn = false
            ensureThinkTimer()
            ensurePacer()
        case "typing":
            let on = (obj["active"] as? Bool) ?? false
            if typingOn != on && draft.isEmpty && thinkDraft.isEmpty {
                typingOn = on
                if on, liveTurnWatermark == 0 { liveTurnWatermark = lastId }
                rebuild(stick: true)
                onTyping?(on)
            }
        case "reaction":
            guard let idn = obj["id"] as? NSNumber else { return }
            let rx = (obj["reactions"] as? [String: Any])?.compactMap { $0.value as? String }.filter { !$0.isEmpty } ?? []
            patch(idn.int64Value) { $0.reactions = rx }
        default:
            break
        }
    }

    private func ensurePacer() {
        guard pacer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let s = self else { return }
            var moved = false
            let db = s.draft.count, tb = s.thinkDraft.count
            if s.draftShown < db { s.draftShown = min(db, s.draftShown + max(1, (db - s.draftShown) / 12)); moved = true }
            if s.thinkShown < tb { s.thinkShown = min(tb, s.thinkShown + max(1, (tb - s.thinkShown) / 12)); moved = true }
            if moved { s.rebuild(stick: true) }
            else if s.draft.isEmpty && s.thinkDraft.isEmpty { s.pacer?.invalidate(); s.pacer = nil }
        }
        t.tolerance = 0.01
        pacer = t
    }
}



final class LXBubbleView: UIView {
    var tailCorner = false { didSet { setNeedsLayout() } }
    var tailLeft = false { didSet { setNeedsLayout() } }
    /// 多行气泡的圆角上限(单行永远是胶囊);头像模式字小了,圆角跟着同比收
    var maxRadius: CGFloat = 18 { didSet { if maxRadius != oldValue { setNeedsLayout() } } }
    private let shapeMask = CAShapeLayer()
    private var softV: LXSoftGlassView?
    /// light:气泡底下是浅色(白天,或浅色壁纸)。玻璃只建一次,换主题只换颜色
    func setGlass(_ on: Bool, light: Bool) {
        guard on else {
            softV?.removeFromSuperview(); softV = nil
            setNeedsLayout()
            return
        }
        let v: LXSoftGlassView
        if let g = softV { v = g } else {
            v = LXSoftGlassView()
            v.isUserInteractionEnabled = false
            v.translatesAutoresizingMaskIntoConstraints = false
            insertSubview(v, at: 0)
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: topAnchor),
                v.bottomAnchor.constraint(equalTo: bottomAnchor),
                v.leadingAnchor.constraint(equalTo: leadingAnchor),
                v.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            softV = v
        }
        v.light = light
        setNeedsLayout()
    }
    private func path(_ b: CGRect, _ rr: CGFloat) -> UIBezierPath {
        let r: CGFloat = rr, br: CGFloat = min(3, rr)
        let p = UIBezierPath()
        p.move(to: CGPoint(x: b.minX + r, y: b.minY))
        p.addLine(to: CGPoint(x: b.maxX - r, y: b.minY))
        p.addArc(withCenter: CGPoint(x: b.maxX - r, y: b.minY + r), radius: r, startAngle: -.pi/2, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - br))
        p.addArc(withCenter: CGPoint(x: b.maxX - br, y: b.maxY - br), radius: br, startAngle: 0, endAngle: .pi/2, clockwise: true)
        p.addLine(to: CGPoint(x: b.minX + r, y: b.maxY))
        p.addArc(withCenter: CGPoint(x: b.minX + r, y: b.maxY - r), radius: r, startAngle: .pi/2, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: b.minX, y: b.minY + r))
        p.addArc(withCenter: CGPoint(x: b.minX + r, y: b.minY + r), radius: r, startAngle: .pi, endAngle: -.pi/2, clockwise: true)
        p.close()
        return p
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let rr = min(maxRadius, bounds.height / 2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let g = softV {
            layer.mask = nil
            layer.cornerRadius = 0
            g.maxRadius = maxRadius; g.tailCorner = tailCorner; g.tailLeft = tailLeft
        } else if tailCorner {
            shapeMask.path = path(bounds, rr).cgPath
            layer.mask = shapeMask
            layer.cornerRadius = 0
        } else {
            layer.mask = nil
            if backgroundColor != nil && backgroundColor != .clear { layer.cornerRadius = rr }
        }
        CATransaction.commit()
    }
}

/// 气泡薄玻璃的数:白天一套、夜里一套,存本机。默认=她 0926 在网页小样里调的(白天最上面那道白后来减到 0.5)
enum LXSoftGlassStore {
    struct Ink { var fill: CGFloat; var top: CGFloat; var rim: CGFloat; var width: CGFloat; var shadow: CGFloat; var blur: CGFloat }
    static let changed = Notification.Name("lx.softGlass.changed")
    /// 糊的滑杆值按 UIBlurEffect(.regular) 整块磨砂约 30 来折成比例;是相对的档,不是真 px
    static let blurFull: CGFloat = 30
    static func defaults(_ light: Bool) -> Ink {
        light ? Ink(fill: 0.07, top: 0.5, rim: 1, width: 1, shadow: 0, blur: 0)
              : Ink(fill: 0.07, top: 0.13, rim: 0.13, width: 0.5, shadow: 0, blur: 0)
    }
    private static func key(_ light: Bool) -> String { light ? "lx.softGlass.day" : "lx.softGlass.night" }
    static func get(_ light: Bool) -> Ink {
        let d = defaults(light)
        guard let m = UserDefaults.standard.dictionary(forKey: key(light)) else { return d }
        func v(_ k: String, _ x: CGFloat) -> CGFloat { (m[k] as? NSNumber).map { CGFloat($0.doubleValue) } ?? x }
        return Ink(fill: v("fill", d.fill), top: v("top", d.top), rim: v("rim", d.rim),
                   width: v("width", d.width), shadow: v("shadow", d.shadow), blur: v("blur", d.blur))
    }
    static func set(_ i: Ink, light: Bool) {
        let m: [String: Double] = ["fill": Double(i.fill), "top": Double(i.top), "rim": Double(i.rim),
                                   "width": Double(i.width), "shadow": Double(i.shadow), "blur": Double(i.blur)]
        UserDefaults.standard.set(m, forKey: key(light))
        NotificationCenter.default.post(name: changed, object: nil)
    }
    static func reset(_ light: Bool) {
        UserDefaults.standard.removeObject(forKey: key(light))
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

/// 气泡的薄玻璃(玻璃拟态):很淡的白底 + 一圈上亮下暗的细边,可选轻糊和阴影;数从 LXSoftGlassStore 取,她在右面板 Bubble glass 里自己调。
/// 亮边从上到下:top → 45% 处 rim×0.2 → 底 浅底黑 rim×0.12 / 深底白 rim×0.08。
/// 糊:系统没有 2-3pt 这么轻的背景模糊,这里让 UIBlurEffect 的动画停在半路取一小段(偏方,苹果不保证);值为 0 就不建这一层
final class LXSoftGlassView: UIView {
    var light = true { didSet { if light != oldValue { applyInk() } } }
    var maxRadius: CGFloat = 18 { didSet { if maxRadius != oldValue { setNeedsLayout() } } }
    var tailCorner = false { didSet { if tailCorner != oldValue { setNeedsLayout() } } }
    var tailLeft = false { didSet { if tailLeft != oldValue { setNeedsLayout() } } }
    private let inkV = UIView()
    private let fill = CAShapeLayer()
    private let rim = CAGradientLayer()
    private let rimMask = CAShapeLayer()
    private var rimW: CGFloat = 1
    private var blurV: UIVisualEffectView?
    private var blurAnim: UIViewPropertyAnimator?
    private var blurFrac: CGFloat = 0
    private let blurMask = LXPathMaskView()
    private var sig = ""

    /// 字是深色=底是浅的
    static func onLight(_ ink: UIColor) -> Bool { var w: CGFloat = 0; ink.getWhite(&w, alpha: nil); return w < 0.5 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        inkV.frame = bounds
        inkV.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inkV.isUserInteractionEnabled = false
        addSubview(inkV)
        inkV.layer.addSublayer(fill)
        rim.startPoint = CGPoint(x: 0.5, y: 0)
        rim.endPoint = CGPoint(x: 0.5, y: 1)
        rim.locations = [0, 0.45, 1]
        rimMask.fillColor = UIColor.clear.cgColor
        rimMask.strokeColor = UIColor.black.cgColor
        rim.mask = rimMask
        inkV.layer.addSublayer(rim)
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 7
        NotificationCenter.default.addObserver(self, selector: #selector(inkChanged), name: LXSoftGlassStore.changed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(backToFront),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        applyInk()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { blurAnim?.stopAnimation(true) }

    @objc private func inkChanged() { applyInk() }
    /// 从后台回来,停在半路的模糊动画可能被系统收尾成整块磨砂;按原来的量重新停一次
    @objc private func backToFront() { if blurFrac > 0 { setBlur(blurFrac, force: true) } }

    private func applyInk() {
        let k = LXSoftGlassStore.get(light)
        rimW = k.width
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.fillColor = UIColor(white: 1, alpha: k.fill).cgColor
        rim.colors = [UIColor(white: 1, alpha: k.top).cgColor,
                      UIColor(white: 1, alpha: k.rim * 0.2).cgColor,
                      (light ? UIColor(white: 0, alpha: k.rim * 0.12) : UIColor(white: 1, alpha: k.rim * 0.08)).cgColor]
        rimMask.lineWidth = k.width
        layer.shadowColor = (light ? UIColor(red: 20 / 255, green: 30 / 255, blue: 40 / 255, alpha: 1) : UIColor.black).cgColor
        layer.shadowOpacity = Float(k.shadow)
        CATransaction.commit()
        blurV?.overrideUserInterfaceStyle = light ? .light : .dark
        setBlur(k.blur / LXSoftGlassStore.blurFull, force: false)
        sig = ""
        setNeedsLayout()
    }

    private func setBlur(_ amount: CGFloat, force: Bool) {
        let f = max(0, min(1, amount))
        guard force || abs(f - blurFrac) > 0.0005 || (f > 0) != (blurV != nil) else { return }
        blurFrac = f
        blurAnim?.stopAnimation(true)
        blurAnim = nil
        guard f > 0 else {
            blurV?.removeFromSuperview()
            blurV = nil
            return
        }
        let v: UIVisualEffectView
        if let b = blurV { v = b } else {
            v = UIVisualEffectView(effect: nil)
            v.frame = bounds
            v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            v.isUserInteractionEnabled = false
            v.mask = blurMask
            insertSubview(v, belowSubview: inkV)
            blurV = v
            sig = ""
        }
        v.overrideUserInterfaceStyle = light ? .light : .dark
        v.effect = nil
        let a = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak v] in v?.effect = UIBlurEffect(style: .regular) }
        a.pausesOnCompletion = true
        a.fractionComplete = f
        blurAnim = a
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds
        let rr = min(maxRadius, b.height / 2)
        let tr = tailCorner ? min(3, rr) : rr
        let s = "\(b.width):\(b.height):\(rr):\(tr):\(tailLeft):\(rimW)"
        guard s != sig else { return }
        sig = s
        let bl = tailLeft ? tr : rr, br = tailLeft ? rr : tr
        let h = rimW / 2
        let shape = Self.path(b, tl: rr, tr: rr, bl: bl, br: br)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = b; rim.frame = b; rimMask.frame = b
        fill.path = shape
        // 细边画在气泡里面:路径往里收半个线宽,外沿正好贴气泡边
        rimMask.path = Self.path(b.insetBy(dx: h, dy: h), tl: max(0, rr - h), tr: max(0, rr - h),
                                 bl: max(0, bl - h), br: max(0, br - h))
        layer.shadowPath = shape
        blurMask.frame = b
        blurMask.shape.path = shape
        CATransaction.commit()
    }

    private static func path(_ r: CGRect, tl: CGFloat, tr: CGFloat, bl: CGFloat, br: CGFloat) -> CGPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - tr, y: r.minY))
        p.addArc(withCenter: CGPoint(x: r.maxX - tr, y: r.minY + tr), radius: tr, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - br))
        p.addArc(withCenter: CGPoint(x: r.maxX - br, y: r.maxY - br), radius: br, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + bl, y: r.maxY))
        p.addArc(withCenter: CGPoint(x: r.minX + bl, y: r.maxY - bl), radius: bl, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + tl))
        p.addArc(withCenter: CGPoint(x: r.minX + tl, y: r.minY + tl), radius: tl, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        p.close()
        return p.cgPath
    }
}

/// 形状遮罩视图:UIVisualEffectView 只认 mask 视图,不认 layer.mask
final class LXPathMaskView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }
    var shape: CAShapeLayer { layer as! CAShapeLayer }
}

/// 右面板 Bubble glass 升起的调节卡:六根滑杆,拖的时候气泡当场变;调的是现在显示的那套(字深=白天那套)
enum LXSoftGlassTuner {
    static func build(into sheet: LXCardSheet, light: Bool) {
        var ink = LXSoftGlassStore.get(light)
        var rows: [(UISlider, UILabel, WritableKeyPath<LXSoftGlassStore.Ink, CGFloat>, (CGFloat) -> String)] = []
        let hint = UILabel()
        hint.text = light ? "Day set · changes show as you drag" : "Night set · changes show as you drag"
        hint.font = LXCardSheet.anthro(13)
        hint.textColor = LXSheetInk.soft
        sheet.content.addArrangedSubview(hint)
        func add(_ name: String, _ kp: WritableKeyPath<LXSoftGlassStore.Ink, CGFloat>, _ lo: Float, _ hi: Float, _ step: Float,
                 _ fmt: @escaping (CGFloat) -> String) {
            let nameL = UILabel()
            nameL.text = name
            nameL.font = LXCardSheet.anthro(15)
            nameL.textColor = LXSheetInk.text
            nameL.widthAnchor.constraint(equalToConstant: 108).isActive = true
            let valL = UILabel()
            valL.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            valL.textColor = LXSheetInk.soft
            valL.textAlignment = .right
            valL.widthAnchor.constraint(equalToConstant: 52).isActive = true
            valL.text = fmt(ink[keyPath: kp])
            let s = UISlider()
            s.minimumValue = lo
            s.maximumValue = hi
            s.value = Float(ink[keyPath: kp])
            s.minimumTrackTintColor = NativeInputPlugin.caretTint
            s.addAction(UIAction { a in
                guard let sl = a.sender as? UISlider else { return }
                let v = CGFloat((sl.value / step).rounded() * step)
                ink[keyPath: kp] = v
                valL.text = fmt(v)
                LXSoftGlassStore.set(ink, light: light)
            }, for: .valueChanged)
            let row = UIStackView(arrangedSubviews: [nameL, s, valL])
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center
            sheet.content.addArrangedSubview(row)
            rows.append((s, valL, kp, fmt))
        }
        let two = { (v: CGFloat) -> String in String(format: "%.2f", Double(v)) }
        add("Fill", \.fill, 0, 0.4, 0.01, two)
        add("Rim", \.rim, 0, 1, 0.01, two)
        add("Top highlight", \.top, 0, 1, 0.01, two)
        add("Rim width", \.width, 0.5, 2, 0.25, { String(format: "%gpt", Double($0)) })
        add("Shadow", \.shadow, 0, 0.6, 0.01, two)
        add("Blur", \.blur, 0, 10, 0.5, { String(format: "%.1f", Double($0)) })
        let reset = UIButton(type: .system)
        reset.setTitle("Reset to default", for: .normal)
        reset.titleLabel?.font = LXCardSheet.anthro(15)
        reset.tintColor = LXSheetInk.soft
        reset.addAction(UIAction { _ in
            LXSoftGlassStore.reset(light)
            ink = LXSoftGlassStore.defaults(light)
            for (s, valL, kp, fmt) in rows {
                s.value = Float(ink[keyPath: kp])
                valL.text = fmt(ink[keyPath: kp])
            }
        }, for: .touchUpInside)
        sheet.content.addArrangedSubview(reset)
    }
}

/// 预览 bubbles 路线专用:白天/半月/月夜各一段,每段上两条是薄玻璃(她调的数),下两条是系统 clear 玻璃;
/// 左边那条在纯色上,右边那条在斜线花纹上。全是样板字,不碰任何真数据。左上一块品红记号:截图脚本认出它才打开看
final class LXBubbleSampler: UIView {
    static let beacon = CGRect(x: 4, y: 70, width: 20, height: 20)
    private var built = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !built, bounds.width > 100 else { return }
        built = true
        let top: CGFloat = 96, bandH = (bounds.height - top) / 3, side: CGFloat = 60, padH: CGFloat = 12.75, h: CGFloat = 31.75
        let bands: [(bg: UInt32, fg: UInt32, dark: Bool)] = [(0xF6FBFF, 0x2A3A4D, false), (0x191917, 0xE9E5DC, true), (0x000000, 0xF5F5F5, true)]
        for (i, b) in bands.enumerated() {
            let fg = Self.hex(b.fg)
            let band = UIView(frame: CGRect(x: 0, y: top + CGFloat(i) * bandH, width: bounds.width, height: bandH))
            band.backgroundColor = Self.hex(b.bg)
            band.clipsToBounds = true
            band.overrideUserInterfaceStyle = b.dark ? .dark : .light
            addSubview(band)
            addLines(to: band, from: bounds.width / 2, color: fg.withAlphaComponent(0.3))
            var y: CGFloat = 20
            for sys in [false, true] {
                for right in [false, true] {
                    let l = UILabel()
                    l.font = .systemFont(ofSize: 14)
                    l.textColor = fg
                    l.text = (sys ? "系统玻璃" : "薄玻璃") + (right ? "·花纹上" : "·纯色上")
                    l.sizeToFit()
                    let w = ceil(l.bounds.width) + 2 * padH
                    let f = CGRect(x: right ? bounds.width - side - w : side, y: y, width: w, height: h)
                    l.frame.origin = CGPoint(x: padH, y: (h - l.bounds.height) / 2)
                    if sys {
                        if #available(iOS 26.0, *) {
                            let e = UIGlassEffect(style: .clear)
                            e.isInteractive = false
                            let g = UIVisualEffectView(effect: e)
                            g.frame = f
                            g.cornerConfiguration = .uniformCorners(radius: .fixed(h / 2))
                            g.contentView.addSubview(l)
                            band.addSubview(g)
                        }
                    } else {
                        let bub = LXBubbleView(frame: f)
                        bub.maxRadius = 16.8
                        bub.tailCorner = right
                        bub.tailLeft = !right
                        bub.addSubview(l)
                        bub.setGlass(true, light: LXSoftGlassView.onLight(fg))
                        band.addSubview(bub)
                    }
                    y += h + 14
                }
            }
        }
        let mark = UIView(frame: Self.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        addSubview(mark)
    }

    private func addLines(to v: UIView, from x0: CGFloat, color: UIColor) {
        let p = UIBezierPath()
        let h = v.bounds.height
        var x = x0 - h
        while x < v.bounds.width {
            p.move(to: CGPoint(x: x, y: h))
            p.addLine(to: CGPoint(x: x + h, y: 0))
            x += 14
        }
        let clip = CAShapeLayer()
        clip.path = UIBezierPath(rect: CGRect(x: x0, y: 0, width: v.bounds.width - x0, height: h)).cgPath
        let s = CAShapeLayer()
        s.path = p.cgPath
        s.strokeColor = color.cgColor
        s.fillColor = nil
        s.lineWidth = 1
        s.mask = clip
        v.layer.addSublayer(s)
    }

    private static func hex(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }
}

enum LXMoonPalette {
    static let order = ["day", "half", "moon"]
    static func next(_ m: String) -> String {
        let i = order.firstIndex(of: m) ?? 2
        return order[(i + 1) % order.count]
    }
    static let chat: [String: [String: Any]] = [
        "day": ["bg": "#f6fbff", "me": "#c8d8e8", "meFg": "#2a3a4d", "aiFg": "#2a3a4d", "faint": "#92a6b8", "fn": "#92a6b8", "fnStar": "#b6d6e8", "think": "#93b2d2", "accent": "#618fbd", "thinkBody": "#769ec6", "accentFg": "#2a3a4d", "hairline": "#7a8c9e", "hairlineA": 0.22, "cardBg": "#fbfdff", "segTrack": "#eff3f6", "menuBg": "#f4f8fb", "fg": "#2a3a4d", "textSoft": "#64798d", "sliderThumb": "#618fbd", "sendBg": "#c8d8e8", "rowPress": "#ecf3f8", "sidePad": 16, "hdrBtnBg": "#fafcfe", "hdrBtnFg": "#2a3a4d", "hdrRing": "#ffffff", "hdrRingA": 0.95, "pillBg": "#fafcfe", "pillFg": "#93b2d2", "statusFs": 12],
        "half": ["bg": "#191917", "me": "#111110", "meFg": "#e9e5dc", "aiFg": "#e9e5dc", "faint": "#6e6b64", "fn": "#a5a198", "fnStar": "#d97757", "think": "#a5a198", "accent": "#da7a55", "thinkBody": "#8b8880", "accentFg": "#191917", "hairline": "#ffffff", "hairlineA": 0.08, "cardBg": "#21211f", "segTrack": "#373735", "menuBg": "#202020", "fg": "#e9e5dc", "textSoft": "#a5a198", "sliderThumb": "#da7a55", "sendBg": "#e9e5dc", "rowPress": "#232525", "sidePad": 16, "hdrBtnBg": "#242422", "hdrBtnFg": "#e9e5dc", "hdrRing": "#e9e5dc", "hdrRingA": 0.18, "pillBg": "#242422", "pillFg": "#a5a198", "statusFs": 12],
        "moon": ["bg": "#000000", "me": "#26252a", "meFg": "#ffffff", "aiFg": "#f5f5f5", "faint": "#717e97", "fn": "#d7eaf8", "fnStar": "#b6d6e8", "think": "#d7eaf8", "accent": "#a9d9ee", "thinkBody": "#b0b0b0", "accentFg": "#05070b", "hairline": "#dfe3ee", "hairlineA": 0.1, "cardBg": "#26252a", "segTrack": "#39383e", "menuBg": "#000000", "fg": "#f5f5f5", "textSoft": "#a5b0c6", "sliderThumb": "#b6d6e8", "sendBg": "#b6d6e8", "rowPress": "#0d0e10", "sidePad": 16, "hdrBtnBg": "#121212", "hdrBtnFg": "#d7eaf8", "hdrRing": "#d6dbea", "hdrRingA": 0.18, "pillBg": "#121212", "pillFg": "#d7eaf8", "statusFs": 12],
    ]
    static let card: [String: [String: Any]] = [
        "day": ["bg": "#fafcfe", "bgAlpha": 0.86, "border": "#ffffff", "borderAlpha": 0.95, "sendBg": "#D7EAF8", "sendFg": "#05070B", "color": "#2A3A4D", "kbDark": false, "phColor": "#92a6b8", "modelFg": "#2a3a4d", "effortFg": "#64798d", "accent": "#618FBD", "quoteBg": "#fafcfe", "quoteBgA": 0.92, "quoteLine": "#9eafbc", "quoteLineA": 0.16, "textSoft": "#64798D", "textFaint": "#92A6B8"],   // 0926 她:白天发送键跟月夜一模一样
        "half": ["bg": "#242422", "bgAlpha": 0.55, "border": "#ffffff", "borderAlpha": 0.1, "sendBg": "#E9E5DC", "sendFg": "#191917", "color": "#E9E5DC", "kbDark": true, "phColor": "#6e6b64", "modelFg": "#e9e5dc", "effortFg": "#a5a198", "accent": "#DA7A55", "quoteBg": "#222220", "quoteBgA": 0.94, "quoteLine": "#ffffff", "quoteLineA": 0.08, "textSoft": "#A5A198", "textFaint": "#6E6B64"],
        "moon": ["bg": "#121212", "bgAlpha": 0.55, "border": "#ffffff", "borderAlpha": 0.1, "sendBg": "#D7EAF8", "sendFg": "#05070B", "color": "#E3E2E7", "kbDark": true, "phColor": "#78859b", "modelFg": "#ffffff", "effortFg": "#78859b", "accent": "#A9D9EE", "quoteBg": "#121212", "quoteBgA": 1, "quoteLine": "#dfe3ee", "quoteLineA": 0.1, "textSoft": "#A5B0C6", "textFaint": "#717E97"],
    ]
    static func persist(_ m: String) {
        guard let c = chat[m] else { return }
        var home = UserDefaults.standard.dictionary(forKey: HomePlugin.themeCacheKey) ?? [:]
        for (k, v) in c { home[k] = v }
        home["moon"] = m
        if (home["flameURL"] as? String ?? "").isEmpty {
            home["flameURL"] = LustreConfig.apiBase.replacingOccurrences(of: "/relay", with: "") + "/chat/home-flame.png?v=2"
        }
        UserDefaults.standard.set(home, forKey: HomePlugin.themeCacheKey)
        guard let cd = card[m] else { return }
        for key in [NativeInputPlugin.cardEnableKey, NativeInputPlugin.cardStateKey] {
            var d = LXFakeCall.load(key)
            if d.isEmpty, key == NativeInputPlugin.cardStateKey { continue }
            for (k, v) in cd { d[k] = v }
            if let data = try? JSONSerialization.data(withJSONObject: d) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

final class LXDefaultWall: UIView {
    private let grad = CAGradientLayer()
    private let noise = CALayer()
    private static let noiseTile: UIImage = {
        let n = 140
        let r = UIGraphicsImageRenderer(size: CGSize(width: n, height: n), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = false; return f
        }())
        return r.image { ctx in
            var g = SystemRandomNumberGenerator()
            for y in 0..<n {
                for x in 0..<n {
                    let v = CGFloat(UInt8.random(in: 0...255, using: &g)) / 255
                    ctx.cgContext.setFillColor(UIColor(white: v, alpha: 0.032).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let hexes: [Int] = [0xF6FBFF, 0xE2F2FF, 0xDEEAF6, 0xD9E7F5]
        var cols: [CGColor] = []
        for h in hexes {
            let r = CGFloat((h >> 16) & 255) / 255
            let g = CGFloat((h >> 8) & 255) / 255
            let b = CGFloat(h & 255) / 255
            cols.append(UIColor(red: r, green: g, blue: b, alpha: 1).cgColor)
        }
        grad.colors = cols
        grad.locations = [0, 0.42, 0.74, 1]
        grad.startPoint = CGPoint(x: 0.5, y: 0)
        grad.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(grad)
        noise.backgroundColor = UIColor(patternImage: Self.noiseTile).cgColor
        layer.addSublayer(noise)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        grad.frame = bounds
        noise.frame = bounds
        CATransaction.commit()
    }
}

enum LXWallStore {
    static var image: UIImage?
    private static var loaded = false
    private static var lastSrc = ""
    private static var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("lx-wall.jpg")
    }
    static func loadDisk() {
        guard !loaded else { return }
        loaded = true
        if let u = fileURL, let d = try? Data(contentsOf: u), let img = UIImage(data: d) { image = img }
    }
    static func set(source: String) {
        if source == lastSrc { return }
        lastSrc = source
        loaded = true
        guard source.hasPrefix("data:"), let comma = source.firstIndex(of: ","),
              let d = Data(base64Encoded: String(source[source.index(after: comma)...])),
              let img = UIImage(data: d) else {
            image = nil
            if let u = fileURL { try? FileManager.default.removeItem(at: u) }
            return
        }
        image = img
        if let u = fileURL { try? d.write(to: u) }
    }
}

final class LXCallPill: UIView {
    static var shared: LXCallPill?
    var onTap: (() -> Void)?
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let film = UIView()
    private let dot = UIView()
    private let label = UILabel()
    private var timer: Timer?
    private var started = Date()
    private init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.14).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        film.translatesAutoresizingMaskIntoConstraints = false
        film.backgroundColor = UIColor(white: 0, alpha: 0.28)
        addSubview(film)
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.backgroundColor = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)
        dot.layer.cornerRadius = 4
        addSubview(dot)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LXDrawerTint.font(13, wght: 500)
        label.textColor = .white
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            blur.topAnchor.constraint(equalTo: topAnchor), blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor), blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            film.topAnchor.constraint(equalTo: topAnchor), film.bottomAnchor.constraint(equalTo: bottomAnchor),
            film.leadingAnchor.constraint(equalTo: leadingAnchor), film.trailingAnchor.constraint(equalTo: trailingAnchor),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1; pulse.toValue = 0.35; pulse.duration = 0.7; pulse.autoreverses = true; pulse.repeatCount = .infinity
        dot.layer.add(pulse, forKey: "pulse")
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onTap?() }
    private func tick() {
        let s = max(0, Int(Date().timeIntervalSince(started)))
        label.text = String(format: "Voice call · %02d:%02d", s / 60, s % 60)
        if let host = superview { reanchor(host: host) }
    }
    private var bottomC: NSLayoutConstraint?
    private weak var anchoredTo: UIView?
    private func reanchor(host: UIView) {
        var target: UIView? = nil
        if let d = LXVoiceDock.shared, d.superview === host, !d.isHidden { target = d }
        else if let c = NativeInputPlugin.live?.card, c.superview === host, !c.isHidden { target = c }
        if anchoredTo === target, bottomC != nil { return }
        bottomC?.isActive = false
        if let t = target { bottomC = bottomAnchor.constraint(equalTo: t.topAnchor, constant: -8) }
        else { bottomC = bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -12) }
        anchoredTo = target
        bottomC?.isActive = true
    }
    static func show(host: UIView, started: Date, onTap: @escaping () -> Void) {
        let v: LXCallPill
        if let s = shared, s.superview === host { v = s }
        else {
            shared?.removeFromSuperview()
            v = LXCallPill()
            host.addSubview(v)
            v.centerXAnchor.constraint(equalTo: host.centerXAnchor).isActive = true
            shared = v
        }
        if let card = NativeInputPlugin.live?.card { v.transform = card.transform }
        v.reanchor(host: host)
        host.bringSubviewToFront(v)
        LXStage.settle(host)
        v.started = started
        v.onTap = onTap
        v.tick()
        v.timer?.invalidate()
        v.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak v] _ in v?.tick() }
        v.alpha = 0
        UIView.animate(withDuration: 0.2) { v.alpha = 1 }
    }
    static func hide() {
        guard let v = shared else { return }
        shared = nil
        v.timer?.invalidate(); v.timer = nil
        UIView.animate(withDuration: 0.18, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }
}

final class LXLatestPill: UIView {
    static var shared: LXLatestPill?
    var onTap: (() -> Void)?
    private let cap = UIView()
    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let film = UIView()
    private let icon = CAShapeLayer()
    private let label = UILabel()
    private init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor(red: 18/255.0, green: 28/255.0, blue: 40/255.0, alpha: 1).cgColor
        layer.shadowOpacity = 0.26
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12
        cap.translatesAutoresizingMaskIntoConstraints = false
        cap.layer.cornerRadius = 14
        cap.layer.cornerCurve = .continuous
        cap.clipsToBounds = true
        addSubview(cap)
        blur.translatesAutoresizingMaskIntoConstraints = false
        cap.addSubview(blur)
        film.translatesAutoresizingMaskIntoConstraints = false
        cap.addSubview(film)
        let iconV = UIView()
        iconV.translatesAutoresizingMaskIntoConstraints = false
        iconV.layer.addSublayer(icon)
        let p = UIBezierPath()
        let k: CGFloat = 15.0 / 24.0
        p.move(to: CGPoint(x: 12 * k, y: 5 * k)); p.addLine(to: CGPoint(x: 12 * k, y: 19 * k))
        p.move(to: CGPoint(x: 6 * k, y: 13 * k)); p.addLine(to: CGPoint(x: 12 * k, y: 19 * k)); p.addLine(to: CGPoint(x: 18 * k, y: 13 * k))
        icon.path = p.cgPath
        icon.fillColor = nil
        icon.lineWidth = 2.4 * k
        icon.lineCap = .round
        icon.lineJoin = .round
        icon.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
        cap.addSubview(iconV)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = LXDrawerTint.font(13, wght: 500)
        cap.addSubview(label)
        NSLayoutConstraint.activate([
            cap.topAnchor.constraint(equalTo: topAnchor), cap.bottomAnchor.constraint(equalTo: bottomAnchor),
            cap.leadingAnchor.constraint(equalTo: leadingAnchor), cap.trailingAnchor.constraint(equalTo: trailingAnchor),
            cap.heightAnchor.constraint(equalToConstant: 28),
            blur.topAnchor.constraint(equalTo: cap.topAnchor), blur.bottomAnchor.constraint(equalTo: cap.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: cap.leadingAnchor), blur.trailingAnchor.constraint(equalTo: cap.trailingAnchor),
            film.topAnchor.constraint(equalTo: cap.topAnchor), film.bottomAnchor.constraint(equalTo: cap.bottomAnchor),
            film.leadingAnchor.constraint(equalTo: cap.leadingAnchor), film.trailingAnchor.constraint(equalTo: cap.trailingAnchor),
            iconV.leadingAnchor.constraint(equalTo: cap.leadingAnchor, constant: 11),
            iconV.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
            iconV.widthAnchor.constraint(equalToConstant: 15),
            iconV.heightAnchor.constraint(equalToConstant: 15),
            label.leadingAnchor.constraint(equalTo: iconV.trailingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: cap.trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: cap.centerYAnchor),
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        retint()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
    }
    @objc private func tapped() { onTap?() }
    private func retint() {
        let fg: UIColor
        switch RPSpec.moonState {
        case "moon":
            film.backgroundColor = UIColor(white: 10/255.0, alpha: 0.94)
            fg = UIColor(red: 0xD6/255.0, green: 0xDB/255.0, blue: 0xEA/255.0, alpha: 1)
            blur.isHidden = true
        case "half":
            film.backgroundColor = UIColor(red: 17/255.0, green: 17/255.0, blue: 16/255.0, alpha: 0.92)
            fg = UIColor(red: 0xE9/255.0, green: 0xE5/255.0, blue: 0xDC/255.0, alpha: 1)
            blur.isHidden = true
        default:
            film.backgroundColor = UIColor(red: 34/255.0, green: 46/255.0, blue: 60/255.0, alpha: 0.52)
            fg = .white
            blur.isHidden = false
        }
        label.textColor = fg
        icon.strokeColor = fg.cgColor
    }
    private var bottomC: NSLayoutConstraint?
    private weak var anchoredTo: UIView?
    private func reanchor(host: UIView) {
        var target: UIView? = nil
        if let c = NativeInputPlugin.live?.card, c.window != nil, c.window === host.window, !c.isHidden { target = c }
        if anchoredTo === target, bottomC != nil { return }
        bottomC?.isActive = false
        if let t = target { bottomC = bottomAnchor.constraint(equalTo: t.topAnchor, constant: -8) }
        else { bottomC = bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -12) }
        anchoredTo = target
        bottomC?.isActive = true
    }
    static func show(host: UIView, fresh: Int, onTap: @escaping () -> Void) {
        let v: LXLatestPill
        if let s = shared, s.superview === host { v = s }
        else {
            shared?.removeFromSuperview()
            v = LXLatestPill()
            host.addSubview(v)
            v.centerXAnchor.constraint(equalTo: host.centerXAnchor).isActive = true
            shared = v
            v.alpha = 0
        }
        v.reanchor(host: host)
        host.bringSubviewToFront(v)
        v.onTap = onTap
        v.retint()
        v.label.text = fresh > 0 ? "新消息" : "回到最新"
        if v.alpha < 1 { UIView.animate(withDuration: 0.2) { v.alpha = 1 } }
    }
    static func hide() {
        guard let v = shared else { return }
        shared = nil
        UIView.animate(withDuration: 0.18, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }
}

final class LXScrimView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    func set(color: UIColor, alphas: [CGFloat], locations: [NSNumber]) {
        guard let g = layer as? CAGradientLayer else { return }
        g.colors = alphas.map { color.withAlphaComponent($0).cgColor }
        g.locations = locations
        g.startPoint = CGPoint(x: 0.5, y: 0)
        g.endPoint = CGPoint(x: 0.5, y: 1)
    }
}

enum LXVoiceCache {
    private static var inflight: Set<String> = []
    private static func dir() -> URL {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("lx-voice", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    private static func local(for url: URL) -> URL {
        let name = url.lastPathComponent.isEmpty ? "v\(url.absoluteString.utf8.count)" : url.lastPathComponent
        return dir().appendingPathComponent(name)
    }
    static func cached(_ url: URL) -> URL? {
        let l = local(for: url)
        return FileManager.default.fileExists(atPath: l.path) ? l : nil
    }
    static func prefetch(_ url: URL) {
        guard url.scheme == "https" || url.scheme == "http" else { return }
        let l = local(for: url)
        guard !FileManager.default.fileExists(atPath: l.path), !inflight.contains(l.path) else { return }
        inflight.insert(l.path)
        URLSession.shared.downloadTask(with: url) { tmp, resp, _ in
            if let tmp = tmp, (resp as? HTTPURLResponse)?.statusCode == 200 {
                try? FileManager.default.removeItem(at: l)
                try? FileManager.default.moveItem(at: tmp, to: l)
            }
            DispatchQueue.main.async { inflight.remove(l.path) }
        }.resume()
    }
}

final class LXTopVeil: UIView {
    private let blur = UIVisualEffectView(effect: nil)
    private let maskV = LXScrimView()
    private let dim = LXScrimView()
    private let bottom: Bool
    init(theme: LXChatTheme, bottom: Bool = false) {
        self.bottom = bottom
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        for v in [blur, dim] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: topAnchor), blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor), blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            dim.topAnchor.constraint(equalTo: topAnchor), dim.bottomAnchor.constraint(equalTo: bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: leadingAnchor), dim.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        blur.mask = maskV
        apply(theme)
    }
    required init?(coder: NSCoder) { fatalError() }
    func apply(_ theme: LXChatTheme) {
        var w: CGFloat = 0
        theme.bg.getWhite(&w, alpha: nil)
        _ = w
        blur.effect = nil
        blur.isHidden = true
        if bottom {
            dim.set(color: theme.bg, alphas: [0, 0.12, 0.38, 0.72, 1], locations: [0, 0.3, 0.58, 0.85, 1])
        } else {
            dim.set(color: theme.bg, alphas: [1, 0.72, 0.38, 0.12, 0], locations: [0, 0.15, 0.42, 0.7, 1])
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        maskV.frame = blur.bounds
    }
}

enum LXAvatarStore {
    static var images: [String: UIImage] = [:]
    static var onChange: (() -> Void)?
    private static var loaded = false
    private static var srcCache: [String: String] = [:]
    private static func fileURL(_ key: String) -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("lx-avatar-\(key).png")
    }
    static func loadDisk() {
        guard !loaded else { return }
        loaded = true
        for k in ["ai", "human", "zhao"] {
            if let u = fileURL(k), let d = try? Data(contentsOf: u), let img = UIImage(data: d) { images[k] = img }
        }
    }
    static func image(_ key: String) -> UIImage? { loadDisk(); return images[key] }
    static var defaultURL: String { LustreConfig.apiBase.replacingOccurrences(of: "/relay", with: "") + "/chat/avatar-sea.png" }
    static func ensureDefaults() {
        loadDisk()
        for k in ["ai", "human", "zhao"] where images[k] == nil { set(k, source: defaultURL) }
    }
    static func set(_ key: String, source: String) {
        if srcCache[key] == source { return }
        srcCache[key] = source
        if source.hasPrefix("data:") {
            if let comma = source.firstIndex(of: ","),
               let d = Data(base64Encoded: String(source[source.index(after: comma)...])),
               let img = UIImage(data: d) { store(key, img) }
        } else if let u = URL(string: source) {
            URLSession.shared.dataTask(with: u) { d, _, _ in
                guard let d = d, let img = UIImage(data: d) else { return }
                DispatchQueue.main.async { store(key, img) }
            }.resume()
        }
    }
    private static func store(_ key: String, _ img: UIImage) {
        images[key] = img
        if let u = fileURL(key), let d = img.pngData() { try? d.write(to: u) }
        onChange?()
    }
}

func lxProbeStack(_ host: UIView?, _ tag: String) {
    guard LustreConfig.isPreview, let h = host else { return }
    let desc = h.subviews.enumerated().map { (i, v) -> String in
        let name = String(describing: type(of: v)).replacingOccurrences(of: "WKWebView", with: "WK")
        return "\(i):\(name)\(v.isHidden ? "藏" : "")a\(String(format: "%.1f", v.alpha))\(v.tag == 7719 ? "残" : "")x\(Int(v.transform.tx))"
    }.joined(separator: " ")
    guard let u = URL(string: LustreConfig.apiBase + "/app/kbdebug") else { return }
    var r = URLRequest(url: u); r.httpMethod = "POST"
    r.setValue("application/json", forHTTPHeaderField: "Content-Type")
    r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
    r.httpBody = try? JSONSerialization.data(withJSONObject: ["tag": "echo-native", "step": "home-stack", "extra": tag + " | " + desc])
    URLSession.shared.dataTask(with: r).resume()
}

/// 头像模式下这一行画不画"头像正下方的时间"(画就画在本行框里,行高给它留位)
enum LXAvaTime { case none, own }

final class LXBubbleCell: UITableViewCell {
    static let reuse = "lxBubble"
    static let reuseGlass = "lxBubbleGlass"
    var isMine = false
    var wasPending = false
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.layer.removeAllAnimations()
        contentView.alpha = 1
        wasPending = false
    }
    let bubble = LXBubbleView()
    let label = UILabel()
    let timeL = UILabel()
    let stackV = UIStackView()
    let attsV = UIStackView()
    let qBlock = UIControl()
    let qBar = UIView()
    let qName = UILabel()
    let qText = UILabel()
    var onQuoteTap: ((Int64) -> Void)?
    private var qId: Int64 = 0
    let reactL = UILabel()
    var onRetry: ((String) -> Void)?
    @objc private func retryTap() {
        guard let m = curMsg, m.failed, !m.cid.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onRetry?(m.cid)
    }
    var curMsg: LXMsg?
    var onLongPress: ((LXMsg, UIView) -> Void)?
    var onAttTap: ((LXAtt) -> Void)?
    var onAvatarTap: ((LXMsg) -> Void)?
    var onAvatarDoubleTap: ((LXMsg) -> Void)?
    @objc private func avatarDoubleTapped() {
        guard let m = curMsg, m.from != "human" else { return }
        onAvatarDoubleTap?(m)
    }
    @objc private func avatarTapped() {
        guard let m = curMsg, m.from != "human" else { return }
        onAvatarTap?(m)
    }
    var ringOn = false
    private let ringLayer = CAShapeLayer()
    private var reactGapC: NSLayoutConstraint!
    private var reactHC: NSLayoutConstraint!
    private var reactLeftC: NSLayoutConstraint!
    private var reactRightC: NSLayoutConstraint!
    private var leftC: NSLayoutConstraint!
    private var rightC: NSLayoutConstraint!
    private var maxWC: NSLayoutConstraint!
    private var bubWC: NSLayoutConstraint!
    static var wCache: [String: CGFloat] = [:]
    private var padT: NSLayoutConstraint!
    private var padB: NSLayoutConstraint!
    private var padL: NSLayoutConstraint!
    private var padR: NSLayoutConstraint!
    private var timeLeftC: NSLayoutConstraint!
    private var timeRightC: NSLayoutConstraint!
    private var timeHC: NSLayoutConstraint!
    private var timeGapC: NSLayoutConstraint!
    private var timeAvaLeftC: NSLayoutConstraint!
    private var timeWC: NSLayoutConstraint!
    private var timeAvaTopC: NSLayoutConstraint!
    private var timeBotC: NSLayoutConstraint!
    private var botReactC: NSLayoutConstraint!
    private var botBubbleC: NSLayoutConstraint!
    /// 0925 她给的参考图(同一台手机 3x 截图量的),她选 A:头像也放到 38,其余全照参考图 1:1——
    /// 贴屏边 12、头像到气泡 10、正文 14、单行气泡 31.75 在头像里上下居中、单行消息一行 55.2、换人说话不额外加空。
    /// 头像形状还是我们的方角;头像下的时间她定 9 号。
    static let avaSize: CGFloat = 38
    static let avaEdge: CGFloat = 12
    static let avaInset: CGFloat = avaEdge + avaSize + 10      // 气泡离屏边 60
    static let avaFontSize: CGFloat = 14
    static let avaLine: CGFloat = 19.9                          // 21.3 × 14/15:行高跟字号同比
    /// 她:气泡里字的上下留白要一样。截图量过(15 号和 11.8 号两种):字墨在行框里本来就居中,
    /// 以前上 4.75 下 6.75 反而把字顶高了约 1pt——所以上下内边距就该相等。
    static let avaPadT: CGFloat = 5.925
    static let avaPadB: CGFloat = 5.925
    static let avaPadH: CGFloat = 12.75                        // 参考图气泡比字宽 27.5 = 2 × 12.75 + 2
    static let avaMaxRadius: CGFloat = 16.8                     // 18 × 14/15
    /// 单行气泡 = 5.925 + 19.9 + 5.925 = 31.75(参考 31.7),在 38 的头像里居中 → 气泡顶比头像顶低 3.1(行顶就是头像顶)
    static let avaLift: CGFloat = 3.1
    /// 头像模式里气泡与气泡之间固定的空(不随气泡高矮变):挂在每行气泡下面 20.35,加下一行的 3.1 = 23.45(参考 23.7)。
    /// 单行一行 = 3.1 + 31.75 + 20.35 = 55.2(参考 55.2),装得下头像 38 + 3 + 时间 11 + 1 = 53,所以时间永远落在本行框里。
    static let avaRowGap: CGFloat = 20.35
    static func bubbleFont(_ av: Bool) -> UIFont { av ? bodyFont(size: avaFontSize) : bodyFont() }
    static func bubbleLine(_ av: Bool) -> CGFloat { av ? avaLine : 21.3 }
    private var reactAvaTopC: NSLayoutConstraint!
    private var topC: NSLayoutConstraint!
    let avatarV = UIImageView()
    private var avaL: NSLayoutConstraint!
    private var avaR: NSLayoutConstraint!
    private var avaBottomC: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        clipsToBounds = false; contentView.clipsToBounds = false
        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerCurve = .circular
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        timeL.translatesAutoresizingMaskIntoConstraints = false
        timeL.font = LXThinkBodyCell.sysFont(10.5)
        stackV.translatesAutoresizingMaskIntoConstraints = false
        stackV.axis = .vertical
        stackV.alignment = .leading
        stackV.spacing = 6
        attsV.axis = .vertical
        attsV.alignment = .leading
        attsV.spacing = 6
        reactL.translatesAutoresizingMaskIntoConstraints = false
        reactL.font = UIFont.systemFont(ofSize: 17)
        reactL.numberOfLines = 0
        reactL.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(retryTap)))
        contentView.addSubview(bubble)
        qBlock.layer.cornerRadius = 8
        qBlock.clipsToBounds = true
        qBar.isUserInteractionEnabled = false
        qName.font = .systemFont(ofSize: 11.5, weight: .semibold)
        qText.font = .systemFont(ofSize: 12.5)
        qText.lineBreakMode = .byTruncatingTail
        [qBar, qName, qText].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; qBlock.addSubview($0) }
        NSLayoutConstraint.activate([
            qBar.leadingAnchor.constraint(equalTo: qBlock.leadingAnchor),
            qBar.topAnchor.constraint(equalTo: qBlock.topAnchor),
            qBar.bottomAnchor.constraint(equalTo: qBlock.bottomAnchor),
            qBar.widthAnchor.constraint(equalToConstant: 2.5),
            qName.topAnchor.constraint(equalTo: qBlock.topAnchor, constant: 6),
            qName.leadingAnchor.constraint(equalTo: qBlock.leadingAnchor, constant: 11),
            qName.trailingAnchor.constraint(lessThanOrEqualTo: qBlock.trailingAnchor, constant: -10),
            qText.topAnchor.constraint(equalTo: qName.bottomAnchor, constant: 2),
            qText.leadingAnchor.constraint(equalTo: qBlock.leadingAnchor, constant: 11),
            qText.trailingAnchor.constraint(equalTo: qBlock.trailingAnchor, constant: -10),
            qText.bottomAnchor.constraint(equalTo: qBlock.bottomAnchor, constant: -6),
        ])
        qBlock.addTarget(self, action: #selector(quoteTapped), for: .touchUpInside)
        stackV.addArrangedSubview(qBlock)
        stackV.setCustomSpacing(7, after: qBlock)
        qBlock.widthAnchor.constraint(equalTo: stackV.widthAnchor).isActive = true
        stackV.addArrangedSubview(attsV)
        stackV.addArrangedSubview(label)
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(labelTapped)))
        bubble.addSubview(stackV)
        contentView.addSubview(timeL)
        contentView.addSubview(reactL)
        avatarV.translatesAutoresizingMaskIntoConstraints = false
        avatarV.contentMode = .scaleAspectFill
        avatarV.clipsToBounds = true
        avatarV.layer.cornerRadius = Self.avaSize * 0.14
        avatarV.layer.cornerCurve = .circular
        avatarV.backgroundColor = UIColor(white: 1, alpha: 0.08)
        avatarV.isHidden = true
        avatarV.isUserInteractionEnabled = true
        let dbl = UITapGestureRecognizer(target: self, action: #selector(avatarDoubleTapped))
        dbl.numberOfTapsRequired = 2
        let one = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        one.require(toFail: dbl)
        avatarV.addGestureRecognizer(dbl)
        avatarV.addGestureRecognizer(one)
        contentView.addSubview(avatarV)
        leftC = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        rightC = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        maxWC = bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72)
        for c0 in [leftC!, rightC!, maxWC!] { c0.priority = UILayoutPriority(999) }
        avaL = avatarV.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.avaEdge)
        avaR = avatarV.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.avaEdge)
        avaL.priority = UILayoutPriority(999); avaR.priority = UILayoutPriority(1)
        avaBottomC = contentView.bottomAnchor.constraint(greaterThanOrEqualTo: avatarV.bottomAnchor, constant: 1)
        avaBottomC.priority = UILayoutPriority(1)
        bubWC = bubble.widthAnchor.constraint(equalToConstant: 0)
        bubWC.priority = UILayoutPriority(998)
        padT = stackV.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 6.83)
        padB = stackV.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -4.67)
        padL = stackV.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 13)
        padR = stackV.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -13)
        label.widthAnchor.constraint(lessThanOrEqualTo: stackV.widthAnchor).isActive = true
        timeLeftC = timeL.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 2)
        timeRightC = timeL.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -2)
        timeLeftC.priority = UILayoutPriority(999); timeRightC.priority = UILayoutPriority(1)
        timeHC = timeL.heightAnchor.constraint(equalToConstant: 10)
        timeGapC = timeL.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 4)
        timeAvaLeftC = timeL.leadingAnchor.constraint(equalTo: avatarV.leadingAnchor)
        timeAvaLeftC.priority = UILayoutPriority(1)
        timeWC = timeL.widthAnchor.constraint(equalToConstant: Self.avaSize)
        timeGapC.priority = UILayoutPriority(999)
        timeAvaTopC = timeL.topAnchor.constraint(equalTo: avatarV.bottomAnchor, constant: 4)
        timeAvaTopC.priority = UILayoutPriority(1)
        topC = bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7)
        timeBotC = contentView.bottomAnchor.constraint(greaterThanOrEqualTo: timeL.bottomAnchor, constant: 1)
        botReactC = contentView.bottomAnchor.constraint(greaterThanOrEqualTo: reactL.bottomAnchor, constant: 1)
        botBubbleC = contentView.bottomAnchor.constraint(greaterThanOrEqualTo: bubble.bottomAnchor, constant: 1)
        reactGapC = reactL.topAnchor.constraint(equalTo: timeL.bottomAnchor, constant: 0)
        reactGapC.priority = UILayoutPriority(999)
        reactAvaTopC = reactL.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 0)
        reactAvaTopC.priority = UILayoutPriority(1)
        reactHC = reactL.heightAnchor.constraint(equalToConstant: 0)
        reactLeftC = reactL.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 2)
        reactRightC = reactL.trailingAnchor.constraint(equalTo: bubble.trailingAnchor)
        reactLeftC.priority = UILayoutPriority(999); reactRightC.priority = UILayoutPriority(1)
        NSLayoutConstraint.activate([
            topC,
            padT, padB, padL, padR,
            timeGapC, timeHC,
            reactGapC, reactHC,
            reactL.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -20),
            leftC, rightC, maxWC,
            timeLeftC, timeRightC, timeAvaLeftC, timeAvaTopC, reactAvaTopC,
            reactLeftC, reactRightC,
            botReactC,
            timeBotC,
            botBubbleC,
            avaL, avaR, avaBottomC,
            avatarV.topAnchor.constraint(equalTo: bubble.topAnchor, constant: -Self.avaLift),
            avatarV.widthAnchor.constraint(equalToConstant: Self.avaSize),
            avatarV.heightAnchor.constraint(equalToConstant: Self.avaSize),
        ])
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(longPress(_:)))
        lp.minimumPressDuration = 0.45
        lp.allowableMovement = 10
        contentView.addGestureRecognizer(lp)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func quoteTapped() { if qId > 0 { onQuoteTap?(qId) } }

    @objc private func longPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let m = curMsg else { return }
        onLongPress?(m, bubble)
    }

    static func bodyFont(size: CGFloat = 15) -> UIFont {
        let base = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: size) ?? UIFont.systemFont(ofSize: size)
        let d = base.fontDescriptor.addingAttributes([
            .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "PingFangSC-Regular"])]
        ])
        return UIFont(descriptor: d, size: size)
    }

    var tailCorner: Bool {
        get { bubble.tailCorner }
        set { bubble.tailCorner = newValue }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if ringOn {
            let rect = bubble.frame.insetBy(dx: -3.25, dy: -3.25)
            ringLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: min(21, rect.height / 2)).cgPath
            ringLayer.lineWidth = 2.5
            ringLayer.fillColor = UIColor.clear.cgColor
            if ringLayer.superlayer == nil { contentView.layer.addSublayer(ringLayer) }
            ringLayer.isHidden = false
        } else {
            ringLayer.isHidden = true
        }
    }
    func setRing(_ on: Bool, color: UIColor) {
        ringOn = on
        ringLayer.strokeColor = color.cgColor
        setNeedsLayout()
    }

    static func styled(_ text: String, base: UIFont, color: UIColor, lineGap: CGFloat) -> NSAttributedString {
        let text = text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        var a: AttributedString
        do {
            a = try AttributedString(markdown: text,
                                     options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        } catch {
            a = AttributedString(text)
        }
        let ns = NSMutableAttributedString(attributedString: NSAttributedString(a))
        let full = NSRange(location: 0, length: ns.length)
        ns.enumerateAttribute(.font, in: full) { v, range, _ in
            var f = base
            if let cur = v as? UIFont {
                let traits = cur.fontDescriptor.symbolicTraits
                if traits.contains(.traitMonoSpace) {
                    f = UIFont.monospacedSystemFont(ofSize: base.pointSize - 2, weight: .regular)
                } else if let d = base.fontDescriptor.withSymbolicTraits(traits) {
                    f = UIFont(descriptor: d, size: base.pointSize)
                }
            }
            ns.addAttribute(.font, value: f, range: range)
        }
        ns.addAttribute(.foregroundColor, value: color, range: full)
        ns.addAttribute(.kern, value: -0.12, range: full)
        let nss = ns.string as NSString
        var i = 0
        while i < nss.length {
            let composed = nss.rangeOfComposedCharacterSequence(at: i)
            let ch = nss.substring(with: composed)
            let cjk = ch.unicodeScalars.contains { sc in
                (0x2E80...0x9FFF).contains(sc.value) || (0x3000...0x303F).contains(sc.value) ||
                (0xF900...0xFAFF).contains(sc.value) || (0xFF00...0xFFEF).contains(sc.value) ||
                (0x20000...0x2FA1F).contains(sc.value)
            }
            if cjk {
                var end = composed.location + composed.length
                while end < nss.length {
                    let nxt = nss.rangeOfComposedCharacterSequence(at: end)
                    let nch = nss.substring(with: nxt)
                    let ncjk = nch.unicodeScalars.contains { sc in
                        (0x2E80...0x9FFF).contains(sc.value) || (0x3000...0x303F).contains(sc.value) ||
                        (0xF900...0xFAFF).contains(sc.value) || (0xFF00...0xFFEF).contains(sc.value) ||
                        (0x20000...0x2FA1F).contains(sc.value)
                    }
                    if !ncjk { break }
                    end = nxt.location + nxt.length
                }
                let runRange = NSRange(location: composed.location, length: end - composed.location)
                let cur = (ns.attribute(.font, at: runRange.location, effectiveRange: nil) as? UIFont) ?? base
                let bold = cur.fontDescriptor.symbolicTraits.contains(.traitBold)
                let pf = UIFont(name: bold ? "PingFangSC-Semibold" : "PingFangSC-Regular", size: cur.pointSize)
                    ?? UIFont.systemFont(ofSize: cur.pointSize, weight: bold ? .semibold : .regular)
                ns.addAttribute(.font, value: pf, range: runRange)
                i = end
            } else {
                i = composed.location + composed.length
            }
        }
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = lineGap
        ps.maximumLineHeight = lineGap
        ps.lineSpacing = 0
        ps.paragraphSpacing = 11 * base.pointSize / 15      // 15 号字段距 11;头像模式字小了同比收
        ns.addAttribute(.paragraphStyle, value: ps, range: full)
        return ns
    }

    /// 0925 她的单:语音消息默认收起不显示转写,长按"转文字"才展开,点文字收回。
    static var voiceOpen = Set<Int64>()
    static func isVoice(_ m: LXMsg) -> Bool { m.atts.contains { $0.kind == "audio" } }
    static func shown(_ m: LXMsg) -> LXMsg {
        guard isVoice(m), !voiceOpen.contains(m.id), !m.text.isEmpty else { return m }
        var c = m; c.text = ""; return c
    }
    var onVoiceTextTap: ((Int64) -> Void)?
    @objc private func labelTapped() {
        guard let m = curMsg, Self.isVoice(m), Self.voiceOpen.contains(m.id) else { return }
        onVoiceTextTap?(m.id)
    }

    var timeShownUnderAvatar: Bool { timeWC.isActive && timeL.attributedText != nil && !timeL.isHidden }
    var timeFrameInCell: CGRect { timeL.convert(timeL.bounds, to: self) }
    func configure(_ m0: LXMsg, showTime showTime0: Bool, tail: Bool, grouped: Bool, afterThink: Bool = false, theme: LXChatTheme, cellW: CGFloat = 0, avaTime: LXAvaTime = .none) {
        let m = Self.shown(m0)
        let mine = m.from == "human"
        curMsg = m0
        let av = theme.avatars
        bubble.maxRadius = av ? Self.avaMaxRadius : 18
        leftC.constant = av ? Self.avaInset : 16
        rightC.constant = av ? -Self.avaInset : -16
        let showAva = av        // 0925 她选:头像模式下每条都带头像,头像下是这条自己的时间
        avatarV.isHidden = !showAva
        avaBottomC.priority = UILayoutPriority(showAva ? 999 : 1)
        avaL.priority = UILayoutPriority(mine ? 1 : 999)
        avaR.priority = UILayoutPriority(mine ? 999 : 1)
        if showAva { refreshAvatar() }
        timeL.textColor = theme.faint.withAlphaComponent(0.85)
        // 0925 她的单(参考图):头像模式下每条都带头像,头像正下方居中是这条自己的时间;时间在本行框里,不伸出去
        var showTime = showTime0
        var timeUnderAva = false
        if av {
            switch avaTime {
            case .none: showTime = false
            case .own: showTime = showAva; timeUnderAva = showAva
            }
        }
        if showTime {
            let ps0 = NSMutableParagraphStyle(); ps0.alignment = timeUnderAva ? .center : (mine ? .right : .left)
            let tsShown = m.ts
            timeL.attributedText = NSAttributedString(string: LXChatData.timeFmt.string(from: tsShown),
                attributes: [.font: UIFont.systemFont(ofSize: timeUnderAva ? 9 : 10),
                             .foregroundColor: theme.faint.withAlphaComponent(0.85), .paragraphStyle: ps0])
        } else { timeL.attributedText = nil }
        timeHC.constant = showTime ? (timeUnderAva ? 11 : 12) : 0
        timeGapC.constant = showTime ? 4 : 0
        timeAvaTopC.constant = showTime ? 3 : 0
        // 0925 她的单:头像模式下气泡之间的空固定(气泡变宽变成两行也不变窄)——空挂在每行气泡(或表情章)下面;
        // 行顶统一是头像顶(气泡再往下 avaLift),换人说话也不多加空(参考图每行一样高)
        botReactC.constant = av ? Self.avaRowGap : 1
        botBubbleC.constant = av ? Self.avaRowGap : 1
        topC.constant = av ? Self.avaLift : (afterThink ? 2 : (grouped ? (mine ? 4 : 0.5) : 7))
        attsV.arrangedSubviews.forEach { $0.removeFromSuperview() }
        attsV.isHidden = m.atts.isEmpty
        label.isHidden = m.text.isEmpty
        if let qt = m.quoteText {
            qBlock.isHidden = false
            qId = m.quoteId
            // 0925:引用条的名字读备注(原来引用他时写死 "Lustre")
            let qRaw = (m.quoteName == "TA") ? LXNick.of(session: m.session) : (m.quoteName ?? "引用")
            qName.text = qRaw == "__LX_YAN__" ? LXNick.yan : qRaw
            qText.text = qt.isEmpty ? "[图片]" : qt
            // 头像模式正文 14:引用条的字同比收(11.5/12.5 × 14/15),不然引用比正文还大
            qName.font = .systemFont(ofSize: av ? 10.7 : 11.5, weight: .semibold)
            qText.font = .systemFont(ofSize: av ? 11.7 : 12.5)
            qName.textColor = theme.accent
            qText.textColor = theme.aiFg.withAlphaComponent(0.75)
            if mine {
                qBlock.backgroundColor = UIColor(white: 1, alpha: 0.55)
                qBar.backgroundColor = theme.accent
                qText.textColor = UIColor(white: 0.15, alpha: 0.8)
                qName.textColor = UIColor(red: 0.28, green: 0.42, blue: 0.55, alpha: 1)
            } else {
                qBlock.backgroundColor = UIColor(red: 0.47, green: 0.55, blue: 0.65, alpha: 0.10)
                qBar.backgroundColor = theme.accent
            }
        } else {
            qBlock.isHidden = true
            qName.text = nil
            qText.text = nil
            qId = 0
        }
        let fg = mine ? theme.meFg : theme.aiFg
        if !m.atts.isEmpty { buildAtts(m.atts, theme: theme, textColor: fg) }
        let hasRx = !m.reactions.isEmpty
        // 0925:发送失败的乐观气泡,气泡下面这一行改成红字"没发出去 · 点这里重发"(点它重发);发失败的不会有表情章,两者不打架
        let failLine = m.failed && m.id > Int64.max - 5000
        reactL.isHidden = !(hasRx || failLine)
        reactL.isUserInteractionEnabled = failLine
        reactHC.constant = hasRx ? 22 : (failLine ? 18 : 0)
        reactGapC.constant = (hasRx || failLine) ? 4 : 0
        reactAvaTopC.constant = (hasRx || failLine) ? 4 : 0
        if failLine {
            reactL.font = LXThinkBodyCell.sysFont(12)
            reactL.textColor = .systemRed
            reactL.text = "没发出去 · 点这里重发"
            reactL.layer.shadowOpacity = 0
        } else if hasRx {
            reactL.font = UIFont.systemFont(ofSize: 17)
            reactL.textColor = mine ? theme.meFg : theme.aiFg
            reactL.text = m.reactions.joined(separator: " ")
            reactL.layer.shadowColor = UIColor(red: 0.235, green: 0.314, blue: 0.392, alpha: 1).cgColor
            reactL.layer.shadowOpacity = 0.18
            reactL.layer.shadowOffset = CGSize(width: 0, height: 2)
            reactL.layer.shadowRadius = 2
        } else { reactL.text = nil }
        let attOnly = m.text.isEmpty && !m.atts.isEmpty
        isMine = mine
        let pending = m.id > Int64.max - 5000 && !m.atts.isEmpty
        if contentView.alpha != 1 { contentView.alpha = 1 }
        if pending {
            attsV.alpha = 0.45
            wasPending = true
        } else if wasPending {
            wasPending = false
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) { self.attsV.alpha = 1 }
        } else if attsV.alpha != 1 {
            attsV.alpha = 1
        }
        if mine {
            bubble.backgroundColor = .clear
            bubble.setGlass(!attOnly, light: LXSoftGlassView.onLight(theme.meFg))
            bubble.tailLeft = false
            tailCorner = !av && tail && !attOnly && !m.atts.contains { $0.kind == "image" }
            label.attributedText = Self.callIconed(Self.styled(m.text, base: Self.bubbleFont(av), color: theme.meFg, lineGap: Self.bubbleLine(av)), m, color: theme.meFg)
            let p: CGFloat = attOnly ? 0 : (av ? Self.avaPadH : 13)
            padT.constant = attOnly ? 0 : (av ? Self.avaPadT : 5.75); padB.constant = attOnly ? 0 : -(av ? Self.avaPadB : 5.75)
            padL.constant = p; padR.constant = -p
            leftC.priority = UILayoutPriority(1)
            rightC.priority = UILayoutPriority(999)
            maxWC.priority = UILayoutPriority(999)
            timeLeftC.priority = UILayoutPriority(1); timeRightC.priority = UILayoutPriority(999)
            timeL.textAlignment = .right
            reactL.textAlignment = .right
            reactLeftC.priority = UILayoutPriority(1); reactRightC.priority = UILayoutPriority(999)
            if cellW > 10 {
                bubWC.constant = Self.measuredWidth(m, cellW: cellW, attOnly: attOnly,
                                                    maxWOverride: av ? (cellW - 2 * Self.avaInset) : nil, av: av)
                bubWC.isActive = true
                label.preferredMaxLayoutWidth = max(1, bubWC.constant - 2 * p)
            } else { bubWC.isActive = false; label.preferredMaxLayoutWidth = 0 }
            setNeedsLayout()
        } else {
            bubble.backgroundColor = .clear
            let boxed = av && !attOnly
            bubble.setGlass(boxed, light: LXSoftGlassView.onLight(theme.meFg))
            bubble.layer.cornerRadius = 0
            bubble.tailLeft = true
            tailCorner = false
            label.attributedText = Self.callIconed(Self.styled(m.text, base: Self.bubbleFont(boxed), color: theme.aiFg, lineGap: boxed ? Self.avaLine : 26.7), m, color: theme.aiFg)
            timeLeftC.priority = UILayoutPriority(999); timeRightC.priority = UILayoutPriority(1)
            timeL.textAlignment = .left
            reactL.textAlignment = .left
            reactLeftC.priority = UILayoutPriority(999); reactRightC.priority = UILayoutPriority(1)
            leftC.priority = UILayoutPriority(999)
            if boxed {
                let p = Self.avaPadH
                padT.constant = Self.avaPadT; padB.constant = -Self.avaPadB; padL.constant = p; padR.constant = -p
                rightC.priority = UILayoutPriority(1)
                maxWC.priority = UILayoutPriority(999)
                if cellW > 10 {
                    bubWC.constant = Self.measuredWidth(m, cellW: cellW, attOnly: false, maxWOverride: cellW - 2 * Self.avaInset, av: true)
                    bubWC.isActive = true
                    label.preferredMaxLayoutWidth = max(1, bubWC.constant - 2 * p)
                } else { bubWC.isActive = false; label.preferredMaxLayoutWidth = 0 }
                setNeedsLayout()
            } else {
                padT.constant = 5; padB.constant = -6; padL.constant = 2; padR.constant = -2
                label.preferredMaxLayoutWidth = 0
                rightC.priority = UILayoutPriority(999)
                maxWC.priority = UILayoutPriority(1)
                bubWC.isActive = false
            }
        }
        if timeUnderAva {
            timeLeftC.priority = UILayoutPriority(1); timeRightC.priority = UILayoutPriority(1)
            timeAvaLeftC.priority = UILayoutPriority(999)
            timeWC.isActive = true
            timeL.textAlignment = .center
            timeGapC.priority = UILayoutPriority(1)
            timeAvaTopC.priority = UILayoutPriority(999)
            reactGapC.priority = UILayoutPriority(1); reactAvaTopC.priority = UILayoutPriority(999)
        } else {
            timeAvaLeftC.priority = UILayoutPriority(1)
            timeWC.isActive = false
            timeGapC.priority = UILayoutPriority(999); timeAvaTopC.priority = UILayoutPriority(1)
            reactGapC.priority = UILayoutPriority(999); reactAvaTopC.priority = UILayoutPriority(1)
        }
    }

    func refreshAvatar() {
        guard let m = curMsg, !avatarV.isHidden else { return }
        let key = m.from == "human" ? "human" : (m.session.isEmpty ? "zhao" : "ai")
        avatarV.image = LXAvatarStore.image(key)
    }

    static let callIconW: CGFloat = 26
    static func callIconed(_ ns: NSAttributedString, _ m: LXMsg, color: UIColor) -> NSAttributedString {
        guard m.kind == "call" else { return ns }
        let f = bodyFont()
        let cfg = UIImage.SymbolConfiguration(pointSize: f.pointSize - 1, weight: .regular)
        guard let img = UIImage(systemName: "phone", withConfiguration: cfg)?
                .withTintColor(color, renderingMode: .alwaysOriginal) else { return ns }
        let att = NSTextAttachment()
        att.image = img
        att.bounds = CGRect(x: 0, y: (f.capHeight - img.size.height) / 2, width: img.size.width, height: img.size.height)
        let out = NSMutableAttributedString(attachment: att)
        out.append(NSAttributedString(string: "  ", attributes: [.font: f, .foregroundColor: color]))
        out.append(ns)
        return out
    }

    static func measuredWidth(_ m: LXMsg, cellW: CGFloat, attOnly: Bool, maxWOverride: CGFloat? = nil, av: Bool = false) -> CGFloat {
        let maxW = floor(min(cellW * 0.72, maxWOverride ?? cellW))
        if attOnly, m.atts.count == 1, m.atts[0].kind == "image" { return 72 }
        let pad: CGFloat = attOnly ? 0 : (av ? 2 * avaPadH : 26)
        let innerMax = maxW - pad
        var w: CGFloat = (av ? 41 : 44) - pad      // 最窄的气泡(头像模式字 14,按 14/15 同比)
        if !m.text.isEmpty {
            let wk = "\(m.id):\(m.text.hashValue):\(Int(cellW)):\(Int(maxW)):\(av ? 1 : 0)"
            if let hit = wCache[wk] {
                w = max(w, hit)
            } else {
                let att = styled(m.text, base: bubbleFont(av), color: .white, lineGap: bubbleLine(av))
                let r = att.boundingRect(with: CGSize(width: innerMax, height: .greatestFiniteMagnitude),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                let tw = ceil(r.width) + 2
                if wCache.count > 2000 { wCache.removeAll() }
                wCache[wk] = tw
                w = max(w, tw)
            }
            if m.kind == "call" { w += callIconW }
        }
        var imgRun = 0
        for a in m.atts {
            switch a.kind {
            case "image":
                imgRun = min(3, imgRun + 1)
                w = max(w, CGFloat(imgRun) * 72 + CGFloat(imgRun - 1) * 6)
            case "audio":
                imgRun = 0
                w = max(w, 150)
            default:
                imgRun = 0
                w = max(w, innerMax)
            }
        }
        if m.quoteText != nil { w = max(w, innerMax) }
        return min(maxW, w + pad)
    }

    private func buildAtts(_ atts: [LXAtt], theme: LXChatTheme, textColor: UIColor) {
        var imgRow: UIStackView?
        for a in atts {
            if a.kind == "image" {
                if imgRow == nil || imgRow!.arrangedSubviews.count >= 3 {
                    let r = UIStackView(); r.axis = .horizontal; r.spacing = 6
                    attsV.addArrangedSubview(r); imgRow = r
                }
                let iv = LXAttImage(att: a)
                iv.onTap = { [weak self] in self?.onAttTap?(a) }
                imgRow!.addArrangedSubview(iv)
            } else if a.kind == "audio" {
                imgRow = nil
                let vb = LXVoiceBar(att: a, theme: theme, textColor: textColor)
                if let u = a.fullURL { LXVoiceCache.prefetch(u) }
                let mine = curMsg?.from == "human"
                vb.title = mine ? "You · Voice message" : ((curMsg?.session == "yan-main") ? "Lustre · Voice message" : "Zhao · Voice message")
                vb.avatarKey = mine ? "human" : ((curMsg?.session.isEmpty ?? true) ? "zhao" : "ai")
                LXVoiceBar.adopt(vb)
                attsV.addArrangedSubview(vb)
            } else {
                imgRow = nil
                let card = LXFileCard(att: a, theme: theme, textColor: textColor)
                card.onTap = { [weak self] in self?.onAttTap?(a) }
                attsV.addArrangedSubview(card)
            }
        }
    }
}

final class LXDayCell: UITableViewCell {
    static let reuse = "lxDay"
    let capsule = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        capsule.translatesAutoresizingMaskIntoConstraints = false
        capsule.font = UIFont.systemFont(ofSize: 11.5, weight: .medium)
        capsule.textAlignment = .center
        capsule.numberOfLines = 0
        contentView.addSubview(capsule)
        NSLayoutConstraint.activate([
            capsule.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            capsule.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40),
            capsule.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            capsule.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(_ s: String, theme: LXChatTheme) {
        capsule.text = s.split(separator: "\u{1F}", maxSplits: 1).first.map(String.init) ?? s
        // 0925 她的单:这一行现在只给拍一拍用——顶部状态栏文字的颜色,统一字体(英文 Anthropic Sans、中文苹方)
        capsule.font = LXThinkBodyCell.sysFont(11.5)
        capsule.textColor = theme.pillFg
    }
}

final class LXStarFlower: UIView {
    private var color: UIColor = .white
    private var running = false
    private var builtSize: CGSize = .zero
    private var fgToken: NSObjectProtocol?
    private func armForegroundRelight() {
        guard fgToken == nil else { return }
        fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let s = self, s.running else { return }
            s.builtSize = .zero
            s.setNeedsLayout()
        }
    }
    deinit { if let t = fgToken { NotificationCenter.default.removeObserver(t) } }
    func start(color c: UIColor) {
        armForegroundRelight()
        if running, c.isEqual(color), !(layer.sublayers?.isEmpty ?? true) { return }
        color = c; running = true
        builtSize = .zero
        setNeedsLayout()
    }
    func stop() {
        running = false
        builtSize = .zero
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
    private static func tinted(_ color: UIColor, size: CGSize) -> UIImage? {
        guard let base = LXFootCell.starImg else { return nil }
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { _ in
            color.set()
            base.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard running, bounds.width > 4 else { return }
        if bounds.size == builtSize, !(layer.sublayers?.isEmpty ?? true) { return }
        builtSize = bounds.size
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        guard let cg = Self.tinted(color, size: bounds.size)?.cgImage else { return }
        let b = bounds
        let c = CGPoint(x: b.midX, y: b.midY)
        for i in 0..<12 {
            let pl = CALayer()
            pl.frame = b
            pl.contents = cg
            let mask = CAShapeLayer()
            let a0 = CGFloat(i) * .pi/6 - .pi/12 - .pi/2 - 0.06
            let p = UIBezierPath()
            p.move(to: c)
            p.addArc(withCenter: c, radius: b.width, startAngle: a0, endAngle: a0 + .pi/6 + 0.12, clockwise: true)
            p.close()
            mask.path = p.cgPath
            pl.mask = mask
            layer.addSublayer(pl)
            let theta = a0 + .pi/12
            var t = CGAffineTransform(rotationAngle: theta)
            t = t.scaledBy(x: 0.62, y: 1.0)
            t = t.rotated(by: -theta)
            let anim = CAKeyframeAnimation(keyPath: "transform")
            anim.values = [NSValue(caTransform3D: CATransform3DIdentity),
                           NSValue(caTransform3D: CATransform3DMakeAffineTransform(t)),
                           NSValue(caTransform3D: CATransform3DIdentity),
                           NSValue(caTransform3D: CATransform3DIdentity)]
            anim.keyTimes = [0, 0.22, 0.45, 1]
            anim.duration = 0.9
            anim.repeatCount = .infinity
            anim.beginTime = CACurrentMediaTime() + Double(i) * 0.075
            pl.add(anim, forKey: "nod")
        }
        let cap = CALayer()
        cap.frame = b
        cap.contents = cg
        let capMask = CAShapeLayer()
        capMask.path = UIBezierPath(ovalIn: CGRect(x: c.x - 2.5, y: c.y - 2.5, width: 5, height: 5)).cgPath
        cap.mask = capMask
        layer.addSublayer(cap)
    }
}

final class LXThinkHeadCell: UITableViewCell {
    static let reuse = "lxThinkHead"
    let star = UIImageView()
    let flower = LXStarFlower()
    let lab = UILabel()
    private var starLeadC: NSLayoutConstraint!

    static func fourStar(filled: Bool) -> UIImage {
        let S: CGFloat = 13
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { _ in
            let c = CGPoint(x: S / 2, y: S / 2)
            let r: CGFloat = filled ? 3.5 : 3.1
            let d = r * 0.22
            let p = UIBezierPath()
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), controlPoint: CGPoint(x: c.x + d, y: c.y - d))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), controlPoint: CGPoint(x: c.x + d, y: c.y + d))
            p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), controlPoint: CGPoint(x: c.x - d, y: c.y + d))
            p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), controlPoint: CGPoint(x: c.x - d, y: c.y - d))
            p.close()
            UIColor.white.set()
            if filled { p.fill() } else { p.lineWidth = 0.8; p.stroke() }
        }
        return img.withRenderingMode(.alwaysTemplate)
    }
    static let starHollow = fourStar(filled: false)
    static let starSolid = fourStar(filled: true)
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        star.translatesAutoresizingMaskIntoConstraints = false
        star.contentMode = .center
        flower.translatesAutoresizingMaskIntoConstraints = false
        lab.translatesAutoresizingMaskIntoConstraints = false
        lab.font = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 12.5) ?? UIFont.systemFont(ofSize: 12.5)
        contentView.addSubview(star); contentView.addSubview(flower); contentView.addSubview(lab)
        starLeadC = star.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        NSLayoutConstraint.activate([
            starLeadC,
            star.centerYAnchor.constraint(equalTo: lab.centerYAnchor),
            flower.centerXAnchor.constraint(equalTo: star.centerXAnchor),
            flower.centerYAnchor.constraint(equalTo: star.centerYAnchor),
            flower.widthAnchor.constraint(equalToConstant: 15),
            flower.heightAnchor.constraint(equalToConstant: 15),
            lab.leadingAnchor.constraint(equalTo: star.trailingAnchor, constant: 6),
            lab.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 9),
            lab.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(label: String, open: Bool, live: Bool, theme: LXChatTheme) {
        starLeadC.constant = theme.avatars ? LXBubbleCell.avaInset : 16
        lab.text = label
        lab.textColor = theme.think
        star.isHidden = live
        flower.isHidden = !live
        if live { flower.start(color: theme.accent) } else { flower.stop() }
        star.image = open ? Self.starSolid : Self.starHollow
        star.tintColor = open ? theme.accent : theme.think
    }
}

final class LXThinkBodyCell: UITableViewCell {
    static let reuse = "lxThinkBody"
    private let stack = UIStackView()
    private var leadC: NSLayoutConstraint!, trailC: NSLayoutConstraint!
    var sideInset: CGFloat?     // 思考小卡里用:不跟头像模式的气泡边距走
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.clipsToBounds = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        contentView.addSubview(stack)
        leadC = stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18)
        trailC = stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            leadC, trailC,
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    static let stepEmojis = ["💭","🧠","⚙️","🔧","📄","📖","✍️","✏️","🔍","🌐","✦","✧"]

    static func sysFont(_ size: CGFloat) -> UIFont {
        let base = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: size) ?? UIFont.systemFont(ofSize: size)
        let d = base.fontDescriptor.addingAttributes([
            .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "PingFangSC-Regular"])]
        ])
        return UIFont(descriptor: d, size: size)
    }

    static func splitSteps(_ text: String) -> [String] {
        let lines = text.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let tagged = lines.filter { l in stepEmojis.contains(where: { l.hasPrefix($0) }) }.count
        if tagged >= 2 { return lines }
        return text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    static func stripEmoji(_ s: String) -> String {
        var t = s
        var moved = true
        while moved {
            moved = false
            t = t.trimmingCharacters(in: .whitespaces)
            for e in stepEmojis where t.hasPrefix(e) {
                t = String(t.dropFirst(e.count)); moved = true
            }
        }
        t = t.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? s : t
    }

    static func iconName(_ t: String) -> String {
        func m(_ p: String) -> Bool { t.range(of: p, options: [.regularExpression, .caseInsensitive]) != nil }
        if m("^\\s*(💭|🧠)") { return "think" }
        if m("^\\s*⚙️|^\\s*🔧|终端|Bash") { return "bash" }
        if m("^\\s*📄|^\\s*📖|读文件|^Read\\b") { return "read" }
        if m("^\\s*✍️|^\\s*✏️|写文件|改文件|^(Write|Edit)\\b") { return "edit" }
        if m("^\\s*🔍|找工具|搜索|^(Grep|Glob|ToolSearch)\\b") { return "search" }
        if m("^\\s*🌐|网页|^(WebFetch|WebSearch)\\b") { return "web" }
        if m("健康|心率|睡眠|vitals|Health") { return "health" }
        if m("日历|提醒|待办|calendar|reminder") { return "cal" }
        if m("记忆|OmbreBrain|breath|hold|dream") { return "memory" }
        return "think"
    }

    static let thinkClock: UIImage = {
        let S: CGFloat = 15
        let k = S / 24
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.white.cgColor)
            c.setFillColor(UIColor.white.cgColor)
            let arc = UIBezierPath(arcCenter: CGPoint(x: 12 * k, y: 12 * k), radius: 8.1 * k,
                                   startAngle: -.pi / 2, endAngle: .pi, clockwise: true)
            arc.lineWidth = 1.5 * k
            arc.lineCapStyle = .round
            arc.stroke()
            for (x, y) in [(8.90, 4.52), (6.27, 6.27), (4.52, 8.90)] {
                c.fillEllipse(in: CGRect(x: (x - 0.62) * k, y: (y - 0.62) * k,
                                         width: 1.24 * k, height: 1.24 * k))
            }
            let h = UIBezierPath()
            h.move(to: CGPoint(x: 12 * k, y: 7.6 * k))
            h.addLine(to: CGPoint(x: 12 * k, y: 12 * k))
            h.addLine(to: CGPoint(x: 15.1 * k, y: 13.9 * k))
            h.lineWidth = 1.5 * k
            h.lineCapStyle = .round
            h.lineJoinStyle = .round
            h.stroke()
        }
        return img.withRenderingMode(.alwaysTemplate)
    }()


    static func railIcon(_ key: String) -> UIImage {
        if key == "think" { return thinkClock }
        if key == "read" || key == "edit" {
            let name = key == "read" ? "doc.text" : "square.and.pencil"
            return UIImage(systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11.5, weight: .light))
                ?? UIImage()
        }
        let S: CGFloat = key == "checkmark" ? 17 : 15
        let k = S / 24
        let img = UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let c = ctx.cgContext
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
            func stroke(_ p: UIBezierPath, _ w: CGFloat) {
                p.lineWidth = w * k
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                UIColor.white.set()
                p.stroke()
            }
            switch key {
            case "bash":
                let p = UIBezierPath()
                p.move(to: P(5, 8)); p.addLine(to: P(9, 12)); p.addLine(to: P(5, 16))
                stroke(p, 1.7)
                let q = UIBezierPath()
                q.move(to: P(12.5, 16)); q.addLine(to: P(18.5, 16))
                stroke(q, 1.7)
            case "read":
                let l = UIBezierPath()
                l.move(to: P(4, 5.5)); l.addLine(to: P(10, 5.5))
                l.addQuadCurve(to: P(12, 7.5), controlPoint: P(12, 5.5))
                l.addLine(to: P(12, 19))
                l.addQuadCurve(to: P(10, 17), controlPoint: P(12, 17))
                l.addLine(to: P(4, 17)); l.close()
                stroke(l, 1.6)
                let r = UIBezierPath()
                r.move(to: P(20, 5.5)); r.addLine(to: P(14, 5.5))
                r.addQuadCurve(to: P(12, 7.5), controlPoint: P(12, 5.5))
                r.addLine(to: P(12, 19))
                r.addQuadCurve(to: P(14, 17), controlPoint: P(12, 17))
                r.addLine(to: P(20, 17)); r.close()
                stroke(r, 1.6)
            case "edit":
                let p = UIBezierPath()
                p.move(to: P(15.5, 4.5)); p.addLine(to: P(19.5, 8.5)); p.addLine(to: P(8, 20))
                p.addLine(to: P(4, 20)); p.addLine(to: P(4, 16)); p.close()
                stroke(p, 1.7)
            case "search":
                stroke(UIBezierPath(arcCenter: P(11, 11), radius: 6.2 * k, startAngle: 0, endAngle: .pi * 2, clockwise: true), 1.7)
                let h = UIBezierPath(); h.move(to: P(15.6, 15.6)); h.addLine(to: P(20, 20))
                stroke(h, 1.7)
            case "web":
                stroke(UIBezierPath(arcCenter: P(12, 12), radius: 8.4 * k, startAngle: 0, endAngle: .pi * 2, clockwise: true), 1.5)
                let h = UIBezierPath(); h.move(to: P(3.8, 12)); h.addLine(to: P(20.2, 12))
                stroke(h, 1.5)
                let lens = UIBezierPath()
                lens.move(to: P(12, 3.6))
                lens.addCurve(to: P(15.2, 12), controlPoint1: P(14.2, 6.0), controlPoint2: P(15.2, 8.9))
                lens.addCurve(to: P(12, 20.4), controlPoint1: P(15.2, 15.1), controlPoint2: P(14.2, 18.0))
                lens.addCurve(to: P(8.8, 12), controlPoint1: P(9.8, 18.0), controlPoint2: P(8.8, 15.1))
                lens.addCurve(to: P(12, 3.6), controlPoint1: P(8.8, 8.9), controlPoint2: P(9.8, 6.0))
                stroke(lens, 1.5)
            case "cal":
                stroke(UIBezierPath(roundedRect: CGRect(x: 4 * k, y: 5.5 * k, width: 16 * k, height: 14 * k), cornerRadius: 2 * k), 1.6)
                let h = UIBezierPath(); h.move(to: P(4, 10)); h.addLine(to: P(20, 10)); stroke(h, 1.6)
                let v1 = UIBezierPath(); v1.move(to: P(8.5, 3.5)); v1.addLine(to: P(8.5, 7.5)); stroke(v1, 1.6)
                let v2 = UIBezierPath(); v2.move(to: P(15.5, 3.5)); v2.addLine(to: P(15.5, 7.5)); stroke(v2, 1.6)
            case "memory":
                let pts: [(CGFloat, CGFloat)] = [(12, 3.2), (14.1, 8.5), (19.8, 8.9), (15.4, 12.6), (16.8, 18.1), (12, 15.1), (7.2, 18.1), (8.6, 12.6), (4.2, 8.9), (9.9, 8.5)]
                let p = UIBezierPath()
                for (i, pt) in pts.enumerated() {
                    if i == 0 { p.move(to: P(pt.0, pt.1)) } else { p.addLine(to: P(pt.0, pt.1)) }
                }
                p.close()
                UIColor.white.set(); p.fill()
            case "health":
                UIColor(red: 0x30/255.0, green: 0x30/255.0, blue: 0x2E/255.0, alpha: 1).set()
                UIBezierPath(roundedRect: CGRect(x: 1.5 * k, y: 1.5 * k, width: 21 * k, height: 21 * k), cornerRadius: 6 * k).fill()
                let lobe = atan2(CGFloat(-1.8), CGFloat(2.4))
                let hp = UIBezierPath()
                hp.move(to: P(12, 17.2))
                hp.addCurve(to: P(6.6, 10.1), controlPoint1: P(12, 17.2), controlPoint2: P(6.6, 13.8))
                hp.addArc(withCenter: P(9.6, 10.1), radius: 3 * k,
                          startAngle: .pi, endAngle: lobe, clockwise: true)
                hp.addArc(withCenter: P(14.4, 10.1), radius: 3 * k,
                          startAngle: -(CGFloat.pi + lobe), endAngle: 0, clockwise: true)
                hp.addCurve(to: P(12, 17.2), controlPoint1: P(17.4, 13.8), controlPoint2: P(12, 17.2))
                hp.close()
                UIColor(red: 0xF1/255.0, green: 0x1C/255.0, blue: 0x73/255.0, alpha: 1).set()
                hp.fill()
            case "checkmark":
                let p = UIBezierPath()
                p.move(to: P(5, 12.5)); p.addLine(to: P(9.8, 17.3)); p.addLine(to: P(19, 7))
                stroke(p, 1.7)
            default:
                _ = c
            }
        }
        return key == "health" ? img.withRenderingMode(.alwaysOriginal) : img.withRenderingMode(.alwaysTemplate)
    }

    private func stepView(icon: String, text: String, last: Bool, theme: LXChatTheme) -> UIView {
        let row = UIView()
        let ic = UIImageView(image: Self.railIcon(icon))
        ic.translatesAutoresizingMaskIntoConstraints = false
        ic.tintColor = theme.think
        ic.contentMode = .center
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        let ns = NSMutableAttributedString(string: text)
        let full = NSRange(location: 0, length: ns.length)
        ns.addAttribute(.font, value: LXThinkBodyCell.sysFont(12.5), range: full)
        ns.addAttribute(.foregroundColor, value: theme.thinkBody, range: full)
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 3.5
        ns.addAttribute(.paragraphStyle, value: ps, range: full)
        tv.attributedText = ns
        row.addSubview(ic); row.addSubview(tv)
        var cons: [NSLayoutConstraint] = [
            ic.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            ic.topAnchor.constraint(equalTo: row.topAnchor, constant: -2),

            ic.widthAnchor.constraint(equalToConstant: 22),
            ic.heightAnchor.constraint(equalToConstant: 22),
            tv.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 32),
            tv.topAnchor.constraint(equalTo: row.topAnchor, constant: 1),
            tv.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: last ? -2 : -16),
        ]
        if !last {
            let line = UIView()
            line.translatesAutoresizingMaskIntoConstraints = false
            line.backgroundColor = theme.faint.withAlphaComponent(0.3)
            row.addSubview(line)
            cons += [
                line.centerXAnchor.constraint(equalTo: ic.centerXAnchor),
                line.topAnchor.constraint(equalTo: ic.bottomAnchor, constant: 3),
                line.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -3),
                line.widthAnchor.constraint(equalToConstant: 1),
            ]
        }
        NSLayoutConstraint.activate(cons)
        return row
    }

    private var lastSteps: [String] = []
    private var lastLive = false
    func configure(_ text: String, live: Bool, theme: LXChatTheme) {
        leadC.constant = sideInset ?? (theme.avatars ? LXBubbleCell.avaInset : 18)
        trailC.constant = -(sideInset ?? (theme.avatars ? LXBubbleCell.avaInset : 18))
        let steps = Self.splitSteps(text)
        var keep = 0
        if live, lastLive, !lastSteps.isEmpty,
           stack.arrangedSubviews.count == lastSteps.count,
           steps.count >= lastSteps.count,
           steps.prefix(lastSteps.count - 1).elementsEqual(lastSteps.prefix(lastSteps.count - 1)) {
            keep = lastSteps.count - 1
        }
        while stack.arrangedSubviews.count > keep { stack.arrangedSubviews.last?.removeFromSuperview() }
        for (i, s) in steps.enumerated() where i >= keep {
            let isLast = live && i == steps.count - 1
            let v = stepView(icon: Self.iconName(s), text: Self.stripEmoji(s), last: isLast, theme: theme)
            stack.addArrangedSubview(v)
            if live && !lastSteps.isEmpty && i >= lastSteps.count {
                v.alpha = 0.45
                v.transform = CGAffineTransform(translationX: 0, y: -6)
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                    v.alpha = 1; v.transform = .identity
                }
            }
        }
        if !live {
            stack.addArrangedSubview(stepView(icon: "checkmark", text: "Done", last: true, theme: theme))
        }
        lastSteps = steps; lastLive = live
    }
}

final class LXApproveCell: UITableViewCell {
    static let reuse = "lxApprove"
    private let card = UIView()
    private let badge = UILabel()
    private let cat = UILabel()
    private let raw = UILabel()
    private let okB = UIButton(type: .system)
    private let noB = UIButton(type: .system)
    private let doneL = UILabel()
    private let btns = UIStackView()
    private var line = "zhao"
    private var winIdx = 0
    private var msgTs: Double = 0
    private var loadedFor: Int64 = -1

    private static let cats: [(String, String)] = [
        ("bash", "执行命令"), ("edit", "修改文件"), ("write", "修改文件"), ("read", "读取文件"),
        ("webfetch", "访问网络"), ("websearch", "访问网络"), ("fetch", "访问网络"),
        ("mcp__", "调用外部服务"), ("permission", "一步操作"), ("授权", "一步操作"),
    ]

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(red: 0x16/255.0, green: 0x18/255.0, blue: 0x1C/255.0, alpha: 1)
        card.layer.cornerRadius = 14
        card.clipsToBounds = true
        contentView.addSubview(card)

        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = "🔒"
        badge.font = .systemFont(ofSize: 15)
        badge.textAlignment = .center
        badge.backgroundColor = UIColor(red: 182/255.0, green: 214/255.0, blue: 232/255.0, alpha: 0.12)
        badge.layer.cornerRadius = 17
        badge.clipsToBounds = true

        cat.translatesAutoresizingMaskIntoConstraints = false
        cat.numberOfLines = 1
        raw.translatesAutoresizingMaskIntoConstraints = false
        raw.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        raw.textColor = UIColor(red: 0x6E/255.0, green: 0x76/255.0, blue: 0x81/255.0, alpha: 1)
        raw.numberOfLines = 1
        raw.lineBreakMode = .byTruncatingTail

        let copy = UIStackView(arrangedSubviews: [cat, raw])
        copy.axis = .vertical
        copy.spacing = 1
        copy.translatesAutoresizingMaskIntoConstraints = false

        for (b, t) in [(okB, "通过"), (noB, "拒绝")] {
            b.setTitle(t, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
            b.layer.cornerRadius = 15
            b.clipsToBounds = true
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
            b.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }
        okB.backgroundColor = UIColor(red: 182/255.0, green: 214/255.0, blue: 232/255.0, alpha: 1)
        okB.setTitleColor(UIColor(red: 0x05/255.0, green: 0x07/255.0, blue: 0x0B/255.0, alpha: 1), for: .normal)
        noB.backgroundColor = UIColor(white: 1, alpha: 0.08)
        noB.setTitleColor(UIColor(white: 0.69, alpha: 1), for: .normal)
        okB.addTarget(self, action: #selector(tapOK), for: .touchUpInside)
        noB.addTarget(self, action: #selector(tapNO), for: .touchUpInside)
        btns.axis = .horizontal
        btns.spacing = 7
        btns.translatesAutoresizingMaskIntoConstraints = false
        btns.addArrangedSubview(okB); btns.addArrangedSubview(noB)

        doneL.translatesAutoresizingMaskIntoConstraints = false
        doneL.font = .systemFont(ofSize: 12.5)
        doneL.textColor = UIColor(red: 0x78/255.0, green: 0x85/255.0, blue: 0x9B/255.0, alpha: 1)
        doneL.textAlignment = .center
        doneL.isHidden = true

        card.addSubview(badge); card.addSubview(copy); card.addSubview(btns); card.addSubview(doneL)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            card.heightAnchor.constraint(equalToConstant: 68),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            badge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 34),
            badge.heightAnchor.constraint(equalToConstant: 34),
            copy.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),
            copy.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            copy.trailingAnchor.constraint(lessThanOrEqualTo: btns.leadingAnchor, constant: -10),
            btns.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            btns.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            doneL.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            doneL.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private static func termURL(_ path: String) -> URL? {
        URL(string: LustreConfig.origin + "/term/api/" + path
            + (path.contains("?") ? "&" : "?") + "auth=" + LustreConfig.secret)
    }

    private static func doneKey(_ id: Int64) -> String { "lustre.approve.\(id)" }

    func configure(_ m: LXMsg, theme: LXChatTheme) {
        line = m.approveLine ?? "zhao"
        let who = line == "yan" ? LXNick.yan : LXNick.zhao
        guard loadedFor != m.id else { return }
        loadedFor = m.id
        msgTs = m.ts.timeIntervalSince1970
        doneL.isHidden = true; btns.isHidden = false
        badge.isHidden = false; cat.isHidden = false; raw.isHidden = false
        if let t = UserDefaults.standard.string(forKey: Self.doneKey(m.id)) { finish(t); return }
        cat.attributedText = NSAttributedString(string: "加载中…", attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: UIColor(white: 0.93, alpha: 1)])
        raw.text = ""
        guard let u = Self.termURL("pending?line=" + line) else { return }
        URLSession.shared.dataTask(with: u) { [weak self] data, _, _ in
            let d = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            let msg = (d?["msg"] as? String) ?? "需要授权"
            let win = (d?["window"] as? NSNumber)?.intValue ?? 0
            let ts = (d?["ts"] as? NSNumber)?.doubleValue ?? 0
            DispatchQueue.main.async {
                guard let s = self else { return }
                s.winIdx = win
                s.raw.text = msg
                if ts > 0, s.msgTs > 0, abs(ts - s.msgTs) > 120 {
                    s.setCat("已处理", who: nil)
                    s.raw.text = ""
                    s.btns.isHidden = true
                    return
                }
                if ts > 0, Date().timeIntervalSince1970 - ts > 600 {
                    s.setCat("这张授权已过期（终端里处理过了）", who: nil)
                    s.btns.isHidden = true
                    return
                }
                var label = "一步操作"
                let low = msg.lowercased()
                for (k, v) in Self.cats where low.contains(k) { label = v; break }
                s.setCat(label, who: who)
            }
        }.resume()
    }

    private func setCat(_ label: String, who: String?) {
        let a = NSMutableAttributedString(string: label, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: UIColor(white: 0.93, alpha: 1)])
        if let w = who {
            a.append(NSAttributedString(string: " · \(w)在等", attributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor(red: 0x78/255.0, green: 0x85/255.0, blue: 0x9B/255.0, alpha: 1)]))
        }
        cat.attributedText = a
    }

    @objc private func tapOK() { send("Enter", "✓ 已通过") }
    @objc private func tapNO() { send("Escape", "✕ 已拒绝") }
    private func send(_ key: String, _ okText: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let u = Self.termURL("key"),
              let body = try? JSONSerialization.data(withJSONObject: ["window": winIdx, "key": key]) else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = body
        finish("发送中…")
        URLSession.shared.dataTask(with: r) { [weak self] _, resp, err in
            let ok = err == nil && ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200
            DispatchQueue.main.async {
                guard let s = self else { return }
                if ok, s.loadedFor > 0 { UserDefaults.standard.set(okText, forKey: Self.doneKey(s.loadedFor)) }
                s.finish(ok ? okText : "发送失败，喊" + LXNick.zhao)
            }
        }.resume()
    }
    private func finish(_ t: String) {
        badge.isHidden = true; cat.isHidden = true; raw.isHidden = true; btns.isHidden = true
        doneL.isHidden = false
        doneL.text = t
    }
}

final class LXFootCell: UITableViewCell {
    static let reuse = "lxFoot"
    let star = UIImageView()
    let lab = UILabel()
    static let starImg: UIImage? = {
        guard let p = Bundle.main.path(forResource: "footstar", ofType: "png"),
              let img = UIImage(contentsOfFile: p) else { return nil }
        return img.withRenderingMode(.alwaysTemplate)
    }()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        star.translatesAutoresizingMaskIntoConstraints = false
        star.image = Self.starImg
        star.contentMode = .scaleAspectFit
        lab.translatesAutoresizingMaskIntoConstraints = false
        lab.numberOfLines = 2
        lab.textAlignment = .right
        contentView.addSubview(star); contentView.addSubview(lab)
        NSLayoutConstraint.activate([
            star.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            star.centerYAnchor.constraint(equalTo: lab.centerYAnchor),
            star.widthAnchor.constraint(equalToConstant: 26),
            star.heightAnchor.constraint(equalToConstant: 26),
            lab.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            lab.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            lab.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            lab.leadingAnchor.constraint(greaterThanOrEqualTo: star.trailingAnchor, constant: 12),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(theme: LXChatTheme) {
        star.tintColor = theme.fnStar
        let f = UIFont(name: "AnthropicSansWebVariable-TextRegular", size: 11.4) ?? UIFont.systemFont(ofSize: 11.4)
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = 13.3; ps.maximumLineHeight = 13.3
        ps.alignment = .right
        lab.attributedText = NSAttributedString(
            string: "\(LXNick.of(session: ChatListPlugin.live?.data.session ?? "")) is AI and can make mistakes.\nPlease spare him the guesses.",
            attributes: [.font: f, .foregroundColor: theme.fn, .paragraphStyle: ps])
    }
}

final class LXTypingCell: UITableViewCell {
    static let reuse = "lxTyping"
    let dots = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        dots.translatesAutoresizingMaskIntoConstraints = false
        dots.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        dots.text = "· · ·"
        contentView.addSubview(dots)
        NSLayoutConstraint.activate([
            dots.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            dots.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            dots.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(theme: LXChatTheme) {
        dots.textColor = theme.faint
        dots.alpha = 0.5
        UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            self.dots.alpha = 1
        }
    }
}

final class LXHeaderBar: UIView {
    let menuBtn = UIButton(type: .system)
    let pill = UIButton(type: .system)
    let moreBtn = UIButton(type: .system)
    let statusL = UILabel()
    let pillGroup = UIStackView()
    let dotsV = UIView()
    private var dotLayers: [CALayer] = []
    var onTap: ((String) -> Void)?

    private var dotColor = UIColor.white
    private var fgToken: NSObjectProtocol?
    private func armForegroundRelight() {
        guard fgToken == nil else { return }
        fgToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.ensureBounce()
        }
    }
    deinit { if let t = fgToken { NotificationCenter.default.removeObserver(t) } }

    private func bounceAnim(_ i: Int) -> CAAnimation {
        let ty = CAKeyframeAnimation(keyPath: "transform.translation.y")
        ty.values = [0, -3, 0, 0]
        ty.keyTimes = [0, 0.35, 0.7, 1]
        let op = CAKeyframeAnimation(keyPath: "opacity")
        op.values = [0.4, 1, 0.4, 0.4]
        op.keyTimes = [0, 0.35, 0.7, 1]
        let grp = CAAnimationGroup()
        grp.animations = [ty, op]
        grp.duration = 1.25
        grp.repeatCount = .infinity
        grp.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        grp.beginTime = CACurrentMediaTime() + Double(i) * 0.16
        return grp
    }

    private func ensureBounce() {
        guard !dotsV.isHidden else { return }
        for (i, d) in dotLayers.enumerated() where d.animation(forKey: "bounce") == nil {
            d.add(bounceAnim(i), forKey: "bounce")
        }
    }

    func setTyping(_ on: Bool, color: UIColor) {
        armForegroundRelight()
        dotColor = color
        dotsV.isHidden = !on
        if on && dotLayers.isEmpty {
            for i in 0..<3 {
                let d = CALayer()
                d.frame = CGRect(x: CGFloat(i) * 7, y: 5, width: 4, height: 4)
                d.cornerRadius = 2
                dotsV.layer.addSublayer(d)
                dotLayers.append(d)
                d.add(bounceAnim(i), forKey: "bounce")
            }
        }
        if on { ensureBounce() }
        for d in dotLayers { d.backgroundColor = color.cgColor }
    }

    static func hamburger() -> UIImage {
        let S: CGFloat = 18
        return UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(1.5)
            c.setLineCap(.round)
            for y in [5.25, 9.0, 12.75] {
                c.move(to: CGPoint(x: 1.5, y: y))
                c.addLine(to: CGPoint(x: 16.5, y: y))
            }
            c.strokePath()
        }.withRenderingMode(.alwaysTemplate)
    }
    static func dots() -> UIImage {
        let S: CGFloat = 18
        return UIGraphicsImageRenderer(size: CGSize(width: S, height: S)).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor)
            for y in [3.75, 9.0, 14.25] {
                c.fillEllipse(in: CGRect(x: 9 - 1.5, y: y - 1.5, width: 3, height: 3))
            }
        }.withRenderingMode(.alwaysTemplate)
    }

    init(theme: LXChatTheme) {
        super.init(frame: .zero)
        let bs = theme.hdrBtnSize, ph = theme.pillH
        for b in [menuBtn, moreBtn] {
            b.translatesAutoresizingMaskIntoConstraints = false
            b.layer.cornerRadius = bs / 2
        }
        menuBtn.setImage(Self.hamburger(), for: .normal)
        moreBtn.setImage(Self.dots(), for: .normal)
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.layer.cornerRadius = ph / 2
        statusL.translatesAutoresizingMaskIntoConstraints = false
        statusL.textAlignment = .center
        statusL.lineBreakMode = .byTruncatingTail
        statusL.setContentHuggingPriority(.required, for: .horizontal)
        dotsV.translatesAutoresizingMaskIntoConstraints = false
        dotsV.isUserInteractionEnabled = false
        dotsV.isHidden = true
        pillGroup.translatesAutoresizingMaskIntoConstraints = false
        pillGroup.axis = .horizontal
        pillGroup.alignment = .center
        pillGroup.spacing = 6
        pillGroup.isUserInteractionEnabled = false
        pillGroup.addArrangedSubview(statusL)
        pillGroup.addArrangedSubview(dotsV)
        pill.addSubview(pillGroup)
        addSubview(menuBtn); addSubview(pill); addSubview(moreBtn)
        menuBtn.addAction(UIAction { [weak self] _ in self?.onTap?("menu") }, for: .touchUpInside)
        pill.addAction(UIAction { [weak self] _ in self?.onTap?("status") }, for: .touchUpInside)
        moreBtn.addAction(UIAction { [weak self] _ in self?.onTap?("more") }, for: .touchUpInside)
        NSLayoutConstraint.activate([
            menuBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            menuBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            menuBtn.widthAnchor.constraint(equalToConstant: bs),
            menuBtn.heightAnchor.constraint(equalToConstant: bs),
            moreBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            moreBtn.centerYAnchor.constraint(equalTo: menuBtn.centerYAnchor),
            moreBtn.widthAnchor.constraint(equalToConstant: bs),
            moreBtn.heightAnchor.constraint(equalToConstant: bs),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: menuBtn.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: ph),
            pill.widthAnchor.constraint(greaterThanOrEqualToConstant: 110),
            pill.leadingAnchor.constraint(greaterThanOrEqualTo: menuBtn.trailingAnchor, constant: 8),
            pill.trailingAnchor.constraint(lessThanOrEqualTo: moreBtn.leadingAnchor, constant: -8),
            pillGroup.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            pillGroup.centerYAnchor.constraint(equalTo: pill.centerYAnchor, constant: 0.2),
            dotsV.widthAnchor.constraint(equalToConstant: 18),
            dotsV.heightAnchor.constraint(equalToConstant: 14),
        ])
        let hug = pill.trailingAnchor.constraint(equalTo: pillGroup.trailingAnchor, constant: 16)
        hug.priority = UILayoutPriority(999)
        hug.isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    private var glassed = false
    private func glassify(_ v: UIView, corner: CGFloat) -> Bool {
        if #available(iOS 26.0, *) {
            let g = UIVisualEffectView(effect: UIGlassEffect())
            g.translatesAutoresizingMaskIntoConstraints = false
            g.layer.cornerRadius = corner
            g.clipsToBounds = true
            g.isUserInteractionEnabled = false
            insertSubview(g, belowSubview: v)
            NSLayoutConstraint.activate([
                g.topAnchor.constraint(equalTo: v.topAnchor),
                g.bottomAnchor.constraint(equalTo: v.bottomAnchor),
                g.leadingAnchor.constraint(equalTo: v.leadingAnchor),
                g.trailingAnchor.constraint(equalTo: v.trailingAnchor),
            ])
            return true
        }
        return false
    }

    func apply(_ t: LXChatTheme) {
        if !glassed {
            let ok1 = glassify(menuBtn, corner: menuBtn.layer.cornerRadius)
            let ok2 = glassify(moreBtn, corner: moreBtn.layer.cornerRadius)
            let ok3 = glassify(pill, corner: pill.layer.cornerRadius)
            glassed = ok1 && ok2 && ok3
        }
        for b in [menuBtn, moreBtn] {
            b.backgroundColor = glassed ? .clear : t.hdrBtnBg
            b.tintColor = t.hdrBtnFg
            b.layer.borderWidth = glassed ? 0 : 1
            b.layer.borderColor = t.hdrRing.cgColor
        }
        pill.backgroundColor = glassed ? .clear : t.pillBg
        pill.layer.borderWidth = glassed ? 0 : 1
        pill.layer.borderColor = t.hdrRing.cgColor
        statusL.textColor = t.pillFg
        statusL.font = LXThinkBodyCell.sysFont(t.statusFs)
    }
}

final class LXStickyTable: UITableView {
    var stickBottom = true
    private var pinning = false
    var bottomY: CGFloat { -adjustedContentInset.top }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard stickBottom, !pinning, !isTracking, !isDragging, !isDecelerating else { return }
        let y = bottomY
        if abs(contentOffset.y - y) > 0.5 {
            pinning = true
            setContentOffset(CGPoint(x: 0, y: y), animated: false)
            pinning = false
        }
    }
}

final class LXChatContainer: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if point.x > bounds.width - 24 { return nil }
        return super.hitTest(point, with: event)
    }
}


final class LXAttImage: UIControl {
    static let cache = NSCache<NSString, UIImage>()
    private let iv = UIImageView()
    private var boundURL = ""
    var onTap: (() -> Void)?
    init(att: LXAtt) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(red: 125/255.0, green: 128/255.0, blue: 135/255.0, alpha: 0.10)
        layer.cornerRadius = 12
        clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 14
        iv.clipsToBounds = true
        iv.isUserInteractionEnabled = false
        addSubview(iv)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 72),
            heightAnchor.constraint(equalToConstant: 72),
            iv.topAnchor.constraint(equalTo: topAnchor), iv.bottomAnchor.constraint(equalTo: bottomAnchor),
            iv.leadingAnchor.constraint(equalTo: leadingAnchor), iv.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        load(att)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onTap?() }
    private func load(_ att: LXAtt) {
        guard let u = att.fullURL else { return }
        boundURL = u.absoluteString
        if let hit = Self.cache.object(forKey: u.absoluteString as NSString) { iv.image = hit; return }
        let want = boundURL
        Task { [weak self] in
            guard let (data, resp) = try? await URLSession.shared.data(from: u),
                  (resp as? HTTPURLResponse)?.statusCode == 200,
                  let raw = UIImage(data: data) else { return }
            let side: CGFloat = 144
            let scale = max(side / max(1, raw.size.width), side / max(1, raw.size.height))
            let sz = CGSize(width: raw.size.width * scale, height: raw.size.height * scale)
            let img = UIGraphicsImageRenderer(size: sz).image { _ in raw.draw(in: CGRect(origin: .zero, size: sz)) }
            Self.cache.setObject(img, forKey: u.absoluteString as NSString)
            await MainActor.run {
                guard let s = self, s.boundURL == want else { return }
                s.iv.image = img
            }
        }
    }
}

final class LXVoiceBar: UIControl {
    static var player: AVPlayer?
    static weak var playing: LXVoiceBar?
    private static let waveH: [CGFloat] = [5, 9, 13, 8, 11, 15, 10, 6, 12, 9, 14, 7, 10, 13, 8, 11]
    private let att: LXAtt
    private let playIcon = CAShapeLayer()
    private let pauseIcon = CAShapeLayer()
    private var bars: [UIView] = []
    private let timeL = UILabel()
    var title = "语音"
    var avatarKey = "ai"
    private let accent: UIColor
    private let barColor: UIColor
    static var timeObs: Any?
    init(att: LXAtt, theme: LXChatTheme, textColor: UIColor) {
        self.att = att
        self.accent = theme.accent
        self.barColor = textColor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = theme.accent
        circle.layer.cornerRadius = 14
        circle.isUserInteractionEnabled = false
        addSubview(circle)
        let s: CGFloat = 15.0 / 24.0
        let tri = UIBezierPath()
        tri.move(to: CGPoint(x: 8 * s, y: 5.5 * s)); tri.addLine(to: CGPoint(x: 8 * s, y: 18.5 * s))
        tri.addLine(to: CGPoint(x: 19 * s, y: 12 * s)); tri.close()
        playIcon.path = tri.cgPath
        playIcon.fillColor = theme.accentFg.cgColor
        playIcon.frame = CGRect(x: 6.5, y: 6.5, width: 15, height: 15)
        circle.layer.addSublayer(playIcon)
        let pp = UIBezierPath(roundedRect: CGRect(x: 6.5 * s, y: 5 * s, width: 4 * s, height: 14 * s), cornerRadius: 1.2 * s)
        pp.append(UIBezierPath(roundedRect: CGRect(x: 13.5 * s, y: 5 * s, width: 4 * s, height: 14 * s), cornerRadius: 1.2 * s))
        pauseIcon.path = pp.cgPath
        pauseIcon.fillColor = theme.accentFg.cgColor
        pauseIcon.frame = playIcon.frame
        pauseIcon.isHidden = true
        circle.layer.addSublayer(pauseIcon)
        let wave = UIStackView()
        wave.translatesAutoresizingMaskIntoConstraints = false
        wave.axis = .horizontal
        wave.spacing = 2
        wave.alignment = .center
        wave.isUserInteractionEnabled = false
        for h in Self.waveH {
            let b = UIView()
            b.translatesAutoresizingMaskIntoConstraints = false
            b.backgroundColor = textColor
            b.alpha = 0.35
            b.layer.cornerRadius = 1.25
            b.widthAnchor.constraint(equalToConstant: 2.5).isActive = true
            b.heightAnchor.constraint(equalToConstant: h).isActive = true
            wave.addArrangedSubview(b)
            bars.append(b)
        }
        addSubview(wave)
        timeL.translatesAutoresizingMaskIntoConstraints = false
        timeL.font = UIFont.systemFont(ofSize: 11)
        timeL.textColor = theme.faint
        let d = att.duration
        timeL.text = String(format: "%d:%02d", d / 60, d % 60)
        timeL.isUserInteractionEnabled = false
        addSubview(timeL)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 36),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 130),
            circle.widthAnchor.constraint(equalToConstant: 28),
            circle.heightAnchor.constraint(equalToConstant: 28),
            circle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            circle.centerYAnchor.constraint(equalTo: centerYAnchor),
            wave.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 8),
            wave.centerYAnchor.constraint(equalTo: centerYAnchor),
            wave.heightAnchor.constraint(equalToConstant: 18),
            timeL.leadingAnchor.constraint(equalTo: wave.trailingAnchor, constant: 8),
            timeL.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeL.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
        ])
        addTarget(self, action: #selector(toggle), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func toggle() {
        if Self.playing === self { if Self.paused { Self.resume() } else { Self.pause() }; return }
        Self.stopAll()
        guard let u = att.fullURL else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let src = LXVoiceCache.cached(u) ?? u
        if src == u { LXVoiceCache.prefetch(u) }
        let item = AVPlayerItem(url: src)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = false
        Self.player = p
        Self.playing = self
        Self.paused = false
        setPlaying(true)
        Self.timeObs = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { _ in
            Self.playing?.updateFill()
        }
        if let o = Self.endObs { NotificationCenter.default.removeObserver(o) }
        Self.endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { _ in
            Self.stopAll()
        }
        Task { [weak self] in
            if let d = try? await item.asset.load(.duration) {
                let sec = Int(d.seconds.rounded())
                if sec > 0 { await MainActor.run { self?.timeL.text = String(format: "%d:%02d", sec / 60, sec % 60); Self.pushNowPlaying() } }
            }
        }
        Self.wireRemote()
        p.play()
        p.rate = LXVoiceDock.currentRate
        Self.pushNowPlaying()
    }
    @objc private func ended() { Self.stopAll() }
    static var endObs: Any?
    static func stopAll() {
        if let p = player, let o = timeObs { p.removeTimeObserver(o) }
        timeObs = nil
        if let o = endObs { NotificationCenter.default.removeObserver(o) }
        endObs = nil
        player?.pause(); player = nil
        playing?.setPlaying(false); playing?.resetFill(); playing = nil
        paused = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        LXVoiceDock.sync()
    }

    static func adopt(_ bar: LXVoiceBar) {
        guard let cur = playing, cur !== bar, player != nil, cur.att.url == bar.att.url else { return }
        cur.setPlaying(false); cur.resetFill()
        playing = bar
        bar.setPlaying(!paused)
        bar.updateFill()
    }
    func updateFill() {
        guard let p = Self.player else { return }
        var d = Double(att.duration)
        if let dd = p.currentItem?.duration.seconds, dd.isFinite, dd > 0 { d = dd }
        guard d > 0 else { return }
        let cur = max(0, p.currentTime().seconds)
        if cur >= d - 0.05, p.timeControlStatus == .paused, !Self.paused { Self.stopAll(); return }
        let frac = max(0, min(1, cur / d))
        let n = Int((frac * Double(bars.count)).rounded(.down))
        for (i, b) in bars.enumerated() where i < n {
            b.layer.removeAnimation(forKey: "vaO")
            if b.backgroundColor != accent { b.backgroundColor = accent }
            b.alpha = 1
        }
        let rem = max(0, Int((d - cur).rounded(.up)))
        timeL.text = String(format: "%d:%02d", rem / 60, rem % 60)
    }
    func resetFill() {
        for b in bars { b.backgroundColor = barColor; b.alpha = 0.35 }
        let d = att.duration
        timeL.text = String(format: "%d:%02d", d / 60, d % 60)
    }

    private(set) static var paused = false
    @discardableResult static func pause() -> Bool {
        guard let p = player, let bar = playing else { return false }
        p.pause(); paused = true; bar.setPlaying(false); pushNowPlaying(); return true
    }
    @discardableResult static func resume() -> Bool {
        guard let p = player, let bar = playing else { return false }
        try? AVAudioSession.sharedInstance().setActive(true)
        p.play(); p.rate = LXVoiceDock.currentRate; paused = false; bar.setPlaying(true); pushNowPlaying(); return true
    }
    static func pushNowPlaying() {
        guard let p = player, let bar = playing else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: bar.title, MPMediaItemPropertyArtist: "Lustre",
                                   MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
        if let d = p.currentItem?.duration.seconds, d.isFinite, d > 0 { info[MPMediaItemPropertyPlaybackDuration] = d }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, p.currentTime().seconds)
        info[MPNowPlayingInfoPropertyPlaybackRate] = paused ? 0.0 : Double(LXVoiceDock.currentRate)
        if let img = LXAvatarStore.image(bar.avatarKey) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        LXVoiceDock.sync()
    }
    private static var remoteWired = false
    private static func wireRemote() {
        guard !remoteWired else { return }
        remoteWired = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in resume() ? .success : .commandFailed }
        c.pauseCommand.addTarget { _ in pause() ? .success : .commandFailed }
        c.togglePlayPauseCommand.addTarget { _ in (paused ? resume() : pause()) ? .success : .commandFailed }
        c.changePlaybackPositionCommand.addTarget { ev in
            guard let e = ev as? MPChangePlaybackPositionCommandEvent, let p = player else { return .commandFailed }
            p.seek(to: CMTime(seconds: e.positionTime, preferredTimescale: 600)) { _ in pushNowPlaying() }
            return .success
        }
        c.nextTrackCommand.isEnabled = false
        c.previousTrackCommand.isEnabled = false
        c.skipForwardCommand.isEnabled = false
        c.skipBackwardCommand.isEnabled = false
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    private func setPlaying(_ on: Bool) {
        playIcon.isHidden = on
        pauseIcon.isHidden = !on
        for (i, b) in bars.enumerated() {
            b.layer.removeAllAnimations()
            if on {
                let n = i + 1
                let delay: Double = n % 3 == 0 ? 0.3 : (n % 2 == 0 ? 0.15 : 0)
                let sy = CABasicAnimation(keyPath: "transform.scale.y")
                sy.fromValue = 1; sy.toValue = 1.5
                sy.duration = 0.5; sy.autoreverses = true; sy.repeatCount = .infinity
                sy.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                sy.timeOffset = delay
                b.layer.add(sy, forKey: "vaS")
                let op = CABasicAnimation(keyPath: "opacity")
                op.fromValue = 0.4; op.toValue = 0.85
                op.duration = 0.5; op.autoreverses = true; op.repeatCount = .infinity
                op.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                op.timeOffset = delay
                b.layer.add(op, forKey: "vaO")
                b.alpha = 0.4
            } else {
                b.alpha = 0.35
            }
        }
    }
}

final class LXFileCard: UIControl {
    var onTap: (() -> Void)?
    private static let extMap: [String: String] = [
        "html": "HTML", "htm": "HTML", "css": "CSS", "js": "JavaScript", "ts": "TypeScript", "json": "JSON",
        "py": "Python", "sh": "Shell", "md": "Markdown", "txt": "文本", "csv": "CSV", "log": "日志",
        "pdf": "PDF", "docx": "Word", "xlsx": "Excel", "pptx": "PPT", "zip": "压缩包",
        "mp3": "音频", "m4a": "音频", "wav": "音频", "mp4": "视频", "mov": "视频", "webm": "视频",
        "png": "图片", "jpg": "图片", "jpeg": "图片", "gif": "图片", "webp": "图片", "svg": "矢量图",
    ]
    static func kindLabel(_ name: String, _ mime: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        if let k = extMap[ext] { return k }
        if mime.hasPrefix("image/") { return "图片" }
        if mime.hasPrefix("video/") { return "视频" }
        if mime.hasPrefix("audio/") { return "音频" }
        if mime.hasPrefix("text/") { return "文本" }
        return ext.isEmpty ? "文件" : ext.uppercased()
    }
    static func fmtSize(_ n: Int) -> String {
        if n < 1024 { return "\(n) B" }
        if n < 1048576 { return "\(Int((Double(n) / 1024).rounded())) KB" }
        return String(format: "%.1f MB", Double(n) / 1048576)
    }
    init(att: LXAtt, theme: LXChatTheme, textColor: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        clipsToBounds = true
        func pinBehind(_ g: UIView) {
            g.translatesAutoresizingMaskIntoConstraints = false
            g.isUserInteractionEnabled = false
            addSubview(g)
            NSLayoutConstraint.activate([
                g.topAnchor.constraint(equalTo: topAnchor), g.bottomAnchor.constraint(equalTo: bottomAnchor),
                g.leadingAnchor.constraint(equalTo: leadingAnchor), g.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
        if theme.avatars {
            // 0926 她:头像模式里这张卡"太灰了"→跟气泡用同一种薄玻璃;薄玻璃画的是圆弧角,卡片裁边也用圆弧
            backgroundColor = .clear
            layer.borderWidth = 0
            layer.cornerCurve = .circular
            let g = LXSoftGlassView()
            g.maxRadius = 16
            g.light = LXSoftGlassView.onLight(textColor)
            pinBehind(g)
        } else if #available(iOS 26.0, *) {
            backgroundColor = .clear
            layer.borderWidth = 0
            // 普通模式:regular 玻璃,按主题底色压深浅
            let g = UIVisualEffectView(effect: UIGlassEffect())
            var w: CGFloat = 0
            theme.bg.getWhite(&w, alpha: nil)
            g.overrideUserInterfaceStyle = w < 0.5 ? .dark : .light
            g.cornerConfiguration = .uniformCorners(radius: .fixed(16))
            pinBehind(g)
        } else {
            backgroundColor = theme.cardBg
            layer.borderWidth = 1
            layer.borderColor = theme.hairline.cgColor
        }
        let ic = UIView()
        ic.translatesAutoresizingMaskIntoConstraints = false
        ic.isUserInteractionEnabled = false
        // 头像模式的图标底块跟字同色系淡一层(原来的 segTrack 在月夜是深灰块)
        let tileC = theme.avatars ? textColor.withAlphaComponent(0.10) : theme.segTrack
        let back = UIView(frame: CGRect(x: 0, y: 3, width: 34, height: 38))
        back.backgroundColor = tileC
        back.alpha = 0.55
        back.layer.cornerRadius = 8
        ic.addSubview(back)
        let front = UIView(frame: CGRect(x: 6, y: 0, width: 36, height: 40))
        front.backgroundColor = tileC
        front.layer.cornerRadius = 8
        ic.addSubview(front)
        let doc = CAShapeLayer()
        let s: CGFloat = 19.0 / 24.0
        let dp = UIBezierPath()
        dp.move(to: CGPoint(x: 14 * s, y: 3 * s)); dp.addLine(to: CGPoint(x: 14 * s, y: 8 * s)); dp.addLine(to: CGPoint(x: 19 * s, y: 8 * s))
        dp.move(to: CGPoint(x: 7 * s, y: 3 * s)); dp.addLine(to: CGPoint(x: 15 * s, y: 3 * s))
        dp.addLine(to: CGPoint(x: 20 * s, y: 8 * s)); dp.addLine(to: CGPoint(x: 20 * s, y: 19 * s))
        dp.addArc(withCenter: CGPoint(x: 18.5 * s, y: 19 * s), radius: 1.5 * s, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        dp.addLine(to: CGPoint(x: 6.5 * s, y: 20.5 * s))
        dp.addArc(withCenter: CGPoint(x: 6.5 * s, y: 19 * s), radius: 1.5 * s, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        dp.addLine(to: CGPoint(x: 5 * s, y: 4.5 * s))
        dp.addArc(withCenter: CGPoint(x: 6.5 * s, y: 4.5 * s), radius: 1.5 * s, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        doc.path = dp.cgPath
        doc.strokeColor = textColor.withAlphaComponent(0.85).cgColor
        doc.fillColor = UIColor.clear.cgColor
        doc.lineWidth = 1.7
        doc.lineCap = .round
        doc.lineJoin = .round
        doc.frame = CGRect(x: 6 + 8.5, y: 10.5, width: 19, height: 19)
        ic.layer.addSublayer(doc)
        addSubview(ic)
        let nameL = UILabel()
        nameL.translatesAutoresizingMaskIntoConstraints = false
        nameL.font = LXBubbleCell.bodyFont().withSize(14.5)
        nameL.textColor = textColor
        nameL.lineBreakMode = .byTruncatingTail
        nameL.text = att.name
        nameL.isUserInteractionEnabled = false
        let kindL = UILabel()
        kindL.translatesAutoresizingMaskIntoConstraints = false
        kindL.font = UIFont.systemFont(ofSize: 12)
        kindL.textColor = theme.faint
        var kt = Self.kindLabel(att.name, att.mime)
        if att.size > 0 { kt += " · " + Self.fmtSize(att.size) }
        kindL.text = kt
        kindL.isUserInteractionEnabled = false
        addSubview(nameL)
        addSubview(kindL)
        let maxW = min(300, UIScreen.main.bounds.width * 0.74)
        let wc = widthAnchor.constraint(equalToConstant: maxW)
        wc.priority = .defaultHigh
        NSLayoutConstraint.activate([
            wc,
            heightAnchor.constraint(equalToConstant: 42 + 22),
            ic.widthAnchor.constraint(equalToConstant: 42),
            ic.heightAnchor.constraint(equalToConstant: 42),
            ic.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 13),
            ic.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameL.leadingAnchor.constraint(equalTo: ic.trailingAnchor, constant: 12),
            nameL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -13),
            nameL.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            kindL.leadingAnchor.constraint(equalTo: nameL.leadingAnchor),
            kindL.trailingAnchor.constraint(equalTo: nameL.trailingAnchor),
            kindL.topAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        addTarget(self, action: #selector(pressDown), for: .touchDown)
        addTarget(self, action: #selector(pressUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func tapped() { onTap?() }
    @objc private func pressDown() { UIView.animate(withDuration: 0.14) { self.transform = CGAffineTransform(scaleX: 0.975, y: 0.975) } }
    @objc private func pressUp() { UIView.animate(withDuration: 0.14) { self.transform = .identity } }
}


final class LXMsgMenu: UIView {
    var onAct: ((String) -> Void)?
    private let dim = UIView()
    private var blurAnim: UIViewPropertyAnimator?
    private let blurV = UIVisualEffectView(effect: nil)
    private var snap: UIView?
    private let panel = UIView()
    private var liftAnim: UIViewPropertyAnimator?

    static func icon(_ name: String, color: UIColor, stroke: CGFloat = 1.7) -> UIImage {
        let sz: CGFloat = 18
        let s = sz / 24
        return UIGraphicsImageRenderer(size: CGSize(width: sz, height: sz)).image { ctx in
            let c = ctx.cgContext
            c.setStrokeColor(color.cgColor)
            c.setLineWidth(stroke * s)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            func line(_ pts: [(CGFloat, CGFloat)]) {
                guard let f = pts.first else { return }
                c.move(to: CGPoint(x: f.0 * s, y: f.1 * s))
                for p in pts.dropFirst() { c.addLine(to: CGPoint(x: p.0 * s, y: p.1 * s)) }
                c.strokePath()
            }
            func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
                c.addPath(UIBezierPath(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s).cgPath)
                c.strokePath()
            }
            switch name {
            case "quote":
                line([(9, 17), (4, 12), (9, 7)])
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 4 * s, y: 12 * s))
                p.addLine(to: CGPoint(x: 15 * s, y: 12 * s))
                p.addArc(withCenter: CGPoint(x: 15 * s, y: 17 * s), radius: 5 * s, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
                p.addLine(to: CGPoint(x: 14 * s, y: 22 * s))
                c.addPath(p.cgPath); c.strokePath()
            case "stt":
                line([(4, 7), (20, 7)])
                line([(4, 12), (20, 12)])
                line([(4, 17), (13, 17)])
            case "multi":
                rrect(4, 4, 7, 7, 1.6)
                rrect(13, 13, 7, 7, 1.6)
                line([(14.5, 6.5), (16.5, 8.5), (20, 5)])
                line([(4.5, 16.5), (6.5, 18.5)])
            case "star":
                line([(12, 3.6), (14.5, 8.8), (20.2, 9.5), (16, 13.4), (17.1, 19), (12, 16.2), (6.9, 19), (8, 13.4), (3.8, 9.5), (9.5, 8.8), (12, 3.6)])
            case "seltext":
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 4 * s, y: 7 * s)); p.addLine(to: CGPoint(x: 4 * s, y: 5.5 * s))
                p.addArc(withCenter: CGPoint(x: 5.5 * s, y: 5.5 * s), radius: 1.5 * s, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
                p.addLine(to: CGPoint(x: 7 * s, y: 4 * s))
                p.move(to: CGPoint(x: 17 * s, y: 4 * s)); p.addLine(to: CGPoint(x: 18.5 * s, y: 4 * s))
                p.addArc(withCenter: CGPoint(x: 18.5 * s, y: 5.5 * s), radius: 1.5 * s, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
                p.addLine(to: CGPoint(x: 20 * s, y: 7 * s))
                p.move(to: CGPoint(x: 20 * s, y: 17 * s)); p.addLine(to: CGPoint(x: 20 * s, y: 18.5 * s))
                p.addArc(withCenter: CGPoint(x: 18.5 * s, y: 18.5 * s), radius: 1.5 * s, startAngle: 0, endAngle: .pi / 2, clockwise: true)
                p.addLine(to: CGPoint(x: 17 * s, y: 20 * s))
                p.move(to: CGPoint(x: 7 * s, y: 20 * s)); p.addLine(to: CGPoint(x: 5.5 * s, y: 20 * s))
                p.addArc(withCenter: CGPoint(x: 5.5 * s, y: 18.5 * s), radius: 1.5 * s, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
                p.addLine(to: CGPoint(x: 4 * s, y: 17 * s))
                c.addPath(p.cgPath); c.strokePath()
                line([(9, 9), (15, 9)])
                line([(12, 9), (12, 16)])
            case "copy":
                rrect(9, 9, 11, 11, 2)
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 5 * s, y: 15 * s))
                p.addLine(to: CGPoint(x: 5 * s, y: 5 * s))
                p.addArc(withCenter: CGPoint(x: 7 * s, y: 5 * s), radius: 2 * s, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
                p.addLine(to: CGPoint(x: 17 * s, y: 3 * s))
                c.addPath(p.cgPath); c.strokePath()
            case "delete":
                line([(4, 7), (20, 7)])
                line([(10, 11), (10, 17)])
                line([(14, 11), (14, 17)])
                line([(5, 7), (6, 20), (7, 21), (17, 21), (18, 20), (19, 7)])
                line([(9, 7), (9, 4), (10, 3), (14, 3), (15, 4), (15, 7)])
            default: break
            }
        }.withRenderingMode(.alwaysOriginal)
    }

    init(msg: LXMsg, bubble: UIView, host: UIView, theme: LXChatTheme) {
        super.init(frame: host.bounds)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let mine = msg.from == "human"
        blurV.frame = bounds
        blurV.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurV)
        let anim = UIViewPropertyAnimator(duration: 1, curve: .linear) { [blurV] in
            blurV.effect = UIBlurEffect(style: .regular)
        }
        anim.fractionComplete = 0.25
        anim.pausesOnCompletion = true
        blurAnim = anim
        dim.frame = bounds
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dim.backgroundColor = UIColor(red: 10/255.0, green: 16/255.0, blue: 24/255.0, alpha: 0.30)
        dim.alpha = 0
        addSubview(dim)
        blurV.alpha = 0
        UIView.animate(withDuration: 0.26) { self.dim.alpha = 1; self.blurV.alpha = 1 }
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(scrimTap)))
        let r = bubble.convert(bubble.bounds, to: host)
        if let sv = bubble.snapshotView(afterScreenUpdates: false) {
            sv.frame = r
            sv.layer.shadowColor = UIColor(red: 18/255.0, green: 34/255.0, blue: 52/255.0, alpha: 1).cgColor
            sv.layer.shadowOpacity = 0.30
            sv.layer.shadowOffset = CGSize(width: 0, height: 22)
            sv.layer.shadowRadius = 25
            addSubview(sv)
            snap = sv
            sv.layer.anchorPoint = CGPoint(x: mine ? 1 : 0, y: 1)
            sv.layer.position = CGPoint(x: mine ? r.maxX : r.minX, y: r.maxY)
            let la = UIViewPropertyAnimator(duration: 0.26,
                controlPoint1: CGPoint(x: 0.22, y: 1), controlPoint2: CGPoint(x: 0.36, y: 1)) {
                sv.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            }
            la.startAnimation()
            liftAnim = la
        }
        var white: CGFloat = 0
        theme.bg.getWhite(&white, alpha: nil)
        let glass26: Bool
        let mat: UIVisualEffectView
        if #available(iOS 26.0, *) {
            glass26 = true
            let g = UIVisualEffectView(effect: UIGlassEffect())
            g.cornerConfiguration = .uniformCorners(radius: .fixed(16))
            g.overrideUserInterfaceStyle = white < 0.5 ? .dark : .light
            mat = g
        } else {
            glass26 = false
            mat = UIVisualEffectView(effect: UIBlurEffect(style: white < 0.5 ? .systemThickMaterialDark : .systemThickMaterialLight))
        }
        panel.layer.cornerRadius = 16
        panel.layer.borderWidth = glass26 ? 0 : 1
        panel.layer.borderColor = theme.hairline.cgColor
        panel.clipsToBounds = true
        mat.frame = .zero
        panel.addSubview(mat)
        let tint = UIView()
        tint.backgroundColor = glass26 ? .clear : theme.menuBg.withAlphaComponent(0.72)
        panel.addSubview(tint)
        let col = UIStackView()
        col.axis = .vertical
        col.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(col)
        NSLayoutConstraint.activate([
            col.topAnchor.constraint(equalTo: panel.topAnchor, constant: 5),
            col.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -5),
            col.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 5),
            col.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -5),
            col.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
        ])
        if msg.from == "ai" && msg.id < Int64.max - 8 {
            let bar = UIStackView()
            bar.axis = .horizontal
            bar.spacing = 2
            let more = UIButton(type: .system)
            more.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
            more.tintColor = (white < 0.5 ? UIColor(white: 0.93, alpha: 1) : UIColor(white: 0.12, alpha: 1)).withAlphaComponent(0.82)
            more.heightAnchor.constraint(equalToConstant: 34).isActive = true
            more.contentHorizontalAlignment = .center
            more.addAction(UIAction { [weak self] _ in self?.act("emojiKb") }, for: .touchUpInside)
            bar.addArrangedSubview(more)
            let wrap = UIStackView(arrangedSubviews: [bar])
            wrap.axis = .vertical
            wrap.isLayoutMarginsRelativeArrangement = true
            wrap.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 6, right: 4)
            col.addArrangedSubview(wrap)
            let sep = UIView()
            sep.backgroundColor = theme.hairline
            sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
            col.addArrangedSubview(sep)
            col.setCustomSpacing(4, after: sep)
        }
        let fg = white < 0.5 ? UIColor(white: 0.93, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        let danger = UIColor(red: 0.878, green: 0.353, blue: 0.302, alpha: 1)
        var items: [(String, String, UIColor)] = [
            ("quote", "引用", fg), ("multi", "多选", fg), ("star", "收藏", fg),
        ]
        let voice = LXBubbleCell.isVoice(msg)
        if voice {
            items.append(("stt", LXBubbleCell.voiceOpen.contains(msg.id) ? "收起文字" : "转文字", fg))
        }
        if !msg.text.isEmpty && (!voice || LXBubbleCell.voiceOpen.contains(msg.id)) {
            items.append(("seltext", "Select text", fg))
            items.append(("copy", "Copy", fg))
        }
        items.append(("delete", "Delete", danger))
        for (id, title, color) in items {
            let b = UIButton(type: .system)
            var cfg = UIButton.Configuration.plain()
            cfg.image = Self.icon(id, color: color.withAlphaComponent(0.82))
            cfg.imagePadding = 11
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
            cfg.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: LXBubbleCell.bodyFont(), .foregroundColor: color]))
            cfg.background.cornerRadius = 12
            b.configuration = cfg
            b.contentHorizontalAlignment = .leading
            b.addAction(UIAction { [weak self] _ in self?.act(id) }, for: .touchUpInside)
            col.addArrangedSubview(b)
        }
        addSubview(panel)
        panel.layoutIfNeeded()
        let psz = panel.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let pw = max(150, psz.width), ph = psz.height
        var top = r.maxY + 10
        if top + ph + 12 > bounds.height { top = max(12, r.minY - 10 - ph) }
        var left = mine ? r.maxX - pw : r.minX
        left = max(10, min(left, bounds.width - pw - 10))
        panel.frame = CGRect(x: left, y: top, width: pw, height: ph)
        panel.layoutIfNeeded()
        let realH = ceil(col.frame.maxY + 5)
        if realH > ph + 0.5 {
            var top2 = top
            if top2 + realH + 12 > bounds.height { top2 = max(12, bounds.height - realH - 12) }
            panel.frame = CGRect(x: left, y: top2, width: pw, height: realH)
        }
        mat.frame = panel.bounds
        tint.frame = panel.bounds
        mat.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.96, y: 0.96)
        let pa = UIViewPropertyAnimator(duration: 0.3,
            controlPoint1: CGPoint(x: 0.16, y: 1), controlPoint2: CGPoint(x: 0.3, y: 1)) {
            self.panel.alpha = 1
            self.panel.transform = .identity
        }
        pa.startAnimation(afterDelay: 0.05)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func scrimTap() { act("close") }
    private func act(_ id: String) { onAct?(id) }

    func dismiss() {
        blurAnim?.stopAnimation(true)
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
        }
    }
}

final class LXEmojiField: UITextField {
    override var textInputContextIdentifier: String? { "lx.emoji.react" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
    }
}

final class LXEmojiPicker: UIView, UITextFieldDelegate {
    static var shared: LXEmojiPicker?
    private let field = LXEmojiField()
    private var onPick: ((String) -> Void)?

    static func present(host: UIView, onPick: @escaping (String) -> Void) {
        shared?.finish(nil)
        let p = LXEmojiPicker(frame: host.bounds)
        p.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        p.backgroundColor = UIColor(white: 0, alpha: 0.18)
        p.onPick = onPick
        p.field.delegate = p
        p.field.autocorrectionType = .no
        p.field.spellCheckingType = .no
        p.field.tintColor = .clear
        p.field.alpha = 0.02
        p.field.frame = CGRect(x: 8, y: 8, width: 1, height: 1)
        p.addSubview(p.field)
        p.addGestureRecognizer(UITapGestureRecognizer(target: p, action: #selector(cancelTap)))
        host.addSubview(p)
        LXStage.settle(host)
        shared = p
        p.alpha = 0
        UIView.animate(withDuration: 0.18) { p.alpha = 1 }
        p.field.becomeFirstResponder()
    }
    func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
        if let first = s.first { finish(String(first)) }
        return false
    }
    func textFieldShouldReturn(_ tf: UITextField) -> Bool { finish(nil); return false }
    func textFieldDidEndEditing(_ tf: UITextField) { finish(nil) }
    @objc private func cancelTap() { finish(nil) }
    private func finish(_ e: String?) {
        guard Self.shared === self else { return }
        Self.shared = nil
        let cb = onPick
        onPick = nil
        if field.isFirstResponder { field.resignFirstResponder() }
        UIView.animate(withDuration: 0.18, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
        if let e = e, !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { cb?(e) }
    }
}


final class LXTermPeek: UIView {
    private let body = UITextView()
    private let status = UILabel()
    private var timer: Timer?
    private var win = "0"
    private var inFlight = false
    private var lastGood: String?
    private var fails = 0

    init(safeTop: CGFloat, host: UIView) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowOffset = CGSize(width: 0, height: 18)
        layer.shadowRadius = 25
        // 0925 她的单:终端小窗跟底部小卡一样用深色玻璃(玻璃 + LXSheetInk.tint);玻璃不许半透明,进出场只动位置
        let glassFx: UIVisualEffect
        if #available(iOS 26.0, *) { glassFx = UIGlassEffect() }
        else { glassFx = UIBlurEffect(style: LXSheetInk.dark ? .systemThickMaterialDark : .systemThickMaterialLight) }
        let glass = UIVisualEffectView(effect: glassFx)
        glass.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        glass.clipsToBounds = true
        glass.layer.cornerRadius = 14
        glass.layer.cornerCurve = .continuous
        if #available(iOS 26.0, *) { glass.cornerConfiguration = .uniformCorners(radius: .fixed(14)) }
        let tintV = UIView(); tintV.backgroundColor = LXSheetInk.tint
        tintV.layer.cornerRadius = 14; tintV.layer.cornerCurve = .continuous; tintV.clipsToBounds = true
        for v in [glass, tintV] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; v.isUserInteractionEnabled = false; addSubview(v) }
        body.translatesAutoresizingMaskIntoConstraints = false
        body.isEditable = false
        body.backgroundColor = .clear
        body.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        body.textColor = UIColor(red: 0x9F/255.0, green: 0xB0/255.0, blue: 0xBF/255.0, alpha: 1)
        body.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        body.text = "连接中…"
        addSubview(body)
        status.translatesAutoresizingMaskIntoConstraints = false
        status.font = UIFont.systemFont(ofSize: 10)
        status.textColor = UIColor(white: 1, alpha: 0.45)
        status.isHidden = true
        addSubview(status)
        host.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 10),
            trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -10),
            topAnchor.constraint(equalTo: host.topAnchor, constant: safeTop + 58),
            heightAnchor.constraint(equalTo: host.heightAnchor, multiplier: 0.34),
            glass.topAnchor.constraint(equalTo: topAnchor), glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor), glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintV.topAnchor.constraint(equalTo: topAnchor), tintV.bottomAnchor.constraint(equalTo: bottomAnchor),
            tintV.leadingAnchor.constraint(equalTo: leadingAnchor), tintV.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            status.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
        ])
        transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.97, y: 0.97)
        UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.3,
                       options: [.allowUserInteraction]) { self.transform = .identity }
    }
    required init?(coder: NSCoder) { fatalError() }

    func start(session: String) {
        if session.isEmpty || session == "__legacy__" { win = "0" }
        else if session == "yan-main" { win = "tg" }
        else { win = "s-" + session }
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = 0.3
        timer = t
    }

    /// 0925 她说预览"老是断、重连":原来每 1.5 秒不管上一次回没回来都再发一次,任何一次没回来就把整屏换成"连不上"。
    /// 现在:上一次没回来就不叠发;偶尔一次没拿到,屏幕上留着上一屏,只在角上小字标"重连中";连续失败才说连不上。
    private func tick() {
        guard !inFlight else { return }
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        guard let u = URL(string: LustreConfig.origin + "/term/api/peek?window=\(win)&auth=" + tok) else { return }
        var r = URLRequest(url: u)
        r.timeoutInterval = 8
        r.cachePolicy = .reloadIgnoringLocalCacheData
        inFlight = true
        URLSession.shared.dataTask(with: r) { [weak self] data, resp, _ in
            DispatchQueue.main.async {
                guard let s = self else { return }
                s.inFlight = false
                if (resp as? HTTPURLResponse)?.statusCode == 404 {
                    s.lastGood = nil; s.status.isHidden = true
                    s.body.text = "这个对话的实例现在没有在运行（发条消息就会醒来）。"
                    return
                }
                guard let d = data,
                      let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                      let text = obj["text"] as? String else {
                    s.fails += 1
                    if s.lastGood != nil {
                        s.status.text = "重连中…"; s.status.isHidden = false
                    } else if s.fails >= 3 {
                        s.body.text = "预览连不上,稍后再试。"
                    }
                    return
                }
                s.fails = 0
                s.status.isHidden = true
                let shown = text.isEmpty ? "(空)" : text
                guard shown != s.lastGood else { return }
                s.lastGood = shown
                let stick = s.body.contentSize.height - s.body.contentOffset.y - s.body.bounds.height < 30
                s.body.text = shown
                if stick {
                    let y = max(0, s.body.contentSize.height - s.body.bounds.height)
                    s.body.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                }
            }
        }.resume()
    }

    func closePeek() {
        timer?.invalidate(); timer = nil
        // 0925 她:点开的动画对,收起别往上滑,点一下就不见(玻璃又不能淡出,直接拿掉)
        removeFromSuperview()
    }
}


@objc(ChatListPlugin)
public class ChatListPlugin: CAPPlugin, CAPBridgedPlugin, UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate {
    public let identifier = "ChatListPlugin"
    public let jsName = "ChatList"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "chatEnable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatDisable", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatSession", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatTheme", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatPoke", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatHide", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatOffset", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatJump", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "rpVals", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatAvatars", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "chatWall", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "callPill", returnType: CAPPluginReturnPromise)
    ]

    var container: UIView?
    var table: UITableView?
    private var pushObs: NSObjectProtocol?

    func armPushIntake() {
        guard pushObs == nil else { return }
        pushObs = NotificationCenter.default.addObserver(
            forName: Notification.Name("lx.push.message"), object: nil, queue: .main) { [weak self] n in
            guard let s = self, let lx = n.userInfo as? [String: Any] else { return }
            s.data.handle(lx)
        }
        if let lx = AppDelegate.pendingPush {
            AppDelegate.pendingPush = nil
            DispatchQueue.main.async { [weak self] in self?.data.handle(lx) }
        }
    }
    var header: LXHeaderBar?
    var rpanel: RPanelView?
    var wallV: UIImageView?
    var defWallV: LXDefaultWall?
    var scrimV: LXScrimView?

    func openRPanel() {
        guard rpanel == nil, let host = bridge?.viewController?.view else { return }
        host.endEditing(true)
        let p = RPanelView()
        p.onAct = { [weak self] act in
            guard let s = self else { return }
            switch act {
            case "back": s.closeRPanel()
            case "moon":
                if LustreConfig.webless { s.switchMoon(LXMoonPalette.next(RPSpec.moonState)) }
                else { s.webAct(["act": "rpClick", "id": "themeMoon"]) }
            case "customAvatarAiRow": s.rpPickImage("ai")
            case "customAvatarHumanRow": s.rpPickImage("human")
            case "customAvatarZhaoRow": s.rpPickImage("zhao")
            case "customWallRow": s.rpPickImage("wall")
            case "customWallReset": s.rpResetWall()
            case "customResetRow": s.rpResetLooks()
            case "chatAvatarsRow" where LustreConfig.webless: s.rpToggleAvatars()
            case "bubbleGlassRow": s.openBubbleTuner()
            default:
                s.webAct(["act": "rpClick", "id": act])
            }
        }
        p.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(p)
        LXStage.settle(host)
        NSLayoutConstraint.activate([
            p.topAnchor.constraint(equalTo: host.topAnchor),
            p.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            p.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            p.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
        host.layoutIfNeeded()
        p.transform = CGAffineTransform(translationX: host.bounds.width, y: 0)
        UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.88,
                       initialSpringVelocity: 0.4, options: [.allowUserInteraction]) {
            p.transform = .identity
        }
        p.fetchUsage()
        rpanel = p
        if let mirror = UserDefaults.standard.dictionary(forKey: "lx.rp.vals") as? [String: String] {
            for (rid, v) in mirror { rpSetVal(rid, v) }
        }
        webAct(["act": "rpVals"])
    }

    func closeRPanel() {
        guard let p = rpanel else { return }
        rpanel = nil
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.95,
                       initialSpringVelocity: 0.2, options: []) {
            p.transform = CGAffineTransform(translationX: p.bounds.width, y: 0)
        } completion: { _ in p.removeFromSuperview() }
    }

    @objc func rpVals(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard self.rpanel != nil else { call.resolve(["ok": false]); return }
            let keys = ["customAvatarAiRow": "ai", "customAvatarHumanRow": "human",
                        "customAvatarZhaoRow": "zhao", "customWallRow": "wall", "chatAvatarsRow": "avatars"]
            for (rid, k) in keys {
                if let v = call.getString(k), !v.isEmpty { self.rpSetVal(rid, v) }
            }
            call.resolve(["ok": true])
        }
    }


    private var rpPickTarget: String?

    func rpPickImage(_ target: String) {
        rpPickTarget = target
        var cfg = PHPickerConfiguration()
        cfg.filter = .images
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        bridge?.viewController?.present(picker, animated: true)
    }

    private func rpProcess(_ img: UIImage, target: String) -> String? {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let data: Data?
        let mime: String
        switch target {
        case "wall":
            let mx = max(img.size.width, img.size.height)
            let sc = min(1, 1500 / mx)
            let sz = CGSize(width: (img.size.width * sc).rounded(), height: (img.size.height * sc).rounded())
            let out = UIGraphicsImageRenderer(size: sz, format: fmt).image { _ in
                img.draw(in: CGRect(origin: .zero, size: sz))
            }
            data = out.jpegData(compressionQuality: 0.82); mime = "image/jpeg"
        case "human", "zhao":
            fmt.opaque = false
            let size: CGFloat = 320
            let sc = min(size / img.size.width, size / img.size.height)
            let w = img.size.width * sc, h = img.size.height * sc
            let out = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { _ in
                img.draw(in: CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
            }
            data = out.pngData(); mime = "image/png"
        default:
            let size: CGFloat = 320
            let s0 = min(img.size.width, img.size.height)
            let sc = size / s0
            let w = img.size.width * sc, h = img.size.height * sc
            let out = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: fmt).image { _ in
                img.draw(in: CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h))
            }
            data = out.jpegData(compressionQuality: 0.86); mime = "image/jpeg"
        }
        guard let d = data else { return nil }
        return "data:\(mime);base64," + d.base64EncodedString()
    }

    private func rpStore(target: String, dataUrl: String) {
        if LustreConfig.webless {
            if target == "wall" {
                LXWallStore.set(source: dataUrl)
                applyWall()
                self.toast("背景已更换")
                rpSetVal("customWallRow", "Custom")
            } else {
                LXAvatarStore.set(target, source: dataUrl)
                self.toast("头像已更换")
                let rowId = ["ai": "customAvatarAiRow", "human": "customAvatarHumanRow", "zhao": "customAvatarZhaoRow"][target]
                if let rid = rowId { rpSetVal(rid, "Custom") }
            }
            return
        }
        let toast = target == "wall" ? "背景已更换"
                  : "头像已更换 · ' + APP_BUILD + ' · " + (dataUrl.hasPrefix("data:image/png") ? "整图" : "裁切")
        let js = """
        (function(){try{
          localStorage.setItem(CUSTOM_KEYS['\(target)'], '\(dataUrl)');
          applyCustomAppearance();
          showToast('\(toast)');
          return true;
        }catch(e){ showToast('图片存不下,换小一点的试试'); return false; }})()
        """
        bridge?.webView?.evaluateJavaScript(js) { [weak self] result, _ in
            guard let s = self, (result as? Bool) == true else { return }
            let rowId = ["ai": "customAvatarAiRow", "human": "customAvatarHumanRow",
                         "zhao": "customAvatarZhaoRow", "wall": "customWallRow"][target]
            if let rid = rowId { s.rpSetVal(rid, "Custom") }
        }
    }

    /// 0926 她:"把气泡参数整个搬到原生界面,我自己调"。先收右面板让出聊天页,再升起调节卡(不压暗,边拖边看)
    func openBubbleTuner() {
        closeRPanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let s = self, let host = s.bridge?.viewController?.view else { return }
            let light = LXSoftGlassView.onLight(s.theme.meFg)
            _ = LXCardSheet(host: host, title: "Bubble glass", dim: false, build: { LXSoftGlassTuner.build(into: $0, light: light) })
        }
    }

    func rpResetLooks() {
        if LustreConfig.webless {
            for k in ["ai", "human", "zhao"] { LXAvatarStore.set(k, source: LXAvatarStore.defaultURL) }
            LXWallStore.set(source: "")
            applyWall()
            toast("已恢复默认外观")
            for rid in ["customAvatarAiRow", "customAvatarHumanRow", "customAvatarZhaoRow", "customWallRow"] {
                rpSetVal(rid, "Default")
            }
            return
        }
        let js = """
        (function(){ Object.values(CUSTOM_KEYS).forEach(function(k){ localStorage.removeItem(k); });
          applyCustomAppearance(); showToast('已恢复默认外观'); return true; })()
        """
        bridge?.webView?.evaluateJavaScript(js) { [weak self] _, _ in
            guard let s = self else { return }
            for rid in ["customAvatarAiRow", "customAvatarHumanRow", "customAvatarZhaoRow", "customWallRow"] {
                s.rpSetVal(rid, "Default")
            }
        }
    }

    private func rpSetVal(_ rowId: String, _ val: String) {
        var mirror = (UserDefaults.standard.dictionary(forKey: "lx.rp.vals") as? [String: String]) ?? [:]
        mirror[rowId] = val
        UserDefaults.standard.set(mirror, forKey: "lx.rp.vals")
        guard let p = rpanel else { return }
        let target: String, shown: String
        switch rowId {
        case "customAvatarAiRow", "customAvatarHumanRow", "customAvatarZhaoRow", "avatarMenu":
            let n = ["customAvatarAiRow", "customAvatarHumanRow", "customAvatarZhaoRow"]
                .filter { let v = mirror[$0] ?? "Default"; return !v.isEmpty && v != "Default" }.count
            target = "avatarMenu"; shown = n == 0 ? "Default" : "\(n) custom"
        case "customWallRow": target = "wallMenu"; shown = val
        default: target = rowId; shown = val
        }
        for (i, pair) in p.rowsById.enumerated() where i < p.actionRows.count && pair.0 == target {
            p.actionRows[i].valL.text = shown
        }
    }
    func rpResetWall() {
        if LustreConfig.webless {
            LXWallStore.set(source: "")
            applyWall()
            rpSetVal("customWallRow", "Default")
            return
        }
        let js = "(function(){ if (window.resetCustomWall) { window.resetCustomWall(); return true; } return false; })()"
        bridge?.webView?.evaluateJavaScript(js) { [weak self] _, _ in self?.rpSetVal("customWallRow", "Default") }
    }
    let data = LXChatData()
    var theme = LXChatTheme() {
        didSet {
            // 输入栏胶囊里的星芒、录音中的语音圆和点跟页脚星同色,换月相时跟着换
            if oldValue.fnStar != theme.fnStar { NativeInputPlugin.live?.syncStarTint() }
            // 0926 头像模式换输入栏样式。switchMoon 会先清零再恢复(假翻转),攒到下一拍只认最后的值;只动输入栏,聊天页不重建
            if oldValue.avatars != theme.avatars, !composerStyleQueued {
                composerStyleQueued = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.composerStyleQueued = false
                    NativeInputPlugin.live?.setAvatarStyle(self.theme.avatars)
                    self.syncCardGap()
                }
            }
            guard data.thinkInSheet != theme.avatars else { return }
            data.thinkInSheet = theme.avatars
            data.rebuild(stick: false)
        }
    }
    private var composerStyleQueued = false
    var bottomC: NSLayoutConstraint?
    var gapTimer: Timer?
    var loadingOlder = false
    var loadingNewer = false
    var kbToken: NSObjectProtocol?
    var menu: LXMsgMenu?
    var termPeek: LXTermPeek?
    var drawerW: CGFloat = 300
    var drawerReady = false
    static let restGap: CGFloat = 70
    static let bottomOverhang: CGFloat = 220
    /// 0926 她:头像模式不要底下那截留白。输入栏当成"下一行":每行框底已带 20.35,再补 avaLift 3.1,
    /// 最后一个气泡到输入栏顶 = 气泡到气泡的 23.45
    static let avaRestGap: CGFloat = LXBubbleCell.avaLift
    var restGapNow: CGFloat { theme.avatars ? Self.avaRestGap : Self.restGap }
    private var appliedRestGap: CGFloat = ChatListPlugin.restGap

    var stickDisarmed = false
    private var drawerBusy = false {
        didSet { if drawerBusy != oldValue { freezeWrapHeight(drawerBusy) } }
    }
    private var pendingPaint = false
    private var forceStick = false
    var pinUntil = Date.distantPast
    var kbAnimating = false
    var multiOn = false
    var multiSel = Set<Int64>()
    var multiBar: UIView?
    var multiCountL: UILabel?

    static weak var live: ChatListPlugin?

    @objc func chatEnable(_ call: CAPPluginCall) {
        Self.live = self
        DispatchQueue.main.async { self.enableOnMain(call) }
    }

    func echo(text: String, atts: [LXAtt], session: String, cid: String = "", ts: Date = Date()) {
        DispatchQueue.main.async {
            if self.data.detached { self.data.returnToLive() }
            self.stickDisarmed = false
            self.forceStick = true
            let sidOK = session.isEmpty || session == self.data.session
            if (!text.isEmpty || !atts.isEmpty) && sidOK {
                self.data.addOptimistic(text: text, atts: atts, cid: cid, ts: ts)
            }
            if let t = self.table {
                self.pinToBottom(t)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let s = self, let t2 = s.table else { return }
                    s.syncCardGap()
                    s.pinToBottom(t2)
                }
            }
        }
    }

    func outboxToast(_ t: String) { LXToast.show(t, host: container?.superview) }
    func echoUpdate(cid: String, atts: [LXAtt]) {
        DispatchQueue.main.async { self.data.updateOptimistic(cid: cid, atts: atts) }
    }
    func echoFailed(cid: String, failed: Bool) {
        DispatchQueue.main.async { self.data.setOptimisticFailed(cid: cid, failed) }
    }

    func attachEarly() {
        Self.live = self
        DispatchQueue.main.async { self.enableOnMain(nil) }
    }

    private func enableOnMain(_ call: CAPPluginCall?) {
        teardown()
        guard let host = self.bridge?.viewController?.view, let wv = self.bridge?.webView else {
            call?.resolve(["ok": false]); return
        }
        data.onTyping = { [weak self] on in
            DispatchQueue.main.async { self?.paintStatus(typing: on) }
        }
        theme.loadCached(RPSpec.moonState)
        if let call { theme.take(call) }
        if LustreConfig.webless {
            if let v = UserDefaults.standard.object(forKey: Self.avatarsKey) as? Bool { theme.avatars = v }
            LXAvatarStore.onChange = { [weak self] in
                self?.table?.visibleCells.forEach { ($0 as? LXBubbleCell)?.refreshAvatar() }
            }
            if theme.avatars { LXAvatarStore.ensureDefaults() }
        }
        if let del = call?.getArray("deleted") {
            for v in del { if let n = v as? NSNumber { data.deletedIds.insert(n.int64Value) } }
        }
        let sid = call?.getString("session")
            ?? UserDefaults.standard.string(forKey: "lx.sessionPick") ?? "__legacy__"
        let safeTop = host.safeAreaInsets.top
        let hdrH = safeTop + 8 + theme.hdrBtnSize + 10

        let cont = LXChatContainer()
        cont.translatesAutoresizingMaskIntoConstraints = false
        cont.backgroundColor = theme.bg
        cont.isHidden = true
        if let hv = host.subviews.first(where: { $0 is HomeView }) {
            host.insertSubview(cont, belowSubview: hv)
            if !hv.isHidden, let dv = LXDrawer.view, dv.superview === host { host.insertSubview(dv, belowSubview: hv) }
        } else if host.subviews.contains(wv) {
            host.insertSubview(cont, aboveSubview: wv)
        } else if let dv = LXDrawer.view, dv.superview === host {
            host.insertSubview(cont, aboveSubview: dv)
        } else {
            host.insertSubview(cont, at: min(1, host.subviews.count))
        }
        LXStage.settle(host)
        lxProbeStack(host, "chatEnable后")

        let t = LXStickyTable(frame: .zero, style: .plain)
        t.translatesAutoresizingMaskIntoConstraints = false
        t.backgroundColor = .clear
        t.separatorStyle = .none
        t.estimatedRowHeight = 56
        t.rowHeight = UITableView.automaticDimension
        t.keyboardDismissMode = .interactive
        t.transform = CGAffineTransform(scaleX: 1, y: -1)
        t.contentInsetAdjustmentBehavior = .never
        t.contentInset = UIEdgeInsets(top: restGapNow + Self.bottomOverhang, left: 0, bottom: hdrH + 6, right: 0)
        t.verticalScrollIndicatorInsets = UIEdgeInsets(top: restGapNow + Self.bottomOverhang, left: 0, bottom: hdrH, right: 0)
        appliedRestGap = restGapNow
        t.register(LXBubbleCell.self, forCellReuseIdentifier: LXBubbleCell.reuse)
        t.register(LXBubbleCell.self, forCellReuseIdentifier: LXBubbleCell.reuseGlass)
        t.register(LXDayCell.self, forCellReuseIdentifier: LXDayCell.reuse)
        t.register(LXTypingCell.self, forCellReuseIdentifier: LXTypingCell.reuse)
        t.register(LXThinkHeadCell.self, forCellReuseIdentifier: LXThinkHeadCell.reuse)
        t.register(LXThinkBodyCell.self, forCellReuseIdentifier: LXThinkBodyCell.reuse)
        t.register(LXFootCell.self, forCellReuseIdentifier: LXFootCell.reuse)
        t.register(LXApproveCell.self, forCellReuseIdentifier: LXApproveCell.reuse)
        t.dataSource = self
        t.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(bgTap))
        tap.cancelsTouchesInView = false
        t.addGestureRecognizer(tap)
        let defWallV = LXDefaultWall()
        defWallV.translatesAutoresizingMaskIntoConstraints = false
        cont.addSubview(defWallV)
        NSLayoutConstraint.activate([
            defWallV.topAnchor.constraint(equalTo: cont.topAnchor), defWallV.bottomAnchor.constraint(equalTo: cont.bottomAnchor),
            defWallV.leadingAnchor.constraint(equalTo: cont.leadingAnchor), defWallV.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
        ])
        self.defWallV = defWallV
        let wallV = UIImageView()
        wallV.translatesAutoresizingMaskIntoConstraints = false
        wallV.contentMode = .scaleAspectFill
        wallV.clipsToBounds = true
        wallV.isUserInteractionEnabled = false
        cont.addSubview(wallV)
        let scrimV = LXScrimView()
        scrimV.translatesAutoresizingMaskIntoConstraints = false
        scrimV.isUserInteractionEnabled = false
        cont.addSubview(scrimV)
        NSLayoutConstraint.activate([
            wallV.topAnchor.constraint(equalTo: cont.topAnchor), wallV.bottomAnchor.constraint(equalTo: cont.bottomAnchor),
            wallV.leadingAnchor.constraint(equalTo: cont.leadingAnchor), wallV.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
            scrimV.topAnchor.constraint(equalTo: cont.topAnchor), scrimV.bottomAnchor.constraint(equalTo: cont.bottomAnchor),
            scrimV.leadingAnchor.constraint(equalTo: cont.leadingAnchor), scrimV.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
        ])
        self.wallV = wallV
        self.scrimV = scrimV
        LXWallStore.loadDisk()
        applyWall()

        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        wrap.backgroundColor = .clear
        cont.addSubview(wrap)
        wrap.addSubview(t)
        fadeWrap = wrap
        let wb = wrap.bottomAnchor.constraint(equalTo: cont.bottomAnchor)
        wrapBotC = wb
        wb.isActive = true

        let bc = cont.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        bottomC = bc
        let hdr = LXHeaderBar(theme: theme)
        hdr.translatesAutoresizingMaskIntoConstraints = false
        hdr.onTap = { [weak self] id in
            guard let s = self else { return }
            if id == "status" { s.toggleTermPeek() }
            else if id == "menu" && s.drawerReady { s.nativeOpenDrawer() }
            else if id == "more" { s.openRPanel() }
            else { s.notifyListeners("chatNav", data: ["id": id]) }
        }
        hdr.apply(theme)
        safeTopV = safeTop
        let veil = LXTopVeil(theme: theme)
        cont.addSubview(veil)
        NSLayoutConstraint.activate([
            veil.topAnchor.constraint(equalTo: cont.topAnchor),
            veil.leadingAnchor.constraint(equalTo: cont.leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
            veil.heightAnchor.constraint(equalToConstant: safeTop + 56),
        ])
        topVeil = veil
        let bveil = LXTopVeil(theme: theme, bottom: true)
        cont.addSubview(bveil)
        NSLayoutConstraint.activate([
            bveil.bottomAnchor.constraint(equalTo: cont.bottomAnchor),
            bveil.leadingAnchor.constraint(equalTo: cont.leadingAnchor),
            bveil.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
            bveil.heightAnchor.constraint(equalToConstant: 96),
        ])
        botVeil = bveil
        cont.addSubview(hdr)
        header = hdr
        NSLayoutConstraint.activate([
            cont.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            cont.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            cont.topAnchor.constraint(equalTo: host.topAnchor),
            bc,
            wrap.topAnchor.constraint(equalTo: cont.topAnchor),
            wrap.leadingAnchor.constraint(equalTo: cont.leadingAnchor),
            wrap.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
            t.topAnchor.constraint(equalTo: wrap.topAnchor),
            t.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: Self.bottomOverhang),
            t.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            t.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            hdr.topAnchor.constraint(equalTo: cont.topAnchor),
            hdr.leadingAnchor.constraint(equalTo: cont.leadingAnchor),
            hdr.trailingAnchor.constraint(equalTo: cont.trailingAnchor),
            hdr.heightAnchor.constraint(equalToConstant: hdrH),
        ])
        if let card = NativeInputPlugin.live?.card { host.bringSubviewToFront(card) }
        LXStage.settle(host)
        drawerReady = false
        if let w = call?.getFloat("drawerW"), w > 100 { drawerW = CGFloat(w); drawerReady = true }
        if LustreConfig.webless {
            drawerW = LXDrawer.spec.w
            drawerReady = true
        }
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgePan(_:)))
        edge.edges = .left
        edge.isEnabled = drawerReady
        cont.addGestureRecognizer(edge)
        let closePan = UIPanGestureRecognizer(target: self, action: #selector(closePanH(_:)))
        closePan.delegate = self
        closePan.isEnabled = drawerReady
        cont.addGestureRecognizer(closePan)
        container = cont
        table = t

        data.onReload = { [weak self] stick in self?.paint(stick: stick) }
        data.onDupe = { [weak self] tag, extra in self?.probe(tag, extra) }
        data.onDetach = { [weak self] on, fresh in
            guard let s = self else { return }
            guard on, let cont = s.container else { LXLatestPill.hide(); return }
            LXLatestPill.show(host: cont, fresh: fresh) { [weak s] in
                guard let s = s, let t = s.table else { return }
                s.stickDisarmed = false
                s.forceStick = true
                s.pinToBottom(t)
            }
        }
        data.start(session: sid)
        paintStatus(typing: data.typingOn)
        armPushIntake()

        if LustreConfig.isPreview && LustreConfig.previewFocus == "bubbles" { previewBubbleSampler() }
        if LustreConfig.isPreview && !LustreConfig.previewNarrow {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                guard let s = self else { return }
                var target: Int64? = nil
                var fallback: Int64? = nil
                var skippedNewest = false
                for i in stride(from: s.data.rows.count - 1, through: 0, by: -1) {
                    guard case .thinkHead(let m, _, _, let live) = s.data.rows[i], !live else { continue }
                    if m.text.contains("心率"), target == nil { target = m.id }
                    if fallback == nil {
                        if !skippedNewest { skippedNewest = true } else { fallback = m.id }
                    }
                }
                if let id = target ?? fallback {
                    s.data.expandedThink.insert(id)
                    s.data.rebuild(stick: false)
                }
                if let t = s.table { t.layoutIfNeeded(); s.scrollToBottom(t) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 39) { [weak self] in
                self?.frameSentinelStart()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 40) { [weak self] in
                self?.previewGhostRepro(round: 0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 46) { [weak self] in
                self?.previewFoldCheck()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 31) { [weak self] in
                self?.previewMoonStep()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 104) { [weak self] in
                guard let s = self else { return }
                s.openRPanel()
                s.previewRpThemeCheck()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 112) { [weak self] in
                guard let s = self else { return }
                s.previewMoonStep()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    s.probe("rp-moon-switch", "相=\(RPSpec.moonState) 面板在=\(s.rpanel != nil)")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 124) { [weak self] in self?.closeRPanel() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 125) { [weak self] in
                guard let s = self else { return }
                let tf = CGAffineTransform(translationX: LXDrawer.spec.w, y: 0)
                s.container?.transform = tf
                NativeInputPlugin.live?.card?.transform = tf
                LXVoiceDock.shared?.transform = tf
                LXCallPill.shared?.transform = tf
                HomePlugin.live?.openHomeDrawer()
                if let host = s.bridge?.viewController?.view {
                    for sub in host.subviews where sub is HomeView && sub !== HomePlugin.live?.home { sub.transform = tf }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 128) { DrawerPlugin.previewProbe() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 134) { SysPlugin.live?.open() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 140) {
                UserDefaults.standard.set(true, forKey: ChatListPlugin.avatarsKey)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 137) { [weak self] in
                self?.probe("sys-check", "showing=\(SysPlugin.live?.isShowing ?? false) " + (SysPlugin.live?.sheet?.probe() ?? "sheet=nil") + " moon=\(RPSpec.moonState)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { HomePlugin.live?.previewDismissEarly() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 24) {
                NativeInputPlugin.live?.tv?.becomeFirstResponder()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 14) { [weak self] in
                guard let s = self, let t = s.table else { return }
                for i in stride(from: s.data.rows.count - 1, through: 0, by: -1) {
                    guard case .msg(let m, _, _, _, _) = s.data.rows[i],
                          m.atts.filter({ $0.kind == "image" }).count >= 3 else { continue }
                    let ip = s.rowIP(i)
                    if ip.row < t.numberOfRows(inSection: 0) {
                        t.scrollToRow(at: ip, at: .middle, animated: false)
                    }
                    break
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 24) { [weak self] in
                guard let s = self, let t = s.table else { return }
                s.pinToBottom(t)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 34) { [weak self] in
                guard let s = self, let t = s.table else { return }
                NativeInputPlugin.live?.tv?.resignFirstResponder()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    for i in stride(from: s.data.rows.count - 1, through: 0, by: -1) {
                        guard case .msg(let m, _, _, _, _) = s.data.rows[i],
                              m.id < Int64.max - 8, !m.text.isEmpty else { continue }
                        guard let c = t.cellForRow(at: s.rowIP(i)) as? LXBubbleCell else { continue }
                        s.showMenu(m, bubble: c.bubble)
                        break
                    }
                }
            }
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.syncCardGap()
        }
        timer.tolerance = 0.1
        gapTimer = timer

        kbToken = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notif in
            guard let s = self, let tb = s.table else { return }
            let dur = (notif.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
            s.kbAnimating = true
            _ = tb
            DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.03) {
                s.kbAnimating = false
                s.syncCardGap()
            }
        }

        cont.isHidden = false
        call?.resolve(["ok": true, "v": 4])
    }

    @objc func edgePan(_ g: UIScreenEdgePanGestureRecognizer) {
        guard let cont = container else { return }
        switch g.state {
        case .began:
            drawerBusy = true
            LXDrawer.show(host: bridge?.viewController?.view)
            LXDrawer.place(below: container)
            notifyListeners("chatEdge", data: ["phase": "begin"])
        case .changed:
            let x = min(max(0, g.translation(in: cont).x), drawerW)
            let tf = CGAffineTransform(translationX: x, y: 0)
            cont.transform = tf
            NativeInputPlugin.live?.card?.transform = tf
            LXVoiceDock.shared?.transform = tf
            LXCallPill.shared?.transform = tf
        case .ended, .cancelled, .failed:
            let x = min(max(0, g.translation(in: cont).x), drawerW)
            let vx = g.velocity(in: cont).x
            let shouldOpen = vx > 350 ? true : (vx < -350 ? false : x > drawerW / 2)
            settleDrawer(open: shouldOpen)
            notifyListeners("chatEdge", data: ["phase": "settled", "open": shouldOpen])
        default: break
        }
    }

    private var drawerBaseTx: CGFloat = 0
    @objc func closePanH(_ g: UIPanGestureRecognizer) {
        guard let cont = container else { return }
        switch g.state {
        case .began:
            drawerBaseTx = cont.transform.tx
            drawerBusy = true
        case .changed:
            let x = min(max(0, drawerBaseTx + g.translation(in: cont).x), drawerW)
            let tf = CGAffineTransform(translationX: x, y: 0)
            cont.transform = tf
            NativeInputPlugin.live?.card?.transform = tf
            LXVoiceDock.shared?.transform = tf
            LXCallPill.shared?.transform = tf
        case .ended, .cancelled, .failed:
            let x = cont.transform.tx
            let vx = g.velocity(in: cont).x
            let open = vx > 350 ? true : (vx < -350 ? false : x > drawerW / 2)
            settleDrawer(open: open)
            notifyListeners("chatEdge", data: ["phase": "settled", "open": open])
        default: break
        }
    }

    public func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if let p = g as? UIPanGestureRecognizer, p.view === container, !(p is UIScreenEdgePanGestureRecognizer) {
            guard let c = container, c.transform.tx > 0 else { return false }
            let v = p.velocity(in: c)
            return abs(v.x) > abs(v.y)
        }
        return true
    }

    func nativeOpenDrawer() {
        guard container != nil else { return }
        drawerBusy = true
        LXDrawer.show(host: bridge?.viewController?.view)
        LXDrawer.place(below: container)
        notifyListeners("chatEdge", data: ["phase": "begin"])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.settleDrawer(open: true)
            self.notifyListeners("chatEdge", data: ["phase": "settled", "open": true])
        }
    }

    func freezeWrapHeight(_ on: Bool) {
        guard let w = fadeWrap else { return }
        if on {
            guard wrapFrozenC == nil, w.bounds.height > 1 else { return }
            wrapBotC?.isActive = false
            let c = w.heightAnchor.constraint(equalToConstant: w.bounds.height)
            c.isActive = true
            wrapFrozenC = c
        } else {
            guard wrapFrozenC != nil else { return }
            wrapFrozenC?.isActive = false
            wrapFrozenC = nil
            attachBottomToCard()
        }
    }

    func settleDrawer(open: Bool) {
        guard let cont = container else { return }
        let tf = open ? CGAffineTransform(translationX: drawerW, y: 0) : .identity
        let a = UIViewPropertyAnimator(duration: 0.28,
            controlPoint1: CGPoint(x: 0.22, y: 1), controlPoint2: CGPoint(x: 0.36, y: 1)) {
            cont.transform = tf
            NativeInputPlugin.live?.card?.transform = tf
            LXVoiceDock.shared?.transform = tf
            LXCallPill.shared?.transform = tf
        }
        a.addCompletion { _ in
            if open {
                NativeInputPlugin.live?.tv?.resignFirstResponder()
                self.bridge?.webView?.endEditing(true)
            }
            if !open {
                self.drawerBusy = false
                self.freezeWrapHeight(false)
                self.syncCardGap()
                if self.pendingPaint { self.pendingPaint = false; self.paint(stick: false) }
                LXDrawer.hide()
            }
        }
        a.startAnimation()
        offsetAnimator = a
    }

    @objc private func bgTap() {
        if let cont = container, cont.transform.tx > 0 {
            settleDrawer(open: false)
            notifyListeners("chatEdge", data: ["phase": "settled", "open": false])
            return
        }
        if let p = termPeek { p.closePeek(); termPeek = nil; return }
        NativeInputPlugin.live?.tv?.resignFirstResponder()
        self.bridge?.webView?.endEditing(true)
    }

    private func toggleTermPeek() {
        if let p = termPeek { p.closePeek(); termPeek = nil; return }
        guard let cont = container else { return }
        let p = LXTermPeek(safeTop: safeTopV, host: cont)
        p.start(session: data.session)
        termPeek = p
    }

    private func currentCardGap() -> CGFloat {
        guard let host = self.bridge?.viewController?.view else { return 34 }
        if let np = NativeInputPlugin.live, let c = np.card, !c.isHidden, c.superview != nil {
            let f = c.convert(c.bounds, to: host)
            return max(20, host.bounds.height - f.minY + 8)
        }
        return 34
    }

    private func attachBottomToCard() {
        guard let wrap = fadeWrap, let cont = container else { return }
        let card = NativeInputPlugin.live?.card
        let wantCard = (card?.superview != nil && card?.isHidden == false)
        let onCard = (wrapBotC?.secondItem as? UIView) === card && card != nil
        if wrapBotC?.isActive == true, wantCard == onCard { return }
        wrapBotC?.isActive = false
        if wantCard, let c = card {
            wrapBotC = wrap.bottomAnchor.constraint(equalTo: c.topAnchor, constant: 0)
        } else {
            wrapBotC = wrap.bottomAnchor.constraint(equalTo: cont.bottomAnchor)
        }
        wrapBotC?.isActive = true
    }

    private func syncCardGap() {
        guard let tb = table else { return }
        attachBottomToCard()
        if drawerBusy { return }
        if kbAnimating {
            syncEdgeFades()
            return
        }
        if let cont = container, !drawerBusy {
            let want = cont.isHidden ? .identity : cont.transform
            if let c = NativeInputPlugin.live?.card, c.transform != want { c.transform = want }
        }
        if let cont = container, cont.transform.tx != 0 { return }
        let want = restGapNow + Self.bottomOverhang
        if tb.contentInset.top != want {
            // 头像模式开关换了停靠留白:原来停在最底的,跟着停到新的最底;别的原因回弹 inset 照旧只改 inset
            let atRest = appliedRestGap != restGapNow && abs(tb.contentOffset.y + tb.contentInset.top) < 1
            tb.contentInset.top = want
            tb.verticalScrollIndicatorInsets.top = want
            if atRest { tb.contentOffset.y = -want }
        }
        appliedRestGap = restGapNow
        syncEdgeFades()
    }

    var topFadeV: UIVisualEffectView?
    var botFadeV: UIVisualEffectView?
    var topVeil: LXTopVeil?
    var botVeil: LXTopVeil?
    var fadeWrap: UIView?
    var wrapBotC: NSLayoutConstraint?
    var wrapFrozenC: NSLayoutConstraint?
    var safeTopV: CGFloat = 59
    private func syncEdgeFades() {
        fadeWrap?.layer.mask = nil
        table?.layer.mask = nil
        topFadeV?.removeFromSuperview(); topFadeV = nil
        botFadeV?.removeFromSuperview(); botFadeV = nil
    }

    func syncFadeMask() {}

    @objc func chatDisable(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.teardown()
            call.resolve(["ok": true])
        }
    }

    private func teardown() {
        gapTimer?.invalidate(); gapTimer = nil
        if let k = kbToken { NotificationCenter.default.removeObserver(k); kbToken = nil }
        LXVoiceBar.stopAll()
        closeMenu()
        termPeek?.closePeek(); termPeek = nil
        if multiOn { exitMulti() }
        data.stop()
        container?.removeFromSuperview()
        container = nil; table = nil; bottomC = nil; header = nil; topFadeV = nil; botFadeV = nil; fadeWrap = nil; topVeil = nil; botVeil = nil
        wallV = nil; scrimV = nil; defWallV = nil
        NativeInputPlugin.live?.card?.transform = .identity
        LXVoiceDock.shared?.transform = .identity
        LXCallPill.shared?.transform = .identity
        drawerBusy = false
        LXDrawer.hide()
    }

    @objc func chatSession(_ call: CAPPluginCall) {
        let sid = call.getString("session") ?? "__legacy__"
        DispatchQueue.main.async {
            guard self.container != nil else { call.resolve(["ok": false]); return }
            self.switchTo(sid)
            call.resolve(["ok": true])
        }
    }

    func switchTo(_ sid: String) {
        guard Thread.isMainThread, container != nil else { return }
        do {
            self.closeMenu()
            if self.multiOn { self.exitMulti() }
            self.termPeek?.closePeek(); self.termPeek = nil
            if let c = self.container, c.transform.tx > 0 {
                self.settleDrawer(open: false)
                self.notifyListeners("chatEdge", data: ["phase": "settled", "open": false])
            }
            LXVoiceBar.stopAll()
            self.stickDisarmed = false
            self.forceStick = true
            self.pinUntil = Date().addingTimeInterval(1.5)
            if let t = self.table {
                t.isHidden = true
                self.data.switchSession(sid)
                LXOutbox.shared.reinject(session: self.data.session)
                self.pinToBottom(t)
                DispatchQueue.main.async { [weak self] in
                    guard let s = self, let t2 = s.table else { return }
                    s.pinToBottom(t2)
                    t2.isHidden = false
                }
            } else {
                self.data.switchSession(sid)
            }
        }
        UserDefaults.standard.set(sid, forKey: "lx.sessionPick")
        NativeInputPlugin.live?.refreshModelTitle()
        if LustreConfig.webless {
            HomePlugin.live?.leaveHome()
            NativeInputPlugin.live?.setCardHidden(false)
        }
        LXSessionsAPI.markActive(sid)
        paintStatus(typing: data.typingOn)
        guard sid != "__legacy__", !sid.isEmpty,
              let u = URL(string: LustreConfig.apiBase + "/app/sessions/"
                          + (sid.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? sid)) else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "PATCH"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["active": true])
        URLSession.shared.dataTask(with: r).resume()
    }

    func previewMoonStep() {
        if LustreConfig.webless { switchMoon(LXMoonPalette.next(RPSpec.moonState)) }
        else { webAct(["act": "rpClick", "id": "themeMoon"]) }
    }
    static let avatarsKey = "lx.chat.avatarsOn"
    func askPat(_ m: LXMsg) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let ai = LXNick.of(session: m.session)
        // 0925 她的单:动作也能改;每个人各记各的,下次双击还是上回那个
        let key = "lx.pat.act." + m.session
        let kb: UIKeyboardAppearance = RPSpec.moonState == "day" ? .light : .dark
        let a = UIAlertController(title: ai, message: nil, preferredStyle: .alert)
        a.addTextField { tf in
            tf.text = UserDefaults.standard.string(forKey: key) ?? "拍了拍"
            tf.placeholder = "拍了拍"
            tf.clearButtonMode = .whileEditing
            tf.keyboardAppearance = kb
        }
        a.addTextField { tf in
            tf.placeholder = "想说的话（可以不填）"
            tf.returnKeyType = .send
            tf.keyboardAppearance = kb
        }
        a.addAction(UIAlertAction(title: "取消", style: .cancel))
        a.addAction(UIAlertAction(title: "发送", style: .default) { [weak self, weak a] _ in
            let fs = a?.textFields ?? []
            let act = (fs.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let t = (fs.last?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(act.isEmpty ? "拍了拍" : act, forKey: key)
            var body: [String: Any] = ["text": t]
            if !act.isEmpty { body["act"] = act }
            if !m.session.isEmpty { body["api_session"] = m.session }
            self?.data.post("/app/pat", body) { ok in
                DispatchQueue.main.async { if !ok { self?.toast("没拍到，再试试") } }
            }
        })
        // 光标直接落在"想说的话":动作记住了,平时只打话
        DrawerPlugin.topVC()?.present(a, animated: true) { _ = a.textFields?.last?.becomeFirstResponder() }
    }

    func toggleVoiceText(_ id: Int64) {
        if LXBubbleCell.voiceOpen.contains(id) { LXBubbleCell.voiceOpen.remove(id) } else { LXBubbleCell.voiceOpen.insert(id) }
        guard let t = table, let i = data.rows.firstIndex(where: { if case .msg(let m, _, _, _, _) = $0 { return m.id == id }; return false }) else { return }
        let ip = rowIP(i)
        guard ip.row < t.numberOfRows(inSection: 0) else { return }
        UIView.performWithoutAnimation {
            reconfigureVisible(t, at: ip)
            t.beginUpdates(); t.endUpdates()
        }
    }

    func showThinkSheet(for m: LXMsg) {
        let thoughts = data.thinkingForGroup(startingAt: m.id)
        guard !thoughts.isEmpty else { LXToast.show("这几条没有思考过程", host: bridge?.viewController?.view); return }
        guard let host = bridge?.viewController?.view else { return }
        LXThinkOverlay.show(host: host, title: "Thought process",
                            text: thoughts.map { $0.text }.joined(separator: "\n\n"), theme: theme)
    }

    func rpToggleAvatars() {
        let on = !theme.avatars
        theme.avatars = on
        UserDefaults.standard.set(on, forKey: Self.avatarsKey)
        rpSetVal("chatAvatarsRow", on ? "On" : "Off")
        if on { LXAvatarStore.ensureDefaults() }
        UIView.performWithoutAnimation { reloadTable(table) }
    }

    func switchMoon(_ m: String) {
        guard LXMoonPalette.order.contains(m) else { return }
        RPSpec.moonState = m
        LXMoonPalette.persist(m)
        let avatars = theme.avatars
        theme = LXChatTheme()
        theme.loadCached(m)
        theme.avatars = avatars
        rpanel?.retheme()
        SysPlugin.live?.retheme()
        if let dv = LXDrawer.view, !dv.isHidden { dv.apply(LXDrawer.spec, moon: m) }
        if let cd = LXMoonPalette.card[m] {
            NativeInputPlugin.live?.applyCardTheme(LXFakeCall.make("cardState", cd))
        }
        container?.backgroundColor = theme.bg
        applyWall()
        header?.apply(theme)
        topVeil?.apply(theme)
        botVeil?.apply(theme)
        syncEdgeFades()
        UIView.performWithoutAnimation { reloadTable(table) }
    }

    @objc func chatTheme(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.theme.take(call)
            if let m = call.getString("moon"), ["day", "half", "moon"].contains(m), m != RPSpec.moonState {
                RPSpec.moonState = m
                self.rpanel?.retheme()
                SysPlugin.live?.retheme()
            }
            self.container?.backgroundColor = self.theme.bg
            self.applyWall()
            self.header?.apply(self.theme)
            self.topVeil?.apply(self.theme)
            self.botVeil?.apply(self.theme)
            self.syncEdgeFades()
            self.reloadTable(self.table)
            call.resolve(["ok": true])
        }
    }

    @objc func chatAvatars(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let on = call.getBool("on") ?? false
            for k in ["ai", "human", "zhao"] {
                if let src = call.getString(k), !src.isEmpty { LXAvatarStore.set(k, source: src) }
            }
            LXAvatarStore.onChange = { [weak self] in
                self?.table?.visibleCells.forEach { ($0 as? LXBubbleCell)?.refreshAvatar() }
            }
            if self.theme.avatars != on {
                self.theme.avatars = on
                self.reloadTable(self.table)
            }
            self.probe("avatar-set", "on=\(on) imgs=\(LXAvatarStore.images.keys.sorted())")
            call.resolve(["ok": true])
        }
    }

    func applyWall() {
        let img = LXWallStore.image
        wallV?.image = img
        wallV?.isHidden = (img == nil)
        scrimV?.isHidden = (img == nil)
        defWallV?.isHidden = !(img == nil && RPSpec.moonState == "day")
        let color: UIColor
        let alphas: [CGFloat]
        switch RPSpec.moonState {
        case "half": color = UIColor(red: 25/255, green: 25/255, blue: 23/255, alpha: 1); alphas = [0.42, 0.12, 0.05, 0.26]
        case "moon": color = .black; alphas = [0.50, 0.14, 0.05, 0.34]
        default:     color = .white; alphas = [0.38, 0.12, 0.04, 0.22]
        }
        scrimV?.set(color: color, alphas: alphas, locations: [0, 0.30, 0.68, 1])
        adaptTextToWall(img)
    }

    private static var lumCache: (ObjectIdentifier, CGFloat)?
    static func luminance(_ img: UIImage) -> CGFloat? {
        if let c = lumCache, c.0 == ObjectIdentifier(img) { return c.1 }
        guard let cg = img.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let crop = CGRect(x: w / 5, y: h / 5, width: w * 3 / 5, height: h * 3 / 5)
        guard let part = cg.cropping(to: crop) else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(part, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let l = (0.2126 * CGFloat(px[0]) + 0.7152 * CGFloat(px[1]) + 0.0722 * CGFloat(px[2])) / 255
        lumCache = (ObjectIdentifier(img), l)
        return l
    }

    func adaptTextToWall(_ img: UIImage?) {
        let pal = LXMoonPalette.chat[RPSpec.moonState] ?? [:]
        var me = (pal["meFg"] as? String).flatMap { NativeInputPlugin.color($0) } ?? theme.meFg
        var ai = (pal["aiFg"] as? String).flatMap { NativeInputPlugin.color($0) } ?? theme.aiFg
        if let img = img, let l = Self.luminance(img) {
            let fg = l > 0.55 ? UIColor(red: 0x1D/255, green: 0x1D/255, blue: 0x1F/255, alpha: 1) : UIColor.white
            me = fg; ai = fg
        }
        guard !theme.meFg.isEqual(me) || !theme.aiFg.isEqual(ai) else { return }
        theme.meFg = me; theme.aiFg = ai
        UIView.performWithoutAnimation { reloadTable(table) }
    }

    @objc func callPill(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        let startedMs = call.getDouble("started") ?? (Date().timeIntervalSince1970 * 1000)
        DispatchQueue.main.async {
            if on, let host = self.bridge?.viewController?.view {
                LXCallPill.show(host: host, started: Date(timeIntervalSince1970: startedMs / 1000)) { [weak self] in
                    self?.notifyListeners("callPill", data: ["act": "expand"])
                }
            } else {
                LXCallPill.hide()
            }
            call.resolve(["ok": true])
        }
    }

    @objc func chatWall(_ call: CAPPluginCall) {
        let src = call.getString("wall") ?? ""
        DispatchQueue.main.async {
            LXWallStore.set(source: src)
            self.applyWall()
            call.resolve(["ok": true, "has": LXWallStore.image != nil])
        }
    }

    /// 预览 bubbles 路线:一整页样板气泡盖在窗口最上面,真聊天藏起来;每秒再藏一次列表、再把样板页提到最上
    private var bubbleSamplerDone = false
    func previewBubbleSampler(tries: Int = 0) {
        guard LustreConfig.isPreview, !bubbleSamplerDone else { return }
        guard let t = table, let win = bridge?.viewController?.view.window else {
            if tries < 40 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.previewBubbleSampler(tries: tries + 1) }
            }
            return
        }
        bubbleSamplerDone = true
        t.isHidden = true
        let page = LXBubbleSampler(frame: win.bounds)
        page.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        win.addSubview(page)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self, weak page] tm in
            guard let s = self, let p = page else { tm.invalidate(); return }
            s.table?.isHidden = true
            p.superview?.bringSubviewToFront(p)
        }
    }

    private var composerTourDone = false
    /// 预览专用(路线 composer):只拍头像模式输入栏。直接进聊天页放出输入栏,
    /// 0–20 秒空栏、20–40 秒框里有字(发送键该露出来)、40–60 秒录音中(红圆+红点计时+×),之后收回空栏
    func previewComposerTour() {
        guard LustreConfig.isPreview, !composerTourDone, let t = table else { return }
        composerTourDone = true
        theme.avatars = true
        // 这条路线的截图只要输入栏:聊天列表整个藏起来,屏幕上不留任何对话内容;每秒再藏一次,防别处把它放回来
        t.isHidden = true
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] tm in
            guard let s = self else { tm.invalidate(); return }
            s.table?.isHidden = true
        }
        UIView.performWithoutAnimation { reloadTable(t) }
        HomePlugin.live?.previewDismissEarly()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            HomePlugin.live?.previewDismissEarly()   // 首页晚挂上来的话再摘一次
            guard let s = self, let t = s.table else { return }
            s.pinToBottom(t)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
            NativeInputPlugin.live?.previewComposer(text: "Preview")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 40) {
            NativeInputPlugin.live?.previewComposer(text: "")
            NativeInputPlugin.live?.enterRecUI()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
            NativeInputPlugin.live?.exitRecUI()
        }
        // 0926:白天的发送键、光标要跟月夜一模一样——63 秒切到白天(只存在模拟器本地),空栏拍一轮,72 秒起框里有字
        DispatchQueue.main.asyncAfter(deadline: .now() + 63) { [weak self] in self?.switchMoon("day") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 72) {
            NativeInputPlugin.live?.previewComposer(text: "Preview")
        }
    }

    private var avaCheckDone = false
    /// 预览专用:头像模式 + 模拟"正在想"的每秒重排,数 10 秒里有没有多余的整表重配、有没有时间画出自己那一行
    func previewAvaTimeCheck() {
        guard LustreConfig.isPreview, !avaCheckDone, let t = table else { return }
        avaCheckDone = true
        theme.avatars = true
        UIView.performWithoutAnimation { reloadTable(t) }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        data.handle(["type": "thinking_delta", "stream_id": "ava-check", "api_session": "",
                     "text": "模拟正在想", "done": false, "ts": iso.string(from: Date())])
        let start = fullPaints
        var frames = 0, outside = 0, shown = 0
        let link = CADisplayLink(target: LXBlockTarget { [weak self, weak t] in
            guard let s = self, let t = t else { return }
            frames += 1
            for c in t.visibleCells {
                guard let b = c as? LXBubbleCell, b.timeShownUnderAvatar else { continue }
                shown += 1
                let f = b.timeFrameInCell
                if f.minY < -0.5 || f.maxY > b.bounds.height + 0.5 { outside += 1 }
            }
            _ = s
        }, selector: #selector(LXBlockTarget.fire))
        link.add(to: .main, forMode: .common)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            link.invalidate()
            guard let s = self else { return }
            s.data.handle(["type": "thinking_delta", "stream_id": "ava-check", "api_session": "",
                           "text": "", "done": true, "ts": iso.string(from: Date())])
            s.probe("ava-time-check", "帧=\(frames) 时间出现=\(shown) 出框=\(outside) 10秒内整表重配=\(s.fullPaints - start)")
        }
    }

    private func probe(_ tag: String, _ extra: String = "") {
        guard let u = URL(string: LustreConfig.apiBase + "/app/kbdebug") else { return }
        var r = URLRequest(url: u)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["tag": "echo-native", "step": tag, "extra": extra])
        URLSession.shared.dataTask(with: r).resume()
    }

    @objc func chatPoke(_ call: CAPPluginCall) {
        let echo = (call.getString("text") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let echoSid = call.getString("session") ?? ""
        var echoAtts: [LXAtt] = []
        if let arr = call.getArray("atts") {
            for v in arr {
                guard let d = v as? [String: Any], let u = d["url"] as? String, !u.isEmpty else { continue }
                echoAtts.append(LXAtt(kind: (d["kind"] as? String) ?? "file", url: u,
                                      name: (d["name"] as? String) ?? "文件",
                                      mime: (d["mime"] as? String) ?? "",
                                      size: (d["size"] as? NSNumber)?.intValue ?? 0,
                                      duration: (d["duration"] as? NSNumber)?.intValue ?? 0))
            }
        }
        DispatchQueue.main.async {
            if self.data.detached { self.data.returnToLive() }
            self.stickDisarmed = false
            self.forceStick = true
            let sidOK = echoSid.isEmpty || echoSid == self.data.session
            if (!echo.isEmpty || !echoAtts.isEmpty) && sidOK {
                self.probe("poke-in", "len=\(echo.count) busy=\(self.drawerBusy)")
                self.data.addOptimistic(text: echo, atts: echoAtts)
                self.probe("optimistic-done", "rows=\(self.data.rows.count)")
            }
            if let t = self.table {
                self.pinToBottom(t)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                    guard let s = self, let t2 = s.table else { return }
                    s.syncCardGap()
                    s.pinToBottom(t2)
                    s.probe("restick", "inset=\(Int(t2.adjustedContentInset.bottom))")
                }
            }
        }
        Task { [weak self] in await self?.data.refetchSince() }
        call.resolve(["ok": true])
    }

    @objc func chatStatus(_ call: CAPPluginCall) {
        let text = call.getString("text") ?? ""
        let typing = call.getBool("typing") ?? false
        DispatchQueue.main.async {
            self.header?.statusL.text = text
            self.header?.setTyping(typing, color: self.theme.pillFg)
            call.resolve(["ok": true])
        }
    }

    func paintStatus(typing: Bool) {
        // 0926 她的单:顶上这行平时显示的名字跟备注走(原来写死英文名)
        header?.statusL.text = typing ? "typing to you" : LXNick.of(session: data.session)
        header?.setTyping(typing, color: theme.pillFg)
    }

    private var offsetAnimator: UIViewPropertyAnimator?
    @objc func chatOffset(_ call: CAPPluginCall) {
        let x = CGFloat(call.getFloat("x") ?? 0)
        let animate = call.getBool("animate") ?? false
        DispatchQueue.main.async {
            guard let cont = self.container else { call.resolve(["ok": false]); return }
            if x != 0 { self.drawerBusy = true; LXDrawer.show(host: self.bridge?.viewController?.view); LXDrawer.place(below: cont) }
            self.offsetAnimator?.stopAnimation(true)
            self.offsetAnimator = nil
            let tf = x == 0 ? CGAffineTransform.identity : CGAffineTransform(translationX: x, y: 0)
            let cardTf = tf
            let finish: () -> Void = {
                if x == 0 {
                    self.drawerBusy = false
                    self.syncCardGap()
                    if self.pendingPaint { self.pendingPaint = false; self.paint(stick: false) }
                    LXDrawer.hide()
                }
            }
            if animate {
                let a = UIViewPropertyAnimator(duration: 0.28,
                    controlPoint1: CGPoint(x: 0.22, y: 1), controlPoint2: CGPoint(x: 0.36, y: 1)) {
                    cont.transform = tf
                    NativeInputPlugin.live?.card?.transform = cardTf
                    LXVoiceDock.shared?.transform = cardTf
                    LXCallPill.shared?.transform = cardTf
                }
                a.addCompletion { _ in finish() }
                a.startAnimation()
                self.offsetAnimator = a
            } else {
                cont.transform = tf
                NativeInputPlugin.live?.card?.transform = cardTf
                LXVoiceDock.shared?.transform = cardTf
                LXCallPill.shared?.transform = cardTf
                finish()
            }
            call.resolve(["ok": true])
        }
    }

    @objc func chatJump(_ call: CAPPluginCall) {
        let id = Int64(call.getInt("id") ?? 0)
        guard id > 0 else { call.resolve(["ok": false]); return }
        jumpToMessage(id) { ok in call.resolve(["ok": ok]) }
    }

    func jumpToMessage(_ id: Int64, done: ((Bool) -> Void)? = nil) {
        Task { [weak self] in
            guard let s = self else { return }
            let found = await s.data.ensureLoaded(id)
            await MainActor.run {
                guard found, let t = s.table else {
                    if LustreConfig.webless { LXToast.show("没找到这条消息", host: s.container) }
                    done?(false); return
                }
                var isThink = false
                for r in s.data.rows {
                    if case .thinkHead(let m, _, _, _) = r, m.id == id { isThink = true; break }
                }
                if isThink, !s.data.expandedThink.contains(id) {
                    s.data.expandedThink.insert(id)
                    s.data.rebuild(stick: false)
                }
                var idx = -1
                for (i, r) in s.data.rows.enumerated() {
                    switch r {
                    case .msg(let m, _, _, _, _): if m.id == id { idx = i }
                    case .thinkHead(let m, _, _, _): if m.id == id { idx = i }
                    default: break
                    }
                    if idx >= 0 { break }
                }
                guard idx >= 0 else { done?(false); return }
                s.stickDisarmed = true
                (t as? LXStickyTable)?.stickBottom = false
                let ip = s.rowIP(idx)
                t.scrollToRow(at: ip, at: .middle, animated: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    guard let cell = t.cellForRow(at: ip) else { return }
                    let orig = cell.contentView.backgroundColor
                    UIView.animate(withDuration: 0.22, animations: {
                        cell.contentView.backgroundColor = s.theme.accent.withAlphaComponent(0.16)
                    }) { _ in
                        UIView.animate(withDuration: 0.7) { cell.contentView.backgroundColor = orig }
                    }
                }
                done?(true)
            }
        }
    }

    @objc func chatHide(_ call: CAPPluginCall) {
        let hide = call.getBool("on") ?? true
        let wantSnap = call.getBool("snap") ?? false
        DispatchQueue.main.async {
            var out: [String: Any] = ["ok": true]
            if hide, wantSnap, let cont = self.container, !cont.isHidden {
                let img = UIGraphicsImageRenderer(bounds: cont.bounds).image { _ in
                    cont.drawHierarchy(in: cont.bounds, afterScreenUpdates: false)
                }
                if let d = img.jpegData(compressionQuality: 0.8) {
                    out["snap"] = "data:image/jpeg;base64," + d.base64EncodedString()
                }
            }
            self.container?.isHidden = hide
            self.container?.alpha = 1
            self.container?.isUserInteractionEnabled = !hide
            if hide {
                let wasOpen = (self.container?.transform.tx ?? 0) > 0
                self.container?.transform = .identity
                NativeInputPlugin.live?.card?.transform = .identity
                LXVoiceDock.shared?.transform = .identity
                LXCallPill.shared?.transform = .identity
                self.drawerBusy = false
                if !(HomePlugin.live?.homeDrawerOpen ?? false) { LXDrawer.hide() }
                if wasOpen {
                    self.notifyListeners("chatEdge", data: ["phase": "settled", "open": false])
                }
            }
            call.resolve(out)
        }
    }


    private var lastRowCount = 0
    private var lastTailSig = ""
    private var lastDecoSig = ""
    private var lastOrderHash = 0
    private var lastTableKeys: [Int] = []
    private var lastContentSig = 0
    private var fullPaints = 0
    private func reloadTable(_ t: UITableView?) {
        guard let t = t else { return }
        stopGlides(t)
        t.reloadData()
        t.layoutIfNeeded()
    }
    private func applyKeyedDiff(_ t: UITableView, old: [Int], new: [Int]) -> Bool {
        guard !old.isEmpty, t.numberOfRows(inSection: 0) == old.count else { return false }
        guard Set(old).count == old.count, Set(new).count == new.count else { return false }
        let newSet = Set(new), oldSet = Set(old)
        guard !oldSet.isDisjoint(with: newSet) else { return false }
        guard old.filter({ newSet.contains($0) }) == new.filter({ oldSet.contains($0) }) else { return false }
        let dels = old.enumerated().filter { !newSet.contains($0.element) }.map { IndexPath(row: $0.offset, section: 0) }
        let ins = new.enumerated().filter { !oldSet.contains($0.element) }.map { IndexPath(row: $0.offset, section: 0) }
        UIView.performWithoutAnimation {
            if !dels.isEmpty || !ins.isEmpty {
                t.performBatchUpdates {
                    if !dels.isEmpty { t.deleteRows(at: dels, with: .none) }
                    if !ins.isEmpty { t.insertRows(at: ins, with: .none) }
                }
            }
            for ip in t.indexPathsForVisibleRows ?? [] { reconfigureVisible(t, at: ip) }
            t.beginUpdates(); t.endUpdates()
        }
        return true
    }

    private func rowKey(_ r: LXRow) -> Int {
        switch r {
        case .day(let s): return Int(truncatingIfNeeded: Int64(s.hashValue) &* 8 &+ 1)
        case .msg(let m, _, _, _, _): return Int(truncatingIfNeeded: (m.echoId != 0 ? m.echoId : m.id) &* 8 &+ 2)
        case .thinkHead(let m, _, _, _): return Int(truncatingIfNeeded: m.id &* 8 &+ 3)
        case .thinkBody(let m): return Int(truncatingIfNeeded: m.id &* 8 &+ 4)
        case .foot: return 5
        case .typing: return 6
        }
    }
    private var lastHeightSettle = Date.distantPast
    private var trailingSettle: DispatchWorkItem?
    private var liveHLog: [String] = []
    private func rowSig(_ r: LXRow) -> String {
        switch r {
        case .day(let s): return "d:" + s
        case .msg(let m, _, _, _, _): return "m:\(m.id)"
        case .thinkHead(let m, let open, _, let live): return "th:\(m.id):\(open):\(live)"
        case .thinkBody(let m): return "tb:\(m.id)"
        case .typing: return "ty"
        case .foot: return "f"
        }
    }
    private func paint(stick: Bool) {
        guard let t = table else { return }
        if drawerBusy { pendingPaint = true; return }
        var contentEnd = data.rows.count
        var decoSig = ""
        deco: while contentEnd > 0 {
            switch data.rows[contentEnd - 1] {
            case .foot: decoSig += "f"; contentEnd -= 1
            case .typing: decoSig += "t"; contentEnd -= 1
            default: break deco
            }
        }
        let decoCount = data.rows.count - contentEnd
        let contentTail = contentEnd > 0 ? rowSig(data.rows[contentEnd - 1]) : ""
        var hAll = Hasher()
        for i in 0..<contentEnd { hAll.combine(rowKey(data.rows[i])) }
        let orderHash = hAll.finalize()
        var hPre = Hasher()
        if lastRowCount > 0, lastRowCount <= contentEnd {
            for i in 0..<lastRowCount { hPre.combine(rowKey(data.rows[i])) }
        }
        let prefixHash = hPre.finalize()
        let newTableKeys = data.rows.reversed().map(rowKey)
        if contentEnd == lastRowCount, lastRowCount > 0, decoSig == lastDecoSig,
           contentTail == lastTailSig, orderHash == lastOrderHash,
           liveTailRefresh(t, stick: stick) { lastTableKeys = newTableKeys; return }
        // 0925 根治:思考计时每秒重排一次,行一条没变也把所有可见行重配+重算行高——没变就什么都不做
        var hC = Hasher()
        for r in data.rows {
            hC.combine(hKey(r))
            if case .msg(let m, _, _, _, _) = r {   // 回执换真 id / 星标 / 时长 / 附件地址 这些 hKey 里没有的也算"变了"
                hC.combine(m.id); hC.combine(m.starred); hC.combine(m.durSec); hC.combine(m.servesId)
                for a in m.atts { hC.combine(String(describing: a)) }
            }
        }
        hC.combine(data.echoPending.count)
        let contentSig = hC.finalize()
        if contentSig == lastContentSig, newTableKeys == lastTableKeys, decoSig == lastDecoSig,
           t.numberOfRows(inSection: 0) == data.rows.count { return }
        lastContentSig = contentSig
        fullPaints += 1
        let tailOK = lastRowCount > 0 && lastRowCount <= contentEnd && prefixHash == lastOrderHash
        if contentEnd > lastRowCount, lastRowCount > 0, tailOK, decoSig == lastDecoSig,
           t.numberOfRows(inSection: 0) == lastRowCount + decoCount, !drawerBusy {
            let added = contentEnd - lastRowCount
            let inserted = (0..<added).map { IndexPath(row: decoCount + $0, section: 0) }
            let retail = IndexPath(row: decoCount + added, section: 0)
            let nearBottom = self.nearBottom(t)
            let dist = endDist(t)
            // 0925 录屏逐帧:新气泡插在底下那一帧,上面所有旧气泡整片瞬移上去(一帧跳)。
            // 插之前记下它们在屏幕上的位置,插完整张表从原位滑到新位置(glide)。
            let before = screenFrames(t)
            var stuck = false
            UIView.performWithoutAnimation {
                t.performBatchUpdates { t.insertRows(at: inserted, with: .none) }
                if retail.row < t.numberOfRows(inSection: 0) {
                    reconfigureVisible(t, at: retail)
                }
                if stick && !stickDisarmed && !(t.isTracking || t.isDragging || t.isDecelerating) && (forceStick || nearBottom || Date() < pinUntil) {
                    if Date() < pinUntil { self.pinToBottom(t) } else { self.scrollToBottom(t) }
                    forceStick = false
                    stuck = true
                } else {
                    self.anchorToEnd(t, dist)
                }
                t.layoutIfNeeded()
            }
            if stuck { glide(t, before: before, keys: newTableKeys) }
            lastRowCount = contentEnd
            lastTailSig = contentTail
            lastDecoSig = decoSig
            lastOrderHash = orderHash
            lastTableKeys = newTableKeys
            scheduleVerify(t)
            return
        }
        lastRowCount = contentEnd
        lastTailSig = contentTail
        lastDecoSig = decoSig
        lastOrderHash = orderHash

        let nearBottom = self.nearBottom(t)
        let userScrolling = t.isTracking || t.isDragging || t.isDecelerating
        let dist = endDist(t)
        let before = screenFrames(t)
        let diffed = applyKeyedDiff(t, old: lastTableKeys, new: newTableKeys)
        lastTableKeys = newTableKeys
        var stuck = false
        UIView.performWithoutAnimation {
            if !diffed { reloadTable(t) }
            if stick && !userScrolling && !stickDisarmed && (forceStick || nearBottom || Date() < pinUntil || t.contentSize.height <= t.bounds.height) {
                if Date() < pinUntil { self.pinToBottom(t) } else { self.scrollToBottom(t) }
                forceStick = false
                stuck = true
            } else {
                self.anchorToEnd(t, dist)
            }
            t.layoutIfNeeded()
        }
        if stuck && diffed { glide(t, before: before, keys: newTableKeys) }
        scheduleVerify(t)
    }


    private func liveTailRefresh(_ t: UITableView, stick: Bool) -> Bool {
        var touched = false
        var heightChanged = false
        let n = data.rows.count
        func noteHeight(_ i: Int) {
            let want = rowHeightFor(rowIP(i).row, width: t.bounds.width)
            let have = t.rectForRow(at: rowIP(i)).height
            if abs(want - have) > 0.5 { heightChanged = true }
            if LustreConfig.isPreview {
                var tl = -1
                if case .thinkBody(let m) = data.rows[i] { tl = m.text.count }
                liveHLog.append("\(Int(want))/\(Int(have))\(abs(want - have) > 0.5 ? "!" : "")\(tl >= 0 ? ":\(tl)" : "")")
                if liveHLog.count >= 40 {
                    probe("live-h", liveHLog.joined(separator: " "))
                    liveHLog.removeAll()
                }
            }
        }
        if data.liveRowIdx >= 0 {
            for i in [data.liveRowIdx, data.liveRowIdx + 1] where i < n {
                guard let cell = t.cellForRow(at: rowIP(i)) else { continue }
                switch data.rows[i] {
                case .thinkHead(_, let open, let label, let live) where live:
                    (cell as? LXThinkHeadCell)?.configure(label: label, open: open, live: live, theme: theme)
                    touched = true; noteHeight(i)
                case .thinkBody(let m) where m.id == LXChatData.liveThinkId:
                    (cell as? LXThinkBodyCell)?.configure(m.text, live: true, theme: theme)
                    touched = true; noteHeight(i)
                default: continue
                }
            }
        }
        for i in stride(from: n - 1, through: max(0, n - 3), by: -1) {
            if i == data.liveRowIdx || i == data.liveRowIdx + 1 { continue }
            guard let cell = t.cellForRow(at: rowIP(i)) else { continue }
            switch data.rows[i] {
            case .msg(let m, let st, let tl, let gp, let at) where m.id == Int64.max:
                (cell as? LXBubbleCell)?.configure(m, showTime: st, tail: tl, grouped: gp, afterThink: at, theme: theme, cellW: t.bounds.width, avaTime: avaTimeFor(i, width: t.bounds.width))
                touched = true; noteHeight(i)
            case .thinkHead(_, let open, let label, let live) where live:
                (cell as? LXThinkHeadCell)?.configure(label: label, open: open, live: live, theme: theme)
                touched = true; noteHeight(i)
            case .thinkBody(let m) where m.id == LXChatData.liveThinkId:
                (cell as? LXThinkBodyCell)?.configure(m.text, live: true, theme: theme)
                touched = true; noteHeight(i)
            default: continue
            }
        }
        if !data.echoPending.isEmpty {
            for id in Array(data.echoPending) {
                guard let i = data.rows.lastIndex(where: { if case .msg(let m, _, _, _, _) = $0 { return m.id == id } else { return false } }) else {
                    data.echoPending.remove(id); continue
                }
                guard i < n, let cell = t.cellForRow(at: rowIP(i)) as? LXBubbleCell else { continue }
                if case .msg(let m, let st, let tl, let gp, let at) = data.rows[i] {
                    cell.configure(m, showTime: st, tail: tl, grouped: gp, afterThink: at, theme: theme, cellW: t.bounds.width, avaTime: avaTimeFor(i, width: t.bounds.width))
                    touched = true; noteHeight(i)
                }
                data.echoPending.remove(id)
            }
        }
        guard touched else { return false }
        let now = Date()
        let settle = heightChanged && now.timeIntervalSince(lastHeightSettle) > 0.2
        if settle { lastHeightSettle = now; trailingSettle?.cancel(); trailingSettle = nil }
        if heightChanged, !settle, trailingSettle == nil {
            let wait = max(0.02, 0.2 - now.timeIntervalSince(lastHeightSettle) + 0.01)
            let w = DispatchWorkItem { [weak self] in
                guard let s = self, let t = s.table else { return }
                s.trailingSettle = nil
                guard !s.drawerBusy, t.numberOfRows(inSection: 0) == s.data.rows.count else { return }
                s.lastHeightSettle = Date()
                let nearB2 = s.nearBottom(t)
                let dist2 = s.endDist(t)
                UIView.performWithoutAnimation {
                    t.beginUpdates(); t.endUpdates()
                    if stick && !s.stickDisarmed && !(t.isTracking || t.isDragging || t.isDecelerating) && nearB2 {
                        s.scrollToBottom(t)
                    } else {
                        s.anchorToEnd(t, dist2)
                    }
                }
            }
            trailingSettle = w
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: w)
        }
        let nearB = self.nearBottom(t)
        let dist = endDist(t)
        UIView.performWithoutAnimation {
            if settle, t.numberOfRows(inSection: 0) == data.rows.count { t.beginUpdates(); t.endUpdates() }
            if stick && !stickDisarmed && !(t.isTracking || t.isDragging || t.isDecelerating) && nearB {
                self.scrollToBottom(t)
            } else if settle {
                self.anchorToEnd(t, dist)
            }
        }
        return true
    }

    /// 可见行此刻在屏幕上的位置,按改动前的行 key 记
    private func screenFrames(_ t: UITableView) -> [Int: CGRect] {
        var out: [Int: CGRect] = [:]
        for ip in t.indexPathsForVisibleRows ?? [] where ip.row < lastTableKeys.count {
            if let c = t.cellForRow(at: ip) { out[lastTableKeys[ip.row]] = c.convert(c.bounds, to: nil) }
        }
        return out
    }

    /// 0925 录屏逐帧根治"发出去那一帧,每个气泡下半截被切掉":以前是把每一行的内容往回挪、再滑上去,
    /// 可 UITableView 插行/删行那一帧会按行框把每一行裁一次,挪出行框的那截就被切了。
    /// 现在谁的内容都不离开自己那一行:整张表的行作为一个整体,从改动前的位置沿发送曲线滑到新位置
    /// (叠加在表的 sublayerTransform 上,不改表和行的真实位置;新行在最底下跟着一起升上来)。
    private var glideN = 0
    private func glide(_ t: UITableView, before: [Int: CGRect], keys: [Int]) {
        guard !before.isEmpty, !UIAccessibility.isReduceMotionEnabled, t.transform.d != 0 else { return }
        // 参照:改动前后都在、离屏幕底最近的那一行——新消息就长在它下面
        var ref: (bottom: CGFloat, dy: CGFloat)?
        for ip in t.indexPathsForVisibleRows ?? [] where ip.row < keys.count {
            guard let old = before[keys[ip.row]], let c = t.cellForRow(at: ip) else { continue }
            let now = c.convert(c.bounds, to: nil)
            if ref == nil || now.maxY > ref!.bottom { ref = (now.maxY, old.midY - now.midY) }
        }
        guard let dy = ref?.dy, abs(dy) > 0.5, abs(dy) < t.bounds.height else { return }
        let a = CABasicAnimation(keyPath: "sublayerTransform.translation.y")
        a.isAdditive = true
        a.fromValue = dy / t.transform.d     // 屏幕上往下 dy,换到表自己(上下翻过来的)坐标里
        a.toValue = 0
        a.duration = 0.28
        a.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
        glideN += 1
        t.layer.add(a, forKey: "lx.glide.\(glideN)")
    }
    private func stopGlides(_ t: UITableView) {
        t.layer.animationKeys()?.filter { $0.hasPrefix("lx.glide.") }.forEach { t.layer.removeAnimation(forKey: $0) }
    }

    func pinToBottom(_ t: UITableView) {
        if data.detached { data.returnToLive() }
        (t as? LXStickyTable)?.stickBottom = true
        if t.numberOfRows(inSection: 0) != data.rows.count { reloadTable(t) }
        scrollToBottom(t)
    }

    private func scrollToBottom(_ t: UITableView) {
        guard data.rows.count > 0 else { return }
        let y = -t.adjustedContentInset.top
        if abs(t.contentOffset.y - y) > 0.5 {
            t.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }

    private func endDist(_ t: UITableView) -> CGFloat { t.contentSize.height - t.contentOffset.y }
    private func anchorToEnd(_ t: UITableView, _ dist: CGFloat) {
        guard !loadingOlder else { return }
        let y = max(-t.adjustedContentInset.top, t.contentSize.height - dist)
        if abs(t.contentOffset.y - y) > 0.5 {
            t.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.rows.count
    }

    @inline(__always) func dataIdx(_ row: Int) -> Int { data.rows.count - 1 - row }
    @inline(__always) func rowIP(_ idx: Int) -> IndexPath {
        IndexPath(row: data.rows.count - 1 - idx, section: 0)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = makeCell(tableView, indexPath)
        cell.transform = tableView.transform
        cell.accessibilityIdentifier = rowSigAt(indexPath.row)
        if abs(cell.frame.width - tableView.bounds.width) > 0.5 {
            cell.frame.size.width = tableView.bounds.width
        }
        UIView.performWithoutAnimation { cell.layoutIfNeeded() }
        return cell
    }

    private var hCache: [String: CGFloat] = [:]
    private var hCacheW: CGFloat = 0
    private lazy var szDay = LXDayCell(style: .default, reuseIdentifier: nil)
    private lazy var szBubble = LXBubbleCell(style: .default, reuseIdentifier: nil)
    private lazy var szApprove = LXApproveCell(style: .default, reuseIdentifier: nil)
    private lazy var szThinkHead = LXThinkHeadCell(style: .default, reuseIdentifier: nil)
    private lazy var szThinkBody = LXThinkBodyCell(style: .default, reuseIdentifier: nil)
    private lazy var szFoot = LXFootCell(style: .default, reuseIdentifier: nil)
    private lazy var szTyping = LXTypingCell(style: .default, reuseIdentifier: nil)

    private func hKey(_ r: LXRow) -> String {
        switch r {
        case .day(let s): return "d:\(s)"
        case .msg(let m, let st, let tl, let gp, let at):
            return "m:\(m.echoId != 0 ? m.echoId : m.id):\(LXBubbleCell.voiceOpen.contains(m.id) ? 1 : 0):\(m.text.hashValue):\(m.attCount):\(m.reactions.joined(separator: " ").hashValue):\(m.quoteId != 0 ? 1 : 0):\(m.approveLine ?? "-"):\(st ? 1 : 0)\(tl ? 1 : 0)\(gp ? 1 : 0)\(at ? 1 : 0):\(theme.avatars ? 1 : 0):\(m.failed ? 1 : 0)"
        case .thinkHead(let m, let open, let label, let live): return "th:\(m.id):\(open ? 1 : 0):\(live ? 1 : 0):\(label):\(theme.avatars ? 1 : 0)"
        case .thinkBody(let m): return "tb:\(m.id):\(m.text.hashValue):\(theme.avatars ? 1 : 0)"
        case .foot: return "f"
        case .typing: return "ty"
        }
    }

    /// 头像模式:每条都在自己头像下画自己的时间(时间在本行框里,行高给它留位)
    private func avaTimeFor(_ i: Int, width: CGFloat) -> LXAvaTime {
        guard theme.avatars, i >= 0, i < data.rows.count, case .msg = data.rows[i] else { return .none }
        return .own
    }

    private func rowHeightFor(_ row: Int, width: CGFloat) -> CGFloat {
        guard width > 10 else { return 56 }
        if hCacheW != width { hCache.removeAll(); hCacheW = width }
        let i = dataIdx(row)
        guard i >= 0, i < data.rows.count else { return 0.5 }
        let r = data.rows[i]
        let k = hKey(r)
        if let h = hCache[k] { return h }
        let cell: UITableViewCell
        switch r {
        case .day(let s):
            szDay.configure(s, theme: theme); cell = szDay
        case .msg(let m, let st, let tl, let gp, let at):
            if m.approveLine != nil { szApprove.configure(m, theme: theme); cell = szApprove }
            else {
                szBubble.configure(m, showTime: st, tail: tl, grouped: gp, afterThink: at, theme: theme, cellW: width,
                                   avaTime: theme.avatars ? .own : .none)
                cell = szBubble
            }
        case .thinkHead(_, let open, let label, let live):
            szThinkHead.configure(label: label, open: open, live: live, theme: theme); cell = szThinkHead
        case .thinkBody(let m):
            szThinkBody.configure(m.text, live: m.id == LXChatData.liveThinkId, theme: theme); cell = szThinkBody
        case .foot:
            szFoot.configure(theme: theme); cell = szFoot
        case .typing:
            szTyping.configure(theme: theme); cell = szTyping
        }
        cell.bounds = CGRect(x: 0, y: 0, width: width, height: 900)
        cell.setNeedsLayout(); cell.layoutIfNeeded()
        let h = ceil(cell.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel).height)
        let hh = max(h, 0.5)
        hCache[k] = hh
        return hh
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeightFor(indexPath.row, width: tableView.bounds.width)
    }
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return rowHeightFor(indexPath.row, width: tableView.bounds.width)
    }

    private func rowSigAt(_ row: Int) -> String {
        let i = dataIdx(row)
        guard i >= 0, i < data.rows.count else { return "" }
        return rowSig(data.rows[i])
    }

    /// 0925:备注改了——重排一遍(拍一拍那行字会跟着换),可见的气泡原地重配(引用条名字),不整表重画
    func namesChanged() {
        paintStatus(typing: data.typingOn)
        guard let t = table else { return }
        data.rebuild(stick: false)
        UIView.performWithoutAnimation {
            for ip in t.indexPathsForVisibleRows ?? [] { reconfigureVisible(t, at: ip) }
        }
    }

    private func reconfigureVisible(_ t: UITableView, at ip: IndexPath) {
        guard let cell = t.cellForRow(at: ip) else { return }
        let i = dataIdx(ip.row)
        guard i >= 0, i < data.rows.count else { return }
        switch data.rows[i] {
        case .msg(let m, let showTime, let tail, let grouped, let afterThink):
            guard m.approveLine == nil, let c = cell as? LXBubbleCell else { return }
            c.configure(m, showTime: showTime, tail: tail, grouped: grouped, afterThink: afterThink, theme: theme, cellW: t.bounds.width, avaTime: avaTimeFor(i, width: t.bounds.width))
            c.setRing(multiOn && multiSel.contains(m.id), color: theme.accent)
        case .thinkHead(let m, let open, let label, let live):
            (cell as? LXThinkHeadCell)?.configure(label: label, open: open, live: live, theme: theme)
            _ = m
        case .thinkBody(let m):
            (cell as? LXThinkBodyCell)?.configure(m.text, live: m.id == LXChatData.liveThinkId, theme: theme)
        default:
            return
        }
        cell.accessibilityIdentifier = rowSigAt(ip.row)
    }

    private func scheduleVerify(_ t: UITableView) {
        DispatchQueue.main.async { [weak self, weak t] in
            guard let s = self, let t = t else { return }
            s.verifyRows(t)
        }
    }

    private func verifyRows(_ t: UITableView) {
        guard let ips = t.indexPathsForVisibleRows, !ips.isEmpty else { return }
        var bad: [String] = []
        for ip in ips {
            guard let cell = t.cellForRow(at: ip) else { continue }
            let want = rowSigAt(ip.row)
            if want.isEmpty { continue }
            let got = cell.accessibilityIdentifier ?? ""
            if got != want { bad.append("r\(ip.row) want=\(want) got=\(got)") }
        }
        guard !bad.isEmpty else { return }
        data.onDupe?("row-mismatch",
                     "tableRows=\(t.numberOfRows(inSection: 0)) data=\(data.rows.count) " +
                     bad.prefix(4).joined(separator: " | "))
        let atBottom = nearBottom(t)
        UIView.performWithoutAnimation {
            reloadTable(t)
            if atBottom, !data.detached { pinToBottom(t) }
        }
        lastRowCount = 0; lastContentSig = 0
        lastTailSig = ""
        lastDecoSig = ""
    }

    private func previewGhostRepro(round: Int) {
        guard LustreConfig.isPreview, round < 6, let t = table else {
            if LustreConfig.isPreview, round >= 6 { previewJumpCheck(); previewSnapCheck() }
            return
        }
        let gaps: [Double] = [0.06, 0.126, 0.126, 0.2, 0.02, 0.126]
        let gap = gaps[round]
        let base = (data.msgs.last?.id ?? 0) + Int64(9000 + round * 10)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = iso.string(from: Date())
        let sid = "ghost-\(round)"

        data.handle(["id": NSNumber(value: base), "from": "human", "kind": "user",
                     "text": "复现第\(round)轮", "ts": now, "meta": [String: Any]()])
        data.handle(["type": "thinking_delta", "stream_id": sid, "api_session": "",
                     "text": "复现:正在想的第一段。", "done": false, "ts": now])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let s = self else { return }
            s.data.handle(["type": "thinking_delta", "stream_id": sid, "api_session": "",
                           "text": "复现:正在想的第二段,再长一点让卡有高度。", "done": false, "ts": now])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                s.data.handle(["id": NSNumber(value: base + 1), "from": "ai", "kind": "thinking",
                               "text": "复现:正在想的第一段。\n复现:正在想的第二段,再长一点让卡有高度。",
                               "ts": iso.string(from: Date()),
                               "meta": ["duration_sec": NSNumber(value: 10)] as [String: Any]])
                DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
                    s.data.handle(["id": NSNumber(value: base + 2), "from": "ai", "kind": "reply",
                                   "text": "复现第\(round)轮的回复正文,够长才好看出有没有画两遍。",
                                   "ts": iso.string(from: Date()), "meta": [String: Any]()])
                    DispatchQueue.main.async { s.ghostCheck(t, round: round, gap: gap, when: "即刻") }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        s.ghostCheck(t, round: round, gap: gap, when: "半秒后")
                        s.previewGhostRepro(round: round + 1)
                    }
                }
            }
        }
    }

    private var frameLink: CADisplayLink?
    private var frameRed = 0
    private var frameTicks = 0
    private func frameSentinelStart() {
        guard LustreConfig.isPreview, frameLink == nil else { return }
        frameRed = 0; frameTicks = 0
        let l = CADisplayLink(target: self, selector: #selector(frameTick))
        l.add(to: .main, forMode: .common)
        frameLink = l
        frameRed = 0; frameTicks = 0; hJumpRed = 0; clipRed = 0; wobbleRed = 0
        hLast.removeAll(); wLast.removeAll(); xLast.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 14) { [weak self] in
            guard let s = self else { return }
            s.frameLink?.invalidate(); s.frameLink = nil
            let verdict = (s.frameRed == 0 && s.hJumpRed == 0 && s.clipRed == 0 && s.wobbleRed == 0) ? "零红" : "红"
            s.probe("frame-sentinel", "\(verdict) 宽\(s.frameRed) 高跳\(s.hJumpRed) 出泡\(s.clipRed) 宽晃\(s.wobbleRed) 帧数\(s.frameTicks)")
            s.previewRpCheck()
        }
    }

    private func previewRpCheck() {
        guard LustreConfig.isPreview else { return }
        openRPanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let s = self else { return }
            guard let p = s.rpanel else { s.probe("rp-check", "no-panel"); return }
            let w = Int(p.bounds.width)
            let vis = p.actionRows.filter { $0.bounds.height > 40 }.count
            s.probe("rp-check", "宽\(w) 行\(p.actionRows.count)/可见\(vis) usage行\(p.usageRowsVisible)")
            s.closeRPanel()
            s.previewRpFuncCheck()
        }
    }

    private func previewFoldCheck() {
        guard let t = table else { return }
        var headIdx = -1
        for (i, r) in data.rows.enumerated() {
            if case .thinkHead(_, let open, _, let live) = r, !live, !open,
               i + 1 < data.rows.count, case .msg = data.rows[i + 1] { headIdx = i; break }
        }
        guard headIdx >= 0 else { probe("fold-check", "无样本(没有贴回复的折叠卡)"); return }
        t.scrollToRow(at: rowIP(headIdx), at: .middle, animated: false)
        t.layoutIfNeeded()
        tableView(t, didSelectRowAt: rowIP(headIdx))
        tableView(t, didSelectRowAt: rowIP(headIdx))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let s = self, let t2 = s.table else { return }
            let replyIdx = headIdx + 1
            guard replyIdx < s.data.rows.count, case .msg = s.data.rows[replyIdx],
                  let cell = t2.cellForRow(at: s.rowIP(replyIdx)) as? LXBubbleCell else {
                s.probe("fold-check", "样本不在屏"); return
            }
            cell.layoutIfNeeded()
            let cellH = cell.bounds.height
            let want = s.rowHeightFor(s.rowIP(replyIdx).row, width: t2.bounds.width)
            let bot = cell.bubble.frame.maxY
            let ok = abs(cellH - want) < 1.5 && bot <= cellH + 0.5
            s.probe("fold-check", "cellH=\(Int(cellH)) 行高账=\(Int(want)) 泡底=\(Int(bot)) 未裁=\(ok)")
        }
    }

    private func previewRpThemeCheck() {
        func alphaAt(_ img: UIImage, _ x: CGFloat, _ y: CGFloat) -> CGFloat {
            var px: [UInt8] = [0, 0, 0, 0]
            guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
            UIGraphicsPushContext(ctx)
            img.draw(at: CGPoint(x: -x, y: -y))
            UIGraphicsPopContext()
            return CGFloat(px[3]) / 255
        }
        func solid(_ img: UIImage) -> Bool { alphaAt(img, 6, 14) > 0.8 && alphaAt(img, 6, 7) > 0.8 }
        func hollow(_ img: UIImage) -> Bool { alphaAt(img, 6, 14) < 0.15 && alphaAt(img, 6, 7) < 0.15 }
        let dayOK = hollow(RPanelView.iMoonDay)
        let halfOK = solid(RPanelView.iMoonHalf)
        let fullOK = solid(RPanelView.iMoonFull) && alphaAt(RPanelView.iMoonFull, 10.5, 10.5) > 0.8
        let strokeOK = alphaAt(RPanelView.iMoonDay, 18.4, 11.2) > 0.3 || alphaAt(RPanelView.iMoonDay, 18.4, 9.8) > 0.3
        let palOK = RPSpec.tints["day"] != nil && RPSpec.tints["half"] != nil && RPSpec.tints["moon"] != nil
        probe("rp-theme", "day空心=\(dayOK) half实心=\(halfOK) full圆盘=\(fullOK) 描边在=\(strokeOK) 三档=\(palOK) 相=\(RPSpec.moonState)")
    }

    private func previewRpFuncCheck() {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 500), format: fmt).image { ctx in
            UIColor.systemRed.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 500))
        }
        func decode(_ s: String?) -> (mime: String, size: CGSize)? {
            guard let s = s, let comma = s.firstIndex(of: ","),
                  let d = Data(base64Encoded: String(s[s.index(after: comma)...])),
                  let im = UIImage(data: d) else { return nil }
            let mime = s.hasPrefix("data:image/png") ? "png" : (s.hasPrefix("data:image/jpeg") ? "jpeg" : "?")
            return (mime, CGSize(width: im.size.width * im.scale, height: im.size.height * im.scale))
        }
        let ai = decode(rpProcess(img, target: "ai"))
        let hu = decode(rpProcess(img, target: "human"))
        let wa = decode(rpProcess(img, target: "wall"))
        let ok = ai?.mime == "jpeg" && ai?.size == CGSize(width: 320, height: 320)
              && hu?.mime == "png" && hu?.size == CGSize(width: 320, height: 320)
              && wa?.mime == "jpeg" && wa?.size == CGSize(width: 800, height: 500)
        probe("rp-func", ok ? "三裁法OK ai=jpeg320 hu=png320 wall=jpeg800x500"
                            : "BAD ai=\(String(describing: ai)) hu=\(String(describing: hu)) wall=\(String(describing: wa))")
    }
    private var hLast: [String: CGFloat] = [:]
    private var wLast: [String: CGFloat] = [:]
    private var xLast: [String: CGFloat] = [:]
    private var wobbleRed = 0
    private var hJumpRed = 0
    private var clipRed = 0
    @objc private func frameTick() {
        guard let t = table else { return }
        frameTicks += 1
        let w = t.bounds.width
        for ip in (t.indexPathsForVisibleRows ?? []) {
            guard let cell = t.cellForRow(at: ip) else { continue }
            let i = dataIdx(ip.row)
            if i >= 0, i < data.rows.count {
                let k = hKey(data.rows[i])
                if !k.hasPrefix("tb:"), !k.hasPrefix("th:") {
                    let h = cell.frame.height
                    if let last = hLast[k], abs(last - h) > 2.5 { hJumpRed += 1 }
                    hLast[k] = h
                }
            }
            guard let c = cell as? LXBubbleCell else { continue }
            let lf = c.label.convert(c.label.bounds, to: c.bubble)
            if lf.maxX > c.bubble.bounds.width + 1.5 || lf.minX < -1.5 { clipRed += 1 }
            if c.isMine {
                let f = c.bubble.frame
                if f.width > w * 0.72 + 8 || f.minX < w * 0.1 { frameRed += 1 }
            }
            if i >= 0, i < data.rows.count {
                let k2 = hKey(data.rows[i])
                let bw = c.bubble.frame.width
                let bx = c.bubble.frame.minX
                if let lw = wLast[k2], abs(lw - bw) > 1.5 { wobbleRed += 1 }
                if let lx = xLast[k2], abs(lx - bx) > 1.5 { wobbleRed += 1 }
                wLast[k2] = bw
                xLast[k2] = bx
            }
        }
    }

    private func previewJumpCheck() {
        guard let t = table else { return }
        var idx = -1
        for (i, r) in data.rows.enumerated() {
            if case .msg(let m, _, _, _, _) = r, m.id < Int64.max - 5000 { idx = i; break }
        }
        guard idx >= 0 else { probe("jump-check", "no-target"); return }
        let before = t.contentOffset.y
        stickDisarmed = true
        (t as? LXStickyTable)?.stickBottom = false
        t.scrollToRow(at: rowIP(idx), at: .middle, animated: false)
        let after = t.contentOffset.y
        let vis = t.indexPathsForVisibleRows?.contains(rowIP(idx)) ?? false
        probe("jump-check", "moved \(Int(before))->\(Int(after)) visible=\(vis)")
        let minBefore = data.msgs.first?.id ?? 0
        Task { [weak self] in
            guard let s = self else { return }
            let target = await s.data.idBefore(max(1, minBefore - 350)) ?? max(1, minBefore - 350)
            let ok = await s.data.ensureLoaded(target)
            let minAfter = s.data.msgs.first?.id ?? 0
            await MainActor.run {
                s.probe("jump-ensure", "ok=\(ok) min \(minBefore)->\(minAfter)")
                if let t2 = s.table { s.pinToBottom(t2) }
            }
        }
    }

    private func previewSnapCheck() {
        guard LustreConfig.isPreview else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let s = self else { return }
            let sid = (s.data.session == "__legacy__" || s.data.session.isEmpty) ? "" : s.data.session
            let mk: (String, Bool) -> [String: Any] = { txt, snap in
                var o: [String: Any] = ["type": "thinking_delta", "stream_id": "pv-snap-native",
                                        "text": txt, "api_session": sid]
                if snap { o["snapshot"] = true }
                return o
            }
            s.data.handle(mk("甲段。", false))
            s.data.handle(mk("乙段。", false))
            s.data.handle(mk("甲段。乙段。", true))
            let got = s.data.thinkDraft
            let ok = got == "甲段。乙段。"
            s.data.thinkDraft = ""
            s.data.thinkStart = nil
            s.data.rebuild(stick: false)
            s.probe("snap-native", (ok ? "替换OK" : "翻倍BAD") + " got=\(String(got.prefix(40)))")
            s.previewMergeCheck()
        }
    }

    private func previewMergeCheck() {
        let now = Date()
        func mk(_ id: Int64, _ kind: String, _ dur: Int, _ serves: Int64 = 0) -> LXMsg {
            LXMsg(id: id, from: kind == "user" ? "human" : "ai", kind: kind,
                  text: "\(kind)\(id)", ts: now.addingTimeInterval(Double(id)),
                  session: "", attCount: 0, durSec: dur, servesId: serves)
        }
        let seq = [mk(1, "user", 0), mk(2, "thinking", 7, 4), mk(3, "thinking", 5, 4),
                   mk(4, "reply", 0), mk(5, "thinking", 9, 6), mk(6, "reply", 0),
                   mk(7, "thinking", 3), mk(8, "thinking", 2)]
        let out = data.mergeTurnThinking(seq)
        let cards = out.filter { $0.kind == "thinking" }
        let ok = cards.count == 5 && cards.map { $0.durSec } == [7, 5, 9, 3, 2]
        probe("merge-check", ok ? "永不凝OK 卡数=\(cards.count) 秒=\(cards.map { $0.durSec })"
                                : "BAD 卡数=\(cards.count) 秒=\(cards.map { $0.durSec })")
        previewServesCheck()
    }

    private func previewServesCheck() {
        let now = Date()
        func mk(_ id: Int64, _ kind: String, _ tsOff: Double, _ serves: Int64 = 0) -> LXMsg {
            LXMsg(id: id, from: kind == "user" ? "human" : "ai", kind: kind,
                  text: "\(kind)\(id)", ts: now.addingTimeInterval(tsOff),
                  session: "", attCount: 0, durSec: 3, servesId: serves)
        }
        func run(_ seq: [LXMsg]) -> LXChatData {
            let d = LXChatData()
            for m in seq { d.probeIngest([m]) }
            return d
        }
        let got1 = run([mk(1, "reply", 1), mk(2, "user", 2), mk(3, "thinking", 6, 5),
                        mk(5, "reply", 5), mk(6, "thinking", 7)]).probeOrder()
        let ok1 = got1 == [1, 2, 3, 5, 6]
        let got2 = run([mk(1, "reply", 1), mk(2, "user", 55), mk(3, "user", 56),
                        mk(4, "thinking", 57), mk(5, "reply", 58),
                        mk(6, "user", 60), mk(7, "user", 61)]).probeOrder()
        let ok2 = got2 == [1, 2, 3, 4, 5, 6, 7]
        let d3 = run([mk(1, "user", 1), mk(2, "thinking", 2), mk(3, "user", 3), mk(4, "reply", 4)])
        d3.probeIngest([mk(2, "thinking", 2, 4)])
        d3.probeIngest([mk(5, "user", 5)])
        let got3 = d3.probeOrder()
        let ok3 = got3 == [1, 3, 2, 4, 5]
        probe("serves-check", (ok1 && ok2 && ok3) ? "出生即正确OK 配对=\(got1) 连发=\(got2) 补芯=\(got3)"
                                                  : "BAD 配对=\(got1) 连发=\(got2) 补芯=\(got3)")
        previewLifecycleCheck()
    }

    private func previewLifecycleCheck() {
        let d = LXChatData()
        let iso = ISO8601DateFormatter()
        var report: [String] = []
        var lastOrder: [Int64] = []
        func pin(_ tag: String) -> Bool {
            let now = d.probeOrder()
            let kept = now.filter { lastOrder.contains($0) }
            let ok = kept == lastOrder
            if !ok { report.append("\(tag)跳位 \(lastOrder)->\(now)") }
            lastOrder = now
            return ok
        }
        func pay(_ id: Int64, _ kind: String, _ serves: Int64 = 0) -> [String: Any] {
            var m: [String: Any] = ["id": NSNumber(value: id), "from": kind == "user" ? "human" : "ai",
                                    "kind": kind, "text": "样\(id)", "ts": iso.string(from: Date()),
                                    "direction": kind == "user" ? "in" : "out"]
            if serves > 0 { m["meta"] = ["serves_id": NSNumber(value: serves)] }
            return m
        }
        d.handle(pay(1, "user"))
        _ = pin("拍0")
        d.handle(["type": "thinking_delta", "text": "想…", "ts": iso.string(from: Date())])
        let live1 = d.thinkStart != nil
        d.handle(pay(2, "thinking"))
        let p1 = d.probeOrder() == [1, 2] && pin("拍1")
        let p2 = d.expandedThink.contains(2)
        d.handle(pay(3, "reply"))
        let p3 = d.probeOrder() == [1, 2, 3] && pin("拍3")
        let p4 = !d.expandedThink.contains(2)
        d.handle(pay(2, "thinking", 3))
        let p5 = d.probeOrder() == [1, 2, 3] && pin("补芯")
        d.handle(pay(4, "user"))
        let p6 = d.probeOrder() == [1, 2, 3, 4] && pin("她再说")
        let all = live1 && p1 && p2 && p3 && p4 && p5 && p6
        probe("lifecycle-check", all
              ? "四拍OK 出现[1,2]✓摊开✓落地[1,2,3]✓折叠✓补芯零搬✓连发钉位✓"
              : "BAD 直播=\(live1) 出现=\(p1) 摊开=\(p2) 落地=\(p3) 折叠=\(p4) 补芯=\(p5) 连发=\(p6) \(report.joined(separator: ";"))")
    }

    private func ghostCheck(_ t: UITableView, round: Int, gap: Double, when: String) {
        var seen: [String: Int] = [:]
        var dupe = ""
        var mismatch = ""
        for ip in (t.indexPathsForVisibleRows ?? []) {
            guard let cell = t.cellForRow(at: ip) else { continue }
            let got = cell.accessibilityIdentifier ?? ""
            let want = rowSigAt(ip.row)
            if !got.isEmpty {
                if let prev = seen[got] { dupe = "同一格画了两遍 sig=\(got) r\(prev)+r\(ip.row)" }
                seen[got] = ip.row
            }
            if !want.isEmpty, got != want, mismatch.isEmpty {
                mismatch = "错位 r\(ip.row) want=\(want) got=\(got)"
            }
        }
        let verdict = dupe.isEmpty && mismatch.isEmpty ? "干净" : "\(dupe) \(mismatch)"
        probe("ghost", "第\(round)轮 间隔\(Int(gap * 1000))ms \(when): \(verdict) " +
                       "| 表\(t.numberOfRows(inSection: 0))行 数据\(data.rows.count)行 可见\((t.indexPathsForVisibleRows ?? []).count)")
    }

    private func makeCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let idx = dataIdx(indexPath.row)
        guard idx >= 0, idx < data.rows.count else {
            return tableView.dequeueReusableCell(withIdentifier: LXDayCell.reuse, for: indexPath)
        }
        switch data.rows[idx] {
        case .day(let s):
            let c = tableView.dequeueReusableCell(withIdentifier: LXDayCell.reuse, for: indexPath) as! LXDayCell
            c.configure(s, theme: theme)
            return c
        case .msg(let m, let showTime, let tail, let grouped, let afterThink):
            if m.approveLine != nil {
                let c = tableView.dequeueReusableCell(withIdentifier: LXApproveCell.reuse, for: indexPath) as! LXApproveCell
                c.configure(m, theme: theme)
                return c
            }
            let attOnly = m.text.isEmpty && !m.atts.isEmpty
            let glassed = !attOnly && (m.from == "human" || theme.avatars)
            let c = tableView.dequeueReusableCell(withIdentifier: glassed ? LXBubbleCell.reuseGlass : LXBubbleCell.reuse,
                                                  for: indexPath) as! LXBubbleCell
            c.configure(m, showTime: showTime, tail: tail, grouped: grouped, afterThink: afterThink, theme: theme, cellW: tableView.bounds.width,
                        avaTime: avaTimeFor(dataIdx(indexPath.row), width: tableView.bounds.width))
            c.onLongPress = { [weak self] msg, bubble in self?.showMenu(msg, bubble: bubble) }
            c.onRetry = { cid in LXOutbox.shared.retry(cid) }
            c.onAttTap = { [weak self] att in self?.attTapped(att) }
            c.onAvatarTap = { [weak self] m in self?.showThinkSheet(for: m) }
            c.onAvatarDoubleTap = { [weak self] m in self?.askPat(m) }
            c.onVoiceTextTap = { [weak self] id in self?.toggleVoiceText(id) }
            c.onQuoteTap = { [weak self] qid in self?.jumpToMessage(qid) }
            c.setRing(multiOn && multiSel.contains(m.id), color: theme.accent)
            return c
        case .thinkHead(_, let open, let label, let live):
            let c = tableView.dequeueReusableCell(withIdentifier: LXThinkHeadCell.reuse, for: indexPath) as! LXThinkHeadCell
            c.configure(label: label, open: open, live: live, theme: theme)
            return c
        case .thinkBody(let m):
            let c = tableView.dequeueReusableCell(withIdentifier: LXThinkBodyCell.reuse, for: indexPath) as! LXThinkBodyCell
            c.configure(m.text, live: m.id == LXChatData.liveThinkId, theme: theme)
            return c
        case .foot:
            let c = tableView.dequeueReusableCell(withIdentifier: LXFootCell.reuse, for: indexPath) as! LXFootCell
            c.configure(theme: theme)
            return c
        case .typing:
            let c = tableView.dequeueReusableCell(withIdentifier: LXTypingCell.reuse, for: indexPath) as! LXTypingCell
            c.configure(theme: theme)
            return c
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let idx = dataIdx(indexPath.row)
        guard idx >= 0, idx < data.rows.count else { return }
        if multiOn, case .msg(let m, _, _, _, _) = data.rows[idx] {
            if multiSel.contains(m.id) { multiSel.remove(m.id) } else { multiSel.insert(m.id) }
            multiCountL?.text = "已选 \(multiSel.count) 条"
            tableView.reloadRows(at: [indexPath], with: .none)
            return
        }
        if case .thinkHead(let m, let open, _, _) = data.rows[idx] {
            if open { data.expandedThink.remove(m.id) } else { data.expandedThink.insert(m.id) }
            let oldCount = data.rows.count
            data.rebuildQuiet()
            let delta = data.rows.count - oldCount
            if abs(delta) == 1, let t = table, t.numberOfRows(inSection: 0) == oldCount {
                let bodyDataIdx = idx + 1
                t.performBatchUpdates({
                    if delta == 1 {
                        t.insertRows(at: [rowIP(bodyDataIdx)], with: .fade)
                    } else {
                        t.deleteRows(at: [IndexPath(row: oldCount - 1 - bodyDataIdx, section: 0)], with: .fade)
                    }
                })
                reconfigureVisible(t, at: rowIP(idx))
                let replyIdx = idx + (delta == 1 ? 2 : 1)
                if replyIdx < data.rows.count, case .msg = data.rows[replyIdx] {
                    reconfigureVisible(t, at: rowIP(replyIdx))
                }
                refreshPaintFingerprints()
                scheduleVerify(t)
            } else {
                data.rebuild(stick: false)
            }
        }
    }

    private func refreshPaintFingerprints() {
        var contentEnd = data.rows.count
        var decoSig = ""
        deco: while contentEnd > 0 {
            switch data.rows[contentEnd - 1] {
            case .foot: decoSig += "f"; contentEnd -= 1
            case .typing: decoSig += "t"; contentEnd -= 1
            default: break deco
            }
        }
        lastRowCount = contentEnd
        lastTailSig = contentEnd > 0 ? rowSig(data.rows[contentEnd - 1]) : ""
        lastDecoSig = decoSig
        var hAll = Hasher()
        for i in 0..<contentEnd { hAll.combine(rowKey(data.rows[i])) }
        lastOrderHash = hAll.finalize()
    }


    private func webAct(_ payload: [String: Any]) { notifyListeners("chatAct", data: payload) }
    private func toast(_ t: String) { LXToast.show(t, host: container?.superview) }

    func showMenu(_ m: LXMsg, bubble: UIView) {
        guard !multiOn, menu == nil, let cont = container else { return }
        guard m.id < Int64.max - 8 else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let mn = LXMsgMenu(msg: m, bubble: bubble, host: cont, theme: theme)
        mn.onAct = { [weak self] act in self?.menuAct(act, m) }
        cont.addSubview(mn)
        menu = mn
    }

    private func closeMenu() {
        menu?.dismiss()
        menu = nil
    }

    private func menuAct(_ act: String, _ m: LXMsg) {
        closeMenu()
        if act == "emojiKb" {
            guard let host = bridge?.viewController?.view else { return }
            LXEmojiPicker.present(host: host) { [weak self] e in self?.menuAct("react:" + e, m) }
            return
        }
        if act.hasPrefix("react:") {
            let emoji = String(act.dropFirst(6))
            let already = m.reactions.contains(emoji)
            data.post("/app/react", ["id": m.id, "emoji": already ? "" : emoji]) { [weak self] ok in
                if !ok { self?.toast("没贴上，再试试") }
            }
            return
        }
        switch act {
        case "stt":
            if m.text.isEmpty { toast("这条还没转出文字"); return }
            toggleVoiceText(m.id)
        case "copy":
            guard !m.text.isEmpty else { return }
            UIPasteboard.general.string = m.text
            toast("已复制")
        case "star":
            let on = !m.starred
            data.post("/app/star", ["id": m.id, "on": on]) { [weak self] ok in
                guard let s = self else { return }
                if ok {
                    s.data.patch(m.id) { $0.starred = on }
                    s.toast(on ? "已收藏⭐" : "已取消收藏")
                    s.webAct(["act": "starred", "id": Int(m.id), "on": on])
                } else { s.toast("操作失败") }
            }
        case "quote":
            let txt = m.text.isEmpty ? (m.atts.isEmpty ? "" : "[图片]") : String(m.text.prefix(80))
            LXOutbox.shared.setQuote(id: m.id, from: m.from, text: txt, session: m.session)
        case "seltext":
            LXSelectText.show(m.text, host: container?.superview, theme: theme)
        case "delete":
            data.markDeleted(m.id)
            toast("已删除")
        case "multi":
            enterMulti(first: m.id)
        default: break
        }
    }

    private func enterMulti(first: Int64) {
        guard let cont = container else { return }
        multiOn = true
        multiSel = [first]
        let bar = UIView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.clipsToBounds = true
        bar.layer.cornerRadius = 18.5
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(blur)
        let tint = UIView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.backgroundColor = UIColor(red: 34/255.0, green: 46/255.0, blue: 60/255.0, alpha: 0.82)
        bar.addSubview(tint)
        let count = UILabel()
        count.translatesAutoresizingMaskIntoConstraints = false
        count.font = UIFont.systemFont(ofSize: 13.5)
        count.textColor = .white
        count.text = "已选 1 条"
        multiCountL = count
        func pill(_ title: String, bg: UIColor, fg: UIColor, bold: Bool) -> UIButton {
            let b = UIButton(type: .system)
            var cfg = UIButton.Configuration.filled()
            cfg.baseBackgroundColor = bg
            cfg.attributedTitle = AttributedString(title, attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 13.5, weight: bold ? .semibold : .regular), .foregroundColor: fg]))
            cfg.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 13, bottom: 6, trailing: 13)
            cfg.background.cornerRadius = 14
            b.configuration = cfg
            return b
        }
        let star = pill("⭐ 收藏", bg: UIColor(red: 0.851, green: 0.643, blue: 0.255, alpha: 1),
                        fg: UIColor(red: 0.165, green: 0.141, blue: 0.090, alpha: 1), bold: true)
        star.addAction(UIAction { [weak self] _ in self?.multiStar() }, for: .touchUpInside)
        let cancel = pill("取消", bg: UIColor(white: 1, alpha: 0.16), fg: .white, bold: false)
        cancel.addAction(UIAction { [weak self] _ in self?.exitMulti() }, for: .touchUpInside)
        let row = UIStackView(arrangedSubviews: [count, star, cancel])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        bar.addSubview(row)
        cont.addSubview(bar)
        let hdrH = header?.bounds.height ?? (safeTopV + 58)
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: bar.topAnchor), blur.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: bar.leadingAnchor), blur.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            tint.topAnchor.constraint(equalTo: bar.topAnchor), tint.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            tint.leadingAnchor.constraint(equalTo: bar.leadingAnchor), tint.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            row.topAnchor.constraint(equalTo: bar.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: bar.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -14),
            bar.centerXAnchor.constraint(equalTo: cont.centerXAnchor),
            bar.topAnchor.constraint(equalTo: cont.topAnchor, constant: hdrH + 8),
        ])
        multiBar = bar
        toast("多选模式：点消息勾选")
        reloadTable(table)
    }

    private func exitMulti() {
        multiOn = false
        multiSel.removeAll()
        multiBar?.removeFromSuperview()
        multiBar = nil; multiCountL = nil
        reloadTable(table)
    }

    private func multiStar() {
        guard !multiSel.isEmpty else { toast("还没选呢"); return }
        let ids = Array(multiSel)
        data.post("/app/star", ["ids": ids.map { NSNumber(value: $0) }, "on": true]) { [weak self] ok in
            guard let s = self else { return }
            if ok {
                for id in ids {
                    s.data.patch(id) { $0.starred = true }
                    s.webAct(["act": "starred", "id": Int(id), "on": true])
                }
                s.toast("已收藏 \(ids.count) 条⭐")
                s.exitMulti()
            } else { s.toast("收藏失败") }
        }
    }

    private func attTapped(_ att: LXAtt) {
        guard let u = att.fullURL?.absoluteString else { return }
        guard let full = att.fullURL else { return }
        if att.kind == "image", let host = container?.superview {
            LXLightbox.show(full, host: host)
        } else {
            LXFilePreview.shared.open(url: full, name: att.name)
        }
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        stickDisarmed = true
        (scrollView as? LXStickyTable)?.stickBottom = false
    }
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate d: Bool) {
        if !d { rearmIfBottom(scrollView) }
    }
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        rearmIfBottom(scrollView)
    }
    private func nearBottom(_ sv: UIScrollView, _ slack: CGFloat = 140) -> Bool {
        sv.contentOffset.y < -sv.adjustedContentInset.top + slack
    }
    private func rearmIfBottom(_ sv: UIScrollView) {
        if data.detached { return }
        let atBottom = nearBottom(sv, 60)
        if atBottom {
            stickDisarmed = false
            (sv as? LXStickyTable)?.stickBottom = true
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        syncFadeMask()
        if menu != nil { closeMenu() }
        if data.detached, !loadingNewer, nearBottom(scrollView, 600) {
            loadingNewer = true
            Task { [weak self] in
                guard let s = self else { return }
                _ = await s.data.fetchNewer()
                await MainActor.run { s.loadingNewer = false }
            }
        }
        let toEnd = scrollView.contentSize.height - scrollView.bounds.height
            + scrollView.adjustedContentInset.bottom - scrollView.contentOffset.y
        guard toEnd < 600, !loadingOlder, data.hasOlder, !data.rows.isEmpty else { return }
        loadingOlder = true
        Task { [weak self] in
            guard let s = self else { return }
            _ = await s.data.fetchOlder()
            await MainActor.run { s.loadingOlder = false }
        }
    }
}

extension ChatListPlugin: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let target = rpPickTarget else { return }
        rpPickTarget = nil
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let s = self, let img = obj as? UIImage else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                guard let dataUrl = s.rpProcess(img, target: target) else { return }
                DispatchQueue.main.async { s.rpStore(target: target, dataUrl: dataUrl) }
            }
        }
    }
}


final class LXThinkOverlay: UIView, UIGestureRecognizerDelegate {
    private let scrim = UIView()
    private let card = UIView()
    private let tv = UIScrollView()
    private let content = UIStackView()
    private var hC: NSLayoutConstraint!
    private var startH: CGFloat = 0
    private static weak var live: LXThinkOverlay?

    static func show(host: UIView, title: String, text: String, theme: LXChatTheme) {
        live?.removeFromSuperview()
        // 0925 她:键盘开着的时候点头像,思考卡升起来被键盘挡住——底部小卡升起前先把键盘收起
        host.window?.endEditing(true)
        let v = LXThinkOverlay(title: title, text: text, theme: theme)
        v.frame = host.bounds
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(v)
        live = v
        v.layoutIfNeeded()
        v.hC.constant = v.mediumH
        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2,
                       options: [.allowUserInteraction]) {
            v.scrim.alpha = 1
            v.layoutIfNeeded()
        }
    }

    private var mediumH: CGFloat { bounds.height * 0.5 }
    private var largeH: CGFloat { bounds.height - safeAreaInsets.top - 12 }

    init(title: String, text: String, theme: LXChatTheme) {
        super.init(frame: .zero)
        scrim.backgroundColor = UIColor(white: 0, alpha: 0.28)
        scrim.alpha = 0
        scrim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
        // 0925 她的单:所有底部升起的小卡统一用"模型小卡"那种底——玻璃 + LXSheetInk.tint 一层(跟 LXCardSheet 同一套)
        card.backgroundColor = .clear
        let glassFx: UIVisualEffect
        if #available(iOS 26.0, *) { glassFx = UIGlassEffect() }
        else { glassFx = UIBlurEffect(style: LXSheetInk.dark ? .systemThickMaterialDark : .systemThickMaterialLight) }
        let glass = UIVisualEffectView(effect: glassFx)
        glass.overrideUserInterfaceStyle = LXSheetInk.dark ? .dark : .light
        let tintV = UIView(); tintV.backgroundColor = LXSheetInk.tint
        for v in [glass, tintV] as [UIView] {
            v.frame = card.bounds; v.autoresizingMask = [.flexibleWidth, .flexibleHeight]; card.addSubview(v)
        }
        card.layer.cornerRadius = 28
        card.layer.cornerCurve = .continuous
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.layer.borderWidth = 1
        card.layer.borderColor = theme.hairline.cgColor
        card.clipsToBounds = true
        let grab = UIView()
        grab.backgroundColor = theme.faint.withAlphaComponent(0.5)
        grab.layer.cornerRadius = 2.5
        let t = UILabel()
        t.text = title
        t.font = LXDrawerTint.font(17, wght: 650)
        // 0926:卡有自己的底,字用卡的墨。theme.aiFg 会跟着壁纸变(浅壁纸=近黑),放在深色卡上就看不见了
        t.textColor = LXSheetInk.text
        t.textAlignment = .center
        // 0925 她的单:纯思考的段落照旧是纯文字;只有调工具的那几步才用"图标+短线"(不露 emoji)
        tv.backgroundColor = .clear
        tv.alwaysBounceVertical = true
        tv.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0)
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: tv.contentLayoutGuide.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: tv.contentLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: tv.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: tv.contentLayoutGuide.trailingAnchor),
            content.widthAnchor.constraint(equalTo: tv.frameLayoutGuide.widthAnchor),
        ])
        let steps = LXThinkBodyCell.splitSteps(text)
        // 只认"行首是工具 emoji / 工具名"的才算调工具;正文里提到"心率""提醒"之类不算
        func isTool(_ st: String) -> Bool {
            let t = st.trimmingCharacters(in: .whitespaces)
            if ["⚙️","🔧","📄","📖","✍️","✏️","🔍","🌐"].contains(where: { t.hasPrefix($0) }) { return true }
            return t.range(of: "^(Bash|Read|Write|Edit|Grep|Glob|ToolSearch|WebFetch|WebSearch|mcp__)", options: .regularExpression) != nil
        }
        let hasTool = steps.contains(where: isTool)
        var runs: [(tool: Bool, lines: [String])] = []
        if hasTool {
            for st in steps {
                let tool = isTool(st)
                if let last = runs.last, last.tool == tool { runs[runs.count - 1].lines.append(st) }
                else { runs.append((tool, [st])) }
            }
        } else {
            runs = [(false, [text])]
        }
        for r in runs {
            if r.tool {
                let c = LXThinkBodyCell(style: .default, reuseIdentifier: nil)
                c.sideInset = 28
                c.configure(r.lines.joined(separator: "\n"), live: true, theme: theme)   // live:不追加 Done 行,末步不拖线
                c.contentView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    c.contentView.topAnchor.constraint(equalTo: c.topAnchor),
                    c.contentView.bottomAnchor.constraint(equalTo: c.bottomAnchor),
                    c.contentView.leadingAnchor.constraint(equalTo: c.leadingAnchor),
                    c.contentView.trailingAnchor.constraint(equalTo: c.trailingAnchor),
                ])
                content.addArrangedSubview(c)
            } else {
                let body = hasTool ? r.lines.map { LXThinkBodyCell.stripEmoji($0) }.joined(separator: "\n") : r.lines[0]
                let l = UITextView()
                l.isEditable = false; l.isScrollEnabled = false; l.backgroundColor = .clear
                l.textContainerInset = UIEdgeInsets(top: 0, left: 28, bottom: 0, right: 28)
                l.textContainer.lineFragmentPadding = 0
                // 0925 她说换行间距太大:原来把原文里的空行原样留着,再叠行距 7 + 段距 14,两段之间能空出三行。
                // 改成跟聊天气泡同一套排版(连续空行并成一个换行,固定行高 21.3,段距 11),间距只由排版决定,不看原文有几个空行
                l.attributedText = LXBubbleCell.styled(body, base: LXBubbleCell.bodyFont(), color: LXSheetInk.text, lineGap: 21.3)
                content.addArrangedSubview(l)
            }
        }
        for v in [scrim, card] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        for v in [grab, t, tv] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; card.addSubview(v) }
        hC = card.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            scrim.topAnchor.constraint(equalTo: topAnchor), scrim.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrim.leadingAnchor.constraint(equalTo: leadingAnchor), scrim.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            hC,
            grab.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            grab.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            grab.widthAnchor.constraint(equalToConstant: 36),
            grab.heightAnchor.constraint(equalToConstant: 5),
            t.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            t.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            t.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            tv.topAnchor.constraint(equalTo: t.bottomAnchor, constant: 16),
            tv.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.delegate = self
        card.addGestureRecognizer(pan)
    }
    required init?(coder: NSCoder) { fatalError() }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other === tv.panGestureRecognizer
    }
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        guard let pan = g as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: self)
        guard abs(v.y) > abs(v.x) else { return false }
        let inText = tv.frame.contains(pan.location(in: card))
        if !inText { return true }
        let atTop = tv.contentOffset.y <= -tv.adjustedContentInset.top + 0.5
        if v.y > 0 { return atTop }
        return hC.constant < largeH - 1
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        let dy = g.translation(in: self).y
        switch g.state {
        case .began:
            startH = hC.constant
        case .changed:
            hC.constant = min(largeH, max(0, startH - dy))
            if tv.contentOffset.y > -tv.adjustedContentInset.top, hC.constant < largeH - 1 {
                tv.contentOffset.y = -tv.adjustedContentInset.top
            }
        case .ended, .cancelled:
            let vy = g.velocity(in: self).y
            let h = hC.constant
            if vy > 900 || h < mediumH * 0.6 { close(); return }
            let target: CGFloat = vy < -600 ? largeH : (vy > 600 ? mediumH : (abs(h - largeH) < abs(h - mediumH) ? largeH : mediumH))
            hC.constant = target
            UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.2,
                           options: [.allowUserInteraction]) { self.layoutIfNeeded() }
        default: break
        }
    }

    @objc func close() {
        hC.constant = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseIn], animations: {
            self.scrim.alpha = 0
            self.layoutIfNeeded()
        }) { _ in self.removeFromSuperview() }
    }
}




final class LXBlockTarget: NSObject {
    let f: () -> Void
    init(_ f: @escaping () -> Void) { self.f = f }
    @objc func fire() { f() }
}
