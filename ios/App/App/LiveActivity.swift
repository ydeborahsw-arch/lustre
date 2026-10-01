import UIKit
import ActivityKit

/// 1001 她先要了灵动岛"正在想",试过后又定"思考这个直接不放灵动岛了":App 不再把令牌交给 relay(relay 那边也关了),
/// 这里只剩收尾——打开 App、回到前台时,把之前推起来还留在灵动岛和锁屏上的全收掉
enum LXLive {
    private static var started = false

    static func start() {
        guard !started, !LustreConfig.isPreview else { return }
        started = true
        endAll()
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            endAll()
        }
    }

    static func endAll() {
        guard #available(iOS 16.2, *) else { return }
        for a in Activity<LXLiveAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
