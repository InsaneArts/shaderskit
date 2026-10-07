import SwiftUI
import ShadersKit
import ImageIO
import UniformTypeIdentifiers

/// A rendered snapshot ready to share.
struct ExportedImage: Identifiable {
    let id = UUID()
    let name: String
    let cgImage: CGImage

    var png: PNGFile? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return PNGFile(data: data as Data, name: name)
    }
}

struct PNGFile: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { "\($0.name).png" }
    }
}

/// JSON text shared as a `.json` file.
struct JSONFile: Transferable {
    let text: String
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { Data($0.text.utf8) }
            .suggestedFileName { "\($0.name).json" }
    }
}

#if !os(tvOS)
struct SnapshotShareSheet: View {
    let image: ExportedImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(decorative: image.cgImage, scale: 2)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 20)
                Text("\(image.cgImage.width) × \(image.cgImage.height) px, rendered with ShaderRenderer.renderImage")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let png = image.png {
                    ShareLink(item: png, preview: SharePreview(image.name, image: Image(decorative: image.cgImage, scale: 2))) {
                        Label("Share PNG", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
            .navigationTitle("Snapshot")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 520)
        #endif
    }
}
#endif
