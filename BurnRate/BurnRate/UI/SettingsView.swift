import SwiftUI
import ServiceManagement
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "SettingsView")

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            ClaudeCodeTab()
                .tabItem { Label("Claude Code", systemImage: "terminal") }

            CodexTab()
                .tabItem { Label("Codex", systemImage: "cpu") }

            NotificationsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
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
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Claude Code

private struct ClaudeCodeTab: View {
    @State private var installer = HookInstaller()
    @State private var currentConfig: StatuslineConfig?
    @State private var actionMessage: String?
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Form {
            Section("Statusline Hook") {
                if let config = currentConfig {
                    LabeledContent("Current command") {
                        Text(config.command)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text("Hook not installed")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Reinstall Hook") {
                        do {
                            try installer.install(mode: currentConfig.map { .chain(existing: $0.command) } ?? .fresh)
                            actionMessage = "Hook reinstalled successfully."
                            refresh()
                        } catch {
                            actionMessage = "Error: \(error.localizedDescription)"
                        }
                    }
                    .accessibilityLabel("Reinstall the Claude Code statusline hook")

                    if currentConfig != nil {
                        Button("Uninstall Hook", role: .destructive) {
                            do {
                                try installer.uninstall()
                                actionMessage = "Hook uninstalled."
                                refresh()
                            } catch {
                                actionMessage = "Error: \(error.localizedDescription)"
                            }
                        }
                        .accessibilityLabel("Uninstall the Claude Code statusline hook")
                    }
                }

                if let msg = actionMessage {
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Re-run Setup Wizard") {
                    onboardingComplete = false
                }
                .accessibilityLabel("Re-run the onboarding setup wizard")
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh() }
    }

    private func refresh() {
        currentConfig = installer.currentStatuslineConfig()
    }
}

// MARK: - Codex

private struct CodexTab: View {
    @AppStorage("codex.customWeeklyTokenCap") private var customWeeklyCap = 0

    var body: some View {
        Form {
            Section("Plan") {
                Text("Plan tier is detected automatically from your Codex session files.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Custom Token Cap (optional)") {
                TextField("Weekly token cap (0 = auto)", value: $customWeeklyCap, format: .number)
                    .accessibilityLabel("Custom weekly token cap for Codex")
                Text("If set, overrides the auto-detected percentage. Enter 0 to use Codex's reported value.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Notifications

private struct NotificationsTab: View {
    var body: some View {
        Form {
            ForEach(ProviderID.allCases) { provider in
                let name = provider == .claudeCode ? "Claude Code" : "Codex CLI"
                Section(name) {
                    if provider == .claudeCode {
                        NotifToggle(provider: provider, metric: "session", threshold: 80, label: "Session at 80%")
                        NotifToggle(provider: provider, metric: "session", threshold: 95, label: "Session at 95%")
                    }
                    NotifToggle(provider: provider, metric: "weekly", threshold: 80, label: "Weekly at 80%")
                    NotifToggle(provider: provider, metric: "weekly", threshold: 95, label: "Weekly at 95%")
                    NotifToggle(provider: provider, metric: "reset", threshold: 0, label: "Window reset (off by default)")
                }
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
