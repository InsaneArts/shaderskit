import SwiftUI
import ShadersKit

/// Live frame statistics measured from `ShaderView.onFrame`.
struct StatsHUD: View {
    let meter: FrameMeter

    var body: some View {
        HStack(spacing: 12) {
            metric(String(format: "%.0f", meter.fps), "fps", tint: fpsTint)
            metric("\(meter.stats.passes)", "passes")
            metric("\(meter.stats.blendPasses)", "blends")
            metric("\(meter.stats.nodes)", "nodes")
            if !meter.stats.compileErrors.isEmpty {
                metric("\(meter.stats.compileErrors.count)", "errors", tint: .red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassSurface(Capsule())
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private var fpsTint: Color {
        switch meter.fps {
        case 55...: return .green
        case 30..<55: return .yellow
        default: return meter.fps == 0 ? .secondary : .red
        }
    }

    private func metric(_ value: String, _ label: String, tint: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Banner for compute-backed components.
struct ComputePendingBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hourglass")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Compute port pending")
                    .font(.subheadline.weight(.semibold))
                Text("This component runs a GPU compute program that is not ported to Metal yet, so it renders transparent. Its props are still editable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: 460)
        .glassSurface(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

#if !os(tvOS)
/// Draggable handles over the preview, one per visible position prop.
struct PositionHandles: View {
    let descriptor: ShaderDescriptor
    @Binding var props: [String: PropValue]

    private var positionProps: [PropDescriptor] {
        let defaults = descriptor.defaultProps
        return descriptor.props.filter { prop in
            if case .position? = PropControl(prop) { return prop.isVisible(in: props, defaults: defaults) }
            return false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(positionProps, id: \.name) { prop in
                let point = (props[prop.name] ?? prop.defaultValue).uvPoint ?? CGPoint(x: 0.5, y: 0.5)
                Handle(label: prop.label)
                    .position(
                        x: min(max(point.x * geo.size.width, 28), geo.size.width - 28),
                        y: min(max(point.y * geo.size.height, 28), geo.size.height - 28)
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("preview"))
                            .onChanged { g in
                                props[prop.name] = .uv(CGPoint(
                                    x: min(max(g.location.x / geo.size.width, 0), 1),
                                    y: min(max(g.location.y / geo.size.height, 0), 1)
                                ))
                            }
                    )
            }
        }
        .coordinateSpace(name: "preview")
    }

    private struct Handle: View {
        let label: String

        var body: some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(.white.opacity(0.25))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .overlay(Circle().fill(.white).frame(width: 6, height: 6))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.45), in: Capsule())
            }
            .offset(y: 10)
            .contentShape(Rectangle().inset(by: -8))
        }
    }
}
#endif
