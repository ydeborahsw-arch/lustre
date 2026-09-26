import Foundation
import Capacitor
import HealthKit

@objc(HealthPlugin)
public class HealthPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "HealthPlugin"
    public let jsName = "Health"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "requestAuth", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "snapshot", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authStatus", returnType: CAPPluginReturnPromise)
    ]

    let store = HKHealthStore()

    func readTypes() -> Set<HKObjectType> { Self.readTypeSet() }

    static func readTypeSet() -> Set<HKObjectType> {
        var t = Set<HKObjectType>()

        let quantityIds: [String] = [
            "HKQuantityTypeIdentifierHeartRate", "HKQuantityTypeIdentifierRestingHeartRate",
            "HKQuantityTypeIdentifierWalkingHeartRateAverage", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
            "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute",
            "HKQuantityTypeIdentifierBloodPressureSystolic", "HKQuantityTypeIdentifierBloodPressureDiastolic",
            "HKQuantityTypeIdentifierVO2Max", "HKQuantityTypeIdentifierAtrialFibrillationBurden",
            "HKQuantityTypeIdentifierStepCount", "HKQuantityTypeIdentifierDistanceWalkingRunning",
            "HKQuantityTypeIdentifierDistanceCycling", "HKQuantityTypeIdentifierDistanceSwimming",
            "HKQuantityTypeIdentifierFlightsClimbed", "HKQuantityTypeIdentifierActiveEnergyBurned",
            "HKQuantityTypeIdentifierBasalEnergyBurned", "HKQuantityTypeIdentifierAppleExerciseTime",
            "HKQuantityTypeIdentifierAppleStandTime", "HKQuantityTypeIdentifierAppleMoveTime",
            "HKQuantityTypeIdentifierWalkingSpeed", "HKQuantityTypeIdentifierWalkingStepLength",
            "HKQuantityTypeIdentifierWalkingAsymmetryPercentage", "HKQuantityTypeIdentifierWalkingDoubleSupportPercentage",
            "HKQuantityTypeIdentifierSixMinuteWalkTestDistance", "HKQuantityTypeIdentifierStairAscentSpeed",
            "HKQuantityTypeIdentifierStairDescentSpeed", "HKQuantityTypeIdentifierRunningPower",
            "HKQuantityTypeIdentifierRunningSpeed", "HKQuantityTypeIdentifierRunningStrideLength",
            "HKQuantityTypeIdentifierPhysicalEffort",
            "HKQuantityTypeIdentifierRespiratoryRate", "HKQuantityTypeIdentifierOxygenSaturation",
            "HKQuantityTypeIdentifierForcedVitalCapacity", "HKQuantityTypeIdentifierPeakExpiratoryFlowRate",
            "HKQuantityTypeIdentifierBodyMass", "HKQuantityTypeIdentifierBodyMassIndex",
            "HKQuantityTypeIdentifierBodyFatPercentage", "HKQuantityTypeIdentifierLeanBodyMass",
            "HKQuantityTypeIdentifierHeight", "HKQuantityTypeIdentifierWaistCircumference",
            "HKQuantityTypeIdentifierBodyTemperature", "HKQuantityTypeIdentifierBasalBodyTemperature",
            "HKQuantityTypeIdentifierAppleSleepingWristTemperature",
            "HKQuantityTypeIdentifierBloodGlucose", "HKQuantityTypeIdentifierInsulinDelivery",
            "HKQuantityTypeIdentifierBloodAlcoholContent",
            "HKQuantityTypeIdentifierDietaryWater", "HKQuantityTypeIdentifierDietaryEnergyConsumed",
            "HKQuantityTypeIdentifierDietaryCaffeine", "HKQuantityTypeIdentifierDietaryProtein",
            "HKQuantityTypeIdentifierDietaryCarbohydrates", "HKQuantityTypeIdentifierDietaryFatTotal",
            "HKQuantityTypeIdentifierDietarySugar", "HKQuantityTypeIdentifierDietaryFiber",
            "HKQuantityTypeIdentifierDietarySodium",
            "HKQuantityTypeIdentifierEnvironmentalAudioExposure", "HKQuantityTypeIdentifierHeadphoneAudioExposure",
            "HKQuantityTypeIdentifierEnvironmentalSoundReduction",
            "HKQuantityTypeIdentifierUVExposure", "HKQuantityTypeIdentifierTimeInDaylight",
            "HKQuantityTypeIdentifierNumberOfTimesFallen", "HKQuantityTypeIdentifierAppleWalkingSteadiness"
        ]
        for id in quantityIds {
            if let q = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) { t.insert(q) }
        }

        let categoryIds: [String] = [
            "HKCategoryTypeIdentifierSleepAnalysis", "HKCategoryTypeIdentifierMindfulSession",
            "HKCategoryTypeIdentifierMenstrualFlow", "HKCategoryTypeIdentifierIntermenstrualBleeding",
            "HKCategoryTypeIdentifierInfrequentMenstrualCycles", "HKCategoryTypeIdentifierIrregularMenstrualCycles",
            "HKCategoryTypeIdentifierPersistentIntermenstrualBleeding", "HKCategoryTypeIdentifierProlongedMenstrualPeriods",
            "HKCategoryTypeIdentifierCervicalMucusQuality", "HKCategoryTypeIdentifierOvulationTestResult",
            "HKCategoryTypeIdentifierProgesteroneTestResult", "HKCategoryTypeIdentifierSexualActivity",
            "HKCategoryTypeIdentifierContraceptive", "HKCategoryTypeIdentifierPregnancy",
            "HKCategoryTypeIdentifierPregnancyTestResult", "HKCategoryTypeIdentifierLactation",
            "HKCategoryTypeIdentifierAbdominalCramps", "HKCategoryTypeIdentifierBloating",
            "HKCategoryTypeIdentifierBreastPain", "HKCategoryTypeIdentifierPelvicPain",
            "HKCategoryTypeIdentifierLowerBackPain", "HKCategoryTypeIdentifierHeadache",
            "HKCategoryTypeIdentifierMoodChanges", "HKCategoryTypeIdentifierFatigue",
            "HKCategoryTypeIdentifierNausea", "HKCategoryTypeIdentifierVomiting",
            "HKCategoryTypeIdentifierDizziness", "HKCategoryTypeIdentifierFainting",
            "HKCategoryTypeIdentifierChills", "HKCategoryTypeIdentifierFever",
            "HKCategoryTypeIdentifierHotFlashes", "HKCategoryTypeIdentifierNightSweats",
            "HKCategoryTypeIdentifierAcne", "HKCategoryTypeIdentifierAppetiteChanges",
            "HKCategoryTypeIdentifierSleepChanges", "HKCategoryTypeIdentifierConstipation",
            "HKCategoryTypeIdentifierDiarrhea", "HKCategoryTypeIdentifierHeartburn",
            "HKCategoryTypeIdentifierCoughing", "HKCategoryTypeIdentifierShortnessOfBreath",
            "HKCategoryTypeIdentifierChestTightnessOrPain", "HKCategoryTypeIdentifierRunnyNose",
            "HKCategoryTypeIdentifierSoreThroat", "HKCategoryTypeIdentifierSinusCongestion",
            "HKCategoryTypeIdentifierLossOfSmell", "HKCategoryTypeIdentifierLossOfTaste",
            "HKCategoryTypeIdentifierMemoryLapse", "HKCategoryTypeIdentifierDrySkin",
            "HKCategoryTypeIdentifierHairLoss", "HKCategoryTypeIdentifierBladderIncontinence",
            "HKCategoryTypeIdentifierGeneralizedBodyAche", "HKCategoryTypeIdentifierWheezing",
            "HKCategoryTypeIdentifierHighHeartRateEvent", "HKCategoryTypeIdentifierLowHeartRateEvent",
            "HKCategoryTypeIdentifierIrregularHeartRhythmEvent", "HKCategoryTypeIdentifierAppleStandHour",
            "HKCategoryTypeIdentifierLowCardioFitnessEvent", "HKCategoryTypeIdentifierAudioExposureEvent",
            "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent", "HKCategoryTypeIdentifierHandwashingEvent",
            "HKCategoryTypeIdentifierToothbrushingEvent"
        ]
        for id in categoryIds {
            if let c = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: id)) { t.insert(c) }
        }

        t.insert(HKObjectType.workoutType())
        if let cs = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { t.insert(cs) }
        if let cb = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { t.insert(cb) }
        if let cbt = HKObjectType.characteristicType(forIdentifier: .bloodType) { t.insert(cbt) }
        if #available(iOS 16.0, *) {
            if let st = HKObjectType.seriesType(forIdentifier: HKDataTypeIdentifierHeartbeatSeries) { t.insert(st) }
        }
        return t
    }

    @objc func available(_ call: CAPPluginCall) {
        call.resolve(["available": HKHealthStore.isHealthDataAvailable()])
    }

    @objc func requestAuth(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["granted": false, "reason": "unavailable"]); return
        }
        store.requestAuthorization(toShare: nil, read: readTypes()) { ok, err in
            call.resolve(["granted": ok, "error": err?.localizedDescription ?? ""])
        }
    }

    @objc func authStatus(_ call: CAPPluginCall) {
        guard HKHealthStore.isHealthDataAvailable() else {
            call.resolve(["available": false, "status": "unavailable"]); return
        }
        store.getRequestStatusForAuthorization(toShare: [], read: readTypes()) { st, err in
            let name: String
            switch st {
            case .unnecessary: name = "asked"
            case .shouldRequest: name = "notAsked"
            default: name = "unknown"
            }
            call.resolve([
                "available": true,
                "status": name,
                "types": self.readTypes().count,
                "error": err?.localizedDescription ?? ""
            ])
        }
    }

    @objc func snapshot(_ call: CAPPluginCall) {
        HealthPlugin.collect(store: store) { out in call.resolve(out) }
    }

    static func collect(store: HKHealthStore, completion: @escaping ([String: Any]) -> Void) {
        var out: [String: Any] = [:]
        let group = DispatchGroup()
        let lock = NSLock()
        func put(_ k: String, _ v: Any) { lock.lock(); out[k] = v; lock.unlock() }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let dayStart = cal.startOfDay(for: Date())
        let dayPred = HKQuery.predicateForSamples(withStart: dayStart, end: Date(), options: .strictStartDate)

        let sums: [(String, String, HKUnit)] = [
            ("stepsToday", "HKQuantityTypeIdentifierStepCount", .count()),
            ("distanceTodayM", "HKQuantityTypeIdentifierDistanceWalkingRunning", .meter()),
            ("flightsToday", "HKQuantityTypeIdentifierFlightsClimbed", .count()),
            ("activeKcalToday", "HKQuantityTypeIdentifierActiveEnergyBurned", .kilocalorie()),
            ("exerciseMinToday", "HKQuantityTypeIdentifierAppleExerciseTime", .minute()),
            ("standHoursToday", "HKQuantityTypeIdentifierAppleStandTime", .minute()),
            ("waterTodayML", "HKQuantityTypeIdentifierDietaryWater", .literUnit(with: .milli)),
            ("daylightMinToday", "HKQuantityTypeIdentifierTimeInDaylight", .minute())
        ]
        for (key, id, unit) in sums {
            guard let q = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) else { continue }
            group.enter()
            let query = HKStatisticsQuery(quantityType: q, quantitySamplePredicate: dayPred, options: .cumulativeSum) { _, stat, _ in
                if let sum = stat?.sumQuantity() {
                    put(key, (sum.doubleValue(for: unit) * 10).rounded() / 10)
                }
                group.leave()
            }
            store.execute(query)
        }

        let latest: [(String, String, HKUnit)] = [
            ("heartRate", "HKQuantityTypeIdentifierHeartRate", HKUnit(from: "count/min")),
            ("restingHeartRate", "HKQuantityTypeIdentifierRestingHeartRate", HKUnit(from: "count/min")),
            ("hrvSDNN", "HKQuantityTypeIdentifierHeartRateVariabilitySDNN", HKUnit.secondUnit(with: .milli)),
            ("oxygenSaturation", "HKQuantityTypeIdentifierOxygenSaturation", .percent()),
            ("respiratoryRate", "HKQuantityTypeIdentifierRespiratoryRate", HKUnit(from: "count/min")),
            ("bodyMassKg", "HKQuantityTypeIdentifierBodyMass", .gramUnit(with: .kilo)),
            ("bodyTemperature", "HKQuantityTypeIdentifierBodyTemperature", .degreeCelsius()),
            ("wristTemperature", "HKQuantityTypeIdentifierAppleSleepingWristTemperature", .degreeCelsius()),
            ("audioExposureDB", "HKQuantityTypeIdentifierEnvironmentalAudioExposure", .decibelAWeightedSoundPressureLevel()),
            ("walkingSpeed", "HKQuantityTypeIdentifierWalkingSpeed", HKUnit(from: "m/s"))
        ]
        for (key, id, unit) in latest {
            guard let q = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: id)) else { continue }
            group.enter()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: q, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let sm = samples?.first as? HKQuantitySample {
                    put(key, (sm.quantity.doubleValue(for: unit) * 100).rounded() / 100)
                    put(key + "Time", ISO8601DateFormatter().string(from: sm.endDate))
                }
                group.leave()
            }
            store.execute(query)
        }

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            group.enter()
            let from = cal.date(byAdding: .hour, value: -6, to: dayStart) ?? dayStart
            let pred = HKQuery.predicateForSamples(withStart: from, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: sleep, predicate: pred, limit: 0, sortDescriptors: [sort]) { _, samples, _ in
                var secs = 0.0
                var deep = 0.0, rem = 0.0, core = 0.0, awake = 0.0
                var segs: [[String: Any]] = []
                func stage(_ v: Int) -> String {
                    if v == HKCategoryValueSleepAnalysis.awake.rawValue { return "awake" }
                    if #available(iOS 16.0, *) {
                        if v == HKCategoryValueSleepAnalysis.asleepDeep.rawValue { return "deep" }
                        if v == HKCategoryValueSleepAnalysis.asleepREM.rawValue { return "rem" }
                    }
                    return "core"
                }
                for s in (samples as? [HKCategorySample]) ?? [] {
                    if s.value == HKCategoryValueSleepAnalysis.inBed.rawValue { continue }
                    let d = s.endDate.timeIntervalSince(s.startDate)
                    let t = stage(s.value)
                    if t == "awake" {
                        awake += d
                    } else {
                        secs += d
                        switch t {
                        case "deep": deep += d
                        case "rem":  rem += d
                        default:     core += d
                        }
                    }
                    let s0 = Int(s.startDate.timeIntervalSince1970), e0 = Int(s.endDate.timeIntervalSince1970)
                    if var last = segs.last, last["t"] as? String == t, (last["e"] as? Int ?? 0) >= s0 - 90 {
                        last["e"] = max(last["e"] as? Int ?? 0, e0)
                        segs[segs.count - 1] = last
                    } else {
                        segs.append(["t": t, "s": s0, "e": e0])
                    }
                }
                if secs > 0 {
                    put("sleepHours", (secs / 3600 * 10).rounded() / 10)
                    if awake > 0 { put("sleepAwakeMin", Int((awake / 60).rounded())) }
                    if !segs.isEmpty { put("sleepSegments", segs) }
                    if deep > 0 { put("sleepDeepMin", Int((deep / 60).rounded())) }
                    if rem  > 0 { put("sleepRemMin",  Int((rem  / 60).rounded())) }
                    if core > 0 { put("sleepCoreMin", Int((core / 60).rounded())) }
                }
                group.leave()
            }
            store.execute(query)
        }

        let eventIds: [(HKCategoryTypeIdentifier, String)] = [
            (.highHeartRateEvent, "highHeartRateEvents"),
            (.lowHeartRateEvent, "lowHeartRateEvents"),
            (.irregularHeartRhythmEvent, "irregularRhythmEvents"),
        ]
        let dayAgo = Date(timeIntervalSinceNow: -24 * 3600)
        for (ident, key) in eventIds {
            guard let t = HKObjectType.categoryType(forIdentifier: ident) else { continue }
            group.enter()
            let pred = HKQuery.predicateForSamples(withStart: dayAgo, end: nil, options: [])
            let q = HKSampleQuery(sampleType: t, predicate: pred, limit: 50, sortDescriptors: nil) { _, samples, _ in
                let n = samples?.count ?? 0
                if n > 0 { put(key, n) }
                group.leave()
            }
            store.execute(q)
        }

        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            group.enter()
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: flow, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let sm = samples?.first as? HKCategorySample {
                    put("menstrualFlow", sm.value)
                    put("menstrualFlowTime", ISO8601DateFormatter().string(from: sm.startDate))
                }
                group.leave()
            }
            store.execute(query)
        }

        if let flow = HKObjectType.categoryType(forIdentifier: .menstrualFlow) {
            group.enter()
            let from = Calendar.current.date(byAdding: .day, value: -365, to: Date()) ?? Date()
            let pred = HKQuery.predicateForSamples(withStart: from, end: Date(), options: [])
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: flow, predicate: pred, limit: 0, sortDescriptors: [sort]) { _, samples, _ in
                var hist: [[String: Any]] = []
                for sm in (samples as? [HKCategorySample]) ?? [] {
                    hist.append(["s": Int(sm.startDate.timeIntervalSince1970),
                                 "e": Int(sm.endDate.timeIntervalSince1970),
                                 "v": sm.value])
                }
                if !hist.isEmpty { put("menstrualHistory", hist) }
                group.leave()
            }
            store.execute(query)
        }

        group.notify(queue: .main) { completion(out) }
    }
}
