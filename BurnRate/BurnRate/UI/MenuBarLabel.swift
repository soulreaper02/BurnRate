import SwiftUI
import AppKit

struct MenuBarLabel: View {
    let latest: [ProviderID: UsageSnapshot]

    private var percent: Double? { latest[.claudeCode]?.sessionUsedPercent }

    var body: some View {
        Image(nsImage: renderMenuBarImage(percent: percent))
            .accessibilityLabel(percent.map { "BurnRate \(Int($0.rounded()))% session used" } ?? "BurnRate")
    }
}

// MARK: - NSImage renderer

private func renderMenuBarImage(percent: Double?) -> NSImage {
    let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    let menuBarHeight: CGFloat = 18

    // Segment bar config
    let segmentCount = 10
    let segW: CGFloat = 3
    let segH: CGFloat = 12
    let segGap: CGFloat = 2
    let segRadius: CGFloat = 1
    let totalBarWidth = CGFloat(segmentCount) * segW + CGFloat(segmentCount - 1) * segGap

    let textAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.controlTextColor
    ]
    let dimAttrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.controlTextColor.withAlphaComponent(0.45)
    ]

    let appName = NSAttributedString(string: "BurnRate", attributes: textAttrs)
    let gap: CGFloat = 6

    let pctLabel: NSAttributedString
    let barPercent: Double

    if let pct = percent {
        pctLabel = NSAttributedString(string: " \(Int(pct.rounded()))%", attributes: textAttrs)
        barPercent = pct
    } else {
        pctLabel = NSAttributedString(string: " —", attributes: dimAttrs)
        barPercent = 0
    }

    // App icon drawn at menu bar size
    let iconSize: CGFloat = 14
    let iconGap: CGFloat = 4
    let totalWidth = iconSize + iconGap + appName.size().width + gap + pctLabel.size().width + gap + totalBarWidth

    let image = NSImage(size: NSSize(width: totalWidth, height: menuBarHeight), flipped: false) { _ in
        let textY: CGFloat = (menuBarHeight - font.capHeight) / 2 - 1
        var x: CGFloat = 0

        // App icon (same as the app's icon — always in sync)
        let iconY = (menuBarHeight - iconSize) / 2
        NSApp.applicationIconImage.draw(
            in: NSRect(x: x, y: iconY, width: iconSize, height: iconSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )
        x += iconSize + iconGap

        // "BurnRate"
        appName.draw(at: NSPoint(x: x, y: textY))
        x += appName.size().width + gap

        // "31%"
        pctLabel.draw(at: NSPoint(x: x, y: textY))
        x += pctLabel.size().width + gap

        // Segmented bar
        let filledCount = Int((barPercent / 100.0) * Double(segmentCount))
        let barY = (menuBarHeight - segH) / 2
        let activeColor = nsBarColor(barPercent)
        let inactiveColor = activeColor.withAlphaComponent(0.2)

        for i in 0..<segmentCount {
            let segX = x + CGFloat(i) * (segW + segGap)
            let rect = NSRect(x: segX, y: barY, width: segW, height: segH)
            let path = NSBezierPath(roundedRect: rect, xRadius: segRadius, yRadius: segRadius)
            (i < filledCount ? activeColor : inactiveColor).setFill()
            path.fill()
        }

        return true
    }

    image.isTemplate = false
    return image
}

private func nsBarColor(_ pct: Double) -> NSColor {
    if pct >= 95 { return .systemRed }
    if pct >= 80 { return .systemOrange }
    return .systemGreen
}
