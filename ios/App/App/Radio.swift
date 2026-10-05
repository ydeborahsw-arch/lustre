import UIKit
import AVFoundation
import MediaPlayer

// MARK: - 1005 电台(她的单):抽屉里的 Radio。他做的节目 + 她从聊天里长按「放进电台」的语音。
// 列表页 → 播放页(文字像歌词一句一句亮,点哪句跳哪句;锁屏能控制;播完接着下一个)。
// 接口:GET /app/radio、POST /app/radio/rename、/app/radio/delete;聊天里加是 /app/radio/add。
// 实时:radio_new / radio_update / radio_del。样子跟 Pocket 一家(顶栏标题 + 右上关闭,颜色用 LXPocketInk)。
// 预览里不连服务器,没有声音,时间是假的往前走。

struct LXRadioItem {
    struct Cue { let t: Double; let s: String }
    let id: Int
    var title: String
    let source: String      // show / voice
    let file: String
    let duration: Int
    let text: String
    let cues: [Cue]
    let status: String      // aligning / ready
    let ts: String

    init?(_ d: [String: Any]) {
        guard let id = (d["id"] as? NSNumber)?.intValue, let file = d["file"] as? String else { return nil }
        self.id = id
        title = (d["title"] as? String) ?? ""
        source = (d["source"] as? String) ?? "show"
        self.file = file
        duration = (d["duration"] as? NSNumber)?.intValue ?? 0
        text = (d["text"] as? String) ?? ""
        cues = ((d["cues"] as? [[String: Any]]) ?? []).compactMap { c in
            guard let t = (c["t"] as? NSNumber)?.doubleValue, let s = c["s"] as? String else { return nil }
            return Cue(t: t, s: s)
        }
        status = (d["status"] as? String) ?? "ready"
        ts = (d["ts"] as? String) ?? ""
    }

    var dict: [String: Any] {
        ["id": id, "title": title, "source": source, "file": file, "duration": duration, "text": text,
         "cues": cues.map { ["t": $0.t, "s": $0.s] as [String: Any] }, "status": status, "ts": ts]
    }

    /// 播放页显示的行:有时间就按时间那一版;还没量出来就按文字切行(不亮)
    var lines: [Cue] {
        if !cues.isEmpty { return cues }
        return text.split(whereSeparator: { $0 == "\n" }).map { Cue(t: -1, s: String($0)) }
    }

    var meta: String {
        let kind = source == "voice" ? "Voice note" : "Show"
        var parts = [kind]
        if duration > 0 { parts.append(LXRadioAudio.clock(Double(duration))) }
        if let d = LXRadioItem.parse(ts) { parts.append(LXRadioItem.dayF.string(from: d)) }
        return parts.joined(separator: " · ")
    }

    static let dayF: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "MMM d"
        return f
    }()
    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()
    static func parse(_ s: String) -> Date? { isoFrac.date(from: s) ?? iso.date(from: s) }
}

enum LXRadioNet {
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

    static func audioURL(_ file: String) -> URL? {
        let tok = LustreConfig.secret.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        return URL(string: LustreConfig.apiBase + "/uploads/" + file + "?token=" + tok)
    }

    /// 聊天里长按语音「放进电台」
    static func add(msgId: Int64, done: @escaping (Bool) -> Void) {
        call("POST", "/app/radio/add", ["msg_id": msgId]) { o, _ in done(o != nil) }
    }
}

// MARK: - 播放(全 App 一个):锁屏控制和聊天里的语音条共用一套,谁在放归谁

final class LXRadioAudio: NSObject {
    static let shared = LXRadioAudio()
    /// 现在锁屏 / 耳机按键归电台管
    static var current: Bool { shared.item != nil && shared.owns }

    private(set) var item: LXRadioItem?
    private(set) var queue: [LXRadioItem] = []
    private(set) var playing = false
    private(set) var elapsed: Double = 0
    private(set) var length: Double = 0
    private var owns = false
    private var player: AVPlayer?
    private var timeObs: Any?
    private var endObs: Any?
    private var failObs: Any?
    private var statusObs: NSKeyValueObservation?
    private var itemObs: NSKeyValueObservation?
    private var seeking = false         // 跳的那一下还没落地:别让走表把进度拽回旧位置
    private var seekGen = 0
    private var fake: Timer?            // 预览:没有声音,时间自己往前走
    private var listeners: [ObjectIdentifier: () -> Void] = [:]
    private static let posKey = "lx.radio.pos"

    func listen(_ who: AnyObject, _ f: @escaping () -> Void) { listeners[ObjectIdentifier(who)] = f }
    func unlisten(_ who: AnyObject) { listeners[ObjectIdentifier(who)] = nil }
    private func tell() { listeners.values.forEach { $0() } }

    static func clock(_ s: Double) -> String {
        let v = max(0, Int(s.rounded(.down)))
        return v >= 3600 ? String(format: "%d:%02d:%02d", v / 3600, v / 60 % 60, v % 60) : String(format: "%d:%02d", v / 60, v % 60)
    }

    /// 播这一条;queue 是播完往下接的那一串(列表的顺序)。saveOld = false:上一条是放完了的,别再记它的位置
    func play(_ it: LXRadioItem, queue q: [LXRadioItem], saveOld: Bool = true) {
        if item?.id == it.id { if !playing { resume() }; return }
        guard !LXCallSession.shared.active else { return }   // 通话里不放
        teardown(savePosition: saveOld)
        LXVoiceBar.stopAll()        // 聊天里正在放的语音先停
        item = it
        queue = q
        owns = true
        length = Double(it.duration)
        let resumeAt = savedPosition(it)
        elapsed = resumeAt
        LXVoiceDock.sync()
        if LustreConfig.isPreview {
            playing = true
            fake = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let s = self, s.playing else { return }
                s.elapsed = min(s.length, s.elapsed + 0.1)
                if s.length > 0, s.elapsed >= s.length { s.playing = false }   // 预览不连播,放到头停住
                s.tell()
            }
            tell()
            return
        }
        guard let u = LXRadioNet.audioURL(it.file) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let src = LXVoiceCache.cached(u) ?? u
        if src == u { LXVoiceCache.prefetch(u) }
        let pi = AVPlayerItem(url: src)
        let p = AVPlayer(playerItem: pi)
        p.automaticallyWaitsToMinimizeStalling = false
        player = p
        timeObs = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] t in
            guard let s = self, !s.seeking else { return }
            s.elapsed = max(0, t.seconds)
            if let d = s.player?.currentItem?.duration.seconds, d.isFinite, d > 0, abs(d - s.length) > 0.5 {
                s.length = d
                s.pushNowPlaying()
            }
            s.tell()
        }
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: pi, queue: .main) { [weak self] _ in
            self?.finished()
        }
        failObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: pi, queue: .main) { [weak self] _ in
            self?.stoppedOnItsOwn()
        }
        // 来电话、Siri、拔耳机、网卡住:播放器自己停了,这边跟着改成暂停(锁屏和按钮才对得上)
        statusObs = p.observe(\.timeControlStatus, options: [.new]) { [weak self] pl, _ in
            DispatchQueue.main.async { self?.syncStatus(pl) }
        }
        itemObs = pi.observe(\.status, options: [.new]) { [weak self] i, _ in
            guard i.status == .failed else { return }
            DispatchQueue.main.async { self?.stoppedOnItsOwn() }
        }
        if resumeAt > 0 { seekPlayer(p, resumeAt) }
        LXVoiceBar.wireRemote()
        p.play()
        playing = true
        enableTrackButtons(true)
        pushNowPlaying()
        tell()
    }

    func toggle() { playing ? pause() : resume() }

    func pause() {
        guard item != nil else { return }
        player?.pause()
        playing = false
        savePosition()
        pushNowPlaying()
        tell()
    }

    func resume() {
        guard let it = item, !LXCallSession.shared.active else { return }
        // 文件上次没拉下来(断网之类):重新开一个播放器,从记住的位置接着
        if player?.currentItem?.status == .failed {
            let q = queue
            teardown(savePosition: true)
            item = nil
            play(it, queue: q)
            return
        }
        if !owns { LXVoiceBar.stopAll(); owns = true; enableTrackButtons(true) }
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        playing = true
        pushNowPlaying()
        tell()
    }

    func seek(to s: Double) {
        guard item != nil else { return }
        let t = max(0, min(length > 0 ? length - 0.5 : s, s))
        elapsed = t
        if let p = player { seekPlayer(p, t) }
        tell()
    }

    /// 跳到准确的那一秒(点哪句跳哪句要准);落地前走表不改进度,连着跳只认最后一下
    private func seekPlayer(_ p: AVPlayer, _ t: Double) {
        seekGen += 1
        let g = seekGen
        seeking = true
        p.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async {
                guard let s = self, g == s.seekGen else { return }
                s.seeking = false
                s.pushNowPlaying()
            }
        }
    }

    private func syncStatus(_ p: AVPlayer) {
        guard p === player else { return }
        switch p.timeControlStatus {
        case .paused where playing:
            playing = false
            savePosition()
            pushNowPlaying()
            tell()
        case .playing where !playing:
            playing = true
            pushNowPlaying()
            tell()
        default: break
        }
    }

    private func stoppedOnItsOwn() {
        guard playing else { return }
        playing = false
        savePosition()
        pushNowPlaying()
        tell()
    }

    func skip(_ d: Double) { seek(to: elapsed + d) }

    func next() {
        guard let it = item, let i = queue.firstIndex(where: { $0.id == it.id }), i + 1 < queue.count else { return }
        clearPosition(it)
        play(queue[i + 1], queue: queue, saveOld: false)
    }

    func prev() {
        guard let it = item else { return }
        // 放了 3 秒以上:回到这一条开头;不然上一条
        if elapsed > 3 { seek(to: 0); return }
        guard let i = queue.firstIndex(where: { $0.id == it.id }), i > 0 else { seek(to: 0); return }
        play(queue[i - 1], queue: queue)
    }

    /// 通话 / 录音 / 共看话筒要用声音通道:电台先停,不然会放进通话里
    static func yieldToMic() {
        if Thread.isMainThread { shared.pause() } else { DispatchQueue.main.async { shared.pause() } }
    }

    /// 聊天里点了语音条:电台让位(暂停,位置记住)
    func yieldToVoice() {
        guard item != nil, owns else { return }
        player?.pause()
        playing = false
        owns = false
        savePosition()
        enableTrackButtons(false)
        tell()
    }

    /// 列表里这一条被拿掉/改了
    func refresh(_ list: [LXRadioItem]) {
        queue = list
        if let it = item {
            if let n = list.first(where: { $0.id == it.id }) {
                if n.title != it.title { LXVoiceDock.sync() }
                item = n; pushNowPlaying(); tell()
            }
            else { stop() }
        }
    }

    func stop() {
        teardown(savePosition: true)
        item = nil
        LXVoiceDock.sync()
        tell()
    }

    private func finished() {
        if let it = item { clearPosition(it) }
        if let it = item, let i = queue.firstIndex(where: { $0.id == it.id }), i + 1 < queue.count {
            play(queue[i + 1], queue: queue, saveOld: false)   // 连播:接着列表里的下一条
        } else {
            teardown(savePosition: false)
            item = nil
            LXVoiceDock.sync()
            tell()
        }
    }

    private func teardown(savePosition save: Bool) {
        if save { savePosition() }
        if let p = player, let o = timeObs { p.removeTimeObserver(o) }
        timeObs = nil
        if let o = endObs { NotificationCenter.default.removeObserver(o) }
        endObs = nil
        if let o = failObs { NotificationCenter.default.removeObserver(o) }
        failObs = nil
        statusObs?.invalidate(); statusObs = nil
        itemObs?.invalidate(); itemObs = nil
        seeking = false
        player?.pause()
        player = nil
        fake?.invalidate()
        fake = nil
        playing = false
        if owns {
            owns = false
            enableTrackButtons(false)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    // 记住每一条放到哪(下次点开从那里接着)
    private func savedPosition(_ it: LXRadioItem) -> Double {
        let d = (UserDefaults.standard.dictionary(forKey: Self.posKey) as? [String: Double]) ?? [:]
        let v = d[String(it.id)] ?? 0
        return (it.duration > 0 && v > Double(it.duration) - 5) ? 0 : v
    }
    private func savePosition() {
        guard let it = item, !LustreConfig.isPreview else { return }
        var d = (UserDefaults.standard.dictionary(forKey: Self.posKey) as? [String: Double]) ?? [:]
        d[String(it.id)] = elapsed > 3 ? elapsed : nil   // 拉回开头再停 = 下次从头
        UserDefaults.standard.set(d, forKey: Self.posKey)
    }
    private func clearPosition(_ it: LXRadioItem) {
        guard !LustreConfig.isPreview else { return }
        var d = (UserDefaults.standard.dictionary(forKey: Self.posKey) as? [String: Double]) ?? [:]
        d[String(it.id)] = nil
        UserDefaults.standard.set(d, forKey: Self.posKey)
    }

    private func enableTrackButtons(_ on: Bool) {
        let c = MPRemoteCommandCenter.shared()
        c.nextTrackCommand.isEnabled = on
        c.previousTrackCommand.isEnabled = on
    }

    func pushNowPlaying() {
        guard let it = item, owns, !LustreConfig.isPreview else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: it.title.isEmpty ? "Radio" : it.title,
                                   MPMediaItemPropertyArtist: "Radio",
                                   MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
        if length > 0 { info[MPMediaItemPropertyPlaybackDuration] = length }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] = playing ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// 锁屏 / 耳机按键:电台在放就归电台,不然返回 nil 交给聊天语音条
    static func remote(_ cmd: String, _ pos: Double? = nil) -> MPRemoteCommandHandlerStatus? {
        guard current else { return nil }
        let a = shared
        switch cmd {
        case "play": a.resume()
        case "pause": a.pause()
        case "toggle": a.toggle()
        case "seek": if let p = pos { a.seek(to: p) }
        case "next": a.next()
        case "prev": a.prev()
        default: return .commandFailed
        }
        return .success
    }
}

// MARK: - 颜色、字

enum LXRadioInk {
    static var bg: UIColor { LXPocketInk.pageBg }
    static var card: UIColor { LXPocketInk.cardBg }
    static var line: UIColor { LXPocketInk.line }
    static var text: UIColor { LXPocketInk.text }
    static var soft: UIColor { LXPocketInk.textSoft }
    static var faint: UIColor { LXPocketInk.textFaint }
    static var star: UIColor { LXPocketInk.star }
    static var onStar: UIColor { LXPocketInk.fg }
    static func font(_ s: CGFloat, _ bold: Bool = false) -> UIFont { LXCardSheet.anthro(s, semibold: bold) }
    static func sym(_ name: String, _ size: CGFloat, _ w: UIImage.SymbolWeight = .medium) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: w))
    }
}

// MARK: - 列表里的一条

final class LXRadioRow: UIControl {
    private(set) var item: LXRadioItem
    private let icon = UIImageView()
    private let ring = UIView()
    private let titleL = UILabel()
    private let metaL = UILabel()
    var onTap: ((LXRadioItem) -> Void)?
    var onMenu: ((LXRadioItem) -> UIMenu?)?

    init(_ it: LXRadioItem) {
        item = it
        super.init(frame: .zero)
        layer.cornerRadius = 14
        ring.layer.cornerRadius = 21
        ring.isUserInteractionEnabled = false
        icon.contentMode = .center
        icon.isUserInteractionEnabled = false
        titleL.numberOfLines = 2
        titleL.isUserInteractionEnabled = false
        metaL.isUserInteractionEnabled = false
        for v in [ring, icon, titleL, metaL] { v.translatesAutoresizingMaskIntoConstraints = false; addSubview(v) }
        NSLayoutConstraint.activate([
            ring.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            ring.centerYAnchor.constraint(equalTo: centerYAnchor),
            ring.widthAnchor.constraint(equalToConstant: 42), ring.heightAnchor.constraint(equalToConstant: 42),
            icon.centerXAnchor.constraint(equalTo: ring.centerXAnchor), icon.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            titleL.leadingAnchor.constraint(equalTo: ring.trailingAnchor, constant: 12),
            titleL.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            titleL.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            metaL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            metaL.trailingAnchor.constraint(equalTo: titleL.trailingAnchor),
            metaL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 3),
            metaL.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -13),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 68),
        ])
        addAction(UIAction { [weak self] _ in guard let s = self else { return }; s.onTap?(s.item) }, for: .touchUpInside)
        isContextMenuInteractionEnabled = true   // 长按:改名 / 拿掉
        set(it)
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(_ it: LXRadioItem) {
        item = it
        titleL.text = it.title.isEmpty ? "Untitled" : it.title
        metaL.text = it.meta
        paint()
    }

    private var shownState = -1   // 0 没在放 / 1 放到它但暂停 / 2 正在放

    func paint() {
        backgroundColor = LXRadioInk.card
        titleL.font = LXRadioInk.font(16, true)
        titleL.textColor = LXRadioInk.text
        metaL.font = LXRadioInk.font(12.5)
        metaL.textColor = LXRadioInk.soft
        shownState = -1
        refreshState()
    }

    /// 播放走一格就问一次(每秒 10 次),状态真变了才换圈和图标
    func refreshState() {
        let a = LXRadioAudio.shared
        let st = a.item?.id != item.id ? 0 : a.playing ? 2 : 1
        guard st != shownState else { return }
        shownState = st
        ring.backgroundColor = st > 0 ? LXRadioInk.star : LXRadioInk.line
        icon.image = LXRadioInk.sym(st == 2 ? "waveform" : "play.fill", st == 2 ? 16 : 14, .semibold)
        icon.tintColor = st > 0 ? LXRadioInk.onStar : LXRadioInk.text
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.7 : 1 } }

    override func contextMenuInteraction(_ i: UIContextMenuInteraction, configurationForMenuAtLocation p: CGPoint) -> UIContextMenuConfiguration? {
        guard let m = onMenu?(item) else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in m }
    }
}

// MARK: - 列表页

final class LXRadioVC: UIViewController {
    static let shared = LXRadioVC()
    static let cacheKey = "lx.radio.cache"

    static func open() {
        let vc = shared
        guard vc.presentingViewController == nil, let top = DrawerPlugin.topVC() else { return }
        vc.modalPresentationStyle = .fullScreen
        top.present(vc, animated: true)
    }

    /// 实时流每来一条都过一下这里
    static func feed(_ obj: [String: Any]) {
        guard !LustreConfig.isPreview, let type = obj["type"] as? String, type.hasPrefix("radio_") else { return }
        DispatchQueue.main.async { shared.apply(type, obj) }
    }

    private let topBar = UIView()
    private let titleL = UILabel()
    private let closeBtn = UIButton(type: .custom)
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let nowCard = UIControl()
    private let nowTitle = UILabel()
    private let nowMeta = UILabel()
    private let nowBar = UIView()
    private let nowFill = UIView()
    private var nowFillW: NSLayoutConstraint!
    private let nowBtn = UIButton(type: .custom)
    private let emptyL = UILabel()
    private(set) var items: [LXRadioItem] = []
    private var rows: [Int: LXRadioRow] = [:]

    override var preferredStatusBarStyle: UIStatusBarStyle { RPSpec.moonState == "day" ? .darkContent : .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleL.text = "Radio"
        titleL.textAlignment = .center
        closeBtn.layer.cornerRadius = 18
        closeBtn.layer.borderWidth = 1
        closeBtn.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        for v in [titleL, closeBtn] { v.translatesAutoresizingMaskIntoConstraints = false; topBar.addSubview(v) }
        topBar.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        view.addSubview(topBar)
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // 正在放的那张卡:标题、细进度条、播放/暂停;点卡进播放页
        nowCard.layer.cornerRadius = 16
        nowCard.isHidden = true
        nowTitle.numberOfLines = 1
        for v in [nowTitle, nowMeta, nowBar, nowBtn] as [UIView] { v.translatesAutoresizingMaskIntoConstraints = false; nowCard.addSubview(v) }
        nowTitle.isUserInteractionEnabled = false
        nowMeta.isUserInteractionEnabled = false
        nowBar.isUserInteractionEnabled = false
        nowBar.layer.cornerRadius = 1.5
        nowBar.clipsToBounds = true
        nowFill.translatesAutoresizingMaskIntoConstraints = false
        nowBar.addSubview(nowFill)
        nowFillW = nowFill.widthAnchor.constraint(equalToConstant: 0)
        nowBtn.layer.cornerRadius = 20
        nowBtn.addAction(UIAction { _ in LXRadioAudio.shared.toggle() }, for: .touchUpInside)
        nowCard.addAction(UIAction { [weak self] _ in self?.openPlayer() }, for: .touchUpInside)
        NSLayoutConstraint.activate([
            nowTitle.leadingAnchor.constraint(equalTo: nowCard.leadingAnchor, constant: 16),
            nowTitle.trailingAnchor.constraint(equalTo: nowBtn.leadingAnchor, constant: -12),
            nowTitle.topAnchor.constraint(equalTo: nowCard.topAnchor, constant: 14),
            nowMeta.leadingAnchor.constraint(equalTo: nowTitle.leadingAnchor),
            nowMeta.trailingAnchor.constraint(equalTo: nowTitle.trailingAnchor),
            nowMeta.topAnchor.constraint(equalTo: nowTitle.bottomAnchor, constant: 2),
            nowBar.leadingAnchor.constraint(equalTo: nowTitle.leadingAnchor),
            nowBar.trailingAnchor.constraint(equalTo: nowCard.trailingAnchor, constant: -16),
            nowBar.topAnchor.constraint(equalTo: nowMeta.bottomAnchor, constant: 10),
            nowBar.heightAnchor.constraint(equalToConstant: 3),
            nowBar.bottomAnchor.constraint(equalTo: nowCard.bottomAnchor, constant: -14),
            nowFill.leadingAnchor.constraint(equalTo: nowBar.leadingAnchor),
            nowFill.topAnchor.constraint(equalTo: nowBar.topAnchor),
            nowFill.bottomAnchor.constraint(equalTo: nowBar.bottomAnchor),
            nowFillW,
            nowBtn.trailingAnchor.constraint(equalTo: nowCard.trailingAnchor, constant: -14),
            nowBtn.centerYAnchor.constraint(equalTo: nowTitle.bottomAnchor, constant: 1),
            nowBtn.widthAnchor.constraint(equalToConstant: 40), nowBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
        stack.addArrangedSubview(nowCard)
        stack.setCustomSpacing(18, after: nowCard)

        emptyL.numberOfLines = 0
        emptyL.textAlignment = .center
        emptyL.text = "Nothing on the radio yet.\nHis shows, and the voice notes you keep\nfrom the chat, will show up here."
        let emptyH = emptyL.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        emptyH.priority = UILayoutPriority(999)
        emptyH.isActive = true
        emptyL.isHidden = true
        stack.addArrangedSubview(emptyL)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            titleL.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleL.centerYAnchor.constraint(equalTo: closeBtn.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            closeBtn.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -8),
            closeBtn.widthAnchor.constraint(equalToConstant: 36), closeBtn.heightAnchor.constraint(equalToConstant: 36),
            scroll.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -40),
        ])

        LXRadioAudio.shared.listen(self) { [weak self] in self?.tick() }
        loadCache()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        paint()
        if !LustreConfig.isPreview { load() }   // 先摆缓存,背后拉新的
    }

    private func paint() {
        overrideUserInterfaceStyle = RPSpec.windowStyle
        view.backgroundColor = LXRadioInk.bg
        topBar.backgroundColor = LXRadioInk.bg
        titleL.font = LXRadioInk.font(17, true)
        titleL.textColor = LXRadioInk.text
        closeBtn.backgroundColor = LXRadioInk.card
        closeBtn.layer.borderColor = LXRadioInk.line.cgColor
        closeBtn.setImage(LXRadioInk.sym("xmark", 15), for: .normal)
        closeBtn.tintColor = LXRadioInk.soft
        nowCard.backgroundColor = LXRadioInk.card
        nowCard.layer.borderWidth = 1
        nowCard.layer.borderColor = LXRadioInk.star.withAlphaComponent(0.55).cgColor
        nowTitle.font = LXRadioInk.font(15.5, true)
        nowTitle.textColor = LXRadioInk.text
        nowMeta.font = LXRadioInk.font(12)
        nowMeta.textColor = LXRadioInk.soft
        nowBar.backgroundColor = LXRadioInk.line
        nowFill.backgroundColor = LXRadioInk.star
        nowBtn.backgroundColor = LXRadioInk.star
        nowBtn.tintColor = LXRadioInk.onStar
        emptyL.font = LXRadioInk.font(13.5)
        emptyL.textColor = LXRadioInk.faint
        rows.values.forEach { $0.paint() }
        tick(force: true)
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: 数据

    private func loadCache() {
        if let d = UserDefaults.standard.data(forKey: Self.cacheKey),
           let a = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] {
            items = a.compactMap(LXRadioItem.init)
        }
        rebuild()
    }

    private func saveCache() {
        guard !LustreConfig.isPreview else { return }
        if let d = try? JSONSerialization.data(withJSONObject: items.map { $0.dict }) { UserDefaults.standard.set(d, forKey: Self.cacheKey) }
    }

    func load() {
        LXRadioNet.call("GET", "/app/radio") { [weak self] o, _ in
            guard let s = self, let o else { return }   // 拉不下来就留着缓存那份
            s.items = ((o["items"] as? [[String: Any]]) ?? []).compactMap(LXRadioItem.init)
            s.rebuild()
            s.saveCache()
        }
    }

    /// 按 items 摆:已有的原地换内容,新的插进去,没了的拿掉
    private func rebuild() {
        let ids = Set(items.map { $0.id })
        for (id, r) in rows where !ids.contains(id) { r.removeFromSuperview(); rows[id] = nil }
        for (i, it) in items.enumerated() {
            let r: LXRadioRow
            if let old = rows[it.id] { r = old; r.set(it) } else {
                r = LXRadioRow(it)
                r.onTap = { [weak self] it in self?.tapped(it) }
                r.onMenu = { [weak self] it in self?.menu(for: it) }
                rows[it.id] = r
            }
            let at = i + 1   // 0 是正在放的卡
            if stack.arrangedSubviews.firstIndex(of: r) != at {
                r.removeFromSuperview()
                stack.insertArrangedSubview(r, at: at)
            }
        }
        emptyL.isHidden = !items.isEmpty
        LXRadioAudio.shared.refresh(items)
        tick()
    }

    private func apply(_ type: String, _ o: [String: Any]) {
        guard isViewLoaded else { return }
        switch type {
        case "radio_new", "radio_update":
            guard let d = o["item"] as? [String: Any], let it = LXRadioItem(d) else { return }
            if let i = items.firstIndex(where: { $0.id == it.id }) { items[i] = it } else { items.insert(it, at: 0) }
        case "radio_del":
            guard let id = (o["id"] as? NSNumber)?.intValue else { return }
            items.removeAll { $0.id == id }
        default:
            return
        }
        rebuild()
        saveCache()
        LXRadioPlayerVC.live?.itemChanged()
    }

    // MARK: 动作

    private func tapped(_ it: LXRadioItem) {
        LXRadioAudio.shared.play(it, queue: items)
        openPlayer()
    }

    func openPlayer() {
        guard LXRadioAudio.shared.item != nil, presentedViewController == nil else { return }
        let vc = LXRadioPlayerVC()
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func menu(for it: LXRadioItem) -> UIMenu? {
        guard !LustreConfig.isPreview else { return nil }
        let rename = UIAction(title: "Rename", image: LXRadioInk.sym("pencil", 15)) { [weak self] _ in self?.askRename(it) }
        let remove = UIAction(title: "Remove from Radio", image: LXRadioInk.sym("trash", 15), attributes: .destructive) { [weak self] _ in
            self?.remove(it)
        }
        return UIMenu(title: "", children: [rename, remove])
    }

    private func askRename(_ it: LXRadioItem) {
        let a = UIAlertController(title: "Rename", message: nil, preferredStyle: .alert)
        a.addTextField { $0.text = it.title; $0.clearButtonMode = .whileEditing }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak a] _ in
            let t = (a?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, t != it.title else { return }
            LXRadioNet.call("POST", "/app/radio/rename", ["id": it.id, "title": t]) { o, _ in
                guard let s = self else { return }
                if let o, let n = LXRadioItem(o), let i = s.items.firstIndex(where: { $0.id == n.id }) {
                    s.items[i] = n; s.rebuild(); s.saveCache()
                } else if o == nil { LXToast.show("没改成，再试一次", host: s.view) }
            }
        })
        present(a, animated: true)
    }

    private func remove(_ it: LXRadioItem) {
        guard let i = items.firstIndex(where: { $0.id == it.id }) else { return }
        items.remove(at: i)
        rebuild()
        LXRadioNet.call("POST", "/app/radio/delete", ["id": it.id]) { [weak self] o, code in
            guard let s = self else { return }
            if o != nil || code == 404 { s.saveCache(); return }
            s.items.insert(it, at: min(i, s.items.count))   // 没拿掉:放回原处
            s.rebuild()
            LXToast.show("没拿掉，再试一次", host: s.view)
        }
    }

    /// 播放走一格:正在放的卡和每一行的图标跟着变。页面关着就不动(再打开时 paint 会补一次)
    private func tick(force: Bool = false) {
        guard isViewLoaded, force || view.window != nil else { return }
        let a = LXRadioAudio.shared
        if let it = a.item {
            nowCard.isHidden = false
            nowTitle.text = it.title.isEmpty ? "Untitled" : it.title
            nowMeta.text = (a.playing ? "Playing" : "Paused") + " · " + LXRadioAudio.clock(a.elapsed) + " / " + LXRadioAudio.clock(a.length)
            updateFill()
            if nowBtnPlaying != a.playing {
                nowBtnPlaying = a.playing
                nowBtn.setImage(LXRadioInk.sym(a.playing ? "pause.fill" : "play.fill", 16, .semibold), for: .normal)
            }
        } else {
            nowCard.isHidden = true
        }
        rows.values.forEach { $0.refreshState() }
    }
    private var nowBtnPlaying: Bool?

    private func updateFill() {
        let a = LXRadioAudio.shared
        let w = max(0, nowBar.bounds.width * CGFloat(a.length > 0 ? min(1, a.elapsed / a.length) : 0))
        if abs(nowFillW.constant - w) > 0.5 { nowFillW.constant = w }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFill()   // 第一次出来时条还没宽度,量好了再补
    }

    // MARK: 预览
    func previewSeed(_ list: [LXRadioItem]) { items = list; rebuild() }
    func previewRepaint() { paint() }
}

// MARK: - 播放页:文字一句一句亮

final class LXRadioPlayerVC: UIViewController, UIScrollViewDelegate {
    static weak var live: LXRadioPlayerVC?

    /// 聊天里那条电台播放条点中间:从最上面那页弹出来,关了回到原处
    static func open() {
        guard LXRadioAudio.shared.item != nil, live?.presentingViewController == nil,
              let top = DrawerPlugin.topVC() else { return }
        let vc = LXRadioPlayerVC()
        vc.modalPresentationStyle = .fullScreen
        top.present(vc, animated: true)
    }

    private let downBtn = UIButton(type: .custom)
    private let titleL = UILabel()
    private let metaL = UILabel()
    private let lyricsBox = UIView()          // 渐隐挂在它上面(挂在滚动视图上会跟着内容跑)
    private let lyrics = UIScrollView()
    private let lyricStack = UIStackView()
    private let fade = CAGradientLayer()
    private let noteL = UILabel()
    private let slider = UISlider()
    private let elapsedL = UILabel()
    private let remainL = UILabel()
    private let playBtn = UIButton(type: .custom)
    private let prevBtn = UIButton(type: .custom)
    private let nextBtn = UIButton(type: .custom)
    private let backBtn = UIButton(type: .custom)
    private let fwdBtn = UIButton(type: .custom)
    private var lineViews: [UILabel] = []
    private var shownId = -1
    private var shownCount = -1
    private var currentLine = -1
    private var dragging = false
    private var userScrolledAt = Date.distantPast

    override var preferredStatusBarStyle: UIStatusBarStyle { RPSpec.moonState == "day" ? .darkContent : .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        Self.live = self
        downBtn.setImage(LXRadioInk.sym("chevron.down", 18, .semibold), for: .normal)
        downBtn.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)
        titleL.numberOfLines = 3
        lyrics.delegate = self
        lyrics.showsVerticalScrollIndicator = false
        lyrics.alwaysBounceVertical = true
        lyricStack.axis = .vertical
        lyricStack.spacing = 18
        lyricStack.translatesAutoresizingMaskIntoConstraints = false
        lyrics.addSubview(lyricStack)
        noteL.numberOfLines = 0
        noteL.isHidden = true

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.setThumbImage(Self.dot(12), for: .normal)
        slider.setThumbImage(Self.dot(18), for: .highlighted)
        slider.addAction(UIAction { [weak self] _ in self?.dragging = true }, for: .touchDown)   // 手指一按下走表就别动它
        slider.addAction(UIAction { [weak self] _ in self?.dragging = true; self?.sliderMoved() }, for: .valueChanged)
        slider.addAction(UIAction { [weak self] _ in self?.sliderDone() }, for: [.touchUpInside, .touchUpOutside, .touchCancel])

        for (b, name, size) in [(backBtn, "gobackward.15", CGFloat(22)), (prevBtn, "backward.end.fill", CGFloat(20)),
                                (nextBtn, "forward.end.fill", CGFloat(20)), (fwdBtn, "goforward.15", CGFloat(22))] {
            b.setImage(LXRadioInk.sym(name, size), for: .normal)
        }
        playBtn.layer.cornerRadius = 34
        backBtn.addAction(UIAction { _ in LXRadioAudio.shared.skip(-15) }, for: .touchUpInside)
        fwdBtn.addAction(UIAction { _ in LXRadioAudio.shared.skip(15) }, for: .touchUpInside)
        prevBtn.addAction(UIAction { _ in LXRadioAudio.shared.prev() }, for: .touchUpInside)
        nextBtn.addAction(UIAction { _ in LXRadioAudio.shared.next() }, for: .touchUpInside)
        playBtn.addAction(UIAction { _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            LXRadioAudio.shared.toggle()
        }, for: .touchUpInside)

        let controls = UIStackView(arrangedSubviews: [backBtn, prevBtn, playBtn, nextBtn, fwdBtn])
        controls.axis = .horizontal
        controls.alignment = .center
        controls.distribution = .equalCentering
        for v in [downBtn, titleL, metaL, lyricsBox, noteL, slider, elapsedL, remainL, controls] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        lyrics.translatesAutoresizingMaskIntoConstraints = false
        lyricsBox.addSubview(lyrics)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            downBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            downBtn.topAnchor.constraint(equalTo: g.topAnchor, constant: 6),
            downBtn.widthAnchor.constraint(equalToConstant: 44), downBtn.heightAnchor.constraint(equalToConstant: 44),
            titleL.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            titleL.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            titleL.topAnchor.constraint(equalTo: downBtn.bottomAnchor, constant: 10),
            metaL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            metaL.trailingAnchor.constraint(equalTo: titleL.trailingAnchor),
            metaL.topAnchor.constraint(equalTo: titleL.bottomAnchor, constant: 5),
            lyricsBox.topAnchor.constraint(equalTo: metaL.bottomAnchor, constant: 14),
            lyricsBox.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lyricsBox.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lyricsBox.bottomAnchor.constraint(equalTo: slider.topAnchor, constant: -14),
            lyrics.topAnchor.constraint(equalTo: lyricsBox.topAnchor),
            lyrics.bottomAnchor.constraint(equalTo: lyricsBox.bottomAnchor),
            lyrics.leadingAnchor.constraint(equalTo: lyricsBox.leadingAnchor),
            lyrics.trailingAnchor.constraint(equalTo: lyricsBox.trailingAnchor),
            lyricStack.topAnchor.constraint(equalTo: lyrics.contentLayoutGuide.topAnchor, constant: 26),
            lyricStack.leadingAnchor.constraint(equalTo: lyrics.frameLayoutGuide.leadingAnchor, constant: 26),
            lyricStack.trailingAnchor.constraint(equalTo: lyrics.frameLayoutGuide.trailingAnchor, constant: -26),
            lyricStack.bottomAnchor.constraint(equalTo: lyrics.contentLayoutGuide.bottomAnchor, constant: -160),
            noteL.leadingAnchor.constraint(equalTo: titleL.leadingAnchor),
            noteL.trailingAnchor.constraint(equalTo: titleL.trailingAnchor),
            noteL.topAnchor.constraint(equalTo: lyricsBox.topAnchor, constant: 26),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            elapsedL.leadingAnchor.constraint(equalTo: slider.leadingAnchor),
            elapsedL.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            remainL.trailingAnchor.constraint(equalTo: slider.trailingAnchor),
            remainL.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 2),
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 34),
            controls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -34),
            controls.topAnchor.constraint(equalTo: elapsedL.bottomAnchor, constant: 14),
            controls.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -22),
            playBtn.widthAnchor.constraint(equalToConstant: 68), playBtn.heightAnchor.constraint(equalToConstant: 68),
        ])
        for b in [backBtn, prevBtn, nextBtn, fwdBtn] {
            b.widthAnchor.constraint(equalToConstant: 44).isActive = true
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        // 文字区上下各一段渐隐
        fade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        fade.locations = [0, 0.07, 0.86, 1]
        lyricsBox.layer.mask = fade

        LXRadioAudio.shared.listen(self) { [weak self] in self?.tick() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        paint()
        itemChanged()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        currentLine = -1   // 文字区这时才有高度:滚到正在念的那句
        tick()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        fade.frame = lyricsBox.bounds
        CATransaction.commit()
    }

    func paint() {
        overrideUserInterfaceStyle = RPSpec.windowStyle
        view.backgroundColor = LXRadioInk.bg
        downBtn.tintColor = LXRadioInk.soft
        titleL.font = LXRadioInk.font(22, true)
        titleL.textColor = LXRadioInk.text
        metaL.font = LXRadioInk.font(13)
        metaL.textColor = LXRadioInk.soft
        noteL.font = LXRadioInk.font(14)
        noteL.textColor = LXRadioInk.faint
        slider.minimumTrackTintColor = LXRadioInk.star
        slider.maximumTrackTintColor = LXRadioInk.line
        slider.tintColor = LXRadioInk.text
        for l in [elapsedL, remainL] { l.font = UIFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium); l.textColor = LXRadioInk.soft }
        for b in [backBtn, prevBtn, nextBtn, fwdBtn] { b.tintColor = LXRadioInk.text }
        playBtn.backgroundColor = LXRadioInk.star
        playBtn.tintColor = LXRadioInk.onStar
        slider.setThumbImage(Self.dot(12, LXRadioInk.text), for: .normal)
        slider.setThumbImage(Self.dot(18, LXRadioInk.text), for: .highlighted)
        lineViews.forEach { $0.textColor = LXRadioInk.text }
        currentLine = -1
        tick()
        setNeedsStatusBarAppearanceUpdate()
    }

    private static func dot(_ d: CGFloat, _ c: UIColor = .white) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: d, height: d)).image { _ in
            c.setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: d, height: d)).fill()
        }
    }

    /// 换了一条 / 这一条的文字或时间更新了:重摆文字
    func itemChanged() {
        guard isViewLoaded, let it = LXRadioAudio.shared.item else { return }
        titleL.text = it.title.isEmpty ? "Untitled" : it.title
        metaL.text = it.meta
        let lines = it.lines
        noteL.isHidden = !lines.isEmpty
        if lines.isEmpty {
            noteL.text = it.status == "aligning" ? "Listening to it and writing the words down…" : "No words for this one."
        }
        let timed = !it.cues.isEmpty
        guard it.id != shownId || lines.count != shownCount || lineViews.map({ $0.text ?? "" }) != lines.map({ $0.s }) else {
            for (i, l) in lineViews.enumerated() { l.alpha = !timed || i == currentLine ? 1 : 0.3 }
            return
        }
        shownId = it.id
        shownCount = lines.count
        lineViews.forEach { $0.removeFromSuperview() }
        lineViews = lines.enumerated().map { i, c in
            let l = UILabel()
            l.numberOfLines = 0
            let f = LXRadioInk.font(21, true)
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 5
            l.attributedText = NSAttributedString(string: c.s, attributes: [.font: f, .paragraphStyle: p])
            l.textColor = LXRadioInk.text
            l.alpha = timed ? 0.3 : 1   // 还没量出时间:整篇照常亮着读
            l.tag = i
            l.isUserInteractionEnabled = true
            l.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(lineTapped(_:))))
            lyricStack.addArrangedSubview(l)
            return l
        }
        currentLine = -1
        lyrics.setContentOffset(.zero, animated: false)
        tick()
    }

    @objc private func lineTapped(_ g: UITapGestureRecognizer) {
        guard let i = g.view?.tag, let it = LXRadioAudio.shared.item, i < it.cues.count else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        userScrolledAt = .distantPast
        LXRadioAudio.shared.seek(to: it.cues[i].t)
        if !LXRadioAudio.shared.playing { LXRadioAudio.shared.resume() }
    }

    private func sliderMoved() {
        let a = LXRadioAudio.shared
        let t = Double(slider.value) * a.length
        elapsedL.text = LXRadioAudio.clock(t)
        remainL.text = "-" + LXRadioAudio.clock(max(0, a.length - t))
    }

    private func sliderDone() {
        let a = LXRadioAudio.shared
        a.seek(to: Double(slider.value) * a.length)
        dragging = false
        userScrolledAt = .distantPast
    }

    func scrollViewWillBeginDragging(_ s: UIScrollView) { userScrolledAt = Date() }

    private func tick() {
        guard isViewLoaded else { return }
        let a = LXRadioAudio.shared
        guard let it = a.item else { dismissIfShowing(); return }
        if it.id != shownId { itemChanged(); return }
        if playBtnPlaying != a.playing {
            playBtnPlaying = a.playing
            playBtn.setImage(LXRadioInk.sym(a.playing ? "pause.fill" : "play.fill", 26, .semibold), for: .normal)
        }
        let hasMore = a.queue.firstIndex(where: { $0.id == it.id }).map { $0 + 1 < a.queue.count } ?? false
        nextBtn.isEnabled = hasMore
        nextBtn.alpha = hasMore ? 1 : 0.35
        if !dragging {
            slider.value = a.length > 0 ? Float(min(1, a.elapsed / a.length)) : 0
            elapsedL.text = LXRadioAudio.clock(a.elapsed)
            remainL.text = "-" + LXRadioAudio.clock(max(0, a.length - a.elapsed))
        }
        // 现在念到哪一句
        var cur = -1
        for (i, c) in it.cues.enumerated() where c.t >= 0 && c.t <= a.elapsed + 0.15 { cur = i }
        guard cur != currentLine else { return }
        let old = currentLine
        currentLine = cur
        UIView.animate(withDuration: 0.28) {
            if old >= 0, old < self.lineViews.count { self.lineViews[old].alpha = 0.3 }
            if cur >= 0, cur < self.lineViews.count { self.lineViews[cur].alpha = 1 }
        }
        // 她刚自己翻过文字:4 秒内不抢着滚
        guard cur >= 0, cur < lineViews.count, Date().timeIntervalSince(userScrolledAt) > 4 else { return }
        lyrics.layoutIfNeeded()
        let l = lineViews[cur]
        let y = lyricStack.frame.minY + l.frame.minY - lyrics.bounds.height * 0.3
        let maxY = max(0, lyrics.contentSize.height - lyrics.bounds.height)
        lyrics.setContentOffset(CGPoint(x: 0, y: min(maxY, max(0, y))), animated: true)
    }

    private var playBtnPlaying: Bool?

    private func dismissIfShowing() {
        if presentingViewController != nil, !isBeingDismissed { dismiss(animated: true) }
    }

    deinit { LXRadioAudio.shared.unlisten(self) }
}

// MARK: - 预览路线 radio:假节目(不连服务器、没有声音),五步

enum LXRadioPreview {
    static func start(tries: Int = 0) {
        guard LustreConfig.isPreview, LustreConfig.previewFocus == "radio" else { return }
        guard let top = DrawerPlugin.topVC(), top.view.window != nil else {
            if tries < 40 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { start(tries: tries + 1) } }
            return
        }
        func iso(_ hAgo: Double) -> String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f.string(from: Date().addingTimeInterval(-hAgo * 3600))
        }
        let script = ["Sample line one · the morning is quiet.", "Sample line two · a little rain on the window.",
                      "Sample line three · this one is a bit longer so it wraps onto a second line on a phone.",
                      "Sample line four.", "Sample line five · halfway there.", "Sample line six.",
                      "Sample line seven · nearly done.", "Sample line eight · the end."]
        let cues: [[String: Any]] = script.enumerated().map { ["t": Double($0.offset) * 4.0, "s": $0.element] }
        let list = [
            LXRadioItem(["id": 3, "title": "Sample show · Morning", "source": "show", "file": "pv-a.mp3", "duration": 34,
                         "text": script.joined(separator: "\n"), "cues": cues, "status": "ready", "ts": iso(2)]),
            LXRadioItem(["id": 2, "title": "Sample voice note", "source": "voice", "file": "pv-b.mp3", "duration": 131,
                         "text": "Sample voice note text.", "cues": [["t": 0.0, "s": "Sample voice note text."]], "status": "ready", "ts": iso(30)]),
            LXRadioItem(["id": 1, "title": "Sample show · a longer title that needs two lines in the list", "source": "show",
                         "file": "pv-c.mp3", "duration": 305, "text": "", "cues": [], "status": "ready", "ts": iso(80)]),
        ].compactMap { $0 }

        LXRadioVC.open()
        let vc = LXRadioVC.shared
        vc.loadViewIfNeeded()
        vc.previewSeed(list)
        let mark = UIView(frame: LXBubbleSampler.beacon)
        mark.backgroundColor = UIColor(red: 1, green: 0, blue: 1, alpha: 1)
        let phase = UIView(frame: CGRect(x: 28, y: 70, width: 20, height: 20))
        // 第一步一开页就亮着(截图开始得晚),往后 40 秒起每 12 秒一步
        let steps: [(UIColor, () -> Void)] = [
            (.yellow, { }),                                                                     // 列表
            (.cyan, { LXRadioAudio.shared.play(list[0], queue: list) ; vc.openPlayer() }),      // 播放页,第一句亮
            (.red, { LXRadioAudio.shared.seek(to: 13) }),                                        // 跳到第四句
            (.orange, { ChatListPlugin.live?.switchMoon("day"); LXRadioPlayerVC.live?.paint() }), // 白天
            (UIColor(red: 0.5, green: 0, blue: 1, alpha: 1), {                                 // 回列表:正在放的卡
                LXRadioPlayerVC.live?.dismiss(animated: false)
                vc.previewRepaint()
            }),
            (.green, {                                     // 关掉电台页回聊天:输入框上面那条电台播放条(这条路线聊天里不画消息)
                LXRadioAudio.shared.seek(to: 10)
                LXRadioAudio.shared.resume()
                vc.dismiss(animated: false)
            }),
        ]
        for (i, st) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (i == 0 ? 0.5 : 40 + Double(i - 1) * 12)) {
                st.1()
                phase.backgroundColor = st.0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    let host: UIView = (LXRadioPlayerVC.live?.presentingViewController != nil ? LXRadioPlayerVC.live?.view : nil)
                        ?? (vc.presentingViewController != nil ? vc.view : nil)
                        ?? NativeInputPlugin.live?.bridge?.viewController?.view ?? vc.view
                    for v in [mark, phase] { if v.superview !== host { host.addSubview(v) }; host.bringSubviewToFront(v) }
                }
            }
        }
    }
}
