// Vérification statique (« compilation ») pour C# et Dart.
import { typeStr, type CompileError, type Expr, type FuncDecl, type Lang, type Program, type Span, type Stmt, type TypeRef } from './ast'

// Types internes simplifiés
type T = string // 'int' | 'double' | 'string' | 'bool' | 'char' | 'void' | 'null' | 'list<int>' | 'array<int>' | '?' (inconnu)

interface VarInfo {
  type: T
  final: boolean
  assigned: boolean
  span: Span
}

const STRING: Record<Lang, string> = { python: 'str', csharp: 'string', dart: 'String' }

export class Checker {
  errors: CompileError[] = []
  scopes: Map<string, VarInfo>[] = []
  globals = new Map<string, VarInfo>()
  fn: FuncDecl | null = null
  loopDepth = 0

  constructor(public program: Program) {}

  get lang() {
    return this.program.lang
  }

  error(code: string, span: Span, params: Record<string, string | number> = {}) {
    this.errors.push({ code, span, params, severity: 'error' })
  }
  warn(code: string, span: Span, params: Record<string, string | number> = {}) {
    this.errors.push({ code, span, params, severity: 'warning' })
  }

  /** Nom affiché d'un type interne. */
  show(t: T): string {
    if (t.startsWith('list<')) return `List<${this.show(t.slice(5, -1))}>`
    if (t.startsWith('array<')) return `${this.show(t.slice(6, -1))}[]`
    if (t === 'string') return STRING[this.lang]
    if (t === 'null') return 'null'
    return t
  }

  fromRef(r: TypeRef | null, span: Span): T {
    if (!r) return '?'
    if (r.array) return `array<${this.fromRef({ name: r.name }, span)}>`
    switch (r.name) {
      case 'int':
      case 'long':
        return 'int'
      case 'double':
      case 'float':
      case 'decimal':
        return 'double'
      case 'num':
        return 'num'
      case 'bool':
        return 'bool'
      case 'char':
        return this.lang === 'csharp' ? 'char' : this.unknownType(r, span)
      case 'void':
        return 'void'
      case 'dynamic':
      case 'object':
      case 'Object':
      case 'var':
        return '?'
      case 'List':
        return `list<${r.args?.[0] ? this.fromRef(r.args[0], span) : '?'}>`
      case 'string':
        if (this.lang === 'dart') return this.unknownType(r, span)
        return 'string'
      case 'String':
        return 'string'
    }
    return this.unknownType(r, span)
  }

  unknownType(r: TypeRef, span: Span): T {
    const hints: Record<string, string> = { string: 'String', Int: 'int', Double: 'double', Bool: 'bool', boolean: 'bool', Boolean: 'bool', integer: 'int', str: STRING[this.lang], float: 'double' }
    this.error('type.unknown', span, { name: typeStr(r), hint: hints[r.name] ?? '' })
    return '?'
  }

  // ---------- Compatibilité ----------
  assignable(target: T, value: T): boolean {
    if (target === '?' || value === '?') return true
    if (target === value) return true
    if (target === 'double' && value === 'int') return true
    if (target === 'num' && (value === 'int' || value === 'double')) return true
    if (value === 'null') return false
    if (this.lang === 'csharp' && target === 'int' && value === 'char') return true
    const inner = (t: string) => t.slice(t.indexOf('<') + 1, -1)
    if (target.startsWith('list<') && value.startsWith('list<')) return inner(value) === '?' || inner(target) === '?' || inner(target) === inner(value) || (inner(target) === 'double' && inner(value) === 'int' && this.lang !== 'dart')
    if (target.startsWith('array<') && value.startsWith('array<')) return inner(value) === '?' || inner(target) === inner(value)
    return false
  }

  isNum(t: T) {
    return t === 'int' || t === 'double' || t === 'num' || t === '?'
  }

  // ---------- Portées ----------
  lookup(name: string): VarInfo | undefined {
    for (let i = this.scopes.length - 1; i >= 0; i--) {
      const v = this.scopes[i].get(name)
      if (v) return v
    }
    return this.globals.get(name)
  }

  declare(name: string, info: VarInfo) {
    // C# interdit de redéclarer un nom déjà visible dans la méthode ; Dart seulement dans le même bloc
    const top = this.scopes[this.scopes.length - 1]
    const clash = this.lang === 'csharp' ? this.scopes.some((s) => s.has(name)) : top.has(name)
    if (clash) this.error('var.redeclared', info.span, { name })
    top.set(name, info)
  }

  withScope<R>(f: () => R): R {
    this.scopes.push(new Map())
    try {
      return f()
    } finally {
      this.scopes.pop()
    }
  }

  // ---------- Programme ----------
  check(): CompileError[] {
    const p = this.program
    // globales (Dart top-level, champs static C#, ou instructions top-level C#)
    this.scopes.push(this.globals)
    for (const s of p.body) this.stmt(s)
    for (const f of p.funcs.values()) this.func(f)
    this.scopes.pop()
    if (p.mainName) {
      const main = p.funcs.get(p.mainName)!
      if (p.lang === 'dart' && main.params.length) this.warn('dart.mainParams', main.headSpan)
    }
    return this.errors
  }

  func(f: FuncDecl) {
    const prevFn = this.fn
    this.fn = f
    const saved = this.scopes
    this.scopes = [this.globals, new Map()]
    for (const p of f.params) {
      if (!p.type && this.lang === 'csharp') this.error('param.noType', p.span, { name: p.name })
      this.declare(p.name, { type: this.fromRef(p.type, p.span), final: false, assigned: true, span: p.span })
    }
    const fallsThrough = this.block(f.body, false)
    const ret = this.fromRef(f.ret, f.headSpan)
    if (fallsThrough && ret !== 'void' && ret !== '?' && f.ret)
      this.error('func.missingReturn', { ...f.headSpan }, { name: f.name, type: this.show(ret) })
    this.scopes = saved
    this.fn = prevFn
  }

  /** Vérifie un bloc ; retourne true si la fin du bloc peut être atteinte. */
  block(stmts: Stmt[], newScope = true): boolean {
    const run = () => {
      let reachable = true
      for (const s of stmts) {
        if (!reachable) {
          this.warn('stmt.unreachable', s.span)
          reachable = true
        }
        reachable = this.stmt(s)
      }
      return reachable
    }
    return newScope ? this.withScope(run) : run()
  }

  /** Retourne true si l'instruction peut « tomber » vers la suivante. */
  stmt(s: Stmt): boolean {
    switch (s.k) {
      case 'decl': {
        let t = s.type ? this.fromRef(s.type, s.span) : '?'
        if (s.init) {
          const vt = this.expr(s.init, t)
          if (!s.type) {
            if (vt === 'null') this.error('var.nullInfer', s.span, { name: s.name })
            t = vt === 'void' ? '?' : vt
          } else this.checkAssign(t, vt, s.init.span, s.name)
        } else if (!s.type) {
          if (this.lang === 'csharp') this.error('var.needsInit', s.span, { name: s.name })
        } else if (s.final && this.lang === 'dart' && this.scopes.length > 1) {
          // final sans init : autorisé si affecté plus tard
        }
        const nullable = !!s.type?.nullable
        this.declare(s.name, { type: t, final: s.final, assigned: !!s.init || nullable, span: s.nameSpan })
        return true
      }
      case 'assign': {
        const vt = this.expr(s.value)
        if (s.target.k === 'name') {
          const v = this.lookup(s.target.name)
          if (!v) {
            this.error('var.undeclared', s.target.span, { name: s.target.name, hint: this.declHint(s.target.name, vt) })
            return true
          }
          if (v.final) this.error('var.final', s.target.span, { name: s.target.name })
          if (s.op === '=') {
            this.checkAssign(v.type, vt, s.value.span, s.target.name)
            v.assigned = true
          } else {
            if (!v.assigned) this.error('var.unassigned', s.target.span, { name: s.target.name })
            const res = this.binType(s.op.slice(0, -1), v.type, vt, s.span)
            this.checkAssign(v.type, res, s.value.span, s.target.name)
          }
        } else {
          const et = this.expr(s.target)
          this.checkAssign(et, vt, s.value.span, this.srcName(s.target))
        }
        return true
      }
      case 'incdec': {
        const t = this.expr(s.target)
        if (!this.isNum(t)) this.error('op.badOperand', s.span, { op: s.op, type: this.show(t) })
        if (s.target.k === 'name') {
          const v = this.lookup(s.target.name)
          if (v?.final) this.error('var.final', s.target.span, { name: s.target.name })
        }
        return true
      }
      case 'expr': {
        const t = this.expr(s.e)
        if (s.e.k !== 'call' && s.e.k !== 'mcall' && this.lang === 'csharp') this.error('stmt.notStatement', s.span)
        void t
        return true
      }
      case 'if': {
        this.cond(s.cond)
        const a = this.block(s.then)
        const b = s.else ? this.block(s.else, !(s.else.length === 1 && s.else[0].k === 'if')) : true
        // affectation définie : on ne la suit pas finement à travers les branches
        return a || b
      }
      case 'while':
      case 'dowhile': {
        this.cond(s.cond)
        this.loopDepth++
        this.block(s.body)
        this.loopDepth--
        return !(s.cond.k === 'bool' && s.cond.v && !containsBreak(s.body))
      }
      case 'for':
        return this.withScope(() => {
          if (s.init) this.stmt(s.init)
          if (s.cond) this.cond(s.cond)
          if (s.update) this.stmt(s.update)
          this.loopDepth++
          this.block(s.body)
          this.loopDepth--
          return true
        })
      case 'foreach':
        return this.withScope(() => {
          const it = this.expr(s.iter)
          let elem: T = '?'
          if (it.startsWith('list<') || it.startsWith('array<')) elem = it.slice(it.indexOf('<') + 1, -1)
          else if (it === 'string') elem = this.lang === 'csharp' ? 'char' : '?'
          else if (it !== '?') this.error('foreach.notIterable', s.iter.span, { type: this.show(it) })
          const declared = s.varType ? this.fromRef(s.varType, s.varSpan) : elem
          if (s.varType) this.checkAssign(declared, elem, s.varSpan, s.varName)
          this.declare(s.varName, { type: declared, final: false, assigned: true, span: s.varSpan })
          this.loopDepth++
          this.block(s.body)
          this.loopDepth--
          return true
        })
      case 'return': {
        if (!this.fn) {
          if (s.e) this.expr(s.e)
          return false
        }
        const rt = this.fromRef(this.fn.ret, this.fn.headSpan)
        if (s.e) {
          const vt = this.expr(s.e, rt)
          if (rt === 'void') this.error('return.inVoid', s.span, { name: this.fn.name })
          else if (this.fn.ret && !this.assignable(rt, vt)) this.error('return.type', s.e.span, { expected: this.show(rt), found: this.show(vt), name: this.fn.name })
        } else if (rt !== 'void' && rt !== '?' && this.fn.ret) this.error('return.missingValue', s.span, { type: this.show(rt) })
        return false
      }
      case 'break':
      case 'continue':
        if (!this.loopDepth) this.error('stmt.breakOutside', s.span, { kw: s.k })
        return false
      case 'block':
        return this.block(s.body)
      case 'func':
        // fonctions locales : hissées dans program.funcs et vérifiées séparément
        return true
      default:
        return true
    }
  }

  srcName(e: Expr): string {
    if (e.k === 'name') return e.name
    if (e.k === 'index') return this.srcName(e.obj) + '[…]'
    return '…'
  }

  declHint(name: string, vt: T): string {
    const t = vt === '?' || vt === 'void' ? 'var' : this.show(vt)
    return `${t} ${name}`
  }

  checkAssign(target: T, value: T, span: Span, name: string) {
    if (value === 'void') {
      this.error('expr.voidValue', span)
      return
    }
    if (value === 'null' && target !== '?') {
      this.error('type.nullNotAllowed', span, { name, type: this.show(target) })
      return
    }
    if (!this.assignable(target, value)) {
      const code = target === 'int' && value === 'double' ? 'type.doubleToInt' : 'type.mismatch'
      this.error(code, span, { name, expected: this.show(target), found: this.show(value) })
    }
  }

  cond(e: Expr) {
    const t = this.expr(e)
    if (t !== 'bool' && t !== '?') this.error('cond.notBool', e.span, { type: this.show(t) })
  }

  // ---------- Expressions ----------
  expr(e: Expr, hint: T = '?'): T {
    switch (e.k) {
      case 'num':
        return e.isInt ? 'int' : 'double'
      case 'str':
        return e.char ? 'char' : 'string'
      case 'istr':
        for (const p of e.parts) if (typeof p !== 'string') this.expr(p)
        return 'string'
      case 'bool':
        return 'bool'
      case 'null':
        return 'null'
      case 'name': {
        const v = this.lookup(e.name)
        if (!v) {
          if (this.program.funcs.has(e.name)) return '?'
          this.error('var.undeclared', e.span, { name: e.name, hint: '' })
          return '?'
        }
        if (!v.assigned) this.error('var.unassigned', e.span, { name: e.name })
        return v.type
      }
      case 'bin': {
        if (e.op === 'and' || e.op === 'or') {
          for (const side of [e.l, e.r]) {
            const t = this.expr(side)
            if (t !== 'bool' && t !== '?') this.error('op.logicNotBool', side.span, { op: e.op === 'and' ? '&&' : '||', type: this.show(t) })
          }
          return 'bool'
        }
        const l = this.expr(e.l)
        const r = this.expr(e.r)
        return this.binType(e.op, l, r, e.span)
      }
      case 'un': {
        const t = this.expr(e.e)
        if (e.op === 'not') {
          if (t !== 'bool' && t !== '?') this.error('op.badOperand', e.span, { op: '!', type: this.show(t) })
          return 'bool'
        }
        if (!this.isNum(t)) this.error('op.badOperand', e.span, { op: e.op, type: this.show(t) })
        return t
      }
      case 'tern': {
        this.cond(e.c)
        const a = this.expr(e.a)
        const b = this.expr(e.b)
        if (a === b) return a
        if (this.isNum(a) && this.isNum(b)) return 'double'
        return '?'
      }
      case 'list': {
        const decl = e.elemType ? this.fromRef(e.elemType, e.span) : hint.includes('<') ? hint.slice(hint.indexOf('<') + 1, -1) : '?'
        let elem = decl
        for (const it of e.items) {
          const t = this.expr(it)
          if (decl !== '?') this.checkAssign(decl, t, it.span, '[…]')
          else if (elem === '?') elem = t
          else if (elem !== t) elem = this.isNum(elem) && this.isNum(t) ? 'double' : '?'
        }
        if (this.lang === 'csharp' && e.ctor !== 'list' && !hint.startsWith('array<') && !hint.startsWith('list<')) {
          if (e.ctor === 'array' || hint === '?') this.error('csharp.arrayInitNeedsType', e.span)
        }
        if (e.ctor === 'array' || hint.startsWith('array<')) return `array<${elem}>`
        return `list<${elem}>`
      }
      case 'newArr': {
        const st = this.expr(e.size)
        if (st !== 'int' && st !== '?') this.error('array.sizeNotInt', e.size.span, { type: this.show(st) })
        return `array<${this.fromRef(e.elemType, e.span)}>`
      }
      case 'cast': {
        const t = this.expr(e.e)
        const to = this.fromRef(e.type, e.span)
        if (!(this.isNum(t) || t === 'char') || !(this.isNum(to) || to === 'char')) this.error('cast.invalid', e.span, { from: this.show(t), to: this.show(to) })
        return to
      }
      case 'index': {
        const o = this.expr(e.obj)
        const i = this.expr(e.idx)
        if (i !== 'int' && i !== '?') this.error('index.notInt', e.idx.span, { type: this.show(i) })
        if (o.startsWith('list<') || o.startsWith('array<')) return o.slice(o.indexOf('<') + 1, -1)
        if (o === 'string') return this.lang === 'csharp' ? 'char' : 'string'
        if (o !== '?') this.error('index.notIndexable', e.obj.span, { type: this.show(o) })
        return '?'
      }
      case 'member':
        return this.member(e)
      case 'call':
        return this.call(e)
      case 'mcall':
        return this.mcall(e)
    }
  }

  binType(op: string, l: T, r: T, span: Span): T {
    const lang = this.lang
    const bad = () => {
      this.error(lang === 'dart' && op === '+' && (l === 'string' || r === 'string') ? 'dart.stringPlus' : 'op.badOperands', span, { op, left: this.show(l), right: this.show(r) })
      return '?'
    }
    if (l === '?' || r === '?') return ['==', '!=', '<', '>', '<=', '>='].includes(op) ? 'bool' : '?'
    if (l === 'void' || r === 'void') {
      this.error('expr.voidValue', span)
      return '?'
    }
    switch (op) {
      case '==':
      case '!=':
        if (this.isNum(l) && this.isNum(r)) return 'bool'
        if (l !== r && l !== 'null' && r !== 'null' && lang === 'csharp') bad()
        return 'bool'
      case '<':
      case '>':
      case '<=':
      case '>=':
        if ((this.isNum(l) && this.isNum(r)) || (l === 'char' && r === 'char')) return 'bool'
        bad()
        return 'bool'
      case '+':
        if (this.isNum(l) && this.isNum(r)) return l === 'int' && r === 'int' ? 'int' : 'double'
        if (l === 'string' && r === 'string') return 'string'
        if (lang === 'csharp' && (l === 'string' || r === 'string')) return 'string'
        if (lang === 'csharp' && (l === 'char' || r === 'char') && (this.isNum(l) || l === 'char') && (this.isNum(r) || r === 'char')) return 'int'
        return bad()
      case '*':
        if (this.isNum(l) && this.isNum(r)) return l === 'int' && r === 'int' ? 'int' : 'double'
        if (lang === 'dart' && l === 'string' && r === 'int') return 'string'
        return bad()
      case '-':
      case '%':
        if (this.isNum(l) && this.isNum(r)) return l === 'int' && r === 'int' ? 'int' : 'double'
        return bad()
      case '/':
        if (this.isNum(l) && this.isNum(r)) {
          if (lang === 'dart') return 'double'
          if (l === 'int' && r === 'int') {
            this.warn('csharp.intDivision', span)
            return 'int'
          }
          return 'double'
        }
        return bad()
      case '~/':
        if (this.isNum(l) && this.isNum(r)) return 'int'
        return bad()
    }
    return bad()
  }

  member(e: Extract<Expr, { k: 'member' }>): T {
    const o = this.expr(e.obj)
    const n = e.name
    const lang = this.lang
    if (o === '?') return '?'
    if (lang === 'csharp') {
      if (o.startsWith('array<') && n === 'Length') return 'int'
      if (o.startsWith('list<') && n === 'Count') return 'int'
      if (o === 'string' && n === 'Length') return 'int'
      if (o.startsWith('array<') && n === 'Count') return this.memberErr(e, o, 'Length')
      if (o.startsWith('list<') && n === 'Length') return this.memberErr(e, o, 'Count')
      if (o === 'string' && n === 'length') return this.memberErr(e, o, 'Length')
    } else {
      if ((o.startsWith('list<') || o === 'string') && n === 'length') return 'int'
      if ((o.startsWith('list<') || o === 'string') && (n === 'isEmpty' || n === 'isNotEmpty')) return 'bool'
      if (o.startsWith('list<') && (n === 'first' || n === 'last')) return o.slice(5, -1)
      if ((o.startsWith('list<') || o === 'string') && (n === 'Length' || n === 'Count' || n === 'size')) return this.memberErr(e, o, 'length')
    }
    return this.memberErr(e, o, '')
  }

  memberErr(e: { span: Span; name: string }, o: T, hint: string): T {
    this.error('member.unknown', e.span, { name: e.name, type: this.show(o), hint })
    return '?'
  }

  call(e: Extract<Expr, { k: 'call' }>): T {
    const lang = this.lang
    const argTypes = e.args.map((a) => this.expr(a))
    if (lang === 'dart' && e.name === 'print') {
      if (e.args.length !== 1) this.error('call.argCount', e.span, { name: 'print', expected: 1, given: e.args.length })
      if (argTypes[0] === 'void') this.error('expr.voidValue', e.args[0].span)
      return 'void'
    }
    const f = this.program.funcs.get(e.name)
    if (!f) {
      const hint = lang === 'csharp' && e.name === 'print' ? 'Console.WriteLine' : lang === 'csharp' && e.name.toLowerCase() === 'writeline' ? 'Console.WriteLine' : ''
      const near = [...this.program.funcs.keys()].find((k) => k.toLowerCase() === e.name.toLowerCase())
      this.error('call.unknown', e.nameSpan, { name: e.name, hint: hint || near || '' })
      return '?'
    }
    if (f.params.length !== e.args.length) this.error('call.argCount', e.span, { name: e.name, expected: f.params.length, given: e.args.length })
    f.params.forEach((p, i) => {
      if (i >= argTypes.length || !p.type) return
      const pt = this.fromRefQuiet(p.type)
      if (argTypes[i] === 'void') this.error('expr.voidValue', e.args[i].span)
      else if (!this.assignable(pt, argTypes[i]))
        this.error('call.argType', e.args[i].span, { name: e.name, param: p.name, expected: this.show(pt), found: this.show(argTypes[i]) })
    })
    return f.ret ? this.fromRefQuiet(f.ret) : '?'
  }

  fromRefQuiet(r: TypeRef): T {
    const n = this.errors.length
    const t = this.fromRef(r, { start: 0, end: 0, line: 1, endLine: 1 })
    this.errors.length = n
    return t
  }

  mcall(e: Extract<Expr, { k: 'mcall' }>): T {
    const lang = this.lang
    const n = e.name
    if (e.obj.k === 'name' && !this.lookup(e.obj.name)) {
      const cls = e.obj.name
      const argTypes = e.args.map((a) => this.expr(a))
      if (lang === 'csharp' && cls === 'Console') {
        if (n === 'WriteLine' || n === 'Write') {
          if (argTypes.length > 1) this.error('call.argCount', e.span, { name: `Console.${n}`, expected: 1, given: argTypes.length })
          if (argTypes[0] === 'void') this.error('expr.voidValue', e.args[0].span)
          return 'void'
        }
        if (n === 'ReadLine') {
          this.error('runtime.noInput', e.span)
          return 'string'
        }
        const near = ['WriteLine', 'Write'].find((k) => k.toLowerCase() === n.toLowerCase())
        this.error('member.unknown', e.span, { name: n, type: 'Console', hint: near ?? '' })
        return '?'
      }
      if (lang === 'csharp' && cls === 'Math') {
        const ok: Record<string, T> = { Max: '*', Min: '*', Abs: '*', Sqrt: 'double', Pow: 'double', Floor: 'double', Round: 'double' }
        if (!ok[n]) return this.memberErr(e, 'Math', '')
        if (ok[n] === '*') return argTypes.every((t) => t === 'int') ? 'int' : 'double'
        return ok[n]
      }
      if ((cls === 'int' || cls === 'double') && (n === 'Parse' || n === 'parse')) return cls
      if (lang === 'csharp' && cls === 'console') {
        this.error('call.unknown', e.obj.span, { name: `${cls}.${n}`, hint: 'Console' })
        return '?'
      }
      if (this.program.funcs.has(cls)) return '?'
      this.error('var.undeclared', e.obj.span, { name: cls, hint: '' })
      return '?'
    }
    const o = this.expr(e.obj)
    const argTypes = e.args.map((a) => this.expr(a))
    if (o === '?') return '?'
    const isList = o.startsWith('list<')
    const elem = isList || o.startsWith('array<') ? o.slice(o.indexOf('<') + 1, -1) : '?'
    const expectArgs = (k: number) => {
      if (argTypes.length !== k) this.error('call.argCount', e.span, { name: n, expected: k, given: argTypes.length })
    }
    if (isList) {
      if ((lang === 'csharp' && n === 'Add') || (lang === 'dart' && n === 'add')) {
        expectArgs(1)
        if (argTypes[0]) this.checkAssign(elem, argTypes[0], e.args[0].span, this.srcName(e.obj))
        return 'void'
      }
      if ((lang === 'csharp' && n === 'RemoveAt') || (lang === 'dart' && n === 'removeAt')) return lang === 'csharp' ? 'void' : elem
      if (lang === 'dart' && n === 'removeLast') return elem
      if ((lang === 'csharp' && n === 'Insert') || (lang === 'dart' && n === 'insert')) return 'void'
      if ((lang === 'csharp' && n === 'Contains') || (lang === 'dart' && n === 'contains')) return 'bool'
      const hint = lang === 'csharp' ? ({ add: 'Add', append: 'Add', push: 'Add' } as Record<string, string>)[n] : ({ Add: 'add', append: 'add', push: 'add' } as Record<string, string>)[n]
      return this.memberErr(e, o, hint ?? '')
    }
    if (o.startsWith('array<') && lang === 'csharp' && (n === 'Add' || n === 'Append')) {
      this.error('csharp.arrayFixed', e.span, { name: this.srcName(e.obj) })
      return '?'
    }
    if (o === 'string') {
      const m: Record<string, T> =
        lang === 'csharp'
          ? { ToUpper: 'string', ToLower: 'string', Trim: 'string', Contains: 'bool', Substring: 'string', ToString: 'string' }
          : { toUpperCase: 'string', toLowerCase: 'string', trim: 'string', contains: 'bool', substring: 'string', toString: 'string' }
      if (m[n]) return m[n]
    }
    if ((lang === 'csharp' && n === 'ToString') || (lang === 'dart' && n === 'toString')) return 'string'
    if (lang === 'dart' && this.isNum(o)) {
      const m: Record<string, T> = { toInt: 'int', toDouble: 'double', abs: o, round: 'int', toStringAsFixed: 'string' }
      if (m[n]) return m[n]
    }
    const near = lang === 'csharp' && /^[a-z]/.test(n) ? n[0].toUpperCase() + n.slice(1) : lang === 'dart' && /^[A-Z]/.test(n) ? n[0].toLowerCase() + n.slice(1) : ''
    return this.memberErr(e, o, near)
  }
}

function containsBreak(stmts: Stmt[]): boolean {
  for (const s of stmts) {
    if (s.k === 'break' || s.k === 'return') return true
    if (s.k === 'if' && (containsBreak(s.then) || (s.else && containsBreak(s.else)))) return true
    if (s.k === 'block' && containsBreak(s.body)) return true
  }
  return false
}

export function checkProgram(p: Program): CompileError[] {
  if (p.lang === 'python') return []
  return new Checker(p).check()
}
