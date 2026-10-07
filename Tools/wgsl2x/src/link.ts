// Links all passes/kernels of one shader (every compile-time variant) into a single unit with
// deduplicated structs/functions, and computes which module globals each function captures.
import type {ConstDecl, Expr, FnDecl, GlobalVar, Module, StructDecl, Type} from './ast.js'
import {typeToString} from './ast.js'
import {parseWGSL} from './parser.js'
import {printExpr, printFn, printStruct, renameInFn, renameType, walkFn} from './printer.js'
import {ModuleEnv, inferModule} from './types.js'

export interface PassSource {
    variantIndex: number
    role: 'final' | 'rtt'
    textureKey: string | null
    wgsl: string
}
export interface KernelSource {
    index: number
    dims: number
    wgsl: string
}
export interface LinkInput {
    shader: string
    passes: PassSource[]
    kernels: KernelSource[]
    /** Plain function libraries (no entry point), e.g. the composition kit. */
    libraries?: string[]
}

export interface LinkedPass {
    variantIndex: number
    role: 'final' | 'rtt'
    textureKey: string | null
    entry: FnDecl
    globals: GlobalVar[]
    inputStruct: string | null
}
export interface LinkedKernel {
    index: number
    dims: number
    entry: FnDecl
    globals: GlobalVar[]
}

export interface LinkUnit {
    shader: string
    structs: StructDecl[]
    inputStructs: Set<string>
    consts: ConstDecl[]
    fns: FnDecl[]
    passes: LinkedPass[]
    kernels: LinkedKernel[]
    env: ModuleEnv
    hostShareable: Set<string>
    constructedStructs: Set<string>
    captures: Map<string, string[]>
    globalDecls: Map<string, GlobalVar>
}

function hasLocationAttr(s: StructDecl): boolean {
    return s.members.some((m) => m.attrs.some((a) => a.name === 'location' || a.name === 'builtin'))
}

export function link(input: LinkInput): LinkUnit {
    const env = new ModuleEnv()
    const unit: LinkUnit = {
        shader: input.shader, structs: [], inputStructs: new Set(), consts: [], fns: [], passes: [], kernels: [], env,
        hostShareable: new Set(), constructedStructs: new Set(), captures: new Map(), globalDecls: new Map(),
    }
    const structKeyToName = new Map<string, string>()
    const structNames = new Set<string>()
    const fnKeyToName = new Map<string, string>()
    const fnNames = new Set<string>()
    const constKeyToName = new Map<string, string>()
    const constNames = new Set<string>()

    const alloc = (orig: string, taken: Set<string>): string => {
        if (!taken.has(orig)) {taken.add(orig); return orig}
        for (let k = 2; ; k++) {
            const n = `${orig}_${k}`
            if (!taken.has(n)) {taken.add(n); return n}
        }
    }

    const absorb = (mod: Module, entryName: string | null, label: string): {entry: FnDecl | null; globals: GlobalVar[]; inputStruct: string | null} => {
        // type-check in the module's own env first (annotates expressions)
        const localEnv = new ModuleEnv()
        inferModule(mod, localEnv)
        const structMap = new Map<string, string>()
        const fnMap = new Map<string, string>()
        const globalMap = new Map<string, string>()
        const globals: GlobalVar[] = []
        let entry: FnDecl | null = null
        let inputStruct: string | null = null
        for (const it of mod.items) {
            if (it.kind === 'struct') {
                const renamed: StructDecl = {kind: 'struct', name: it.name, members: it.members.map((m) => ({name: m.name, type: renameType(m.type, structMap), attrs: m.attrs}))}
                if (hasLocationAttr(it)) {
                    // entry input struct: keep per pass, never emitted as a plain struct
                    const name = alloc(it.name, structNames)
                    structMap.set(it.name, name)
                    renamed.name = name
                    unit.inputStructs.add(name)
                    env.structs.set(name, renamed)
                    inputStruct = name
                    continue
                }
                const key = printStruct({...renamed, name: '_'})
                const existing = structKeyToName.get(key)
                if (existing) {
                    structMap.set(it.name, existing)
                } else {
                    const name = alloc(it.name, structNames)
                    structKeyToName.set(key, name)
                    structMap.set(it.name, name)
                    renamed.name = name
                    unit.structs.push(renamed)
                    env.structs.set(name, renamed)
                }
            } else if (it.kind === 'const') {
                const renamedType = it.type ? renameType(it.type, structMap) : null
                const key = `${it.name}|${renamedType ? typeToString(renamedType) : ''}|${printExpr(it.init)}`
                if (constKeyToName.has(key)) continue
                const name = alloc(it.name, constNames)
                if (name !== it.name) throw new Error(`[${label}] const ${it.name} redefined with a different value`)
                constKeyToName.set(key, name)
                const decl: ConstDecl = {kind: 'const', name, type: renamedType ?? localEnv.consts.get(it.name) ?? null, init: it.init}
                unit.consts.push(decl)
                if (decl.type) env.consts.set(name, decl.type)
            } else if (it.kind === 'global') {
                const g: GlobalVar = {...it, type: renameType(it.type, structMap)}
                // A global name may be reused with a different type in another kernel of the same
                // shader (e.g. two `params` uniform structs). Rename to keep one type per name.
                let prev = unit.globalDecls.get(g.name)
                if (prev && typeToString(prev.type) !== typeToString(g.type)) {
                    const base = g.name
                    let k = 2
                    while (unit.globalDecls.has(`${base}_${k}`) && typeToString(unit.globalDecls.get(`${base}_${k}`)!.type) !== typeToString(g.type)) k++
                    globalMap.set(g.name, `${base}_${k}`)
                    g.name = `${base}_${k}`
                    prev = unit.globalDecls.get(g.name)
                }
                if (!prev) {
                    unit.globalDecls.set(g.name, g)
                    env.globals.set(g.name, g.type)
                }
                globals.push(g)
                markHostShareable(g.type, unit, env)
            } else if (it.kind === 'fn') {
                if (globalMap.size) renameGlobalsInFn(it, globalMap)
                renameInFn(it, structMap, fnMap)
                const isEntry = entryName !== null && (it.stage !== null || it.name === entryName)
                if (isEntry) {
                    it.name = entryName!
                    entry = it
                    continue
                }
                const key = printFn({...it, name: '_'})
                const existing = fnKeyToName.get(key)
                if (existing) {
                    fnMap.set(it.name, existing)
                } else {
                    const name = alloc(it.name, fnNames)
                    fnKeyToName.set(key, name)
                    fnMap.set(it.name, name)
                    it.name = name
                    unit.fns.push(it)
                    env.fns.set(name, {params: it.params.map((p) => p.type), ret: it.ret})
                }
            }
        }
        return {entry, globals, inputStruct}
    }

    for (const [i, lib] of (input.libraries ?? []).entries()) {
        absorb(parseWGSL(lib), null, `${input.shader}:lib${i}`)
    }
    for (const p of input.passes) {
        const mod = parseWGSL(p.wgsl)
        const label = `${input.shader}#${p.variantIndex}:${p.role}${p.textureKey ? `:${p.textureKey}` : ''}`
        const entryName = `${input.shader}_v${p.variantIndex}_${p.role === 'final' ? 'final' : p.textureKey!.replace(/[^a-zA-Z0-9_]/g, '_')}`
        const {entry, globals, inputStruct} = absorb(mod, entryName, label)
        if (!entry) throw new Error(`[${label}] no entry function found`)
        if (p.role === 'final') stripFinalTail(entry, label)
        unit.passes.push({variantIndex: p.variantIndex, role: p.role, textureKey: p.textureKey, entry, globals, inputStruct})
    }
    for (const k of input.kernels) {
        const mod = parseWGSL(k.wgsl)
        const label = `${input.shader}:kernel${k.index}`
        // the wrapped callback is named kernel_<index> by the dump
        for (const it of mod.items) if (it.kind === 'fn' && it.name === `kernel_${k.index}`) it.stage = 'compute'
        const {entry, globals} = absorb(mod, `${input.shader}_k${k.index}`, label)
        if (!entry) throw new Error(`[${label}] no kernel entry found`)
        unit.kernels.push({index: k.index, dims: k.dims, entry, globals})
    }

    // constructed structs (struct ctor calls) — these must not get layout padding
    const noteCtors = (f: FnDecl) => walkFn(f, (e) => {
        if (e.kind === 'call' && env.structs.has(e.callee)) unit.constructedStructs.add(e.callee)
    })
    unit.fns.forEach(noteCtors)
    unit.passes.forEach((p) => noteCtors(p.entry))
    unit.kernels.forEach((k) => noteCtors(k.entry))

    computeCaptures(unit)
    return unit
}

/**
 * The composer's final pass ends with `return vec4f(linearToSrgb(tone_linear(X.rgb)), X.a);`.
 * ShadersKit composites in linear light and applies tone mapping + the sRGB OETF itself in its
 * present pass, so the per-node pass must return the linear composed value instead.
 */
function stripFinalTail(entry: FnDecl, label: string) {
    const last = entry.body[entry.body.length - 1]
    if (!last || last.kind !== 'return' || !last.expr) throw new Error(`[${label}] final pass does not end in a return`)
    const e = last.expr
    const isCall = (x: Expr, name: string): x is Expr & {kind: 'call'} => x.kind === 'call' && x.callee === name
    if (!isCall(e, 'vec4f') || e.args.length !== 2) throw new Error(`[${label}] unexpected final tail: ${printExpr(e)}`)
    const [rgb, a] = e.args
    if (!isCall(rgb, 'linearToSrgb') || rgb.args.length !== 1) throw new Error(`[${label}] unexpected final tail (no linearToSrgb): ${printExpr(e)}`)
    let inner = rgb.args[0]
    if (inner.kind === 'call' && /^tone_/.test(inner.callee) && inner.args.length === 1) inner = inner.args[0]
    if (inner.kind !== 'member' || inner.name !== 'rgb' || inner.obj.kind !== 'ident') throw new Error(`[${label}] unexpected final tail (rgb source): ${printExpr(e)}`)
    if (a.kind !== 'member' || a.name !== 'a' || a.obj.kind !== 'ident' || a.obj.name !== inner.obj.name) throw new Error(`[${label}] unexpected final tail (alpha source): ${printExpr(e)}`)
    const src = inner.obj
    last.expr = {kind: 'ident', name: src.name, type: src.type}
}

/** Renames references to module globals inside a function (skipping names shadowed by params/locals). */
function renameGlobalsInFn(f: FnDecl, map: Map<string, string>) {
    const shadowed = new Set(f.params.map((p) => p.name))
    walkFn(f, () => {}, (s) => {
        if (s.kind === 'let' || s.kind === 'var' || s.kind === 'const') shadowed.add(s.name)
    })
    walkFn(f, (e) => {
        if (e.kind === 'ident' && map.has(e.name) && !shadowed.has(e.name)) e.name = map.get(e.name)!
    })
}

function markHostShareable(t: Type, unit: LinkUnit, env: ModuleEnv) {
    if (t.kind === 'struct') {
        if (unit.hostShareable.has(t.name)) return
        unit.hostShareable.add(t.name)
        const s = env.structs.get(t.name)
        if (s) for (const m of s.members) markHostShareable(m.type, unit, env)
    } else if (t.kind === 'array') markHostShareable(t.elem, unit, env)
    else if (t.kind === 'ptr') markHostShareable(t.inner, unit, env)
}

/** Direct global references of a function body (identifiers naming module globals, not shadowed). */
export function directGlobalRefs(f: FnDecl, unit: LinkUnit): Set<string> {
    const locals = new Set<string>(f.params.map((p) => p.name))
    walkFn(f, () => {}, (s) => {
        if (s.kind === 'let' || s.kind === 'var' || s.kind === 'const') locals.add(s.name)
    })
    const refs = new Set<string>()
    walkFn(f, (e: Expr) => {
        if (e.kind === 'ident' && unit.globalDecls.has(e.name) && !locals.has(e.name)) refs.add(e.name)
    })
    return refs
}

export function calledFns(f: FnDecl, unit: LinkUnit): Set<string> {
    const out = new Set<string>()
    walkFn(f, (e) => {
        if (e.kind === 'call' && unit.env.fns.has(e.callee)) out.add(e.callee)
    })
    return out
}

function computeCaptures(unit: LinkUnit) {
    // unit.fns is in dependency order (callees precede callers) by construction of the dumps
    for (const f of unit.fns) {
        const caps = new Set(directGlobalRefs(f, unit))
        for (const c of calledFns(f, unit)) for (const g of unit.captures.get(c) ?? []) caps.add(g)
        unit.captures.set(f.name, [...caps].sort())
    }
}
