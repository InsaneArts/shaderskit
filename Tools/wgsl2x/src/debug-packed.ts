import fs from 'node:fs'
import path from 'node:path'
import {link} from './link.js'
import {LayoutCalculator} from './layout.js'
import {emitMSL} from './msl.js'
const dumpDir = process.argv[2]
const only = process.argv[3]
let packedCases = 0
for (const f of fs.readdirSync(dumpDir).sort()) {
    if (!f.endsWith('.json') || f.startsWith('_')) continue
    const name = f.replace(/\.json$/, '')
    if (only && only !== name) continue
    const json = JSON.parse(fs.readFileSync(path.join(dumpDir, f), 'utf8'))
    const input = {shader: json.name, passes: [] as any[], kernels: [] as any[]}
    json.variants.forEach((v: any, vi: number) => {if (v.error) return; input.passes.push({variantIndex: vi, role: 'final', textureKey: null, wgsl: v.finalPass.wgsl}); for (const p of v.rttPasses ?? []) input.passes.push({variantIndex: vi, role: 'rtt', textureKey: p.textureKey, wgsl: p.wgsl})})
    for (const k of json.variants[0]?.recorded?.kernels ?? []) if (!k.wgsl.startsWith('ERROR')) input.kernels.push({index: k.index, dims: k.dims, wgsl: k.wgsl})
    try {
        const unit = link(input)
        const lc = new LayoutCalculator(unit.env.structs, 'uniform')
        for (const sname of unit.hostShareable) {
            if (unit.constructedStructs.has(sname)) {console.log(`${name}: host struct ${sname} is also constructed in code!`); continue}
            const l = lc.structLayout(sname)
            l.fields.forEach((fl, i) => {
                if (fl.type.kind === 'vec' && fl.type.n === 3) {
                    const next = l.fields[i + 1]
                    const end = next ? next.offset : l.size
                    if (end < fl.offset + 16) {packedCases++; console.log(`${name}: ${sname}.${fl.name} vec3 packed (next at +${end - fl.offset})`)}
                }
            })
        }
        if (only) {
            try {emitMSL(unit)} catch (e: any) {console.log(e.stack.split('\n').slice(0, 10).join('\n'))}
            for (const c of unit.consts) console.log('const', c.name, c.type ? 'typed' : 'UNTYPED', (c.init as any).type ? 'initTyped' : 'INIT-UNTYPED')
        }
    } catch (e: any) {console.log(`${name}: link error ${e.message}`)}
}
console.log('packed vec3 cases:', packedCases)
