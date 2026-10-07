// Dumps the composition kit (blend modes, mask functions, tone mapping, OETF) as WGSL for the Swift port.
import {it} from 'vitest'
import fs from 'node:fs'
import path from 'node:path'
import {tgpu} from '@coreroot/gpu/kit'
import {blendModes, unpremultiplyAlpha} from '@coreroot/gpu/kit/blend'
import {maskFunctions} from '@coreroot/gpu/kit/mask'
import {tonemapFns, linearToSrgb, srgbToLinear} from '@coreroot/gpu/kit/tonemap'

const OUT = process.env.DUMP_OUT ?? path.resolve(__dirname, '../../../../../dump-out')

it('dumps the composition kit', () => {
    fs.mkdirSync(OUT, {recursive: true})
    const fns: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(blendModes)) fns[`blend_${k.replace(/[^a-zA-Z0-9_]/g, '_')}`] = v
    for (const [k, v] of Object.entries(maskFunctions)) fns[`mask_${k}`] = v
    for (const [k, v] of Object.entries(tonemapFns)) fns[`tone_${k}`] = v
    fns.linearToSrgb = linearToSrgb
    fns.srgbToLinear = srgbToLinear
    fns.unpremultiplyAlpha = unpremultiplyAlpha
    const out: Record<string, string> = {}
    for (const [name, fn] of Object.entries(fns)) {
        try {
            ;(fn as any).$name?.(name)
        } catch {}
        out[name] = (tgpu as any).resolve([fn], {names: 'strict'})
    }
    fs.writeFileSync(path.join(OUT, '_kit.json'), JSON.stringify({blendModes: Object.keys(blendModes), maskTypes: Object.keys(maskFunctions), toneModes: Object.keys(tonemapFns), wgsl: out}, null, 1))
})
