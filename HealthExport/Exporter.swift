import HealthKit
import UIKit

/// Envía una vez al día, como texto, el resumen del día anterior.
actor Exporter {
    static let shared = Exporter()

    /// Si el iPhone lleva días sin enviar, se recuperan como mucho estos días (un envío por día).
    private static let maxCatchUpDays = 7

    private var running = false
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return encoder
    }()

    func run(trigger: String) async {
        guard !running else { return }
        running = true
        defer { running = false }

        let config = Config.load()
        var days = [Report.yesterday]
        if trigger != "manual" {
            // Automático: a partir de la hora elegida, con destino configurado y el iPhone
            // desbloqueado (si no, HealthKit no deja leer). Manda los días que falten hasta ayer.
            guard !config.endpoint.isEmpty, Date() >= config.sendTime,
                  await MainActor.run(body: { UIApplication.shared.isProtectedDataAvailable }) else { return }
            days = pendingDays()
        }

        for day in days {
            do {
                let text = try await Report.text(for: day, types: config.enabledExportTypes)
                try await post(text, config: config)
                if trigger != "manual" { UserDefaults.standard.set(day, forKey: Key.lastReport) }
                await Log.add("Enviado resumen del \(day.formatted(.dateTime.day().month(.twoDigits))), \(text.count) caracteres (\(trigger))")
            } catch {
                await Log.add("Error (\(trigger)): \(error.localizedDescription)")
                return
            }
        }
    }

    func sendTest() async {
        do {
            try await post("Prueba de conexión de Health Export. Puedes ignorar este mensaje.", config: .load())
            await Log.add("Prueba de conexión OK")
        } catch {
            await Log.add("Prueba fallida: \(error.localizedDescription)")
        }
    }

    /// Días desde el último resumen enviado hasta ayer (solo ayer si nunca se ha enviado).
    private func pendingDays() -> [Date] {
        let calendar = Calendar.current
        let yesterday = Report.yesterday
        let oldest = calendar.date(byAdding: .day, value: 1 - Self.maxCatchUpDays, to: yesterday)!
        var day = (UserDefaults.standard.object(forKey: Key.lastReport) as? Date)
            .map { max(calendar.date(byAdding: .day, value: 1, to: $0)!, oldest) } ?? yesterday
        var days: [Date] = []
        while day <= yesterday {
            days.append(day)
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return days
    }

    private func post(_ text: String, config: Config) async throws {
        var request = URLRequest(url: try config.url(), timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(["text": text])

        let (body, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ExportError("HTTP \(status) \(String(decoding: body.prefix(200), as: UTF8.self))")
        }
    }
}
