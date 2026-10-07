// Type inference for the parsed WGSL subset. Annotates every Expr with `.type`.
import type {Block, Expr, FnDecl, Module, Scalar, Stmt, StructDecl, Type} from './ast.js'
import {BOOL, F32, I32, U32, VOID, scalarOf, typeToString, vec, vecLen} from './ast.js'

export interface FnSig {
    params: Type[]
    ret: Type
}

export class ModuleEnv {
    structs = new Map<string, StructDecl>()
    fns = new Map<string, FnSig>()
    globals = new Map<string, Type>()
    consts = new Map<string, Type>()

    constructor(mod?: Module) {
        if (mod) this.addModule(mod)
    }

    addModule(mod: Module) {
        for (const it of mod.items) {
            if (it.kind === 'struct') this.structs.set(it.name, it)
            else if (it.kind === 'fn') this.fns.set(it.name, {params: it.params.map((p) => p.type), ret: it.ret})
            else if (it.kind === 'global') this.globals.set(it.name, it.type)
        }
        // consts need expression typing; done lazily in inferModule
    }

    memberType(structName: string, member: string): Type {
        const s = this.structs.get(structName)
        if (!s) throw new Error(`type: unknown struct ${structName}`)
        const m = s.members.find((x) => x.name === member)
        if (!m) throw new Error(`type: struct ${structName} has no member ${member}`)
        return m.type
    }
}

export class Scope {
    private vars = new Map<string, Type>()
    constructor(public parent: Scope | null, public env: ModuleEnv) {}
    declare(name: string, t: Type) {this.vars.set(name, t)}
    lookup(name: string): Type | null {
        let s: Scope | null = this
        while (s) {
            const t = s.vars.get(name)
            if (t) return t
            s = s.parent
        }
        return this.env.globals.get(name) ?? this.env.consts.get(name) ?? null
    }
    child(): Scope {return new Scope(this, this.env)}
}

const SWIZZLE = /^[xyzw]{1,4}$|^[rgba]{1,4}$/

function concretize(t: Type): Type {
    if (t.kind === 'scalar' && t.abstract) return {kind: 'scalar', scalar: t.scalar}
    return t
}

/** Result type of a binary arithmetic op given operand types (scalar/vector promotion). */
export function arithmeticResult(l: Type, r: Type): Type {
    if (l.kind === 'vec' && r.kind === 'vec') return l
    if (l.kind === 'vec') return l
    if (r.kind === 'vec') return r
    if (l.kind === 'mat' || r.kind === 'mat') return l.kind === 'mat' ? l : r
    if (l.kind === 'scalar' && r.kind === 'scalar') {
        if (l.abstract && !r.abstract) return r
        if (r.abstract && !l.abstract) return l
        if (l.abstract && r.abstract) {
            // abstract int op abstract float → float
            if (l.scalar === 'f32' || r.scalar === 'f32') return {kind: 'scalar', scalar: 'f32', abstract: true}
            return l
        }
        return l
    }
    return l
}

function boolVecLike(t: Type): Type {
    if (t.kind === 'vec') return vec(t.n, 'bool')
    return BOOL
}

export function inferModule(mod: Module, env?: ModuleEnv): ModuleEnv {
    const e = env ?? new ModuleEnv()
    e.addModule(mod)
    for (const it of mod.items) {
        if (it.kind === 'const') {
            const sc = new Scope(null, e)
            const inferred = concretize(inferExpr(it.init, sc))
            const t = it.type ?? inferred
            it.type = t
            e.consts.set(it.name, t)
        }
    }
    for (const it of mod.items) {
        if (it.kind === 'fn') inferFn(it, e)
    }
    return e
}

export function inferFn(fn: FnDecl, env: ModuleEnv) {
    const sc = new Scope(null, env)
    for (const p of fn.params) sc.declare(p.name, p.type)
    inferBlock(fn.body, sc)
}

function inferBlock(b: Block, sc: Scope) {
    for (const s of b) inferStmt(s, sc)
}

function inferStmt(s: Stmt, sc: Scope) {
    switch (s.kind) {
        case 'let': case 'const': {
            const t = inferExpr(s.init, sc)
            const decl = s.type ?? concretize(t)
            s.type = decl
            sc.declare(s.name, decl)
            return
        }
        case 'var': {
            let decl = s.type
            if (s.init) {
                const t = inferExpr(s.init, sc)
                if (!decl) decl = concretize(t)
            }
            if (!decl) throw new Error(`type: var ${s.name} without type or init`)
            s.type = decl
            sc.declare(s.name, decl)
            return
        }
        case 'assign': inferExpr(s.target, sc); inferExpr(s.value, sc); return
        case 'incdec': inferExpr(s.target, sc); return
        case 'expr': case 'phony': inferExpr(s.expr, sc); return
        case 'return': if (s.expr) inferExpr(s.expr, sc); return
        case 'if': {
            inferExpr(s.cond, sc)
            inferBlock(s.then, sc.child())
            if (s.else) {
                if (Array.isArray(s.else)) inferBlock(s.else, sc.child())
                else inferStmt(s.else, sc.child())
            }
            return
        }
        case 'for': {
            const inner = sc.child()
            if (s.init) inferStmt(s.init, inner)
            if (s.cond) inferExpr(s.cond, inner)
            if (s.update) inferStmt(s.update, inner)
            inferBlock(s.body, inner.child())
            return
        }
        case 'while': inferExpr(s.cond, sc); inferBlock(s.body, sc.child()); return
        case 'loop': {
            const inner = sc.child()
            inferBlock(s.body, inner)
            if (s.continuing) inferBlock(s.continuing, inner.child())
            return
        }
        case 'switch': {
            inferExpr(s.selector, sc)
            for (const c of s.cases) {
                if (c.values) for (const v of c.values) inferExpr(v, sc)
                inferBlock(c.body, sc.child())
            }
            return
        }
        case 'block': inferBlock(s.body, sc.child()); return
        case 'break': case 'continue': case 'discard': return
    }
}

const VEC_CTORS: Record<string, {n: 2 | 3 | 4; scalar: Scalar}> = {
    vec2f: {n: 2, scalar: 'f32'}, vec3f: {n: 3, scalar: 'f32'}, vec4f: {n: 4, scalar: 'f32'},
    vec2i: {n: 2, scalar: 'i32'}, vec3i: {n: 3, scalar: 'i32'}, vec4i: {n: 4, scalar: 'i32'},
    vec2u: {n: 2, scalar: 'u32'}, vec3u: {n: 3, scalar: 'u32'}, vec4u: {n: 4, scalar: 'u32'},
}

/** Builtins whose result type equals the (promoted) type of their first argument. */
const SAME_AS_FIRST = new Set([
    'abs', 'acos', 'acosh', 'asin', 'asinh', 'atan', 'atanh', 'ceil', 'clamp', 'cos', 'cosh', 'degrees', 'exp', 'exp2', 'floor', 'fma', 'fract',
    'inverseSqrt', 'log', 'log2', 'max', 'min', 'mix', 'pow', 'radians', 'round', 'saturate', 'sign', 'sin', 'sinh', 'smoothstep', 'sqrt',
    'step', 'tan', 'tanh', 'trunc', 'dpdx', 'dpdy', 'fwidth', 'dpdxCoarse', 'dpdyCoarse', 'dpdxFine', 'dpdyFine', 'fwidthCoarse', 'fwidthFine',
    'normalize', 'reflect', 'refract', 'faceForward', 'countOneBits', 'reverseBits', 'extractBits', 'insertBits', 'firstLeadingBit', 'firstTrailingBit',
    'atan2', 'quantizeToF16', 'select_first',
])

export function inferExpr(e: Expr, sc: Scope): Type {
    const t = inferExprInner(e, sc)
    e.type = t
    return t
}

function promoted(types: Type[]): Type {
    let best: Type | null = null
    for (const t of types) {
        if (!best) {best = t; continue}
        best = arithmeticResult(best, t)
    }
    return best ?? F32
}

function inferExprInner(e: Expr, sc: Scope): Type {
    switch (e.kind) {
        case 'ident': {
            const t = sc.lookup(e.name)
            if (!t) throw new Error(`type: unknown identifier ${e.name}`)
            return t
        }
        case 'int': return e.suffix === 'u' ? U32 : e.suffix === 'i' ? I32 : {kind: 'scalar', scalar: 'i32', abstract: true}
        case 'float': return e.suffix === 'f' ? F32 : {kind: 'scalar', scalar: 'f32', abstract: true}
        case 'bool': return BOOL
        case 'paren': return inferExpr(e.expr, sc)
        case 'unary': {
            const t = inferExpr(e.expr, sc)
            switch (e.op) {
                case '-': case '~': return t
                case '!': return t
                case '&': return {kind: 'ptr', space: 'function', inner: t}
                case '*': if (t.kind !== 'ptr') throw new Error('type: deref of non-pointer'); return t.inner
            }
            return t
        }
        case 'binary': {
            const l = inferExpr(e.left, sc)
            const r = inferExpr(e.right, sc)
            switch (e.op) {
                case '==': case '!=': case '<': case '>': case '<=': case '>=':
                    return boolVecLike(l.kind === 'vec' ? l : r)
                case '&&': case '||': return BOOL
                case '<<': case '>>': return l
                case '&': case '|': case '^':
                    // bool & bool is allowed; otherwise int-ish
                    return arithmeticResult(l, r)
                default: {
                    // matrix * vector etc.
                    if (l.kind === 'mat' && r.kind === 'vec') return r
                    if (l.kind === 'vec' && r.kind === 'mat') return l
                    return arithmeticResult(l, r)
                }
            }
        }
        case 'member': {
            const ot = inferExpr(e.obj, sc)
            const base = ot.kind === 'ptr' ? ot.inner : ot
            if (base.kind === 'struct') return sc.env.memberType(base.name, e.name)
            if (base.kind === 'vec') {
                if (!SWIZZLE.test(e.name)) throw new Error(`type: bad swizzle .${e.name}`)
                return e.name.length === 1 ? {kind: 'scalar', scalar: base.scalar} : vec(e.name.length as 2 | 3 | 4, base.scalar)
            }
            throw new Error(`type: member access .${e.name} on ${typeToString(ot)}`)
        }
        case 'index': {
            const ot = inferExpr(e.obj, sc)
            inferExpr(e.index, sc)
            const base = ot.kind === 'ptr' ? ot.inner : ot
            if (base.kind === 'array') return base.elem
            if (base.kind === 'vec') return {kind: 'scalar', scalar: base.scalar}
            if (base.kind === 'mat') return vec(base.rows as 2 | 3 | 4, 'f32')
            throw new Error(`type: index on ${typeToString(ot)}`)
        }
        case 'call': return inferCall(e, sc)
    }
}

function inferCall(e: Expr & {kind: 'call'}, sc: Scope): Type {
    const argTypes = e.args.map((a) => inferExpr(a, sc))
    const name = e.callee
    const env = sc.env
    // user function
    const fn = env.fns.get(name)
    if (fn) return fn.ret
    // struct constructor
    if (env.structs.has(name)) return {kind: 'struct', name}
    // vector constructors
    const vc = VEC_CTORS[name]
    if (vc) return vec(vc.n, vc.scalar)
    if (name === 'vec2' || name === 'vec3' || name === 'vec4') {
        const n = Number(name[3]) as 2 | 3 | 4
        const sc0 = e.templateArgs[0]
        const scalar: Scalar = sc0 && sc0.kind === 'scalar' ? sc0.scalar : (scalarOf(argTypes[0] ?? F32) ?? 'f32')
        return vec(n, scalar)
    }
    if (name === 'mat2x2f') return {kind: 'mat', cols: 2, rows: 2}
    if (name === 'mat3x3f') return {kind: 'mat', cols: 3, rows: 3}
    if (name === 'mat4x4f') return {kind: 'mat', cols: 4, rows: 4}
    if (name === 'array') {
        const ta = e.templateArgs[0]
        if (ta && ta.kind === 'array') {
            if (ta.count === null) return {kind: 'array', elem: ta.elem, count: e.args.length}
            return ta
        }
        return {kind: 'array', elem: concretize(argTypes[0] ?? F32), count: e.args.length}
    }
    switch (name) {
        case 'f32': return argTypes[0]?.kind === 'vec' ? vec(argTypes[0].n, 'f32') : F32
        case 'i32': return argTypes[0]?.kind === 'vec' ? vec(argTypes[0].n, 'i32') : I32
        case 'u32': return argTypes[0]?.kind === 'vec' ? vec(argTypes[0].n, 'u32') : U32
        case 'bool': return argTypes[0]?.kind === 'vec' ? vec(argTypes[0].n, 'bool') : BOOL
        case 'bitcast': return e.templateArgs[0] ?? F32
        case 'select': return promoted([argTypes[0], argTypes[1]])
        case 'dot': return {kind: 'scalar', scalar: scalarOf(argTypes[0]) ?? 'f32'}
        case 'length': case 'distance': case 'determinant': return F32
        case 'cross': return argTypes[0]
        case 'any': case 'all': return BOOL
        case 'transpose': {
            const m = argTypes[0]
            return m.kind === 'mat' ? {kind: 'mat', cols: m.rows, rows: m.cols} : m
        }
        case 'textureSample': case 'textureSampleLevel': case 'textureSampleBaseClampToEdge': case 'textureSampleGrad': case 'textureSampleBias':
            return vec(4, 'f32')
        case 'textureLoad': {
            const tt = argTypes[0]
            return vec(4, tt.kind === 'texture' ? tt.sample : 'f32')
        }
        case 'textureStore': return VOID
        case 'textureDimensions': return vec(2, 'u32')
        case 'textureNumLevels': return U32
        case 'atomicAdd': case 'atomicSub': case 'atomicMax': case 'atomicMin': case 'atomicAnd': case 'atomicOr': case 'atomicXor': case 'atomicExchange': case 'atomicLoad': {
            const p = argTypes[0]
            const inner = p.kind === 'ptr' ? p.inner : p
            return inner.kind === 'atomic' ? {kind: 'scalar', scalar: inner.inner} : U32
        }
        case 'atomicStore': return VOID
        case 'arrayLength': return U32
        case 'pack4x8unorm': case 'pack4x8snorm': case 'pack2x16unorm': case 'pack2x16snorm': case 'pack2x16float': return U32
        case 'unpack4x8unorm': case 'unpack4x8snorm': return vec(4, 'f32')
        case 'unpack2x16unorm': case 'unpack2x16snorm': case 'unpack2x16float': return vec(2, 'f32')
        case 'workgroupBarrier': case 'storageBarrier': case 'textureBarrier': return VOID
        case 'modf': case 'frexp': throw new Error('type: modf/frexp unsupported')
        case 'ldexp': return argTypes[0]
    }
    if (SAME_AS_FIRST.has(name)) {
        // promote across args (e.g. max(vec, scalar) → vec; mix(a,b,t) → a)
        if (name === 'mix' || name === 'clamp' || name === 'smoothstep' || name === 'fma') return promoted(argTypes.slice(0, name === 'smoothstep' ? 3 : 3))
        if (name === 'step') return promoted(argTypes)
        if (name === 'max' || name === 'min' || name === 'pow' || name === 'atan2' || name === 'reflect') return promoted(argTypes)
        return concretize(argTypes[0])
    }
    throw new Error(`type: unknown call ${name}`)
}

export function exprType(e: Expr): Type {
    if (!e.type) throw new Error(`type: expression not typed (${e.kind})`)
    return e.type
}

export {vecLen}
