// Parser commun C# / Dart (syntaxe à accolades et points-virgules).
import { CompileFailure, joinSpan, type Expr, type FuncDecl, type Lang, type Param, type Program, type Stmt, type TypeRef } from '../ast'
import { ParserBase } from '../parser-base'
import { LineMap, tokenize, type Token } from '../tokenizer'

const MODIFIERS = new Set(['public', 'private', 'protected', 'internal', 'static', 'override', 'async'])
const ASSIGN_OPS = ['=', '+=', '-=', '*=', '/=', '%=', '~/=']

export class CLikeParser extends ParserBase {
  constructor(lang: Lang, lm: LineMap, toks: Token[]) {
    super(lang, lm, toks)
  }

  // ---------- Programme ----------
  parseProgram(): Program {
    const body: Stmt[] = []
    const funcs = new Map<string, FuncDecl>()
    const addFunc = (f: FuncDecl) => {
      if (funcs.has(f.name)) this.errors.push({ code: 'func.duplicate', span: f.headSpan, params: { name: f.name }, severity: 'error' })
      funcs.set(f.name, f)
    }
    let hasTopStatements = false

    const parseMembers = (close: string | null, inClass: boolean) => {
      while (!(close ? this.is(close) : this.at('eof'))) {
        if (this.at('eof')) this.fail('syntax.missingBrace')
        if (this.is('using') || this.is('import')) {
          while (!this.is(';') && !this.at('eof')) this.advance()
          this.semi()
          continue
        }
        if (this.lang === 'csharp' && this.is('namespace')) {
          this.advance()
          this.ident()
          while (this.accept('.')) this.ident()
          if (this.accept(';')) continue
          this.expect('{')
          parseMembers('}', false)
          this.expect('}')
          continue
        }
        const save = this.pos
        while (this.at('id') && MODIFIERS.has(this.cur.v)) this.advance()
        if (this.is('class')) {
          this.advance()
          this.ident()
          this.expect('{')
          parseMembers('}', true)
          this.expect('}', 'syntax.missingBrace')
          continue
        }
        const f = this.tryFuncDecl()
        if (f) {
          addFunc(f)
          continue
        }
        this.pos = save
        while (this.at('id') && MODIFIERS.has(this.cur.v)) this.advance()
        const stmts = this.parseStatement()
        for (const s of stmts) {
          if (s.k === 'func') addFunc(s)
          else {
            if (!inClass) hasTopStatements = true
            body.push(s)
          }
        }
      }
    }
    parseMembers(null, false)

    const lastTok = this.toks[this.toks.length - 1]
    const eofSpan = this.lm.span(lastTok.start, lastTok.start)
    let entry: Program['entry'] = 'top'
    let mainName: string | undefined
    if (this.lang === 'dart') {
      if (!funcs.has('main')) throw new CompileFailure({ code: 'dart.noMain', span: eofSpan, params: {}, severity: 'error' })
      entry = 'main'
      mainName = 'main'
      for (const s of body)
        if (s.k !== 'decl') this.errors.push({ code: 'dart.topLevelStatement', span: s.span, params: {}, severity: 'error' })
    } else if (funcs.has('Main') && !hasTopStatements) {
      entry = 'main'
      mainName = 'Main'
    } else if (!hasTopStatements && !funcs.has('Main')) {
      throw new CompileFailure({ code: 'csharp.noMain', span: eofSpan, params: {}, severity: 'error' })
    }
    return { lang: this.lang, body, funcs, entry, mainName, lineCount: this.lm.lineCount() }
  }

  /** `int f(int x) { ... }`, `void main() { ... }`, `f(x) { ... }` (Dart), `int f(int x) => x * 2;` */
  tryFuncDecl(): FuncDecl | null {
    const save = this.pos
    const start = this.cur
    let ret: TypeRef | null = null
    if (this.is('void') || this.isTypeStart()) {
      ret = this.is('void') ? (this.advance(), { name: 'void' }) : this.parseType()
    }
    if (!this.at('id') || !this.is('(', this.peek())) {
      this.pos = save
      return null
    }
    if (!ret && this.lang === 'csharp') {
      this.pos = save
      return null
    }
    const name = this.ident().v
    let params: Param[]
    try {
      params = this.parseParams()
    } catch (e) {
      // `print('x');` en Dart ressemble au début d'une fonction sans type de retour
      if (ret || !(e instanceof CompileFailure)) throw e
      this.pos = save
      return null
    }
    if (!ret && !this.is('{') && !this.is('=>')) {
      this.pos = save
      return null
    }
    const headSpan = this.spanFrom(start)
    if (this.is('=>')) {
      const arrow = this.advance()
      const e = this.parseExpr()
      this.semi()
      const ret1: Stmt = { k: ret?.name === 'void' ? 'expr' : 'return', id: this.id(), e, span: joinSpan(this.tspan(arrow), e.span) } as Stmt
      return { k: 'func', id: this.id(), name, params, ret, body: [ret1], headSpan, endLine: e.span.endLine, span: { ...headSpan, endLine: e.span.endLine } }
    }
    if (!this.is('{')) {
      this.pos = save
      return null
    }
    const { body, endLine } = this.parseBraces()
    return { k: 'func', id: this.id(), name, params, ret, body, headSpan, endLine, span: { ...headSpan, endLine } }
  }

  parseParams(): Param[] {
    this.expect('(')
    const params: Param[] = []
    while (!this.is(')')) {
      let type: TypeRef | null = null
      if (this.isTypeStart() || (this.at('id') && this.peek().t === 'id')) type = this.parseType()
      const n = this.ident()
      params.push({ name: n.v, type, span: this.tspan(n) })
      if (!this.accept(',')) break
    }
    this.expect(')', 'syntax.missingParen')
    return params
  }

  // ---------- Instructions ----------
  semi() {
    if (this.accept(';')) return
    // Erreur récupérable : on la note et on continue comme si le ';' était là.
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

  /** Corps d'un if / while / for : bloc entre accolades ou instruction unique. */
  parseBody(): { body: Stmt[]; endLine: number } {
    if (this.is('{')) return this.parseBraces()
    const body = this.parseStatement()
    const last = body[body.length - 1]
    return { body, endLine: last.span.endLine }
  }

  parseParenCond(): Expr {
    if (!this.is('(')) this.fail('clike.condParens')
    this.advance()
    const c = this.parseExpr()
    if (this.is('=')) this.fail('clike.assignInCond')
    this.expect(')', 'syntax.missingParen')
    return c
  }

  isDeclStart(): boolean {
    const t = this.cur
    if (t.t !== 'id') return false
    if (t.v === 'var' || t.v === 'final' || t.v === 'const') return true
    if (this.isTypeStart()) {
      const n = this.peek()
      return n.t === 'id' || this.is('<', n) || (this.is('[', n) && this.is(']', this.peek(2))) || this.is('?', n)
    }
    // type inconnu : `string s = ...` en Dart, `Int x;`...
    const n = this.peek()
    const n2 = this.peek(2)
    return n.t === 'id' && (this.is('=', n2) || this.is(';', n2) || this.is(',', n2))
  }

  parseDecl(needSemi = true): Stmt[] {
    const start = this.cur
    let final = false
    let type: TypeRef | null = null
    if (this.is('final') || this.is('const')) {
      this.advance()
      final = true
      if (this.isTypeStart() && this.peek().t !== 'op') type = this.parseType()
      else if (this.isTypeStart() && (this.is('<', this.peek()) || this.is('[', this.peek()))) type = this.parseType()
    } else if (this.is('var')) {
      this.advance()
    } else {
      type = this.parseType()
    }
    const out: Stmt[] = []
    do {
      const n = this.ident()
      let init: Expr | null = null
      if (this.accept('=')) init = this.parseExpr()
      const span = this.lm.span(start.start, init ? init.span.end : n.end)
      out.push({ k: 'decl', id: this.id(), type, name: n.v, init, final, nameSpan: this.tspan(n), span })
    } while (this.accept(','))
    if (needSemi) this.semi()
    return out
  }

  /** Affectation, ++/-- ou appel (sans le ';'). */
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
    if (this.is('++') || this.is('--')) {
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
        case 'foreach':
          if (this.lang === 'csharp') return [this.parseForeach()]
          break
        case 'return': {
          this.advance()
          const e = this.is(';') ? null : this.parseExpr()
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
      // fonction locale (C#) ou imbriquée (Dart)
      if (this.is('void') || this.isTypeStart()) {
        const f = this.tryFuncDecl()
        if (f) return [f]
      }
      if (this.isDeclStart()) return this.parseDecl()
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
    // Dart : for (var x in liste)
    const save = this.pos
    if (this.lang === 'dart') {
      let varType: TypeRef | null = null
      if (this.is('var') || this.is('final')) this.advance()
      else if (this.isTypeStart()) varType = this.parseType()
      if (this.at('id') && this.is('in', this.peek())) {
        const v = this.advance()
        this.advance()
        const iter = this.parseExpr()
        this.expect(')', 'syntax.missingParen')
        const headSpan = this.spanFrom(t)
        const { body, endLine } = this.parseBody()
        return { k: 'foreach', id: this.id(), varName: v.v, varType, varSpan: this.tspan(v), iter, body, headSpan, endLine, span: { ...headSpan, endLine } }
      }
      this.pos = save
    }
    let init: Stmt | null = null
    if (!this.is(';')) init = this.isDeclStart() ? this.parseDecl(false)[0] : this.parseSimple()
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

  parseForeach(): Stmt {
    const t = this.advance()
    this.expect('(')
    let varType: TypeRef | null = null
    if (this.is('var')) this.advance()
    else varType = this.parseType()
    const v = this.ident()
    this.expect('in')
    const iter = this.parseExpr()
    this.expect(')', 'syntax.missingParen')
    const headSpan = this.spanFrom(t)
    const { body, endLine } = this.parseBody()
    return { k: 'foreach', id: this.id(), varName: v.v, varType, varSpan: this.tspan(v), iter, body, headSpan, endLine, span: { ...headSpan, endLine } }
  }
}

export function parseCLike(lang: 'csharp' | 'dart', src: string): { program: Program; errors: CLikeParser['errors'] } {
  const lm = new LineMap(src)
  const toks = tokenize(lang, lm)
  const p = new CLikeParser(lang, lm, toks)
  const program = p.parseProgram()
  return { program, errors: p.errors }
}
