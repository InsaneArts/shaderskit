// WGSL memory layout (uniform / storage address spaces) for host-shareable types.
import type {StructDecl, Type} from './ast.js'
import {typeToString} from './ast.js'

export interface FieldLayout {
    name: string
    offset: number
    size: number
    type: Type
    /** For nested structs, the nested fields (offsets relative to the parent). */
    fields?: FieldLayout[]
}

export interface StructLayout {
    name: string
    size: number
    align: number
    fields: FieldLayout[]
}

export type LayoutSpace = 'uniform' | 'storage'

const roundUp = (k: number, n: number) => Math.ceil(n / k) * k

export class LayoutCalculator {
    private cache = new Map<string, StructLayout>()
    constructor(private structs: Map<string, StructDecl>, private space: LayoutSpace) {}

    sizeAlign(t: Type): {size: number; align: number} {
        switch (t.kind) {
            case 'scalar': return {size: 4, align: 4}
            case 'atomic': return {size: 4, align: 4}
            case 'vec': return t.n === 2 ? {size: 8, align: 8} : t.n === 3 ? {size: 12, align: 16} : {size: 16, align: 16}
            case 'mat': {
                const col = this.sizeAlign({kind: 'vec', n: t.rows as 2 | 3 | 4, scalar: 'f32'})
                const stride = roundUp(col.align, col.size)
                return {size: stride * t.cols, align: col.align}
            }
            case 'array': {
                const stride = this.arrayStride(t.elem)
                const elem = this.sizeAlign(t.elem)
                const align = this.space === 'uniform' ? Math.max(16, elem.align) : elem.align
                return {size: stride * (t.count ?? 0), align}
            }
            case 'struct': {
                const l = this.structLayout(t.name)
                return {size: l.size, align: l.align}
            }
            default: throw new Error(`layout: type ${typeToString(t)} is not host-shareable`)
        }
    }

    arrayStride(elem: Type): number {
        const e = this.sizeAlign(elem)
        const align = this.space === 'uniform' ? Math.max(16, e.align) : e.align
        return roundUp(align, e.size)
    }

    structLayout(name: string): StructLayout {
        const cached = this.cache.get(name)
        if (cached) return cached
        const decl = this.structs.get(name)
        if (!decl) throw new Error(`layout: unknown struct ${name}`)
        let offset = 0
        let maxAlign = 1
        const fields: FieldLayout[] = []
        for (const m of decl.members) {
            const sa = this.sizeAlign(m.type)
            let align = sa.align
            // explicit @align / @size attributes override
            const alignAttr = m.attrs.find((a) => a.name === 'align')
            const sizeAttr = m.attrs.find((a) => a.name === 'size')
            if (alignAttr) align = Number(alignAttr.args[0])
            if (this.space === 'uniform' && m.type.kind === 'struct') align = Math.max(16, align)
            offset = roundUp(align, offset)
            const size = sizeAttr ? Number(sizeAttr.args[0]) : sa.size
            const f: FieldLayout = {name: m.name, offset, size, type: m.type}
            if (m.type.kind === 'struct') f.fields = this.structLayout(m.type.name).fields
            fields.push(f)
            offset += size
            maxAlign = Math.max(maxAlign, align)
        }
        const align = this.space === 'uniform' ? Math.max(16, maxAlign) : maxAlign
        const layout: StructLayout = {name, size: roundUp(align, offset), align, fields}
        this.cache.set(name, layout)
        return layout
    }
}

/** Flattens a struct layout into dotted paths (e.g. `n_x.colorA`) with absolute offsets. */
export function flattenLayout(l: StructLayout): {path: string; offset: number; type: Type; size: number}[] {
    const out: {path: string; offset: number; type: Type; size: number}[] = []
    const walk = (fields: FieldLayout[], base: number, prefix: string) => {
        for (const f of fields) {
            if (f.fields) walk(f.fields, base + f.offset, `${prefix}${f.name}.`)
            else out.push({path: `${prefix}${f.name}`, offset: base + f.offset, type: f.type, size: f.size})
        }
    }
    walk(l.fields, 0, '')
    return out
}
