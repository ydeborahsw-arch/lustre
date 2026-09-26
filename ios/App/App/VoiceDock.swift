import UIKit
import AVFoundation

final class LXVoiceDock: UIView {
    static var shared: LXVoiceDock?
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


    static func sync() {
        DispatchQueue.main.async {
            guard let bar = LXVoiceBar.playing, let player = LXVoiceBar.player,
                  let host = NativeInputPlugin.live?.bridge?.viewController?.view else {
                shared?.detach(); return
            }
            let d: LXVoiceDock
            if let s = shared, s.superview === host { d = s }
            else { shared?.removeFromSuperview(); d = LXVoiceDock(); host.addSubview(d); shared = d
                   NSLayoutConstraint.activate([
                       d.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 12),
                       d.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -12),
                   ]) }
            if let card = NativeInputPlugin.live?.card { d.transform = card.transform }
            host.bringSubviewToFront(d)
            LXStage.settle(host)
            d.titleL.text = bar.title.components(separatedBy: " · ").first ?? "Lustre"
            d.playB.setImage(UIImage(systemName: LXVoiceBar.paused ? "play.fill" : "pause.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)), for: .normal)
            d.observe(player)
            d.reanchor(host: host)
            d.tick()
        }
    }
    private func detach() {
        if let p = observedPlayer, let o = timeObs { p.removeTimeObserver(o) }
        timeObs = nil; observedPlayer = nil
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
        guard !scrubbing, let p = observedPlayer, let item = p.currentItem else { return }
        let d = item.duration.seconds
        guard d.isFinite, d > 0 else { fillW.constant = 0; return }
        let f = max(0, min(1, p.currentTime().seconds / d))
        fillW.constant = track.bounds.width * CGFloat(f)
    }


    @objc private func playTap() {
        if LXVoiceBar.paused { LXVoiceBar.resume() } else { LXVoiceBar.pause() }
    }
    @objc private func closeTap() { LXVoiceBar.stopAll() }
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
    }
}
