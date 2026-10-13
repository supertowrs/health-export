import HealthKit

/// Texto del resumen de un día: actividad, corazón, etc. de ese día y el sueño de la noche siguiente.
enum Report {
    private static let locale = Locale(identifier: "es_ES")

    static var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
    }

    static func text(for day: Date, types: [ExportType]) async throws -> String {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let predicate = HKQuery.predicateForSamples(withStart: day, end: end)
        var lines = ["Resumen de Apple Salud del \(day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))", ""]
        var missing: [String] = []

        for type in types {
            let summary: [String]
            if let quantityType = type.sampleType as? HKQuantityType {
                summary = try await quantity(type, quantityType, predicate)
            } else if type.id == "workouts" {
                summary = try await workouts(predicate)
            } else if type.id == "sleepAnalysis" {
                summary = try await sleep(after: day)
            } else {
                summary = try await events(type, predicate)
            }
            if summary.isEmpty { missing.append(type.name) } else { lines += summary }
        }
        if !missing.isEmpty { lines += ["", "Sin datos: " + missing.joined(separator: ", ")] }
        return lines.joined(separator: "\n")
    }

    /// Suma (pasos, energía…) o media/mínimo/máximo (pulso, peso…). HealthKit ya descuenta
    /// los solapes entre iPhone y Watch, igual que la app Salud.
    private static func quantity(_ type: ExportType, _ quantityType: HKQuantityType, _ predicate: NSPredicate) async throws -> [String] {
        let cumulative = quantityType.aggregationStyle == .cumulative
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: quantityType, predicate: predicate),
            options: cumulative ? .cumulativeSum : [.discreteAverage, .discreteMin, .discreteMax])
        let stats: HKStatistics?
        do { stats = try await descriptor.result(for: Health.store) } catch HKError.errorNoData { return [] }

        if cumulative {
            guard let sum = stats?.sumQuantity() else { return [] }
            return ["\(type.name): \(format(sum, type))"]
        }
        guard let average = stats?.averageQuantity(), let min = stats?.minimumQuantity(), let max = stats?.maximumQuantity() else { return [] }
        if format(min, type) == format(max, type) { return ["\(type.name): \(format(average, type))"] }
        return ["\(type.name): media \(format(average, type)), mín. \(format(min, type, unit: false)), máx. \(format(max, type, unit: false))"]
    }

    private static func workouts(_ predicate: NSPredicate) async throws -> [String] {
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [SortDescriptor(\.startDate)])
        let workouts = try await descriptor.result(for: Health.store)
        guard !workouts.isEmpty else { return [] }
        let distances: [HKQuantityTypeIdentifier] = [.distanceWalkingRunning, .distanceCycling, .distanceSwimming]
        return ["Entrenamientos:"] + workouts.map { w in
            var parts = [Catalog.workoutNames[w.workoutActivityType] ?? "Entrenamiento", "a las \(time(w.startDate))", duration(w.duration)]
            if let km = distances.lazy.compactMap({ w.statistics(for: HKQuantityType($0))?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) }).first {
                parts.append("\(number(km, decimals: 1)) km")
            }
            if let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                parts.append("\(number(kcal)) kcal")
            }
            if let bpm = w.statistics(for: HKQuantityType(.heartRate))?.averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
                parts.append("FC media \(number(bpm)) lpm")
            }
            return "- " + parts.joined(separator: ", ")
        }
    }

    /// Sueño que empieza entre el mediodía del día y el del día siguiente.
    private static func sleep(after day: Date) async throws -> [String] {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .hour, value: 12, to: day)!
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: calendar.date(byAdding: .day, value: 1, to: start), options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let all = try await descriptor.result(for: Health.store)

        // iPhone, Watch y otras apps pueden registrar la misma noche: se usa la fuente con más tiempo dormido.
        let asleepValues = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        func asleep(_ samples: [HKCategorySample]) -> [HKCategorySample] { samples.filter { asleepValues.contains($0.value) } }
        let bySource = Dictionary(grouping: all, by: \.sourceRevision.source.bundleIdentifier).values
        guard let samples = bySource.max(by: { totalDuration(asleep($0)) < totalDuration(asleep($1)) }) else { return [] }
        func stage(_ value: HKCategoryValueSleepAnalysis) -> [HKCategorySample] { samples.filter { $0.value == value.rawValue } }

        let night = "noche del \(day.formatted(.dateTime.day().locale(locale))) al \(next.formatted(.dateTime.day().month(.wide).locale(locale)))"
        let asleepSamples = asleep(samples)
        guard let bedtime = asleepSamples.first?.startDate, let wake = asleepSamples.map(\.endDate).max() else {
            let inBed = totalDuration(stage(.inBed))
            return inBed > 0 ? ["Sueño (\(night)): \(duration(inBed)) en cama, sin datos de sueño"] : []
        }

        var lines = ["Sueño (\(night)): \(duration(totalDuration(asleepSamples))) dormido, de \(time(bedtime)) a \(time(wake))"]
        let stages: [(String, HKCategoryValueSleepAnalysis)] = [("Profundo", .asleepDeep), ("Ligero", .asleepCore), ("REM", .asleepREM)]
        for (name, value) in stages {
            let seconds = totalDuration(stage(value))
            if seconds > 0 { lines.append("- \(name): \(duration(seconds))") }
        }
        let awake = stage(.awake)
        if !awake.isEmpty {
            let times = awake.count == 1 ? "1 interrupción" : "\(awake.count) interrupciones"
            lines.append("- Despierto: \(duration(totalDuration(awake))) (\(times))")
        }
        return lines
    }

    /// Horas de pie, minutos de atención plena y avisos de pulso.
    private static func events(_ type: ExportType, _ predicate: NSPredicate) async throws -> [String] {
        guard let categoryType = type.sampleType as? HKCategoryType else { return [] }
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: categoryType, predicate: predicate)], sortDescriptors: [])
        let samples = try await descriptor.result(for: Health.store)
        guard !samples.isEmpty else { return [] }
        switch type.id {
        case "appleStandHour":
            return ["\(type.name): \(samples.filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }.count)"]
        case "mindfulSession":
            return ["\(type.name): \(duration(totalDuration(samples)))"]
        default:
            return ["\(type.name): \(samples.count)"]
        }
    }

    // MARK: - Formato

    /// "6,2 km", "97 %", "54 lpm"… (HealthKit guarda los porcentajes de 0 a 1).
    private static func format(_ quantity: HKQuantity, _ type: ExportType, unit: Bool = true) -> String {
        guard let hkUnit = type.unit else { return "" }
        let value = quantity.doubleValue(for: hkUnit) * (hkUnit.unitString == "%" ? 100 : 1)
        let suffix = switch hkUnit.unitString {
        case "count": ""
        case "count/min": type.id == "respiratoryRate" ? "rpm" : "lpm"
        case "mL/min·kg": "ml/kg/min"
        case "degC": "°C"
        case "dBASPL": "dB"
        case let other: other
        }
        let text = number(value, decimals: ["km", "kg", "m", "cm", "m/s", "degC", "mL/min·kg"].contains(hkUnit.unitString) ? 1 : 0)
        return unit && !suffix.isEmpty ? "\(text) \(suffix)" : text
    }

    private static func number(_ value: Double, decimals: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(0...decimals)).locale(locale))
    }

    private static func totalDuration(_ samples: [HKSample]) -> TimeInterval {
        samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(locale))
    }
}
