import SwiftUI
import SwiftData
import OSLog

private let appLogger = Logger(subsystem: "com.amitkumar.burnrate", category: "App")

@main
struct BurnRateApp: App {
    private let sharedContainer: ModelContainer
    @State private var appState: AppState
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    init() {
        // Create container synchronously so AppState can start writing history immediately
        let container: ModelContainer
        do {
            container = try ModelContainer(for: HistoryPoint.self)
        } catch {
            appLogger.critical("SwiftData init failed: \(error)")
            fatalError("Cannot create SwiftData container: \(error)")
        }
        self.sharedContainer = container

        let state = AppState()
        state.configureStore(modelContext: container.mainContext)
        self._appState = State(initialValue: state)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView()
                .environment(appState)
                .modelContainer(sharedContainer)
                .onAppear {
                    if !onboardingComplete {
                        NSApp.activate(ignoringOtherApps: true)
                        NSApp.windows.first(where: { $0.title == "Setup" })?.makeKeyAndOrderFront(nil)
                    }
                }
        } label: {
            MenuBarLabel(latest: appState.poller.latest)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Setup", id: "onboarding") {
            OnboardingView()
        }
        .defaultSize(width: 480, height: 400)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
