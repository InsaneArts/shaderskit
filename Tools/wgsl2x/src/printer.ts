// Canonical WGSL-ish printer used for hashing/deduplicating functions across variants,
// plus a generic AST walker/renamer.
import type {Block, Expr, FnDecl, Stmt, StructDecl, Type} from './ast.js'
import {typeToString} from './ast.js'

export function printExpr(e: Expr): string {
    switch (e.kind) {
        case 'ident': return e.name
        case 'int': return e.text
        case 'float': return e.text
        case 'bool': return String(e.value)
        case 'paren': return `(${printExpr(e.expr)})`
        case 'unary': return `${e.op}${printExpr(e.expr)}`
        case 'binary': return `(${printExpr(e.left)} ${e.op} ${printExpr(e.right)})`
        case 'member': return `${printExpr(e.obj)}.${e.name}`
        case 'index': return `${printExpr(e.obj)}[${printExpr(e.index)}]`
        case 'call': {
            const t = e.templateArgs.length ? `<${e.templateArgs.map(typeToString).join(', ')}>` : ''
            return `${e.callee}${t}(${e.args.map(printExpr).join(', ')})`
        }
    }
}

export function printStmt(s: Stmt, ind = ''): string {
    const b = (bl: Block) => `{\n${bl.map((x) => printStmt(x, ind + '  ')).join('\n')}\n${ind}}`
    switch (s.kind) {
        case 'let': return `${ind}let ${s.name}${s.type ? `: ${typeToString(s.type)}` : ''} = ${printExpr(s.init)};`
        case 'const': return `${ind}const ${s.name}${s.type ? `: ${typeToString(s.type)}` : ''} = ${printExpr(s.init)};`
        case 'var': return `${ind}var ${s.name}${s.type ? `: ${typeToString(s.type)}` : ''}${s.init ? ` = ${printExpr(s.init)}` : ''};`
        case 'assign': return `${ind}${printExpr(s.target)} ${s.op} ${printExpr(s.value)};`
        case 'incdec': return `${ind}${printExpr(s.target)}${s.op};`
        case 'expr': return `${ind}${printExpr(s.expr)};`
        case 'phony': return `${ind}_ = ${printExpr(s.expr)};`
        case 'return': return `${ind}return${s.expr ? ` ${printExpr(s.expr)}` : ''};`
        case 'if': {
            let out = `${ind}if ${printExpr(s.cond)} ${b(s.then)}`
            if (s.else) out += Array.isArray(s.else) ? ` else ${b(s.else)}` : ` else ${printStmt(s.else, ind).trimStart()}`
            return out
        }
        case 'for': return `${ind}for (${s.init ? printStmt(s.init).trim().replace(/;$/, '') : ''}; ${s.cond ? printExpr(s.cond) : ''}; ${s.update ? printStmt(s.update).trim().replace(/;$/, '') : ''}) ${b(s.body)}`
        case 'while': return `${ind}while ${printExpr(s.cond)} ${b(s.body)}`
        case 'loop': return `${ind}loop ${b(s.body)}${s.continuing ? ` continuing ${b(s.continuing)}` : ''}`
        case 'switch': return `${ind}switch ${printExpr(s.selector)} {\n${s.cases.map((c) => `${ind}  ${c.values ? `case ${c.values.map(printExpr).join(', ')}` : 'default'} ${b(c.body)}`).join('\n')}\n${ind}}`
        case 'break': return `${ind}break;`
        case 'continue': return `${ind}continue;`
        case 'discard': return `${ind}discard;`
        case 'block': return `${ind}${b(s.body)}`
    }
}

export function printFn(f: FnDecl): string {
    return `fn ${f.name}(${f.params.map((p) => `${p.name}: ${typeToString(p.type)}`).join(', ')}) -> ${typeToString(f.ret)} {\n${f.body.map((s) => printStmt(s, '  ')).join('\n')}\n}`
}

export function printStruct(s: StructDecl): string {
    return `struct ${s.name} { ${s.members.map((m) => `${m.name}: ${typeToString(m.type)}`).join(', ')} }`
}

// ───────────── walkers ─────────────

export function walkExpr(e: Expr, fn: (e: Expr) => void) {
    fn(e)
    switch (e.kind) {
        case 'paren': walkExpr(e.expr, fn); break
        case 'unary': walkExpr(e.expr, fn); break
        case 'binary': walkExpr(e.left, fn); walkExpr(e.right, fn); break
        case 'member': walkExpr(e.obj, fn); break
        case 'index': walkExpr(e.obj, fn); walkExpr(e.index, fn); break
        case 'call': for (const a of e.args) walkExpr(a, fn); break
    }
}

export function walkStmt(s: Stmt, fnE: (e: Expr) => void, fnS?: (s: Stmt) => void) {
    fnS?.(s)
    const blk = (b: Block) => b.forEach((x) => walkStmt(x, fnE, fnS))
    switch (s.kind) {
        case 'let': case 'const': walkExpr(s.init, fnE); break
        case 'var': if (s.init) walkExpr(s.init, fnE); break
        case 'assign': walkExpr(s.target, fnE); walkExpr(s.value, fnE); break
        case 'incdec': walkExpr(s.target, fnE); break
        case 'expr': case 'phony': walkExpr(s.expr, fnE); break
        case 'return': if (s.expr) walkExpr(s.expr, fnE); break
        case 'if': walkExpr(s.cond, fnE); blk(s.then); if (s.else) {if (Array.isArray(s.else)) blk(s.else); else walkStmt(s.else, fnE, fnS)} break
        case 'for': if (s.init) walkStmt(s.init, fnE, fnS); if (s.cond) walkExpr(s.cond, fnE); if (s.update) walkStmt(s.update, fnE, fnS); blk(s.body); break
        case 'while': walkExpr(s.cond, fnE); blk(s.body); break
        case 'loop': blk(s.body); if (s.continuing) blk(s.continuing); break
        case 'switch': walkExpr(s.selector, fnE); for (const c of s.cases) {if (c.values) c.values.forEach((v) => walkExpr(v, fnE)); blk(c.body)} break
        case 'block': blk(s.body); break
    }
}

export function walkFn(f: FnDecl, fnE: (e: Expr) => void, fnS?: (s: Stmt) => void) {
    f.body.forEach((s) => walkStmt(s, fnE, fnS))
}

/** Renames struct references inside a type (in place where possible; returns the new type). */
export function renameType(t: Type, map: Map<string, string>): Type {
    switch (t.kind) {
        case 'struct': {const n = map.get(t.name); return n ? {kind: 'struct', name: n} : t}
        case 'array': return {kind: 'array', elem: renameType(t.elem, map), count: t.count}
        case 'ptr': return {kind: 'ptr', space: t.space, inner: renameType(t.inner, map)}
        default: return t
    }
}

/** Applies struct + function renames throughout a function declaration (types, callees, annotations). */
export function renameInFn(f: FnDecl, structMap: Map<string, string>, fnMap: Map<string, string>) {
    f.params = f.params.map((p) => ({name: p.name, type: renameType(p.type, structMap)}))
    f.ret = renameType(f.ret, structMap)
    const fixType = (e: Expr) => {if (e.type) e.type = renameType(e.type, structMap)}
    walkFn(f, (e) => {
        fixType(e)
        if (e.kind === 'call') {
            const sm = structMap.get(e.callee)
            if (sm) e.callee = sm
            const fm = fnMap.get(e.callee)
            if (fm) e.callee = fm
            e.templateArgs = e.templateArgs.map((t) => renameType(t, structMap))
        }
    }, (s) => {
        if ((s.kind === 'let' || s.kind === 'var' || s.kind === 'const') && s.type) s.type = renameType(s.type, structMap)
    })
}
