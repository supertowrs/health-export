import SwiftUI

@main
struct HealthExportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Config.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Health.scheduleRefresh() }
        }
        .backgroundTask(.appRefresh(Health.refreshTaskID)) {
            Health.scheduleRefresh()
            await Exporter.shared.run(trigger: "background")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Health.startObserving()
        return true
    }
}
