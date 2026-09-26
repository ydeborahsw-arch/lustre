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
        let info = response.notification.request.content.userInfo
        if let lx = info["lx"] as? [String: Any] {
            AppDelegate.pendingPush = lx
            NotificationCenter.default.post(name: Notification.Name("lx.push.message"), object: nil, userInfo: lx)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        AppDelegate.clearIconBadge()
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
