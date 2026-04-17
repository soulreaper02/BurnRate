import SwiftUI

struct OnboardingView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
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
                case 1: stepNotifications
                default: stepDone
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)

            Divider().padding(.vertical, 12)

            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Go back")
                }
                Spacer()
                if step < 2 {
                    Button("Next") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Next step")
                } else {
                    Button("Get Started") { onboardingComplete = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Finish onboarding")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 440, height: 340)
    }

    private var stepWelcome: some View {
        VStack(spacing: 16) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("Welcome to BurnRate")
                .font(.title2.bold())
            Text("A menu bar app that tracks your Claude Code usage, costs, and rate limits — all locally from your ~/.claude/projects history. No configuration needed.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }

    private var stepNotifications: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notifications")
                .font(.title3.bold())
            Text("BurnRate can notify you when you're approaching rate limits (80% and 95% thresholds).")
                .font(.body)
                .foregroundStyle(.secondary)
            Text("You can adjust notification settings anytime in Settings → Notifications.")
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
            Text("BurnRate reads your session data automatically. Usage and costs will appear in the menu bar within a few seconds.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
}
