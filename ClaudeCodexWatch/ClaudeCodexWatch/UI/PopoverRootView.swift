import SwiftUI

struct PopoverRootView: View {
    @Environment(AppState.self) private var appState
    @State private var isRefreshing = false

    private var claudeSnapshot: UsageSnapshot? { appState.poller.latest[.claudeCode] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Claude Code card
            if let snapshot = claudeSnapshot {
                ProviderCardWithHistoryButton(snapshot: snapshot)
            } else {
                placeholderCard
            }

            Divider()

            // Footer
            HStack {
                SettingsLink {
                    Image(systemName: "gear")
                        .accessibilityLabel("Open Settings")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    isRefreshing = true
                    appState.poller.refreshNow()
                    // Brief visual feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                        .foregroundStyle(isRefreshing ? Color.accentColor : .secondary)
                        .accessibilityLabel("Refresh now")
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private var placeholderCard: some View {
        HStack {
            Text("Claude Code")
                .font(.headline)
            Spacer()
            ProgressView()
                .scaleEffect(0.6)
                .accessibilityLabel("Loading Claude Code")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
