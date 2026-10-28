// Chemins possibles (arcs de contrôle) de chaque structure, pour les flèches dessinées sur le code.
import type { Program, Stmt } from './ast'

export type ArcKind = 'true' | 'false' | 'back' | 'skip'

export interface Arc {
  from: number // ligne
  to: number | null // null = fin de la fonction / du programme
  kind: ArcKind
}

export interface Construct {
  id: number
  kind: 'while' | 'dowhile' | 'for' | 'foreach' | 'if' | 'func'
  headLine: number
  endLine: number
  arcs: Arc[]
}

function firstLine(s: Stmt): number {
  if (s.k === 'block') return s.body[0] ? firstLine(s.body[0]) : s.span.line
  return s.span.line
}

export function buildFlow(p: Program): Map<number, Construct> {
  const out = new Map<number, Construct>()
  const bodyFirst = (b: Stmt[], fallback: number) => (b[0] ? firstLine(b[0]) : fallback)

  const walk = (stmts: Stmt[], after: number | null) => {
    stmts.forEach((s, i) => {
      const next = stmts[i + 1] ? firstLine(stmts[i + 1]) : after
      switch (s.k) {
        case 'while':
        case 'for':
        case 'foreach': {
          const h = s.headSpan.line
          out.set(s.id, {
            id: s.id,
            kind: s.k,
            headLine: h,
            endLine: s.endLine,
            arcs: [
              { from: h, to: bodyFirst(s.body, h), kind: 'true' },
              { from: h, to: next, kind: 'false' },
              { from: s.endLine, to: h, kind: 'back' },
            ],
          })
          walk(s.body, h)
          break
        }
        case 'dowhile': {
          const c = s.condSpan.line
          out.set(s.id, {
            id: s.id,
            kind: 'dowhile',
            headLine: s.headSpan.line,
            endLine: c,
            arcs: [
              { from: c, to: bodyFirst(s.body, s.headSpan.line), kind: 'back' },
              { from: c, to: next, kind: 'false' },
            ],
          })
          walk(s.body, c)
          break
        }
        case 'if': {
          const h = s.headSpan.line
          const arcs: Arc[] = [{ from: h, to: bodyFirst(s.then, h), kind: 'true' }]
          if (s.else) {
            const elseTarget = s.else.length === 1 && s.else[0].k === 'if' ? s.else[0].headSpan.line : s.elseLine ?? bodyFirst(s.else, h)
            arcs.push({ from: h, to: elseTarget, kind: 'false' })
            const thenEnd = s.elseLine ? s.elseLine - 1 : h
            arcs.push({ from: Math.max(h, thenEnd), to: next, kind: 'skip' })
          } else arcs.push({ from: h, to: next, kind: 'false' })
          out.set(s.id, { id: s.id, kind: 'if', headLine: h, endLine: s.endLine, arcs })
          walk(s.then, next)
          if (s.else) walk(s.else, next)
          break
        }
        case 'block':
          walk(s.body, next)
          break
        case 'func':
          out.set(s.id, { id: s.id, kind: 'func', headLine: s.headSpan.line, endLine: s.endLine, arcs: [] })
          walk(s.body, null)
          break
      }
    })
  }
  walk(p.body, null)
  for (const f of p.funcs.values()) if (!out.has(f.id)) {
    out.set(f.id, { id: f.id, kind: 'func', headLine: f.headSpan.line, endLine: f.endLine, arcs: [] })
    walk(f.body, null)
  }
  return out
}

/** Structure de contrôle la plus interne qui contient la ligne (hors fonctions). */
export function constructAt(flow: Map<number, Construct>, line: number): Construct | undefined {
  let best: Construct | undefined
  for (const c of flow.values()) {
    if (c.kind === 'func') continue
    if (line >= c.headLine && line <= c.endLine) {
      if (!best || c.headLine >= best.headLine) best = c
    }
  }
  return best
}
