#if canImport(Metal)
import Foundation

/// grid / feedback simulations (std/sim/grids, std/sim/feedback, scaffolds/gridKernels, scaffolds/heightField, std/effects/pointerFields, std/effects/fracture).
/// Register each ported `ComputeProgram` type here.
let gridFamilyPrograms: [ComputeProgram.Type] = {
    // PixelThrow is a CPU host-grid sim with no compute flag, so it runs as a media program. The
    // framework's `builtinMediaPrograms` does not list family media programs; register it the
    // first time the compute registry loads (see `gridFamilyMediaPrograms`).
    for t in gridFamilyMediaPrograms { MediaPrograms.register(t) }
    return [
        GridPointerSplatProgram.self,     // GridDistortion
        GridSpringLatticeProgram.self,    // Liquify
        GridWaveFieldProgram.self,        // CursorRipples
        GridReactionDiffusionProgram.self,
        GridPixelSortProgram.self,
        GridDataMoshProgram.self,
        GridTimeTrailProgram.self,
        GridKeyFramesProgram.self,
        GridShatterProgram.self,
        GridSurface3DProgram.self,
    ]
}()

/// Media programs of the grid family. Belongs in `builtinMediaPrograms` (Programs/_Builtins.swift).
let gridFamilyMediaPrograms: [MediaProgram.Type] = [
    GridPixelThrowProgram.self,
]
#endif
