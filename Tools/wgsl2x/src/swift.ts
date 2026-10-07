// Swift (CPU) emitter for a linked shader unit: fragment passes only. Used for the watchOS
// rasterizer and for CPU reference tests. Compute kernels are skipped.
import type {Block, ConstDecl, Expr, FnDecl, GlobalVar, Scalar, Stmt, StructDecl, Type} from './ast.js'
import {scalarOf, typeToString} from './ast.js'
import type {LinkUnit, LinkedPass} from './link.js'
import {exprType} from './types.js'
import {LayoutCalculator} from './layout.js'

const SWIFT_RESERVED = new Set([
    'associatedtype', 'class', 'deinit', 'enum', 'extension', 'fileprivate', 'func', 'import', 'init', 'inout', 'internal', 'let', 'open', 'operator',
    'private', 'precedencegroup', 'protocol', 'public', 'rethrows', 'static', 'struct', 'subscript', 'typealias', 'var', 'break', 'case', 'catch',
    'continue', 'default', 'defer', 'do', 'else', 'fallthrough', 'for', 'guard', 'if', 'in', 'repeat', 'return', 'throw', 'switch', 'where', 'while',
    'Any', 'as', 'await', 'false', 'is', 'nil', 'self', 'Self', 'super', 'throws', 'true', 'try', 'some', 'any', 'Type', 'Float', 'Int', 'Bool', 'min', 'max',
    'abs', 'floor', 'ceil', 'sqrt', 'pow', 'exp', 'log', 'sin', 'cos', 'tan', 'round', 'clamp', 'mix', 'step', 'fract', 'sign', 'length', 'normalize', 'dot',
    'cross', 'reflect', 'refract', 'distance', 'select', 'all', 'any', 'in', 'out', 'ctx', 'env', 'print', 'exp2', 'log2', 'atan2', 'fma',
])

function ident(name: string): string {
    return SWIFT_RESERVED.has(name) ? `${name}_` : name
}

function swiftScalar(s: Scalar): string {
    switch (s) {
        case 'f32': return 'Float'
        case 'i32': return 'Int32'
        case 'u32': return 'UInt32'
        case 'bool': return 'Bool'
    }
}

export function swiftType(t: Type): string {
    switch (t.kind) {
        case 'scalar': return swiftScalar(t.scalar)
        case 'vec': return t.scalar === 'bool' ? `SIMDMask<SIMD${t.n}<Int32>>` : `SIMD${t.n}<${swiftScalar(t.scalar)}>`
        case 'mat': return `simd_float${t.cols}x${t.rows}`
        case 'array': return `[${swiftType(t.elem)}]`
        case 'struct': return ident(t.name)
        case 'texture': return 'CPUTexture'
        case 'sampler': return 'CPUSampler'
        case 'atomic': return 'UInt32'
        case 'ptr': return swiftType(t.inner)
        case 'void': return 'Void'
    }
}

function zeroValue(t: Type): string {
    switch (t.kind) {
        case 'scalar': return t.scalar === 'bool' ? 'false' : '0'
        case 'vec': return t.scalar === 'bool' ? `${swiftType(t)}(repeating: false)` : `${swiftType(t)}()`
        case 'mat': return `${swiftType(t)}(0)`
        case 'array': return `[${swiftType(t.elem)}](repeating: ${zeroValue(t.elem)}, count: ${t.count ?? 0})`
        case 'struct': return `${ident(t.name)}()`
        default: return '0'
    }
}

export interface EmittedSwiftPass {
    variantIndex: number
    role: 'final' | 'rtt'
    textureKey: string | null
    entry: string
    textures: string[]
}
export interface EmittedSwiftUnit {
    source: string
    passes: EmittedSwiftPass[]
    supported: boolean
    reason?: string
}

/** Emits a function-only Swift enum (e.g. the blend/mask/tone kit) from a linked library unit. */
export function emitSwiftLibrary(unit: LinkUnit, enumName: string, extraBody: string): string {
    const em = new SwiftEmitter(unit)
    return em.emitLibrary(enumName, extraBody)
}

/** Emits the CPU implementation. Returns supported=false when a pass needs compute outputs. */
export function emitSwift(unit: LinkUnit): EmittedSwiftUnit {
    try {
        return new SwiftEmitter(unit).emit()
    } catch (e: any) {
        return {source: '', passes: [], supported: false, reason: e.message}
    }
}

class SwiftEmitter {
    private layout: LayoutCalculator
    constructor(private unit: LinkUnit) {
        this.layout = new LayoutCalculator(unit.env.structs, 'uniform')
    }

    private usesTexture(p: LinkedPass): boolean {
        return p.globals.some((g) => g.type.kind === 'texture')
    }

    emit(): EmittedSwiftUnit {
        const u = this.unit
        // compute-backed shaders read compute_* textures: not supported on the CPU
        for (const p of u.passes) {
            for (const g of p.globals) {
                if (g.name.startsWith('compute_') || g.name.startsWith('video_')) {
                    return {source: '', passes: [], supported: false, reason: `pass reads ${g.name}`}
                }
            }
        }
        const body: string[] = []
        for (const s of u.structs) if (!u.inputStructs.has(s.name)) body.push(this.emitStruct(s))
        for (const c of u.consts) body.push(this.emitConst(c))
        for (const f of u.fns) {
            if (!this.fnIsNeeded(f)) continue
            body.push(this.emitFn(f))
        }
        const passes: EmittedSwiftPass[] = []
        const entries: string[] = []
        for (const p of u.passes) {
            const {text, info} = this.emitPass(p)
            entries.push(text)
            passes.push(info)
        }
        const name = `CPU_${u.shader}`
        const source = [
            `// Generated by wgsl2x (CPU backend) from the shaders.com WGSL library — do not edit.`,
            `// Shader: ${u.shader}`,
            `import Foundation`,
            `import simd`,
            ``,
            `enum ${name}: CPUShaderProgram {`,
            indent(body.join('\n\n'), '    '),
            ``,
            indent(entries.join('\n\n'), '    '),
            ``,
            `    static let passes: [String: CPUPassFactory] = [`,
            ...passes.map((p) => `        "${p.entry}": ${p.entry},`),
            `    ]`,
            `}`,
            ``,
        ].join('\n')
        return {source, passes, supported: true}
    }

    emitLibrary(enumName: string, extraBody: string): string {
        const u = this.unit
        const body: string[] = []
        for (const s of u.structs) if (!u.inputStructs.has(s.name)) body.push(this.emitStruct(s))
        for (const c of u.consts) body.push(this.emitConst(c))
        for (const f of u.fns) body.push(this.emitFn(f))
        return [
            `// Generated by wgsl2x (CPU backend) from the shaders.com composition kit — do not edit.`,
            `import Foundation`,
            `import simd`,
            ``,
            `enum ${enumName} {`,
            indent(body.join('\n\n'), '    '),
            ``,
            indent(extraBody, '    '),
            `}`,
            ``,
        ].join('\n')
    }

    /** Functions only reachable from kernels are skipped (they may use atomics / storage). */
    private fnIsNeeded(f: FnDecl): boolean {
        if (!this.reachable) {
            const reach = new Set<string>()
            const visit = (fn: FnDecl) => {
                for (const c of this.calledNames(fn)) {
                    if (!reach.has(c)) {
                        reach.add(c)
                        const decl = this.unit.fns.find((x) => x.name === c)
                        if (decl) visit(decl)
                    }
                }
            }
            for (const p of this.unit.passes) visit(p.entry)
            this.reachable = reach
        }
        return this.reachable.has(f.name)
    }
    private reachable: Set<string> | null = null

    private calledNames(f: FnDecl): Set<string> {
        const out = new Set<string>()
        const walkE = (e: Expr) => {
            if (e.kind === 'call' && this.unit.env.fns.has(e.callee)) out.add(e.callee)
            switch (e.kind) {
                case 'paren': walkE(e.expr); break
                case 'unary': walkE(e.expr); break
                case 'binary': walkE(e.left); walkE(e.right); break
                case 'member': walkE(e.obj); break
                case 'index': walkE(e.obj); walkE(e.index); break
                case 'call': e.args.forEach(walkE); break
            }
        }
        const walkS = (s: Stmt) => {
            switch (s.kind) {
                case 'let': case 'const': walkE(s.init); break
                case 'var': if (s.init) walkE(s.init); break
                case 'assign': walkE(s.target); walkE(s.value); break
                case 'incdec': walkE(s.target); break
                case 'expr': case 'phony': walkE(s.expr); break
                case 'return': if (s.expr) walkE(s.expr); break
                case 'if': walkE(s.cond); s.then.forEach(walkS); if (s.else) {if (Array.isArray(s.else)) s.else.forEach(walkS); else walkS(s.else)} break
                case 'for': if (s.init) walkS(s.init); if (s.cond) walkE(s.cond); if (s.update) walkS(s.update); s.body.forEach(walkS); break
                case 'while': walkE(s.cond); s.body.forEach(walkS); break
                case 'loop': s.body.forEach(walkS); break
                case 'switch': walkE(s.selector); s.cases.forEach((c) => {c.values?.forEach(walkE); c.body.forEach(walkS)}); break
                case 'block': s.body.forEach(walkS); break
            }
        }
        f.body.forEach(walkS)
        return out
    }

    // ───────── declarations ─────────
    private emitStruct(s: StructDecl): string {
        const lines = [`struct ${ident(s.name)} {`]
        for (const m of s.members) lines.push(`    var ${ident(m.name)}: ${swiftType(m.type)} = ${zeroValue(m.type)}`)
        lines.push(`    init() {}`)
        lines.push(`    init(${s.members.map((m) => `_ ${ident(m.name)}: ${swiftType(m.type)}`).join(', ')}) {`)
        for (const m of s.members) lines.push(`        self.${ident(m.name)} = ${ident(m.name)}`)
        lines.push(`    }`)
        if (this.unit.hostShareable.has(s.name)) {
            // decode from the packed WGSL uniform layout
            const l = this.layout.structLayout(s.name)
            lines.push(`    init(sk_raw p: UnsafeRawPointer, at base: Int) {`)
            s.members.forEach((m, i) => {
                const off = l.fields[i].offset
                lines.push(`        ${ident(m.name)} = ${this.loadExpr(m.type, `(base + ${off})`)}`)
            })
            lines.push(`    }`)
        }
        lines.push(`}`)
        return lines.join('\n')
    }

    private loadExpr(t: Type, offset: string): string {
        switch (t.kind) {
            case 'scalar': return t.scalar === 'f32' ? `sk_loadF32(p, ${offset})` : t.scalar === 'i32' ? `sk_loadI32(p, ${offset})` : t.scalar === 'u32' ? `sk_loadU32(p, ${offset})` : `(sk_loadU32(p, ${offset}) != 0)`
            case 'vec': return t.n === 2 ? `sk_loadV2(p, ${offset})` : t.n === 3 ? `sk_loadV3(p, ${offset})` : `sk_loadV4(p, ${offset})`
            case 'struct': return `${ident(t.name)}(sk_raw: p, at: ${offset})`
            case 'array': {
                const stride = this.layout.arrayStride(t.elem)
                return `(0..<${t.count ?? 0}).map { sk_i in ${this.loadExpr(t.elem, `${offset} + sk_i * ${stride}`)} }`
            }
            default: return zeroValue(t)
        }
    }

    private emitConst(c: ConstDecl): string {
        const t = c.type ?? exprType(c.init)
        return `static let ${ident(c.name)}: ${swiftType(t)} = ${this.coerce(c.init, t)}`
    }

    private captureParams(fnName: string): string[] {
        return (this.unit.captures.get(fnName) ?? []).map((g) => `${ident(g)}: ${this.globalParamType(this.unit.globalDecls.get(g)!)}`)
    }
    private captureArgs(fnName: string): string[] {
        return (this.unit.captures.get(fnName) ?? []).map((g) => `${ident(g)}: ${ident(g)}`)
    }
    private globalParamType(g: GlobalVar): string {
        return swiftType(g.type)
    }

    /** Names assigned / incremented / passed by pointer in the current function body. */
    private mutated = new Set<string>()
    /** Identifier read counts in the current function body. */
    private reads = new Map<string, number>()

    private analyzeBody(body: Block) {
        this.mutated = new Set()
        this.reads = new Map()
        const baseName = (e: Expr): string | null => {
            switch (e.kind) {
                case 'ident': return e.name
                case 'paren': return baseName(e.expr)
                case 'member': return baseName(e.obj)
                case 'index': return baseName(e.obj)
                case 'unary': return e.op === '*' || e.op === '&' ? baseName(e.expr) : null
                default: return null
            }
        }
        const walkE = (e: Expr) => {
            switch (e.kind) {
                case 'ident': this.reads.set(e.name, (this.reads.get(e.name) ?? 0) + 1); break
                case 'paren': walkE(e.expr); break
                case 'unary': if (e.op === '&') {const b = baseName(e.expr); if (b) this.mutated.add(b)} walkE(e.expr); break
                case 'binary': walkE(e.left); walkE(e.right); break
                case 'member': walkE(e.obj); break
                case 'index': walkE(e.obj); walkE(e.index); break
                case 'call': {
                    const sig = this.unit.env.fns.get(e.callee)
                    e.args.forEach((a, i) => {
                        if (sig?.params[i]?.kind === 'ptr') {const b = baseName(a); if (b) this.mutated.add(b)}
                        walkE(a)
                    })
                    break
                }
            }
        }
        const walkS = (s: Stmt) => {
            switch (s.kind) {
                case 'let': case 'const': walkE(s.init); break
                case 'var': if (s.init) walkE(s.init); break
                case 'assign': {const b = baseName(s.target); if (b) this.mutated.add(b); walkE(s.target); walkE(s.value); break}
                case 'incdec': {const b = baseName(s.target); if (b) this.mutated.add(b); walkE(s.target); break}
                case 'expr': case 'phony': walkE(s.expr); break
                case 'return': if (s.expr) walkE(s.expr); break
                case 'if': walkE(s.cond); s.then.forEach(walkS); if (s.else) {if (Array.isArray(s.else)) s.else.forEach(walkS); else walkS(s.else)} break
                case 'for': if (s.init) walkS(s.init); if (s.cond) walkE(s.cond); if (s.update) walkS(s.update); s.body.forEach(walkS); break
                case 'while': walkE(s.cond); s.body.forEach(walkS); break
                case 'loop': s.body.forEach(walkS); if (s.continuing) s.continuing.forEach(walkS); break
                case 'switch': walkE(s.selector); s.cases.forEach((c) => {c.values?.forEach(walkE); c.body.forEach(walkS)}); break
                case 'block': s.body.forEach(walkS); break
            }
        }
        body.forEach(walkS)
    }

    private emitFn(f: FnDecl): string {
        this.analyzeBody(f.body)
        const params = [...f.params.map((p) => `_ ${ident(p.name)}: ${this.paramType(p.type)}`), ...this.captureParams(f.name)]
        const ret = f.ret.kind === 'void' ? '' : ` -> ${swiftType(f.ret)}`
        // WGSL params are immutable; Swift params are too. Pointer params become inout.
        return `@inline(__always) static func ${ident(f.name)}(${params.join(', ')})${ret} ${this.block(f.body, '')}`
    }

    private paramType(t: Type): string {
        if (t.kind === 'ptr') return `inout ${swiftType(t.inner)}`
        return swiftType(t)
    }

    private emitPass(p: LinkedPass): {text: string; info: EmittedSwiftPass} {
        this.analyzeBody(p.entry.body)
        const textures = p.globals.filter((g) => g.type.kind === 'texture').map((g) => g.name)
        const inParam = p.entry.params[0]?.name ?? 'in'
        const lines: string[] = []
        lines.push(`static func ${p.entry.name}(_ env: CPUPassEnvironment) -> CPUPixelFunction {`)
        for (const g of p.globals) {
            if (g.space === 'uniform' && g.type.kind === 'struct') lines.push(`    let ${ident(g.name)} = ${ident(g.type.name)}(sk_raw: env.uniformBytes, at: 0)`)
            else if (g.type.kind === 'texture') lines.push(`    let ${ident(g.name)} = env.texture("${g.name}")`)
            else if (g.type.kind === 'sampler') lines.push(`    let ${ident(g.name)} = CPUSampler.${g.name}`)
        }
        lines.push(`    return { ctx in`)
        lines.push(`        let ${ident(inParam)} = ctx.input`)
        lines.push(indent(this.blockBody(p.entry.body, ''), '        '))
        lines.push(`    }`)
        lines.push(`}`)
        return {text: lines.join('\n'), info: {variantIndex: p.variantIndex, role: p.role, textureKey: p.textureKey, entry: p.entry.name, textures}}
    }

    // ───────── statements ─────────
    private block(b: Block, ind: string): string {
        return `{\n${this.blockBody(b, ind + '    ')}\n${ind}}`
    }
    private blockBody(b: Block, ind: string): string {
        return b.map((s) => this.stmt(s, ind)).join('\n')
    }

    // Swift's type checker chokes on long arithmetic chains: statements hoist large
    // sub-expressions into explicitly typed temporaries first.
    private hoisted: string[] = []
    private hoistInd = ''
    private tempCounter = 0

    private withHoisting(ind: string, body: () => string): string {
        const prevH = this.hoisted
        const prevI = this.hoistInd
        this.hoisted = []
        this.hoistInd = ind
        const main = body()
        const lines = [...this.hoisted, main]
        this.hoisted = prevH
        this.hoistInd = prevI
        return lines.join('\n')
    }

    private complexity(e: Expr): number {
        switch (e.kind) {
            case 'paren': return this.complexity(e.expr)
            case 'unary': return 1 + this.complexity(e.expr)
            case 'binary': return 1 + this.complexity(e.left) + this.complexity(e.right)
            case 'member': return this.complexity(e.obj)
            case 'index': return 1 + this.complexity(e.obj) + this.complexity(e.index)
            case 'call': return 1 + e.args.reduce((a, x) => a + this.complexity(x), 0)
            default: return 0
        }
    }

    /** Emits `e`, hoisting heavy operands into temporaries so each remaining expression stays small. */
    private hoistIfNeeded(e: Expr): string {
        const LIMIT = 6
        if (this.complexity(e) <= LIMIT) return this.expr(e)
        if (e.kind === 'paren') return this.hoistIfNeeded(e.expr)
        if (e.kind === 'binary') {
            // hoist both operands when they are themselves heavy
            const l = this.complexity(e.left) > 2 ? this.hoistToTemp(e.left) : e.left
            const r = this.complexity(e.right) > 2 ? this.hoistToTemp(e.right) : e.right
            return this.expr({...e, left: l, right: r})
        }
        if (e.kind === 'call') {
            const args = e.args.map((a) => (this.complexity(a) > 2 ? this.hoistToTemp(a) : a))
            return this.expr({...e, args})
        }
        if (e.kind === 'unary') {
            return this.expr({...e, expr: this.hoistToTemp(e.expr)})
        }
        return this.expr(e)
    }

    /** Emits `e` into a temporary (recursively hoisting) and returns an identifier expression for it. */
    private hoistToTemp(e: Expr): Expr {
        const t = exprType(e)
        if (t.kind === 'ptr' || t.kind === 'void') return e
        const name = `sk_t${this.tempCounter++}`
        const value = this.hoistIfNeeded(e)
        this.hoisted.push(`${this.hoistInd}let ${name}: ${swiftType(t)} = ${value}`)
        return {kind: 'ident', name, type: t}
    }

    private stmt(s: Stmt, ind: string): string {
        return this.withHoisting(ind, () => this.stmtInner(s, ind))
    }

    private stmtInner(s: Stmt, ind: string): string {
        switch (s.kind) {
            case 'let': case 'const': {
                const t = s.type ?? exprType(s.init)
                const used = (this.reads.get(s.name) ?? 0) > 0
                if (t.kind === 'ptr') {
                    // `let p = &x` → alias the pointee for reads (uniform/storage data is read-only in fragments)
                    if (!used) return `${ind}// unused pointer alias ${s.name}`
                    return `${ind}let ${ident(s.name)} = ${this.expr(stripAddressOf(s.init))}`
                }
                if (!used) return `${ind}_ = ${this.coerceHoisted(s.init, t)}`
                return `${ind}let ${ident(s.name)}: ${swiftType(t)} = ${this.coerceHoisted(s.init, t)}`
            }
            case 'var': {
                const t = s.type ?? (s.init ? exprType(s.init) : null)
                if (!t) throw new Error('var without type')
                const used = (this.reads.get(s.name) ?? 0) > 0
                const mutated = this.mutated.has(s.name)
                if (!used && !mutated) return s.init ? `${ind}_ = ${this.coerceHoisted(s.init, t)}` : `${ind}// unused var ${s.name}`
                const kw = mutated ? 'var' : 'let'
                return `${ind}${kw} ${ident(s.name)}: ${swiftType(t)} = ${s.init ? this.coerceHoisted(s.init, t) : zeroValue(t)}`
            }
            case 'assign': {
                const tt = exprType(s.target)
                const target = this.expr(s.target)
                if (s.op === '=') return `${ind}${target} = ${this.coerceHoisted(s.value, tt)}`
                const op = s.op.slice(0, -1)
                return `${ind}${target} = ${this.binaryOp(op, target, this.coerceHoisted(s.value, tt), tt, tt, tt)}`
            }
            case 'incdec': {
                const tt = exprType(s.target)
                const target = this.expr(s.target)
                return `${ind}${target} = ${target} ${s.op === '++' ? '&+' : '&-'} 1`
            }
            case 'expr': return `${ind}_ = ${this.hoistIfNeeded(s.expr)}`
            case 'phony': return `${ind}_ = ${this.hoistIfNeeded(s.expr)}`
            case 'return': return `${ind}return${s.expr ? ` ${this.hoistIfNeeded(s.expr)}` : ''}`
            case 'if': {
                let out = `${ind}if ${this.hoistIfNeeded(s.cond)} ${this.block(s.then, ind)}`
                if (s.else) {
                    if (Array.isArray(s.else)) out += ` else ${this.block(s.else, ind)}`
                    else out += ` else ${this.stmt(s.else, ind).trimStart()}`
                }
                return out
            }
            case 'for': {
                // for (init; cond; update) body  →  init; while cond { body; update }
                const lines: string[] = [`${ind}do {`]
                if (s.init) lines.push(this.stmt(s.init, ind + '    '))
                lines.push(`${ind}    while ${s.cond ? this.expr(s.cond) : 'true'} {`)
                lines.push(this.blockBody(s.body, ind + '        '))
                if (s.update) lines.push(this.stmt(s.update, ind + '        '))
                lines.push(`${ind}    }`)
                lines.push(`${ind}}`)
                if (hasContinue(s.body)) {
                    // `continue` must still run the update: emit the update inside a labeled loop
                    return this.forWithContinue(s, ind)
                }
                return lines.join('\n')
            }
            case 'while': return `${ind}while ${this.expr(s.cond)} ${this.block(s.body, ind)}`
            case 'loop': return `${ind}while true ${this.block(s.body, ind)}`
            case 'switch': {
                const cases = s.cases.map((c) => {
                    const label = c.values ? `case ${c.values.map((v) => this.expr(v)).join(', ')}:` : 'default:'
                    return `${ind}${label}\n${this.blockBody(c.body, ind + '    ')}${c.body.length ? '' : `\n${ind}    break`}`
                })
                return `${ind}switch ${this.expr(s.selector)} {\n${cases.join('\n')}\n${ind}}`
            }
            case 'break': return `${ind}break`
            case 'continue': return `${ind}continue`
            case 'discard': return `${ind}return SIMD4<Float>()`
            case 'block': return `${ind}do ${this.block(s.body, ind)}`
        }
    }

    private forWithContinue(s: Stmt & {kind: 'for'}, ind: string): string {
        const lines: string[] = [`${ind}do {`]
        if (s.init) lines.push(this.stmt(s.init, ind + '    '))
        lines.push(`${ind}    var sk_first = true`)
        lines.push(`${ind}    while true {`)
        lines.push(`${ind}        if !sk_first {`)
        if (s.update) lines.push(this.stmt(s.update, ind + '            '))
        lines.push(`${ind}        }`)
        lines.push(`${ind}        sk_first = false`)
        if (s.cond) lines.push(`${ind}        if !(${this.expr(s.cond)}) { break }`)
        lines.push(this.blockBody(s.body, ind + '        '))
        lines.push(`${ind}    }`)
        lines.push(`${ind}}`)
        return lines.join('\n')
    }

    // ───────── expressions ─────────
    private coerce(e: Expr, target: Type): string {
        const t = exprType(e)
        const s = this.expr(e)
        if (t.kind === 'scalar' && t.abstract && target.kind === 'scalar' && target.scalar !== t.scalar) {
            if (target.scalar === 'f32' && e.kind === 'int') return `${e.value.toString()}.0`
            return `${swiftType(target)}(${s})`
        }
        if (t.kind === 'scalar' && target.kind === 'vec' && target.scalar !== 'bool') return `${swiftType(target)}(repeating: ${s})`
        return s
    }

    private coerceHoisted(e: Expr, target: Type): string {
        const t = exprType(e)
        if (t.kind === 'scalar' && t.abstract && target.kind === 'scalar' && target.scalar !== t.scalar) return this.coerce(e, target)
        if (t.kind === 'scalar' && target.kind === 'vec' && target.scalar !== 'bool') return `${swiftType(target)}(repeating: ${this.hoistIfNeeded(e)})`
        return this.hoistIfNeeded(e)
    }

    expr(e: Expr): string {
        switch (e.kind) {
            case 'ident': return ident(e.name)
            case 'int': {
                const t = exprType(e)
                const v = e.value.toString()
                if (t.kind === 'scalar' && t.scalar === 'f32') return `${v}.0`
                return v
            }
            case 'float': return floatLit(e.text)
            case 'bool': return e.value ? 'true' : 'false'
            case 'paren': return `(${this.expr(e.expr)})`
            case 'unary': {
                const t = exprType(e.expr)
                const inner = this.expr(e.expr)
                switch (e.op) {
                    case '-': return `(-${inner})`
                    case '!': return t.kind === 'vec' ? `(.!${inner})` : `(!${inner})`
                    case '~': return `(~${inner})`
                    default: return inner
                }
            }
            case 'binary': return this.binary(e)
            case 'member': {
                const ot = exprType(e.obj)
                const base = ot.kind === 'ptr' ? ot.inner : ot
                const o = this.expr(e.obj)
                if (base.kind === 'vec') return this.swizzle(o, e.name, base)
                return `${o}.${ident(e.name)}`
            }
            case 'index': {
                const ot = exprType(e.obj)
                const it = exprType(e.index)
                const idx = scalarOf(it) === 'i32' || scalarOf(it) === 'u32' || (it.kind === 'scalar' && it.abstract) ? `Int(${this.expr(e.index)})` : this.expr(e.index)
                const base = ot.kind === 'ptr' ? ot.inner : ot
                if (base.kind === 'vec') return `${this.expr(e.obj)}[${idx}]`
                return `${this.expr(e.obj)}[${idx}]`
            }
            case 'call': return this.call(e)
        }
    }

    private swizzle(o: string, sw: string, base: Type & {kind: 'vec'}): string {
        const map: Record<string, number> = {x: 0, y: 1, z: 2, w: 3, r: 0, g: 1, b: 2, a: 3}
        const idx = [...sw].map((c) => map[c])
        const comp = ['x', 'y', 'z', 'w']
        if (idx.length === 1) return `${o}.${comp[idx[0]]}`
        if (base.scalar === 'bool') {
            return `SIMDMask<SIMD${idx.length}<Int32>>(SIMD${idx.length}<Int32>(${idx.map((i) => `${o}[${i}] ? -1 : 0`).join(', ')}))`
        }
        // use a temporary when `o` is not a simple identifier to avoid repeated evaluation
        if (/^[A-Za-z_][A-Za-z0-9_.]*$/.test(o)) return `SIMD${idx.length}<${swiftScalar(base.scalar)}>(${idx.map((i) => `${o}.${comp[i]}`).join(', ')})`
        return `sk_swz${idx.length}(${o}, ${idx.join(', ')})`
    }

    private binaryOp(op: string, l: string, r: string, lt: Type, rt: Type, outT: Type): string {
        const isInt = (t: Type) => scalarOf(t) === 'i32' || scalarOf(t) === 'u32'
        const outScalar = scalarOf(outT)
        switch (op) {
            case '+': case '-': case '*':
                if (isInt(outT)) return `(${l} &${op} ${r})`
                return `(${l} ${op} ${r})`
            case '/':
                if (isInt(outT)) return `sk_idiv(${l}, ${r})`
                return `(${l} / ${r})`
            case '%':
                if (isInt(outT)) return `sk_imod(${l}, ${r})`
                return `sk_fmod(${l}, ${r})`
            case '<<': return `(${l} &<< ${r})`
            case '>>': return `(${l} &>> ${r})`
            case '&': case '|': case '^':
                if (outScalar === 'bool' && outT.kind === 'scalar') return op === '&' ? `(${l} && ${r})` : op === '|' ? `(${l} || ${r})` : `(${l} != ${r})`
                if (outT.kind === 'vec' && outT.scalar === 'bool') return `(${l} .${op} ${r})`
                return `(${l} ${op} ${r})`
            case '==': case '!=': case '<': case '>': case '<=': case '>=':
                if (lt.kind === 'vec' || rt.kind === 'vec') return `(${l} .${op} ${r})`
                return `(${l} ${op} ${r})`
            case '&&': return `(${l} && ${r})`
            case '||': return `(${l} || ${r})`
        }
        return `(${l} ${op} ${r})`
    }

    private binary(e: Expr & {kind: 'binary'}): string {
        const lt = exprType(e.left)
        const rt = exprType(e.right)
        const outT = exprType(e)
        let l = this.expr(e.left)
        let r = this.expr(e.right)
        // abstract literals take the other side's type
        if (lt.kind === 'scalar' && lt.abstract && !(rt.kind === 'scalar' && rt.abstract)) {
            const target = scalarOf(rt)
            if (target && target !== lt.scalar) l = this.coerce(e.left, {kind: 'scalar', scalar: target})
        }
        if (rt.kind === 'scalar' && rt.abstract && !(lt.kind === 'scalar' && lt.abstract)) {
            const target = scalarOf(lt)
            if (target && target !== rt.scalar) r = this.coerce(e.right, {kind: 'scalar', scalar: target})
        }
        // scalar ⊕ vector: Swift SIMD supports scalar operands for + - * / but not comparisons / fmod
        const cmp = ['==', '!=', '<', '>', '<=', '>=', '%'].includes(e.op)
        if (cmp && outT.kind === 'vec' || (e.op === '%' && (lt.kind === 'vec' || rt.kind === 'vec'))) {
            const vt: Type = lt.kind === 'vec' ? lt : rt.kind === 'vec' ? rt : outT
            if (lt.kind !== 'vec') l = `${swiftType(vt)}(repeating: ${l})`
            if (rt.kind !== 'vec') r = `${swiftType(vt)}(repeating: ${r})`
        }
        // matrix * vector
        if (lt.kind === 'mat' || rt.kind === 'mat') return `(${l} * ${r})`
        return this.binaryOp(e.op, l, r, lt, rt, outT)
    }

    private call(e: Expr & {kind: 'call'}): string {
        const name = e.callee
        const env = this.unit.env
        const argT = e.args.map((a) => exprType(a))
        const args = e.args.map((a) => this.expr(a))
        const rt = exprType(e)
        if (env.fns.has(name)) {
            const sig = env.fns.get(name)!
            const coerced = e.args.map((a, i) => {
                const pt = sig.params[i]
                if (pt && pt.kind === 'ptr') return `&${this.expr(stripAddressOf(a))}`
                return this.coerce(a, pt ?? exprType(a))
            })
            return `${ident(name)}(${[...coerced, ...this.captureArgs(name)].join(', ')})`
        }
        if (env.structs.has(name)) {
            if (args.length === 0) return `${ident(name)}()`
            const s = env.structs.get(name)!
            return `${ident(name)}(${e.args.map((a, i) => this.coerce(a, s.members[i].type)).join(', ')})`
        }
        if (/^vec[234][fiu]?$/.test(name) || /^vec[234]$/.test(name)) return this.vecCtor(e, rt as Type & {kind: 'vec'})
        if (/^mat[234]x[234]f$/.test(name)) {
            const m = rt as Type & {kind: 'mat'}
            const cols: string[] = []
            for (let c = 0; c < m.cols; c++) cols.push(`SIMD${m.rows}<Float>(${e.args.slice(c * m.rows, (c + 1) * m.rows).map((a) => this.coerce(a, {kind: 'scalar', scalar: 'f32'})).join(', ')})`)
            return `${swiftType(m)}(${cols.join(', ')})`
        }
        if (name === 'array') {
            const at = rt as Type & {kind: 'array'}
            if (args.length === 0) return zeroValue(at)
            return `[${e.args.map((a) => this.coerce(a, at.elem)).join(', ')}]`
        }
        switch (name) {
            case 'f32': {
                const a = argT[0]
                if (a.kind === 'vec') return a.scalar === 'f32' ? args[0] : `SIMD${a.n}<Float>(${args[0]})`
                if (a.kind === 'scalar' && a.scalar === 'bool') return `(${args[0]} ? Float(1) : Float(0))`
                if (a.kind === 'scalar' && a.scalar === 'f32' && !a.abstract) return args[0]
                return `Float(${args[0]})`
            }
            case 'i32': return argT[0].kind === 'vec' ? `sk_i32(${args[0]})` : `sk_i32(${args[0]})`
            case 'u32': return `sk_u32(${args[0]})`
            case 'bool': return argT[0].kind === 'vec' ? `(${args[0]} .!= ${swiftType(argT[0])}())` : `(${args[0]} != 0)`
            case 'bitcast': {
                const target = rt
                const src = argT[0]
                const ts = scalarOf(target)
                const ss = scalarOf(src)
                if (target.kind === 'scalar' && src.kind === 'scalar') {
                    if (ts === 'u32' && ss === 'f32') return `${args[0]}.bitPattern`
                    if (ts === 'i32' && ss === 'f32') return `Int32(bitPattern: ${args[0]}.bitPattern)`
                    if (ts === 'f32' && ss === 'u32') return `Float(bitPattern: ${args[0]})`
                    if (ts === 'f32' && ss === 'i32') return `Float(bitPattern: UInt32(bitPattern: ${args[0]}))`
                    if (ts === 'u32' && ss === 'i32') return `UInt32(bitPattern: ${args[0]})`
                    if (ts === 'i32' && ss === 'u32') return `Int32(bitPattern: ${args[0]})`
                    return args[0]
                }
                return `unsafeBitCast(${args[0]}, to: ${swiftType(target)}.self)`
            }
            case 'select': {
                const target = rt
                const f = this.coerce(e.args[0], target)
                const t = this.coerce(e.args[1], target)
                if (argT[2].kind === 'vec') return `${f}.replacing(with: ${t}, where: ${args[2]})`
                return `(${args[2]} ? ${t} : ${f})`
            }
            case 'textureSample': case 'textureSampleBaseClampToEdge': return `${args[0]}.sample(${args[1]}, ${args[2]})`
            case 'textureSampleLevel': return `${args[0]}.sample(${args[1]}, ${args[2]})`
            case 'textureLoad': return `${args[0]}.load(${args[1]})`
            case 'textureDimensions': return `${args[0]}.dimensions`
            case 'inverseSqrt': return `sk_rsqrt(${args[0]})`
            case 'dpdx': case 'dpdxCoarse': case 'dpdxFine': return `sk_dpdx(${args[0]})`
            case 'dpdy': case 'dpdyCoarse': case 'dpdyFine': return `sk_dpdy(${args[0]})`
            case 'fwidth': case 'fwidthCoarse': case 'fwidthFine': return `sk_fwidth(${args[0]})`
            case 'radians': return `(${args[0]} * 0.017453292519943295)`
            case 'degrees': return `(${args[0]} * 57.29577951308232)`
            case 'countOneBits': return `UInt32(${args[0]}.nonzeroBitCount)`
            case 'reverseBits': return `sk_reverseBits(${args[0]})`
            case 'extractBits': return `sk_extractBits(${args[0]}, ${args[1]}, ${args[2]})`
            case 'any': return `any(${args[0]})`
            case 'all': return `all(${args[0]})`
            case 'round': return `sk_round(${args[0]})`
            case 'sign': return `sk_sign(${args[0]})`
            case 'atan2': return `sk_atan2(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)})`
            case 'mix': return `sk_mix(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)}, ${argT[2].kind === 'vec' ? args[2] : this.coerce(e.args[2], {kind: 'scalar', scalar: 'f32'})})`
            case 'clamp': return `sk_clamp(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)}, ${this.promote(e.args[2], rt)})`
            case 'smoothstep': return `sk_smoothstep(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)}, ${this.promote(e.args[2], rt)})`
            case 'step': return `sk_step(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)})`
            case 'max': return `sk_max(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)})`
            case 'min': return `sk_min(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)})`
            case 'pow': return `sk_pow(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)})`
            case 'fma': return `sk_fma(${this.promote(e.args[0], rt)}, ${this.promote(e.args[1], rt)}, ${this.promote(e.args[2], rt)})`
            case 'reflect': return `sk_reflect(${args[0]}, ${args[1]})`
            case 'refract': return `sk_refract(${args[0]}, ${args[1]}, ${this.coerce(e.args[2], {kind: 'scalar', scalar: 'f32'})})`
            case 'distance': return `sk_distance(${args[0]}, ${args[1]})`
            case 'abs': case 'floor': case 'ceil': case 'fract': case 'sqrt': case 'exp': case 'exp2': case 'log': case 'log2': case 'sin': case 'cos': case 'tan': case 'asin': case 'acos': case 'atan': case 'sinh': case 'cosh': case 'tanh': case 'trunc': case 'saturate': case 'normalize': case 'length': case 'dot': case 'cross': case 'transpose': case 'determinant':
                return `sk_${name}(${args.join(', ')})`
            case 'quantizeToF16': return args[0]
        }
        throw new Error(`swift: unsupported call ${name}`)
    }

    /** Scalar → vector splat when the builtin's result is a vector (WGSL allows mixed scalar/vector). */
    private promote(a: Expr, rt: Type): string {
        const t = exprType(a)
        if (rt.kind === 'vec' && t.kind !== 'vec') return `${swiftType(rt)}(repeating: ${this.coerce(a, {kind: 'scalar', scalar: rt.scalar})})`
        return this.coerce(a, rt)
    }

    private vecCtor(e: Expr & {kind: 'call'}, vt: Type & {kind: 'vec'}): string {
        const tn = swiftType(vt)
        const argT = e.args.map((a) => exprType(a))
        if (e.args.length === 0) return vt.scalar === 'bool' ? `${tn}(repeating: false)` : `${tn}()`
        if (e.args.length === 1) {
            const t = argT[0]
            if (t.kind === 'vec') {
                if (t.scalar === vt.scalar) return this.expr(e.args[0])
                if (vt.scalar === 'i32') return `sk_i32(${this.expr(e.args[0])})`
                if (vt.scalar === 'u32') return `sk_u32(${this.expr(e.args[0])})`
                return `${tn}(${this.expr(e.args[0])})`
            }
            return `${tn}(repeating: ${this.coerce(e.args[0], {kind: 'scalar', scalar: vt.scalar})})`
        }
        // component-wise mix of scalars and vectors
        const parts: string[] = []
        const temps: string[] = []
        e.args.forEach((a, i) => {
            const t = argT[i]
            if (t.kind === 'vec') {
                let s = this.expr(a)
                if (!/^[A-Za-z_][A-Za-z0-9_.]*$/.test(s)) {
                    // hoist complex vector args via helper to avoid double evaluation
                    s = `sk_tmp(${s})`
                }
                for (let c = 0; c < t.n; c++) parts.push(`${s}${['.x', '.y', '.z', '.w'][c]}`)
            } else {
                parts.push(this.coerce(a, {kind: 'scalar', scalar: vt.scalar}))
            }
        })
        void temps
        return `${tn}(${parts.join(', ')})`
    }
}

function stripAddressOf(e: Expr): Expr {
    if (e.kind === 'paren') return stripAddressOf(e.expr)
    if (e.kind === 'unary' && e.op === '&') return e.expr
    return e
}

function hasContinue(b: Block): boolean {
    const walk = (s: Stmt): boolean => {
        switch (s.kind) {
            case 'continue': return true
            case 'if': return s.then.some(walk) || (s.else ? (Array.isArray(s.else) ? s.else.some(walk) : walk(s.else)) : false)
            case 'block': return s.body.some(walk)
            case 'switch': return s.cases.some((c) => c.body.some(walk))
            default: return false // nested loops own their continues
        }
    }
    return b.some(walk)
}

function indent(s: string, ind: string): string {
    return s.split('\n').map((l) => (l.length ? ind + l : l)).join('\n')
}

function floatLit(text: string): string {
    let t = text
    if (t.endsWith('f') || t.endsWith('h')) t = t.slice(0, -1)
    if (t.startsWith('.')) t = `0${t}`
    if (/^\d+$/.test(t)) t = `${t}.0`
    if (/\.$/.test(t)) t = `${t}0`
    if (/^\d+e/i.test(t)) t = t.replace(/^(\d+)e/i, '$1.0e')
    return t
}
