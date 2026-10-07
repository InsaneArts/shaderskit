#if canImport(Metal)
import Foundation

/// shapedSurface / SDF-field materials family (std/paint/materials, kit/sdf3d, scaffolds/radiance, std/paint/voxels).
/// Register each ported `ComputeProgram` type here.
let sdfFamilyPrograms: [ComputeProgram.Type] = [
    SDFFieldProgram.self,
    SDFIrradianceProgram.self,
    SDFVoxelsProgram.self,
]
#endif
