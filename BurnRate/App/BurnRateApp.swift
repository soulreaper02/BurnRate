import SwiftUI

// Rename this file to BurnRateApp.swift in Xcode's file navigator.

@main
struct BurnRateApp: App {
    @State private var appState = AppState()
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView()
                .environment(appState)
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
        .defaultSize(width: 440, height: 340)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}
