import SwiftUI

struct ContentView: View {
    @AppStorage(Key.endpoint) private var endpoint = ""
    @AppStorage(Key.authMode) private var authMode = AuthMode.bearer
    @AppStorage(Key.token) private var token = ""
    @AppStorage(Key.username) private var username = ""
    @AppStorage(Key.password) private var password = ""
    @AppStorage(Key.enabledTypes) private var enabledTypes = ""
    @AppStorage(Key.sendHour) private var sendHour = 9
    @AppStorage(Key.log) private var log = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Destino") {
                    TextField("https://mi-bot.example.com/webhook", text: $endpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Autenticación", selection: $authMode) {
                        Text("Ninguna").tag(AuthMode.none)
                        Text("Token (Bearer)").tag(AuthMode.bearer)
                        Text("Básica").tag(AuthMode.basic)
                    }
                    switch authMode {
                    case .none:
                        EmptyView()
                    case .bearer:
                        SecureField("Token", text: $token)
                    case .basic:
                        TextField("Usuario", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Contraseña", text: $password)
                    }
                }

                Section {
                    NavigationLink {
                        TypePicker(selection: $enabledTypes)
                    } label: {
                        LabeledContent("Datos a incluir", value: "\(Config.parseTypes(enabledTypes).count) de \(Catalog.all.count)")
                    }
                    Picker("Hora de envío", selection: $sendHour) {
                        ForEach(5..<24) { Text("\($0):00").tag($0) }
                    }
                    NavigationLink("Ver el resumen de ayer") { ReportPreview() }
                } header: {
                    Text("Resumen diario")
                } footer: {
                    Text("Cada día, a partir de esa hora, se envía como texto el resumen del día anterior y del sueño de esa noche. iOS decide el momento exacto, y los datos de Salud solo se pueden leer con el iPhone desbloqueado.")
                }

                Section {
                    Button("Enviar resumen ahora") { perform { await Exporter.shared.run(trigger: "manual") } }
                    Button("Probar conexión") { perform { await Exporter.shared.sendTest() } }
                    #if targetEnvironment(simulator)
                    Button("Insertar datos de prueba") { perform { await Health.insertSampleData() } }
                    #endif
                } footer: {
                    if busy { ProgressView() }
                }
                .disabled(busy)

                Section("Registro") {
                    Text(log.isEmpty ? "Sin actividad" : log)
                        .font(.caption.monospacedDigit())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Health Export")
        }
        .task { await Health.requestAuthorization() }
        .onChange(of: enabledTypes) { Health.startObserving() }
    }

    private func perform(_ action: @escaping () async -> Void) {
        busy = true
        Task {
            await action()
            busy = false
        }
    }
}

struct TypePicker: View {
    @Binding var selection: String

    var body: some View {
        let enabled = Config.parseTypes(selection)
        List {
            ForEach(Catalog.groups, id: \.name) { group in
                Section(group.name) {
                    ForEach(group.types) { type in
                        Toggle(type.name, isOn: Binding(
                            get: { enabled.contains(type.id) },
                            set: { isOn in
                                var updated = enabled
                                if isOn { updated.insert(type.id) } else { updated.remove(type.id) }
                                selection = updated.sorted().joined(separator: ",")
                            }))
                    }
                }
            }
        }
        .navigationTitle("Datos a incluir")
        .toolbar {
            Menu("Selección") {
                Button("Todos") { selection = Catalog.all.map(\.id).joined(separator: ",") }
                Button("Por defecto") { selection = Catalog.defaultEnabled.joined(separator: ",") }
                Button("Ninguno") { selection = "" }
            }
        }
    }
}

struct ReportPreview: View {
    @State private var text: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let text {
                    Text(text).textSelection(.enabled)
                    Text("\(text.count) caracteres").font(.caption).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Resumen de ayer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                text = try await Report.text(for: Report.yesterday, types: Config.load().enabledExportTypes)
            } catch {
                text = error.localizedDescription
            }
        }
    }
}
