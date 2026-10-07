import SwiftUI
import ShadersKit

/// 2D pad for a position prop (UV space, top-left origin).
struct PositionRow: View {
    let title: String
    @Binding var point: CGPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "x %.2f  y %.2f", point.x, point.y))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            #if os(tvOS)
            NumberSlider(title: "X", value: axis(\.x), range: 0...1, step: 0.01)
            NumberSlider(title: "Y", value: axis(\.y), range: 0...1, step: 0.01)
            #else
            PositionPad(point: $point)
                .frame(height: 110)
            #endif
        }
    }

    private func axis(_ keyPath: WritableKeyPath<CGPoint, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(point[keyPath: keyPath]) },
            set: { point[keyPath: keyPath] = CGFloat($0) }
        )
    }
}

#if !os(tvOS)
struct PositionPad: View {
    @Binding var point: CGPoint

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                Path { path in
                    for i in 1..<4 {
                        let x = size.width * CGFloat(i) / 4
                        let y = size.height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .position(x: point.x * size.width, y: point.y * size.height)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        point = CGPoint(
                            x: min(max(g.location.x / size.width, 0), 1),
                            y: min(max(g.location.y / size.height, 0), 1)
                        )
                    }
            )
        }
    }
}
#endif

/// 3×3 anchor picker for `origin` props.
struct OriginRow: View {
    let title: String
    @Binding var selection: String

    private let rows: [[ShaderOrigin]] = [
        [.topLeft, .top, .topRight],
        [.left, .center, .right],
        [.bottomLeft, .bottom, .bottomRight],
    ]

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline)
            Spacer()
            VStack(spacing: 4) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(row, id: \.self) { origin in
                            Button {
                                selection = origin.rawValue
                            } label: {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selection == origin.rawValue ? Color.accentColor : Color.primary.opacity(0.12))
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(origin.rawValue)
                        }
                    }
                }
            }
        }
    }
}

/// Editor for `gradient-stops`: null means "use Color A / Color B".
struct StopsEditor: View {
    let title: String
    @Binding var value: PropValue
    let siblings: [String: PropValue]

    private var stops: [ColorStop] {
        if case .colorStops(let s) = value { return s.sorted { $0.position < $1.position } }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                if !stops.isEmpty {
                    Button("Use Color A / B") { value = .null }
                        .font(.caption)
                }
            }
            if stops.isEmpty {
                Button {
                    value = .colorStops(seedStops())
                } label: {
                    Label("Customize Stops", systemImage: "slider.horizontal.below.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .glassButtonStyle()
            } else {
                LinearGradient(stops: stops.map { Gradient.Stop(color: CSSColorBridge.color($0.color), location: CGFloat($0.position)) }, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 18)
                    .clipShape(Capsule())
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    HStack(spacing: 10) {
                        ColorRow(title: "", css: Binding(
                            get: { stop.color },
                            set: { new in mutate(index) { $0.color = new } }
                        ))
                        .labelsHidden()
                        .frame(width: 44)
                        NumberSlider(title: "Stop \(index + 1)", value: Binding(
                            get: { Double(stop.position) },
                            set: { new in mutate(index) { $0.position = Float(new) } }
                        ), range: 0...1, step: 0.01)
                        Button {
                            var s = stops
                            s.remove(at: index)
                            value = s.isEmpty ? .null : .colorStops(s)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(stops.count <= 2)
                    }
                }
                if stops.count < ColorStops.maxStops {
                    Button {
                        var s = stops
                        let last = s.last?.color ?? "#ffffff"
                        s.append(ColorStop(color: last, position: 1))
                        if s.count > 1 {
                            for i in s.indices { s[i].position = Float(i) / Float(s.count - 1) }
                        }
                        value = .colorStops(s)
                    } label: {
                        Label("Add Stop", systemImage: "plus")
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func mutate(_ index: Int, _ body: (inout ColorStop) -> Void) {
        var s = stops
        guard s.indices.contains(index) else { return }
        body(&s[index])
        value = .colorStops(s)
    }

    private func seedStops() -> [ColorStop] {
        let a = siblings["colorA"]?.stringValue ?? "#7c3aed"
        let b = siblings["colorB"]?.stringValue ?? "#ffd166"
        return [ColorStop(color: a, position: 0), ColorStop(color: "#ff3d7f", position: 0.5), ColorStop(color: b, position: 1)]
    }
}
