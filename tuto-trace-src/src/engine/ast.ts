// AST commun aux trois langages (Python, C#, Dart).
// Les positions sont des offsets absolus dans le source + numéros de lignes (1-based).

export type Lang = 'python' | 'csharp' | 'dart'

export interface Span {
  start: number
  end: number
  line: number
  endLine: number
}

export interface TypeRef {
  name: string // int, double, string, String, bool, List, var, void, char...
  args?: TypeRef[] // List<int>
  array?: boolean // int[]
  nullable?: boolean
}

export function typeStr(t: TypeRef | null | undefined): string {
  if (!t) return 'var'
  let s = t.name
  if (t.args && t.args.length) s += '<' + t.args.map(typeStr).join(', ') + '>'
  if (t.array) s += '[]'
  if (t.nullable) s += '?'
  return s
}

export type Expr =
  | { k: 'num'; v: number; isInt: boolean; span: Span }
  | { k: 'str'; v: string; char?: boolean; span: Span }
  | { k: 'istr'; parts: (string | Expr)[]; span: Span }
  | { k: 'bool'; v: boolean; span: Span }
  | { k: 'null'; span: Span }
  | { k: 'name'; name: string; span: Span }
  | { k: 'bin'; op: string; l: Expr; r: Expr; span: Span }
  | { k: 'un'; op: string; e: Expr; span: Span }
  | { k: 'call'; name: string; args: Expr[]; span: Span; nameSpan: Span }
  | { k: 'mcall'; obj: Expr; name: string; args: Expr[]; span: Span }
  | { k: 'member'; obj: Expr; name: string; span: Span }
  | { k: 'index'; obj: Expr; idx: Expr; span: Span }
  | { k: 'list'; items: Expr[]; elemType?: TypeRef; ctor?: 'array' | 'list'; span: Span }
  | { k: 'newArr'; elemType: TypeRef; size: Expr; span: Span }
  | { k: 'cast'; type: TypeRef; e: Expr; span: Span }
  | { k: 'tern'; c: Expr; a: Expr; b: Expr; span: Span }

export interface Param {
  name: string
  type: TypeRef | null
  span: Span
}

interface StmtBase {
  span: Span
  id: number
}

export type Stmt =
  | (StmtBase & { k: 'decl'; type: TypeRef | null; name: string; init: Expr | null; final: boolean; nameSpan: Span })
  | (StmtBase & { k: 'assign'; target: Expr; op: string; value: Expr })
  | (StmtBase & { k: 'incdec'; target: Expr; op: '++' | '--' })
  | (StmtBase & { k: 'expr'; e: Expr })
  | (StmtBase & { k: 'if'; cond: Expr; then: Stmt[]; else: Stmt[] | null; headSpan: Span; elseLine?: number; endLine: number; isElif?: boolean })
  | (StmtBase & { k: 'while'; cond: Expr; body: Stmt[]; headSpan: Span; endLine: number })
  | (StmtBase & { k: 'dowhile'; cond: Expr; body: Stmt[]; headSpan: Span; condSpan: Span; endLine: number })
  | (StmtBase & { k: 'for'; init: Stmt | null; cond: Expr | null; update: Stmt | null; body: Stmt[]; headSpan: Span; endLine: number })
  | (StmtBase & { k: 'foreach'; varName: string; varType: TypeRef | null; iter: Expr; body: Stmt[]; headSpan: Span; varSpan: Span; endLine: number })
  | (StmtBase & { k: 'return'; e: Expr | null })
  | (StmtBase & { k: 'break' })
  | (StmtBase & { k: 'continue' })
  | (StmtBase & { k: 'pass' })
  | (StmtBase & { k: 'global'; names: string[] })
  | (StmtBase & { k: 'block'; body: Stmt[]; endLine: number })
  | FuncDecl

export interface FuncDecl extends StmtBase {
  k: 'func'
  name: string
  params: Param[]
  ret: TypeRef | null
  body: Stmt[]
  headSpan: Span
  endLine: number
  isStatic?: boolean
}

export interface Program {
  lang: Lang
  body: Stmt[] // instructions de premier niveau (Python, C# top-level, globales Dart)
  funcs: Map<string, FuncDecl>
  entry: 'top' | 'main'
  mainName?: string // Main (C#) ou main (Dart)
  lineCount: number
}

export interface CompileError {
  code: string
  span: Span
  params: Record<string, string | number>
  severity: 'error' | 'warning'
}

export class CompileFailure extends Error {
  constructor(public err: CompileError) {
    super(err.code)
  }
}

export function joinSpan(a: Span, b: Span): Span {
  return { start: a.start, end: b.end, line: a.line, endLine: b.endLine }
}

/** Enfants « blocs » d'une instruction, pour les parcours génériques. */
export function childBlocks(s: Stmt): Stmt[][] {
  switch (s.k) {
    case 'if':
      return s.else ? [s.then, s.else] : [s.then]
    case 'while':
    case 'dowhile':
    case 'for':
    case 'foreach':
    case 'func':
    case 'block':
      return [s.body]
    default:
      return []
  }
}

export function walkStmts(stmts: Stmt[], f: (s: Stmt) => void) {
  for (const s of stmts) {
    f(s)
    if (s.k === 'for') {
      if (s.init) f(s.init)
      if (s.update) f(s.update)
    }
    for (const b of childBlocks(s)) walkStmts(b, f)
  }
}
