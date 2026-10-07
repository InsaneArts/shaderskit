// Generates Compositor.metal: the upstream blend / mask / tone-mapping kit (transpiled from the
// dumped WGSL) plus ShadersKit's own hand-written fullscreen entry points.
import fs from 'node:fs'
import path from 'node:path'
import {link} from './link.js'
import {emitMSL} from './msl.js'
import {emitSwiftLibrary} from './swift.js'

export function generateCompositor(dumpDir: string): {source: string; blendModes: string[]; maskTypes: string[]; toneModes: string[]} {
    const kit = JSON.parse(fs.readFileSync(path.join(dumpDir, '_kit.json'), 'utf8'))
    const unit = link({shader: 'Compositor', passes: [], kernels: [], libraries: Object.values(kit.wgsl as Record<string, string>)})
    const emitted = emitMSL(unit)
    const blendModes: string[] = kit.blendModes
    const maskTypes: string[] = kit.maskTypes
    const toneModes: string[] = kit.toneModes
    const blendCase = blendModes.map((m, i) => `        case ${i}: return blend_${m.replace(/[^a-zA-Z0-9_]/g, '_')}(base, overlay, opacity);`).join('\n')
    const maskCase = maskTypes.map((m, i) => `        case ${i}: return mask_${m}(target, mask);`).join('\n')
    const toneCase = toneModes.map((m, i) => `        case ${i}: return tone_${m}(c);`).join('\n')
    const extra = `
// ───────────────────────── ShadersKit compositor entry points ─────────────────────────

struct SKBlendParams {
    int mode;        // index into BlendMode.allCases
    float opacity;
    int maskType;    // -1 = no mask, else index into MaskType.allCases
    int flags;       // bit0: base is a solid clear (ignore base texture)
};

struct SKPresentParams {
    int toneMode;    // index into ToneMapping.allCases
    int premultiply; // 1 = premultiply RGB by alpha for the drawable
    int srgb;        // 1 = apply the sRGB OETF (0 when the drawable is an sRGB pixel format)
    int pad;
    float4 background; // linear straight-alpha clear color composited under the stack
};

struct SKTransformParams {
    float2 offset;
    float2 anchor;
    float rotation;   // radians
    float scale;
    float aspect;
    int edges;        // 0 stretch (clamp), 1 transparent, 2 mirror, 3 wrap
};

vertex SK_VertexOut sk_fullscreen_vertex(uint vid [[vertex_id]]) {
    const float2 pos[3] = {float2(-1.0f, -1.0f), float2(3.0f, -1.0f), float2(-1.0f, 3.0f)};
    const float2 uv[3] = {float2(0.0f, 1.0f), float2(2.0f, 1.0f), float2(0.0f, -1.0f)};
    SK_VertexOut o;
    o.position = float4(pos[vid], 0.0f, 1.0f);
    o.uv = uv[vid];
    return o;
}

static float4 sk_apply_blend(int mode, float4 base, float4 overlay, float opacity) {
    switch (mode) {
${blendCase}
        default: return blend_normal(base, overlay, opacity);
    }
}

static float4 sk_apply_mask(int type, float4 target, float4 mask) {
    switch (type) {
${maskCase}
        default: return target;
    }
}

static float3 sk_apply_tone(int mode, float3 c) {
    switch (mode) {
${toneCase}
        default: return c;
    }
}

/// Composites \`overlay\` (optionally masked) over \`base\` with the given blend mode and opacity.
fragment float4 sk_blend(SK_VertexOut in [[stage_in]],
                         constant SKBlendParams& p [[buffer(0)]],
                         texture2d<float> baseTex [[texture(0)]],
                         texture2d<float> overlayTex [[texture(1)]],
                         texture2d<float> maskTex [[texture(2)]],
                         sampler linearClamp [[sampler(0)]]) {
    float4 base = (p.flags & 1) ? float4(0.0f) : baseTex.sample(linearClamp, in.uv);
    float4 overlay = overlayTex.sample(linearClamp, in.uv);
    if (p.maskType >= 0) {
        overlay = sk_apply_mask(p.maskType, overlay, maskTex.sample(linearClamp, in.uv));
    }
    return sk_apply_blend(p.mode, base, overlay, p.opacity);
}

/// Final pass: tone mapping, sRGB OETF and optional premultiplication into the drawable.
fragment float4 sk_present(SK_VertexOut in [[stage_in]],
                           constant SKPresentParams& p [[buffer(0)]],
                           texture2d<float> src [[texture(0)]],
                           sampler linearClamp [[sampler(0)]]) {
    float4 c = src.sample(linearClamp, in.uv);
    if (p.background.a > 0.0f) c = blend_normal(p.background, c, 1.0f);
    float3 rgb = sk_apply_tone(p.toneMode, max(c.rgb, float3(0.0f)));
    if (p.srgb) rgb = linearToSrgb(clamp(rgb, 0.0f, 1.0f));
    float a = clamp(c.a, 0.0f, 1.0f);
    if (p.premultiply) rgb *= a;
    return float4(rgb, a);
}

/// Plain copy (resize / format conversion).
fragment float4 sk_copy(SK_VertexOut in [[stage_in]], texture2d<float> src [[texture(0)]], sampler linearClamp [[sampler(0)]]) {
    return src.sample(linearClamp, in.uv);
}

/// Decodes an sRGB-encoded media texture (images) into linear light, cutting alpha outside 0..1 UVs.
fragment float4 sk_decode_srgb(SK_VertexOut in [[stage_in]], texture2d<float> src [[texture(0)]], sampler linearClamp [[sampler(0)]]) {
    float4 c = src.sample(linearClamp, in.uv);
    return float4(srgbToLinear(c.rgb), c.a);
}

static float2 sk_edge_uv(float2 uv, int edges, thread float& alphaMask) {
    alphaMask = 1.0f;
    switch (edges) {
        case 1: {
            bool inside = all(uv >= float2(0.0f)) && all(uv <= float2(1.0f));
            alphaMask = inside ? 1.0f : 0.0f;
            return clamp(uv, 0.0f, 1.0f);
        }
        case 2: {
            float2 m = abs(fmod(abs(uv), 2.0f));
            return float2(m.x > 1.0f ? 2.0f - m.x : m.x, m.y > 1.0f ? 2.0f - m.y : m.y);
        }
        case 3: return fract(uv);
        default: return clamp(uv, 0.0f, 1.0f);
    }
}

/// Layer transform (offset / rotation / scale around an anchor) with edge handling.
fragment float4 sk_transform(SK_VertexOut in [[stage_in]],
                             constant SKTransformParams& p [[buffer(0)]],
                             texture2d<float> src [[texture(0)]],
                             sampler linearClamp [[sampler(0)]]) {
    float2 uv = in.uv - p.offset;
    float2 d = (uv - p.anchor) * float2(p.aspect, 1.0f);
    float c = cos(-p.rotation), s = sin(-p.rotation);
    d = float2(d.x * c - d.y * s, d.x * s + d.y * c) / max(p.scale, 1e-5f);
    uv = p.anchor + d / float2(p.aspect, 1.0f);
    float alphaMask = 1.0f;
    uv = sk_edge_uv(uv, p.edges, alphaMask);
    float4 col = src.sample(linearClamp, uv);
    return float4(col.rgb, col.a * alphaMask);
}
`
    return {source: emitted.source + extra, blendModes, maskTypes, toneModes}
}

/** Swift port of the composition kit for the CPU rasterizer. */
export function generateCompositorSwift(dumpDir: string): string {
    const kit = JSON.parse(fs.readFileSync(path.join(dumpDir, '_kit.json'), 'utf8'))
    const unit = link({shader: 'Compositor', passes: [], kernels: [], libraries: Object.values(kit.wgsl as Record<string, string>)})
    const blendModes: string[] = kit.blendModes
    const maskTypes: string[] = kit.maskTypes
    const toneModes: string[] = kit.toneModes
    const extra = `
static func sk_blend(_ mode: Int, _ base: SIMD4<Float>, _ overlay: SIMD4<Float>, _ opacity: Float) -> SIMD4<Float> {
    switch mode {
${blendModes.map((m, i) => `    case ${i}: return blend_${m.replace(/[^a-zA-Z0-9_]/g, '_')}(base, overlay, opacity)`).join('\n')}
    default: return blend_normal(base, overlay, opacity)
    }
}

static func sk_mask(_ type: Int, _ target: SIMD4<Float>, _ mask: SIMD4<Float>) -> SIMD4<Float> {
    switch type {
${maskTypes.map((m, i) => `    case ${i}: return mask_${m}(target, mask)`).join('\n')}
    default: return target
    }
}

static func sk_tone(_ mode: Int, _ c: SIMD3<Float>) -> SIMD3<Float> {
    switch mode {
${toneModes.map((m, i) => `    case ${i}: return tone_${m}(c)`).join('\n')}
    default: return c
    }
}
`
    return emitSwiftLibrary(unit, 'CPU_Compositor', extra)
}

if (process.argv[1] && process.argv[1].endsWith('gen-kit.ts')) {
    const [dumpDir, outFile] = process.argv.slice(2)
    const r = generateCompositor(dumpDir)
    fs.writeFileSync(outFile, r.source)
    console.log(`wrote ${outFile} (${r.source.length} bytes)`)
}
