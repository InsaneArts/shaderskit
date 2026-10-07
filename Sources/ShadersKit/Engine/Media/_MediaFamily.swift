#if canImport(Metal)
import Foundation

/// Media source programs (video, camera, text, view capture). Register ported `MediaProgram` types here.
let mediaFamilyPrograms: [MediaProgram.Type] = [
    VideoMediaProgram.self,
    WebcamMediaProgram.self,
    TextMediaProgram.self,
    ViewTextureProgram.self,
    // Per-frame CPU host hooks of fragment-only shaders (extraFields / data textures).
    AsciiHostProgram.self,
    ChromaFlowHostProgram.self,
    CursorTrailHostProgram.self,
]
#endif
