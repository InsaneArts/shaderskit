// Stage 1 driver: dump JSON → linked units → MSL files (+ validation with the Metal compiler).
// Usage: tsx src/gen-msl.ts <dumpDir> <outDir> [--only A,B] [--validate]
import fs from 'node:fs'
import path from 'node:path'
import {execFileSync} from 'node:child_process'
import {link, type LinkInput} from './link.js'
import {emitMSL} from './msl.js'

const [dumpDir, outDir, ...rest] = process.argv.slice(2)
if (!dumpDir || !outDir) throw new Error('usage: gen-msl <dumpDir> <outDir> [--only A,B] [--validate]')
const onlyIdx = rest.indexOf('--only')
const only = onlyIdx >= 0 ? new Set(rest[onlyIdx + 1].split(',')) : null
const validate = rest.includes('--validate')
fs.mkdirSync(outDir, {recursive: true})

export function loadLinkInput(dumpDir: string, name: string): {input: LinkInput; json: any} {
    const json = JSON.parse(fs.readFileSync(path.join(dumpDir, `${name}.json`), 'utf8'))
    const input: LinkInput = {shader: json.name, passes: [], kernels: []}
    json.variants.forEach((v: any, vi: number) => {
        if (v.error) return
        input.passes.push({variantIndex: vi, role: 'final', textureKey: null, wgsl: v.finalPass.wgsl})
        for (const p of v.rttPasses ?? []) input.passes.push({variantIndex: vi, role: 'rtt', textureKey: p.textureKey, wgsl: p.wgsl})
    })
    const k0 = json.variants.find((v: any) => !v.error)
    for (const k of k0?.recorded?.kernels ?? []) if (!k.wgsl.startsWith('ERROR')) input.kernels.push({index: k.index, dims: k.dims, wgsl: k.wgsl})
    return {input, json}
}

const names = fs.readdirSync(dumpDir).filter((f) => f.endsWith('.json') && !f.startsWith('_')).map((f) => f.replace(/\.json$/, '')).sort()
let okCount = 0
const failures: string[] = []
const compileFailures: string[] = []
let totalBytes = 0
for (const name of names) {
    if (only && !only.has(name)) continue
    try {
        const {input} = loadLinkInput(dumpDir, name)
        const unit = link(input)
        const emitted = emitMSL(unit)
        const file = path.join(outDir, `${name}.metal`)
        fs.writeFileSync(file, emitted.source)
        fs.writeFileSync(path.join(outDir, `${name}.manifest.json`), JSON.stringify({passes: emitted.passes, kernels: emitted.kernels, uniformLayout: emitted.uniformLayout, kernelUniformLayouts: emitted.kernelUniformLayouts}, null, 1))
        totalBytes += emitted.source.length
        okCount++
        if (validate) {
            try {
                execFileSync('xcrun', ['-sdk', 'macosx', 'metal', '-c', '-Wno-unused-variable', file, '-o', path.join(outDir, `${name}.air`)], {stdio: ['ignore', 'pipe', 'pipe']})
            } catch (e: any) {
                const err = String(e.stderr ?? e.message)
                compileFailures.push(`${name}: ${err.split('\n').filter((l) => l.includes('error:')).slice(0, 4).join(' | ')}`)
            }
        }
    } catch (e: any) {
        failures.push(`${name}: ${e.message}`)
    }
}
console.log(`linked+emitted ${okCount}/${names.length} shaders, ${(totalBytes / 1e6).toFixed(2)} MB of MSL`)
if (failures.length) {console.log(`\nEMIT FAILURES (${failures.length}):`); failures.forEach((f) => console.log('  ' + f))}
if (validate) {
    console.log(`\nMETAL COMPILE: ${okCount - compileFailures.length}/${okCount} ok`)
    compileFailures.forEach((f) => console.log('  ' + f))
}
