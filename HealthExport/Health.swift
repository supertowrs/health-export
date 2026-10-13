import BackgroundTasks
import HealthKit

enum Health {
    static let store = HKHealthStore()
    static let refreshTaskID = "me.daviddelatorre.healthexport.refresh"
    private static var observer: HKObserverQuery?

    static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: Set(Catalog.all.map { $0.sampleType as HKObjectType }))
            startObserving()
        } catch {
            await Log.add("Error de permisos: \(error.localizedDescription)")
        }
    }

    /// Pide a HealthKit que despierte la app cuando haya datos nuevos de los tipos activados.
    /// Debe llamarse en cada arranque (también los arranques en segundo plano).
    static func startObserving() {
        let config = Config.load()
        let enabled = config.enabledExportTypes

        if let observer { store.stop(observer) }
        observer = nil
        for type in Catalog.all where !enabled.contains(where: { $0.id == type.id }) {
            store.disableBackgroundDelivery(for: type.sampleType) { _, _ in }
        }
        guard !enabled.isEmpty else { return }

        let query = HKObserverQuery(queryDescriptors: enabled.map { HKQueryDescriptor(sampleType: $0.sampleType, predicate: nil) }) { _, _, completion, error in
            Task {
                if error == nil { await Exporter.shared.run(trigger: "healthkit") }
                completion()
            }
        }
        store.execute(query)
        observer = query
        for type in enabled {
            store.enableBackgroundDelivery(for: type.sampleType, frequency: .hourly) { _, _ in }
        }
    }

    /// Respaldo por si HealthKit no despierta la app: refresco en segundo plano de iOS
    /// a la hora del resumen (hoy si aún no se ha enviado, si no mañana).
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        let sendTime = Config.load().sendTime
        let sentToday = (UserDefaults.standard.object(forKey: Key.lastReport) as? Date).map(Calendar.current.isDateInYesterday) ?? false
        request.earliestBeginDate = sentToday ? Calendar.current.date(byAdding: .day, value: 1, to: sendTime) : sendTime
        try? BGTaskScheduler.shared.submit(request)
    }

    #if targetEnvironment(simulator)
    private static let shareTypes: Set<HKSampleType> = [HKQuantityType(.stepCount), HKQuantityType(.heartRate), HKCategoryType(.sleepAnalysis)]

    static func insertSampleData() async {
        let now = Date()
        var samples: [HKSample] = []
        for hour in 1...48 {
            let start = now.addingTimeInterval(Double(-hour) * 3600)
            samples.append(HKQuantitySample(type: HKQuantityType(.stepCount),
                                            quantity: HKQuantity(unit: .count(), doubleValue: .random(in: 100...1500).rounded()),
                                            start: start, end: start.addingTimeInterval(600)))
            samples.append(HKQuantitySample(type: HKQuantityType(.heartRate),
                                            quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: .random(in: 55...120).rounded()),
                                            start: start, end: start))
        }
        // Una noche con fases, de 22:00 de ayer a unas 06:30 de hoy.
        var start = Calendar.current.startOfDay(for: now).addingTimeInterval(-2 * 3600)
        let stages: [(HKCategoryValueSleepAnalysis, Double)] = [
            (.asleepCore, 50), (.asleepDeep, 60), (.asleepCore, 70), (.asleepREM, 30), (.awake, 8),
            (.asleepCore, 80), (.asleepDeep, 30), (.asleepREM, 45), (.awake, 5), (.asleepCore, 40),
        ]
        for (stage, minutes) in stages {
            let end = start.addingTimeInterval(minutes * 60)
            samples.append(HKCategorySample(type: HKCategoryType(.sleepAnalysis), value: stage.rawValue, start: start, end: end))
            start = end
        }
        do {
            // Sustituye los datos de prueba anteriores para que no se acumulen.
            for type in shareTypes {
                _ = try await store.deleteObjects(of: type, predicate: HKQuery.predicateForObjects(from: .default()))
            }
            try await store.save(samples)
            await Log.add("Insertadas \(samples.count) muestras de prueba")
        } catch {
            await Log.add("Error insertando datos: \(error.localizedDescription)")
        }
    }
    #else
    private static let shareTypes: Set<HKSampleType> = []
    #endif
}
