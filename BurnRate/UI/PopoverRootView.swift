import SwiftUI

struct PopoverRootView: View {
    @Environment(AppState.self) private var appState
    @State private var isRefreshing = false

    private var claudeSnapshot: UsageSnapshot? { appState.poller.latest[.claudeCode] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Claude Code card
            if let snapshot = claudeSnapshot {
                ProviderCardView(snapshot: snapshot).cardStyle()
            } else {
                placeholderCard
            }

            // Claude status + recent incidents
            StatusSectionView(monitor: appState.statusMonitor)

            // Footer
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            // Left group: settings + refresh
            HStack(spacing: 2) {
                SettingsLink {
                    Image(systemName: "gear")
                        .footerIconStyle()
                }
                .buttonStyle(.plain)

                Button {
                    isRefreshing = true
                    appState.poller.refreshNow()
                    appState.statusMonitor.fetchNow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isRefreshing = false
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .footerIconStyle()
                        .symbolEffect(.rotate, isActive: isRefreshing)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Refresh now")
            }
            .padding(4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            Spacer()

            // Quit button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                    Text("QUIT")
                        .font(Font.custom("FiraCode-Regular", size: 11))
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.2))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Color(red: 1.0, green: 0.35, blue: 0.2).opacity(0.15),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(red: 1.0, green: 0.35, blue: 0.2).opacity(0.3), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
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

// MARK: - Icon style helper

private extension Image {
    func footerIconStyle() -> some View {
        self
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }
}
