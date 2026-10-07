import SwiftUI
import ShadersKit

struct RoleBadge: View {
    let role: ShaderRole
    var compact = false

    var body: some View {
        Label(role.title, systemImage: role.symbol)
            .labelStyle(BadgeLabelStyle(compact: compact))
            .foregroundStyle(role.tint)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, 3)
            .background(role.tint.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(role.tint.opacity(0.35), lineWidth: 0.5))
            .accessibilityLabel("Role: \(role.title)")
    }
}

struct ComputeBadge: View {
    var compact = false

    var body: some View {
        Label(compact ? "Compute pending" : "Compute port pending", systemImage: "hourglass")
            .labelStyle(BadgeLabelStyle(compact: compact))
            .foregroundStyle(Color.orange)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.4), lineWidth: 0.5))
            .accessibilityLabel("Compute port pending")
    }
}

struct BadgeLabelStyle: LabelStyle {
    var compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
                .lineLimit(1)
        }
        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
    }
}

/// Artwork shown instead of an empty preview (compute-backed, pointer-driven or media components).
struct PlaceholderArt: View {
    let entry: ShaderIndexEntry

    var body: some View {
        ZStack {
            LinearGradient(colors: [entry.role.tint.opacity(0.35), Color.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(entry.role.tint.gradient)
                    .symbolRenderingMode(.hierarchical)
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
    }

    private var symbol: String {
        if entry.hasCompute { return Catalog.symbol(forCategory: entry.categoryName) }
        if entry.needsInteraction { return "hand.draw" }
        if entry.role == .media { return "photo.on.rectangle" }
        return entry.role.symbol
    }

    private var caption: String {
        if entry.hasCompute { return "GPU compute program not ported yet" }
        if entry.needsInteraction { return "Drag on the preview to draw" }
        if entry.role == .media { return "Needs a media source" }
        return "Open to explore"
    }
}
