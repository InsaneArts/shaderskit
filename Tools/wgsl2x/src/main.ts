// Full pipeline: dump JSON → MSL resources + descriptor JSON + typed Swift layer structs.
// Usage: tsx src/main.ts <dumpDir> <repoRoot> [--only A,B] [--validate]
import fs from 'node:fs'
import path from 'node:path'
import {execFileSync} from 'node:child_process'
import {link, type LinkInput} from './link.js'
import {emitMSL, type EmittedUnit} from './msl.js'
import {generateCompositor, generateCompositorSwift} from './gen-kit.js'
import {emitSwift} from './swift.js'
import {generateLayerSwift, sharedEnumSwift} from './gen-swift.js'

const [dumpDir, repoRoot, ...rest] = process.argv.slice(2)
if (!dumpDir || !repoRoot) throw new Error('usage: main <dumpDir> <repoRoot> [--only A,B] [--validate]')
const onlyIdx = rest.indexOf('--only')
const only = onlyIdx >= 0 ? new Set(rest[onlyIdx + 1].split(',')) : null
const validate = rest.includes('--validate')

const mslDir = path.join(repoRoot, 'Sources/ShadersKit/Resources/MSL')
const descDir = path.join(repoRoot, 'Sources/ShadersKit/Resources/Descriptors')
const layersDir = path.join(repoRoot, 'Sources/ShadersKit/Generated/Layers')
const cpuDir = path.join(repoRoot, 'Sources/ShadersKit/Generated/CPU')
for (const d of [mslDir, descDir, layersDir, cpuDir]) fs.mkdirSync(d, {recursive: true})
const noCPU = rest.includes('--no-cpu')

const roles: Record<string, {role: string | null; species: string | null}> = JSON.parse(fs.readFileSync(path.join(repoRoot, 'Tools/upstream-dump/roles.json'), 'utf8'))

function loadLinkInput(json: any): LinkInput {
    const input: LinkInput = {shader: json.name, passes: [], kernels: []}
    json.variants.forEach((v: any, vi: number) => {
        if (v.error) return
        input.passes.push({variantIndex: vi, role: 'final', textureKey: null, wgsl: v.finalPass.wgsl})
        for (const p of v.rttPasses ?? []) input.passes.push({variantIndex: vi, role: 'rtt', textureKey: p.textureKey, wgsl: p.wgsl})
    })
    const k0 = json.variants.find((v: any) => !v.error)
    for (const k of k0?.recorded?.kernels ?? []) if (!k.wgsl.startsWith('ERROR')) input.kernels.push({index: k.index, dims: k.dims, wgsl: k.wgsl})
    return input
}

// ── prop default → PropValue JSON ─────────────────────────────────────────────────────
export function propValueJSON(v: unknown): unknown {
    if (v === null || v === undefined) return null
    if (typeof v === 'number' || typeof v === 'boolean' || typeof v === 'string') return v
    if (Array.isArray(v)) return v // color stops / list items pass through
    if (typeof v === 'object') {
        const o = v as Record<string, unknown>
        if ('x' in o && 'y' in o) return {x: o.x, y: o.y}
        if ('value' in o && 'unit' in o) return {value: o.value, unit: o.unit}
        return JSON.stringify(v)
    }
    return String(v)
}

function transformJSON(t: any, p: any): any {
    switch (t.kind) {
        case 'select': return {kind: 'select', table: Object.fromEntries(Object.entries(t.table).map(([k, v]) => [k, typeof v === 'number' ? v : 0]))}
        case 'booleanCustom': return {kind: 'booleanTable', trueValue: t.table.true, falseValue: t.table.false}
        case 'custom': {
            // numeric closure: fit value*scale+offset from two samples (default and default+1)
            const d = typeof p.default === 'number' ? p.default : 0
            const s0 = typeof t.sampleTransformed === 'number' ? t.sampleTransformed : d
            // slope estimated from the known upstream closures (all are affine)
            const slope = closureSlope(p)
            return {kind: 'affine', scale: slope, offset: s0 - slope * d}
        }
        default: return {kind: t.kind}
    }
}

/** The six upstream inline numeric transforms are affine; their slopes are read from the sources. */
function closureSlope(p: any): number {
    const known: Record<string, number> = {
        'Ascii.spacing': 1.4, 'FilmStock.halation': 10, 'Glass.thickness': 0.5, 'Neon.tubeThickness': 0.05,
        'Repeater.instanceRotation': Math.PI / 180, 'Repeater.hueShift': Math.PI / 180,
    }
    const key = `${currentShader}.${p.name}`
    if (!(key in known)) throw new Error(`unknown custom transform ${key} — add its slope to closureSlope()`)
    return known[key]
}
let currentShader = ''

function uiJSON(ui: any): any {
    if (!ui) return {types: [], hidden: false}
    const types = ui.type ? (Array.isArray(ui.type) ? ui.type : [ui.type]) : []
    const out: any = {types}
    if (typeof ui.min === 'number') out.min = ui.min
    if (typeof ui.max === 'number') out.max = ui.max
    if (typeof ui.step === 'number') out.step = ui.step
    if (Array.isArray(ui.options)) out.options = ui.options.map((o: any) => ({label: String(o.label), value: String(o.value)}))
    if (ui.label) out.label = ui.label
    if (ui.group) out.group = ui.group
    if (Array.isArray(ui.units)) out.units = ui.units
    if (ui.dimensional) out.dimensional = ui.dimensional
    out.hidden = !!ui.hidden
    if (ui.condition && typeof ui.condition === 'object') {
        const cond: Record<string, string[]> = {}
        for (const [k, v] of Object.entries(ui.condition)) cond[k] = (Array.isArray(v) ? v : [v]).map((x) => String(x))
        out.condition = cond
    }
    if (ui.item && typeof ui.item === 'object') {
        out.item = Object.entries(ui.item).map(([name, cfg]: [string, any]) => ({
            name, kind: cfg.kind, defaultValue: propValueJSON(cfg.default), label: cfg.label, min: cfg.min, max: cfg.max, step: cfg.step,
        }))
        out.maxItems = ui.maxItems
        out.minItems = ui.minItems
        out.itemLabel = ui.itemLabel
    }
    return out
}

function variantIsDefault(key: Record<string, unknown>, props: any[]): boolean {
    for (const [k, v] of Object.entries(key)) {
        const p = props.find((x) => x.name === k)
        const def = p?.default ?? null
        if (JSON.stringify(v) !== JSON.stringify(def)) return false
    }
    return true
}

export function buildDescriptor(json: any, emitted: EmittedUnit): any {
    const name: string = json.name
    const roleInfo = roles[name] ?? {role: null, species: null}
    const fieldsByName = new Map<string, any>((json.fields ?? []).map((f: any) => [f.name, f]))
    const layoutTypes = new Map<string, string>((emitted.uniformLayout?.fields ?? []).filter((f) => f.path.startsWith('n_x.')).map((f) => [f.path.slice(4), f.type]))
    const fieldType = (f: any): string => layoutTypes.get(f.name) ?? (f.schema ? schemaTypeString(f.schema) : 'f32')
    const props = json.props.map((p: any) => {
        const field = fieldsByName.get(p.name)
        const isUniform = !!field && !field.cpu
        return {
            name: p.name,
            defaultValue: propValueJSON(p.default),
            description: p.description,
            transform: transformJSON(p.transform, p),
            ui: uiJSON(p.ui),
            compileTime: !!p.compileTime || !!p.compileTimeWhen,
            isUniform,
            uniformType: isUniform ? fieldType(field) : null,
        }
    })
    const passesByVariant = new Map<number, any[]>()
    for (const pass of emitted.passes) {
        const arr = passesByVariant.get(pass.variantIndex) ?? []
        arr.push({kind: pass.role, textureKey: pass.textureKey, entry: pass.entry, textures: pass.textures, samplers: pass.samplers, usesUniforms: pass.usesUniforms})
        passesByVariant.set(pass.variantIndex, arr)
    }
    const variants = json.variants.map((v: any, vi: number) => {
        const passes = passesByVariant.get(vi) ?? []
        // RTT passes first (leaves→root order as dumped), final last
        passes.sort((a, b) => (a.kind === 'final' ? 1 : 0) - (b.kind === 'final' ? 1 : 0))
        return {
            key: Object.fromEntries(Object.entries(v.key).map(([k, val]) => [k, propValueJSON(val)])),
            isDefault: variantIsDefault(v.key, json.props),
            passes,
            textures: v.textures ?? [],
            computeSteps: v.computeSteps ?? 0,
        }
    })
    if (!variants.some((v: any) => v.isDefault) && variants.length) variants[0].isDefault = true
    const bbox = json.boundingBoxDeclaration
    return {
        name,
        category: json.category,
        description: json.description ?? '',
        role: roleInfo.role ?? 'generator',
        species: roleInfo.species,
        deprecatedNames: json.deprecatedNames ?? [],
        flags: json.flags,
        animatedTimeSpeedProp: json.animatedTime?.speed ?? null,
        extraAnimatedTimes: json.extraAnimatedTimes ?? {},
        extraFields: Object.entries(json.extraFields ?? {}).map(([n, f]: [string, any]) => ({name: n, type: schemaTypeString(f.schema), initial: Array.isArray(f.initial) ? f.initial : [f.initial]})),
        props,
        fields: (json.fields ?? []).map((f: any) => ({name: f.name, type: fieldType(f), cpu: !!f.cpu})),
        variantAxes: (json.axes ?? []).map((a: any) => a.prop),
        variants,
        uniformLayout: emitted.uniformLayout ?? {size: 0, fields: []},
        boundingBox: bbox ? {
            propBindings: bbox.propBindings ?? null,
            aspectRatio: typeof bbox.aspectRatio === 'number' ? bbox.aspectRatio : null,
            supportsResizeFit: bbox.supportsResizeFit ?? null,
            boxResamplesContent: bbox.boxResamplesContent ?? null,
            freeResize: bbox.freeResize ?? null,
            softnessProp: bbox.softnessBinding?.prop ?? null,
        } : null,
        naturalSizeProp: json.naturalSizeKey?.fromProp ?? null,
        msl: name,
        cpuSupported: false,
        compute: computeInfo(json, emitted),
    }
}

/** Kernel entry points + recorded resource graph, for the hand-written compute programs. */
function computeInfo(json: any, emitted: EmittedUnit): any {
    if (!emitted.kernels.length) return null
    const v0 = json.variants.find((v: any) => !v.error && v.recorded)
    const rec = v0?.recorded ?? {}
    return {
        kernels: emitted.kernels.map((k) => ({
            index: k.index, dims: k.dims, entry: k.entry, sizeSlot: k.sizeSlot,
            buffers: k.buffers.map((b) => ({name: b.name, slot: b.slot, space: b.space, type: b.type})),
            textures: k.textures.map((t) => ({name: t.name, slot: t.slot, type: t.type})),
        })),
        uniformLayouts: emitted.kernelUniformLayouts,
        textures: (rec.textures ?? []).map((t: any) => ({id: t.id, width: t.size?.[0] ?? null, height: t.size?.[1] ?? null, format: t.format ?? null})),
        buffers: (rec.buffers ?? []).map((b: any) => ({id: b.id, type: schemaTypeString(b.schema), count: b.schema?.type === 'array' ? b.schema.count : null, element: b.schema?.type === 'array' ? schemaTypeString(b.schema.element) : null})),
        uniforms: (rec.uniforms ?? []).map((u: any) => ({id: u.id, fields: Object.keys(u.schema?.props ?? {})})),
        bindGroups: (rec.bindGroups ?? []).map((bg: any) => ({id: bg._id, entries: bg.entries})),
        kernelBindGroups: (rec.kernels ?? []).map((k: any) => ({index: k.index, bindGroups: k.bindGroups})),
        drive: v0?.computeDrive ?? null,
        rttInputKeys: (v0?.textures ?? []).filter((t: any) => t.kind === 'rtt').map((t: any) => t.key),
    }
}

function schemaTypeString(s: any): string {
    if (!s) return 'f32'
    if (s.type === 'array') return `array<${schemaTypeString(s.element)}, ${s.count}>`
    if (s.type === 'struct') return 'struct'
    return s.type
}

// ── main ──────────────────────────────────────────────────────────────────────────────
const names = fs.readdirSync(dumpDir).filter((f) => f.endsWith('.json') && !f.startsWith('_')).map((f) => f.replace(/\.json$/, '')).sort()
const index: any[] = []
const failures: string[] = []
const compileFailures: string[] = []
let mslBytes = 0
const allDescriptors: any[] = []
const cpuNames: string[] = []
const cpuSkipped: string[] = []
for (const name of names) {
    if (only && !only.has(name)) continue
    currentShader = name
    try {
        const json = JSON.parse(fs.readFileSync(path.join(dumpDir, `${name}.json`), 'utf8'))
        const unit = link(loadLinkInput(json))
        const emitted = emitMSL(unit)
        fs.writeFileSync(path.join(mslDir, `${name}.metal`), emitted.source)
        mslBytes += emitted.source.length
        const desc = buildDescriptor(json, emitted)
        if (!noCPU) {
            const sw = emitSwift(unit)
            if (sw.supported) {
                fs.writeFileSync(path.join(cpuDir, `${name}.cpu.swift`), sw.source)
                desc.cpuSupported = true
                cpuNames.push(name)
            } else {
                cpuSkipped.push(`${name}: ${sw.reason}`)
                try {fs.unlinkSync(path.join(cpuDir, `${name}.cpu.swift`))} catch {}
            }
        }
        allDescriptors.push(desc)
        fs.writeFileSync(path.join(descDir, `${name}.json`), JSON.stringify(desc))
        index.push({name, category: desc.category, description: desc.description, role: desc.role, acceptsChildren: desc.flags.requiresChild || desc.flags.acceptsOptionalChild || desc.role === 'structural', hasCompute: desc.flags.hasCompute, cpuSupported: desc.cpuSupported})
        if (validate) {
            try {
                execFileSync('xcrun', ['-sdk', 'macosx', 'metal', '-c', '-Wno-unused-variable', '-Wno-unused-function', path.join(mslDir, `${name}.metal`), '-o', '/dev/null'], {stdio: ['ignore', 'pipe', 'pipe']})
            } catch (e: any) {
                compileFailures.push(`${name}: ${String(e.stderr ?? e.message).split('\n').filter((l) => l.includes('error:')).slice(0, 3).join(' | ')}`)
            }
        }
    } catch (e: any) {
        failures.push(`${name}: ${e.stack?.split('\n').slice(0, 3).join(' ') ?? e.message}`)
    }
}
if (!only) fs.writeFileSync(path.join(descDir, 'index.json'), JSON.stringify(index, null, 1))

// compositor
const comp = generateCompositor(dumpDir)
fs.writeFileSync(path.join(mslDir, 'Compositor.metal'), comp.source)
if (!noCPU) {
    fs.writeFileSync(path.join(cpuDir, '_Compositor.swift'), generateCompositorSwift(dumpDir))
    const reg = [
        `// Generated by wgsl2x — do not edit.`,
        `import Foundation`,
        ``,
        `/// CPU shader programs available to the rasterizer (shaders without compute passes).`,
        `enum CPUPrograms {`,
        `    static func program(for name: String) -> CPUShaderProgram.Type? { table[name] }`,
        `    static var supportedNames: [String] { Array(table.keys).sorted() }`,
        `    private static let table: [String: CPUShaderProgram.Type] = [`,
        ...cpuNames.sort().map((n) => `        "${n}": CPU_${n}.self,`),
        `    ]`,
        `}`,
        ``,
    ].join('\n')
    fs.writeFileSync(path.join(cpuDir, '_Programs.swift'), reg)
    console.log(`CPU programs: ${cpuNames.length} supported, ${cpuSkipped.length} skipped`)
    if (cpuSkipped.length) cpuSkipped.slice(0, 60).forEach((x) => console.log('  skip ' + x))
}

// typed Swift layers
const sharedOut = sharedEnumSwift(allDescriptors)
fs.writeFileSync(path.join(layersDir, '_SharedEnums.swift'), sharedOut.source)
for (const desc of allDescriptors) {
    fs.writeFileSync(path.join(layersDir, `${desc.name}.swift`), generateLayerSwift(desc, sharedOut.sharedByOptions))
}

console.log(`generated ${allDescriptors.length} shaders → MSL ${(mslBytes / 1e6).toFixed(2)} MB, descriptors, ${allDescriptors.length} Swift layer files`)
if (failures.length) {console.log(`\nFAILURES (${failures.length}):`); failures.forEach((f) => console.log('  ' + f))}
if (validate) {
    console.log(`METAL COMPILE: ${allDescriptors.length - compileFailures.length}/${allDescriptors.length} ok`)
    compileFailures.forEach((f) => console.log('  ' + f))
}
