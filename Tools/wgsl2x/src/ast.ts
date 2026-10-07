// AST + type representation for the TypeGPU-emitted WGSL subset.

export type Scalar = 'f32' | 'i32' | 'u32' | 'bool'

export type Type =
    | {kind: 'scalar'; scalar: Scalar; abstract?: boolean}
    | {kind: 'vec'; n: 2 | 3 | 4; scalar: Scalar; packed?: boolean}
    | {kind: 'mat'; cols: number; rows: number}
    | {kind: 'array'; elem: Type; count: number | null}
    | {kind: 'struct'; name: string}
    | {kind: 'texture'; dim: '2d' | 'storage2d' | 'external'; sample: Scalar; format?: string; access?: string}
    | {kind: 'sampler'}
    | {kind: 'ptr'; space: string; inner: Type}
    | {kind: 'atomic'; inner: Scalar}
    | {kind: 'void'}

export const F32: Type = {kind: 'scalar', scalar: 'f32'}
export const I32: Type = {kind: 'scalar', scalar: 'i32'}
export const U32: Type = {kind: 'scalar', scalar: 'u32'}
export const BOOL: Type = {kind: 'scalar', scalar: 'bool'}
export const VOID: Type = {kind: 'void'}
export const vec = (n: 2 | 3 | 4, scalar: Scalar = 'f32'): Type => ({kind: 'vec', n, scalar})

export interface Attr {
    name: string
    args: string[]
}

export interface StructMember {
    name: string
    type: Type
    attrs: Attr[]
}

export interface StructDecl {
    kind: 'struct'
    name: string
    members: StructMember[]
}

export interface GlobalVar {
    kind: 'global'
    name: string
    type: Type
    space: 'uniform' | 'storage' | 'handle' | 'private' | 'workgroup'
    access: 'read' | 'read_write' | null
    group: number | null
    binding: number | null
}

export interface ConstDecl {
    kind: 'const'
    name: string
    type: Type | null
    init: Expr
}

export interface Param {
    name: string
    type: Type
}

export interface FnDecl {
    kind: 'fn'
    name: string
    params: Param[]
    ret: Type
    body: Block
    stage: 'fragment' | 'compute' | 'vertex' | null
    attrs: Attr[]
}

export type Item = StructDecl | GlobalVar | ConstDecl | FnDecl

export interface Module {
    items: Item[]
}

export type Block = Stmt[]

export type Stmt =
    | {kind: 'let'; name: string; type: Type | null; init: Expr}
    | {kind: 'var'; name: string; type: Type | null; init: Expr | null}
    | {kind: 'const'; name: string; type: Type | null; init: Expr}
    | {kind: 'assign'; target: Expr; op: string; value: Expr}
    | {kind: 'incdec'; target: Expr; op: '++' | '--'}
    | {kind: 'expr'; expr: Expr}
    | {kind: 'phony'; expr: Expr}
    | {kind: 'return'; expr: Expr | null}
    | {kind: 'if'; cond: Expr; then: Block; else: Block | Stmt | null}
    | {kind: 'for'; init: Stmt | null; cond: Expr | null; update: Stmt | null; body: Block}
    | {kind: 'while'; cond: Expr; body: Block}
    | {kind: 'loop'; body: Block; continuing: Block | null}
    | {kind: 'break'}
    | {kind: 'continue'}
    | {kind: 'discard'}
    | {kind: 'block'; body: Block}
    | {kind: 'switch'; selector: Expr; cases: {values: Expr[] | null; body: Block}[]}

export type Expr =
    | {kind: 'ident'; name: string; type?: Type}
    | {kind: 'int'; text: string; value: bigint; suffix: 'i' | 'u' | null; type?: Type}
    | {kind: 'float'; text: string; suffix: 'f' | 'h' | null; type?: Type}
    | {kind: 'bool'; value: boolean; type?: Type}
    | {kind: 'unary'; op: '-' | '!' | '~' | '&' | '*'; expr: Expr; type?: Type}
    | {kind: 'binary'; op: string; left: Expr; right: Expr; type?: Type}
    | {kind: 'call'; callee: string; templateArgs: Type[]; args: Expr[]; type?: Type}
    | {kind: 'member'; obj: Expr; name: string; type?: Type}
    | {kind: 'index'; obj: Expr; index: Expr; type?: Type}
    | {kind: 'paren'; expr: Expr; type?: Type}

export function typeToString(t: Type): string {
    switch (t.kind) {
        case 'scalar': return t.scalar
        case 'vec': return `vec${t.n}<${t.scalar}>`
        case 'mat': return `mat${t.cols}x${t.rows}<f32>`
        case 'array': return `array<${typeToString(t.elem)}${t.count === null ? '' : `, ${t.count}`}>`
        case 'struct': return t.name
        case 'texture': return t.dim === 'external' ? 'texture_external' : t.dim === 'storage2d' ? `texture_storage_2d<${t.format}, ${t.access}>` : `texture_2d<${t.sample}>`
        case 'sampler': return 'sampler'
        case 'ptr': return `ptr<${t.space}, ${typeToString(t.inner)}>`
        case 'atomic': return `atomic<${t.inner}>`
        case 'void': return 'void'
    }
}

export function typeEquals(a: Type, b: Type): boolean {
    return typeToString(a) === typeToString(b)
}

export function isNumericScalar(t: Type): t is {kind: 'scalar'; scalar: Scalar} {
    return t.kind === 'scalar' && t.scalar !== 'bool'
}

export function scalarOf(t: Type): Scalar | null {
    if (t.kind === 'scalar') return t.scalar
    if (t.kind === 'vec') return t.scalar
    if (t.kind === 'mat') return 'f32'
    return null
}

export function vecLen(t: Type): number {
    return t.kind === 'vec' ? t.n : 1
}
