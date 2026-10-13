import HealthKit

/// Un tipo de dato de Salud que puede ir en el resumen. `id` es la clave con la que se guarda la selección.
struct ExportType: Identifiable {
    let id: String
    let name: String
    let sampleType: HKSampleType
    /// Unidad en la que se muestran los valores (solo tipos de cantidad).
    let unit: HKUnit?
}

enum Catalog {
    static let groups: [(name: String, types: [ExportType])] = [
        ("Actividad", [
            q(.stepCount, "Pasos", .count()),
            q(.distanceWalkingRunning, "Distancia andando/corriendo", .meterUnit(with: .kilo)),
            q(.distanceCycling, "Distancia en bici", .meterUnit(with: .kilo)),
            q(.distanceSwimming, "Distancia nadando", .meterUnit(with: .kilo)),
            q(.activeEnergyBurned, "Energía activa", .kilocalorie()),
            q(.basalEnergyBurned, "Energía en reposo", .kilocalorie()),
            q(.flightsClimbed, "Pisos subidos", .count()),
            q(.appleExerciseTime, "Minutos de ejercicio", .minute()),
            q(.appleStandTime, "Minutos de pie", .minute()),
            q(.appleMoveTime, "Minutos de movimiento", .minute()),
            q(.timeInDaylight, "Tiempo a la luz del día", .minute()),
            c(.appleStandHour, "Horas de pie"),
            ExportType(id: "workouts", name: "Entrenamientos", sampleType: .workoutType(), unit: nil),
        ]),
        ("Corazón", [
            q(.heartRate, "Frecuencia cardiaca", bpm),
            q(.restingHeartRate, "FC en reposo", bpm),
            q(.walkingHeartRateAverage, "FC media andando", bpm),
            q(.heartRateVariabilitySDNN, "Variabilidad (HRV)", .secondUnit(with: .milli)),
            q(.heartRateRecoveryOneMinute, "Recuperación cardiaca", bpm),
            q(.vo2Max, "VO2 máx.", HKUnit(from: "ml/kg*min")),
            c(.highHeartRateEvent, "Avisos de FC alta"),
            c(.lowHeartRateEvent, "Avisos de FC baja"),
            c(.irregularHeartRhythmEvent, "Avisos de ritmo irregular"),
        ]),
        ("Signos vitales", [
            q(.oxygenSaturation, "Oxígeno en sangre", .percent()),
            q(.respiratoryRate, "Frecuencia respiratoria", bpm),
            q(.bodyTemperature, "Temperatura corporal", .degreeCelsius()),
            q(.appleSleepingWristTemperature, "Temperatura de muñeca", .degreeCelsius()),
            q(.bloodPressureSystolic, "Tensión sistólica", .millimeterOfMercury()),
            q(.bloodPressureDiastolic, "Tensión diastólica", .millimeterOfMercury()),
            q(.bloodGlucose, "Glucosa", HKUnit(from: "mg/dL")),
        ]),
        ("Sueño y mente", [
            c(.sleepAnalysis, "Sueño"),
            c(.mindfulSession, "Minutos de atención plena"),
        ]),
        ("Cuerpo", [
            q(.bodyMass, "Peso", .gramUnit(with: .kilo)),
            q(.bodyMassIndex, "IMC", .count()),
            q(.bodyFatPercentage, "Grasa corporal", .percent()),
            q(.leanBodyMass, "Masa magra", .gramUnit(with: .kilo)),
            q(.height, "Altura", .meterUnit(with: .centi)),
            q(.waistCircumference, "Perímetro de cintura", .meterUnit(with: .centi)),
        ]),
        ("Movilidad", [
            q(.walkingSpeed, "Velocidad andando", mps),
            q(.walkingStepLength, "Longitud del paso", .meterUnit(with: .centi)),
            q(.walkingAsymmetryPercentage, "Asimetría al andar", .percent()),
            q(.walkingDoubleSupportPercentage, "Doble apoyo", .percent()),
            q(.appleWalkingSteadiness, "Estabilidad al andar", .percent()),
            q(.sixMinuteWalkTestDistance, "Test 6 minutos", .meter()),
            q(.stairAscentSpeed, "Velocidad subiendo escaleras", mps),
            q(.stairDescentSpeed, "Velocidad bajando escaleras", mps),
            q(.runningSpeed, "Velocidad corriendo", mps),
            q(.runningPower, "Potencia corriendo", .watt()),
            q(.runningStrideLength, "Zancada", .meter()),
            q(.runningVerticalOscillation, "Oscilación vertical", .meterUnit(with: .centi)),
            q(.runningGroundContactTime, "Contacto con el suelo", .secondUnit(with: .milli)),
        ]),
        ("Audición", [
            q(.environmentalAudioExposure, "Ruido ambiental", .decibelAWeightedSoundPressureLevel()),
            q(.headphoneAudioExposure, "Volumen de auriculares", .decibelAWeightedSoundPressureLevel()),
        ]),
        ("Nutrición", [
            q(.dietaryEnergyConsumed, "Energía ingerida", .kilocalorie()),
            q(.dietaryProtein, "Proteína", .gram()),
            q(.dietaryCarbohydrates, "Hidratos", .gram()),
            q(.dietaryFatTotal, "Grasa", .gram()),
            q(.dietarySugar, "Azúcar", .gram()),
            q(.dietaryFiber, "Fibra", .gram()),
            q(.dietaryWater, "Agua", .literUnit(with: .milli)),
            q(.dietaryCaffeine, "Cafeína", .gramUnit(with: .milli)),
        ]),
    ]

    static let all = groups.flatMap(\.types)

    static let defaultEnabled = [
        "stepCount", "distanceWalkingRunning", "activeEnergyBurned", "appleExerciseTime", "workouts",
        "heartRate", "restingHeartRate", "heartRateVariabilitySDNN", "vo2Max",
        "oxygenSaturation", "respiratoryRate", "sleepAnalysis", "bodyMass",
    ]

    static let workoutNames: [HKWorkoutActivityType: String] = [
        .running: "Carrera", .walking: "Caminata", .hiking: "Senderismo", .cycling: "Ciclismo",
        .swimming: "Natación", .rowing: "Remo", .elliptical: "Elíptica", .stairClimbing: "Escaleras",
        .traditionalStrengthTraining: "Fuerza", .functionalStrengthTraining: "Fuerza funcional",
        .highIntensityIntervalTraining: "HIIT", .coreTraining: "Core", .crossTraining: "Entrenamiento cruzado",
        .mixedCardio: "Cardio mixto", .yoga: "Yoga", .pilates: "Pilates", .flexibility: "Flexibilidad",
        .cooldown: "Enfriamiento", .socialDance: "Baile", .cardioDance: "Baile cardio", .golf: "Golf", .tennis: "Tenis",
        .paddleSports: "Kayak/SUP", .pickleball: "Pickleball", .soccer: "Fútbol", .basketball: "Baloncesto",
        .skatingSports: "Patinaje", .snowSports: "Deportes de nieve", .downhillSkiing: "Esquí", .surfingSports: "Surf",
        .waterSports: "Deportes acuáticos", .underwaterDiving: "Buceo", .other: "Otro",
    ]

    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let mps = HKUnit.meter().unitDivided(by: .second())

    private static func q(_ identifier: HKQuantityTypeIdentifier, _ name: String, _ unit: HKUnit) -> ExportType {
        ExportType(id: key(identifier.rawValue, prefix: "HKQuantityTypeIdentifier"), name: name,
                   sampleType: HKQuantityType(identifier), unit: unit)
    }

    private static func c(_ identifier: HKCategoryTypeIdentifier, _ name: String) -> ExportType {
        ExportType(id: key(identifier.rawValue, prefix: "HKCategoryTypeIdentifier"), name: name,
                   sampleType: HKCategoryType(identifier), unit: nil)
    }

    /// "HKQuantityTypeIdentifierStepCount" -> "stepCount", "…VO2Max" -> "vo2Max".
    private static func key(_ raw: String, prefix: String) -> String {
        let name = raw.dropFirst(prefix.count)
        return name.prefix(while: \.isUppercase).lowercased() + name.drop(while: \.isUppercase)
    }
}
