// Hand-written (not generated): GlassGlow, light moving through a glass shape.
// The shape comes from the child's alpha. Distances are in units of the shape's bounding-box
// height, origin at the box centre, y up, so the look does not depend on resolution.
#include <metal_stdlib>
using namespace metal;

struct SK_VertexOut { float4 position [[position]]; float2 uv; };

struct GGNode {
    float speed;
    float intensity;
    float glow;
    float refraction;
    float dispersion;
    float _opacity;
    float _p3;
    float _pad0;
};

struct GGSys {
    float time;
    float2 viewportSize;
    float2 logicalViewportSize;
    float aspect;
    float2 pointer;
    float pointerActive;
    char _sk_pad0[4];
};

struct GGPadded {
    float _opacity;
    float _pad0;
    float _pad1;
    float _pad2;
};

struct GGCombined {
    GGPadded n_root;
    GGNode n_x;
    GGSys _sys;
};

/// One light, already evaluated for this frame on the CPU.
struct GGBlob {
    float4 pos;     // x, y, z, radius
    float4 shape;   // intensity, aspect, cos(angle), sin(angle)
    float4 colour;  // rgb
};

struct GGParams {
    float4 a;       // height, contrast, edge softness, dispersion
    float4 b;       // bevel width, bevel refraction, bevel exponent, rim width
    float4 c;       // rim ambient, rim light, rim inset, intensity
    float4 gamma;   // per-channel output gamma
    float4 rimColour;
    float4 band;    // inner band: inset, width, light, blur (squared)
    uint4 info;     // width, height, blob count, unused
};

/// Bounding box of the shape in pixels: min x, min y, max x, max y.
struct GGBox { atomic_uint v[4]; };

static constant float GG_NONE = -1.0f;

kernel void gg_reset(device GGBox& box [[buffer(0)]]) {
    atomic_store_explicit(&box.v[0], 0xFFFFFFFFu, memory_order_relaxed);
    atomic_store_explicit(&box.v[1], 0xFFFFFFFFu, memory_order_relaxed);
    atomic_store_explicit(&box.v[2], 0u, memory_order_relaxed);
    atomic_store_explicit(&box.v[3], 0u, memory_order_relaxed);
}

// MARK: - Distance field (jump flood)

/// Seeds: inside pixels know themselves as the nearest inside pixel, outside pixels the nearest
/// outside pixel. The flood then finds, for each pixel, the nearest pixel of the other side.
kernel void gg_seed(uint2 gid [[thread_position_in_grid]],
                    texture2d<float, access::read> child [[texture(0)]],
                    texture2d<float, access::write> seeds [[texture(1)]],
                    device GGBox& box [[buffer(0)]],
                    constant uint2& size [[buffer(1)]]) {
    if (gid.x >= size.x || gid.y >= size.y) return;
    float a = child.read(gid).a;
    float2 p = float2(gid);
    if (a >= 0.5f) {
        seeds.write(float4(p, GG_NONE, GG_NONE), gid);
        atomic_fetch_min_explicit(&box.v[0], gid.x, memory_order_relaxed);
        atomic_fetch_min_explicit(&box.v[1], gid.y, memory_order_relaxed);
        atomic_fetch_max_explicit(&box.v[2], gid.x, memory_order_relaxed);
        atomic_fetch_max_explicit(&box.v[3], gid.y, memory_order_relaxed);
    } else {
        seeds.write(float4(GG_NONE, GG_NONE, p), gid);
    }
}

kernel void gg_flood(uint2 gid [[thread_position_in_grid]],
                     texture2d<float, access::read> src [[texture(0)]],
                     texture2d<float, access::write> dst [[texture(1)]],
                     constant int3& sizeStep [[buffer(0)]]) {
    int2 size = sizeStep.xy;
    if (int(gid.x) >= size.x || int(gid.y) >= size.y) return;
    int step = sizeStep.z;
    float2 p = float2(gid);
    float4 best = src.read(gid);
    float dIn = best.x < 0 ? INFINITY : distance_squared(p, best.xy);
    float dOut = best.z < 0 ? INFINITY : distance_squared(p, best.zw);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            int2 q = int2(gid) + int2(i, j) * step;
            if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y) continue;
            float4 s = src.read(uint2(q));
            if (s.x >= 0) { float d = distance_squared(p, s.xy); if (d < dIn) { dIn = d; best.xy = s.xy; } }
            if (s.z >= 0) { float d = distance_squared(p, s.zw); if (d < dOut) { dOut = d; best.zw = s.zw; } }
        }
    }
    dst.write(best, gid);
}

/// Signed distance in pixels, positive inside. Within a pixel of the edge the child's coverage
/// gives the sub-pixel position.
kernel void gg_distance(uint2 gid [[thread_position_in_grid]],
                        texture2d<float, access::read> child [[texture(0)]],
                        texture2d<float, access::read> seeds [[texture(1)]],
                        texture2d<float, access::write> sdf [[texture(2)]],
                        constant uint2& size [[buffer(0)]]) {
    if (gid.x >= size.x || gid.y >= size.y) return;
    float a = child.read(gid).a;
    float4 s = seeds.read(gid);
    float2 p = float2(gid);
    float d;
    if (a >= 0.5f) {
        d = s.z < 0 ? 1e4f : distance(p, s.zw) - 0.5f;
    } else {
        d = s.x < 0 ? -1e4f : -(distance(p, s.xy) - 0.5f);
    }
    if (abs(d) < 1.0f) d = a - 0.5f;
    sdf.write(float4(d), gid);
}

/// 5x5 Gaussian on the distance field: the flood measures to pixel centres, so its contours step
/// along the edge; thin rims drawn from them would look jagged.
kernel void gg_smooth(uint2 gid [[thread_position_in_grid]],
                      texture2d<float, access::read> src [[texture(0)]],
                      texture2d<float, access::write> dst [[texture(1)]],
                      constant uint2& size [[buffer(0)]]) {
    if (gid.x >= size.x || gid.y >= size.y) return;
    const float w[5] = { 0.0545f, 0.2442f, 0.4026f, 0.2442f, 0.0545f };   // sigma 1
    int2 hi = int2(size) - 1;
    float sum = 0;
    for (int j = -2; j <= 2; j++) {
        for (int i = -2; i <= 2; i++) {
            sum += w[i + 2] * w[j + 2] * src.read(uint2(clamp(int2(gid) + int2(i, j), int2(0), hi))).r;
        }
    }
    dst.write(float4(sum), gid);
}

// MARK: - Light

/// The light field at `p`. `blur2` > 0 returns it convolved with a Gaussian (each light widened,
/// its energy kept), for samples that would otherwise magnify fast-moving detail.
static float3 gg_light(float2 p, float depth, constant GGParams& P, constant GGBlob* blobs, float blur2 = 0.0f) {
    float z = P.a.x * sqrt(max(depth, 0.0f) + 1e-6f);
    float3 e = 0;
    for (uint k = 0; k < P.info.z; k++) {
        GGBlob b = blobs[k];
        float ru2 = b.pos.w * b.pos.w;
        float rv2 = ru2 * b.shape.y * b.shape.y;
        float wu2 = ru2 + blur2, wv2 = rv2 + blur2;
        float2 d = p - b.pos.xy;
        float u = d.x * b.shape.z + d.y * b.shape.w;
        float v = -d.x * b.shape.w + d.y * b.shape.z;
        float dz = z - b.pos.z;
        float d2 = u * u / wu2 + v * v / wv2 + dz * dz / wu2;
        float keep = sqrt(ru2 * rv2 / (wu2 * wv2));
        e += b.shape.x * keep * exp(-d2) * b.colour.rgb;
    }
    float3 L = 1.0f - exp(-P.a.y * e);
    return pow(clamp(L, 1e-5f, 1.0f), P.gamma.rgb);
}

struct GGFrame {
    float2 centre;  // box centre in pixels
    float height;   // box height in pixels
};

static GGFrame gg_frame(device GGBox& box) {
    float x0 = float(atomic_load_explicit(&box.v[0], memory_order_relaxed));
    float y0 = float(atomic_load_explicit(&box.v[1], memory_order_relaxed));
    float x1 = float(atomic_load_explicit(&box.v[2], memory_order_relaxed));
    float y1 = float(atomic_load_explicit(&box.v[3], memory_order_relaxed));
    GGFrame f;
    f.centre = float2(x0 + x1, y0 + y1) * 0.5f;
    f.height = max(y1 - y0, 1.0f);
    return f;
}

/// The glass and its rim. `glass` holds the lit inside only (the bloom source); `base` adds the rim.
kernel void gg_shade(uint2 gid [[thread_position_in_grid]],
                     texture2d<float, access::read> sdfTex [[texture(0)]],
                     texture2d<float, access::write> glassOut [[texture(1)]],
                     texture2d<float, access::write> baseOut [[texture(2)]],
                     constant GGParams& P [[buffer(0)]],
                     constant GGBlob* blobs [[buffer(1)]],
                     device GGBox& box [[buffer(2)]]) {
    uint2 size = P.info.xy;
    if (gid.x >= size.x || gid.y >= size.y) return;
    GGFrame f = gg_frame(box);
    float sdfPx = sdfTex.read(gid).r;
    float sdf = sdfPx / f.height;
    // Outward normal from the distance field's gradient (central differences ~0.45% of the box).
    int h = max(1, int(round(f.height * 0.0045f)));
    int2 g = int2(gid);
    int2 hi = int2(size) - 1;
    float dx = sdfTex.read(uint2(clamp(g + int2(h, 0), int2(0), hi))).r - sdfTex.read(uint2(clamp(g - int2(h, 0), int2(0), hi))).r;
    float dy = sdfTex.read(uint2(clamp(g + int2(0, h), int2(0), hi))).r - sdfTex.read(uint2(clamp(g - int2(0, h), int2(0), hi))).r;
    float2 n = float2(-dx, dy);
    float len = length(n);
    n = len > 1e-6f ? n / len : float2(0);
    // A coarser normal (~1.5% of the box) for the far samples of the rim band: small dents in the
    // edge would otherwise swing those samples a long way.
    int hc = max(1, int(round(f.height * 0.015f)));
    float cx = sdfTex.read(uint2(clamp(g + int2(hc, 0), int2(0), hi))).r - sdfTex.read(uint2(clamp(g - int2(hc, 0), int2(0), hi))).r;
    float cy = sdfTex.read(uint2(clamp(g + int2(0, hc), int2(0), hi))).r - sdfTex.read(uint2(clamp(g - int2(0, hc), int2(0), hi))).r;
    float2 nc = float2(-cx, cy);
    float lc = length(nc);
    nc = lc > 1e-6f ? nc / lc : n;

    float2 p = (float2(gid) + 0.5f - f.centre) / f.height;
    p.y = -p.y;
    // Edge softness: the fitted value, but never wider than a pixel at this resolution.
    float aaPx = clamp(P.a.z * f.height, 0.35f, 1.0f);
    float inside = 1.0f / (1.0f + exp(-sdfPx / aaPx));
    float depth = max(sdf, 0.0f);

    float bev = pow(clamp(1.0f - depth / P.b.x, 0.0f, 1.0f), P.b.z);
    float3 glass;
    float m[3] = { 1.0f - P.a.w, 1.0f, 1.0f + P.a.w };
    for (int c = 0; c < 3; c++) {
        float2 q = p - n * (P.b.y * m[c] * bev);
        glass[c] = gg_light(q, depth, P, blobs)[c];
    }
    glass *= inside;
    float rim = exp(-abs(sdf) / P.b.w);
    float3 rimRGB = rim * (P.c.x * P.rimColour.rgb + P.c.y * gg_light(p - nc * P.c.z, 0.0f, P, blobs, P.band.w));
    // A thin band just inside the edge, lit from deeper in the shape (blurred light, coarse normal).
    rimRGB += inside * exp(-depth / P.band.y) * P.band.z * gg_light(p - nc * P.band.x, 0.0f, P, blobs, P.band.w);
    glassOut.write(float4(glass, 1), gid);
    baseOut.write(float4(glass + rimRGB, inside), gid);
}

// MARK: - Bloom

/// Separable Gaussian on one level of the glass mip chain. Outside the frame is black.
/// The radius is a fraction of the shape's box height, so it is computed here from the box.
kernel void gg_blur(uint2 gid [[thread_position_in_grid]],
                    texture2d<float, access::read> src [[texture(0)]],
                    texture2d<float, access::write> dst [[texture(1)]],
                    constant float4& params [[buffer(0)]],   // dir.x, dir.y, sigma (box heights), level scale
                    device GGBox& box [[buffer(1)]]) {
    uint w = dst.get_width(), hgt = dst.get_height();
    if (gid.x >= w || gid.y >= hgt) return;
    int2 dir = int2(params.xy);
    float sigma = max(params.z * gg_frame(box).height * params.w, 0.3f);
    int r = min(int(ceil(3.0f * sigma)), 96);
    float3 sum = 0;
    float total = 0;
    for (int i = -r; i <= r; i++) {
        float wgt = exp(-0.5f * float(i * i) / (sigma * sigma));
        total += wgt;
        int2 q = int2(gid) + dir * i;
        if (q.x < 0 || q.y < 0 || q.x >= int(w) || q.y >= int(hgt)) continue;
        sum += src.read(uint2(q)).rgb * wgt;
    }
    dst.write(float4(sum / total, 1), gid);
}

kernel void gg_compose(uint2 gid [[thread_position_in_grid]],
                       texture2d<float, access::read> base [[texture(0)]],
                       texture2d<float> bloom0 [[texture(1)]],
                       texture2d<float> bloom1 [[texture(2)]],
                       texture2d<float> bloom2 [[texture(3)]],
                       texture2d<float, access::write> out [[texture(4)]],
                       constant float4& gains [[buffer(0)]],
                       constant GGParams& P [[buffer(1)]]) {
    uint2 size = P.info.xy;
    if (gid.x >= size.x || gid.y >= size.y) return;
    constexpr sampler s(filter::linear, address::clamp_to_zero);
    float2 uv = (float2(gid) + 0.5f) / float2(size);
    float4 b = base.read(gid);
    float3 bloom = gains.x * bloom0.sample(s, uv).rgb + gains.y * bloom1.sample(s, uv).rgb + gains.z * bloom2.sample(s, uv).rgb;
    float3 c = (b.rgb + bloom * (1.0f - b.a)) * P.c.w;
    out.write(float4(c, 1), gid);
}

// MARK: - Final pass

static float3 gg_srgbToLinear(float3 c) {
    float3 lo = c / 12.92f;
    float3 hi = pow((max(c, 0.0f) + 0.055f) / 1.055f, 2.4f);
    return select(hi, lo, c <= 0.04045f);
}

/// The fit was made in display sRGB; ShadersKit works in linear light (Display P3 by default).
fragment float4 GlassGlow_final(SK_VertexOut in [[stage_in]], constant GGCombined& uniforms [[buffer(0)]], texture2d<float> compute_0 [[texture(0)]], sampler linearClamp [[sampler(0)]]) {
    float3 c = gg_srgbToLinear(compute_0.sample(linearClamp, in.uv).rgb);
    if (uniforms.n_x._p3 > 0.5f) {
        const float3x3 srgbToP3 = float3x3(float3(0.8224621f, 0.0331941f, 0.0170827f),
                                           float3(0.1775380f, 0.9668058f, 0.0723974f),
                                           float3(0.0f, 0.0f, 0.9105199f));
        c = srgbToP3 * c;
    }
    float a = clamp(max(c.r, max(c.g, c.b)), 0.0f, 1.0f);
    float3 straight = a > 1e-4f ? c / a : float3(0);
    return float4(straight, a * uniforms.n_x._opacity);
}
