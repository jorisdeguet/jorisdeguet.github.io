import { CompileFailure, joinSpan, type CompileError, type Expr, type Lang, type Span, type TypeRef } from './ast'
import { tokenize, type LineMap, type Token, type TokType } from './tokenizer'

export const TYPE_NAMES: Record<Lang, Set<string>> = {
  python: new Set(),
  csharp: new Set(['int', 'double', 'float', 'decimal', 'long', 'string', 'bool', 'char', 'var', 'List', 'object']),
  dart: new Set(['int', 'double', 'num', 'String', 'bool', 'var', 'List', 'dynamic', 'Object']),
  javascript: new Set(),
  typescript: new Set(),
}

export function tokDesc(t: Token): string {
  switch (t.t) {
    case 'nl':
      return '<newline>'
    case 'indent':
      return '<indent>'
    case 'dedent':
      return '<dedent>'
    case 'eof':
      return '<eof>'
    case 'str':
    case 'istr':
      return t.v.length > 12 ? t.v.slice(0, 12) + '…' : JSON.stringify(t.v)
    default:
      return t.v
  }
}

/** Curseur sur les jetons + analyse des expressions, commun aux trois langages. */
export class ParserBase {
  pos = 0
  errors: CompileError[] = []
  nextId = 1

  constructor(public lang: Lang, public lm: LineMap, public toks: Token[]) {}

  get cur(): Token {
    return this.toks[this.pos]
  }
  /** Type du jeton courant (méthode : évite un rétrécissement de type abusif par TS). */
  at(t: TokType): boolean {
    return this.cur.t === t
  }
  peek(n = 1): Token {
    return this.toks[Math.min(this.pos + n, this.toks.length - 1)]
  }
  prev(): Token {
    return this.toks[Math.max(0, this.pos - 1)]
  }
  is(v: string, t: Token = this.cur): boolean {
    return (t.t === 'op' || t.t === 'id') && t.v === v
  }
  advance(): Token {
    const t = this.cur
    if (this.pos < this.toks.length - 1) this.pos++
    return t
  }
  accept(v: string): Token | null {
    if (this.is(v)) return this.advance()
    return null
  }
  fail(code: string, t: Token = this.cur, params: Record<string, string | number> = {}): never {
    throw new CompileFailure({ code, span: this.tspan(t), params: { found: tokDesc(t), ...params }, severity: 'error' })
  }
  expect(v: string, code = 'syntax.expected'): Token {
    if (this.is(v)) return this.advance()
    this.fail(code, this.cur, { expected: v })
  }
  ident(): Token {
    if (!this.at('id')) this.fail('syntax.expectedName')
    return this.advance()
  }
  tspan(t: Token): Span {
    return this.lm.span(t.start, Math.max(t.end, t.start + 1))
  }
  spanFrom(from: { start: number }): Span {
    const s = from.start
    const endTok = this.prev()
    return this.lm.span(s, Math.max(endTok.end, s + 1))
  }
  id() {
    return this.nextId++
  }

  // ---------- Types (C# / Dart) ----------
  isTypeStart(t: Token = this.cur): boolean {
    return t.t === 'id' && TYPE_NAMES[this.lang].has(t.v)
  }
  parseType(): TypeRef {
    const name = this.ident().v
    const tr: TypeRef = { name }
    if (this.is('<') && (name === 'List' || name === 'Map')) {
      this.advance()
      tr.args = [this.parseType()]
      while (this.accept(',')) tr.args.push(this.parseType())
      this.expect('>')
    }
    if (this.is('[') && this.is(']', this.peek())) {
      this.advance()
      this.advance()
      tr.array = true
    }
    if (this.is('?')) {
      this.advance()
      tr.nullable = true
    }
    return tr
  }

  // ---------- Expressions ----------
  parseExpr(): Expr {
    return this.parseTernary()
  }

  parseTernary(): Expr {
    const c = this.parseOr()
    if (this.lang === 'python') {
      if (this.is('if')) {
        // a if c else b
        this.advance()
        const cond = this.parseOr()
        this.expect('else')
        const b = this.parseTernary()
        return { k: 'tern', c: cond, a: c, b, span: joinSpan(c.span, b.span) }
      }
      return c
    }
    if (this.is('?')) {
      this.advance()
      const a = this.parseTernary()
      this.expect(':')
      const b = this.parseTernary()
      return { k: 'tern', c, a, b, span: joinSpan(c.span, b.span) }
    }
    return c
  }

  private bin(op: string, l: Expr, r: Expr): Expr {
    return { k: 'bin', op, l, r, span: joinSpan(l.span, r.span) }
  }

  parseOr(): Expr {
    let l = this.parseAnd()
    for (;;) {
      if (this.lang === 'python' && this.is('||')) this.fail('py.useOr')
      if (this.is(this.lang === 'python' ? 'or' : '||')) {
        this.advance()
        l = this.bin('or', l, this.parseAnd())
      } else return l
    }
  }

  parseAnd(): Expr {
    let l = this.parseNot()
    for (;;) {
      if (this.lang === 'python' && this.is('&&')) this.fail('py.useAnd')
      if (this.is(this.lang === 'python' ? 'and' : '&&')) {
        this.advance()
        l = this.bin('and', l, this.parseNot())
      } else return l
    }
  }

  parseNot(): Expr {
    if (this.lang === 'python') {
      if (this.is('!')) this.fail('py.useNot')
      if (this.is('not')) {
        const t = this.advance()
        const e = this.parseNot()
        return { k: 'un', op: 'not', e, span: joinSpan(this.tspan(t), e.span) }
      }
      return this.parseCompare()
    }
    return this.parseEquality()
  }

  // Python : comparaisons chaînées a < b < c  →  (a < b) and (b < c)
  parseCompare(): Expr {
    const first = this.parseAdd()
    const ops = ['==', '!=', '<', '>', '<=', '>=']
    let left = first
    let result: Expr | null = null
    while ((this.at('op') && ops.includes(this.cur.v)) || this.is('in') || (this.is('not') && this.is('in', this.peek()))) {
      let op = this.advance().v
      if (op === 'not') {
        this.advance()
        op = 'not in'
      }
      const right = this.parseAdd()
      const cmp = this.bin(op, left, right)
      result = result ? this.bin('and', result, cmp) : cmp
      left = right
    }
    return result ?? first
  }

  parseEquality(): Expr {
    let l = this.parseRelational()
    while (this.is('==') || this.is('!=')) {
      const op = this.advance().v
      l = this.bin(op, l, this.parseRelational())
    }
    return l
  }

  parseRelational(): Expr {
    let l = this.parseAdd()
    while (this.is('<') || this.is('>') || this.is('<=') || this.is('>=')) {
      const op = this.advance().v
      l = this.bin(op, l, this.parseAdd())
    }
    return l
  }

  parseAdd(): Expr {
    let l = this.parseMul()
    while (this.is('+') || this.is('-')) {
      const op = this.advance().v
      l = this.bin(op, l, this.parseMul())
    }
    return l
  }

  parseMul(): Expr {
    let l = this.parseUnary()
    while (this.is('*') || this.is('/') || this.is('%') || this.is('//') || this.is('~/')) {
      const op = this.advance().v
      l = this.bin(op, l, this.parseUnary())
    }
    return l
  }

  parseUnary(): Expr {
    if (this.is('-') || this.is('+') || (this.lang !== 'python' && this.is('!'))) {
      const t = this.advance()
      const e = this.parseUnary()
      const op = t.v === '!' ? 'not' : t.v
      if (op === '-' && e.k === 'num') return { ...e, v: -e.v, span: joinSpan(this.tspan(t), e.span) }
      return { k: 'un', op, e, span: joinSpan(this.tspan(t), e.span) }
    }
    if (this.lang === 'python' && (this.is('++') || this.is('--'))) this.fail('py.noIncrement')
    // Conversion C# : (int) x
    if (this.lang === 'csharp' && this.is('(') && this.isTypeStart(this.peek()) && this.is(')', this.peek(2))) {
      const t = this.advance()
      const type = this.parseType()
      this.expect(')')
      const e = this.parseUnary()
      return { k: 'cast', type, e, span: joinSpan(this.tspan(t), e.span) }
    }
    return this.parsePower()
  }

  parsePower(): Expr {
    const base = this.parsePostfix()
    if (this.lang === 'python' && this.is('**')) {
      this.advance()
      const exp = this.parseUnary()
      return this.bin('**', base, exp)
    }
    return base
  }

  parseArgs(): Expr[] {
    const args: Expr[] = []
    this.expect('(')
    if (!this.is(')')) {
      do {
        if (this.is(')')) break
        args.push(this.parseExpr())
      } while (this.accept(','))
    }
    this.expect(')', 'syntax.missingParen')
    return args
  }

  parsePostfix(): Expr {
    let e = this.parsePrimary()
    for (;;) {
      if (this.is('(')) {
        if (e.k !== 'name') this.fail('syntax.unexpected')
        const nameSpan = e.span
        const args = this.parseArgs()
        e = { k: 'call', name: e.name, args, span: this.spanFrom(e.span), nameSpan }
      } else if (this.is('[')) {
        this.advance()
        const idx = this.parseExpr()
        this.expect(']')
        e = { k: 'index', obj: e, idx, span: this.spanFrom(e.span) }
      } else if (this.is('.')) {
        this.advance()
        const name = this.ident().v
        if (this.is('(')) {
          const args = this.parseArgs()
          e = { k: 'mcall', obj: e, name, args, span: this.spanFrom(e.span) }
        } else e = { k: 'member', obj: e, name, span: this.spanFrom(e.span) }
      } else return e
    }
  }

  parseListItems(close: string): Expr[] {
    const items: Expr[] = []
    while (!this.is(close)) {
      items.push(this.parseExpr())
      if (!this.accept(',')) break
    }
    this.expect(close)
    return items
  }

  parsePrimary(): Expr {
    const t = this.cur
    const sp = this.tspan(t)
    switch (t.t) {
      case 'num':
        this.advance()
        return { k: 'num', v: t.num!, isInt: !!t.isInt, span: sp }
      case 'str':
        this.advance()
        return { k: 'str', v: t.v, char: t.char, span: sp }
      case 'istr': {
        this.advance()
        const parts = t.parts!.map((p) => (typeof p === 'string' ? p : this.subExpr(p.src, p.start)))
        return { k: 'istr', parts, span: sp }
      }
      case 'id': {
        const v = t.v
        const py = this.lang === 'python'
        if ((py && v === 'True') || (!py && v === 'true')) {
          this.advance()
          return { k: 'bool', v: true, span: sp }
        }
        if ((py && v === 'False') || (!py && v === 'false')) {
          this.advance()
          return { k: 'bool', v: false, span: sp }
        }
        if ((py && v === 'None') || (!py && v === 'null')) {
          this.advance()
          return { k: 'null', span: sp }
        }
        if (py && (v === 'true' || v === 'false')) this.fail('py.boolCase', t, { good: v === 'true' ? 'True' : 'False' })
        if (!py && (v === 'True' || v === 'False')) this.fail('clike.boolCase', t, { good: v.toLowerCase() })
        if (this.lang === 'csharp' && v === 'new') return this.parseNew()
        this.advance()
        return { k: 'name', name: v, span: sp }
      }
      case 'op':
        if (t.v === '(') {
          this.advance()
          const e = this.parseExpr()
          this.expect(')', 'syntax.missingParen')
          return { ...e, span: this.spanFrom(sp) } as Expr
        }
        if (t.v === '[' && this.lang !== 'csharp') {
          this.advance()
          const items = this.parseListItems(']')
          return { k: 'list', items, ctor: 'list', span: this.spanFrom(sp) }
        }
        if (t.v === '<' && this.lang === 'dart') {
          // <int>[1, 2]
          this.advance()
          const elemType = this.parseType()
          this.expect('>')
          this.expect('[')
          const items = this.parseListItems(']')
          return { k: 'list', items, elemType, ctor: 'list', span: this.spanFrom(sp) }
        }
        if (t.v === '{' && this.lang === 'csharp') {
          // initialiseur de tableau : int[] t = {1, 2, 3};
          this.advance()
          const items = this.parseListItems('}')
          return { k: 'list', items, ctor: 'array', span: this.spanFrom(sp) }
        }
        if (t.v === '[' && this.lang === 'csharp') {
          // expression de collection C# 12 : [1, 2, 3]
          this.advance()
          const items = this.parseListItems(']')
          return { k: 'list', items, span: this.spanFrom(sp) }
        }
        break
    }
    this.fail(t.t === 'eof' || t.t === 'nl' ? 'syntax.incompleteExpr' : 'syntax.unexpected', t)
  }

  parseNew(): Expr {
    const start = this.advance()
    const sp = this.tspan(start)
    const name = this.ident().v
    if (name === 'List') {
      this.expect('<')
      const elem = this.parseType()
      this.expect('>')
      let items: Expr[] = []
      if (this.is('(')) {
        this.advance()
        this.expect(')')
      }
      if (this.is('{')) {
        this.advance()
        items = this.parseListItems('}')
      }
      return { k: 'list', items, elemType: elem, ctor: 'list', span: this.spanFrom(sp) }
    }
    if (!TYPE_NAMES.csharp.has(name)) this.fail('csharp.unknownType', this.prev(), { name })
    this.expect('[')
    const elemType: TypeRef = { name }
    if (this.is(']')) {
      this.advance()
      this.expect('{')
      const items = this.parseListItems('}')
      return { k: 'list', items, elemType, ctor: 'array', span: this.spanFrom(sp) }
    }
    const size = this.parseExpr()
    this.expect(']')
    return { k: 'newArr', elemType, size, span: this.spanFrom(sp) }
  }

  /** Analyse une expression à l'intérieur d'une chaîne interpolée. */
  subExpr(src: string, start: number): Expr {
    const toks = tokenize(this.lang, this.lm, src, start, false)
    const sub = new ParserBase(this.lang, this.lm, toks)
    const e = sub.parseExpr()
    if (sub.cur.t !== 'eof') sub.fail('syntax.unexpected')
    return e
  }
}
