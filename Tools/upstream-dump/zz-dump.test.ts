/**
 * Swift-port dump: composes every library shader GPU-free (mock root) and writes the resolved
 * WGSL of every pass plus the prop/field metadata to JSON, one file per shader.
 *
 *   DUMP_OUT=/abs/dir DUMP_ONLY=LinearGradient,Blur pnpm vitest run zz-dump
 */
import {describe, it, vi} from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import {tgpu, d} from '@coreroot/gpu/kit'
import {createUniformStore, type FieldInit} from '@coreroot/gpu/uniformStore'
import {SystemUniforms} from '@coreroot/gpu/kit/coords'
import {composeNodeTree} from '@coreroot/gpu/composer'
import {createGpuUniformsMap} from '@coreroot/gpu/uniformBridge'
import type {GpuShaderDefinition, RegistryView, RegistryNode, GpuFragmentParams, Expr} from '@coreroot/gpu/contract'
import type {NodeMetadata} from '@coreroot/types'
import {
    transformColor, transformPosition, transformAngle, transformEdges, transformColorSpace,
    transformBoolean, transformStrokePosition,
} from '@coreroot/utilities/transformations'
import {colorStopsTransform} from '@coreroot/utilities/colorStops'
import {listPropTransform} from '@coreroot/utilities/listProps'

const OUT = process.env.DUMP_OUT ?? path.resolve(__dirname, '../../../../../dump-out')
const ONLY = process.env.DUMP_ONLY ? new Set(process.env.DUMP_ONLY.split(',')) : null
const MAX_VARIANTS = Number(process.env.DUMP_MAX_VARIANTS ?? 64)

const modules = import.meta.glob('../../shaders/*/index.ts', {eager: true}) as Record<string, {default: GpuShaderDefinition}>

// ── schema description ────────────────────────────────────────────────────────────────
function describeSchema(s: any): any {
    if (!s) return null
    const t = s.type
    if (t === 'array') return {type: 'array', element: describeSchema(s.elementType), count: s.elementCount}
    if (t === 'struct') {
        const props: Record<string, any> = {}
        for (const [k, v] of Object.entries(s.propTypes ?? {})) props[k] = describeSchema(v)
        return {type: 'struct', props}
    }
    if (t === 'atomic') return {type: 'atomic', inner: describeSchema(s.inner)}
    if (t === 'decorated') return describeSchema(s.inner)
    return {type: t}
}

// ── mock root (records everything a compute hook allocates) ─────────────────────────────
interface Recorded {
    textures: any[]
    buffers: any[]
    uniforms: any[]
    bindGroups: any[]
    kernels: any[]
    samplers: any[]
}
function mockRoot(rec: Recorded) {
    let ids = 0
    const mkBuffer = (schema: any, initial?: unknown) => {
        const id = `buf_${ids++}`
        const buffer: any = {
            _id: id,
            patch: vi.fn(), write: vi.fn(), destroy: vi.fn(), read: vi.fn(async () => undefined),
            $usage: vi.fn(function (this: unknown) {return buffer}),
            $name: vi.fn(function (this: unknown) {return buffer}),
            $addFlags: vi.fn(function (this: unknown) {return buffer}),
            as: vi.fn(() => ({_id: id, usage: 'as'})),
            dataType: schema,
        }
        rec.buffers.push({id, schema: describeSchema(schema), hasInitial: initial !== undefined})
        return buffer
    }
    const mkTexture = (props: any) => {
        const id = `tex_${ids++}`
        const texture: any = {
            _id: id, props,
            $usage: vi.fn(function (this: unknown) {return texture}),
            $name: vi.fn(function (this: unknown) {return texture}),
            destroy: vi.fn(), write: vi.fn(), clear: vi.fn(),
            createView: vi.fn(() => ({_id: id, view: true})),
            generateMipmaps: vi.fn(),
        }
        rec.textures.push({id, size: props?.size, format: props?.format, dimension: props?.dimension, mipLevelCount: props?.mipLevelCount})
        return texture
    }
    const mkUniform = (schema: any, initial?: unknown) => {
        const id = `uni_${ids++}`
        const u: any = {_id: id, buffer: {_id: id}, write: vi.fn(), patch: vi.fn(), $name: vi.fn(function () {return u}), $: undefined, value: initial}
        rec.uniforms.push({id, schema: describeSchema(schema)})
        return u
    }
    const root: any = {
        device: {
            createTexture: vi.fn((desc: any) => ({_raw: true, desc, createView: () => ({}), destroy: () => {}})),
            queue: {writeTexture: vi.fn(), writeBuffer: vi.fn(), copyExternalImageToTexture: vi.fn(), submit: vi.fn()},
            createBuffer: vi.fn(() => ({destroy: () => {}})),
            createSampler: vi.fn(() => ({})),
            importExternalTexture: vi.fn(() => ({})),
            limits: {maxTextureDimension2D: 8192, maxStorageBufferBindingSize: 134217728, maxComputeWorkgroupsPerDimension: 65535},
            features: new Set(),
        },
        createBuffer: vi.fn((schema: any, initial?: unknown) => mkBuffer(schema, initial)),
        createTexture: vi.fn((props: any) => mkTexture(props)),
        createUniform: vi.fn((schema: any, initial?: unknown) => mkUniform(schema, initial)),
        createMutable: vi.fn((schema: any, initial?: unknown) => mkUniform(schema, initial)),
        createReadonly: vi.fn((schema: any, initial?: unknown) => mkUniform(schema, initial)),
        createSampler: vi.fn((props: any) => {rec.samplers.push(props); return {resourceType: 'sampler', props}}),
        createBindGroup: vi.fn((layout: any, entries: any) => {
            const ent: Record<string, any> = {}
            for (const [k, v] of Object.entries(entries ?? {})) {
                const r: any = v
                ent[k] = r?._id ?? r?.buffer?._id ?? (r?.resourceType === 'sampler' ? 'sampler' : typeof r)
            }
            const layoutEntries: Record<string, any> = {}
            try {
                for (const [k, v] of Object.entries((layout as any)?.entries ?? {})) {
                    const e: any = v
                    layoutEntries[k] = e?.uniform ? {uniform: describeSchema(e.uniform)}
                        : e?.storage ? {storage: describeSchema(typeof e.storage === 'function' ? null : e.storage), access: e.access}
                        : e?.texture ? {texture: e.texture, viewDimension: e.viewDimension}
                        : e?.storageTexture ? {storageTexture: e.storageTexture, access: e.access}
                        : e?.sampler ? {sampler: e.sampler} : e
                }
            } catch {}
            const bg = {_id: `bg_${ids++}`, layoutEntries, entries: ent}
            rec.bindGroups.push(bg)
            return bg
        }),
        createGuardedComputePipeline: vi.fn((callback: any) => {
            const idx = rec.kernels.length
            let wgsl = ''
            try {
                const wrapped = (tgpu as any).fn([d.u32, d.u32, d.u32])(callback)
                try {wrapped.$name(`kernel_${idx}`)} catch {}
                wgsl = (tgpu as any).resolve([wrapped], {names: 'strict'})
            } catch (e: any) {
                wgsl = `ERROR: ${e?.message ?? e}`
            }
            const k = {index: idx, dims: callback.length, wgsl, bindGroups: [] as string[]}
            rec.kernels.push(k)
            const guarded: any = {
                _kernel: idx,
                with: vi.fn(function (this: unknown, bg: any) {k.bindGroups.push(bg?._id); return guarded}),
                dispatchThreads: vi.fn(),
            }
            return guarded
        }),
        createComputePipeline: vi.fn(() => ({with: vi.fn(function (this: any) {return this}), dispatchWorkgroups: vi.fn()})),
        unwrap: vi.fn((x: any) => x),
    }
    return root
}

// ── transform classification ────────────────────────────────────────────────────────────
function classifyTransform(cfg: any): any {
    const t = cfg.transform
    if (!t) return {kind: 'none'}
    if (t === transformColor) return {kind: 'color'}
    if (t === transformPosition) return {kind: 'position'}
    if (t === transformAngle) return {kind: 'angle'}
    if (t === transformEdges) return {kind: 'edges'}
    if (t === transformColorSpace) return {kind: 'colorSpace'}
    if (t === transformBoolean) return {kind: 'boolean'}
    if (t === transformStrokePosition) return {kind: 'strokePosition'}
    if (t === colorStopsTransform) return {kind: 'colorStops'}
    if (t === listPropTransform) return {kind: 'list'}
    // closure: evaluate over options / booleans
    const options = cfg.ui?.options
    if (Array.isArray(options)) {
        const table: Record<string, any> = {}
        for (const o of options) {
            try {table[String(o.value)] = t(o.value)} catch {table[String(o.value)] = null}
        }
        return {kind: 'select', table, name: t.name || null}
    }
    if (typeof cfg.default === 'boolean') {
        try {return {kind: 'booleanCustom', table: {true: t(true), false: t(false)}, name: t.name || null}} catch {}
    }
    let sample: unknown = null
    try {sample = t(cfg.default)} catch {}
    return {kind: 'custom', name: t.name || null, sampleDefault: cfg.default, sampleTransformed: sample}
}

// ── registry builder (mirrors production buildFieldInits) ───────────────────────────────
interface NodeSpec {id: string; def: GpuShaderDefinition; parentId: string | null; props?: Record<string, unknown>; metadata?: Partial<NodeMetadata>}

function defaultsFor(def: GpuShaderDefinition): Record<string, unknown> {
    const out: Record<string, unknown> = {}
    for (const [name, cfg] of Object.entries(def.props)) out[name] = (cfg as {default: unknown}).default
    return out
}

function fieldInitsFor(def: GpuShaderDefinition, props: Record<string, unknown>, id: string): FieldInit[] {
    const map = createGpuUniformsMap(def as never, props, id)
    const inits: FieldInit[] = []
    for (const [name, u] of Object.entries(map)) inits.push({name, initial: u.value, transform: u.transform, cpu: u.cpu, schema: u.schema})
    inits.push({name: '_opacity', schema: d.f32, initial: 1})
    if (def.animatedTime) inits.push({name: '_animTime', schema: d.f32, initial: 0})
    if (def.extraAnimatedTimes) for (const key of Object.keys(def.extraAnimatedTimes)) inits.push({name: `_animTime_${key}`, schema: d.f32, initial: 0})
    if (def.extraFields) for (const [name, f] of Object.entries(def.extraFields)) inits.push({name, schema: f.schema, initial: f.initial})
    return inits
}

function buildRegistry(specs: NodeSpec[], root: any) {
    const store = createUniformStore(root, {systemSchema: SystemUniforms})
    const handlesById: Record<string, any> = {}
    const fieldsById: Record<string, any[]> = {}
    for (const s of specs) {
        const props = {...defaultsFor(s.def), ...(s.props ?? {})}
        const inits = fieldInitsFor(s.def, props, s.id)
        fieldsById[s.id] = inits.map((f) => ({name: f.name, cpu: !!f.cpu, schema: describeSchema(f.schema), hasTransform: !!f.transform}))
        handlesById[s.id] = store.defineNode(s.id, inits)
    }
    store.defineSystem()
    store.finalize()
    const nodes = new Map<string, RegistryNode>()
    const childrenByParent = new Map<string, RegistryNode[]>()
    for (const s of specs) {
        nodes.set(s.id, {
            id: s.id, componentName: s.def.name, parentId: s.parentId, definition: s.def,
            metadata: {blendMode: 'normal', opacity: undefined, renderOrder: 0, ...s.metadata} as NodeMetadata,
            handles: handlesById[s.id],
        })
    }
    for (const s of specs) {
        if (s.parentId) {
            const arr = childrenByParent.get(s.parentId) ?? []
            arr.push(nodes.get(s.id)!)
            childrenByParent.set(s.parentId, arr)
        }
    }
    const rootNode = specs.find((s) => s.parentId === null)!
    const registry: RegistryView = {
        rootId: rootNode.id,
        getNode: (id) => nodes.get(id),
        getChildren: (parentId) => childrenByParent.get(parentId) ?? [],
        resolveCustomId: () => null,
        store,
    }
    return {registry, store, fieldsById, handlesById}
}

// Root container + texture-backed child placeholder.
const RootContainer: GpuShaderDefinition = {
    name: 'Root', props: {} as never,
    fragment: ({childNode}: GpuFragmentParams): Expr => childNode ?? (undefined as never),
}
const ChildTexture: GpuShaderDefinition = {
    name: '__Child', props: {} as never, acceptsUVContext: true,
    fragment: (params: GpuFragmentParams): Expr => {
        const tex = params.registerMediaTexture(() => ({_child: true}))
        return tex.sample(params.uvContext ?? params.ctx.uv)
    },
}

function mediaStub(opts: any) {
    const texture = {_media: true, opts}
    return {
        texture, width: opts.width ?? 1, height: opts.height ?? 1,
        write: () => {}, unwrap: () => texture, generateMipmaps: () => {}, destroy: () => {},
    }
}

// ── variant enumeration ─────────────────────────────────────────────────────────────────
function variantAxes(def: GpuShaderDefinition): {prop: string; values: unknown[]}[] {
    const axes: {prop: string; values: unknown[]}[] = []
    for (const [name, cfgAny] of Object.entries(def.props)) {
        const cfg: any = cfgAny
        if (cfg.compileTime) {
            if (Array.isArray(cfg.ui?.options)) axes.push({prop: name, values: cfg.ui.options.map((o: any) => o.value)})
            else if (typeof cfg.default === 'boolean') axes.push({prop: name, values: [true, false]})
            else axes.push({prop: name, values: [cfg.default]})
        } else if (cfg.compileTimeWhen && cfg.transform === colorStopsTransform) {
            axes.push({prop: name, values: [null, [
                {color: '#ff0000', position: 0}, {color: '#00ff00', position: 0.5}, {color: '#0000ff', position: 1},
            ]]})
        }
    }
    return axes
}
function cartesian(axes: {prop: string; values: unknown[]}[]): Record<string, unknown>[] {
    let combos: Record<string, unknown>[] = [{}]
    for (const ax of axes) {
        const next: Record<string, unknown>[] = []
        for (const c of combos) for (const v of ax.values) next.push({...c, [ax.prop]: v})
        combos = next
    }
    return combos
}

function stripTail(wgsl: string): string {
    return wgsl
}

// ── main ────────────────────────────────────────────────────────────────────────────────
describe('swift-port dump', () => {
    fs.mkdirSync(OUT, {recursive: true})
    const names = Object.keys(modules).map((p) => p.split('/').slice(-2)[0]).sort()
    const summary: any[] = []
    for (const name of names) {
        if (ONLY && !ONLY.has(name)) continue
        it(`dumps ${name}`, () => {
            const def = modules[`../../shaders/${name}/index.ts`].default as GpuShaderDefinition
            const props: any[] = []
            for (const [pname, cfgAny] of Object.entries(def.props)) {
                const cfg: any = cfgAny
                props.push({
                    name: pname,
                    default: cfg.default === undefined ? null : cfg.default,
                    description: cfg.description ?? null,
                    compileTime: !!cfg.compileTime,
                    compileTimeWhen: !!cfg.compileTimeWhen,
                    transform: classifyTransform(cfg),
                    ui: cfg.ui ? JSON.parse(JSON.stringify(cfg.ui)) : null,
                })
            }
            const axes = variantAxes(def)
            let combos = cartesian(axes)
            let truncated = false
            if (combos.length > MAX_VARIANTS) {
                truncated = true
                // keep: all-defaults combo + single-axis deviations
                const defaults: Record<string, unknown> = {}
                for (const ax of axes) defaults[ax.prop] = (def.props as any)[ax.prop]?.default ?? ax.values[0]
                const keep: Record<string, unknown>[] = [defaults]
                for (const ax of axes) for (const v of ax.values) {
                    if (v === defaults[ax.prop]) continue
                    keep.push({...defaults, [ax.prop]: v})
                }
                combos = keep
            }
            const variants: any[] = []
            let fields: any[] | null = null
            for (const combo of combos) {
                const rec: Recorded = {textures: [], buffers: [], uniforms: [], bindGroups: [], kernels: [], samplers: []}
                const root = mockRoot(rec)
                const specs: NodeSpec[] = [
                    {id: 'root', def: RootContainer, parentId: null},
                    {id: 'x', def, parentId: 'root', metadata: {renderOrder: 0}, props: combo},
                ]
                if (def.requiresChild) specs.push({id: 'child', def: ChildTexture, parentId: 'x', metadata: {renderOrder: 0}})
                const out: any = {key: combo}
                try {
                    const {registry, fieldsById} = buildRegistry(specs, root)
                    fields ??= fieldsById['x']
                    const ir = composeNodeTree(registry, {
                        flipY: false, toneMapping: 'linear' as never, premultiplyAlpha: false,
                        dimensions: {width: 800, height: 600},
                        gpu: {device: root.device, root} as never,
                        createMediaTexture: mediaStub as never,
                        createDataTexture: mediaStub as never,
                    } as never)
                    out.finalPass = {
                        wgsl: stripTail(tgpu.resolve([ir.finalPass.entry], {names: 'strict'})),
                        reads: ir.finalPass.reads, externalReads: ir.finalPass.externalReads, usesSamplers: ir.finalPass.usesSamplers,
                    }
                    out.rttPasses = ir.rttPasses.map((p) => ({
                        textureKey: p.textureKey,
                        wgsl: tgpu.resolve([p.fragment.entry], {names: 'strict'}),
                        reads: p.fragment.reads, externalReads: p.fragment.externalReads, usesSamplers: p.fragment.usesSamplers,
                    }))
                    out.textures = ir.textures.map((t) => ({key: t.key, kind: t.kind}))
                    out.externalTextures = ir.externalTextures.map((t) => t.key)
                    out.computeSteps = ir.computeSteps.length
                    out.hooks = {onBeforeRender: ir.onBeforeRender.length, onAfterRender: ir.onAfterRender.length, onResize: ir.onResize.length}
                    // Drive compute hooks once to record pipelines/bind groups
                    if (ir.computeSteps.length) {
                        const steps: any[] = []
                        for (const cs of ir.computeSteps) {
                            try {
                                cs.bindInputs?.((key) => ({texture: {_rtt: key}}))
                                const nodes = cs.getComputeNodes({deltaTime: 0.016, pointer: {x: 0.5, y: 0.5}, pointerActive: false, dimensions: {width: 800, height: 600}})
                                steps.push({nodeId: cs.nodeId, steps: (nodes ?? []).map((s: any) => typeof s === 'function' ? 'thunk' : {kernel: s?.guarded?._kernel ?? null, bindGroups: s?.guarded?.with?.mock?.calls?.map((c: any[]) => c[0]?._id) ?? []})})
                            } catch (e: any) {
                                steps.push({nodeId: cs.nodeId, error: String(e?.message ?? e)})
                            }
                        }
                        out.computeDrive = steps
                    }
                    out.recorded = rec
                } catch (e: any) {
                    out.error = String(e?.stack ?? e?.message ?? e)
                }
                variants.push(out)
            }
            const meta = {
                name: def.name, deprecatedNames: def.deprecatedNames ?? [], category: def.category ?? null, description: def.description ?? null,
                role: (def as any).role ?? null, species: (def as any).species ?? null,
                flags: {
                    requiresRTT: !!def.requiresRTT, requiresChild: !!def.requiresChild, acceptsOptionalChild: !!def.acceptsOptionalChild,
                    blendWithChildren: !!def.blendWithChildren, usesPointer: !!def.usesPointer, acceptsUVContext: !!def.acceptsUVContext,
                    providesUVContextViaCompute: !!def.providesUVContextViaCompute, capturesDOM: !!def.capturesDOM, wantsBoundsParams: !!def.wantsBoundsParams,
                    hasCompute: !!def.compute, hasUvRemap: !!def.uvRemap, hasMapSampleUVs: !!def.mapSampleUVs,
                },
                animatedTime: def.animatedTime ?? null, extraAnimatedTimes: def.extraAnimatedTimes ?? null,
                extraFields: def.extraFields ? Object.fromEntries(Object.entries(def.extraFields).map(([k, v]) => [k, {schema: describeSchema(v.schema), initial: v.initial}])) : null,
                boundingBoxDeclaration: def.boundingBoxDeclaration ? JSON.parse(JSON.stringify(def.boundingBoxDeclaration)) : null,
                naturalSizeKey: def.naturalSizeKey ?? null,
                props, fields, axes: axes.map((a) => ({prop: a.prop, count: a.values.length})), variantCount: variants.length, truncated,
                variants,
            }
            fs.writeFileSync(path.join(OUT, `${name}.json`), JSON.stringify(meta, null, 1))
            const errs = variants.filter((v) => v.error).length
            summary.push({name, variants: variants.length, errors: errs, compute: meta.flags.hasCompute, truncated})
            fs.writeFileSync(path.join(OUT, `_summary.json`), JSON.stringify(summary, null, 1))
        })
    }
})
