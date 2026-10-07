#if canImport(Metal)
import Foundation

/// stable-fluids simulations (std/sim/fluids, scaffolds/fluids).
/// Register each ported `ComputeProgram` type here.
let fluidsFamilyPrograms: [ComputeProgram.Type] = [
    FluidsFamilyProgram.self,
]
#endif
