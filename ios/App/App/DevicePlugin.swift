import Foundation
import Capacitor
import UIKit
import CoreLocation
import EventKit

@objc(DevicePlugin)
public class DevicePlugin: CAPPlugin, CAPBridgedPlugin, CLLocationManagerDelegate {
    public let identifier = "DevicePlugin"
    public let jsName = "Device2"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "battery", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestLocation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "location", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestCalendar", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "calendarEvents", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addEvent", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reminders", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addReminder", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "completeReminder", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "permissions", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openSettings", returnType: CAPPluginReturnPromise)
    ]

    let locMgr = CLLocationManager()
    var locCall: CAPPluginCall?
    let store = EKEventStore()
    let iso = ISO8601DateFormatter()

    @objc func permissions(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let ls: CLAuthorizationStatus
            if #available(iOS 14.0, *) { ls = self.locMgr.authorizationStatus }
            else { ls = CLLocationManager.authorizationStatus() }
            let locName: String
            switch ls {
            case .authorizedAlways: locName = "always"
            case .authorizedWhenInUse: locName = "whenInUse"
            case .denied: locName = "denied"
            case .restricted: locName = "restricted"
            case .notDetermined: locName = "notDetermined"
            @unknown default: locName = "unknown"
            }
            call.resolve([
                "location": locName,
                "calendar": self.ekName(EKEventStore.authorizationStatus(for: .event)),
                "reminders": self.ekName(EKEventStore.authorizationStatus(for: .reminder))
            ])
        }
    }

    func ekName(_ s: EKAuthorizationStatus) -> String {
        if #available(iOS 17.0, *) {
            switch s {
            case .fullAccess: return "full"
            case .writeOnly: return "writeOnly"
            case .denied: return "denied"
            case .restricted: return "restricted"
            case .notDetermined: return "notDetermined"
            default: return "unknown"
            }
        }
        switch s {
        case .authorized: return "full"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        default: return "unknown"
        }
    }

    @objc func openSettings(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                call.resolve(["ok": false]); return
            }
            UIApplication.shared.open(url, options: [:]) { ok in call.resolve(["ok": ok]) }
        }
    }

    @objc func battery(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            UIDevice.current.isBatteryMonitoringEnabled = true
            let lvl = UIDevice.current.batteryLevel
            let st = UIDevice.current.batteryState
            let stName: String
            switch st {
            case .charging: stName = "charging"
            case .full: stName = "full"
            case .unplugged: stName = "unplugged"
            default: stName = "unknown"
            }
            call.resolve([
                "level": lvl < 0 ? -1 : Int((lvl * 100).rounded()),
                "state": stName,
                "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled
            ])
        }
    }

    @objc func requestLocation(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.locMgr.delegate = self
            self.locMgr.requestWhenInUseAuthorization()
            call.resolve(["requested": true])
        }
    }

    @objc func location(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let status = CLLocationManager.authorizationStatus()
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                call.resolve(["ok": false, "reason": "denied"]); return
            }
            self.locCall = call
            self.locMgr.delegate = self
            self.locMgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
            self.locMgr.requestLocation()
        }
    }

    public func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let c = locCall, let l = locs.last else { return }
        locCall = nil
        c.resolve([
            "ok": true,
            "lat": l.coordinate.latitude,
            "lon": l.coordinate.longitude,
            "accuracy": l.horizontalAccuracy,
            "time": iso.string(from: l.timestamp)
        ])
    }

    public func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        guard let c = locCall else { return }
        locCall = nil
        c.resolve(["ok": false, "reason": error.localizedDescription])
    }

    @objc func requestCalendar(_ call: CAPPluginCall) {
        var gotEvent = false, gotReminder = false
        let group = DispatchGroup()
        group.enter(); group.enter()
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { ok, _ in gotEvent = ok; group.leave() }
            store.requestFullAccessToReminders { ok, _ in gotReminder = ok; group.leave() }
        } else {
            store.requestAccess(to: .event) { ok, _ in gotEvent = ok; group.leave() }
            store.requestAccess(to: .reminder) { ok, _ in gotReminder = ok; group.leave() }
        }
        group.notify(queue: .main) {
            call.resolve(["calendar": gotEvent, "reminders": gotReminder])
        }
    }

    @objc func calendarEvents(_ call: CAPPluginCall) {
        let days = call.getInt("days") ?? 7
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let items = store.events(matching: pred).map { e -> [String: Any] in
            [
                "id": e.eventIdentifier ?? "",
                "title": e.title ?? "",
                "start": iso.string(from: e.startDate),
                "end": iso.string(from: e.endDate),
                "allDay": e.isAllDay,
                "location": e.location ?? "",
                "notes": e.notes ?? "",
                "calendar": e.calendar?.title ?? ""
            ]
        }
        call.resolve(["events": items])
    }

    @objc func addEvent(_ call: CAPPluginCall) {
        guard let title = call.getString("title"),
              let startS = call.getString("start"),
              let start = iso.date(from: startS) else {
            call.reject("need title + start(ISO8601)"); return
        }
        let end = call.getString("end").flatMap { iso.date(from: $0) }
            ?? Calendar.current.date(byAdding: .hour, value: 1, to: start)!
        let e = EKEvent(eventStore: store)
        e.title = title
        e.startDate = start
        e.endDate = end
        e.notes = call.getString("notes")
        e.location = call.getString("location")
        e.calendar = store.defaultCalendarForNewEvents
        if let mins = call.getInt("alarmMinutesBefore") {
            e.addAlarm(EKAlarm(relativeOffset: TimeInterval(-60 * mins)))
        }
        do {
            try store.save(e, span: .thisEvent)
            call.resolve(["ok": true, "id": e.eventIdentifier ?? ""])
        } catch {
            call.resolve(["ok": false, "error": error.localizedDescription])
        }
    }

    @objc func reminders(_ call: CAPPluginCall) {
        let pred = store.predicateForReminders(in: nil)
        store.fetchReminders(matching: pred) { list in
            let items = (list ?? []).map { r -> [String: Any] in
                var d: [String: Any] = [
                    "id": r.calendarItemIdentifier,
                    "title": r.title ?? "",
                    "completed": r.isCompleted,
                    "notes": r.notes ?? "",
                    "list": r.calendar?.title ?? ""
                ]
                if let due = r.dueDateComponents,
                   let date = Calendar.current.date(from: due) {
                    d["due"] = self.iso.string(from: date)
                }
                return d
            }
            DispatchQueue.main.async { call.resolve(["reminders": items]) }
        }
    }

    @objc func addReminder(_ call: CAPPluginCall) {
        guard let title = call.getString("title") else {
            call.reject("need title"); return
        }
        let r = EKReminder(eventStore: store)
        r.title = title
        r.notes = call.getString("notes")
        r.calendar = store.defaultCalendarForNewReminders()
        if let dueS = call.getString("due"), let due = iso.date(from: dueS) {
            r.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due)
            r.addAlarm(EKAlarm(absoluteDate: due))
        }
        do {
            try store.save(r, commit: true)
            call.resolve(["ok": true, "id": r.calendarItemIdentifier])
        } catch {
            call.resolve(["ok": false, "error": error.localizedDescription])
        }
    }

    @objc func completeReminder(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else { call.reject("need id"); return }
        guard let item = store.calendarItem(withIdentifier: id) as? EKReminder else {
            call.resolve(["ok": false, "error": "not found"]); return
        }
        item.isCompleted = true
        do {
            try store.save(item, commit: true)
            call.resolve(["ok": true])
        } catch {
            call.resolve(["ok": false, "error": error.localizedDescription])
        }
    }
}

final class LXVitalsLoop {
    static let shared = LXVitalsLoop()
    weak var health: HealthPlugin?
    weak var device: DevicePlugin?
    private var asked = false
    private var timer: Timer?
    private var running = false

    func start(health: HealthPlugin, device: DevicePlugin) {
        self.health = health
        self.device = device
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.report() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in self?.report() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self?.report() }
        }
    }

    private func call(_ opts: [String: Any] = [:], _ done: @escaping ([String: Any]?) -> Void,
                      _ run: (CAPPluginCall) -> Void) {
        var fired = false
        guard let c = CAPPluginCall(callbackId: "lx-vitals", methodName: "native", options: opts,
                              success: { res, _ in
                                  DispatchQueue.main.async { if !fired { fired = true; done(res?.data) } }
                              },
                              error: { _ in
                                  DispatchQueue.main.async { if !fired { fired = true; done(nil) } }
                              }) else { done(nil); return }
        run(c)
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { if !fired { fired = true; done(nil) } }
    }

    private func askPermissions(_ done: @escaping () -> Void) {
        guard !asked, !LustreConfig.isPreview, let h = health, let d = device else { done(); return }
        asked = true
        call([:], { _ in
            self.call([:], { _ in
                self.call([:], { _ in done() }) { d.requestLocation($0) }
            }) { d.requestCalendar($0) }
        }) { h.requestAuth($0) }
    }

    func report() {
        guard !running, UIApplication.shared.applicationState == .active else { return }
        running = true
        askPermissions { [weak self] in
            self?.runOrders { self?.collectAndSend() }
        }
    }

    private func req(_ path: String, _ method: String = "GET", _ body: [String: Any]? = nil) -> URLRequest? {
        guard let u = URL(string: LustreConfig.apiBase + path) else { return nil }
        var r = URLRequest(url: u, timeoutInterval: 20)
        r.httpMethod = method
        r.setValue("Bearer " + LustreConfig.secret, forHTTPHeaderField: "Authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        return r
    }

    private func runOrders(_ done: @escaping () -> Void) {
        guard let d = device, let r = req("/app/order") else { done(); return }
        URLSession.shared.dataTask(with: r) { data, resp, _ in
            DispatchQueue.main.async {
                guard (resp as? HTTPURLResponse)?.statusCode == 200, let data,
                      let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let orders = obj["orders"] as? [[String: Any]], !orders.isEmpty else { done(); return }
                var results: [[String: Any]] = []
                func next(_ i: Int) {
                    guard i < orders.count else {
                        if let rr = self.req("/app/order/done", "POST", ["results": results]) {
                            URLSession.shared.dataTask(with: rr).resume()
                        }
                        let okN = results.filter { ($0["ok"] as? Bool) == true }.count
                        if okN > 0 {
                            LXToast.show("已按\(LXVitalsLoop.yanName)的安排加了 \(okN) 条",
                                         host: ChatListPlugin.live?.bridge?.viewController?.view)
                        }
                        done()
                        return
                    }
                    let o = orders[i]
                    let id = o["id"] ?? ""
                    let args = (o["args"] as? [String: Any]) ?? [:]
                    let finish: ([String: Any]?) -> Void = { out in
                        results.append(["id": id, "ok": (out?["ok"] as? Bool) ?? false,
                                        "nativeId": (out?["id"] as? String) ?? "",
                                        "error": (out?["error"] as? String) ?? (out == nil ? "failed" : "")])
                        next(i + 1)
                    }
                    switch o["kind"] as? String ?? "" {
                    case "addEvent": self.call(args, finish) { d.addEvent($0) }
                    case "addReminder": self.call(args, finish) { d.addReminder($0) }
                    case "completeReminder": self.call(args, finish) { d.completeReminder($0) }
                    default:
                        results.append(["id": id, "ok": false, "error": "unknown kind"])
                        next(i + 1)
                    }
                }
                next(0)
            }
        }.resume()
    }

    static var yanName: String { LXNick.yan }

    private func collectAndSend() {
        guard let h = health, let d = device else { running = false; return }
        var out: [String: Any] = [:]
        let g = DispatchGroup()
        g.enter(); call([:], { v in if let v, !v.isEmpty { out["health"] = v }; g.leave() }) { h.snapshot($0) }
        g.enter(); call([:], { v in if let v { out["battery"] = v }; g.leave() }) { d.battery($0) }
        g.enter(); call([:], { v in if let v, (v["ok"] as? Bool) == true { out["location"] = v }; g.leave() }) { d.location($0) }
        g.enter(); call(["days": 7], { v in if let ev = v?["events"] { out["calendar"] = ev }; g.leave() }) { d.calendarEvents($0) }
        g.enter(); call([:], { v in
            if let rs = v?["reminders"] as? [[String: Any]] {
                out["reminders"] = Array(rs.filter { ($0["completed"] as? Bool) != true }.prefix(50))
            }
            g.leave()
        }) { d.reminders($0) }
        g.notify(queue: .main) { [weak self] in
            guard let s = self else { return }
            s.running = false
            guard !out.isEmpty, JSONSerialization.isValidJSONObject(out), let r = s.req("/app/vitals", "POST", out) else { return }
            URLSession.shared.dataTask(with: r).resume()
        }
    }
}
