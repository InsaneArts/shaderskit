// Parses + type-checks every dumped WGSL pass and kernel. Usage: tsx src/selftest.ts <dumpDir>
import fs from 'node:fs'
import path from 'node:path'
import {parseWGSL} from './parser.js'
import {inferModule} from './types.js'

const dir = process.argv[2]
if (!dir) throw new Error('usage: selftest <dumpDir>')
let ok = 0
let fail = 0
const failures = new Map<string, number>()
const examples = new Map<string, string>()
for (const f of fs.readdirSync(dir).sort()) {
    if (!f.endsWith('.json') || f.startsWith('_')) continue
    const j = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'))
    const sources: {label: string; wgsl: string}[] = []
    j.variants.forEach((v: any, vi: number) => {
        if (v.finalPass) sources.push({label: `${j.name}#${vi}:final`, wgsl: v.finalPass.wgsl})
        for (const p of v.rttPasses ?? []) sources.push({label: `${j.name}#${vi}:${p.textureKey}`, wgsl: p.wgsl})
        if (vi === 0) for (const k of v.recorded?.kernels ?? []) if (!k.wgsl.startsWith('ERROR')) sources.push({label: `${j.name}:kernel${k.index}`, wgsl: k.wgsl})
    })
    for (const s of sources) {
        try {
            const mod = parseWGSL(s.wgsl)
            inferModule(mod)
            ok++
        } catch (e: any) {
            fail++
            const msg = String(e.message).replace(/line \d+/, 'line N').replace(/identifier \w+/, 'identifier X')
            failures.set(msg, (failures.get(msg) ?? 0) + 1)
            if (!examples.has(msg)) examples.set(msg, s.label)
        }
    }
}
console.log(`ok=${ok} fail=${fail}`)
for (const [m, c] of [...failures.entries()].sort((a, b) => b[1] - a[1])) console.log(`${c}\t${m}\t(e.g. ${examples.get(m)})`)
