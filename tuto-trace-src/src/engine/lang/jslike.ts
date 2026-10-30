// Parser commun JavaScript / TypeScript (accolades, points-virgules facultatifs).
// TypeScript : les annotations de type sont lues (et vérifiées par checkTs), puis effacées à l'exécution.
import { joinSpan, type CompileError, type Expr, type FuncDecl, type Param, type Program, type Span, type Stmt, type TypeRef } from '../ast'
import { ParserBase } from '../parser-base'
import { LineMap, tokenize, type Token } from '../tokenizer'

const ASSIGN_OPS = ['=', '+=', '-=', '*=', '/=', '%=', '**=']

export class JsParser extends ParserBase {
  constructor(lang: 'javascript' | 'typescript', lm: LineMap, toks: Token[]) {
    super(lang, lm, toks)
  }
  get ts() {
    return this.lang === 'typescript'
  }

  parseProgram(): Program {
    const body: Stmt[] = []
    const funcs = new Map<string, FuncDecl>()
    while (!this.at('eof')) {
      for (const s of this.parseStatement()) {
        if (s.k === 'func') {
          if (funcs.has(s.name)) this.errors.push({ code: 'func.duplicate', span: s.headSpan, params: { name: s.name }, severity: 'error' })
          funcs.set(s.name, s)
        } else body.push(s)
      }
    }
    return { lang: this.lang, body, funcs, entry: 'top', lineCount: this.lm.lineCount() }
  }

  // ---------- Types TypeScript ----------
  /** `: type` facultatif (TypeScript seulement). */
  typeAnnot(): TypeRef | null {
    if (!this.is(':')) return null
    if (!this.ts) this.fail('js.typeInJs')
    this.advance()
    return this.parseTsType()
  }

  parseTsType(): TypeRef {
    const one = (): TypeRef => {
      if (this.is('(')) {
        this.advance()
        const t = this.parseTsType()
        this.expect(')', 'syntax.missingParen')
        return t
      }
      const name = this.ident().v
      const tr: TypeRef = { name }
      if (this.is('<')) {
        this.advance()
        tr.args = [this.parseTsType()]
        while (this.accept(',')) tr.args.push(this.parseTsType())
        this.expect('>')
      }
      while (this.is('[') && this.is(']', this.peek())) {
        this.advance()
        this.advance()
        if (tr.array) return { name: typeStrTs(tr), array: true }
        tr.array = true
      }
      return tr
    }
    let t = one()
    // union : string | null
    while (this.is('|')) {
      this.advance()
      const u = one()
      t = { name: `${typeStrTs(t)} | ${typeStrTs(u)}` }
    }
    return t
  }

  // ---------- Instructions ----------
  /** Insertion automatique du point-virgule : accepté en fin de ligne, avant `}` ou à la fin du fichier. */
  semi() {
    if (this.accept(';')) return
    if (this.is('}') || this.at('eof') || this.cur.line > this.prev().line) return
    const p = this.prev()
    this.errors.push({ code: 'syntax.missingSemicolon', span: this.lm.span(p.end, p.end + 1), params: { found: this.cur.v }, severity: 'error' })
  }

  parseBraces(): { body: Stmt[]; endLine: number } {
    const open = this.expect('{')
    const body: Stmt[] = []
    while (!this.is('}')) {
      if (this.at('eof')) this.fail('syntax.missingBrace', open)
      body.push(...this.parseStatement())
    }
    const close = this.advance()
    return { body, endLine: close.line }
  }

  parseBody(): { body: Stmt[]; endLine: number } {
    if (this.is('{')) return this.parseBraces()
    const body = this.parseStatement()
    const last = body[body.length - 1]
    return { body, endLine: last ? last.span.endLine : this.prev().line }
  }

  parseParenCond(): Expr {
    if (!this.is('(')) this.fail('clike.condParens')
    this.advance()
    const c = this.parseExpr()
    if (this.is('=')) this.fail('clike.assignInCond')
    this.expect(')', 'syntax.missingParen')
    return c
  }

  parseDecl(needSemi = true): Stmt[] {
    const start = this.advance() // let / const / var
    const final = start.v === 'const'
    const out: Stmt[] = []
    do {
      const n = this.ident()
      const type = this.typeAnnot()
      let init: Expr | null = null
      if (this.accept('=')) init = this.parseExpr()
      else if (final && needSemi) this.fail('js.constNeedsInit', n, { name: n.v })
      const span = this.lm.span(start.start, init ? init.span.end : this.prev().end)
      out.push({ k: 'decl', id: this.id(), type, name: n.v, init, final, nameSpan: this.tspan(n), span })
    } while (this.accept(','))
    if (needSemi) this.semi()
    return out
  }

  parseFunction(): FuncDecl {
    const start = this.advance() // function
    const name = this.ident().v
    this.expect('(')
    const params: Param[] = []
    while (!this.is(')')) {
      const n = this.ident()
      this.accept('?')
      params.push({ name: n.v, type: this.typeAnnot(), span: this.tspan(n) })
      if (!this.accept(',')) break
    }
    this.expect(')', 'syntax.missingParen')
    const ret = this.typeAnnot()
    const headSpan = this.spanFrom(start)
    const { body, endLine } = this.parseBraces()
    return { k: 'func', id: this.id(), name, params, ret, body, headSpan, endLine, span: { ...headSpan, endLine } }
  }

  parseSimple(): Stmt {
    const t = this.cur
    if (this.is('++') || this.is('--')) {
      const op = this.advance().v as '++' | '--'
      const target = this.parsePostfix()
      return { k: 'incdec', id: this.id(), target, op, span: this.spanFrom(t) }
    }
    const e = this.parseExpr()
    if (this.at('op') && ASSIGN_OPS.includes(this.cur.v)) {
      const op = this.advance().v
      if (e.k !== 'name' && e.k !== 'index') this.fail('syntax.badTarget', t)
      const value = this.parseExpr()
      return { k: 'assign', id: this.id(), target: e, op, value, span: joinSpan(e.span, value.span) }
    }
    // `i++` (sur la même ligne : un `++` en début de ligne appartient à l'instruction suivante)
    if ((this.is('++') || this.is('--')) && this.cur.line === this.prev().line) {
      const op = this.advance().v as '++' | '--'
      return { k: 'incdec', id: this.id(), target: e, op, span: this.spanFrom(t) }
    }
    return { k: 'expr', id: this.id(), e, span: e.span }
  }

  parseStatement(): Stmt[] {
    const t = this.cur
    if (t.t === 'eof') this.fail('syntax.missingBrace')
    if (this.is('{')) {
      const { body, endLine } = this.parseBraces()
      return [{ k: 'block', id: this.id(), body, endLine, span: { ...this.tspan(t), endLine } }]
    }
    if (this.is(';')) {
      this.advance()
      return []
    }
    if (t.t === 'id') {
      switch (t.v) {
        case 'let':
        case 'const':
        case 'var':
          return this.parseDecl()
        case 'function':
          return [this.parseFunction()]
        case 'if':
          return [this.parseIf()]
        case 'while': {
          this.advance()
          const cond = this.parseParenCond()
          const headSpan = this.spanFrom(t)
          if (this.is(';')) this.errors.push({ code: 'clike.semicolonAfterHeader', span: this.tspan(this.cur), params: {}, severity: 'warning' })
          const { body, endLine } = this.parseBody()
          return [{ k: 'while', id: this.id(), cond, body, headSpan, endLine, span: { ...headSpan, endLine } }]
        }
        case 'do': {
          this.advance()
          const headSpan = this.tspan(t)
          const { body } = this.parseBody()
          const w = this.expect('while')
          const cond = this.parseParenCond()
          const condSpan = this.spanFrom(w)
          this.semi()
          return [{ k: 'dowhile', id: this.id(), cond, body, headSpan, condSpan, endLine: condSpan.line, span: { ...headSpan, endLine: condSpan.line } }]
        }
        case 'for':
          return [this.parseFor()]
        case 'return': {
          this.advance()
          // `return` seul en fin de ligne renvoie undefined (insertion du point-virgule)
          const bare = this.is(';') || this.is('}') || this.at('eof') || this.cur.line > t.line
          const e = bare ? null : this.parseExpr()
          const span = this.spanFrom(t)
          this.semi()
          return [{ k: 'return', id: this.id(), e, span }]
        }
        case 'break':
        case 'continue': {
          this.advance()
          this.semi()
          return [{ k: t.v as 'break', id: this.id(), span: this.tspan(t) }]
        }
        case 'else':
          this.fail('clike.elseWithoutIf')
      }
    }
    const s = this.parseSimple()
    this.semi()
    return [s]
  }

  parseIf(): Stmt {
    const t = this.advance()
    const cond = this.parseParenCond()
    const headSpan = this.spanFrom(t)
    if (this.is(';')) this.errors.push({ code: 'clike.semicolonAfterHeader', span: this.tspan(this.cur), params: {}, severity: 'warning' })
    const { body, endLine } = this.parseBody()
    let els: Stmt[] | null = null
    let elseLine: number | undefined
    let end = endLine
    if (this.is('else')) {
      const et = this.advance()
      elseLine = et.line
      if (this.is('if')) {
        const nested = this.parseIf() as Extract<Stmt, { k: 'if' }>
        nested.isElif = true
        els = [nested]
        end = nested.endLine
      } else {
        const b = this.parseBody()
        els = b.body
        end = b.endLine
      }
    }
    return { k: 'if', id: this.id(), cond, then: body, else: els, headSpan, elseLine, endLine: end, span: { ...headSpan, endLine: end } }
  }

  parseFor(): Stmt {
    const t = this.advance()
    if (!this.is('(')) this.fail('clike.condParens')
    this.advance()
    // for (const x of liste)
    if ((this.is('let') || this.is('const') || this.is('var')) && this.peek().t === 'id' && (this.is('of', this.peek(2)) || this.is('in', this.peek(2)))) {
      this.advance()
      const v = this.advance()
      if (this.is('in')) this.fail('js.forIn', this.cur)
      this.advance()
      const iter = this.parseExpr()
      this.expect(')', 'syntax.missingParen')
      const headSpan = this.spanFrom(t)
      const { body, endLine } = this.parseBody()
      return { k: 'foreach', id: this.id(), varName: v.v, varType: null, varSpan: this.tspan(v), iter, body, headSpan, endLine, span: { ...headSpan, endLine } }
    }
    let init: Stmt | null = null
    if (!this.is(';')) init = this.is('let') || this.is('const') || this.is('var') ? this.parseDecl(false)[0] : this.parseSimple()
    this.expect(';')
    const cond = this.is(';') ? null : this.parseExpr()
    this.expect(';')
    const update = this.is(')') ? null : this.parseSimple()
    this.expect(')', 'syntax.missingParen')
    const headSpan = this.spanFrom(t)
    if (this.is(';')) this.errors.push({ code: 'clike.semicolonAfterHeader', span: this.tspan(this.cur), params: {}, severity: 'warning' })
    const { body, endLine } = this.parseBody()
    return { k: 'for', id: this.id(), init, cond, update, body, headSpan, endLine, span: { ...headSpan, endLine } }
  }

  // ---------- Expressions propres à JavaScript ----------
  parseEquality(): Expr {
    let l = this.parseRelational()
    while (this.is('===') || this.is('!==') || this.is('==') || this.is('!=')) {
      const op = this.advance().v
      const r = this.parseRelational()
      l = { k: 'bin', op, l, r, span: joinSpan(l.span, r.span) }
    }
    return l
  }

  parsePower(): Expr {
    const base = this.parsePostfix()
    if (this.is('**')) {
      this.advance()
      const exp = this.parseUnary()
      return { k: 'bin', op: '**', l: base, r: exp, span: joinSpan(base.span, exp.span) }
    }
    return base
  }

  subExpr(src: string, start: number): Expr {
    const toks = tokenize(this.lang, this.lm, src, start, false)
    const sub = new JsParser(this.lang as 'javascript', this.lm, toks)
    const e = sub.parseExpr()
    if (sub.cur.t !== 'eof') sub.fail('syntax.unexpected')
    return e
  }
}

export function typeStrTs(t: TypeRef): string {
  let s = t.name
  if (t.args?.length) s += '<' + t.args.map(typeStrTs).join(', ') + '>'
  if (t.array) s += '[]'
  return s
}

export function parseJs(lang: 'javascript' | 'typescript', src: string): { program: Program; errors: CompileError[] } {
  const lm = new LineMap(src)
  const toks = tokenize(lang, lm)
  const p = new JsParser(lang, lm, toks)
  const program = p.parseProgram()
  return { program, errors: p.errors }
}

// ---------- Vérification TypeScript (sous-ensemble de tsc) ----------
// Types simplifiés : 'number' | 'string' | 'boolean' | 'null' | 'undefined' | 'void' | '<T>[]' | '?' (inconnu / any)

const GLOBALS = new Set(['console', 'Math', 'parseInt', 'parseFloat', 'String', 'Number', 'Boolean', 'undefined', 'NaN', 'Infinity'])

interface TsVar {
  type: string
  final: boolean
}

/** Normalise une annotation : Array<number> → number[], any → ?. */
function norm(t: TypeRef | null): string {
  if (!t) return '?'
  if (t.name === 'Array' && t.args?.length === 1) return norm(t.args[0]) + '[]' + (t.array ? '[]' : '')
  if (t.name === 'any' || t.name === 'unknown' || t.name.includes('|')) return '?'
  return typeStrTs(t)
}

export function checkTs(p: Program): CompileError[] {
  const errors: CompileError[] = []
  const err = (code: string, span: Span, params: Record<string, string | number> = {}) => errors.push({ code, span, params, severity: 'error' })
  const scopes: Map<string, TsVar>[] = [new Map()]
  let fn: FuncDecl | null = null

  const find = (name: string): TsVar | undefined => {
    for (let i = scopes.length - 1; i >= 0; i--) {
      const v = scopes[i].get(name)
      if (v) return v
    }
    return undefined
  }
  const known = (name: string) => !!find(name) || p.funcs.has(name) || GLOBALS.has(name)
  const compatible = (target: string, value: string) =>
    target === '?' || value === '?' || target === value || (target.endsWith('[]') && value === '?[]')

  function infer(e: Expr): string {
    switch (e.k) {
      case 'num':
        return 'number'
      case 'str':
      case 'istr':
        if (e.k === 'istr') e.parts.forEach((x) => typeof x !== 'string' && infer(x))
        return 'string'
      case 'bool':
        return 'boolean'
      case 'null':
        return 'null'
      case 'name': {
        if (e.name === 'undefined') return 'undefined'
        if (e.name === 'NaN' || e.name === 'Infinity') return 'number'
        if (!known(e.name)) err('var.undeclared', e.span, { name: e.name, hint: `let ${e.name}` })
        return find(e.name)?.type ?? '?'
      }
      case 'list': {
        const ts = e.items.map(infer)
        if (!ts.length) return '?[]'
        return ts.every((x) => x === ts[0]) && ts[0] !== '?' ? ts[0] + '[]' : '?[]'
      }
      case 'bin': {
        const l = infer(e.l)
        const r = infer(e.r)
        if (['===', '!==', '==', '!=', '<', '>', '<=', '>='].includes(e.op)) return 'boolean'
        if (e.op === 'and' || e.op === 'or') return l === r ? l : '?'
        if (e.op === '+') {
          if (l === 'string' || r === 'string') return 'string'
          if (l === 'number' && r === 'number') return 'number'
          return '?'
        }
        if (l !== '?' && r !== '?' && (l !== 'number' || r !== 'number'))
          err('op.badOperands', e.span, { op: e.op, left: l, right: r })
        return 'number'
      }
      case 'un':
        infer(e.e)
        return e.op === 'not' ? 'boolean' : 'number'
      case 'tern': {
        infer(e.c)
        const a = infer(e.a)
        const b = infer(e.b)
        return a === b ? a : '?'
      }
      case 'index': {
        const o = infer(e.obj)
        infer(e.idx)
        return o.endsWith('[]') ? o.slice(0, -2) : o === 'string' ? 'string' : '?'
      }
      case 'member': {
        const o = infer(e.obj)
        if (e.name === 'length' && (o === 'string' || o.endsWith('[]'))) return 'number'
        return '?'
      }
      case 'call': {
        const args = e.args.map(infer)
        const f = p.funcs.get(e.name)
        if (!f) {
          if (!GLOBALS.has(e.name) && !find(e.name)) err('call.unknown', e.nameSpan, { name: e.name })
          if (e.name === 'parseInt' || e.name === 'parseFloat' || e.name === 'Number') return 'number'
          if (e.name === 'String') return 'string'
          return '?'
        }
        if (args.length !== f.params.length) err('call.argCount', e.span, { name: f.name, expected: f.params.length, given: args.length })
        f.params.forEach((prm, i) => {
          const want = norm(prm.type)
          if (i < args.length && !compatible(want, args[i])) err('call.argType', e.args[i].span, { name: f.name, param: prm.name, expected: want, found: args[i] })
        })
        return f.ret ? norm(f.ret) : '?'
      }
      case 'mcall': {
        const o = infer(e.obj)
        e.args.forEach(infer)
        if (o === 'string' && ['toUpperCase', 'toLowerCase', 'trim', 'substring', 'slice', 'charAt'].includes(e.name)) return 'string'
        if (o.endsWith('[]') && (e.name === 'push' || e.name === 'indexOf')) return 'number'
        if (e.name === 'includes') return 'boolean'
        if (e.name === 'toFixed' || e.name === 'toString' || e.name === 'join') return 'string'
        if (e.obj.k === 'name' && e.obj.name === 'Math') return 'number'
        return '?'
      }
      default:
        return '?'
    }
  }

  function assignCheck(name: string, value: string, span: Span) {
    const v = find(name)
    if (!v) return
    if (!compatible(v.type, value)) err('type.mismatch', span, { name, expected: v.type, found: value })
  }

  function stmts(list: Stmt[], newScope = true) {
    if (newScope) scopes.push(new Map())
    for (const s of list) stmt(s)
    if (newScope) scopes.pop()
  }

  function stmt(s: Stmt) {
    switch (s.k) {
      case 'decl': {
        const found = s.init ? infer(s.init) : 'undefined'
        const declared = s.type ? norm(s.type) : null
        if (declared && s.init && !compatible(declared, found)) err('type.mismatch', s.span, { name: s.name, expected: declared, found })
        const top = scopes[scopes.length - 1]
        if (top.has(s.name)) err('var.redeclared', s.nameSpan, { name: s.name })
        // sans annotation, TypeScript déduit le type de la valeur initiale
        top.set(s.name, { type: declared ?? (s.init ? (found === '?[]' ? '?' : found) : '?'), final: s.final })
        return
      }
      case 'assign': {
        if (s.target.k === 'name') {
          const name = s.target.name
          if (!known(name)) err('var.undeclared', s.target.span, { name, hint: `let ${name}` })
          const v = find(name)
          if (v?.final) err('var.final', s.target.span, { name })
          const value = infer(s.value)
          if (s.op === '=') assignCheck(name, value, s.span)
          else if (s.op === '+=' && v?.type === 'string') return
          else if (v && v.type !== '?' && v.type !== 'number') err('op.badOperands', s.span, { op: s.op.slice(0, -1), left: v.type, right: value })
        } else {
          infer(s.target)
          infer(s.value)
        }
        return
      }
      case 'incdec':
        if (s.target.k === 'name' && find(s.target.name)?.final) err('var.final', s.target.span, { name: s.target.name })
        infer(s.target)
        return
      case 'expr':
        infer(s.e)
        return
      case 'if':
        infer(s.cond)
        stmts(s.then)
        if (s.else) stmts(s.else)
        return
      case 'while':
      case 'dowhile':
        infer(s.cond)
        stmts(s.body)
        return
      case 'for':
        scopes.push(new Map())
        if (s.init) stmt(s.init)
        if (s.cond) infer(s.cond)
        if (s.update) stmt(s.update)
        stmts(s.body)
        scopes.pop()
        return
      case 'foreach': {
        const it = infer(s.iter)
        scopes.push(new Map([[s.varName, { type: it.endsWith('[]') ? it.slice(0, -2) : it === 'string' ? 'string' : '?', final: false }]]))
        stmts(s.body)
        scopes.pop()
        return
      }
      case 'return':
        if (s.e) {
          const t = infer(s.e)
          const want = fn?.ret ? norm(fn.ret) : '?'
          if (fn && want === 'void') err('return.inVoid', s.span, { name: fn.name })
          else if (fn && !compatible(want, t)) err('return.type', s.e.span, { name: fn.name, expected: want, found: t })
        }
        return
      case 'block':
        stmts(s.body)
        return
      default:
        return
    }
  }

  // le programme principal d'abord, puis les corps de fonctions (qui voient toutes les variables globales)
  stmts(p.body, false)
  for (const f of p.funcs.values()) {
    fn = f
    scopes.push(new Map(f.params.map((prm) => [prm.name, { type: norm(prm.type), final: false }])))
    stmts(f.body, false)
    scopes.pop()
  }
  return errors
}
