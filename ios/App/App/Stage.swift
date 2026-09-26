import UIKit

enum LXStage {
    static func rank(_ v: UIView, homeUp: Bool) -> Int {
        let cls = String(describing: type(of: v))
        if cls.hasPrefix("WK") { return 0 }
        if v is LXDrawerView { return homeUp ? 25 : 10 }
        if v is LXChatContainer { return 20 }
        if v.tag == 7719 { return 29 }
        if v is HomeView { return 30 }
        if let card = NativeInputPlugin.live?.card, card === v { return 40 }
        if v is LXVoiceDock || v is LXCallPill { return 45 }
        if v is RPanelView { return 50 }
        if v is LXSysSheetView { return 60 }
        if v is LXEmojiPicker { return 70 }
        return 80
    }

    static func settle(_ host: UIView?) {
        guard let host = host else { return }
        let subs = host.subviews
        guard subs.count > 2 else { return }
        let homeUp = subs.contains { ($0 is HomeView) && !$0.isHidden }
        let ranked = subs.enumerated().map { (i, v) in (v: v, r: rank(v, homeUp: homeUp), i: i) }
        let sorted = ranked.sorted { a, b in a.r != b.r ? a.r < b.r : a.i < b.i }
        if sorted.map({ $0.v }) == subs { return }
        for e in sorted { host.bringSubviewToFront(e.v) }
    }
}
