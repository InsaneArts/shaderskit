import SwiftUI
import ShadersKit

/// Gallery card: live preview while on screen and within the live-view budget, cached
/// snapshot otherwise.
struct ShaderCard: View {
    let entry: ShaderIndexEntry
    /// False when the gallery is covered (detail pushed, other tab, app inactive).
    var isActive: Bool
    var previewAspect: CGFloat = 4.0 / 3.0

    @Environment(LiveBudget.self) private var budget
    @State private var thumbnail: Thumbnail?
    @State private var loaded = false

    private var nodes: [ShaderNode] { PreviewFactory.nodes(for: entry) }
    private var isBlank: Bool { loaded && (thumbnail?.isBlank ?? true) }
    private var isLive: Bool { isActive && !isBlank && thumbnail != nil && budget.isLive(entry.name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            preview
                .aspectRatio(previewAspect, contentMode: .fit)
                .clipped()
            footer
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onScreenChange { budget.setVisible(entry.name, $0) }
        .task(id: entry.name) {
            var result = await ThumbnailRenderer.shared.thumbnail(key: "card:\(entry.name)", nodes: nodes, size: CGSize(width: 240, height: 180))
            // media loads asynchronously: render once more after the source arrives
            if result?.isBlank == true, entry.role == .media, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                result = await ThumbnailRenderer.shared.thumbnail(key: "card-retry:\(entry.name)", nodes: nodes, size: CGSize(width: 240, height: 180)) ?? result
            }
            guard !Task.isCancelled else { return }
            thumbnail = result
            loaded = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(entry.description)
    }

    private var preview: some View {
        ZStack {
            PreviewWell()
            if isBlank {
                PlaceholderArt(entry: entry)
            } else if let thumbnail {
                Image(decorative: thumbnail.image, scale: 2)
                    .resizable()
                    .scaledToFill()
                if isLive {
                    ShaderCanvas(nodes: nodes, onFrame: PerfLog.onFrame(entry.name))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topLeading) {
            if entry.hasCompute {
                ComputeBadge(compact: true)
                    .padding(8)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLive)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
            }
            Text(entry.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
            RoleBadge(role: entry.role, compact: true)
        }
        .padding(12)
    }
}

/// Dark well behind previews (shaders render into a transparent canvas).
struct PreviewWell: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)
            RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .center, startRadius: 0, endRadius: 220)
        }
    }
}
