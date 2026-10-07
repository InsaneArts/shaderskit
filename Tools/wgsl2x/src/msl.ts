// Metal Shading Language emitter for a linked shader unit.
import type {Block, ConstDecl, Expr, FnDecl, GlobalVar, Scalar, Stmt, StructDecl, Type} from './ast.js'
import {scalarOf, typeToString, vecLen} from './ast.js'
import {LayoutCalculator, flattenLayout, type StructLayout} from './layout.js'
import type {LinkUnit, LinkedKernel, LinkedPass} from './link.js'
import {calledFns} from './link.js'
import {exprType} from './types.js'

const MSL_RESERVED = new Set([
    'kernel', 'vertex', 'fragment', 'constant', 'device', 'thread', 'threadgroup', 'sampler', 'texture', 'uniform', 'main', 'template', 'union', 'class',
    'new', 'delete', 'this', 'half', 'float', 'int', 'uint', 'bool', 'short', 'char', 'long', 'double', 'auto', 'switch', 'case', 'default', 'do', 'goto',
    'extern', 'static', 'register', 'signed', 'unsigned', 'typedef', 'sizeof', 'volatile', 'inline', 'namespace', 'using', 'operator', 'friend', 'virtual',
    'public', 'private', 'protected', 'try', 'catch', 'throw', 'export', 'mutable', 'explicit', 'typename', 'alignas', 'alignof', 'and', 'or', 'not', 'xor',
    'bitand', 'bitor', 'compl', 'nullptr', 'decltype', 'constexpr', 'noexcept', 'static_assert', 'thread_local', 'wchar_t', 'char16_t', 'char32_t', 'asm',
    'dynamic_cast', 'static_cast', 'reinterpret_cast', 'const_cast', 'typeid', 'const', 'void', 'enum', 'struct', 'return', 'if', 'else', 'for', 'while',
    'break', 'continue', 'true', 'false', 'select', 'min', 'max', 'abs', 'sign', 'step', 'mix', 'clamp', 'floor', 'ceil', 'fract', 'sqrt', 'pow', 'exp', 'log',
    'sin', 'cos', 'tan', 'length', 'normalize', 'dot', 'cross', 'reflect', 'refract', 'distance', 'any', 'all', 'ushort', 'uchar', 'size_t', 'ptrdiff_t',
    'in', 'out', 'inout', 'level', 'bias', 'gradient2d', 'array', 'metal', 'simd', 'quad', 'atomic', 'packed_float3', 'buffer', 'rint', 'round', 'trunc',
    'fmod', 'modf', 'frexp', 'ldexp', 'exp2', 'log2', 'rsqrt', 'saturate', 'fma', 'popcount', 'clz', 'ctz', 'as_type', 'access', 'uv', // keep uv free? no: uv is fine as a local
])
MSL_RESERVED.delete('uv')

function ident(name: string): string {
    return MSL_RESERVED.has(name) ? `${name}_` : name
}

function mslScalar(s: Scalar): string {
    switch (s) {
        case 'f32': return 'float'
        case 'i32': return 'int'
        case 'u32': return 'uint'
        case 'bool': return 'bool'
    }
}

export function mslType(t: Type, opts: {packedVec3?: boolean} = {}): string {
    switch (t.kind) {
        case 'scalar': return mslScalar(t.scalar)
        case 'vec': return t.n === 3 && (opts.packedVec3 || t.packed) && t.scalar === 'f32' ? 'packed_float3' : `${mslScalar(t.scalar)}${t.n}`
        case 'mat': return `float${t.cols}x${t.rows}`
        case 'array': return `metal::array<${mslType(t.elem)}, ${t.count ?? 1}>`
        case 'struct': return ident(t.name)
        case 'texture':
            if (t.dim === 'storage2d') {
                const access = t.access === 'write' ? 'access::write' : t.access === 'read_write' ? 'access::read_write' : 'access::read'
                return `texture2d<${storageScalar(t.format ?? 'rgba16float')}, ${access}>`
            }
            return 'texture2d<float>'
        case 'sampler': return 'sampler'
        case 'atomic': return t.inner === 'i32' ? 'atomic_int' : 'atomic_uint'
        case 'ptr': return `thread ${mslType(t.inner)}*`
        case 'void': return 'void'
    }
}

function storageScalar(format: string): string {
    if (format.includes('uint')) return 'uint'
    if (format.includes('sint')) return 'int'
    return 'float'
}

function globalParamType(g: GlobalVar): string {
    switch (g.space) {
        case 'uniform': return `constant ${mslType(g.type)}&`
        case 'storage': {
            // Always non-const: the same buffer may be read-only in one kernel and read-write in
            // another, and helper functions shared between them need one pointer type.
            if (g.type.kind === 'array') return `device ${mslType(g.type.elem)}*`
            return `device ${mslType(g.type)}&`
        }
        default: return mslType(g.type)
    }
}

export interface EmittedPass {
    variantIndex: number
    role: 'final' | 'rtt'
    textureKey: string | null
    entry: string
    textures: {key: string; slot: number; external: boolean}[]
    samplers: {name: string; slot: number}[]
    usesUniforms: boolean
}
export interface EmittedKernel {
    index: number
    dims: number
    entry: string
    buffers: {name: string; slot: number; space: string; type: string}[]
    textures: {name: string; slot: number; type: string}[]
    sizeSlot: number
}
export interface EmittedUnit {
    source: string
    passes: EmittedPass[]
    kernels: EmittedKernel[]
    uniformLayout: {size: number; fields: {path: string; offset: number; type: string; size: number}[]} | null
    kernelUniformLayouts: Record<string, {size: number; fields: {path: string; offset: number; type: string; size: number}[]}>
}

export function emitMSL(unit: LinkUnit): EmittedUnit {
    const em = new MSLEmitter(unit)
    return em.emit()
}

class MSLEmitter {
    private out: string[] = []
    private layout: LayoutCalculator
    private storageLayout: LayoutCalculator
    private usedHelpers = new Set<string>()

    constructor(private unit: LinkUnit) {
        this.layout = new LayoutCalculator(unit.env.structs, 'uniform')
        this.storageLayout = new LayoutCalculator(unit.env.structs, 'storage')
    }

    private isHostStruct(name: string): boolean {
        return this.unit.hostShareable.has(name) && !this.unit.constructedStructs.has(name)
    }

    /** Marks vec3 members of host-shareable structs that WGSL packs tightly (next member within 12 bytes). */
    private markPackedMembers() {
        for (const s of this.unit.structs) {
            if (!this.isHostStruct(s.name)) continue
            const l = this.layout.structLayout(s.name)
            s.members.forEach((m, i) => {
                if (m.type.kind === 'vec' && m.type.n === 3 && m.type.scalar === 'f32') {
                    const next = l.fields[i + 1]
                    const end = next ? next.offset : l.size
                    if (end < l.fields[i].offset + 16) {
                        // mutate the shared Type object so annotated expression types see the flag
                        m.type.packed = true
                    }
                }
            })
        }
    }

    emit(): EmittedUnit {
        this.markPackedMembers()
        const ns = `S_${this.unit.shader}`
        const body: string[] = []
        // structs
        for (const s of this.unit.structs) body.push(this.emitStruct(s))
        // consts
        for (const c of this.unit.consts) body.push(this.emitConst(c))
        // functions
        for (const f of this.unit.fns) body.push(this.emitFn(f))
        const passes: EmittedPass[] = []
        const kernels: EmittedKernel[] = []
        const entries: string[] = []
        for (const p of this.unit.passes) {
            const {text, info} = this.emitPassEntry(p, ns)
            entries.push(text)
            passes.push(info)
        }
        for (const k of this.unit.kernels) {
            const {text, info} = this.emitKernelEntry(k, ns)
            entries.push(text)
            kernels.push(info)
        }
        const helpers = this.emitHelpers()
        const src = [
            `// Generated by wgsl2x from the shaders.com WGSL library — do not edit.`,
            `// Shader: ${this.unit.shader}`,
            `#include <metal_stdlib>`,
            `using namespace metal;`,
            ``,
            `struct SK_VertexOut { float4 position [[position]]; float2 uv; };`,
            ``,
            `namespace ${ns} {`,
            helpers,
            body.join('\n\n'),
            `} // namespace ${ns}`,
            ``,
            `using namespace ${ns};`,
            ``,
            entries.join('\n\n'),
            ``,
        ].join('\n')

        // uniform layout for `uniforms` global (fragment passes)
        let uniformLayout: EmittedUnit['uniformLayout'] = null
        const ug = this.unit.globalDecls.get('uniforms')
        if (ug && ug.type.kind === 'struct') uniformLayout = this.describeLayout(this.layout.structLayout(ug.type.name))
        const kernelUniformLayouts: EmittedUnit['kernelUniformLayouts'] = {}
        for (const [name, g] of this.unit.globalDecls) {
            if (g.space === 'uniform' && g.type.kind === 'struct' && name !== 'uniforms') kernelUniformLayouts[name] = this.describeLayout(this.layout.structLayout(g.type.name))
        }
        return {source: src, passes, kernels, uniformLayout, kernelUniformLayouts}
    }

    private describeLayout(l: StructLayout) {
        return {size: l.size, fields: flattenLayout(l).map((f) => ({path: f.path, offset: f.offset, type: shortTypeName(f.type), size: f.size}))}
    }

    private emitHelpers(): string {
        // Always-available helpers (cheap, inline).
        return [
            `[[maybe_unused]] static inline int wgsl_isign(int x) { return (x > 0) - (x < 0); }`,
            `[[maybe_unused]] static inline int2 wgsl_isign(int2 x) { return int2((x > 0)) - int2((x < 0)); }`,
            `[[maybe_unused]] static inline int3 wgsl_isign(int3 x) { return int3((x > 0)) - int3((x < 0)); }`,
            `[[maybe_unused]] static inline int4 wgsl_isign(int4 x) { return int4((x > 0)) - int4((x < 0)); }`,
            `[[maybe_unused]] static inline uint wgsl_f2u(float x) { return uint(max(x, 0.0f)); }`,
            `[[maybe_unused]] static inline uint2 wgsl_f2u(float2 x) { return uint2(max(x, 0.0f)); }`,
            `[[maybe_unused]] static inline uint3 wgsl_f2u(float3 x) { return uint3(max(x, 0.0f)); }`,
            `[[maybe_unused]] static inline uint4 wgsl_f2u(float4 x) { return uint4(max(x, 0.0f)); }`,
        ].join('\n')
    }

    // ───────── structs ─────────
    private emitStruct(s: StructDecl): string {
        const host = this.isHostStruct(s.name)
        const lines: string[] = [`struct ${ident(s.name)} {`]
        if (host) {
            // match WGSL uniform layout with explicit padding
            const l = this.layout.structLayout(s.name)
            let msl = 0
            let padIdx = 0
            for (let i = 0; i < s.members.length; i++) {
                const m = s.members[i]
                const f = l.fields[i]
                const mAlign = this.mslAlign(m.type)
                const natural = Math.ceil(msl / mAlign) * mAlign
                if (natural < f.offset) {
                    lines.push(`    char _sk_pad${padIdx++}[${f.offset - natural}];`)
                } else if (natural > f.offset) {
                    throw new Error(`[${this.unit.shader}] struct ${s.name}.${m.name}: MSL offset ${natural} exceeds WGSL offset ${f.offset}`)
                }
                lines.push(`    ${mslType(m.type)} ${ident(m.name)};`)
                msl = f.offset + this.mslSize(m.type)
            }
            if (msl < l.size) lines.push(`    char _sk_pad${padIdx++}[${l.size - msl}];`)
        } else {
            for (const m of s.members) lines.push(`    ${mslType(m.type)} ${ident(m.name)};`)
        }
        lines.push('};')
        return lines.join('\n')
    }

    private mslAlign(t: Type): number {
        switch (t.kind) {
            case 'scalar': case 'atomic': return 4
            case 'vec': return t.n === 2 ? 8 : t.n === 3 ? (t.packed ? 4 : 16) : 16
            case 'mat': return 16
            case 'array': return this.mslAlignElem(t.elem)
            case 'struct': return 1 // padded explicitly by us → char-alignment is enough
            default: return 4
        }
    }
    private mslAlignElem(t: Type): number {
        if (t.kind === 'vec') return t.n === 2 ? 8 : 16
        if (t.kind === 'struct') return 1
        return this.mslAlign(t)
    }
    private mslSize(t: Type): number {
        switch (t.kind) {
            case 'scalar': case 'atomic': return 4
            case 'vec': return t.n === 2 ? 8 : t.n === 3 ? (t.packed ? 12 : 16) : 16
            case 'mat': return 16 * t.cols
            case 'array': {
                const e = t.elem
                const es = e.kind === 'vec' ? (e.n === 2 ? 8 : 16) : e.kind === 'struct' ? this.layout.structLayout(e.name).size : this.mslSize(e)
                return es * (t.count ?? 0)
            }
            case 'struct': return this.layout.structLayout(t.name).size
            default: return 4
        }
    }

    // ───────── consts ─────────
    private emitConst(c: ConstDecl): string {
        const t = c.type ?? exprType(c.init)
        if (t.kind === 'array') {
            return `constant ${mslType(t)} ${ident(c.name)} = ${this.expr(c.init)};`
        }
        return `constant ${mslType(t)} ${ident(c.name)} = ${this.expr(c.init)};`
    }

    // ───────── functions ─────────
    private captureParams(fnName: string): string[] {
        const caps = this.unit.captures.get(fnName) ?? []
        return caps.map((g) => `${globalParamType(this.unit.globalDecls.get(g)!)} ${ident(g)}`)
    }
    private captureArgs(fnName: string): string[] {
        return (this.unit.captures.get(fnName) ?? []).map((g) => ident(g))
    }

    private emitFn(f: FnDecl): string {
        const params = [...f.params.map((p) => `${this.paramType(p.type)} ${ident(p.name)}`), ...this.captureParams(f.name)]
        return `static ${mslType(f.ret)} ${ident(f.name)}(${params.join(', ')}) ${this.block(f.body, '')}`
    }

    private paramType(t: Type): string {
        if (t.kind === 'ptr') return `thread ${mslType(t.inner)}&`
        return mslType(t)
    }

    // ───────── entries ─────────
    private emitPassEntry(p: LinkedPass, ns: string): {text: string; info: EmittedPass} {
        const params: string[] = [`SK_VertexOut in [[stage_in]]`]
        const textures: EmittedPass['textures'] = []
        const samplers: EmittedPass['samplers'] = []
        let usesUniforms = false
        // group 1 textures (by binding), then group 3 externals; group 2 samplers; group 0 uniforms
        const g1 = p.globals.filter((g) => g.group === 1).sort((a, b) => (a.binding ?? 0) - (b.binding ?? 0))
        const g3 = p.globals.filter((g) => g.group === 3).sort((a, b) => (a.binding ?? 0) - (b.binding ?? 0))
        const g2 = p.globals.filter((g) => g.group === 2).sort((a, b) => (a.binding ?? 0) - (b.binding ?? 0))
        const g0 = p.globals.filter((g) => g.group === 0)
        for (const g of g0) {
            usesUniforms = true
            params.push(`${globalParamType(g)} ${ident(g.name)} [[buffer(0)]]`)
        }
        let tslot = 0
        for (const g of [...g1, ...g3]) {
            params.push(`texture2d<float> ${ident(g.name)} [[texture(${tslot})]]`)
            textures.push({key: g.name, slot: tslot, external: g.group === 3})
            tslot++
        }
        let sslot = 0
        for (const g of g2) {
            params.push(`sampler ${ident(g.name)} [[sampler(${sslot})]]`)
            samplers.push({name: g.name, slot: sslot})
            sslot++
        }
        // The entry body references its WGSL input struct param (usually `in`): rename to `in`.
        const inParam = p.entry.params[0]?.name ?? 'in'
        const body = this.block(p.entry.body, '', {renameIdent: new Map([[inParam, 'in']])})
        const text = `fragment float4 ${p.entry.name}(${params.join(', ')}) ${body}`
        return {text, info: {variantIndex: p.variantIndex, role: p.role, textureKey: p.textureKey, entry: p.entry.name, textures, samplers, usesUniforms}}
    }

    private emitKernelEntry(k: LinkedKernel, ns: string): {text: string; info: EmittedKernel} {
        const params: string[] = [`uint3 sk_gid [[thread_position_in_grid]]`]
        const buffers: EmittedKernel['buffers'] = []
        const textures: EmittedKernel['textures'] = []
        let bslot = 0
        let tslot = 0
        const sorted = [...k.globals].sort((a, b) => (a.binding ?? 0) - (b.binding ?? 0))
        for (const g of sorted) {
            if (g.type.kind === 'texture') {
                params.push(`${mslType(g.type)} ${ident(g.name)} [[texture(${tslot})]]`)
                textures.push({name: g.name, slot: tslot, type: typeToString(g.type)})
                tslot++
            } else if (g.type.kind === 'sampler') {
                params.push(`sampler ${ident(g.name)} [[sampler(0)]]`)
            } else {
                params.push(`${globalParamType(g)} ${ident(g.name)} [[buffer(${bslot})]]`)
                buffers.push({name: g.name, slot: bslot, space: g.space, type: typeToString(g.type)})
                bslot++
            }
        }
        const sizeSlot = bslot
        params.push(`constant uint3& sk_size [[buffer(${sizeSlot})]]`)
        // the entry fn (wrapped callback) takes (x, y, z) u32 params and captures globals
        const innerName = `${k.entry.name}_body`
        const inner: FnDecl = {...k.entry, name: innerName}
        // register captures for the inner body: direct + transitive
        const caps = new Set<string>()
        for (const g of k.globals) {
            // only include globals actually referenced (directly or via callees)
            caps.add(g.name)
        }
        const referenced = this.referencedGlobals(inner)
        const capList = [...caps].filter((g) => referenced.has(g)).sort()
        this.unit.captures.set(innerName, capList)
        const innerText = this.emitFn(inner)
        const callArgs = [...inner.params.map((_, i) => ['sk_gid.x', 'sk_gid.y', 'sk_gid.z'][i]), ...capList.map(ident)]
        const text = `${innerText}\n\nkernel void ${k.entry.name}(${params.join(', ')}) {\n    if (any(sk_gid >= sk_size)) { return; }\n    ${innerName}(${callArgs.join(', ')});\n}`
        return {text, info: {index: k.index, dims: k.dims, entry: k.entry.name, buffers, textures, sizeSlot}}
    }

    private referencedGlobals(f: FnDecl): Set<string> {
        const refs = new Set<string>()
        const visit = (fn: FnDecl) => {
            const locals = new Set(fn.params.map((p) => p.name))
            const walk = (e: Expr) => {
                if (e.kind === 'ident' && this.unit.globalDecls.has(e.name) && !locals.has(e.name)) refs.add(e.name)
            }
            const walkStmtE = (s: Stmt) => {
                if (s.kind === 'let' || s.kind === 'var' || s.kind === 'const') locals.add(s.name)
            }
            // reuse printer walkers via calledFns + manual
            const {walkFn} = require_walk()
            walkFn(fn, walk, walkStmtE)
            for (const c of calledFns(fn, this.unit)) for (const g of this.unit.captures.get(c) ?? []) refs.add(g)
        }
        visit(f)
        return refs
    }

    // ───────── statements ─────────
    private renames: Map<string, string>[] = []

    private block(b: Block, ind: string, opts?: {renameIdent?: Map<string, string>}): string {
        if (opts?.renameIdent) this.renames.push(opts.renameIdent)
        const lines = b.map((s) => this.stmt(s, ind + '    '))
        if (opts?.renameIdent) this.renames.pop()
        return `{\n${lines.join('\n')}\n${ind}}`
    }

    private stmt(s: Stmt, ind: string): string {
        switch (s.kind) {
            case 'let': case 'const': {
                const t = s.type ?? exprType(s.init)
                if (t.kind === 'ptr') return `${ind}auto ${ident(s.name)} = ${this.expr(s.init)};`
                return `${ind}const ${mslType(t)} ${ident(s.name)} = ${this.coerce(s.init, t)};`
            }
            case 'var': {
                const t = s.type ?? (s.init ? exprType(s.init) : null)
                if (!t) throw new Error('var without type')
                if (t.kind === 'ptr') return `${ind}auto ${ident(s.name)} = ${s.init ? this.expr(s.init) : 'nullptr'};`
                return `${ind}${mslType(t)} ${ident(s.name)} = ${s.init ? this.coerce(s.init, t) : '{}'};`
            }
            case 'assign': {
                const tt = exprType(s.target)
                const target = this.asLvalue(() => this.expr(s.target))
                if (s.op === '%=' && scalarOf(tt) === 'f32') return `${ind}${target} = fmod(${this.expr(s.target)}, ${this.coerce(s.value, tt)});`
                return `${ind}${target} ${s.op} ${this.coerce(s.value, tt)};`
            }
            case 'incdec': return `${ind}${this.asLvalue(() => this.expr(s.target))}${s.op};`
            case 'expr': return `${ind}${this.expr(s.expr)};`
            case 'phony': return `${ind}(void)(${this.expr(s.expr)});`
            case 'return': return `${ind}return${s.expr ? ` ${this.expr(s.expr)}` : ''};`
            case 'if': {
                let out = `${ind}if (${this.expr(s.cond)}) ${this.block(s.then, ind)}`
                if (s.else) {
                    if (Array.isArray(s.else)) out += ` else ${this.block(s.else, ind)}`
                    else out += ` else ${this.stmt(s.else, ind).trimStart()}`
                }
                return out
            }
            case 'for': {
                const init = s.init ? this.stmt(s.init, '').replace(/;$/, '') : ''
                const cond = s.cond ? this.expr(s.cond) : ''
                const upd = s.update ? this.stmt(s.update, '').replace(/;$/, '') : ''
                return `${ind}for (${init}; ${cond}; ${upd}) ${this.block(s.body, ind)}`
            }
            case 'while': return `${ind}while (${this.expr(s.cond)}) ${this.block(s.body, ind)}`
            case 'loop': {
                if (s.continuing && s.continuing.length) throw new Error('loop with continuing block unsupported')
                return `${ind}while (true) ${this.block(s.body, ind)}`
            }
            case 'switch': {
                const cases = s.cases.map((c) => {
                    const label = c.values ? c.values.map((v) => `${ind}    case ${this.expr(v)}:`).join('\n') : `${ind}    default:`
                    return `${label} ${this.block(c.body, ind + '    ')} break;`
                })
                return `${ind}switch (${this.expr(s.selector)}) {\n${cases.join('\n')}\n${ind}}`
            }
            case 'break': return `${ind}break;`
            case 'continue': return `${ind}continue;`
            case 'discard': return `${ind}discard_fragment();`
            case 'block': return `${ind}${this.block(s.body, ind)}`
        }
    }

    // ───────── expressions ─────────
    private lvalue = false
    private asLvalue<T>(f: () => T): T {
        const prev = this.lvalue
        this.lvalue = true
        try {return f()} finally {this.lvalue = prev}
    }

    /** Emits `e` converted to type `target` where WGSL allows implicit abstract-literal conversion. */
    private coerce(e: Expr, target: Type): string {
        const t = exprType(e)
        const s = this.expr(e)
        if (t.kind === 'scalar' && t.abstract && target.kind === 'scalar' && target.scalar !== t.scalar) {
            return this.castTo(s, target)
        }
        if (t.kind === 'scalar' && t.abstract && target.kind === 'vec') return `${mslType(target)}(${s})`
        return s
    }

    private castTo(s: string, target: Type): string {
        return `${mslType(target)}(${s})`
    }

    private lookupRename(name: string): string | null {
        for (let i = this.renames.length - 1; i >= 0; i--) {
            const r = this.renames[i].get(name)
            if (r) return r
        }
        return null
    }

    expr(e: Expr): string {
        switch (e.kind) {
            case 'ident': return this.lookupRename(e.name) ?? ident(e.name)
            case 'int': {
                const t = exprType(e)
                const v = e.value.toString()
                if (t.kind === 'scalar' && t.scalar === 'u32') return `${v}u`
                return v
            }
            case 'float': return floatLit(e.text)
            case 'bool': return e.value ? 'true' : 'false'
            case 'paren': return `(${this.expr(e.expr)})`
            case 'unary': {
                if (e.op === '&') {
                    const inner = this.asLvalue(() => this.expr(e.expr))
                    return `(&${inner})`
                }
                const inner = this.expr(e.expr)
                switch (e.op) {
                    case '-': return `(-${inner})`
                    case '!': return `(!${inner})`
                    case '~': return `(~${inner})`
                    case '*': {
                        const t = exprType(e)
                        if (t.kind === 'vec' && t.packed && !this.lvalue) return `float3((*${inner}))`
                        return `(*${inner})`
                    }
                }
                return inner
            }
            case 'binary': return this.binary(e)
            case 'member': {
                const objS = this.expr(e.obj)
                const acc = `${objS}.${ident(e.name)}`
                const mt = exprType(e)
                if (mt.kind === 'vec' && mt.packed && !this.lvalue) return `float3(${acc})`
                return acc
            }
            case 'index': return `${this.expr(e.obj)}[${this.expr(e.index)}]`
            case 'call': return this.call(e)
        }
    }

    private binary(e: Expr & {kind: 'binary'}): string {
        const lt = exprType(e.left)
        const rt = exprType(e.right)
        const rtType = exprType(e)
        let l = this.expr(e.left)
        let r = this.expr(e.right)
        // abstract literal coercion toward the other operand
        if (lt.kind === 'scalar' && lt.abstract && !(rt.kind === 'scalar' && rt.abstract)) {
            const target = scalarOf(rt)
            if (target && target !== lt.scalar) l = `${mslScalar(target)}(${l})`
        }
        if (rt.kind === 'scalar' && rt.abstract && !(lt.kind === 'scalar' && lt.abstract)) {
            const target = scalarOf(lt)
            if (target && target !== rt.scalar) r = `${mslScalar(target)}(${r})`
        }
        switch (e.op) {
            case '%':
                if (scalarOf(rtType) === 'f32') {
                    // fmod(vec, scalar) needs a splat
                    if (rtType.kind === 'vec') {
                        if (lt.kind !== 'vec') l = `${mslType(rtType)}(${l})`
                        if (rt.kind !== 'vec') r = `${mslType(rtType)}(${r})`
                    }
                    return `fmod(${l}, ${r})`
                }
                return `(${l} % ${r})`
            case '&': case '|': case '^': {
                if (scalarOf(lt) === 'bool' && lt.kind === 'scalar') {
                    if (e.op === '&') return `(${l} && ${r})`
                    if (e.op === '|') return `(${l} || ${r})`
                    return `(${l} != ${r})`
                }
                return `(${l} ${e.op} ${r})`
            }
            default:
                return `(${l} ${e.op} ${r})`
        }
    }

    private call(e: Expr & {kind: 'call'}): string {
        const name = e.callee
        const env = this.unit.env
        const argT = e.args.map((a) => exprType(a))
        const args = e.args.map((a) => this.expr(a))
        // user function
        if (env.fns.has(name)) {
            const sig = env.fns.get(name)!
            const coerced = e.args.map((a, i) => this.coerce(a, sig.params[i] ?? exprType(a)))
            return `${ident(name)}(${[...coerced, ...this.captureArgs(name)].join(', ')})`
        }
        // struct ctor
        if (env.structs.has(name)) {
            if (args.length === 0) return `${ident(name)}{}`
            const s = env.structs.get(name)!
            const coerced = e.args.map((a, i) => this.coerce(a, s.members[i].type))
            return `${ident(name)}{${coerced.join(', ')}}`
        }
        const rt = exprType(e)
        // vector constructors
        if (/^vec[234][fiu]?$/.test(name)) {
            const vt = rt as Type & {kind: 'vec'}
            const tn = mslType(vt)
            if (args.length === 0) return `${tn}(0)`
            return `${tn}(${args.join(', ')})`
        }
        if (/^mat[234]x[234]f$/.test(name)) {
            return `${mslType(rt)}(${e.args.map((a) => this.coerce(a, {kind: 'scalar', scalar: 'f32'})).join(', ')})`
        }
        if (name === 'array') {
            const at = rt as Type & {kind: 'array'}
            if (args.length === 0) return `${mslType(at)}{}`
            const coerced = e.args.map((a) => this.coerce(a, at.elem))
            return `${mslType(at)}{{${coerced.join(', ')}}}`
        }
        switch (name) {
            case 'f32': case 'i32': case 'bool': return `${mslType(rt)}(${args[0]})`
            case 'u32': {
                if (scalarOf(argT[0]) === 'f32') return `wgsl_f2u(${args[0]})`
                return `${mslType(rt)}(${args[0]})`
            }
            case 'bitcast': return `as_type<${mslType(rt)}>(${args[0]})`
            case 'select': {
                // select(f, t, cond) — same order in MSL; coerce abstract literal operands
                const target = rt
                const f = this.coerce(e.args[0], target)
                const t = this.coerce(e.args[1], target)
                return `select(${f}, ${t}, ${args[2]})`
            }
            case 'textureSample': return `${args[0]}.sample(${args[1]}, ${args[2]})`
            case 'textureSampleBaseClampToEdge': return `${args[0]}.sample(${args[1]}, ${args[2]})`
            case 'textureSampleLevel': return `${args[0]}.sample(${args[1]}, ${args[2]}, level(${args[3]}))`
            case 'textureLoad': {
                const tt = argT[0]
                const coord = this.coordToUint2(e.args[1])
                if (tt.kind === 'texture' && tt.dim === 'storage2d') return `${args[0]}.read(${coord})`
                return `${args[0]}.read(${coord}${args.length > 2 ? `, ${args[2]}` : ''})`
            }
            case 'textureStore': return `${args[0]}.write(${args[2]}, ${this.coordToUint2(e.args[1])})`
            case 'textureDimensions': return `uint2(${args[0]}.get_width(), ${args[0]}.get_height())`
            case 'atomicAdd': return `atomic_fetch_add_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicSub': return `atomic_fetch_sub_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicMax': return `atomic_fetch_max_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicMin': return `atomic_fetch_min_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicAnd': return `atomic_fetch_and_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicOr': return `atomic_fetch_or_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicXor': return `atomic_fetch_xor_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicExchange': return `atomic_exchange_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'atomicLoad': return `atomic_load_explicit(${args[0]}, memory_order_relaxed)`
            case 'atomicStore': return `atomic_store_explicit(${args[0]}, ${args[1]}, memory_order_relaxed)`
            case 'inverseSqrt': return `rsqrt(${args[0]})`
            case 'dpdx': case 'dpdxCoarse': case 'dpdxFine': return `dfdx(${args[0]})`
            case 'dpdy': case 'dpdyCoarse': case 'dpdyFine': return `dfdy(${args[0]})`
            case 'fwidth': case 'fwidthCoarse': case 'fwidthFine': return `fwidth(${args[0]})`
            case 'round': return `rint(${args[0]})`
            case 'sign': return scalarOf(argT[0]) === 'f32' ? `sign(${args[0]})` : `wgsl_isign(${args[0]})`
            case 'countOneBits': return `popcount(${args[0]})`
            case 'reverseBits': return `reverse_bits(${args[0]})`
            case 'extractBits': return `extract_bits(${args[0]}, ${args[1]}, ${args[2]})`
            case 'insertBits': return `insert_bits(${args[0]}, ${args[1]}, ${args[2]}, ${args[3]})`
            case 'faceForward': return `faceforward(${args.join(', ')})`
            case 'workgroupBarrier': return `threadgroup_barrier(mem_flags::mem_threadgroup)`
            case 'storageBarrier': return `threadgroup_barrier(mem_flags::mem_device)`
            case 'arrayLength': throw new Error('arrayLength unsupported')
            case 'pack4x8unorm': return `pack_float_to_unorm4x8(${args[0]})`
            case 'unpack4x8unorm': return `unpack_unorm4x8_to_float(${args[0]})`
            case 'mix': case 'clamp': case 'smoothstep': case 'step': case 'max': case 'min': case 'pow': case 'atan2': case 'fma': case 'reflect': case 'refract': case 'distance': case 'ldexp': {
                // promote scalar arguments to the vector result type where MSL lacks mixed overloads
                const target = rt
                const out = e.args.map((a, i) => {
                    const at = argT[i]
                    const s = this.coerce(a, target.kind === 'vec' ? {kind: 'scalar', scalar: target.scalar} : target)
                    if (target.kind === 'vec' && at.kind !== 'vec') {
                        // mix/smoothstep allow a scalar interpolant; MSL: mix(T,T,float) ok, smoothstep(float,float,T) ok, clamp(T,float,float) ok, max/min(T,float) ok, pow needs T,T, step(float,T) ok, atan2 needs T,T
                        if (name === 'refract' && i === 2) return s
                        if (name === 'pow' || name === 'atan2' || name === 'fma' || name === 'reflect' || name === 'refract' || name === 'distance') return `${mslType(target)}(${s})`
                        if (name === 'mix' && i === 2) return s
                        if (name === 'smoothstep' && i < 2) return s
                        if (name === 'step' && i === 0) return s
                        if ((name === 'clamp' || name === 'max' || name === 'min') && i > 0) return s
                        return `${mslType(target)}(${s})`
                    }
                    return s
                })
                return `${name}(${out.join(', ')})`
            }
            case 'radians': return `(${args[0]} * 0.017453292519943295f)`
            case 'degrees': return `(${args[0]} * 57.29577951308232f)`
            case 'abs': case 'floor': case 'ceil': case 'fract': case 'sqrt': case 'exp': case 'exp2': case 'log': case 'log2': case 'sin': case 'cos': case 'tan': case 'asin': case 'acos': case 'atan': case 'sinh': case 'cosh': case 'tanh': case 'trunc': case 'saturate': case 'normalize': case 'length': case 'dot': case 'cross': case 'any': case 'all': case 'transpose': case 'determinant': case 'quantizeToF16':
                return `${name}(${args.join(', ')})`
        }
        throw new Error(`msl: unsupported call ${name}`)
    }

    private coordToUint2(coord: Expr): string {
        const t = exprType(coord)
        const s = this.expr(coord)
        if (t.kind === 'vec' && t.scalar === 'u32') return s
        return `uint2(${s})`
    }
}

/** `vec4<f32>` → `vec4f` etc., matching the TypeGPU schema names the descriptors use. */
export function shortTypeName(t: Type): string {
    return typeToString(t).replace(/vec([234])<f32>/g, 'vec$1f').replace(/vec([234])<i32>/g, 'vec$1i').replace(/vec([234])<u32>/g, 'vec$1u')
}

function floatLit(text: string): string {
    let t = text
    if (t.endsWith('f') || t.endsWith('h')) t = t.slice(0, -1)
    if (t.startsWith('.')) t = `0${t}`
    if (/^\d+$/.test(t)) t = `${t}.0`
    if (/\.$/.test(t)) t = `${t}0`
    if (/^\d+e/i.test(t)) t = t.replace(/^(\d+)e/i, '$1.0e')
    return `${t}f`
}

// lazy import to avoid a circular import at module-evaluation time
import * as printerMod from './printer.js'
function require_walk() {
    return printerMod
}

export {ident as mslIdent}
