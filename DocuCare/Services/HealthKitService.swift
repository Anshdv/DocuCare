//
//  HealthKitService.swift
//  DocuCare
//
//  Centralizes Apple Health (HealthKit) authorization and read-only snapshot
//  fetching used to give the AI a holistic view of the patient when answering
//  questions or summarizing reports.
//
//  IMPORTANT: HealthKit read access is implicit — Apple intentionally does NOT
//  expose whether the user denied any read type, only whether the auth prompt
//  has been seen. We persist a "user opted in" flag locally so DocuCare only
//  attaches health context when the user has explicitly enabled the integration.
//

import Foundation
import HealthKit
import Combine

/// Status of the HealthKit integration for the current user.
enum HealthKitConnectionStatus {
    /// Device does not expose HealthKit (e.g. unsupported hardware).
    case unavailable
    /// User has not yet been asked, or has not enabled the integration in DocuCare.
    case notConnected
    /// User enabled the integration; DocuCare will include health context where useful.
    case connected
}

/// Read-only summary of the most recent Apple Health data for the signed-in user.
/// Values are best-effort: any field can be `nil` if unauthorized, missing, or stale.
struct HealthSnapshot {
    struct Sample {
        let value: Double
        let unitLabel: String
        let date: Date
    }

    var biologicalSex: String?
    var bloodType: String?
    var dateOfBirth: Date?

    var heightMeters: Double?
    var bodyMassKg: Double?
    var bodyMassIndex: Double?
    var bodyFatPercent: Double?

    var restingHeartRateBPM: Sample?
    var latestHeartRateBPM: Sample?
    var systolicBP: Sample?
    var diastolicBP: Sample?
    var oxygenSaturationPercent: Sample?
    var bodyTemperatureC: Sample?
    var respiratoryRate: Sample?
    var bloodGlucoseMgPerDl: Sample?

    var avgDailySteps7d: Double?
    var avgDailyActiveEnergyKcal7d: Double?
    var avgDailySleepHours7d: Double?

    /// `true` if every field above is empty; used to decide whether to attach context to the AI.
    var isEmpty: Bool {
        biologicalSex == nil &&
        bloodType == nil &&
        dateOfBirth == nil &&
        heightMeters == nil &&
        bodyMassKg == nil &&
        bodyMassIndex == nil &&
        bodyFatPercent == nil &&
        restingHeartRateBPM == nil &&
        latestHeartRateBPM == nil &&
        systolicBP == nil &&
        diastolicBP == nil &&
        oxygenSaturationPercent == nil &&
        bodyTemperatureC == nil &&
        respiratoryRate == nil &&
        bloodGlucoseMgPerDl == nil &&
        avgDailySteps7d == nil &&
        avgDailyActiveEnergyKcal7d == nil &&
        avgDailySleepHours7d == nil
    }
}

final class HealthKitService {
    static let shared = HealthKitService()

    /// `nil` on simulators / devices that don't support HealthKit (defensive — we still gate calls on `isHealthDataAvailable`).
    private let store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    private init() {}

    // MARK: - Availability

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Set of types DocuCare reads to build a holistic patient profile for the AI.
    /// Read-only — DocuCare never writes to HealthKit.
    private var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = []

        // Characteristic types (constant patient attributes).
        if let t = HKObjectType.characteristicType(forIdentifier: .biologicalSex) { set.insert(t) }
        if let t = HKObjectType.characteristicType(forIdentifier: .bloodType) { set.insert(t) }
        if let t = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) { set.insert(t) }

        // Body measurements.
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .height, .bodyMass, .bodyMassIndex, .bodyFatPercentage,
            .heartRate, .restingHeartRate,
            .bloodPressureSystolic, .bloodPressureDiastolic,
            .oxygenSaturation, .bodyTemperature, .respiratoryRate,
            .bloodGlucose,
            .stepCount, .activeEnergyBurned
        ]
        for id in quantityIdentifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { set.insert(t) }
        }

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { set.insert(sleep) }

        return set
    }

    /// Triggers the system Health auth sheet. Apple does not reveal per-type read decisions,
    /// so we treat success of this call as "user has reviewed the prompt"; the caller decides
    /// whether to mark the integration as connected based on whether any data is readable.
    func requestAuthorization(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let store = store else {
            completion(.failure(NSError(domain: "DocuCare.HealthKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])))
            return
        }
        store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if !success {
                    completion(.failure(NSError(domain: "DocuCare.HealthKit", code: -2, userInfo: [NSLocalizedDescriptionKey: "Authorization was not granted."])))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    // MARK: - Snapshot

    /// Builds a best-effort snapshot of the most recent health metrics. Fields the user
    /// has not granted (or that have no samples) are simply left `nil`.
    func fetchSnapshot() async -> HealthSnapshot {
        guard let store = store else { return HealthSnapshot() }

        var snapshot = HealthSnapshot()

        // Characteristics.
        if let sex = try? store.biologicalSex().biologicalSex {
            snapshot.biologicalSex = HealthKitService.label(for: sex)
        }
        if let blood = try? store.bloodType().bloodType {
            snapshot.bloodType = HealthKitService.label(for: blood)
        }
        if let dob = try? store.dateOfBirthComponents().date {
            snapshot.dateOfBirth = dob
        }

        // Most-recent single samples.
        snapshot.heightMeters = await mostRecent(.height, unit: .meter())
        snapshot.bodyMassKg = await mostRecent(.bodyMass, unit: .gramUnit(with: .kilo))
        snapshot.bodyMassIndex = await mostRecent(.bodyMassIndex, unit: .count())
        snapshot.bodyFatPercent = await mostRecent(.bodyFatPercentage, unit: .percent()).map { $0 * 100 }

        snapshot.latestHeartRateBPM = await mostRecentSample(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "bpm")
        snapshot.restingHeartRateBPM = await mostRecentSample(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "bpm")
        snapshot.systolicBP = await mostRecentSample(.bloodPressureSystolic, unit: .millimeterOfMercury(), unitLabel: "mmHg")
        snapshot.diastolicBP = await mostRecentSample(.bloodPressureDiastolic, unit: .millimeterOfMercury(), unitLabel: "mmHg")
        if let oxygen = await mostRecentSample(.oxygenSaturation, unit: .percent(), unitLabel: "%") {
            snapshot.oxygenSaturationPercent = .init(value: oxygen.value * 100, unitLabel: "%", date: oxygen.date)
        }
        snapshot.bodyTemperatureC = await mostRecentSample(.bodyTemperature, unit: .degreeCelsius(), unitLabel: "°C")
        snapshot.respiratoryRate = await mostRecentSample(.respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "breaths/min")
        let glucoseUnit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        snapshot.bloodGlucoseMgPerDl = await mostRecentSample(.bloodGlucose, unit: glucoseUnit, unitLabel: "mg/dL")

        // 7-day averages.
        snapshot.avgDailySteps7d = await averageDaily(.stepCount, unit: .count(), days: 7)
        snapshot.avgDailyActiveEnergyKcal7d = await averageDaily(.activeEnergyBurned, unit: .kilocalorie(), days: 7)
        snapshot.avgDailySleepHours7d = await averageSleepHours(days: 7)

        return snapshot
    }

    // MARK: - Sample helpers

    private func mostRecent(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        await mostRecentSample(identifier, unit: unit, unitLabel: "")?.value
    }

    private func mostRecentSample(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, unitLabel: String) async -> HealthSnapshot.Sample? {
        guard let store = store, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample,
                      sample.quantity.is(compatibleWith: unit) else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: .init(value: value, unitLabel: unitLabel, date: sample.endDate))
            }
            store.execute(query)
        }
    }

    private func averageDaily(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double? {
        guard let store = store, let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: Date()).addingTimeInterval(86_400)
        guard let start = calendar.date(byAdding: .day, value: -days, to: endOfToday) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endOfToday, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: Date()),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: nil)
                    return
                }
                var totals: [Double] = []
                results.enumerateStatistics(from: start, to: endOfToday) { stats, _ in
                    if let sum = stats.sumQuantity()?.doubleValue(for: unit) {
                        totals.append(sum)
                    }
                }
                guard !totals.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let avg = totals.reduce(0, +) / Double(totals.count)
                continuation.resume(returning: avg)
            }
            store.execute(query)
        }
    }

    private func averageSleepHours(days: Int) async -> Double? {
        guard let store = store, let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let calendar = Calendar.current
        let endOfToday = calendar.startOfDay(for: Date()).addingTimeInterval(86_400)
        guard let start = calendar.date(byAdding: .day, value: -days, to: endOfToday) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: endOfToday, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Treat any "asleep" variant as sleep (Apple introduced finer-grained values in iOS 16).
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let totalSeconds = samples.reduce(0.0) { running, sample in
                    guard asleepValues.contains(sample.value) else { return running }
                    return running + sample.endDate.timeIntervalSince(sample.startDate)
                }
                guard totalSeconds > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let totalHours = totalSeconds / 3600.0
                continuation.resume(returning: totalHours / Double(days))
            }
            store.execute(query)
        }
    }

    // MARK: - Characteristic labels

    private static func label(for sex: HKBiologicalSex) -> String? {
        switch sex {
        case .female: return "female"
        case .male: return "male"
        case .other: return "other"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    private static func label(for blood: HKBloodType) -> String? {
        switch blood {
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        case .notSet: return nil
        @unknown default: return nil
        }
    }
}

// MARK: - Prompt-friendly formatting

extension HealthSnapshot {
    /// Produces a compact, multi-line English description of the snapshot intended for the
    /// AI system prompt. The AI is told elsewhere how to use it; this is purely the data
    /// block. Returns `nil` if there is nothing meaningful to share.
    func aiContextBlock(now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard !isEmpty else { return nil }
        var lines: [String] = []

        if let dob = dateOfBirth {
            let age = calendar.dateComponents([.year], from: dob, to: now).year
            if let age = age {
                lines.append("- Age: \(age)")
            }
        }
        if let sex = biologicalSex {
            lines.append("- Biological sex: \(sex)")
        }
        if let blood = bloodType {
            lines.append("- Blood type: \(blood)")
        }
        if let h = heightMeters {
            lines.append("- Height: \(String(format: "%.2f", h)) m")
        }
        if let w = bodyMassKg {
            lines.append("- Weight: \(String(format: "%.1f", w)) kg")
        }
        if let bmi = bodyMassIndex {
            lines.append("- BMI: \(String(format: "%.1f", bmi))")
        }
        if let bf = bodyFatPercent {
            lines.append("- Body fat: \(String(format: "%.1f", bf))%")
        }
        if let s = systolicBP, let d = diastolicBP {
            lines.append("- Latest blood pressure: \(Int(s.value.rounded()))/\(Int(d.value.rounded())) mmHg (\(Self.shortDate(s.date)))")
        } else {
            if let s = systolicBP {
                lines.append("- Latest systolic BP: \(Int(s.value.rounded())) mmHg (\(Self.shortDate(s.date)))")
            }
            if let d = diastolicBP {
                lines.append("- Latest diastolic BP: \(Int(d.value.rounded())) mmHg (\(Self.shortDate(d.date)))")
            }
        }
        if let r = restingHeartRateBPM {
            lines.append("- Resting heart rate: \(Int(r.value.rounded())) bpm (\(Self.shortDate(r.date)))")
        }
        if let h = latestHeartRateBPM {
            lines.append("- Most recent heart rate: \(Int(h.value.rounded())) bpm (\(Self.shortDate(h.date)))")
        }
        if let ox = oxygenSaturationPercent {
            lines.append("- Oxygen saturation (SpO₂): \(String(format: "%.1f", ox.value))% (\(Self.shortDate(ox.date)))")
        }
        if let t = bodyTemperatureC {
            lines.append("- Body temperature: \(String(format: "%.1f", t.value)) °C (\(Self.shortDate(t.date)))")
        }
        if let rr = respiratoryRate {
            lines.append("- Respiratory rate: \(String(format: "%.0f", rr.value)) breaths/min (\(Self.shortDate(rr.date)))")
        }
        if let g = bloodGlucoseMgPerDl {
            lines.append("- Blood glucose: \(String(format: "%.0f", g.value)) mg/dL (\(Self.shortDate(g.date)))")
        }
        if let steps = avgDailySteps7d {
            lines.append("- 7-day avg daily steps: \(Int(steps.rounded()))")
        }
        if let kcal = avgDailyActiveEnergyKcal7d {
            lines.append("- 7-day avg daily active energy: \(Int(kcal.rounded())) kcal")
        }
        if let sleep = avgDailySleepHours7d {
            lines.append("- 7-day avg sleep: \(String(format: "%.1f", sleep)) h/night")
        }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        df.locale = Locale(identifier: "en_US_POSIX")
        return df.string(from: date)
    }
}

// MARK: - UI display rows

/// A single row in the "Data accessed from Apple Health" view.
/// `value` is `nil` when DocuCare could not read that metric, so the UI can mark it as "Not shared".
struct HealthDisplayRow: Identifiable {
    let id = UUID()
    let labelKey: L10n.Key
    let value: String?
    let sampleDate: Date?
}

extension HealthSnapshot {
    /// All rows that DocuCare attempts to read, in display order. Unread metrics are returned
    /// with `value == nil` so the UI can clearly show what is missing or denied.
    func displayRows(now: Date = Date(), calendar: Calendar = .current, languageCode: String) -> [HealthDisplayRow] {
        let locale = Locale(identifier: AppLanguage.localeIdentifier(from: languageCode))
        let numberFmt: (Double, Int) -> String = { value, fractionDigits in
            let f = NumberFormatter()
            f.locale = locale
            f.numberStyle = .decimal
            f.minimumFractionDigits = fractionDigits
            f.maximumFractionDigits = fractionDigits
            return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(fractionDigits)f", value)
        }

        var rows: [HealthDisplayRow] = []

        // Characteristics ----------------------------------------------------
        let ageValue: String? = {
            guard let dob = dateOfBirth,
                  let years = calendar.dateComponents([.year], from: dob, to: now).year else {
                return nil
            }
            return "\(years)"
        }()
        rows.append(.init(labelKey: .appleHealthRowAge, value: ageValue, sampleDate: nil))
        rows.append(.init(labelKey: .appleHealthRowSex, value: biologicalSex?.capitalized, sampleDate: nil))
        rows.append(.init(labelKey: .appleHealthRowBloodType, value: bloodType, sampleDate: nil))

        // Body measurements --------------------------------------------------
        rows.append(.init(
            labelKey: .appleHealthRowHeight,
            value: heightMeters.map { "\(numberFmt($0, 2)) m" },
            sampleDate: nil
        ))
        rows.append(.init(
            labelKey: .appleHealthRowWeight,
            value: bodyMassKg.map { "\(numberFmt($0, 1)) kg" },
            sampleDate: nil
        ))
        rows.append(.init(
            labelKey: .appleHealthRowBMI,
            value: bodyMassIndex.map { numberFmt($0, 1) },
            sampleDate: nil
        ))
        rows.append(.init(
            labelKey: .appleHealthRowBodyFat,
            value: bodyFatPercent.map { "\(numberFmt($0, 1))%" },
            sampleDate: nil
        ))

        // Vitals -------------------------------------------------------------
        let bpValue: String? = {
            if let s = systolicBP, let d = diastolicBP {
                return "\(Int(s.value.rounded()))/\(Int(d.value.rounded())) mmHg"
            }
            if let s = systolicBP { return "\(Int(s.value.rounded())) mmHg" }
            if let d = diastolicBP { return "\(Int(d.value.rounded())) mmHg" }
            return nil
        }()
        let bpDate = systolicBP?.date ?? diastolicBP?.date
        rows.append(.init(labelKey: .appleHealthRowBloodPressure, value: bpValue, sampleDate: bpDate))

        rows.append(.init(
            labelKey: .appleHealthRowRestingHeartRate,
            value: restingHeartRateBPM.map { "\(Int($0.value.rounded())) bpm" },
            sampleDate: restingHeartRateBPM?.date
        ))
        rows.append(.init(
            labelKey: .appleHealthRowHeartRate,
            value: latestHeartRateBPM.map { "\(Int($0.value.rounded())) bpm" },
            sampleDate: latestHeartRateBPM?.date
        ))
        rows.append(.init(
            labelKey: .appleHealthRowOxygenSaturation,
            value: oxygenSaturationPercent.map { "\(numberFmt($0.value, 1))%" },
            sampleDate: oxygenSaturationPercent?.date
        ))
        rows.append(.init(
            labelKey: .appleHealthRowBodyTemperature,
            value: bodyTemperatureC.map { "\(numberFmt($0.value, 1)) °C" },
            sampleDate: bodyTemperatureC?.date
        ))
        rows.append(.init(
            labelKey: .appleHealthRowRespiratoryRate,
            value: respiratoryRate.map { "\(Int($0.value.rounded())) /min" },
            sampleDate: respiratoryRate?.date
        ))
        rows.append(.init(
            labelKey: .appleHealthRowBloodGlucose,
            value: bloodGlucoseMgPerDl.map { "\(Int($0.value.rounded())) mg/dL" },
            sampleDate: bloodGlucoseMgPerDl?.date
        ))

        // 7-day averages -----------------------------------------------------
        rows.append(.init(
            labelKey: .appleHealthRowAvgDailySteps,
            value: avgDailySteps7d.map { "\(Int($0.rounded()))" },
            sampleDate: nil
        ))
        rows.append(.init(
            labelKey: .appleHealthRowAvgActiveEnergy,
            value: avgDailyActiveEnergyKcal7d.map { "\(Int($0.rounded())) kcal" },
            sampleDate: nil
        ))
        rows.append(.init(
            labelKey: .appleHealthRowAvgSleep,
            value: avgDailySleepHours7d.map { "\(numberFmt($0, 1)) h" },
            sampleDate: nil
        ))

        return rows
    }
}
