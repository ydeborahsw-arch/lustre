import UIKit
import AVFoundation

/// 输入框上面那条玻璃播放条。两种:聊天里的语音(LXVoiceBar),电台(LXRadioAudio,1005 她选 A:电台在放就一直挂在这)。
/// 语音优先:点了语音电台先让位,语音完了电台那条回来(暂停着,点一下接着放)。
final class LXVoiceDock: UIView {
    static var shared: LXVoiceDock?
    private enum Mode { case voice, radio }
    private var mode = Mode.voice
    private var iconPaused: Bool?
    static let rates: [Float] = [1, 1.5, 2]
    static var rateIdx = 0
    static var currentRate: Float { rates[rateIdx] }

    private let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let film = UIView()
    private let playB = UIButton(type: .custom)
    private let titleL = UILabel()
    private let subL = UILabel()
    private let rateB = UIButton(type: .custom)
    private let dash = CAShapeLayer()
    private let closeB = UIButton(type: .custom)
    private let track = UIView()
    private let fill = UIView()
    private var fillW: NSLayoutConstraint!
    private var bottomC: NSLayoutConstraint?
    private weak var anchoredTo: UIView?
    private var timeObs: Any?
    private weak var observedPlayer: AVPlayer?
    private var scrubbing = false
    private var glassDark: Bool?

    private init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 25
        layer.cornerCurve = .continuous
        clipsToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 1, alpha: 0.14).cgColor
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        film.translatesAutoresizingMaskIntoConstraints = false
        film.backgroundColor = UIColor(white: 0, alpha: 0.28)
        addSubview(film)
        playB.translatesAutoresizingMaskIntoConstraints = false
        playB.tintColor = .white
        playB.addTarget(self, action: #selector(playTap), for: .touchUpInside)
        addSubview(playB)
        titleL.translatesAutoresizingMaskIntoConstraints = false
        titleL.font = LXDrawerTint.font(15, wght: 500)
        titleL.textColor = .white
        titleL.textAlignment = .center
        subL.translatesAutoresizingMaskIntoConstraints = false
        subL.font = LXDrawerTint.font(12)
        subL.textColor = UIColor(white: 1, alpha: 0.62)
        subL.textAlignment = .center
        subL.text = "Voice message"
        let col = UIStackView(arrangedSubviews: [titleL, subL])
        col.translatesAutoresizingMaskIntoConstraints = false
        col.axis = .vertical
        col.spacing = 1
        col.isUserInteractionEnabled = false
        addSubview(col)
        rateB.translatesAutoresizingMaskIntoConstraints = false
        rateB.titleLabel?.font = LXDrawerTint.font(13, wght: 600)
        rateB.setTitleColor(UIColor(white: 1, alpha: 0.9), for: .normal)
        rateB.addTarget(self, action: #selector(rateTap), for: .touchUpInside)
        dash.fillColor = nil
        dash.strokeColor = UIColor(white: 1, alpha: 0.7).cgColor
        dash.lineWidth = 1.2
        dash.lineDashPattern = [3, 3]
        rateB.layer.addSublayer(dash)
        addSubview(rateB)
        closeB.translatesAutoresizingMaskIntoConstraints = false
        closeB.tintColor = .white
        closeB.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)), for: .normal)
        closeB.addTarget(self, action: #selector(closeTap), for: .touchUpInside)
        addSubview(closeB)
        track.translatesAutoresizingMaskIntoConstraints = false
        track.backgroundColor = UIColor(white: 1, alpha: 0.22)
        track.layer.cornerRadius = 1
        track.isUserInteractionEnabled = false
        addSubview(track)
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.backgroundColor = UIColor(white: 1, alpha: 0.92)
        fill.layer.cornerRadius = 1
        track.addSubview(fill)
        fillW = fill.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 50),
            blur.topAnchor.constraint(equalTo: topAnchor), blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: leadingAnchor), blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            film.topAnchor.constraint(equalTo: topAnchor), film.bottomAnchor.constraint(equalTo: bottomAnchor),
            film.leadingAnchor.constraint(equalTo: leadingAnchor), film.trailingAnchor.constraint(equalTo: trailingAnchor),
            playB.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            playB.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            playB.widthAnchor.constraint(equalToConstant: 36),
            playB.heightAnchor.constraint(equalToConstant: 36),
            col.centerXAnchor.constraint(equalTo: centerXAnchor),
            col.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            col.leadingAnchor.constraint(greaterThanOrEqualTo: playB.trailingAnchor, constant: 8),
            col.trailingAnchor.constraint(lessThanOrEqualTo: rateB.leadingAnchor, constant: -8),
            closeB.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            closeB.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            closeB.widthAnchor.constraint(equalToConstant: 32),
            closeB.heightAnchor.constraint(equalToConstant: 32),
            rateB.trailingAnchor.constraint(equalTo: closeB.leadingAnchor, constant: -8),
            rateB.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -3),
            rateB.widthAnchor.constraint(equalToConstant: 40),
            rateB.heightAnchor.constraint(equalToConstant: 26),
            track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            track.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            track.heightAnchor.constraint(equalToConstant: 2),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fillW,
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(scrub(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(scrubTap(_:)))
        addGestureRecognizer(tap)
        refreshRateLabel()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        dash.frame = rateB.bounds
        dash.path = UIBezierPath(roundedRect: rateB.bounds.insetBy(dx: 0.6, dy: 0.6), cornerRadius: 6).cgPath
    }

    /// 0930 她:"白天的时候语音显示怎么也是深色玻璃,不应该也跟着主题走吗"——深浅跟紧挨着的输入框一样
    /// (NativeInputPlugin.dockGlassDark)。深玻璃照 0907 原样;浅玻璃换浅材质+白膜,墨用输入框浅玻璃那支,各处透明度照深的抄
    func applyGlass() {
        let dark = NativeInputPlugin.live?.dockGlassDark ?? true
        if glassDark == dark { return }
        glassDark = dark
        let ink: UIColor = dark ? .white : NativeInputPlugin.lightGlassInk
        blur.effect = UIBlurEffect(style: dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
        film.backgroundColor = UIColor(white: dark ? 0 : 1, alpha: 0.28)
        layer.borderColor = UIColor(white: 1, alpha: dark ? 0.14 : 0.5).cgColor
        playB.tintColor = ink
        closeB.tintColor = ink
        titleL.textColor = ink
        subL.textColor = ink.withAlphaComponent(0.62)
        rateB.setTitleColor(ink.withAlphaComponent(0.9), for: .normal)
        dash.strokeColor = ink.withAlphaComponent(0.7).cgColor
        track.backgroundColor = ink.withAlphaComponent(0.22)
        fill.backgroundColor = ink.withAlphaComponent(0.92)
    }


    static func sync() {
        DispatchQueue.main.async {
            let voice = LXVoiceBar.playing != nil && LXVoiceBar.player != nil
            let radio = !voice && LXRadioAudio.shared.item != nil
            guard voice || radio, let host = NativeInputPlugin.live?.bridge?.viewController?.view else {
                shared?.detach(); return
            }
            let d: LXVoiceDock
            if let s = shared, s.superview === host { d = s }
            else { shared?.detach(); d = LXVoiceDock(); host.addSubview(d); shared = d
                   NSLayoutConstraint.activate([
                       d.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12),
                       d.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -12),
                   ]) }
            d.applyGlass()
            if let card = NativeInputPlugin.live?.card { d.transform = card.transform }
            host.bringSubviewToFront(d)
            LXStage.settle(host)
            if voice, let bar = LXVoiceBar.playing, let player = LXVoiceBar.player {
                d.mode = .voice
                LXRadioAudio.shared.unlisten(d)
                d.titleL.text = bar.title.components(separatedBy: " · ").first ?? "Lustre"
                d.subL.text = "Voice message"
                d.rateB.isHidden = false
                d.setPlayIcon(paused: LXVoiceBar.paused)
                d.observe(player)
            } else if let it = LXRadioAudio.shared.item {
                d.mode = .radio
                d.stopObserving()
                d.titleL.text = it.title.isEmpty ? "Untitled" : it.title
                d.subL.text = "Radio"
                d.rateB.isHidden = true   // 电台不调速
                LXRadioAudio.shared.listen(d) { [weak d] in d?.tick() }
            }
            d.reanchor(host: host)
            d.tick()
        }
    }
    private func setPlayIcon(paused: Bool) {
        guard iconPaused != paused else { return }
        iconPaused = paused
        playB.setImage(UIImage(systemName: paused ? "play.fill" : "pause.fill",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
    }
    private func stopObserving() {
        if let p = observedPlayer, let o = timeObs { p.removeTimeObserver(o) }
        timeObs = nil; observedPlayer = nil
    }
    private func detach() {
        stopObserving()
        LXRadioAudio.shared.unlisten(self)
        removeFromSuperview()
        Self.shared = nil
    }
    private func observe(_ p: AVPlayer) {
        if observedPlayer === p { return }
        if let op = observedPlayer, let o = timeObs { op.removeTimeObserver(o) }
        observedPlayer = p
        timeObs = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in
            self?.tick()
        }
    }
    private func reanchor(host: UIView) {
        let card = NativeInputPlugin.live?.card
        let target: UIView? = (card != nil && card?.superview === host && !(card?.isHidden ?? true)) ? card : nil
        if anchoredTo === target, bottomC != nil { return }
        bottomC?.isActive = false
        if let c = target {
            bottomC = bottomAnchor.constraint(equalTo: c.topAnchor, constant: -8)
        } else {
            bottomC = bottomAnchor.constraint(equalTo: host.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        }
        anchoredTo = target
        bottomC?.isActive = true
    }
    private func tick() {
        guard let host = superview else { return }
        reanchor(host: host)
        if mode == .radio {
            let a = LXRadioAudio.shared
            guard a.item != nil else { return }   // 电台停了:sync 会把条收走
            setPlayIcon(paused: !a.playing)
            guard !scrubbing else { return }
            let w = track.bounds.width * CGFloat(a.length > 0 ? min(1, a.elapsed / a.length) : 0)
            if abs(fillW.constant - w) > 0.5 { fillW.constant = w }
            return
        }
        guard !scrubbing, let p = observedPlayer, let item = p.currentItem else { return }
        let d = item.duration.seconds
        guard d.isFinite, d > 0 else { fillW.constant = 0; return }
        let f = max(0, min(1, p.currentTime().seconds / d))
        fillW.constant = track.bounds.width * CGFloat(f)
    }


    @objc private func playTap() {
        if mode == .radio { LXRadioAudio.shared.toggle(); return }
        if LXVoiceBar.paused { LXVoiceBar.resume() } else { LXVoiceBar.pause() }
    }
    @objc private func closeTap() {
        if mode == .radio { LXRadioAudio.shared.stop(); return }
        LXVoiceBar.stopAll()
    }
    @objc private func rateTap() {
        Self.rateIdx = (Self.rateIdx + 1) % Self.rates.count
        refreshRateLabel()
        if !LXVoiceBar.paused { LXVoiceBar.player?.rate = Self.currentRate }
        LXVoiceBar.pushNowPlaying()
    }
    private func refreshRateLabel() {
        let r = Self.currentRate
        rateB.setTitle(r == r.rounded() ? "\(Int(r))X" : String(format: "%.1fX", r), for: .normal)
    }
    private func seek(toX x: CGFloat) {
        if mode == .radio {
            let a = LXRadioAudio.shared
            guard a.length > 0 else { return }
            let f = max(0, min(1, (x - track.frame.minX) / max(1, track.bounds.width)))
            fillW.constant = track.bounds.width * f
            a.seek(to: a.length * Double(f))
            return
        }
        guard let p = observedPlayer, let item = p.currentItem else { return }
        let d = item.duration.seconds
        guard d.isFinite, d > 0 else { return }
        let f = max(0, min(1, (x - track.frame.minX) / max(1, track.bounds.width)))
        fillW.constant = track.bounds.width * f
        p.seek(to: CMTime(seconds: d * Double(f), preferredTimescale: 600)) { _ in LXVoiceBar.pushNowPlaying() }
    }
    @objc private func scrub(_ g: UIPanGestureRecognizer) {
        let pt = g.location(in: self)
        switch g.state {
        case .began: scrubbing = pt.y > bounds.height * 0.55
        case .changed: if scrubbing { seek(toX: pt.x) }
        default: if scrubbing { seek(toX: pt.x) }; scrubbing = false
        }
    }
    @objc private func scrubTap(_ g: UITapGestureRecognizer) {
        let pt = g.location(in: self)
        if pt.y > bounds.height - 22 { seek(toX: pt.x) }
        else if mode == .radio { LXRadioPlayerVC.open() }   // 点节目名:回到文字亮的那页
    }
}
