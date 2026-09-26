import Foundation
import UIKit
import Capacitor
import PushKit
import CallKit
import AVFoundation
import Speech

final class LXCallCenter: NSObject, PKPushRegistryDelegate, CXProviderDelegate {
    static let shared = LXCallCenter()
    static var onEvent: ((String, [String: Any]) -> Void)?
    static var voipToken: String?
    private var registry: PKPushRegistry?
    private let provider: CXProvider
    let controllerRef = CXCallController()
    private var controller: CXCallController { controllerRef }
    private(set) var activeUUID: UUID?
    private var activeInfo: [String: Any] = [:]
    private var answered = false
    private var ringTimer: Timer?

    private override init() {
        let cfg = CXProviderConfiguration()
        cfg.supportsVideo = false
        cfg.maximumCallGroups = 1
        cfg.maximumCallsPerCallGroup = 1
        cfg.supportedHandleTypes = [.generic]
        cfg.includesCallsInRecents = true
        provider = CXProvider(configuration: cfg)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func start() {
        if LustreConfig.webless {
            Self.onEvent = { act, info in LXCallSession.shared.handleCallKit(act, info) }
        }
        let r = PKPushRegistry(queue: .main)
        r.delegate = self
        r.desiredPushTypes = [.voIP]
        registry = r
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let tok = credentials.token.map { String(format: "%02x", $0) }.joined()
        Self.voipToken = tok
        post("/app/voip_token", ["token": tok])
    }
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        if type == .voIP { Self.voipToken = nil }
    }
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }
        let lx = (payload.dictionaryPayload["lx"] as? [String: Any]) ?? [:]
        reportIncoming(lx)
        completion()
    }

    func reportIncoming(_ info: [String: Any]) {
        let who = (info["who"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Lustre"
        let uuid = UUID()
        if activeUUID != nil {
            provider.reportNewIncomingCall(with: uuid, update: CXCallUpdate()) { [weak self] _ in
                self?.provider.reportCall(with: uuid, endedAt: nil, reason: .unanswered)
            }
            return
        }
        activeUUID = uuid
        activeInfo = info
        answered = false
        let up = CXCallUpdate()
        up.remoteHandle = CXHandle(type: .generic, value: who)
        up.localizedCallerName = who
        up.hasVideo = false
        up.supportsHolding = false
        up.supportsGrouping = false
        up.supportsUngrouping = false
        up.supportsDTMF = false
        provider.reportNewIncomingCall(with: uuid, update: up) { [weak self] err in
            guard let s = self else { return }
            if err != nil { s.activeUUID = nil; return }
            DispatchQueue.main.async { Self.onEvent?("incoming", s.activeInfo) }
        }
        ringTimer?.invalidate()
        ringTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            guard let s = self, let u = s.activeUUID, !s.answered else { return }
            s.provider.reportCall(with: u, endedAt: nil, reason: .unanswered)
            s.activeUUID = nil
            Self.onEvent?("missed", s.activeInfo)
        }
    }

    func webDidAccept() {
        guard let u = activeUUID, !answered else { return }
        answered = true
        ringTimer?.invalidate()
        controller.request(CXTransaction(action: CXAnswerCallAction(call: u))) { _ in }
    }
    func webDidEnd(declined: Bool) {
        guard let u = activeUUID else { return }
        ringTimer?.invalidate()
        activeUUID = nil
        provider.reportCall(with: u, endedAt: nil, reason: declined ? .declinedElsewhere : .remoteEnded)
    }

    func activeUUIDSet(_ u: UUID?) {
        activeUUID = u
        answered = u != nil
        ringTimer?.invalidate()
        if u == nil { activeInfo = [:] }
    }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        action.fulfill()
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
    }
    func providerDidReset(_ provider: CXProvider) {
        activeUUID = nil
        ringTimer?.invalidate()
    }
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        ringTimer?.invalidate()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        let already = answered
        answered = true
        action.fulfill()
        if !already { DispatchQueue.main.async { Self.onEvent?("answer", self.activeInfo) } }
    }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        ringTimer?.invalidate()
        let wasAnswered = answered
        activeUUID = nil
        action.fulfill()
        DispatchQueue.main.async { Self.onEvent?(wasAnswered ? "end" : "decline", self.activeInfo) }
    }
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        DispatchQueue.main.async { LXCallSession.shared.onAudioActivated() }
    }
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}

    private func post(_ path: String, _ body: [String: Any]) {
        guard let url = URL(string: LustreConfig.apiBase + path) else { return }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r).resume()
    }
}

@objc(CallKitPlugin)
public class CallKitPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CallKitPlugin"
    public let jsName = "NativeCall"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "accepted", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "ended", returnType: CAPPluginReturnPromise),
    ]
    public override func load() {
        if LustreConfig.webless { return }
        LXCallCenter.onEvent = { [weak self] act, info in
            var d: [String: Any] = ["act": act]
            for (k, v) in info { d[k] = v }
            self?.notifyListeners("callkit", data: d)
        }
    }
    @objc func available(_ call: CAPPluginCall) {
        call.resolve(["ok": true, "token": LXCallCenter.voipToken ?? ""])
    }
    @objc func accepted(_ call: CAPPluginCall) {
        DispatchQueue.main.async { LXCallCenter.shared.webDidAccept(); call.resolve(["ok": true]) }
    }
    @objc func ended(_ call: CAPPluginCall) {
        let declined = call.getBool("declined") ?? false
        DispatchQueue.main.async { LXCallCenter.shared.webDidEnd(declined: declined); call.resolve(["ok": true]) }
    }
}

extension LXCallCenter {
    static var onAudio: (() -> Void)?
    func startOutgoing(name: String, failed: @escaping () -> Void) {
        let uuid = UUID()
        activeUUIDSet(uuid)
        let act = CXStartCallAction(call: uuid, handle: CXHandle(type: .generic, value: name))
        controllerRef.request(CXTransaction(action: act)) { err in
            if err != nil { DispatchQueue.main.async { self.activeUUIDSet(nil); failed() } }
        }
    }
    func endLocal() {
        guard let u = activeUUID else { return }
        controllerRef.request(CXTransaction(action: CXEndCallAction(call: u))) { [weak self] err in
            if err != nil { self?.webDidEnd(declined: false) }
        }
    }
}

final class LXCallSession: NSObject, AVAudioPlayerDelegate {
    static let shared = LXCallSession()
    enum Phase { case connecting, listening, thinking, speaking }
    private(set) var active = false
    private(set) var callId = ""
    private(set) var sid = ""
    private(set) var who = "Claude"
    private(set) var startedAt = Date()
    private(set) var phase: Phase = .connecting
    private(set) var partial = ""
    private(set) var line = ""
    private(set) var level: CGFloat = 0
    var muted = false
    var speaker = true
    private var viaCallKit = false
    private let engine = AVAudioEngine()
    private var tapOn = false
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var gen = 0
    private var taskStarted = Date()
    private var lastPartialAt = Date()
    private var tick: Timer?
    private struct Item { let text: String; var data: Data?; var failed: Bool }
    private var items: [Item] = []
    private var player: AVAudioPlayer?
    private var playGuard: DispatchWorkItem?
    private var speaking = false
    private var streamBuf = ""
    private var spoken = 0
    private var view: LXCallView?

    var isActive: Bool { active }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let s = self, s.active, s.view == nil else { return }
            s.showView()
        }
    }

    static func apiSid(_ s: String) -> String { (s == "__legacy__") ? "" : s }

    static func peer(_ sid: String) -> (name: String, avatar: String) {
        let zhao = sid.isEmpty || sid == "__legacy__" || LXSessionsAPI.personaBySid[sid] == "zhao"
        return zhao ? (LXNick.zhao, "zhao") : (LXNick.yan, "ai")
    }

    func startOutgoing() {
        guard !active else { view?.expand(); return }
        let s = Self.apiSid(ChatListPlugin.live?.data.session ?? "")
        begin(callId: "call-" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36), sid: s, who: Self.peer(s).name, firstLine: nil)
        viaCallKit = true
        LXCallCenter.shared.startOutgoing(name: who) { [weak self] in
            self?.viaCallKit = false
            self?.beginAudio()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let s = self, s.active, !s.engine.isRunning else { return }
            s.beginAudio()
        }
    }

    func handleCallKit(_ act: String, _ info: [String: Any]) {
        switch act {
        case "answer":
            guard !active else { return }
            let cid = (info["call_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                ?? "call-" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36)
            let sid = Self.apiSid((info["session"] as? String) ?? "")
            let who = (info["who"] as? String).flatMap { $0.isEmpty || $0 == "Claude" ? nil : $0 } ?? Self.peer(sid).name
            viaCallKit = true
            begin(callId: cid, sid: sid, who: who,
                  firstLine: (info["text"] as? String).flatMap { $0.isEmpty ? nil : $0 })
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let s = self, s.active, !s.engine.isRunning else { return }
                s.beginAudio()
            }
        case "end":
            close(fromSystem: true)
        case "decline":
            var body: [String: Any] = ["action": "decline"]
            if let c = info["call_id"] as? String { body["call_id"] = c }
            let s = Self.apiSid((info["session"] as? String) ?? "")
            if !s.isEmpty { body["api_session"] = s }
            post("/app/call", body)
        default:
            break
        }
    }

    private func begin(callId: String, sid: String, who: String, firstLine: String?) {
        active = true
        self.callId = callId
        self.sid = sid
        self.who = who
        startedAt = Date()
        muted = false
        speaker = true
        partial = ""; line = ""; streamBuf = ""; spoken = 0; items = []
        phase = .connecting
        var body: [String: Any] = ["action": "start", "call_id": callId]
        if !sid.isEmpty { body["api_session"] = sid }
        post("/app/call", body)
        showView()
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.onTick() }
        if let f = firstLine { speak(f) }
    }

    func onAudioActivated() {
        guard active, !engine.isRunning else { return }
        beginAudio()
    }

    private func beginAudio() {
        guard active else { return }
        let ses = AVAudioSession.sharedInstance()
        try? ses.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker])
        if !viaCallKit { try? ses.setActive(true) }
        applySpeaker()
        SFSpeechRecognizer.requestAuthorization { st in
            DispatchQueue.main.async {
                guard self.active else { return }
                guard st == .authorized else {
                    self.line = "没有语音识别权限，去 设置 里打开"
                    self.view?.render()
                    return
                }
                self.startEngine()
            }
        }
    }

    private func startEngine() {
        guard active, !engine.isRunning else { return }
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.startEngine() }
            return
        }
        if tapOn { input.removeTap(onBus: 0); tapOn = false }
        input.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
            guard let s = self else { return }
            var rms: Float = 0
            if let ch = buf.floatChannelData?[0] {
                let n = Int(buf.frameLength)
                var sum: Float = 0
                for i in 0..<n { sum += ch[i] * ch[i] }
                rms = n > 0 ? sqrt(sum / Float(n)) : 0
            }
            let lv = CGFloat(min(1, rms * 9))
            if !s.muted, !s.speaking { s.request?.append(buf) }
            DispatchQueue.main.async { s.level = s.speaking ? s.level : (s.muted ? 0 : lv) }
        }
        tapOn = true
        engine.prepare()
        do { try engine.start() } catch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.startEngine() }
            return
        }
        if !speaking { startRecognition() }
    }

    private func startRecognition() {
        guard active, !speaking, let rec = recognizer, rec.isAvailable else { return }
        stopRecognition()
        gen += 1
        let g = gen
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true
        if #available(iOS 16.0, *) { r.addsPunctuation = true }
        request = r
        taskStarted = Date()
        lastPartialAt = Date()
        partial = ""
        phase = (phase == .thinking) ? .thinking : .listening
        view?.render()
        task = rec.recognitionTask(with: r) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let s = self, s.active, g == s.gen else { return }
                if let res = result {
                    let t = res.bestTranscription.formattedString
                    if t != s.partial { s.partial = t; s.lastPartialAt = Date(); s.view?.render() }
                    if res.isFinal { s.commit(); return }
                }
                if error != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                        guard let s = self, s.active, g == s.gen, !s.speaking else { return }
                        s.startRecognition()
                    }
                }
            }
        }
    }

    private func stopRecognition() {
        gen += 1
        task?.cancel(); task = nil
        request?.endAudio(); request = nil
    }

    private func commit() {
        let text = partial.trimmingCharacters(in: .whitespacesAndNewlines)
        partial = ""
        stopRecognition()
        if !text.isEmpty {
            var body: [String: Any] = ["text": text, "source": "native_speech", "call_id": callId]
            if !sid.isEmpty { body["api_session"] = sid }
            post("/app/voice", body)
            line = ""
            phase = .thinking
        }
        view?.render()
        startRecognition()
    }

    private func onTick() {
        guard active else { return }
        if !speaking, !partial.isEmpty, Date().timeIntervalSince(lastPartialAt) > 1.2 { commit() }
        else if !speaking, partial.isEmpty, task != nil, Date().timeIntervalSince(taskStarted) > 50 { startRecognition() }
        if speaking { level = 0.45 + CGFloat.random(in: 0...0.5) }
        view?.tick()
    }

    func feed(_ obj: [String: Any]) {
        guard active else { return }
        if let type = obj["type"] as? String {
            let es = Self.apiSid((obj["api_session"] as? String) ?? "")
            guard es == sid else { return }
            switch type {
            case "reply_delta":
                if (obj["done"] as? Bool) == true { flushTail(); return }
                streamBuf += (obj["text"] as? String) ?? ""
                speakStream()
            case "typing":
                if (obj["active"] as? Bool) == true, !speaking { phase = .thinking; view?.render() }
            default: break
            }
            return
        }
        guard obj["id"] is NSNumber, let m = LXChatData.parse(obj), m.from == "ai", m.kind == "reply",
              Self.apiSid(m.session) == sid, m.ts > startedAt.addingTimeInterval(-5) else { return }
        let meta = obj["meta"] as? [String: Any] ?? [:]
        let full = ((meta["tts"] as? String).flatMap { $0.isEmpty ? nil : $0 }) ?? m.text
        if streamBuf.isEmpty {
            speak(full)
        } else if m.text.hasPrefix(streamBuf) || m.text.count > spoken {
            let chars = Array(m.text)
            if spoken < chars.count { speak(String(chars[spoken...])) }
        }
        streamBuf = ""; spoken = 0
    }

    private static let stops: Set<Character> = ["。", "！", "？", "!", "?", "；", ";", "…", "\n"]
    private func speakStream() {
        let chars = Array(streamBuf)
        guard spoken < chars.count else { return }
        var cut = -1
        for i in stride(from: chars.count - 1, through: spoken, by: -1) where Self.stops.contains(chars[i]) { cut = i; break }
        guard cut >= spoken else { return }
        let chunk = String(chars[spoken...cut])
        if chunk.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
            speak(chunk)
            spoken = cut + 1
        }
    }
    private func flushTail() {
        let chars = Array(streamBuf)
        if spoken < chars.count { speak(String(chars[spoken...])); spoken = chars.count }
    }

    func speak(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard active, !text.isEmpty else { return }
        items.append(Item(text: text, data: nil, failed: false))
        let idx = items.count - 1
        fetchTTS(text) { [weak self] d in
            guard let s = self, s.active, idx < s.items.count, s.items[idx].text == text else { return }
            if let d { s.items[idx].data = d } else { s.items[idx].failed = true }
            s.drain()
        }
        if !speaking {
            speaking = true
            stopRecognition()
            partial = ""
            phase = .speaking
            view?.render()
        }
    }

    private func drain() {
        guard active, player == nil else { return }
        while let first = items.first, first.failed { items.removeFirst() }
        guard let first = items.first else { finishSpeaking(); return }
        guard let d = first.data else { return }
        line = first.text
        view?.render()
        do {
            let p = try AVAudioPlayer(data: d)
            p.delegate = self
            player = p
            p.play()
            let w = DispatchWorkItem { [weak self] in self?.advance() }
            playGuard = w
            DispatchQueue.main.asyncAfter(deadline: .now() + p.duration + 3, execute: w)
        } catch {
            items.removeFirst()
            drain()
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.advance() }
    }
    private func advance() {
        playGuard?.cancel(); playGuard = nil
        player?.stop(); player = nil
        if !items.isEmpty { items.removeFirst() }
        drain()
    }
    private func finishSpeaking() {
        guard speaking else { return }
        speaking = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let s = self, s.active, !s.speaking else { return }
            s.phase = .listening
            s.startRecognition()
        }
    }

    func toggleMute() { muted.toggle(); if muted { partial = "" }; view?.render() }
    func toggleSpeaker() { speaker.toggle(); applySpeaker(); view?.render() }
    private func applySpeaker() {
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(speaker ? .speaker : .none)
    }

    func hangUp() { close(fromSystem: false) }

    private func close(fromSystem: Bool) {
        guard active else { return }
        active = false
        tick?.invalidate(); tick = nil
        stopRecognition()
        if tapOn { engine.inputNode.removeTap(onBus: 0); tapOn = false }
        engine.stop()
        playGuard?.cancel(); playGuard = nil
        player?.stop(); player = nil
        items = []; speaking = false
        let dur = Int(Date().timeIntervalSince(startedAt))
        var body: [String: Any] = ["action": "end", "call_id": callId, "duration_sec": dur]
        if !sid.isEmpty { body["api_session"] = sid }
        var meta: [String: Any] = ["user": "human", "call": "end", "call_id": callId]
        if dur > 0 { meta["duration"] = dur }
        if !sid.isEmpty { meta["api_session"] = sid }
        let text = String(format: "Voice call · %d:%02d", dur / 60, dur % 60)
        let ts = ISO8601DateFormatter().string(from: Date())
        post("/app/call", body) { obj in
            guard let id = obj?["id"] as? NSNumber else { return }
            DispatchQueue.main.async {
                ChatListPlugin.live?.data.handle(["id": id, "from": "human", "kind": "call",
                                                  "text": text, "ts": ts, "meta": meta])
            }
        }
        if !fromSystem { LXCallCenter.shared.endLocal() }
        if !viaCallKit { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
        LXCallPill.hide()
        view?.dismiss()
        view = nil
    }

    private func showView() {
        guard let host = ChatListPlugin.live?.bridge?.viewController?.view else { return }
        host.endEditing(true)
        let v = LXCallView(session: self)
        v.frame = host.bounds
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.addSubview(v)
        view = v
        v.present()
    }

    func minimize() {
        guard let v = view, let host = v.superview else { return }
        v.hideAway()
        LXCallPill.show(host: host, started: startedAt) { [weak self] in self?.view?.expand() }
    }

    var elapsedText: String {
        let s = max(0, Int(Date().timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func fetchTTS(_ text: String, done: @escaping (Data?) -> Void) {
        guard let url = URL(string: LustreConfig.apiBase + "/app/tts") else { done(nil); return }
        var r = URLRequest(url: url, timeoutInterval: 30)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
        URLSession.shared.dataTask(with: r) { d, resp, _ in
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200 && (d?.count ?? 0) > 200
            DispatchQueue.main.async { done(ok ? d : nil) }
        }.resume()
    }

    private func post(_ path: String, _ body: [String: Any], done: (([String: Any]?) -> Void)? = nil) {
        guard let url = URL(string: LustreConfig.apiBase + path) else { return }
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: r) { d, _, _ in
            done?(d.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })
        }.resume()
    }
}

final class LXCallView: UIView {
    private unowned let session: LXCallSession
    private let wall = LXDefaultWall()
    private let minBtn = UIButton(type: .system)
    private let ring = UIView()
    private let avatar = UIImageView()
    private var barsL: [UIView] = []
    private var barsR: [UIView] = []
    private let nameL = UILabel()
    private let statusL = UILabel()
    private let timerL = UILabel()
    private let quoteL = UILabel()
    private let capL = UILabel()
    private let transV = UIVisualEffectView(effect: nil)
    private let transL = UILabel()
    private let muteB = UIButton(type: .system)
    private let spkB = UIButton(type: .system)
    private let hangB = UIButton(type: .system)
    private let muteL = UILabel()
    private let spkL = UILabel()
    private var accent = UIColor(red: 0.663, green: 0.851, blue: 0.933, alpha: 1)
    private var text = UIColor.white
    private var soft = UIColor(white: 0.7, alpha: 1)
    private var chip = UIColor(white: 1, alpha: 0.08)

    init(session: LXCallSession) {
        self.session = session
        super.init(frame: .zero)
        let pal = LXMoonPalette.chat[RPSpec.moonState] ?? [:]
        func c(_ k: String) -> UIColor? { (pal[k] as? String).flatMap { NativeInputPlugin.color($0) } }
        backgroundColor = c("bg") ?? .black
        accent = c("accent") ?? accent
        text = c("fg") ?? text
        soft = c("textSoft") ?? soft
        chip = LXSheetInk.chip
        wall.frame = bounds
        wall.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        wall.isHidden = RPSpec.moonState != "day"
        addSubview(wall)
        build()
        render()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func circleButton(_ b: UIButton, _ sf: String, size: CGFloat, bg: UIColor, fg: UIColor) {
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(systemName: sf, withConfiguration: UIImage.SymbolConfiguration(pointSize: size * 0.34, weight: .regular)), for: .normal)
        b.tintColor = fg
        b.backgroundColor = bg
        b.layer.cornerRadius = size / 2
        b.widthAnchor.constraint(equalToConstant: size).isActive = true
        b.heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    private func build() {
        let font = { (s: CGFloat) in LXBubbleCell.bodyFont().withSize(s) }
        circleButton(minBtn, "chevron.down", size: 36, bg: chip, fg: text)
        minBtn.addAction(UIAction { [weak self] _ in self?.session.minimize() }, for: .touchUpInside)
        addSubview(minBtn)

        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.layer.cornerRadius = 74
        ring.layer.borderWidth = 1.5
        ring.layer.borderColor = accent.withAlphaComponent(0.55).cgColor
        ring.layer.shadowColor = accent.cgColor
        ring.layer.shadowOffset = .zero
        ring.layer.shadowRadius = 18
        ring.layer.shadowOpacity = 0.2
        addSubview(ring)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 64
        avatar.backgroundColor = chip
        avatar.image = LXAvatarStore.image(LXCallSession.peer(session.sid).avatar)
        ring.addSubview(avatar)

        let barRowL = UIStackView(), barRowR = UIStackView()
        for (row, store) in [(barRowL, 0), (barRowR, 1)] {
            row.translatesAutoresizingMaskIntoConstraints = false
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 4
            for _ in 0..<8 {
                let b = UIView()
                b.backgroundColor = accent
                b.layer.cornerRadius = 1.25
                b.translatesAutoresizingMaskIntoConstraints = false
                b.widthAnchor.constraint(equalToConstant: 2.5).isActive = true
                b.heightAnchor.constraint(equalToConstant: 26).isActive = true
                b.transform = CGAffineTransform(scaleX: 1, y: 0.2)
                row.addArrangedSubview(b)
                if store == 0 { barsL.append(b) } else { barsR.append(b) }
            }
            addSubview(row)
        }

        nameL.font = font(30); nameL.textColor = text; nameL.textAlignment = .center
        statusL.font = font(13); statusL.textColor = accent; statusL.textAlignment = .center
        timerL.font = UIFont.monospacedDigitSystemFont(ofSize: 21, weight: .regular); timerL.textColor = soft; timerL.textAlignment = .center
        quoteL.font = font(21); quoteL.textColor = text; quoteL.textAlignment = .center; quoteL.numberOfLines = 4
        capL.font = font(11.5); capL.textColor = soft.withAlphaComponent(0.7); capL.textAlignment = .center
        capL.text = "实时字幕 · live transcript"
        transL.font = font(15); transL.textColor = text; transL.numberOfLines = 3
        for l in [nameL, statusL, timerL, quoteL, capL] { l.translatesAutoresizingMaskIntoConstraints = false; addSubview(l) }

        transV.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) { transV.effect = UIGlassEffect(style: .clear) }
        else { transV.effect = UIBlurEffect(style: LXSheetInk.dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight) }
        transV.layer.cornerRadius = 20
        transV.clipsToBounds = true
        addSubview(transV)
        transL.translatesAutoresizingMaskIntoConstraints = false
        transV.contentView.addSubview(transL)

        circleButton(muteB, "mic.slash", size: 64, bg: chip, fg: text)
        circleButton(spkB, "speaker.wave.2", size: 64, bg: chip, fg: text)
        circleButton(hangB, "phone.down.fill", size: 70, bg: .systemRed, fg: .white)
        muteB.addAction(UIAction { [weak self] _ in self?.session.toggleMute() }, for: .touchUpInside)
        spkB.addAction(UIAction { [weak self] _ in self?.session.toggleSpeaker() }, for: .touchUpInside)
        hangB.addAction(UIAction { [weak self] _ in self?.session.hangUp() }, for: .touchUpInside)
        hangB.layer.shadowColor = UIColor.systemRed.cgColor
        hangB.layer.shadowOpacity = 0.34
        hangB.layer.shadowRadius = 12
        hangB.layer.shadowOffset = CGSize(width: 0, height: 6)
        muteL.text = "静音"; spkL.text = "扬声器"
        func col(_ b: UIButton, _ l: UILabel?) -> UIStackView {
            let v = UIStackView(arrangedSubviews: [b])
            v.axis = .vertical; v.alignment = .center; v.spacing = 8
            if let l { l.font = font(12); l.textColor = soft; v.addArrangedSubview(l) }
            return v
        }
        let controls = UIStackView(arrangedSubviews: [col(muteB, muteL), col(hangB, nil), col(spkB, spkL)])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.axis = .horizontal
        controls.alignment = .top
        controls.distribution = .equalSpacing
        addSubview(controls)

        let g = safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            minBtn.topAnchor.constraint(equalTo: g.topAnchor, constant: 10),
            minBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            ring.topAnchor.constraint(equalTo: g.topAnchor, constant: 70),
            ring.centerXAnchor.constraint(equalTo: centerXAnchor),
            ring.widthAnchor.constraint(equalToConstant: 148),
            ring.heightAnchor.constraint(equalToConstant: 148),
            avatar.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 128),
            avatar.heightAnchor.constraint(equalToConstant: 128),
            barRowL.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            barRowL.trailingAnchor.constraint(equalTo: ring.leadingAnchor, constant: -16),
            barRowR.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            barRowR.leadingAnchor.constraint(equalTo: ring.trailingAnchor, constant: 16),
            nameL.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 22),
            nameL.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusL.topAnchor.constraint(equalTo: nameL.bottomAnchor, constant: 8),
            statusL.centerXAnchor.constraint(equalTo: centerXAnchor),
            timerL.topAnchor.constraint(equalTo: statusL.bottomAnchor, constant: 8),
            timerL.centerXAnchor.constraint(equalTo: centerXAnchor),
            quoteL.topAnchor.constraint(equalTo: timerL.bottomAnchor, constant: 26),
            quoteL.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            quoteL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            capL.bottomAnchor.constraint(equalTo: transV.topAnchor, constant: -8),
            capL.centerXAnchor.constraint(equalTo: centerXAnchor),
            transV.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            transV.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            transV.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -28),
            transV.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            transL.topAnchor.constraint(equalTo: transV.contentView.topAnchor, constant: 14),
            transL.bottomAnchor.constraint(equalTo: transV.contentView.bottomAnchor, constant: -14),
            transL.leadingAnchor.constraint(equalTo: transV.contentView.leadingAnchor, constant: 16),
            transL.trailingAnchor.constraint(equalTo: transV.contentView.trailingAnchor, constant: -16),
            controls.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 44),
            controls.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -44),
            controls.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -26),
        ])
    }

    func render() {
        nameL.text = session.who
        let st: String
        switch session.phase {
        case .connecting: st = "on call"
        case .listening: st = session.muted ? "muted" : "listening"
        case .thinking: st = "thinking"
        case .speaking: st = "speaking"
        }
        statusL.attributedText = NSAttributedString(string: "✦ " + st + " ✦", attributes: [.kern: 2.0])
        if !session.line.isEmpty, session.phase == .speaking {
            quoteL.text = "“" + session.line + "”"
            quoteL.textColor = text
        } else {
            quoteL.text = session.phase == .thinking ? "我在想…" : (session.line.isEmpty ? "我在听，你慢慢说" : session.line)
            quoteL.textColor = soft
        }
        transL.text = session.partial.isEmpty ? " " : "你: " + session.partial
        muteB.backgroundColor = session.muted ? accent : chip
        muteB.tintColor = session.muted ? (LXSheetInk.dark ? .black : .white) : text
        spkB.backgroundColor = session.speaker ? accent : chip
        spkB.tintColor = session.speaker ? (LXSheetInk.dark ? .black : .white) : text
        tick()
    }

    func tick() {
        timerL.text = session.elapsedText
        let lv = session.level
        ring.layer.shadowOpacity = Float(0.18 + lv * 0.6)
        ring.layer.shadowRadius = 14 + lv * 18
        UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut]) {
            for (i, b) in (self.barsL.reversed() + self.barsR).enumerated() {
                let k = CGFloat((i % 8) + 1) / 8
                let v = max(0.18, min(1, lv * (0.55 + 0.45 * sin(k * 3.1 + CGFloat(Date().timeIntervalSince1970 * 4)))))
                b.transform = CGAffineTransform(scaleX: 1, y: v)
            }
        }
    }

    func present() {
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.34, delay: 0, options: [.curveEaseOut]) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    func hideAway() {
        UIView.animate(withDuration: 0.28, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 12)
        }, completion: { _ in if self.alpha == 0 { self.isHidden = true } })
    }
    func expand() {
        LXCallPill.hide()
        superview?.bringSubviewToFront(self)
        isHidden = false
        present()
    }
    func dismiss() {
        UIView.animate(withDuration: 0.34, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: 12)
        }, completion: { _ in self.removeFromSuperview() })
    }
}
