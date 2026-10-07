import SwiftUI
import ShadersKit

/// Curated compositions; tap one for full-screen presentation.
struct ShowcaseView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    private var isActive: Bool { model.section == .showcase && model.presentedPreset == nil && scenePhase == .active }

    private var columns: [GridItem] {
        DeviceClass.isPhone
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(ShowcasePresets.all.count) compositions built only from components that render today. Tap one to present it full screen; swipe or use the arrow keys to move between them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(Array(ShowcasePresets.all.enumerated()), id: \.element.id) { index, preset in
                        Button {
                            withAnimation(.smooth) { model.presentedPreset = index }
                        } label: {
                            PresetCard(preset: preset, isActive: isActive)
                        }
                        .buttonStyle(CardButtonStyle())
                    }
                }
            }
            .padding(.horizontal, DeviceClass.isPhone ? 16 : 24)
            .padding(.bottom, 32)
        }
        .background { AmbientBackground(style: .flow, isPaused: !isActive) }
        .navigationTitle("Showcase")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.smooth) { model.presentedPreset = 0 }
                } label: {
                    Label("Present", systemImage: "play.rectangle")
                }
            }
        }
        #if os(macOS)
        .overlay {
            if model.presentedPreset != nil {
                PresentationView()
                    .transition(.opacity)
            }
        }
        #else
        .fullScreenCover(isPresented: Binding(
            get: { model.presentedPreset != nil },
            set: { if !$0 { model.presentedPreset = nil } }
        )) {
            PresentationView()
        }
        #endif
    }
}

private struct PresetCard: View {
    let preset: ShowcasePreset
    let isActive: Bool
    @Environment(LiveBudget.self) private var budget

    private var key: String { "preset:\(preset.id)" }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PreviewWell()
            SnapshotImage(key: key, nodes: preset.layers, size: CGSize(width: 320, height: 200))
            if isActive, budget.isLive(key) {
                ShaderCanvas(nodes: preset.layers)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Label(preset.title, systemImage: preset.symbol)
                    .font(.title3.weight(.bold))
                Text(preset.subtitle)
                    .font(.caption)
                    .opacity(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .onScreenChange { budget.setVisible(key, $0) }
        .animation(.easeInOut(duration: 0.25), value: budget.isLive(key))
    }
}
