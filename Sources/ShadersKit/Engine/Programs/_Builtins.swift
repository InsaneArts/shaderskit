#if canImport(Metal)
import Foundation

/// Compute programs shipped with ShadersKit, grouped by upstream scaffold family.
/// Each family file owns its own list so ports can land independently.
let builtinPrograms: [ComputeProgram.Type] =
    blurFamilyPrograms
    + sdfFamilyPrograms
    + fluidsFamilyPrograms
    + agentsFamilyPrograms
    + gridFamilyPrograms

/// Media programs (image/video/camera/text sources).
let builtinMediaPrograms: [MediaProgram.Type] =
    [ImageMediaProgram.self]
    + mediaFamilyPrograms
    + gridFamilyMediaPrograms
#endif
