import Foundation
import Capacitor
import UIKit
import WebKit
import Photos
import UserNotifications
import LocalAuthentication
import BackgroundTasks

@objc(ExtraPlugin)
public class ExtraPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ExtraPlugin"
    public let jsName = "Extra"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "haptic", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "saveImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "settings", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setLock", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setBackground", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTextSelect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "saveFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setImeLine", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "imeDiag", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "mirrorNow", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "mirrorStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getApnsToken", returnType: CAPPluginReturnPromise)
    ]

    public override func load() {
        NotificationCenter.default.addObserver(forName: Notification.Name("lx.apnsToken"), object: nil, queue: .main) { [weak self] n in
            if let t = n.object as? String { self?.notifyListeners("apnsToken", data: ["token": t]) }
        }
        DispatchQueue.main.async { [weak self] in
            if !LustreConfig.webless, let wv = self?.bridge?.webView { WebWatchdog.shared.start(wv) }
        }
    }
    @objc func getApnsToken(_ call: CAPPluginCall) {
        call.resolve(["token": ApnsToken.latest ?? ""])
    }

    @objc func mirrorNow(_ call: CAPPluginCall) {
        MirrorSync.shared.run(progress: { [weak self] p in
            self?.notifyListeners("mirror", data: ["state": "progress", "detail": p])
        }, done: { [weak self] ok, summary in
            self?.notifyListeners("mirror", data: ["state": ok ? "done" : "failed", "detail": summary])
        })
        call.resolve(["ok": true])
    }
    @objc func mirrorStatus(_ call: CAPPluginCall) {
        call.resolve(MirrorSync.shared.status())
    }

    @objc func haptic(_ call: CAPPluginCall) {
        let type = call.getString("type") ?? "light"
        DispatchQueue.main.async {
            switch type {
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case "heavy":  UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            case "rigid":  UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            case "soft":   UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            case "select": UISelectionFeedbackGenerator().selectionChanged()
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "warning": UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case "error":   UINotificationFeedbackGenerator().notificationOccurred(.error)
            default:        UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            call.resolve(["ok": true])
        }
    }

    @objc func setTextSelect(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? true
        DispatchQueue.main.async {
            if #available(iOS 14.5, *) {
                self.bridge?.webView?.configuration.preferences.isTextInteractionEnabled = on
                call.resolve(["ok": true, "on": on])
            } else {
                call.resolve(["ok": false, "reason": "needs iOS 14.5+"])
            }
        }
    }

    @objc func saveImage(_ call: CAPPluginCall) {
        guard let b64 = call.getString("data"),
              let data = Data(base64Encoded: b64),
              let img = UIImage(data: data) else {
            call.resolve(["ok": false, "error": "bad image"]); return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                call.resolve(["ok": false, "error": "denied"]); return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }, completionHandler: { ok, err in
                call.resolve(["ok": ok, "error": err?.localizedDescription ?? ""])
            })
        }
    }

    @objc func saveFile(_ call: CAPPluginCall) {
        guard let b64 = call.getString("data"), let data = Data(base64Encoded: b64) else {
            call.resolve(["ok": false, "error": "bad data"]); return
        }
        let name = call.getString("name") ?? "file"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try data.write(to: url) } catch {
            call.resolve(["ok": false, "error": error.localizedDescription]); return
        }
        DispatchQueue.main.async {
            let vc = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
            self.bridge?.viewController?.present(vc, animated: true)
            call.resolve(["ok": true])
        }
    }

    @objc func setImeLine(_ call: CAPPluginCall) {
        let m = call.getInt("mode") ?? 0
        DispatchQueue.main.async {
            ImeLine.apply(m, on: self.bridge?.webView)
            call.resolve(["ok": true, "mode": m])
        }
    }

    @objc func imeDiag(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["report": ImeDiag.report(self.bridge?.webView)])
        }
    }

    @objc func settings(_ call: CAPPluginCall) {
        let ctx = LAContext()
        var err: NSError?
        let canBio = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        let lastRun = UserDefaults.standard.double(forKey: BackgroundSync.ranKey)
        UNUserNotificationCenter.current().getNotificationSettings { st in
            call.resolve([
                "imeLine": ImeLine.mode,
                "lock": LockGate.shared.enabled,
                "lockAvailable": canBio,
                "background": BackgroundSync.shared.enabled,
                "notifications": st.authorizationStatus == .authorized,
                "lastBgRun": lastRun > 0 ? ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: lastRun)) : ""
            ])
        }
    }

    @objc func setLock(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            call.resolve(["ok": false, "error": "这台设备没有可用的面容ID或密码"]); return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: on ? "打开 Lustre 的面容 ID 锁" : "关掉 Lustre 的面容 ID 锁") { ok, _ in
            DispatchQueue.main.async {
                if ok { LockGate.shared.enabled = on }
                call.resolve(["ok": ok, "lock": LockGate.shared.enabled])
            }
        }
    }

    @objc func setBackground(_ call: CAPPluginCall) {
        let on = call.getBool("on") ?? false
        if !on {
            BackgroundSync.shared.enabled = false
            BGTaskSchedulerCancelAll()
            call.resolve(["ok": true, "background": false]); return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                BackgroundSync.shared.enabled = true
                BackgroundSync.shared.schedule()
                call.resolve(["ok": true, "background": true, "notifications": granted])
            }
        }
    }
}

func BGTaskSchedulerCancelAll() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: BackgroundSync.taskId)
}

final class WebWatchdog {
    static let shared = WebWatchdog()
    private weak var webView: WKWebView?
    private var timer: Timer?
    private var lastReload = Date.distantPast
    private var confirming = false

    func start(_ wv: WKWebView) {
        webView = wv
        guard timer == nil else { return }
        let t = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            self?.check()
        }
        t.tolerance = 1.5
        timer = t
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self?.check() }
        }
    }

    private func check(confirmed: Bool = false) {
        guard UIApplication.shared.applicationState == .active,
              let wv = webView, !wv.isLoading else { return }
        var answered = false
        wv.evaluateJavaScript("1") { [weak self] _, err in
            if answered { return }
            answered = true
            if err != nil { self?.dead(confirmed: confirmed) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if !answered { answered = true; self?.dead(confirmed: confirmed) }
        }
    }

    private func dead(confirmed: Bool) {
        if !confirmed {
            if confirming { return }
            confirming = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.confirming = false
                self?.check(confirmed: true)
            }
            return
        }
        guard Date().timeIntervalSince(lastReload) > 12 else { return }
        lastReload = Date()
        webView?.reload()
    }
}
