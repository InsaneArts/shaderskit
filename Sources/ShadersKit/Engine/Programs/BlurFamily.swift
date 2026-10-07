#if canImport(Metal)
import Foundation

/// Gaussian/bokeh/progressive blur family (std/effects/blurs, kit/blur).
/// Register each ported `ComputeProgram` type here.
let blurFamilyPrograms: [ComputeProgram.Type] = [
    FixedBlurProgram.self,
    VariableBlurProgram.self,
    GlowProgram.self,
    FilmStockProgram.self,
    BokehBlurProgram.self,
    CompressionArtifactsProgram.self,
]
#endif
