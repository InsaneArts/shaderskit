// Lexer + recursive-descent parser for the WGSL subset TypeGPU emits.
import type {Attr, Block, ConstDecl, Expr, FnDecl, GlobalVar, Item, Module, Param, Stmt, StructDecl, StructMember, Type} from './ast.js'
import {BOOL, F32, I32, U32, VOID} from './ast.js'

// ───────────────────────────── lexer ─────────────────────────────

export type TokKind = 'ident' | 'int' | 'float' | 'punct' | 'eof'
export interface Tok {
    kind: TokKind
    text: string
    pos: number
    line: number
}

const PUNCTS = [
    '<<=', '>>=', '->', '==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<', '>>',
    '(', ')', '{', '}', '[', ']', ',', ';', ':', '.', '@', '=', '<', '>', '+', '-', '*', '/', '%', '!', '&', '|', '^', '~',
]

export function lex(src: string): Tok[] {
    const toks: Tok[] = []
    let i = 0
    let line = 1
    const n = src.length
    while (i < n) {
        const c = src[i]
        if (c === '\n') {line++; i++; continue}
        if (c === ' ' || c === '\t' || c === '\r') {i++; continue}
        if (c === '/' && src[i + 1] === '/') {
            while (i < n && src[i] !== '\n') i++
            continue
        }
        if (c === '/' && src[i + 1] === '*') {
            i += 2
            while (i < n && !(src[i] === '*' && src[i + 1] === '/')) {if (src[i] === '\n') line++; i++}
            i += 2
            continue
        }
        if (/[A-Za-z_]/.test(c)) {
            let j = i + 1
            while (j < n && /[A-Za-z0-9_]/.test(src[j])) j++
            toks.push({kind: 'ident', text: src.slice(i, j), pos: i, line})
            i = j
            continue
        }
        if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1] ?? ''))) {
            // number: hex, int (with i/u suffix), float (with f/h suffix, exponent)
            let j = i
            let isFloat = false
            if (c === '0' && (src[i + 1] === 'x' || src[i + 1] === 'X')) {
                j = i + 2
                while (j < n && /[0-9a-fA-F]/.test(src[j])) j++
            } else {
                while (j < n && /[0-9]/.test(src[j])) j++
                if (src[j] === '.') {
                    isFloat = true
                    j++
                    while (j < n && /[0-9]/.test(src[j])) j++
                }
                if (src[j] === 'e' || src[j] === 'E') {
                    const k = j + 1 + ((src[j + 1] === '+' || src[j + 1] === '-') ? 1 : 0)
                    if (/[0-9]/.test(src[k] ?? '')) {
                        isFloat = true
                        j = k
                        while (j < n && /[0-9]/.test(src[j])) j++
                    }
                }
            }
            if (src[j] === 'f' || src[j] === 'h') {isFloat = true; j++}
            else if (src[j] === 'i' || src[j] === 'u') {j++}
            toks.push({kind: isFloat ? 'float' : 'int', text: src.slice(i, j), pos: i, line})
            i = j
            continue
        }
        let matched = false
        for (const p of PUNCTS) {
            if (src.startsWith(p, i)) {
                toks.push({kind: 'punct', text: p, pos: i, line})
                i += p.length
                matched = true
                break
            }
        }
        if (!matched) throw new Error(`lex: unexpected character '${c}' at line ${line}`)
    }
    toks.push({kind: 'eof', text: '', pos: n, line})
    return toks
}

// ───────────────────────────── parser ─────────────────────────────

const TEMPLATE_HEADS = new Set(['array', 'vec2', 'vec3', 'vec4', 'mat2x2', 'mat3x3', 'mat4x4', 'ptr', 'atomic', 'texture_2d', 'texture_storage_2d', 'bitcast', 'texture_2d_array', 'texture_3d', 'texture_cube'])

export class Parser {
    private toks: Tok[]
    private p = 0
    constructor(src: string) {
        this.toks = lex(src)
    }

    private peek(o = 0): Tok {return this.toks[Math.min(this.p + o, this.toks.length - 1)]}
    private next(): Tok {return this.toks[this.p++]}
    private is(text: string, o = 0): boolean {const t = this.peek(o); return t.kind !== 'eof' && t.text === text}
    private accept(text: string): boolean {if (this.is(text)) {this.p++; return true} return false}
    private expect(text: string): Tok {
        const t = this.next()
        if (t.text !== text) throw new Error(`parse: expected '${text}' but got '${t.text}' at line ${t.line}`)
        return t
    }
    private ident(): string {
        const t = this.next()
        if (t.kind !== 'ident') throw new Error(`parse: expected identifier but got '${t.text}' at line ${t.line}`)
        return t.text
    }

    parseModule(): Module {
        const items: Item[] = []
        while (this.peek().kind !== 'eof') {
            const attrs = this.parseAttrs()
            if (this.is('struct')) items.push(this.parseStruct())
            else if (this.is('fn')) items.push(this.parseFn(attrs))
            else if (this.is('var')) items.push(this.parseGlobalVar(attrs))
            else if (this.is('const') || this.is('override')) items.push(this.parseGlobalConst())
            else if (this.is('alias')) {throw new Error('parse: alias unsupported')}
            else if (this.accept(';')) continue
            else throw new Error(`parse: unexpected top-level token '${this.peek().text}' at line ${this.peek().line}`)
        }
        return {items}
    }

    private parseAttrs(): Attr[] {
        const attrs: Attr[] = []
        while (this.accept('@')) {
            const name = this.ident()
            const args: string[] = []
            if (this.accept('(')) {
                while (!this.is(')')) {
                    // attribute args are literals / identifiers / simple expressions
                    let s = ''
                    let depth = 0
                    while (!(depth === 0 && (this.is(',') || this.is(')')))) {
                        const t = this.next()
                        if (t.text === '(') depth++
                        if (t.text === ')') depth--
                        s += t.text
                    }
                    args.push(s)
                    this.accept(',')
                }
                this.expect(')')
            }
            attrs.push({name, args})
        }
        return attrs
    }

    private parseStruct(): StructDecl {
        this.expect('struct')
        const name = this.ident()
        this.expect('{')
        const members: StructMember[] = []
        while (!this.is('}')) {
            const attrs = this.parseAttrs()
            const mname = this.ident()
            this.expect(':')
            const type = this.parseType()
            members.push({name: mname, type, attrs})
            if (!this.accept(',')) break
        }
        this.expect('}')
        this.accept(';')
        return {kind: 'struct', name, members}
    }

    private parseGlobalVar(attrs: Attr[]): GlobalVar {
        this.expect('var')
        let space: GlobalVar['space'] = 'handle'
        let access: GlobalVar['access'] = null
        if (this.accept('<')) {
            space = this.ident() as GlobalVar['space']
            if (this.accept(',')) access = this.ident() as GlobalVar['access']
            this.expect('>')
        }
        const name = this.ident()
        this.expect(':')
        const type = this.parseType()
        if (this.accept('=')) this.parseExpr() // ignore initializer for globals (not emitted by TypeGPU)
        this.accept(';')
        const g = (n: string) => {const a = attrs.find((x) => x.name === n); return a ? Number(a.args[0]) : null}
        return {kind: 'global', name, type, space, access, group: g('group'), binding: g('binding')}
    }

    private parseGlobalConst(): ConstDecl {
        this.next() // const | override
        const name = this.ident()
        let type: Type | null = null
        if (this.accept(':')) type = this.parseType()
        this.expect('=')
        const init = this.parseExpr()
        this.accept(';')
        return {kind: 'const', name, type, init}
    }

    private parseFn(attrs: Attr[]): FnDecl {
        this.expect('fn')
        const name = this.ident()
        this.expect('(')
        const params: Param[] = []
        while (!this.is(')')) {
            this.parseAttrs()
            const pname = this.ident()
            this.expect(':')
            const type = this.parseType()
            params.push({name: pname, type})
            if (!this.accept(',')) break
        }
        this.expect(')')
        let ret: Type = VOID
        if (this.accept('->')) {
            this.parseAttrs()
            ret = this.parseType()
        }
        const body = this.parseBlock()
        const stage = attrs.find((a) => a.name === 'fragment') ? 'fragment' : attrs.find((a) => a.name === 'compute') ? 'compute' : attrs.find((a) => a.name === 'vertex') ? 'vertex' : null
        return {kind: 'fn', name, params, ret, body, stage, attrs}
    }

    parseType(): Type {
        const t = this.next()
        if (t.kind !== 'ident') throw new Error(`parse: expected type but got '${t.text}' at line ${t.line}`)
        const name = t.text
        switch (name) {
            case 'f32': return F32
            case 'i32': return I32
            case 'u32': return U32
            case 'bool': return BOOL
            case 'vec2f': return {kind: 'vec', n: 2, scalar: 'f32'}
            case 'vec3f': return {kind: 'vec', n: 3, scalar: 'f32'}
            case 'vec4f': return {kind: 'vec', n: 4, scalar: 'f32'}
            case 'vec2i': return {kind: 'vec', n: 2, scalar: 'i32'}
            case 'vec3i': return {kind: 'vec', n: 3, scalar: 'i32'}
            case 'vec4i': return {kind: 'vec', n: 4, scalar: 'i32'}
            case 'vec2u': return {kind: 'vec', n: 2, scalar: 'u32'}
            case 'vec3u': return {kind: 'vec', n: 3, scalar: 'u32'}
            case 'vec4u': return {kind: 'vec', n: 4, scalar: 'u32'}
            case 'mat2x2f': return {kind: 'mat', cols: 2, rows: 2}
            case 'mat3x3f': return {kind: 'mat', cols: 3, rows: 3}
            case 'mat4x4f': return {kind: 'mat', cols: 4, rows: 4}
            case 'sampler': return {kind: 'sampler'}
            case 'texture_external': return {kind: 'texture', dim: 'external', sample: 'f32'}
            case 'vec2': case 'vec3': case 'vec4': {
                this.expect('<')
                const inner = this.parseType()
                this.expect('>')
                if (inner.kind !== 'scalar') throw new Error('parse: vec of non-scalar')
                return {kind: 'vec', n: Number(name[3]) as 2 | 3 | 4, scalar: inner.scalar}
            }
            case 'array': {
                this.expect('<')
                const elem = this.parseType()
                let count: number | null = null
                if (this.accept(',')) {
                    const c = this.next()
                    count = Number(c.text.replace(/[iu]$/, ''))
                }
                this.expect('>')
                return {kind: 'array', elem, count}
            }
            case 'ptr': {
                this.expect('<')
                const space = this.ident()
                this.expect(',')
                const inner = this.parseType()
                if (this.accept(',')) this.ident()
                this.expect('>')
                return {kind: 'ptr', space, inner}
            }
            case 'atomic': {
                this.expect('<')
                const inner = this.parseType()
                this.expect('>')
                if (inner.kind !== 'scalar') throw new Error('parse: atomic of non-scalar')
                return {kind: 'atomic', inner: inner.scalar}
            }
            case 'texture_2d': {
                this.expect('<')
                const inner = this.parseType()
                this.expect('>')
                return {kind: 'texture', dim: '2d', sample: inner.kind === 'scalar' ? inner.scalar : 'f32'}
            }
            case 'texture_storage_2d': {
                this.expect('<')
                const format = this.ident()
                this.expect(',')
                const access = this.ident()
                this.expect('>')
                return {kind: 'texture', dim: 'storage2d', sample: 'f32', format, access}
            }
            default:
                return {kind: 'struct', name}
        }
    }

    private parseBlock(): Block {
        this.expect('{')
        const stmts: Stmt[] = []
        while (!this.is('}')) stmts.push(this.parseStmt())
        this.expect('}')
        return stmts
    }

    private parseStmt(): Stmt {
        const t = this.peek()
        if (t.kind === 'punct') {
            if (t.text === '{') return {kind: 'block', body: this.parseBlock()}
            if (t.text === ';') {this.next(); return {kind: 'block', body: []}}
            if (t.text === '@') {this.parseAttrs(); return this.parseStmt()}
        }
        if (t.kind === 'ident') {
            switch (t.text) {
                case 'let': {
                    this.next()
                    const name = this.ident()
                    let type: Type | null = null
                    if (this.accept(':')) type = this.parseType()
                    this.expect('=')
                    const init = this.parseExpr()
                    this.expect(';')
                    return {kind: 'let', name, type, init}
                }
                case 'const': {
                    this.next()
                    const name = this.ident()
                    let type: Type | null = null
                    if (this.accept(':')) type = this.parseType()
                    this.expect('=')
                    const init = this.parseExpr()
                    this.expect(';')
                    return {kind: 'const', name, type, init}
                }
                case 'var': {
                    this.next()
                    if (this.accept('<')) {this.ident(); this.expect('>')}
                    const name = this.ident()
                    let type: Type | null = null
                    if (this.accept(':')) type = this.parseType()
                    let init: Expr | null = null
                    if (this.accept('=')) init = this.parseExpr()
                    this.expect(';')
                    return {kind: 'var', name, type, init}
                }
                case 'return': {
                    this.next()
                    if (this.accept(';')) return {kind: 'return', expr: null}
                    const expr = this.parseExpr()
                    this.expect(';')
                    return {kind: 'return', expr}
                }
                case 'if': {
                    this.next()
                    const cond = this.parseParenOrExpr()
                    const then = this.parseBlock()
                    let els: Block | Stmt | null = null
                    if (this.accept('else')) {
                        if (this.is('if')) els = this.parseStmt()
                        else els = this.parseBlock()
                    }
                    return {kind: 'if', cond, then, else: els}
                }
                case 'for': {
                    this.next()
                    this.expect('(')
                    let init: Stmt | null = null
                    if (!this.is(';')) init = this.parseSimpleStmt()
                    this.expect(';')
                    let cond: Expr | null = null
                    if (!this.is(';')) cond = this.parseExpr()
                    this.expect(';')
                    let update: Stmt | null = null
                    if (!this.is(')')) update = this.parseSimpleStmt()
                    this.expect(')')
                    const body = this.parseBlock()
                    return {kind: 'for', init, cond, update, body}
                }
                case 'while': {
                    this.next()
                    const cond = this.parseParenOrExpr()
                    const body = this.parseBlock()
                    return {kind: 'while', cond, body}
                }
                case 'loop': {
                    this.next()
                    this.expect('{')
                    const body: Stmt[] = []
                    let continuing: Block | null = null
                    while (!this.is('}')) {
                        if (this.is('continuing')) {this.next(); continuing = this.parseBlock(); continue}
                        body.push(this.parseStmt())
                    }
                    this.expect('}')
                    return {kind: 'loop', body, continuing}
                }
                case 'switch': {
                    this.next()
                    const selector = this.parseParenOrExpr()
                    this.expect('{')
                    const cases: {values: Expr[] | null; body: Block}[] = []
                    while (!this.is('}')) {
                        if (this.accept('default')) {
                            this.accept(':')
                            cases.push({values: null, body: this.parseBlock()})
                        } else {
                            this.expect('case')
                            const values: Expr[] = []
                            let hasDefault = false
                            while (!this.is('{') && !this.is(':')) {
                                if (this.accept('default')) {hasDefault = true}
                                else values.push(this.parseExpr())
                                this.accept(',')
                            }
                            this.accept(':')
                            const body = this.parseBlock()
                            cases.push({values: hasDefault ? null : values, body})
                        }
                    }
                    this.expect('}')
                    return {kind: 'switch', selector, cases}
                }
                case 'break': this.next(); this.expect(';'); return {kind: 'break'}
                case 'continue': this.next(); this.expect(';'); return {kind: 'continue'}
                case 'discard': this.next(); this.expect(';'); return {kind: 'discard'}
                case '_': {
                    this.next()
                    this.expect('=')
                    const expr = this.parseExpr()
                    this.expect(';')
                    return {kind: 'phony', expr}
                }
            }
        }
        const s = this.parseSimpleStmt()
        this.expect(';')
        return s
    }

    private parseParenOrExpr(): Expr {
        return this.parseExpr()
    }

    // assignment / increment / call statement (no trailing ';')
    private parseSimpleStmt(): Stmt {
        if (this.is('var') || this.is('let') || this.is('const')) {
            // for-init declarations
            const kw = this.next().text
            const name = this.ident()
            let type: Type | null = null
            if (this.accept(':')) type = this.parseType()
            let init: Expr | null = null
            if (this.accept('=')) init = this.parseExpr()
            if (kw === 'var') return {kind: 'var', name, type, init}
            if (!init) throw new Error('parse: let without initializer')
            return {kind: kw === 'let' ? 'let' : 'const', name, type, init}
        }
        if (this.is('_') && this.is('=', 1)) {
            this.next(); this.next()
            return {kind: 'phony', expr: this.parseExpr()}
        }
        const target = this.parseExpr()
        if (this.is('++') || this.is('--')) {
            const op = this.next().text as '++' | '--'
            return {kind: 'incdec', target, op}
        }
        const t = this.peek()
        if (t.kind === 'punct' && ['=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>='].includes(t.text)) {
            this.next()
            const value = this.parseExpr()
            return {kind: 'assign', target, op: t.text, value}
        }
        return {kind: 'expr', expr: target}
    }

    // ── expressions (precedence climbing) ──
    parseExpr(): Expr {return this.parseBinary(0)}

    private static PREC: Record<string, number> = {
        '||': 1, '&&': 2, '|': 3, '^': 4, '&': 5,
        '==': 6, '!=': 6, '<': 7, '>': 7, '<=': 7, '>=': 7,
        '<<': 8, '>>': 8, '+': 9, '-': 9, '*': 10, '/': 10, '%': 10,
    }

    private parseBinary(minPrec: number): Expr {
        let left = this.parseUnary()
        for (;;) {
            const t = this.peek()
            if (t.kind !== 'punct') break
            const prec = Parser.PREC[t.text]
            if (prec === undefined || prec < minPrec) break
            // disambiguate: '>' closing a template never reaches here because templates are
            // consumed by parseType / callee template parsing
            this.next()
            const right = this.parseBinary(prec + 1)
            left = {kind: 'binary', op: t.text, left, right}
        }
        return left
    }

    private parseUnary(): Expr {
        const t = this.peek()
        if (t.kind === 'punct' && (t.text === '-' || t.text === '!' || t.text === '~' || t.text === '&' || t.text === '*')) {
            this.next()
            const expr = this.parseUnary()
            return {kind: 'unary', op: t.text as '-' | '!' | '~' | '&' | '*', expr}
        }
        return this.parsePostfix(this.parsePrimary())
    }

    private parsePostfix(e: Expr): Expr {
        for (;;) {
            if (this.accept('.')) {
                const name = this.ident()
                e = {kind: 'member', obj: e, name}
            } else if (this.accept('[')) {
                const index = this.parseExpr()
                this.expect(']')
                e = {kind: 'index', obj: e, index}
            } else break
        }
        return e
    }

    private parsePrimary(): Expr {
        const t = this.next()
        if (t.kind === 'int') {
            const suffix = t.text.endsWith('i') ? 'i' : t.text.endsWith('u') ? 'u' : null
            const body = suffix ? t.text.slice(0, -1) : t.text
            return {kind: 'int', text: t.text, value: BigInt(body), suffix}
        }
        if (t.kind === 'float') {
            const suffix = t.text.endsWith('f') ? 'f' : t.text.endsWith('h') ? 'h' : null
            return {kind: 'float', text: t.text, suffix}
        }
        if (t.kind === 'punct' && t.text === '(') {
            const expr = this.parseExpr()
            this.expect(')')
            return {kind: 'paren', expr}
        }
        if (t.kind === 'ident') {
            if (t.text === 'true') return {kind: 'bool', value: true}
            if (t.text === 'false') return {kind: 'bool', value: false}
            // template call: array<T, N>(...), bitcast<T>(x), vec3<f32>(...)
            let templateArgs: Type[] = []
            if (this.is('<') && TEMPLATE_HEADS.has(t.text)) {
                this.expect('<')
                while (!this.is('>')) {
                    // array count may be an int literal
                    const nt = this.peek()
                    if (nt.kind === 'int') {this.next(); templateArgs.push({kind: 'array', elem: VOID, count: Number(nt.text.replace(/[iu]$/, ''))})}
                    else templateArgs.push(this.parseType())
                    if (!this.accept(',')) break
                }
                this.expect('>')
                // normalise array<T, N> template into a single array type
                if (t.text === 'array') {
                    const elem = templateArgs[0]
                    const cnt = templateArgs[1]
                    templateArgs = [{kind: 'array', elem, count: cnt && cnt.kind === 'array' ? cnt.count : null}]
                }
            }
            if (this.accept('(')) {
                const args: Expr[] = []
                while (!this.is(')')) {
                    args.push(this.parseExpr())
                    if (!this.accept(',')) break
                }
                this.expect(')')
                return {kind: 'call', callee: t.text, templateArgs, args}
            }
            return {kind: 'ident', name: t.text}
        }
        throw new Error(`parse: unexpected token '${t.text}' at line ${t.line}`)
    }
}

export function parseWGSL(src: string): Module {
    return new Parser(src).parseModule()
}
