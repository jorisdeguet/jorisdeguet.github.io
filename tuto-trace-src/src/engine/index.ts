import { CompileFailure, isJs, walkStmts, type CompileError, type FuncDecl, type Lang, type Program } from './ast'
import { checkProgram } from './check'
import { buildFlow, type Construct } from './flow'
import { record, type Step } from './interpreter'
import { parseCLike } from './lang/clike'
import { checkTs, parseJs } from './lang/jslike'
import { parsePython } from './lang/python'

export type { CompileError, Lang, Program } from './ast'
export { isJs } from './ast'
export type { Step, FrameView, VarView, Fly } from './interpreter'
export type { Construct, Arc } from './flow'
export { constructAt } from './flow'

export interface Analysis {
  program: Program | null
  errors: CompileError[] // erreurs + avertissements
  flow: Map<number, Construct>
}

export function analyze(lang: Lang, src: string): Analysis {
  let program: Program | null = null
  let errors: CompileError[] = []
  try {
    if (lang === 'python') program = parsePython(src)
    else {
      const r = isJs(lang) ? parseJs(lang, src) : parseCLike(lang, src)
      program = r.program
      errors = r.errors
    }
    hoistNested(program)
    // JavaScript : aucune vérification avant l'exécution ; TypeScript : vérification de types (comme tsc)
    if (lang === 'typescript') errors = [...errors, ...checkTs(program)]
    else if (lang !== 'javascript') errors = [...errors, ...checkProgram(program)]
  } catch (e) {
    if (e instanceof CompileFailure) errors = [...errors, e.err]
    else throw e
  }
  errors.sort((a, b) => a.span.start - b.span.start)
  // une même erreur ne doit apparaître qu'une fois
  errors = errors.filter((e, i) => i === 0 || e.code !== errors[i - 1].code || e.span.start !== errors[i - 1].span.start)
  return { program, errors, flow: program ? buildFlow(program) : new Map() }
}

/** Fonctions locales (C#) / imbriquées (Dart) : visibles comme les autres. */
function hoistNested(p: Program) {
  const add = (f: FuncDecl) => {
    if (!p.funcs.has(f.name)) p.funcs.set(f.name, f)
  }
  if (p.lang === 'python') return
  walkStmts(p.body, (s) => s.k === 'func' && add(s))
  for (const f of [...p.funcs.values()]) walkStmts(f.body, (s) => s.k === 'func' && add(s))
}

export function hasBlockingErrors(a: Analysis): boolean {
  return !a.program || a.errors.some((e) => e.severity === 'error')
}

export function trace(a: Analysis, src: string): Step[] {
  if (!a.program) return []
  return record(a.program, src)
}
