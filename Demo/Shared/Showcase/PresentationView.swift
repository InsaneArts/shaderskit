import SwiftUI
import ShadersKit

/// Full-screen presentation of the showcase presets with swipe, arrow-key and remote navigation.
struct PresentationView: View {
    @Environment(AppModel.self) private var model
    @State private var direction: Edge = .trailing
    @State private var chromeVisible = true
    @State private var autoplay = false
    @State private var lastInteraction = Date()
    @State private var showCode = false
    @FocusState private var focused: Bool

    private var presets: [ShowcasePreset] { ShowcasePresets.all }
    private var index: Int { min(max(model.presentedPreset ?? 0, 0), presets.count - 1) }
    private var preset: ShowcasePreset { presets[index] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ShaderCanvas(nodes: preset.layers)
                .id(preset.id)
                .transition(.asymmetric(
                    insertion: .move(edge: direction).combined(with: .opacity),
                    removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                ))
                .ignoresSafeArea()
            if chromeVisible {
                chrome
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { chromeVisible.toggle() } }
        #if os(iOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { g in
                    if g.translation.width < -60 { step(1) } else if g.translation.width > 60 { step(-1) }
                }
        )
        .statusBarHidden(!chromeVisible)
        .persistentSystemOverlays(chromeVisible ? .automatic : .hidden)
        #endif
        #if os(tvOS)
        .onMoveCommand { direction in
            switch direction {
            case .left: step(-1)
            case .right: step(1)
            default: withAnimation { chromeVisible.toggle() }
            }
        }
        .onExitCommand { close() }
        #else
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onKeyPress(.leftArrow) { step(-1); return .handled }
        .onKeyPress(.rightArrow) { step(1); return .handled }
        .onKeyPress(.space) { step(1); return .handled }
        .onKeyPress(.escape) { close(); return .handled }
        #endif
        .onAppear { focused = true }
        .task(id: autoplay) {
            guard autoplay else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                if Task.isCancelled { break }
                step(1)
            }
        }
        .sheet(isPresented: $showCode) {
            CodeExportSheet(title: preset.title.replacingOccurrences(of: " ", with: ""), code: CodeExporter.swift(for: preset.layers), promptNodes: preset.layers)
        }
        .impactHaptic(trigger: index)
    }

    private var chrome: some View {
        VStack {
            HStack(spacing: 12) {
                roundButton("xmark", label: "Close", action: close)
                Spacer()
                roundButton(autoplay ? "pause.fill" : "play.fill", label: autoplay ? "Pause" : "Autoplay") { autoplay.toggle() }
                roundButton("chevron.left.forwardslash.chevron.right", label: "Show Code") { showCode = true }
                roundButton("square.3.layers.3d", label: "Open in Playground") {
                    model.playground.load(preset)
                    close()
                    model.section = .playground
                }
            }
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(index + 1) / \(presets.count)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .opacity(0.7)
                    Label(preset.title, systemImage: preset.symbol)
                        .font(.title.weight(.bold))
                    Text(preset.subtitle)
                        .font(.subheadline)
                        .opacity(0.8)
                    HStack(spacing: 6) {
                        ForEach(presets.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? Color.white : Color.white.opacity(0.35))
                                .frame(width: i == index ? 18 : 6, height: 6)
                        }
                    }
                    .padding(.top, 4)
                    .animation(.snappy, value: index)
                }
                .padding(18)
                .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Spacer()
                HStack(spacing: 12) {
                    roundButton("chevron.left", label: "Previous") { step(-1) }
                    roundButton("chevron.right", label: "Next") { step(1) }
                }
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(20)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 46, height: 46)
                .glassSurface(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ delta: Int) {
        direction = delta > 0 ? .trailing : .leading
        withAnimation(.smooth(duration: 0.5)) {
            model.presentedPreset = (index + delta + presets.count) % presets.count
        }
    }

    private func close() {
        withAnimation(.smooth) { model.presentedPreset = nil }
    }
}
