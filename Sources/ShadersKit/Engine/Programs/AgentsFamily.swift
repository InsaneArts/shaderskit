#if canImport(Metal)
import Foundation

/// agent/particle systems (std/sim/agents, scaffolds/agentSystem).
/// Register each ported `ComputeProgram` type here.
let agentsFamilyPrograms: [ComputeProgram.Type] = [
    AgentSystemProgram.self,
]
#endif
