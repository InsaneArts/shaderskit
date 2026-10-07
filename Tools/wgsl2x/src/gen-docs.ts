// Generates the per-component reference docs for the `shaderskit` agent skill from the
// descriptor JSON shipped in the package. Usage: tsx src/gen-docs.ts <repoRoot>
import fs from 'node:fs'
import path from 'node:path'
import {planProp, SHARED, type PropPlan} from './gen-swift.js'

const repoRoot = process.argv[2]
if (!repoRoot) throw new Error('usage: gen-docs <repoRoot>')
const descDir = path.join(repoRoot, 'Sources/ShadersKit/Resources/Descriptors')
const outDir = path.join(repoRoot, 'skills/shaderskit/components')
fs.mkdirSync(outDir, {recursive: true})
const shared = new Map<string, string>(Object.entries(SHARED))
const CLASHING = new Set(['Circle', 'Ellipse', 'Text', 'Group', 'Grid', 'Glass', 'Mirror', 'LinearGradient', 'RadialGradient', 'MeshGradient'])

const COMPUTE_GAPS: Record<string, string> = {
    Glass: 'The frosted (`blur > 0`) prepass is not ported; clear glass works.',
    Voxels: 'Only `voxelShape: cube` with `gridSpace: shape` is ported; other voxel shapes render as cubes.',
    TimeTrail: 'Rainbow tint runs untinted.',
    ReactionDiffusion: 'A nested child does not influence the simulation (upstream "drive" mode).',
    Irradiance: 'Shadows cannot be disabled (`shadows: false` only affects the rim).',
}

function fmtDefault(v: any): string {
    if (v === null || v === undefined) return '—'
    if (typeof v === 'string') return `\`"${v}"\``
    if (typeof v === 'number' || typeof v === 'boolean') return `\`${v}\``
    if (Array.isArray(v)) return v.length ? `\`${JSON.stringify(v)}\`` : '`[]`'
    if (typeof v === 'object' && 'x' in v) return `\`(${JSON.stringify(v.x)}, ${JSON.stringify(v.y)})\``
    return `\`${JSON.stringify(v)}\``
}

function rangeOrOptions(p: any): string {
    const ui = p.ui ?? {}
    if (Array.isArray(ui.options) && ui.options.length) return ui.options.map((o: any) => `\`${o.value}\``).join(', ')
    const parts: string[] = []
    if (typeof ui.min === 'number' || typeof ui.max === 'number') parts.push(`${ui.min ?? '…'} … ${ui.max ?? '…'}`)
    if (typeof ui.step === 'number') parts.push(`step ${ui.step}`)
    if (Array.isArray(ui.units) && ui.units.includes('px')) parts.push('fraction or `.px(n)`')
    if (p.transform?.kind === 'color') parts.push('CSS color string')
    if (p.transform?.kind === 'position') parts.push('`ShaderPosition` (0…1, top-left origin)')
    if (p.transform?.kind === 'angle') parts.push('degrees')
    if (p.transform?.kind === 'colorStops') parts.push('`[ColorStop]`, overrides the two-colour props when set')
    return parts.join(', ') || '—'
}

function swiftType(plan: PropPlan): string {
    return plan.type
}

const names = fs.readdirSync(descDir).filter((f) => f.endsWith('.json') && f !== 'index.json').map((f) => f.replace(/\.json$/, '')).sort()
const indexRows: Record<string, string[]> = {}
for (const name of names) {
    const d = JSON.parse(fs.readFileSync(path.join(descDir, `${name}.json`), 'utf8'))
    const plans: PropPlan[] = d.props.map((p: any) => planProp(p, name, shared))
    const acceptsChildren = d.flags.requiresChild || d.flags.acceptsOptionalChild || d.role === 'structural'
    const qualified = CLASHING.has(name) ? `ShadersKit.${name}` : name
    const sigArgs = plans.map((pl) => `${pl.swiftName}: ${swiftType(pl)} = ${pl.defaultExpr}`).join(', ')
    const childNote = d.flags.requiresChild ? 'Wraps the layers in its trailing closure; draws nothing without content.' : d.flags.acceptsOptionalChild ? 'Optionally wraps layers in its trailing closure.' : d.role === 'structural' ? 'Container for nested layers.' : ''
    const platform = d.flags.hasCompute
        ? 'Metal only (iOS, iPadOS, macOS, tvOS, visionOS). Not available on watchOS (compute passes).'
        : d.role === 'media'
            ? 'Metal only (iOS, iPadOS, macOS, tvOS, visionOS); see notes for sources.'
            : d.cpuSupported ? 'All platforms, including watchOS (CPU rasterizer).' : 'Metal only.'
    const notes: string[] = []
    if (childNote) notes.push(childNote)
    if (d.flags.usesPointer || ['Interactive'].includes(d.category)) notes.push('Reacts to the pointer / touch position (`ShaderView` feeds it automatically).')
    if (d.animatedTimeSpeedProp) notes.push(`Animates on its own clock; \`${d.animatedTimeSpeedProp}\` scales the speed (0 pauses).`)
    if (CLASHING.has(name)) notes.push(`\`${name}\` also exists in SwiftUI or the standard library: write \`ShadersKit.${name}\` in files that import SwiftUI.`)
    if (COMPUTE_GAPS[name]) notes.push(COMPUTE_GAPS[name])
    if (name === 'ImageTexture') notes.push('`url` accepts http(s) URLs, file paths, `data:` URIs, or a key registered with `ShaderMedia.registerImage(_:for:)`.')
    if (name === 'VideoTexture') notes.push('`url` accepts http(s) or file URLs; playback loops and is muted.')
    if (name === 'WebcamTexture') notes.push('iOS and macOS only (camera permission required); renders nothing elsewhere.')
    if (name === 'HTMLInCanvas') notes.push('Upstream captured DOM content. Here it renders a SwiftUI view registered with `ViewTextureRegistry` under the `source` prop (`.prop("source", "myView")`).')
    if (name === 'Text') notes.push('Rasterized with CoreText; Google font names map to the closest installed font.')
    const selectEnums = plans.filter((p) => p.nestedEnum).map((p) => `- \`${name}.${p.nestedEnum!.name}\`: ${p.nestedEnum!.options.map((o) => `.${caseOf(o.value)}`).join(', ')}`)
    const listItems = plans.filter((p) => p.nestedItem).map((p) => `- \`${name}.${p.nestedItem!.name}(${p.nestedItem!.fields.map((f) => `${f.swiftName}: ${f.type}`).join(', ')})\``)
    const example = exampleFor(name, d, plans, acceptsChildren, qualified)
    const md = `# ${name}

${d.description || ''}

- Category: ${d.category ?? '—'} · Role: ${d.role}
- Platforms: ${platform}

## Swift

\`\`\`swift
import ShadersKit

${example}
\`\`\`

Initializer (all parameters optional, defaults shown):

\`\`\`swift
${qualified}(${sigArgs}${acceptsChildren ? ', layer: LayerAttributes = LayerAttributes()) { /* nested layers */ }' : ', layer: LayerAttributes = LayerAttributes())'}
\`\`\`
${selectEnums.length ? `\nOption enums:\n${selectEnums.join('\n')}\n` : ''}${listItems.length ? `\nList item types:\n${listItems.join('\n')}\n` : ''}
## Props

| Prop | Swift type | Default | Range / options | Description |
|---|---|---|---|---|
${d.props.map((p: any, i: number) => `| \`${p.name}\` | \`${plans[i].type}\` | ${fmtDefault(p.defaultValue)} | ${rangeOrOptions(p)} | ${(p.description ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ')} |`).join('\n')}

Dynamic form (same values): \`ShaderNode(type: "${name}", props: [${d.props.slice(0, 2).map((p: any) => `"${p.name}": ${dynExample(p)}`).join(', ')}])\`
${notes.length ? `\n## Notes\n\n${notes.map((n) => `- ${n}`).join('\n')}\n` : ''}`
    fs.writeFileSync(path.join(outDir, `${name}.md`), md)
    const cat = d.category ?? 'Other'
    ;(indexRows[cat] ??= []).push(`| [${name}](components/${name}.md) | ${d.role} | ${d.flags.hasCompute ? 'Metal' : d.cpuSupported ? 'all' : 'Metal'} | ${(d.description ?? '').split(/[.—]/)[0].slice(0, 90)} |`)
}

function caseOf(value: string): string {
    const parts = value.split(/[^A-Za-z0-9]+/).filter(Boolean)
    if (!parts.length) return 'none'
    let s = parts.map((p, i) => (i === 0 ? p.charAt(0).toLowerCase() + p.slice(1) : p.charAt(0).toUpperCase() + p.slice(1))).join('')
    if (/^[A-Z0-9]+$/.test(parts[0])) s = parts[0].toLowerCase() + parts.slice(1).map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase()).join('')
    if (/^[0-9]/.test(s)) s = `_${s}`
    return s
}

function dynExample(p: any): string {
    const v = p.defaultValue
    if (typeof v === 'number') return `.number(${v})`
    if (typeof v === 'boolean') return `.bool(${v})`
    if (typeof v === 'string') return `.string("${v}")`
    if (v && typeof v === 'object' && 'x' in v) return `.position(.xy(x: .number(${v.x}), y: .number(${v.y})))`
    return '.null'
}

function exampleFor(name: string, d: any, plans: PropPlan[], acceptsChildren: boolean, qualified: string): string {
    // show the two or three most "visual" props explicitly
    const picks = plans.filter((p) => ['ShaderColor', 'Float', 'DimensionalValue'].includes(p.type) && !/^(seed|_)/.test(p.name)).slice(0, 3)
    const args = picks.map((p) => `${p.swiftName}: ${p.defaultExpr}`).join(', ')
    if (acceptsChildren) {
        return `ShaderView {\n    ${qualified}(${args}) {\n        ShadersKit.LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")   // the content this ${d.role} applies to\n    }\n}`
    }
    return `ShaderView {\n    ${qualified}(${args})\n}`
}

const cats = Object.keys(indexRows).sort()
const index = `# Component index

199 components, grouped by upstream category. "all" platforms includes watchOS (CPU rasterizer); "Metal" means iOS, iPadOS, macOS, tvOS and visionOS only.

${cats.map((c) => `## ${c}\n\n| Component | Role | Platforms | Summary |\n|---|---|---|---|\n${indexRows[c].join('\n')}`).join('\n\n')}
`
fs.writeFileSync(path.join(repoRoot, 'skills/shaderskit/COMPONENTS.md'), index)
console.log(`wrote ${names.length} component docs + COMPONENTS.md`)
