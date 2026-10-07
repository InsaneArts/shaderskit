#!/usr/bin/env node
// Prints a ShadersKit component's API from the package's descriptor JSON.
// Usage (from the ShadersKit repository root, or with SHADERSKIT_ROOT set):
//   node skills/shaderskit/scripts/component.js SunBurst
//   node skills/shaderskit/scripts/component.js --list [category]
const fs = require('fs')
const path = require('path')

const root = process.env.SHADERSKIT_ROOT || path.resolve(__dirname, '../../..')
const dir = path.join(root, 'Sources/ShadersKit/Resources/Descriptors')
const args = process.argv.slice(2)

function load(name) {
    const f = path.join(dir, `${name}.json`)
    if (!fs.existsSync(f)) {
        console.error(`unknown component "${name}" (looked in ${dir})`)
        process.exit(1)
    }
    return JSON.parse(fs.readFileSync(f, 'utf8'))
}

if (!args.length || args[0] === '--list') {
    const index = JSON.parse(fs.readFileSync(path.join(dir, 'index.json'), 'utf8'))
    const filter = args[1]?.toLowerCase()
    for (const e of index) {
        if (filter && !(e.category || '').toLowerCase().includes(filter)) continue
        console.log(`${e.name.padEnd(22)} ${(e.category || '').padEnd(14)} ${e.role.padEnd(12)} ${e.hasCompute ? 'Metal' : e.cpuSupported ? 'all  ' : 'Metal'}  ${e.description}`)
    }
    process.exit(0)
}

const d = load(args[0])
const fmt = (v) => (v === null || v === undefined ? '—' : typeof v === 'object' && 'x' in v ? `(${v.x}, ${v.y})` : JSON.stringify(v))
console.log(`${d.name} — ${d.description}`)
console.log(`category: ${d.category}   role: ${d.role}   platforms: ${d.flags.hasCompute ? 'Metal only (no watchOS)' : d.cpuSupported ? 'all incl. watchOS' : 'Metal only'}`)
if (d.flags.requiresChild) console.log('wraps content: yes (trailing closure required)')
if (d.animatedTimeSpeedProp) console.log(`animated: yes (speed prop "${d.animatedTimeSpeedProp}")`)
console.log('\nprops:')
for (const p of d.props) {
    const ui = p.ui || {}
    let range = ''
    if (Array.isArray(ui.options)) range = ui.options.map((o) => o.value).join(' | ')
    else if (typeof ui.min === 'number' || typeof ui.max === 'number') range = `${ui.min ?? '…'}..${ui.max ?? '…'}${typeof ui.step === 'number' ? ` step ${ui.step}` : ''}`
    if (Array.isArray(ui.units) && ui.units.includes('px')) range += ' (fraction or px)'
    console.log(`  ${p.name.padEnd(18)} ${(p.transform.kind === 'none' ? (typeof p.defaultValue) : p.transform.kind).padEnd(12)} default ${fmt(p.defaultValue).padEnd(22)} ${range.padEnd(28)} ${p.description || ''}`)
}
console.log(`\ndocs: skills/shaderskit/components/${d.name}.md`)
