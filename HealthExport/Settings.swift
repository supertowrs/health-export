import Foundation

enum Key {
    static let endpoint = "endpoint"
    static let authMode = "authMode"
    static let token = "token"
    static let username = "username"
    static let password = "password"
    static let enabledTypes = "enabledTypes"
    static let sendHour = "sendHour"
    static let lastReport = "lastReport"
    static let log = "log"
}

enum AuthMode: String, CaseIterable, Identifiable {
    case none, bearer, basic
    var id: Self { self }
}

struct ExportError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// Instantánea de los ajustes guardados en UserDefaults (la UI los edita con @AppStorage).
struct Config {
    let endpoint: String
    let authMode: AuthMode
    let token: String
    let username: String
    let password: String
    let enabledTypes: Set<String>
    let sendHour: Int

    static func load() -> Config {
        let d = UserDefaults.standard
        return Config(
            endpoint: d.string(forKey: Key.endpoint) ?? "",
            authMode: AuthMode(rawValue: d.string(forKey: Key.authMode) ?? "") ?? AuthMode.none,
            token: d.string(forKey: Key.token) ?? "",
            username: d.string(forKey: Key.username) ?? "",
            password: d.string(forKey: Key.password) ?? "",
            enabledTypes: parseTypes(d.string(forKey: Key.enabledTypes) ?? ""),
            sendHour: d.integer(forKey: Key.sendHour))
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.authMode: AuthMode.bearer.rawValue,
            Key.enabledTypes: Catalog.defaultEnabled.joined(separator: ","),
            Key.sendHour: 9,
        ])
    }

    static func parseTypes(_ value: String) -> Set<String> {
        Set(value.split(separator: ",").map(String.init))
    }

    var enabledExportTypes: [ExportType] {
        Catalog.all.filter { enabledTypes.contains($0.id) }
    }

    /// Hora de hoy a partir de la cual se envía el resumen automático.
    var sendTime: Date {
        Calendar.current.date(bySettingHour: sendHour, minute: 0, second: 0, of: Date())!
    }

    func url() throws -> URL {
        let text = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()) else {
            throw ExportError("Configura una URL http(s) válida")
        }
        return url
    }

    var authorization: String? {
        switch authMode {
        case .none: nil
        case .bearer: "Bearer \(token)"
        case .basic: "Basic " + Data("\(username):\(password)".utf8).base64EncodedString()
        }
    }
}

@MainActor
enum Log {
    static func add(_ message: String) {
        let line = "\(Date().formatted(.dateTime.day().month(.twoDigits).hour().minute()))  \(message)"
        let previous = (UserDefaults.standard.string(forKey: Key.log) ?? "").split(separator: "\n").map(String.init)
        UserDefaults.standard.set(([line] + previous).prefix(50).joined(separator: "\n"), forKey: Key.log)
    }
}
