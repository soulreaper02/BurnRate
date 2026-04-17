import SwiftUI
import ServiceManagement
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "SettingsView")

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 280)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        logger.error("SMAppService error: \(error)")
                    }
                }
                .accessibilityLabel("Launch BurnRate at login")

            Section {
                Text("Usage data is read directly from ~/.claude/projects — no hook or configuration needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notifications

private struct NotificationsTab: View {
    var body: some View {
        Form {
            Section("Claude Code") {
                NotifToggle(provider: .claudeCode, metric: "session", threshold: 80, label: "Session at 80%")
                NotifToggle(provider: .claudeCode, metric: "session", threshold: 95, label: "Session at 95%")
                NotifToggle(provider: .claudeCode, metric: "reset", threshold: 0, label: "Window reset (off by default)")
            }
        }
        .formStyle(.grouped)
    }
}

private struct NotifToggle: View {
    let provider: ProviderID
    let metric: String
    let threshold: Int
    let label: String

    private var key: String {
        threshold == 0
            ? "notify.\(provider.rawValue).\(metric).enabled"
            : "notify.\(provider.rawValue).\(metric).\(threshold).enabled"
    }

    @State private var isOn = true

    var body: some View {
        Toggle(label, isOn: $isOn)
            .onAppear {
                let stored = UserDefaults.standard.object(forKey: key)
                isOn = stored == nil ? metric != "reset" : UserDefaults.standard.bool(forKey: key)
            }
            .onChange(of: isOn) { _, v in UserDefaults.standard.set(v, forKey: key) }
            .accessibilityLabel("Enable notification: \(label)")
    }
}

// MARK: - About

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text("BurnRate")
                .font(.title2.bold())
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .foregroundStyle(.secondary)
            Text("All data stays on-device. No telemetry. No network calls.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
