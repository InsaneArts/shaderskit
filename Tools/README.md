# Tools

Everything under `Sources/ShadersKit/Generated` and `Sources/ShadersKit/Resources` is generated
from the upstream repository by the pipeline in this folder. Run `Tools/regenerate.sh` to redo it.

## upstream-dump

Vitest files copied into `packages/core/src/__tests__/gpu/` of an upstream checkout:

- `zz-dump.test.ts` composes every shader GPU-free (mock TypeGPU root, exactly like the upstream
  test suite), enumerates its compile-time prop variants, and writes one JSON per shader with the
  resolved WGSL of every pass, the prop/field metadata, and — for compute-backed shaders — the
  kernel WGSL and the recorded resource graph (textures, buffers, uniform structs, bind groups,
  per-frame dispatch order).
- `zz-dump-kit.test.ts` dumps the blend / mask / tone-mapping functions used by the compositor.
- `roles.json` is extracted from the shader sources (`role` / `species` per component).

## wgsl2x

A TypeScript transpiler for the WGSL subset TypeGPU emits:

| File | Role |
|---|---|
| `parser.ts`, `ast.ts` | Lexer + recursive-descent parser |
| `types.ts` | Type inference (annotates every expression) |
| `layout.ts` | WGSL uniform/storage memory layout |
| `link.ts` | Links all variants of a shader into one unit: dedupes structs/functions by body hash, renames conflicting globals, computes which globals each function captures (closure conversion for MSL), strips the per-pass sRGB tail |
| `msl.ts` | Metal Shading Language emitter (fragment entries + compute kernels) |
| `swift.ts` | Swift emitter for the CPU rasterizer (fragment passes only) |
| `gen-kit.ts` | `Compositor.metal` / `_Compositor.swift` from the kit dump + hand-written entry points |
| `gen-swift.ts` | Typed Swift layer structs |
| `main.ts` | Driver: dump → MSL resources, descriptor JSON, Swift layers, CPU programs |
| `selftest.ts` | Parses and type-checks every dumped pass (sanity check for the parser) |
| `gen-msl.ts`, `debug-packed.ts` | Development helpers |

```bash
cd Tools/wgsl2x && npm install
npx tsx src/main.ts <dumpDir> <repoRoot> [--validate] [--only A,B] [--no-cpu]
```

`--validate` compiles every generated `.metal` with `xcrun metal`.
