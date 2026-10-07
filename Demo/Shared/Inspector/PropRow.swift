import SwiftUI
import ShadersKit

/// One inspector row; the control comes from the prop's `ui.types`.
struct PropRow: View {
    let prop: PropDescriptor
    @Binding var value: PropValue
    /// Current values of the other props (stops editor seeds from Color A / Color B).
    let siblings: [String: PropValue]
    let defaults: [String: PropValue]

    var body: some View {
        Group {
            switch PropControl(prop) {
            case .slider(let range, let step)?:
                NumberSlider(title: prop.label, value: numberBinding, range: range, step: step)
            case .color?:
                ColorRow(title: prop.label, css: stringBinding)
            case .select(let options)?:
                SelectRow(title: prop.label, options: options, selection: selectBinding)
            case .toggle?:
                Toggle(prop.label, isOn: boolBinding)
                    .font(.subheadline)
            case .position?:
                PositionRow(title: prop.label, point: pointBinding)
            case .origin?:
                OriginRow(title: prop.label, selection: stringBinding)
            case .stops?:
                StopsEditor(title: prop.label, value: $value, siblings: siblings)
            case .text(let multiline)?:
                TextPropRow(title: prop.label, text: stringBinding, multiline: multiline)
            case .readOnly(let kind)?:
                HStack {
                    Text(prop.label).font(.subheadline)
                    Spacer()
                    Text(summary(kind)).font(.caption).foregroundStyle(.secondary)
                }
            case nil:
                EmptyView()
            }
        }
        .help(prop.description ?? prop.label)
    }

    private func summary(_ kind: String) -> String {
        if case .list(let items) = value { return "\(items.count) items" }
        return kind
    }

    // MARK: bindings

    private var numberBinding: Binding<Double> {
        Binding(
            get: { Double(value.numberValue ?? prop.defaultValue.numberValue ?? 0) },
            set: { value = value.isNull ? .number(Float($0)) : value.withNumber(Float($0)) }
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { value.stringValue ?? prop.defaultValue.stringValue ?? "" },
            set: { value = .string($0) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { value.boolValue ?? false },
            set: { value = .bool($0) }
        )
    }

    private var selectBinding: Binding<String> {
        Binding(
            get: { value.conditionKey },
            set: { new in
                switch prop.defaultValue {
                case .number: value = .number(Float(new) ?? 0)
                case .bool: value = .bool(new == "true")
                default: value = .string(new)
                }
            }
        )
    }

    private var pointBinding: Binding<CGPoint> {
        Binding(
            get: { value.uvPoint ?? prop.defaultValue.uvPoint ?? CGPoint(x: 0.5, y: 0.5) },
            set: { value = .uv($0) }
        )
    }
}

// MARK: - Controls

struct NumberSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                Text(formatted)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            #if os(tvOS)
            HStack(spacing: 16) {
                Button { nudge(-1) } label: { Image(systemName: "minus") }
                ProgressView(value: fraction)
                Button { nudge(1) } label: { Image(systemName: "plus") }
            }
            #else
            Slider(value: sliderBinding, in: range)
            #endif
        }
    }

    private var effectiveStep: Double { step > 0 ? step : (range.upperBound - range.lowerBound) / 100 }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(value, range.lowerBound), range.upperBound) },
            set: { new in
                let snapped = step > 0 ? (new / step).rounded() * step : new
                let clamped = min(max(snapped, range.lowerBound), range.upperBound)
                if clamped != value { value = clamped }
            }
        )
    }

    private var fraction: Double {
        (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private func nudge(_ direction: Double) {
        let span = range.upperBound - range.lowerBound
        let delta = max(effectiveStep, span / 20)
        value = min(max(value + direction * delta, range.lowerBound), range.upperBound)
    }

    private var formatted: String {
        let decimals: Int
        switch step {
        case 1...: decimals = 0
        case 0.1...: decimals = 1
        case 0.01...: decimals = 2
        case 0.001...: decimals = 3
        case 0: decimals = 2
        default: decimals = 4
        }
        return String(format: "%.\(decimals)f", value)
    }
}

struct ColorRow: View {
    let title: String
    @Binding var css: String

    var body: some View {
        #if os(tvOS)
        Picker(title, selection: $css) {
            ForEach(Self.palette, id: \.self) { hex in
                Label(hex, systemImage: "circle.fill")
                    .foregroundStyle(CSSColorBridge.color(hex))
                    .tag(hex)
            }
            if !Self.palette.contains(css) {
                Text(css).tag(css)
            }
        }
        #else
        ColorPicker(selection: colorBinding, supportsOpacity: true) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(CSSColorBridge.hex(css: css))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        #endif
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { CSSColorBridge.color(css) },
            set: { css = CSSColorBridge.hex($0) }
        )
    }

    static let palette = ["#ffffff", "#000000", "#ff3d7f", "#ff8a00", "#ffd166", "#06d6a0", "#1fd1a5", "#4dd6ff", "#3d5afe", "#7c3aed", "#a533f8", "#0f172a", "transparent"]
}

struct SelectRow: View {
    let title: String
    let options: [PropOption]
    @Binding var selection: String

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        } label: {
            Text(title).font(.subheadline)
        }
        #if !os(tvOS)
        .pickerStyle(.menu)
        #endif
    }
}

struct TextPropRow: View {
    let title: String
    @Binding var text: String
    var multiline = false
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
            TextField(title, text: $draft, axis: multiline ? .vertical : .horizontal)
                .font(multiline ? .caption.monospaced() : .body)
                .lineLimit(multiline ? 2...6 : 1...1)
                .focused($focused)
                .onSubmit(commit)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
        }
        .onAppear { draft = text }
        .onChange(of: text) { _, new in if !focused { draft = new } }
        .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
    }

    private func commit() {
        if draft != text { text = draft }
    }
}
