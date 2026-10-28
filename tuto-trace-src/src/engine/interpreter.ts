// Interpréteur pédagogique : un générateur qui produit un « pas » (Step) par instruction.
import { typeStr, type Expr, type FuncDecl, type Lang, type Program, type Span, type Stmt, type TypeRef } from './ast'
import { LineMap } from './tokenizer'
import { NULL, bool, dbl, display, int, list, rangeLen, repr, str, truthy, typeName, valueEquals, type Value } from './values'

export type StepKind =
  | 'start' | 'decl' | 'assign' | 'incdec' | 'cond' | 'loopBack' | 'forNext' | 'forUpdate'
  | 'call' | 'return' | 'print' | 'mutate' | 'expr' | 'break' | 'continue' | 'error' | 'end' | 'limit'

export interface VarView {
  name: string
  type?: string
  text: string
  items?: string[]
  unset?: boolean
}

export interface FrameView {
  id: number
  fn: string
  callLine?: number
  vars: VarView[]
  ret?: string
  global?: boolean
}

export type FlyTarget = { var: { frameId: number; name: string } } | { console: true } | { span: Span } | { ret: number }

export interface Fly {
  from: Span
  text: string
  to: FlyTarget
}

export interface Step {
  i: number
  kind: StepKind
  line: number
  span: Span
  key: string
  params: Record<string, string | number>
  construct?: number
  arc?: 'true' | 'false' | 'back'
  jump?: { from: number; to: number; kind: 'call' | 'return' }
  flies?: Fly[]
  links?: { from: Span; to: Span }[] // argument (appel) → paramètre (définition)
  changed?: { frameId: number; name: string }
  error?: { code: string; params: Record<string, string | number> }
  frameId: number
  depth: number
  frames: FrameView[]
  out: string
}

export const MAX_STEPS = 5000
const MAX_DEPTH = 100

interface Var {
  v: Value | undefined
  type: TypeRef | null
  final: boolean
}

class Frame {
  scopes: Map<string, Var>[] = [new Map()]
  ret?: Value
  globals = new Set<string>() // Python : noms déclarés `global`
  locals?: Set<string> // Python : noms affectés dans la fonction
  constructor(public id: number, public fn: string, public func?: FuncDecl, public callSpan?: Span, public isGlobal = false) {}
  find(name: string): Var | undefined {
    for (let i = this.scopes.length - 1; i >= 0; i--) {
      const v = this.scopes[i].get(name)
      if (v) return v
    }
    return undefined
  }
}

class Signal {}
class BreakSig extends Signal {}
class ContinueSig extends Signal {}
class ReturnSig extends Signal {
  constructor(public value: Value, public stmt: Extract<Stmt, { k: 'return' }>) {
    super()
  }
}
class LimitSig extends Signal {}
export class RuntimeErr extends Signal {
  constructor(public code: string, public span: Span, public params: Record<string, string | number> = {}) {
    super()
  }
}

type Gen<T = void> = Generator<Step, T, void>

export class Interpreter {
  steps = 0
  frames: Frame[] = []
  out = ''
  nextFrameId = 1
  definedFuncs = new Set<string>()
  lm: LineMap
  lang: Lang

  constructor(public program: Program, public src: string) {
    this.lm = new LineMap(src)
    this.lang = program.lang
  }

  // ---------- Utilitaires ----------
  get frame(): Frame {
    return this.frames[this.frames.length - 1]
  }
  get globalFrame(): Frame {
    return this.frames[0]
  }
  text(span: Span): string {
    return this.src.slice(span.start, span.end)
  }
  lineSpan(line: number): Span {
    const start = this.lm.starts[line - 1] ?? 0
    let end = this.src.indexOf('\n', start)
    if (end < 0) end = this.src.length
    const trimmed = this.src.slice(start, end)
    const lead = trimmed.length - trimmed.trimStart().length
    return { start: start + lead, end: Math.max(start + lead + 1, end), line, endLine: line }
  }
  /** Texte de l'expression où chaque variable est remplacée par sa valeur (`i <= n` → `3 <= 5`), '' si rien à remplacer. */
  withValues(e: Expr): string {
    const names: Extract<Expr, { k: 'name' }>[] = []
    const visit = (x: unknown) => {
      if (!x || typeof x !== 'object') return
      if (Array.isArray(x)) return x.forEach(visit)
      const n = x as Expr
      if (n.k === 'name') names.push(n)
      else for (const [key, val] of Object.entries(n)) if (key !== 'span' && key !== 'nameSpan') visit(val)
    }
    visit(e)
    let out = this.text(e.span)
    for (const n of names.sort((a, b) => b.span.start - a.span.start)) {
      let v: Value | undefined
      try {
        v = this.lookup(n.name, n.span).v
      } catch {
        return ''
      }
      if (v === undefined) return ''
      out = out.slice(0, n.span.start - e.span.start) + this.repr(v) + out.slice(n.span.end - e.span.start)
    }
    return names.length ? out : ''
  }
  repr(v: Value | undefined): string {
    return v === undefined ? '?' : repr(this.lang, v)
  }
  err(code: string, span: Span, params: Record<string, string | number> = {}): never {
    throw new RuntimeErr(code, span, params)
  }

  snapshot(): FrameView[] {
    return this.frames.map((f) => {
      const vars: VarView[] = []
      for (const scope of f.scopes)
        for (const [name, v] of scope) {
          const vv: VarView = { name, text: this.repr(v.v), unset: v.v === undefined }
          if (this.lang !== 'python') vv.type = typeStr(v.type) === 'var' && v.v ? typeName(this.lang, v.v) : typeStr(v.type)
          else if (v.v) vv.type = typeName('python', v.v)
          if (v.v?.k === 'list') vv.items = v.v.items.map((x) => this.repr(x))
          vars.push(vv)
        }
      return {
        id: f.id,
        fn: f.fn,
        callLine: f.callSpan?.line,
        vars,
        ret: f.ret ? this.repr(f.ret) : undefined,
        global: f.isGlobal,
      }
    })
  }

  emit(s: Omit<Step, 'i' | 'frames' | 'out' | 'frameId' | 'depth' | 'line'> & { line?: number; caller?: boolean }): Step {
    const { caller, ...rest } = s
    // caller : le pas appartient au contexte appelant (l'appel, alors que le nouveau contexte est déjà empilé)
    const owner = caller ? this.frames.length - 2 : this.frames.length - 1
    if (this.steps >= MAX_STEPS) throw new LimitSig()
    const step: Step = {
      ...rest,
      line: s.line ?? s.span.line,
      i: this.steps++,
      frameId: this.frames[owner]?.id ?? 0,
      depth: Math.max(0, owner),
      frames: this.snapshot(),
      out: this.out,
    }
    return step
  }

  // ---------- Exécution globale ----------
  *run(): Gen {
    const p = this.program
    const py = this.lang === 'python'
    const globalName = py ? 'global' : p.entry === 'main' ? 'global' : 'Main'
    const g = new Frame(this.nextFrameId++, globalName, undefined, undefined, true)
    this.frames.push(g)
    try {
      if (p.entry === 'top') {
        // le programme commence à la première instruction exécutée (les `def` ne sont pas des pas)
        const first = p.body.find((s) => s.k !== 'func')
        if (first) yield this.emit({ kind: 'start', span: first.span.line === first.span.endLine ? first.span : this.lineSpan(first.span.line), key: 'start.top', params: { line: first.span.line } })
        yield* this.execBlock(p.body, false)
      } else {
        yield* this.execBlock(p.body, false)
        const main = p.funcs.get(p.mainName!)!
        yield this.emit({ kind: 'start', span: main.headSpan, key: 'start.main', params: { name: main.name } })
        const mf = new Frame(this.nextFrameId++, main.name, main)
        if (p.lang === 'csharp' && main.params.length) mf.scopes[0].set(main.params[0].name, { v: list([], 'string', true), type: main.params[0].type, final: false })
        this.frames.push(mf)
        try {
          yield* this.execBlock(main.body, false)
        } catch (e) {
          if (!(e instanceof ReturnSig)) throw e
        }
        this.frames.pop()
      }
      yield this.emit({ kind: 'end', span: this.lineSpan(Math.max(1, this.lastCodeLine())), key: 'end', params: {} })
    } catch (e) {
      if (e instanceof RuntimeErr) {
        yield this.emit({ kind: 'error', span: e.span, key: 'error', params: e.params, error: { code: e.code, params: e.params } })
      } else if (e instanceof LimitSig) {
        this.steps = MAX_STEPS - 1
        yield this.emit({ kind: 'limit', span: this.lineSpan(1), key: 'limit', params: { max: MAX_STEPS } })
      } else throw e
    }
  }

  lastCodeLine(): number {
    const lines = this.src.split('\n')
    for (let i = lines.length - 1; i >= 0; i--) if (lines[i].trim()) return i + 1
    return 1
  }

  // ---------- Portée des variables ----------
  lookup(name: string, span: Span): Var {
    const f = this.frame
    if (this.lang === 'python') {
      const isLocal = !f.isGlobal && f.locals?.has(name) && !f.globals.has(name)
      if (isLocal) {
        const v = f.find(name)
        if (!v || v.v === undefined) this.err('py.unboundLocal', span, { name })
        return v
      }
      const v = (f.isGlobal ? f : this.globalFrame).find(name)
      if (!v) this.err('py.nameError', span, { name })
      return v
    }
    const v = f.find(name) ?? this.globalFrame.find(name)
    if (!v) this.err('runtime.undeclared', span, { name })
    return v
  }

  /** Cadre et variable où écrire `name` (Python crée la variable si besoin). */
  writeTarget(name: string, span: Span): { frame: Frame; v: Var | undefined } {
    const f = this.frame
    if (this.lang === 'python') {
      const target = f.isGlobal || f.globals.has(name) ? this.globalFrame : f
      return { frame: target, v: target.find(name) }
    }
    const local = f.find(name)
    if (local) return { frame: f, v: local }
    const gv = this.globalFrame.find(name)
    if (gv) return { frame: this.globalFrame, v: gv }
    this.err('runtime.undeclared', span, { name })
  }

  coerce(v: Value, t: TypeRef | null): Value {
    if (!t) return v
    if ((t.name === 'double' || t.name === 'float' || t.name === 'decimal') && !t.array && v.k === 'int') return dbl(v.v)
    if (v.k === 'list' && (t.args?.length || t.array)) {
      v.elem = t.array ? t.name : typeStr(t.args![0])
      v.array = !!t.array
      if (v.elem === 'double') v.items = v.items.map((x) => (x.k === 'int' ? dbl(x.v) : x))
    }
    return v
  }

  // ---------- Instructions ----------
  *execBlock(stmts: Stmt[], newScope = true): Gen {
    if (newScope && this.lang !== 'python') this.frame.scopes.push(new Map())
    try {
      for (const s of stmts) yield* this.exec(s)
    } finally {
      if (newScope && this.lang !== 'python') this.frame.scopes.pop()
    }
  }

  *exec(s: Stmt): Gen {
    switch (s.k) {
      case 'decl': {
        const f = this.frame
        let v: Value | undefined
        if (s.init) v = this.coerce(yield* this.eval(s.init, s.type), s.type)
        else if (s.type?.nullable) v = NULL
        f.scopes[f.scopes.length - 1].set(s.name, { v, type: s.type ?? (v ? { name: typeName(this.lang, v) } : null), final: s.final })
        yield this.emit({
          kind: 'decl',
          span: s.span,
          key: s.init ? 'decl.init' : 'decl.noinit',
          params: { name: s.name, type: typeStr(s.type), value: this.repr(v) },
          changed: { frameId: f.id, name: s.name },
          flies: s.init ? [{ from: s.init.span, text: this.repr(v), to: { var: { frameId: f.id, name: s.name } } }] : undefined,
        })
        return
      }
      case 'assign':
        return yield* this.execAssign(s)
      case 'incdec': {
        const t = s.target
        if (t.k !== 'name') this.err('runtime.unsupported', s.span)
        const { frame, v } = this.writeTarget(t.name, t.span)
        const cur = this.lookup(t.name, t.span).v!
        if (cur.k !== 'int' && cur.k !== 'double') this.err('runtime.badOperand', s.span, { op: s.op, type: typeName(this.lang, cur) })
        const nv = this.wrap({ k: cur.k, v: cur.v + (s.op === '++' ? 1 : -1) } as Value)
        v!.v = nv
        yield this.emit({
          kind: 'incdec',
          span: s.span,
          key: s.op === '++' ? 'incdec.inc' : 'incdec.dec',
          params: { name: t.name, old: this.repr(cur), value: this.repr(nv) },
          changed: { frameId: frame.id, name: t.name },
        })
        return
      }
      case 'expr': {
        const before = this.steps
        const v = yield* this.eval(s.e)
        const silent = s.e.k === 'call' || s.e.k === 'mcall'
        if (!silent || this.steps === before)
          yield this.emit({ kind: 'expr', span: s.span, key: 'expr', params: { value: this.repr(v) } })
        return
      }
      case 'if': {
        const c = yield* this.cond(s.cond)
        const hasElif = !!s.else && s.else.length === 1 && s.else[0].k === 'if' && (s.else[0] as Extract<Stmt, { k: 'if' }>).isElif
        yield this.emit({
          kind: 'cond',
          span: s.cond.span,
          line: s.headSpan.line,
          key: c ? 'if.true' : !s.else ? 'if.false.none' : hasElif ? 'if.false.elif' : 'if.false.else',
          params: { cond: this.text(s.cond.span), vals: this.withValues(s.cond), value: this.repr(bool(c)) },
          construct: s.id,
          arc: c ? 'true' : 'false',
        })
        if (c) yield* this.execBlock(s.then)
        else if (s.else) yield* this.execBlock(s.else, !hasElif)
        return
      }
      case 'while':
        for (;;) {
          const c = yield* this.cond(s.cond)
          yield this.emit({
            kind: 'cond',
            span: s.cond.span,
            line: s.headSpan.line,
            key: c ? 'while.true' : 'while.false',
            params: { cond: this.text(s.cond.span), vals: this.withValues(s.cond), value: this.repr(bool(c)) },
            construct: s.id,
            arc: c ? 'true' : 'false',
          })
          if (!c) return
          if (!(yield* this.loopBody(s.body))) return
          yield this.emit({ kind: 'loopBack', span: this.lineSpan(s.endLine), key: 'while.back', params: { line: s.headSpan.line }, construct: s.id, arc: 'back' })
        }
      case 'dowhile':
        for (;;) {
          if (!(yield* this.loopBody(s.body))) return
          const c = yield* this.cond(s.cond)
          yield this.emit({
            kind: 'cond',
            span: s.cond.span,
            line: s.condSpan.line,
            key: c ? 'dowhile.true' : 'dowhile.false',
            params: { cond: this.text(s.cond.span), vals: this.withValues(s.cond), value: this.repr(bool(c)) },
            construct: s.id,
            arc: c ? 'back' : 'false',
          })
          if (!c) return
        }
      case 'for':
        return yield* this.execFor(s)
      case 'foreach':
        return yield* this.execForeach(s)
      case 'return': {
        const v = s.e ? yield* this.eval(s.e, this.frame.func?.ret ?? null) : NULL
        throw new ReturnSig(v, s)
      }
      case 'break':
        yield this.emit({ kind: 'break', span: s.span, key: 'break', params: {} })
        throw new BreakSig()
      case 'continue':
        yield this.emit({ kind: 'continue', span: s.span, key: 'continue', params: {} })
        throw new ContinueSig()
      case 'pass':
        yield this.emit({ kind: 'expr', span: s.span, key: 'pass', params: {} })
        return
      case 'global':
        for (const n of s.names) this.frame.globals.add(n)
        return
      case 'block':
        return yield* this.execBlock(s.body)
      case 'func':
        // la ligne `def` ne produit pas de pas : on se concentre sur l'exécution des instructions
        if (this.lang === 'python') this.definedFuncs.add(s.name)
        return
    }
  }

  /** Exécute le corps d'une boucle ; retourne false si `break`. */
  *loopBody(body: Stmt[]): Gen<boolean> {
    try {
      yield* this.execBlock(body)
    } catch (e) {
      if (e instanceof BreakSig) return false
      if (!(e instanceof ContinueSig)) throw e
    }
    return true
  }

  *cond(e: Expr): Gen<boolean> {
    const v = yield* this.eval(e)
    if (this.lang !== 'python' && v.k !== 'bool') this.err('runtime.condNotBool', e.span, { type: typeName(this.lang, v) })
    return truthy(v)
  }

  *execAssign(s: Extract<Stmt, { k: 'assign' }>): Gen {
    const t = s.target
    if (t.k === 'index') {
      const obj = yield* this.eval(t.obj)
      const idx = yield* this.eval(t.idx)
      let v = yield* this.eval(s.value)
      if (obj.k !== 'list') this.err(obj.k === 'str' ? 'runtime.strImmutable' : 'runtime.notIndexable', t.obj.span, { type: typeName(this.lang, obj) })
      const i = this.checkIndex(obj, idx, t.idx.span)
      if (s.op !== '=') v = this.binop(s.op.slice(0, -1), obj.items[i], v, s.span)
      if (obj.elem === 'double' && v.k === 'int') v = dbl(v.v)
      obj.items[i] = v
      const owner = t.obj.k === 'name' ? t.obj.name : this.text(t.obj.span)
      const fr = t.obj.k === 'name' ? this.ownerFrame(t.obj.name) : this.frame
      yield this.emit({
        kind: 'assign',
        span: s.span,
        key: 'assign.index',
        params: { name: owner, index: i, value: this.repr(v) },
        changed: { frameId: fr.id, name: owner },
        flies: [{ from: s.value.span, text: this.repr(v), to: { var: { frameId: fr.id, name: owner } } }],
      })
      return
    }
    if (t.k !== 'name') this.err('runtime.unsupported', s.span)
    const name = t.name
    let { frame, v: slot } = this.writeTarget(name, t.span)
    let val: Value
    let old: Value | undefined
    if (s.op === '=') {
      val = yield* this.eval(s.value, slot?.type ?? null)
    } else {
      old = this.lookup(name, t.span).v
      const rhs = yield* this.eval(s.value)
      const op = s.op.slice(0, -1)
      val = this.binop(op, old!, rhs, s.span)
      // C# : x += 1.5 sur un int est refusé par le compilateur ; ici on garde le type déclaré
    }
    if (this.lang === 'python') {
      ;({ frame, v: slot } = this.writeTarget(name, t.span))
      if (!slot) {
        slot = { v: undefined, type: null, final: false }
        frame.scopes[0].set(name, slot)
      }
    }
    if (slot!.final) this.err('runtime.final', t.span, { name })
    const created = slot!.v === undefined && this.lang === 'python'
    old = old ?? slot!.v
    val = this.coerce(val, slot!.type)
    slot!.v = val
    yield this.emit({
      kind: 'assign',
      span: s.span,
      key: s.op !== '=' ? 'assign.op' : created ? 'assign.new' : old === undefined ? 'assign.first' : 'assign',
      params: { name, value: this.repr(val), old: this.repr(old), op: s.op },
      changed: { frameId: frame.id, name },
      flies: [{ from: s.value.span, text: this.repr(val), to: { var: { frameId: frame.id, name } } }],
    })
  }

  ownerFrame(name: string): Frame {
    if (this.frame.find(name)) return this.frame
    return this.globalFrame
  }

  *execFor(s: Extract<Stmt, { k: 'for' }>): Gen {
    this.frame.scopes.push(new Map())
    try {
      if (s.init) yield* this.relabel(this.exec(s.init), 'for.init', s.id)
      for (;;) {
        if (s.cond) {
          const c = yield* this.cond(s.cond)
          yield this.emit({
            kind: 'cond',
            span: s.cond.span,
            line: s.headSpan.line,
            key: c ? 'for.true' : 'for.false',
            params: { cond: this.text(s.cond.span), vals: this.withValues(s.cond), value: this.repr(bool(c)) },
            construct: s.id,
            arc: c ? 'true' : 'false',
          })
          if (!c) return
        }
        if (!(yield* this.loopBody(s.body))) return
        if (s.update) yield* this.relabel(this.exec(s.update), 'for.update', s.id, 'back')
      }
    } finally {
      this.frame.scopes.pop()
    }
  }

  /** Re-étiquette les pas d'initialisation / mise à jour d'un for. */
  *relabel(g: Gen, key: string, construct: number, arc?: 'back'): Gen {
    const depth = this.frames.length - 1
    for (const st of g) {
      if (st.depth === depth && (st.kind === 'decl' || st.kind === 'assign' || st.kind === 'incdec')) {
        st.params = { ...st.params, inner: st.key }
        st.key = key
        st.construct = construct
        if (arc) st.arc = arc
        if (key === 'for.update') st.kind = 'forUpdate'
      }
      yield st
    }
  }

  *execForeach(s: Extract<Stmt, { k: 'foreach' }>): Gen {
    const it = yield* this.eval(s.iter)
    const at = (i: number): Value | undefined => {
      if (it.k === 'list') return it.items[i]
      if (it.k === 'str') return i < it.v.length ? (this.lang === 'csharp' ? { k: 'char', v: it.v[i] } : str(it.v[i])) : undefined
      if (it.k === 'range') return i < rangeLen(it) ? int(it.start + i * it.step) : undefined
      return undefined
    }
    if (it.k !== 'list' && it.k !== 'str' && it.k !== 'range') this.err('runtime.notIterable', s.iter.span, { type: typeName(this.lang, it) })
    const py = this.lang === 'python'
    for (let i = 0; ; i++) {
      const v = at(i)
      if (v === undefined) {
        yield this.emit({
          kind: 'cond',
          span: s.headSpan,
          key: 'foreach.done',
          params: { name: s.varName, iter: this.text(s.iter.span) },
          construct: s.id,
          arc: 'false',
        })
        return
      }
      if (!py) this.frame.scopes.push(new Map())
      try {
        let frame = this.frame
        if (py) {
          const w = this.writeTarget(s.varName, s.varSpan)
          frame = w.frame
          if (w.v) w.v.v = v
          else frame.scopes[0].set(s.varName, { v, type: null, final: false })
        } else this.frame.scopes[this.frame.scopes.length - 1].set(s.varName, { v: this.coerce(v, s.varType), type: s.varType ?? { name: typeName(this.lang, v) }, final: false })
        yield this.emit({
          kind: 'forNext',
          span: s.headSpan,
          key: 'foreach.next',
          params: { name: s.varName, value: this.repr(v), index: i, index1: i + 1, iter: this.text(s.iter.span) },
          construct: s.id,
          arc: 'true',
          changed: { frameId: frame.id, name: s.varName },
          flies: [{ from: s.iter.span, text: this.repr(v), to: { var: { frameId: frame.id, name: s.varName } } }],
        })
        const cont = yield* this.loopBody(s.body)
        if (!cont) return
        yield this.emit({ kind: 'loopBack', span: this.lineSpan(s.endLine), key: 'foreach.back', params: { name: s.varName, line: s.headSpan.line }, construct: s.id, arc: 'back' })
      } finally {
        if (!py) this.frame.scopes.pop()
      }
    }
  }

  // ---------- Appels de fonctions ----------
  *callUser(f: FuncDecl, args: Value[], argExprs: Expr[], callSpan: Span): Gen<Value> {
    if (args.length !== f.params.length)
      this.err('runtime.argCount', callSpan, { name: f.name, expected: f.params.length, given: args.length })
    if (this.frames.length > MAX_DEPTH) this.err(this.lang === 'python' ? 'py.recursion' : 'runtime.stackOverflow', callSpan, { name: f.name, max: MAX_DEPTH })
    const fr = new Frame(this.nextFrameId++, f.name, f, callSpan)
    if (this.lang === 'python') {
      fr.locals = new Set()
      collectPyLocals(f.body, fr.locals, fr.globals)
      for (const p of f.params) fr.locals.add(p.name)
    }
    f.params.forEach((p, i) => fr.scopes[0].set(p.name, { v: this.coerce(args[i], p.type), type: p.type, final: false }))
    this.frames.push(fr)
    const recursive = this.frames.filter((x) => x.fn === f.name).length > 1
    // le pas d'appel est sur la ligne qui appelle (dans la trace : `a = carre(3)` puis le corps de carre)
    yield this.emit({
      kind: 'call',
      span: callSpan,
      caller: true,
      key: recursive ? 'call.recursive' : f.params.length ? 'call' : 'call.noargs',
      params: {
        name: f.name,
        args: args.map((a) => this.repr(a)).join(', '),
        bindings: f.params.map((p, i) => `${p.name} = ${this.repr(args[i])}`).join(', '),
        passing: f.params.map((p, i) => `${this.repr(args[i])} → ${p.name}`).join(', '),
        defLine: f.headSpan.line,
        line: callSpan.line,
        depth: this.frames.length - 1,
      },
      construct: f.id,
      jump: { from: callSpan.line, to: f.headSpan.line, kind: 'call' },
      flies: argExprs.map((a, i) => ({ from: a.span, text: this.repr(args[i]), to: { var: { frameId: fr.id, name: f.params[i].name } } })),
      links: argExprs.map((a, i) => ({ from: a.span, to: f.params[i].span })),
    })
    let value: Value = NULL
    let retStmt: Extract<Stmt, { k: 'return' }> | null = null
    try {
      yield* this.execBlock(f.body, false)
    } catch (e) {
      if (e instanceof ReturnSig) {
        value = e.value
        retStmt = e.stmt
      } else if (e instanceof BreakSig || e instanceof ContinueSig) {
        throw e
      } else throw e
    }
    value = this.coerce(value, f.ret)
    const isVoid = this.lang === 'python' ? !retStmt?.e : f.ret?.name === 'void' || !retStmt?.e
    fr.ret = isVoid ? undefined : value
    const span = retStmt ? retStmt.span : this.lineSpan(f.endLine)
    yield this.emit({
      kind: 'return',
      span,
      key: retStmt ? (isVoid ? 'return.void' : 'return.value') : 'return.implicit',
      params: { name: f.name, value: this.repr(value), line: callSpan.line, call: this.text(callSpan) },
      construct: f.id,
      jump: { from: span.line, to: callSpan.line, kind: 'return' },
      flies: !isVoid && retStmt?.e ? [{ from: retStmt.e.span, text: this.repr(value), to: { span: callSpan } }] : undefined,
    })
    this.frames.pop()
    return value
  }

  // ---------- Expressions ----------
  *eval(e: Expr, hint: TypeRef | null = null): Gen<Value> {
    switch (e.k) {
      case 'num':
        return e.isInt ? int(e.v) : dbl(e.v)
      case 'str':
        return e.char ? { k: 'char', v: e.v } : str(e.v)
      case 'istr': {
        let s = ''
        for (const p of e.parts) s += typeof p === 'string' ? p : display(this.lang, yield* this.eval(p))
        return str(s)
      }
      case 'bool':
        return bool(e.v)
      case 'null':
        return NULL
      case 'name': {
        const v = this.lookup(e.name, e.span)
        if (v.v === undefined) this.err('runtime.unassigned', e.span, { name: e.name })
        return v.v
      }
      case 'bin': {
        if (e.op === 'and' || e.op === 'or') {
          const l = yield* this.eval(e.l)
          if (this.lang !== 'python' && l.k !== 'bool') this.err('runtime.condNotBool', e.l.span, { type: typeName(this.lang, l) })
          if (e.op === 'and' ? !truthy(l) : truthy(l)) return this.lang === 'python' ? l : bool(truthy(l))
          const r = yield* this.eval(e.r)
          return this.lang === 'python' ? r : bool(truthy(r))
        }
        const l = yield* this.eval(e.l)
        const r = yield* this.eval(e.r)
        return this.binop(e.op, l, r, e.span)
      }
      case 'un': {
        const v = yield* this.eval(e.e)
        if (e.op === 'not') return bool(!truthy(v))
        if (v.k !== 'int' && v.k !== 'double') this.err('runtime.badOperand', e.span, { op: e.op, type: typeName(this.lang, v) })
        return e.op === '-' ? this.wrap({ k: v.k, v: -v.v } as Value) : v
      }
      case 'tern': {
        const c = yield* this.cond(e.c)
        return yield* this.eval(c ? e.a : e.b, hint)
      }
      case 'list': {
        const items: Value[] = []
        for (const it of e.items) items.push(yield* this.eval(it))
        const elemT = e.elemType ?? (hint?.args?.[0] ?? (hint?.array ? { name: hint.name } : null))
        const elem = elemT ? typeStr(elemT) : items[0] ? typeName(this.lang, items[0]) : undefined
        const l = list(items, elem, e.ctor === 'array' || !!hint?.array)
        if (elem === 'double') l.k === 'list' && (l.items = l.items.map((x) => (x.k === 'int' ? dbl(x.v) : x)))
        return l
      }
      case 'newArr': {
        const n = yield* this.eval(e.size)
        if (n.k !== 'int' || n.v < 0) this.err('runtime.badSize', e.size.span, { value: this.repr(n) })
        const t = e.elemType.name
        const def: Value = t === 'int' ? int(0) : t === 'double' ? dbl(0) : t === 'bool' ? bool(false) : t === 'char' ? { k: 'char', v: '\0' } : NULL
        return list(Array.from({ length: n.v }, () => ({ ...def }) as Value), t, true)
      }
      case 'cast': {
        const v = yield* this.eval(e.e)
        if (e.type.name === 'int' && (v.k === 'double' || v.k === 'int')) return int(Math.trunc(v.v))
        if (e.type.name === 'double' && (v.k === 'double' || v.k === 'int')) return dbl(v.v)
        if (e.type.name === 'int' && v.k === 'char') return int(v.v.charCodeAt(0))
        if (e.type.name === 'char' && v.k === 'int') return { k: 'char', v: String.fromCharCode(v.v) }
        this.err('runtime.badCast', e.span, { from: typeName(this.lang, v), to: e.type.name })
      }
      case 'index': {
        const obj = yield* this.eval(e.obj)
        const idx = yield* this.eval(e.idx)
        if (obj.k === 'list') return obj.items[this.checkIndex(obj, idx, e.idx.span)]
        if (obj.k === 'str') {
          const i = this.checkIndex(obj, idx, e.idx.span)
          return this.lang === 'csharp' ? { k: 'char', v: obj.v[i] } : str(obj.v[i])
        }
        this.err('runtime.notIndexable', e.obj.span, { type: typeName(this.lang, obj) })
      }
      case 'member':
        return yield* this.member(e)
      case 'call':
        return yield* this.call(e)
      case 'mcall':
        return yield* this.mcall(e)
    }
  }

  checkIndex(obj: Value, idx: Value, span: Span): number {
    if (idx.k !== 'int') this.err('runtime.indexType', span, { type: typeName(this.lang, idx) })
    const len = obj.k === 'list' ? obj.items.length : obj.k === 'str' ? obj.v.length : 0
    let i = idx.v
    if (this.lang === 'python' && i < 0) i += len
    if (i < 0 || i >= len) this.err('runtime.indexOut', span, { index: idx.v, len, list: obj.k === 'list' && !obj.array ? 1 : 0 })
    return i
  }

  /** Débordement des int 32 bits en C#. */
  wrap(v: Value): Value {
    if (this.lang === 'csharp' && v.k === 'int') return int(v.v | 0)
    return v
  }

  binop(op: string, l: Value, r: Value, span: Span): Value {
    const lang = this.lang
    const num = (x: Value) => x.k === 'int' || x.k === 'double'
    const bad = (): never => this.err('runtime.badOperands', span, { op, left: typeName(lang, l), right: typeName(lang, r) })
    switch (op) {
      case '==':
        return bool(this.eq(l, r))
      case '!=':
        return bool(!this.eq(l, r))
      case 'in':
      case 'not in': {
        let res: boolean
        if (r.k === 'list') res = r.items.some((x) => valueEquals(x, l))
        else if (r.k === 'str' && l.k === 'str') res = r.v.includes(l.v)
        else if (r.k === 'range' && l.k === 'int') res = l.v >= r.start && l.v < r.stop && (l.v - r.start) % r.step === 0
        else return bad()
        return bool(op === 'in' ? res : !res)
      }
      case '<':
      case '>':
      case '<=':
      case '>=': {
        let a: number | string
        let b: number | string
        if (num(l) && num(r)) {
          a = (l as { v: number }).v
          b = (r as { v: number }).v
        } else if (lang === 'python' && l.k === 'str' && r.k === 'str') {
          a = l.v
          b = r.v
        } else if (l.k === 'char' && r.k === 'char') {
          a = l.v
          b = r.v
        } else return bad()
        return bool(op === '<' ? a < b : op === '>' ? a > b : op === '<=' ? a <= b : a >= b)
      }
      case '+':
        if (num(l) && num(r)) return this.arith(op, l, r)
        if (l.k === 'str' && r.k === 'str') return str(l.v + r.v)
        if (lang === 'csharp' && (l.k === 'str' || r.k === 'str')) return str(display(lang, l) + display(lang, r))
        if (lang === 'csharp' && l.k === 'char' && r.k === 'char') return int(l.v.charCodeAt(0) + r.v.charCodeAt(0))
        if (lang === 'python' && l.k === 'list' && r.k === 'list') return list([...l.items, ...r.items])
        if (lang === 'python' && (l.k === 'str' || r.k === 'str')) this.err('py.strConcat', span, { left: typeName(lang, l), right: typeName(lang, r) })
        return bad()
      case '*':
        if (num(l) && num(r)) return this.arith(op, l, r)
        if (lang !== 'csharp' && l.k === 'str' && r.k === 'int') return str(l.v.repeat(Math.max(0, r.v)))
        if (lang === 'python' && l.k === 'int' && r.k === 'str') return str(r.v.repeat(Math.max(0, l.v)))
        if (lang === 'python' && l.k === 'list' && r.k === 'int') return list(Array.from({ length: Math.max(0, r.v) }, () => l.items).flat())
        return bad()
      case '-':
      case '/':
      case '%':
      case '//':
      case '~/':
      case '**':
        if (num(l) && num(r)) return this.arith(op, l, r, span)
        return bad()
    }
    return bad()
  }

  eq(l: Value, r: Value): boolean {
    if (this.lang !== 'python' && l.k === 'list' && r.k === 'list') return l === r
    return valueEquals(l, r)
  }

  arith(op: string, l: Value, r: Value, span?: Span): Value {
    const a = (l as { v: number }).v
    const b = (r as { v: number }).v
    const ints = l.k === 'int' && r.k === 'int'
    const mk = (v: number) => this.wrap(ints ? int(v) : dbl(v))
    const lang = this.lang
    switch (op) {
      case '+':
        return mk(a + b)
      case '-':
        return mk(a - b)
      case '*':
        return ints ? this.wrap(int(lang === 'csharp' ? Math.imul(a, b) : a * b)) : dbl(a * b)
      case '/':
        if (lang === 'python') {
          if (b === 0) this.err('py.zeroDiv', span!)
          return dbl(a / b)
        }
        if (lang === 'csharp' && ints) {
          if (b === 0) this.err('runtime.divZero', span!)
          return int(Math.trunc(a / b))
        }
        return dbl(a / b)
      case '//':
        if (b === 0) this.err('py.zeroDiv', span!)
        return ints ? int(Math.floor(a / b)) : dbl(Math.floor(a / b))
      case '~/':
        if (b === 0) this.err('runtime.divZero', span!)
        return int(Math.trunc(a / b))
      case '%':
        if (b === 0) this.err(lang === 'python' ? 'py.zeroDiv' : ints ? 'runtime.divZero' : 'runtime.divZero', span!)
        if (lang === 'python') return mk(a - b * Math.floor(a / b))
        if (lang === 'dart') {
          const m = a % b
          return mk(m < 0 ? m + Math.abs(b) : m)
        }
        return mk(a % b)
      case '**':
        if (ints && b >= 0) return int(a ** b)
        return dbl(a ** b)
    }
    return NULL
  }

  *member(e: Extract<Expr, { k: 'member' }>): Gen<Value> {
    const obj = yield* this.eval(e.obj)
    const n = e.name
    if (obj.k === 'list') {
      if ((this.lang === 'csharp' && ((obj.array && n === 'Length') || (!obj.array && n === 'Count'))) || (this.lang === 'dart' && n === 'length'))
        return int(obj.items.length)
      if (this.lang === 'dart' && n === 'isEmpty') return bool(obj.items.length === 0)
      if (this.lang === 'dart' && n === 'isNotEmpty') return bool(obj.items.length > 0)
      if (this.lang === 'dart' && (n === 'first' || n === 'last')) {
        if (!obj.items.length) this.err('runtime.emptyList', e.span)
        return n === 'first' ? obj.items[0] : obj.items[obj.items.length - 1]
      }
    }
    if (obj.k === 'str' && ((this.lang === 'csharp' && n === 'Length') || (this.lang === 'dart' && n === 'length'))) return int(obj.v.length)
    if (obj.k === 'str' && this.lang === 'dart' && n === 'isEmpty') return bool(obj.v.length === 0)
    this.err('runtime.noMember', e.span, { name: n, type: typeName(this.lang, obj) })
  }

  *evalArgs(args: Expr[]): Gen<Value[]> {
    const out: Value[] = []
    for (const a of args) out.push(yield* this.eval(a))
    return out
  }

  print(text: string, newline: boolean, span: Span, argSpan?: Span): Step {
    this.out += text + (newline ? '\n' : '')
    return this.emit({
      kind: 'print',
      span,
      key: 'print',
      params: { text: JSON.stringify(text) },
      flies: argSpan ? [{ from: argSpan, text, to: { console: true } }] : undefined,
    })
  }

  *call(e: Extract<Expr, { k: 'call' }>): Gen<Value> {
    const lang = this.lang
    const name = e.name
    const user = this.program.funcs.get(name)
    if (user && (lang !== 'python' || this.definedFuncs.has(name))) {
      const args = yield* this.evalArgs(e.args)
      return yield* this.callUser(user, args, e.args, e.span)
    }
    const args = yield* this.evalArgs(e.args)
    const argc = (n: number, m = n) => {
      if (args.length < n || args.length > m) this.err('runtime.argCount', e.span, { name, expected: n === m ? n : `${n}-${m}`, given: args.length })
    }
    if (name === 'print' && lang !== 'csharp') {
      if (lang === 'dart') argc(1)
      const text = args.map((a) => display(lang, a)).join(' ')
      yield this.print(text, true, e.span, e.args[0]?.span ?? e.span)
      return NULL
    }
    if (lang === 'python') {
      switch (name) {
        case 'len': {
          argc(1)
          const a = args[0]
          if (a.k === 'list') return int(a.items.length)
          if (a.k === 'str') return int(a.v.length)
          if (a.k === 'range') return int(rangeLen(a))
          this.err('py.typeError.len', e.span, { type: typeName(lang, a) })
        }
        case 'range': {
          argc(1, 3)
          if (args.some((a) => a.k !== 'int')) this.err('py.typeError.range', e.span)
          const n = args.map((a) => (a as { v: number }).v)
          const [start, stop, step] = n.length === 1 ? [0, n[0], 1] : n.length === 2 ? [n[0], n[1], 1] : n
          if (step === 0) this.err('py.rangeStep', e.span)
          return { k: 'range', start, stop, step }
        }
        case 'str':
          argc(1)
          return str(display(lang, args[0]))
        case 'int': {
          argc(1)
          const a = args[0]
          if (a.k === 'int' || a.k === 'double') return int(Math.trunc(a.v))
          if (a.k === 'bool') return int(a.v ? 1 : 0)
          if (a.k === 'str' && /^\s*[-+]?\d+\s*$/.test(a.v)) return int(parseInt(a.v, 10))
          this.err('py.valueError.int', e.span, { value: this.repr(a) })
        }
        case 'float': {
          argc(1)
          const a = args[0]
          if (a.k === 'int' || a.k === 'double') return dbl(a.v)
          if (a.k === 'str' && a.v.trim() !== '' && !isNaN(Number(a.v))) return dbl(Number(a.v))
          this.err('py.valueError.float', e.span, { value: this.repr(a) })
        }
        case 'bool':
          argc(1)
          return bool(truthy(args[0]))
        case 'abs': {
          argc(1)
          const a = args[0]
          if (a.k === 'int' || a.k === 'double') return { k: a.k, v: Math.abs(a.v) } as Value
          return this.binop('abs', a, a, e.span)
        }
        case 'min':
        case 'max':
        case 'sum': {
          const items = args.length === 1 && (args[0].k === 'list' || args[0].k === 'range') ? this.iterItems(args[0]) : args
          if (!items.length && name !== 'sum') this.err('py.valueError.empty', e.span, { name })
          if (name === 'sum') return items.reduce((acc, x) => this.binop('+', acc, x, e.span), int(0) as Value)
          return items.reduce((acc, x) => (truthy(this.binop(name === 'min' ? '<' : '>', x, acc, e.span)) ? x : acc))
        }
        case 'round': {
          argc(1, 2)
          const a = args[0]
          if (a.k !== 'int' && a.k !== 'double') return this.binop('round', a, a, e.span)
          if (args.length === 2) {
            const d = (args[1] as { v: number }).v
            return dbl(Number(a.v.toFixed(d)))
          }
          return int(roundHalfEven(a.v))
        }
        case 'input':
          this.err('runtime.noInput', e.span)
      }
      if (this.program.funcs.has(name)) this.err('py.nameErrorFunc', e.nameSpan, { name })
      this.err('py.nameError', e.nameSpan, { name })
    }
    this.err('runtime.unknownFunc', e.nameSpan, { name })
  }

  iterItems(v: Value): Value[] {
    if (v.k === 'list') return v.items
    if (v.k === 'range') return Array.from({ length: rangeLen(v) }, (_, i) => int(v.start + i * v.step))
    return []
  }

  *mcall(e: Extract<Expr, { k: 'mcall' }>): Gen<Value> {
    const lang = this.lang
    const n = e.name
    // Classes statiques C# : Console, Math, int.Parse
    if (e.obj.k === 'name' && !this.frame.find(e.obj.name) && !this.globalFrame.find(e.obj.name)) {
      const cls = e.obj.name
      const args = yield* this.evalArgs(e.args)
      if (lang === 'csharp' && cls === 'Console' && (n === 'WriteLine' || n === 'Write')) {
        if (args.length > 1) this.err('runtime.argCount', e.span, { name: `Console.${n}`, expected: '0-1', given: args.length })
        yield this.print(args.length ? display(lang, args[0]) : '', n === 'WriteLine', e.span, e.args[0]?.span ?? e.span)
        return NULL
      }
      if (lang === 'csharp' && cls === 'Math') {
        const nums = args.map((a) => {
          if (a.k !== 'int' && a.k !== 'double') this.err('runtime.badOperand', e.span, { op: `Math.${n}`, type: typeName(lang, a) })
          return a.v
        })
        const allInt = args.every((a) => a.k === 'int')
        switch (n) {
          case 'Max':
            return allInt ? int(Math.max(...nums)) : dbl(Math.max(...nums))
          case 'Min':
            return allInt ? int(Math.min(...nums)) : dbl(Math.min(...nums))
          case 'Abs':
            return allInt ? int(Math.abs(nums[0])) : dbl(Math.abs(nums[0]))
          case 'Sqrt':
            return dbl(Math.sqrt(nums[0]))
          case 'Pow':
            return dbl(nums[0] ** nums[1])
          case 'Floor':
            return dbl(Math.floor(nums[0]))
          case 'Round':
            return dbl(roundHalfEven(nums[0]))
        }
      }
      if ((cls === 'int' || cls === 'double') && (n === 'Parse' || n === 'parse')) {
        const a = args[0]
        if (a?.k === 'str') {
          if (cls === 'int' && /^\s*[-+]?\d+\s*$/.test(a.v)) return int(parseInt(a.v, 10))
          if (cls === 'double' && a.v.trim() !== '' && !isNaN(Number(a.v))) return dbl(Number(a.v))
        }
        this.err('runtime.parseError', e.span, { value: a ? this.repr(a) : '' })
      }
      this.err(lang === 'python' ? 'py.nameError' : 'runtime.unknownFunc', e.obj.span, { name: `${cls}.${n}` })
    }

    const obj = yield* this.eval(e.obj)
    const args = yield* this.evalArgs(e.args)
    const owner = e.obj.k === 'name' ? e.obj.name : this.text(e.obj.span)
    const ownerFrame = e.obj.k === 'name' ? this.ownerFrame(e.obj.name) : this.frame
    const mutate = (key: string, params: Record<string, string | number>, flyFrom?: Span, flyText?: string): Step =>
      this.emit({
        kind: 'mutate',
        span: e.span,
        key,
        params: { name: owner, ...params },
        changed: { frameId: ownerFrame.id, name: owner },
        flies: flyFrom ? [{ from: flyFrom, text: flyText!, to: { var: { frameId: ownerFrame.id, name: owner } } }] : undefined,
      })

    if (obj.k === 'list') {
      const add = (lang === 'python' && n === 'append') || (lang === 'csharp' && n === 'Add') || (lang === 'dart' && n === 'add')
      if (add) {
        if (obj.array) this.err('runtime.arrayFixed', e.span, { name: owner })
        let v = args[0]
        if (obj.elem === 'double' && v.k === 'int') v = dbl(v.v)
        obj.items.push(v)
        yield mutate('list.add', { value: this.repr(v), size: obj.items.length }, e.args[0].span, this.repr(v))
        return NULL
      }
      if ((lang === 'python' && n === 'pop') || (lang === 'csharp' && n === 'RemoveAt') || (lang === 'dart' && (n === 'removeAt' || n === 'removeLast'))) {
        if (!obj.items.length) this.err('runtime.emptyList', e.span)
        const idx = args.length ? this.checkIndex(obj, args[0], e.args[0].span) : obj.items.length - 1
        const [v] = obj.items.splice(idx, 1)
        yield mutate('list.remove', { value: this.repr(v), index: idx })
        return lang === 'csharp' ? NULL : v
      }
      if ((lang === 'python' && n === 'insert') || (lang === 'csharp' && n === 'Insert') || (lang === 'dart' && n === 'insert')) {
        const i = (args[0] as { v: number }).v
        obj.items.splice(Math.min(Math.max(i, 0), obj.items.length), 0, args[1])
        yield mutate('list.insert', { value: this.repr(args[1]), index: i }, e.args[1].span, this.repr(args[1]))
        return NULL
      }
      if ((lang === 'csharp' && n === 'Contains') || (lang === 'dart' && n === 'contains')) return bool(obj.items.some((x) => valueEquals(x, args[0])))
      if (lang === 'python' && n === 'index') {
        const i = obj.items.findIndex((x) => valueEquals(x, args[0]))
        if (i < 0) this.err('py.valueError.index', e.span, { value: this.repr(args[0]) })
        return int(i)
      }
    }
    if (obj.k === 'str') {
      const up = { python: 'upper', csharp: 'ToUpper', dart: 'toUpperCase' }[lang]
      const low = { python: 'lower', csharp: 'ToLower', dart: 'toLowerCase' }[lang]
      if (n === up) return str(obj.v.toUpperCase())
      if (n === low) return str(obj.v.toLowerCase())
      if ((lang === 'python' && n === 'strip') || (lang === 'csharp' && n === 'Trim') || (lang === 'dart' && n === 'trim')) return str(obj.v.trim())
      if ((lang === 'csharp' && n === 'Contains') || (lang === 'dart' && n === 'contains')) return bool(args[0]?.k === 'str' && obj.v.includes(args[0].v))
      if ((lang === 'csharp' && n === 'Substring') || (lang === 'dart' && n === 'substring')) {
        const a = (args[0] as { v: number }).v
        const b = args[1] ? (args[1] as { v: number }).v : undefined
        const end = b === undefined ? obj.v.length : lang === 'csharp' ? a + b : b
        if (a < 0 || end > obj.v.length || end < a) this.err('runtime.indexOut', e.span, { index: end, len: obj.v.length })
        return str(obj.v.slice(a, end))
      }
    }
    if ((lang === 'csharp' && n === 'ToString') || (lang === 'dart' && n === 'toString')) return str(display(lang, obj))
    if (lang === 'dart' && (obj.k === 'int' || obj.k === 'double')) {
      if (n === 'toInt') return int(Math.trunc(obj.v))
      if (n === 'toDouble') return dbl(obj.v)
      if (n === 'abs') return { k: obj.k, v: Math.abs(obj.v) } as Value
      if (n === 'round') return int(Math.round(obj.v))
      if (n === 'toStringAsFixed') return str(obj.v.toFixed((args[0] as { v: number }).v))
    }
    this.err('runtime.noMember', e.span, { name: n, type: typeName(lang, obj) })
  }
}

function roundHalfEven(x: number): number {
  const f = Math.floor(x)
  const d = x - f
  if (d > 0.5) return f + 1
  if (d < 0.5) return f
  return f % 2 === 0 ? f : f + 1
}

/** Python : les noms affectés dans une fonction sont locaux. */
function collectPyLocals(stmts: Stmt[], locals: Set<string>, globals: Set<string>) {
  for (const s of stmts) {
    if (s.k === 'assign' && s.target.k === 'name') locals.add(s.target.name)
    if (s.k === 'foreach') locals.add(s.varName)
    if (s.k === 'global') s.names.forEach((n) => globals.add(n))
    if (s.k === 'if') {
      collectPyLocals(s.then, locals, globals)
      if (s.else) collectPyLocals(s.else, locals, globals)
    }
    if (s.k === 'while' || s.k === 'foreach') collectPyLocals(s.body, locals, globals)
  }
  for (const g of globals) locals.delete(g)
}

/** Exécute tout le programme et retourne la liste des pas (bornée par MAX_STEPS). */
export function record(program: Program, src: string): Step[] {
  const it = new Interpreter(program, src)
  return [...it.run()]
}
