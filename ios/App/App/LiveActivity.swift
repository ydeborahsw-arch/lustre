import UIKit
import ActivityKit

/// 1001 她要的"正在想"。灵动岛那一条由 relay 用推送推起、更新,App 这边只做四件事:
/// 把"推起令牌"交给 relay;每条推起来的活动把自己的更新令牌交给 relay;
/// 告诉 relay 她在不在 App(切到后台/锁屏 = away,回到前台 = back);她一回到 App 就全收掉(她已经在看了)
enum LXLive {
    private static var started = false

    static func start() {
        guard !started, !LustreConfig.isPreview, !LustreConfig.secret.isEmpty else { return }
        started = true
        // 用场景的 App 不叫 applicationDidBecomeActive,听通知最稳。
        // relay 那边判断"她在不在"只认这两声:App 从来不发 /app/ping,推送那只钟对它不准
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            endAll()
            post(["kind": "back"])
        }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            post(["kind": "away"])
        }
        if #available(iOS 17.2, *) {
            Task {
                for await data in Activity<LXLiveAttributes>.pushToStartTokenUpdates {
                    post(["kind": "start", "token": hex(data)])
                }
            }
        }
        if #available(iOS 16.2, *) {
            for a in Activity<LXLiveAttributes>.activities { watch(a) }
            Task {
                for await a in Activity<LXLiveAttributes>.activityUpdates {
                    // 她正看着 App 的时候推起来的(切回来和推送前后脚撞上):不留
                    if await MainActor.run(body: { UIApplication.shared.applicationState == .active }) {
                        await a.end(nil, dismissalPolicy: .immediate)
                        continue
                    }
                    watch(a)
                }
            }
        }
    }

    @available(iOS 16.2, *)
    private static func watch(_ a: Activity<LXLiveAttributes>) {
        Task {
            for await data in a.pushTokenUpdates {
                post(["kind": "update", "token": hex(data), "activity": a.id, "line": a.attributes.line])
            }
        }
    }

    /// 她回到 App:灵动岛和锁屏上的全收掉(relay 收到 back 也会把这些忘掉)
    static func endAll() {
        guard #available(iOS 16.2, *) else { return }
        for a in Activity<LXLiveAttributes>.activities { Task { await a.end(nil, dismissalPolicy: .immediate) } }
    }

    private static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }

    /// 推起来时 App 多半在后台被叫醒,只有几秒:要一点后台时间,把令牌送到再睡
    private static func post(_ body: [String: Any]) {
        guard let u = URL(string: LustreConfig.apiBase + "/app/la_token") else { return }
        var r = URLRequest(url: u, timeoutInterval: 15)
        r.httpMethod = "POST"
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        DispatchQueue.main.async {
            var bg = UIBackgroundTaskIdentifier.invalid
            let done = {
                if bg != .invalid { UIApplication.shared.endBackgroundTask(bg); bg = .invalid }
            }
            bg = UIApplication.shared.beginBackgroundTask(withName: "lx.live", expirationHandler: done)
            URLSession.shared.dataTask(with: r) { _, _, _ in DispatchQueue.main.async(execute: done) }.resume()
        }
    }
}
