import UIKit
import Capacitor
import WebKit
import BackgroundTasks
import UserNotifications

extension WKWebView {
    func removeInputAccessory() {
        guard let target = scrollView.subviews.first(where: {
            String(describing: type(of: $0)).hasPrefix("WKContent")
        }) else { return }
        let currentClassName = String(describing: type(of: target))
        if currentClassName.hasSuffix("_NoAccessory") { return }
        let noAccessoryName = "\(currentClassName)_NoAccessory"
        if let existing = NSClassFromString(noAccessoryName) {
            object_setClass(target, existing)
            return
        }
        guard let cls = objc_allocateClassPair(object_getClass(target), noAccessoryName, 0) else { return }
        let sel = #selector(getter: UIResponder.inputAccessoryView)
        if let method = class_getInstanceMethod(UIResponder.self, sel) {
            let block: @convention(block) (Any) -> UIView? = { _ in nil }
            class_addMethod(cls, sel, imp_implementationWithBlock(block), method_getTypeEncoding(method))
        }
        objc_registerClassPair(cls)
        object_setClass(target, cls)
    }
}

func lustreKillAccessoryBars() {
    for scene in UIApplication.shared.connectedScenes {
        guard let ws = scene as? UIWindowScene else { continue }
        for window in ws.windows {
            var stack: [UIView] = [window]
            while let v = stack.popLast() {
                if let wv = v as? WKWebView { wv.removeInputAccessory() }
                stack.append(contentsOf: v.subviews)
            }
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
            lustreKillAccessoryBars()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { lustreKillAccessoryBars() }
        BackgroundSync.shared.register()
        BackgroundSync.shared.schedule()
        if !LustreConfig.isPreview {
            HealthWatch.note("launch", HealthWatch.envTag())
            HealthWatch.shared.start()
        }
        // 0926:capacitor.config.json 里关了 ios.handleApplicationNotifications。不关的话 Capacitor 的桥一搭好就把这个位子
        // 换成它自己的通知路由(没装推送插件=点通知什么也不做),下面点通知进对话那段从来没被叫到过
        UNUserNotificationCenter.current().delegate = self
        // 0925 备注:开机拉一次;改了就刷抽屉标题和聊天里的名字
        LXNick.refresh()
        LXUploader.shared.wake()   // 0925:后台上传的会话开机就接上,切出去期间传完的回执能收到
        NotificationCenter.default.addObserver(forName: LXNick.changed, object: nil, queue: .main) { _ in
            LXSessionsAPI.refresh()
            ChatListPlugin.live?.namesChanged()
        }
        if !LustreConfig.isPreview {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                DispatchQueue.main.async { application.registerForRemoteNotifications() }
            }
            LXCallCenter.shared.start()
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        ApnsToken.latest = token
        NotificationCenter.default.post(name: Notification.Name("lx.apnsToken"), object: token)
    }
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }

    func applicationWillResignActive(_ application: UIApplication) {
        LockGate.shared.coverNow()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        LockGate.shared.coverNow()
        BackgroundSync.shared.schedule()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == LXUploader.sessionId else { completionHandler(); return }
        LXUploader.shared.bgDone = completionHandler
        LXUploader.shared.wake()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        LockGate.shared.unlockIfNeeded()
        AppDelegate.clearIconBadge()
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration",
                                          sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    static var pendingPush: [String: Any]?

    static func clearIconBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        let lx = content.userInfo["lx"] as? [String: Any]
        let tapped = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let run: () -> Void = {
            // 0926:点通知只切到那条消息的窗。背来的那份不喂进聊天:它只有前 1500 字、meta 只剩会话,按 id 合并会把
            // 屏幕上/缓存里的全文换成这份残本;消息照常由回前台的补拉带回来
            if tapped { LXPushRoute.open(lx, thread: content.threadIdentifier) }
        }
        if Thread.isMainThread { run() } else { DispatchQueue.main.async(execute: run) }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AppDelegate.clearIconBadge()
        // App 开着时不弹横幅:她一直是这样用的(之前这个位子被 Capacitor 占着,它在前台一律不弹)
        completionHandler([])
    }
}

/// 0926 她的单:点消息通知(横幅/通知中心)直接进那条消息所在的对话,和点抽屉那一行走同一条路。
/// 认窗看 lx.meta.api_session:他的窗 "yan-main",昭的窗 ""(App 里叫 "__legacy__");没背 lx 才看 aps.thread-id("main"=昭)。
enum LXPushRoute {
    private static var pending: String?

    static func target(_ lx: [String: Any]?, thread: String) -> String? {
        let sid: String
        if let meta = lx?["meta"] as? [String: Any] {
            sid = (meta["api_session"] as? String) ?? ""
        } else if !thread.isEmpty {
            sid = thread == "main" ? "" : thread
        } else {
            return nil
        }
        return sid.isEmpty ? "__legacy__" : sid
    }

    static func open(_ lx: [String: Any]?, thread: String) {
        guard let sid = target(lx, thread: thread) else { return }
        // 冷启动聊天页还没搭:记成上次选中,开机直接落在这一窗(不先开错窗再切),背来的消息也进这一窗
        if ChatListPlugin.live?.container == nil {
            UserDefaults.standard.set(sid, forKey: "lx.sessionPick")
        }
        pending = sid
        deliver()
    }

    private static func deliver(_ attempt: Int = 0) {
        guard let sid = pending else { return }
        guard let chat = ChatListPlugin.live, let cont = chat.container else {
            if attempt >= 20 { pending = nil; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { deliver(attempt + 1) }
            return
        }
        pending = nil
        let cur = chat.data.session.isEmpty ? "__legacy__" : chat.data.session
        let host = chat.bridge?.viewController?.view
        let homeUp = host?.subviews.contains(where: { $0 is HomeView && !$0.isHidden }) ?? false
        // 已在这一窗、聊天页也露着:一动不动(不重排、不跳底);被抽屉或 Home 盖着才走一遍切换把它亮出来
        if sid == cur, cont.transform.tx <= 0, !homeUp { return }
        LXDrawer.pick(sid)
    }
}
