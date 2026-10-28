import { joinSpan, type Expr, type FuncDecl, type Program, type Stmt } from '../ast'
import { ParserBase } from '../parser-base'
import { LineMap, tokenize } from '../tokenizer'

class PyParser extends ParserBase {
  parseProgram(): Program {
    const body: Stmt[] = []
    while (this.at('nl')) this.advance()
    while (!this.at('eof')) {
      body.push(...this.parseStatement())
      while (this.at('nl')) this.advance()
    }
    const funcs = new Map<string, FuncDecl>()
    for (const s of body) if (s.k === 'func') funcs.set(s.name, s)
    return { lang: 'python', body, funcs, entry: 'top', lineCount: this.lm.lineCount() }
  }

  endOfSimple() {
    if (this.at('nl')) {
      this.advance()
      return
    }
    if (this.at('eof') || this.at('dedent')) return
    if (this.is(';')) {
      this.advance()
      if (this.at('nl')) this.advance()
      return
    }
    if (this.is('=')) this.fail('syntax.unexpected')
    this.fail('py.expectedNewline')
  }

  /** Bloc indenté après ':' */
  parseBlock(headTok: { line: number }): { body: Stmt[]; endLine: number } {
    if (!this.is(':')) this.fail('py.expectedColon')
    this.advance()
    if (!this.at('nl')) {
      // bloc sur la même ligne : while x: x -= 1
      const body = this.parseSimple()
      return { body, endLine: headTok.line }
    }
    this.advance()
    if (!this.at('indent')) this.fail('py.expectedIndent', this.cur)
    this.advance()
    const body: Stmt[] = []
    while (!this.at('dedent') && !this.at('eof')) {
      body.push(...this.parseStatement())
      while (this.at('nl')) this.advance()
    }
    if (this.at('dedent')) this.advance()
    const last = body[body.length - 1]
    return { body, endLine: last ? lastLine(last) : headTok.line }
  }

  parseStatement(): Stmt[] {
    const t = this.cur
    if (t.t === 'indent') this.fail('py.unexpectedIndent')
    if (t.t === 'id') {
      switch (t.v) {
        case 'if':
          return [this.parseIf()]
        case 'while': {
          this.advance()
          const cond = this.parseCondition()
          const headSpan = this.spanFrom(t)
          const { body, endLine } = this.parseBlock(t)
          return [{ k: 'while', id: this.id(), cond, body, headSpan, endLine, span: { ...headSpan, endLine } }]
        }
        case 'for': {
          this.advance()
          const v = this.ident()
          this.expect('in', 'py.forIn')
          const iter = this.parseExpr()
          const headSpan = this.spanFrom(t)
          const { body, endLine } = this.parseBlock(t)
          return [{ k: 'foreach', id: this.id(), varName: v.v, varType: null, varSpan: this.tspan(v), iter, body, headSpan, endLine, span: { ...headSpan, endLine } }]
        }
        case 'def':
          return [this.parseDef()]
        case 'else':
        case 'elif':
          this.fail('py.elseWithoutIf')
      }
    }
    return this.parseSimple()
  }

  parseCondition(): Expr {
    const cond = this.parseExpr()
    if (this.is('=')) this.fail('py.assignInCond')
    return cond
  }

  parseIf(): Stmt {
    const t = this.advance() // if / elif
    const cond = this.parseCondition()
    const headSpan = this.spanFrom(t)
    const { body, endLine } = this.parseBlock(t)
    while (this.at('nl')) this.advance()
    let els: Stmt[] | null = null
    let elseLine: number | undefined
    let end = endLine
    if (this.is('elif')) {
      const nested = this.parseIf() as Extract<Stmt, { k: 'if' }>
      nested.isElif = true
      els = [nested]
      elseLine = nested.headSpan.line
      end = nested.endLine
    } else if (this.is('else')) {
      const et = this.advance()
      elseLine = et.line
      const b = this.parseBlock(et)
      els = b.body
      end = b.endLine
    }
    return { k: 'if', id: this.id(), cond, then: body, else: els, headSpan, elseLine, endLine: end, span: { ...headSpan, endLine: end } }
  }

  parseDef(): Stmt {
    const t = this.advance()
    const name = this.ident().v
    this.expect('(')
    const params: FuncDecl['params'] = []
    while (!this.is(')')) {
      const p = this.ident()
      params.push({ name: p.v, type: null, span: this.tspan(p) })
      if (!this.accept(',')) break
    }
    this.expect(')', 'syntax.missingParen')
    if (this.is('->')) {
      this.advance()
      this.parseExpr()
    }
    const headSpan = this.spanFrom(t)
    const { body, endLine } = this.parseBlock(t)
    return { k: 'func', id: this.id(), name, params, ret: null, body, headSpan, endLine, span: { ...headSpan, endLine } }
  }

  parseSimple(): Stmt[] {
    const t = this.cur
    const sp = this.tspan(t)
    let s: Stmt
    if (this.is('return')) {
      this.advance()
      const e = this.at('nl') || this.at('eof') || this.at('dedent') ? null : this.parseExpr()
      s = { k: 'return', id: this.id(), e, span: this.spanFrom(sp) }
    } else if (this.is('break') || this.is('continue') || this.is('pass')) {
      this.advance()
      s = { k: t.v as 'break', id: this.id(), span: sp }
    } else if (this.is('global')) {
      this.advance()
      const names = [this.ident().v]
      while (this.accept(',')) names.push(this.ident().v)
      s = { k: 'global', id: this.id(), names, span: this.spanFrom(sp) }
    } else {
      const e = this.parseExpr()
      if (this.is('=') || ['+=', '-=', '*=', '/=', '%=', '//=', '**='].includes(this.cur.v)) {
        const op = this.advance().v
        if (e.k !== 'name' && e.k !== 'index') this.fail('syntax.badTarget', t)
        // a = b = 0 non supporté : une seule cible
        const value = this.parseExpr()
        s = { k: 'assign', id: this.id(), target: e, op, value, span: joinSpan(e.span, value.span) }
      } else if (this.is('++') || this.is('--')) {
        this.fail('py.noIncrement')
      } else {
        s = { k: 'expr', id: this.id(), e, span: e.span }
      }
    }
    this.endOfSimple()
    return [s]
  }
}

function lastLine(s: Stmt): number {
  if ('endLine' in s && typeof s.endLine === 'number') return s.endLine
  return s.span.endLine
}

export function parsePython(src: string): Program {
  const lm = new LineMap(src)
  const toks = tokenize('python', lm)
  const p = new PyParser('python', lm, toks)
  return p.parseProgram()
}
