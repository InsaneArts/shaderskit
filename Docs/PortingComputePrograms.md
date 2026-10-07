# Porting compute-backed shaders

ShadersKit transpiles every upstream WGSL pass and compute kernel to Metal automatically. What it
cannot generate is the CPU-side orchestration that upstream writes in TypeScript inside each
shader's `compute` hook: which textures and buffers exist, what is written into the small
per-kernel uniform structs each frame, which kernels run in which order, ping-pong swaps, and the
per-frame math (spring physics, pointer handling, radius → sigma, …). Those hooks are ported by
hand as `ComputeProgram` types. This document is the contract.

## Where things are

| What | Where |
|---|---|
| Framework | `Sources/ShadersKit/Engine/ComputeProgram.swift` (`ComputeProgram`, `ComputeContext`, `ComputeOutputs`, helpers) |
| Reference port | `Sources/ShadersKit/Engine/Programs/FixedBlurProgram.swift` (upstream `withFixedBlurCompute`) |
| Registration | `Sources/ShadersKit/Engine/Programs/<Family>Family.swift` — add your type to the family array |
| Generated kernels (MSL) | `Sources/ShadersKit/Resources/MSL/<Shader>.metal`, entries `<Shader>_k<N>` |
| Kernel metadata | `Sources/ShadersKit/Resources/Descriptors/<Shader>.json` → `compute` (see below) |
| Upstream TypeScript | the shader's `index.ts`, its std module (`std/sim/*`, `std/effects/blurs.ts`, `std/paint/materials.ts`, …) and the scaffold (`gpu/scaffolds/*`, `gpu/kit/*`) |
| Dumped kernel WGSL + recorded resource graph | the dump JSON used to generate the package (`variants[0].recorded`) |

## Descriptor `compute` block

```json
"compute": {
  "kernels": [{ "index": 0, "dims": 2, "entry": "Blur_k0", "sizeSlot": 2,
                "buffers": [{"name": "weights", "slot": 0, "space": "storage", "type": "array<f32, 49>"},
                            {"name": "params", "slot": 1, "space": "uniform", "type": "item"}],
                "textures": [{"name": "input", "slot": 0, "type": "texture_2d<f32>"},
                             {"name": "intermediate", "slot": 1, "type": "texture_storage_2d<rgba16float, write>"}] }],
  "uniformLayouts": { "params": { "size": 16, "fields": [{"path": "activeHalf", "offset": 0, "type": "i32", "size": 4}, ...] } },
  "textures":  [{ "id": "tex_2", "width": 1024, "height": 640, "format": "rgba16float" }],
  "buffers":   [{ "id": "buf_4", "type": "array<f32, 49>", "count": 49, "element": "f32" }],
  "uniforms":  [{ "id": "uni_6", "fields": ["activeHalf", "inputWidth", "inputHeight"] }],
  "bindGroups": [{ "id": "bg_9", "entries": {"input": "object", "intermediate": "tex_2", "weights": "buf_4", "params": "uni_6"} }],
  "kernelBindGroups": [{ "index": 0, "bindGroups": ["bg_9"] }],
  "rttInputKeys": ["rtt_0"]
}
```

* `kernels[i].entry` is the Metal kernel function. Bind resources by **name** through the slots
  (`kernel.texture("input")!.slot`, `kernel.buffer("weights")!.slot`). The dispatch size goes in
  `sizeSlot` (the framework's `ComputeContext.dispatch` does this and applies the upstream bounds
  guard).
* Upstream names a resource once per kernel; when two kernels use the same name with different
  types the second is suffixed (`params`, `params_2`). The recorded `bindGroups` tell you which
  recorded texture/buffer each kernel binding received upstream; `textures`/`buffers` give their
  sizes, formats and element types.
* `"object"` in a bind-group entry means an RTT texture (the composed child). In ShadersKit that is
  `context.rttTextures["rtt_0"]` (premultiplied, like upstream) or `context.childTexture`.
* Kernel uniform structs are written with `context.pack(layout, values, into: buffer)` using the
  WGSL offsets from `uniformLayouts`.

## Lifecycle

1. `init(context:)` runs once per node (state lives in `NodeState.storage["__program"]`). Allocate
   textures/buffers here (`context.makeTexture`, `context.makeBuffer`).
2. `encode(_:)` runs every frame **after** the node's RTT passes and **before** its final pass.
   Dispatch kernels into a compute encoder on `context.commandBuffer`, update uniforms from
   `context.props` (`context.scalar("intensity")`, `context.position("center")`, …), and return
   the textures the fragment pass samples (`compute_0`, `compute_1`, …) plus any `extraFields`
   values the fragment uniform block declares.
3. Handle resizes: compare `context.width/height` with the last frame.
4. Time: `context.frame.time`, `context.frame.deltaTime`; pointer: `context.frame.pointer`
   (UV, top-left origin) and `context.frame.pointerActive`.

## Rules

* Port the upstream math exactly (constants, clamps, frame ordering). Upstream's `getCpuValue`
  returns the *post-transform* value (the same number the uniform store holds), so read transformed
  props with `context.scalar(...)` / `context.position(...)` / `context.color(...)`; read raw
  strings (shape JSON, select values) from `context.props[...]`.
* Never edit generated files. If a kernel needs something the transpiler did not emit, note it.
* Keep everything inside `Engine/Programs/` (one file per family or shader) and register in the
  family file. Tests go in `Tests/ShadersKitTests/<Family>Tests.swift` and must render the shader
  offscreen (`ShaderRenderer.renderOffscreen`) and assert `stats.compileErrors.isEmpty`,
  `!stats.unsupportedNodes.contains(name)` and a non-trivial pixel result.
