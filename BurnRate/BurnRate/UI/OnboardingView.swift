import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var step = 0
    @State private var installer = HookInstaller()
    @State private var installMode: InstallMode = .fresh
    @State private var installError: String?
    @State private var installed = false
    @State private var showDiff = false
    @State private var diffBefore = ""
    @State private var diffAfter = ""

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<5) { i in
                    Circle()
                        .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Step \(i + 1)\(i == step ? " (current)" : "")")
                }
            }
            .padding(.top, 20)

            Divider().padding(.vertical, 12)

            Group {
                switch step {
                case 0: stepWelcome
                case 1: stepClaudeCode
                case 2: stepCodex
                case 3: stepNotifications
                default: stepDone
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)

            Divider().padding(.vertical, 12)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Go back")
                }
                Spacer()
                if step < 4 {
                    Button(step == 1 && !installed ? "Skip" : "Next") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(step == 1 && !installed ? "Skip hook installation" : "Next step")
                } else {
                    Button("Get Started") {
                        onboardingComplete = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Finish onboarding")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 480, height: 400)
    }

    // MARK: - Steps

    private var stepWelcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Welcome to BurnRate")
                .font(.title2.bold())
            Text("A menu bar app that tracks your Claude Code and Codex CLI usage, rate limits, and session state — all locally, no telemetry.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }

    private var stepClaudeCode: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Code setup")
                .font(.title3.bold())
            Text("We'll install a statusline hook that sends usage data to this app whenever Claude Code is running. Your existing settings.json will be backed up first.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let existing = installer.currentStatuslineConfig() {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Existing statusline detected", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                    Text("Current command: `\(existing.command)`")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Picker("Action", selection: Binding(
                        get: {
                            if case .chain = installMode { return 1 }
                            return 0
                        },
                        set: { v in installMode = v == 0 ? .replace : .chain(existing: existing.command) }
                    )) {
                        Text("Replace").tag(0)
                        Text("Chain (run both)").tag(1)
                    }
                    .pickerStyle(.radioGroup)
                    .accessibilityLabel("Choose how to handle existing statusline")
                }
                .padding(10)
                .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            if installed {
                Label("Hook installed successfully", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Button("Preview changes…") {
                        let diff = installer.previewDiff(mode: installMode)
                        diffBefore = diff.before
                        diffAfter = diff.after
                        showDiff = true
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Preview diff before installing")

                    Button("Install Hook") {
                        do {
                            try installer.install(mode: installMode)
                            installed = true
                            installError = nil
                        } catch {
                            installError = error.localizedDescription
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Install Claude Code statusline hook")

                    if let err = installError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showDiff) {
            DiffPreviewSheet(before: diffBefore, after: diffAfter)
        }
    }

    private var stepCodex: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Codex CLI")
                .font(.title3.bold())
            Text("BurnRate reads your Codex session files from `~/.codex/sessions/` to estimate weekly usage. No configuration needed.")
                .font(.body)
                .foregroundStyle(.secondary)

            Label("Codex sessions found at ~/.codex/sessions/", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text("The Codex card will show your weekly rate limit percentage as reported in your session files.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var stepNotifications: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notifications")
                .font(.title3.bold())
            Text("BurnRate can notify you when you're approaching rate limits (80% and 95% thresholds).")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("You've already been asked for notification permission when the app launched. You can adjust per-provider settings later in Settings → Notifications.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var stepDone: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("You're all set!")
                .font(.title2.bold())
            Text("Open Claude Code and run any command — you should see live data in the menu bar within 10 seconds.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Diff preview sheet

private struct DiffPreviewSheet: View {
    let before: String
    let after: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Changes to settings.json")
                .font(.headline)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Before").font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        Text(before)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                VStack(alignment: .leading) {
                    Text("After").font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        Text(after)
                            .font(.caption.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Close diff preview")
            }
        }
        .padding(20)
        .frame(width: 600, height: 400)
    }
}
