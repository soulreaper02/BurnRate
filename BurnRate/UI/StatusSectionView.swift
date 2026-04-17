import SwiftUI

struct StatusSectionView: View {
    let monitor: StatusMonitor

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusHeader

            if !monitor.incidents.isEmpty {
                Divider().padding(.vertical, 8)
                carousel
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: monitor.incidents.count) {
            currentIndex = 0
        }
    }

    // MARK: - Header

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)

            Text("Claude Status")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Text(monitor.statusDescription)
                .font(Font.custom("FiraCode-Regular", size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack(spacing: 8) {
            // Incident slide
            incidentCard(monitor.incidents[currentIndex])
                .id(currentIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: dragOffset < 0 ? .trailing : .leading).combined(with: .opacity),
                    removal:   .move(edge: dragOffset < 0 ? .leading  : .trailing).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: currentIndex)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { dragOffset = $0.translation.width }
                        .onEnded { value in
                            dragOffset = value.translation.width
                            if value.translation.width < -30 {
                                advance(by: +1)
                            } else if value.translation.width > 30 {
                                advance(by: -1)
                            }
                            dragOffset = 0
                        }
                )

            // Page dots + nav arrows
            HStack(spacing: 8) {
                Button { advance(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(currentIndex == 0 ? Color.secondary.opacity(0.3) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex == 0)

                HStack(spacing: 4) {
                    ForEach(0..<monitor.incidents.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Color.primary : Color.secondary.opacity(0.35))
                            .frame(width: i == currentIndex ? 5 : 4, height: i == currentIndex ? 5 : 4)
                            .animation(.easeInOut(duration: 0.2), value: currentIndex)
                    }
                }

                Button { advance(by: +1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(currentIndex == monitor.incidents.count - 1 ? Color.secondary.opacity(0.3) : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex == monitor.incidents.count - 1)

                Spacer()

                Text("\(currentIndex + 1) / \(monitor.incidents.count)")
                    .font(Font.custom("FiraCode-Regular", size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func incidentCard(_ incident: ClaudeIncident) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(impactColor(incident.impact))
                    .frame(width: 5, height: 5)
                    .padding(.top, 2)

                Text(incident.name)
                    .font(Font.custom("FiraCode-Regular", size: 11))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Text(incident.status)
                    .font(Font.custom("FiraCode-Regular", size: 10))
                    .foregroundStyle(statusBadgeColor(incident.status))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusBadgeColor(incident.status).opacity(0.12), in: Capsule())
            }

            if let update = incident.latestUpdate {
                Text(update.body)
                    .font(Font.custom("FiraCode-Regular", size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .padding(.leading, 11)
            }

            Text(incident.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))
                .font(Font.custom("FiraCode-Regular", size: 10))
                .foregroundStyle(.tertiary)
                .padding(.leading, 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func advance(by delta: Int) {
        let next = currentIndex + delta
        guard next >= 0 && next < monitor.incidents.count else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = next
        }
    }

    private var indicatorColor: Color {
        switch monitor.indicator {
        case .none:     return .green
        case .minor:    return .yellow
        case .major:    return .orange
        case .critical: return .red
        case .unknown:  return .secondary
        }
    }

    private func impactColor(_ impact: String) -> Color {
        switch impact {
        case "none":     return .green
        case "minor":    return .yellow
        case "major":    return .orange
        case "critical": return .red
        default:         return .secondary
        }
    }

    private func statusBadgeColor(_ status: String) -> Color {
        switch status {
        case "resolved":   return .green
        case "monitoring": return .blue
        default:           return .orange
        }
    }
}
