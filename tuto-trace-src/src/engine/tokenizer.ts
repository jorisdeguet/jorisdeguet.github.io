import { CompileFailure, type Lang, type Span } from './ast'

export type TokType = 'id' | 'num' | 'str' | 'istr' | 'op' | 'nl' | 'indent' | 'dedent' | 'eof'

export interface IPart {
  src: string
  start: number // offset absolu du début de l'expression
}

export interface Token {
  t: TokType
  v: string
  start: number
  end: number
  line: number
  isInt?: boolean
  num?: number
  parts?: (string | IPart)[] // chaînes interpolées
  char?: boolean // littéral caractère C#
}

/** Retrouve la ligne (1-based) d'un offset. */
export class LineMap {
  starts: number[] = [0]
  constructor(public src: string) {
    for (let i = 0; i < src.length; i++) if (src[i] === '\n') this.starts.push(i + 1)
  }
  lineOf(off: number): number {
    let lo = 0
    let hi = this.starts.length - 1
    while (lo < hi) {
      const mid = (lo + hi + 1) >> 1
      if (this.starts[mid] <= off) lo = mid
      else hi = mid - 1
    }
    return lo + 1
  }
  span(start: number, end: number): Span {
    return { start, end, line: this.lineOf(start), endLine: this.lineOf(Math.max(start, end - 1)) }
  }
  lineCount() {
    return this.starts.length
  }
}

const OPS: Record<Lang, string[]> = {
  python: ['**=', '//=', '**', '//', '==', '!=', '<=', '>=', '+=', '-=', '*=', '/=', '%=', '&&', '||', '++', '--', '->',
    '(', ')', '[', ']', '{', '}', ',', ':', '.', '+', '-', '*', '/', '%', '<', '>', '=', ';', '!'],
  csharp: ['==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '=>', '??',
    '(', ')', '[', ']', '{', '}', ',', ';', ':', '.', '+', '-', '*', '/', '%', '<', '>', '=', '!', '?'],
  dart: ['~/=', '~/', '==', '!=', '<=', '>=', '&&', '||', '++', '--', '+=', '-=', '*=', '/=', '%=', '=>', '??',
    '(', ')', '[', ']', '{', '}', ',', ';', ':', '.', '+', '-', '*', '/', '%', '<', '>', '=', '!', '?'],
}

const ESCAPES: Record<string, string> = { n: '\n', t: '\t', '\\': '\\', '"': '"', "'": "'", r: '\r', '0': '\0', $: '$', '{': '{', '}': '}' }

function fail(lm: LineMap, code: string, start: number, end: number, params: Record<string, string | number> = {}): never {
  throw new CompileFailure({ code, span: lm.span(start, end), params, severity: 'error' })
}

/**
 * Tokenise `src` (qui commence à l'offset `base` dans le source complet).
 * Pour Python, produit aussi les jetons NEWLINE / INDENT / DEDENT.
 */
export function tokenize(lang: Lang, lm: LineMap, src: string = lm.src, base = 0, layout = lang === 'python'): Token[] {
  const toks: Token[] = []
  const ops = OPS[lang]
  let i = 0
  let depth = 0 // parenthèses ouvertes (Python ignore les fins de ligne dedans)
  const indents = [0]
  let atLineStart = layout

  const push = (t: TokType, v: string, s: number, e: number, extra: Partial<Token> = {}) =>
    toks.push({ t, v, start: base + s, end: base + e, line: lm.lineOf(base + s), ...extra })

  while (i < src.length) {
    // Indentation Python
    if (atLineStart) {
      let j = i
      let width = 0
      while (j < src.length && (src[j] === ' ' || src[j] === '\t')) {
        width += src[j] === '\t' ? 4 : 1
        j++
      }
      const c = src[j]
      if (j >= src.length || c === '\n' || c === '#' || c === '\r') {
        // ligne vide ou commentaire : ignorée pour l'indentation
        while (j < src.length && src[j] !== '\n') j++
        i = j + 1
        continue
      }
      const top = indents[indents.length - 1]
      if (width > top) {
        // une indentation inattendue est signalée par le parser (meilleur contexte)
        indents.push(width)
        push('indent', '', i, j)
      } else if (width < top) {
        while (indents[indents.length - 1] > width) {
          indents.pop()
          push('dedent', '', j, j)
        }
        if (indents[indents.length - 1] !== width) fail(lm, 'py.dedentMismatch', base + i, base + j)
      }
      atLineStart = false
      i = j
      continue
    }

    const c = src[i]
    if (c === '\n') {
      if (layout && depth === 0) {
        if (toks.length && toks[toks.length - 1].t !== 'nl') push('nl', '\n', i, i + 1)
        atLineStart = true
      }
      i++
      continue
    }
    if (c === ' ' || c === '\t' || c === '\r') {
      i++
      continue
    }
    // Commentaires
    if (lang === 'python' && c === '#') {
      while (i < src.length && src[i] !== '\n') i++
      continue
    }
    if (lang !== 'python' && c === '/' && src[i + 1] === '/') {
      while (i < src.length && src[i] !== '\n') i++
      continue
    }
    if (lang !== 'python' && c === '/' && src[i + 1] === '*') {
      const e = src.indexOf('*/', i + 2)
      if (e < 0) fail(lm, 'syntax.unterminatedComment', base + i, base + i + 2)
      i = e + 2
      continue
    }
    // Nombres
    if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1] ?? ''))) {
      let j = i
      let isInt = true
      while (j < src.length && /[0-9_]/.test(src[j])) j++
      if (src[j] === '.' && /[0-9]/.test(src[j + 1] ?? '')) {
        isInt = false
        j++
        while (j < src.length && /[0-9]/.test(src[j])) j++
      }
      if (src[j] === 'e' || src[j] === 'E') {
        let k = j + 1
        if (src[k] === '+' || src[k] === '-') k++
        if (/[0-9]/.test(src[k] ?? '')) {
          isInt = false
          j = k
          while (j < src.length && /[0-9]/.test(src[j])) j++
        }
      }
      // suffixes C# (3.5d, 2f, 10m) acceptés comme double
      if (lang === 'csharp' && /[dDfFmM]/.test(src[j] ?? '')) {
        isInt = false
        j++
      }
      const text = src.slice(i, j)
      push('num', text, i, j, { isInt, num: Number(text.replace(/_/g, '').replace(/[dDfFmM]$/, '')) })
      i = j
      continue
    }
    // Chaînes (avec préfixes f"..." Python, $"..." C#)
    const isPyF = lang === 'python' && (c === 'f' || c === 'F') && (src[i + 1] === '"' || src[i + 1] === "'")
    const isCsInterp = lang === 'csharp' && c === '$' && src[i + 1] === '"'
    if (c === '"' || c === "'" || isPyF || isCsInterp) {
      const start = i
      const interp = isPyF || isCsInterp || lang === 'dart'
      if (isPyF || isCsInterp) i++
      const q = src[i]
      if (lang === 'csharp' && q === "'") {
        // littéral caractère
        let j = i + 1
        let ch = src[j]
        if (ch === '\\') {
          ch = ESCAPES[src[j + 1]] ?? src[j + 1]
          j++
        }
        if (src[j + 1] !== "'") fail(lm, 'syntax.badChar', base + start, base + j + 1)
        push('str', ch, start, j + 2, { char: true })
        i = j + 2
        continue
      }
      // triple guillemets Python
      const triple = lang === 'python' && src.startsWith(q + q + q, i)
      const qlen = triple ? 3 : 1
      let j = i + qlen
      const parts: (string | IPart)[] = []
      let cur = ''
      let closed = false
      while (j < src.length) {
        const ch = src[j]
        if (triple ? src.startsWith(q + q + q, j) : ch === q) {
          closed = true
          j += qlen
          break
        }
        if (ch === '\n' && !triple) break
        if (ch === '\\') {
          cur += ESCAPES[src[j + 1]] ?? src[j + 1]
          j += 2
          continue
        }
        if (interp && lang !== 'dart' && ch === '{') {
          if (src[j + 1] === '{') {
            cur += '{'
            j += 2
            continue
          }
          const e = matchBrace(src, j)
          if (e < 0) fail(lm, 'syntax.unterminatedString', base + start, base + j)
          if (cur) parts.push(cur)
          cur = ''
          parts.push({ src: src.slice(j + 1, e), start: base + j + 1 })
          j = e + 1
          continue
        }
        if (interp && lang !== 'dart' && ch === '}' && src[j + 1] === '}') {
          cur += '}'
          j += 2
          continue
        }
        if (lang === 'dart' && ch === '$') {
          if (src[j + 1] === '{') {
            const e = matchBrace(src, j + 1)
            if (e < 0) fail(lm, 'syntax.unterminatedString', base + start, base + j)
            if (cur) parts.push(cur)
            cur = ''
            parts.push({ src: src.slice(j + 2, e), start: base + j + 2 })
            j = e + 1
            continue
          }
          const m = /^[A-Za-z_][A-Za-z0-9_]*/.exec(src.slice(j + 1))
          if (m) {
            if (cur) parts.push(cur)
            cur = ''
            parts.push({ src: m[0], start: base + j + 1 })
            j += 1 + m[0].length
            continue
          }
        }
        cur += ch
        j++
      }
      if (!closed) fail(lm, 'syntax.unterminatedString', base + start, base + j)
      if (cur || parts.length === 0) parts.push(cur)
      const hasExpr = parts.some((p) => typeof p !== 'string')
      if (hasExpr) push('istr', src.slice(start, j), start, j, { parts })
      else push('str', parts.join(''), start, j)
      i = j
      continue
    }
    // Identifiants
    if (/[A-Za-z_]/.test(c)) {
      let j = i + 1
      while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++
      push('id', src.slice(i, j), i, j)
      i = j
      continue
    }
    // Opérateurs
    const op = ops.find((o) => src.startsWith(o, i))
    if (op) {
      if (op === '(' || op === '[' || op === '{') depth++
      if (op === ')' || op === ']' || op === '}') depth = Math.max(0, depth - 1)
      push('op', op, i, i + op.length)
      i += op.length
      continue
    }
    fail(lm, 'syntax.unexpectedChar', base + i, base + i + 1, { char: c })
  }
  if (layout) {
    if (toks.length && toks[toks.length - 1].t !== 'nl') push('nl', '\n', src.length, src.length)
    while (indents.length > 1) {
      indents.pop()
      push('dedent', '', src.length, src.length)
    }
  }
  push('eof', '', src.length, src.length)
  return toks
}

function matchBrace(src: string, open: number): number {
  let d = 0
  for (let k = open; k < src.length; k++) {
    if (src[k] === '{') d++
    else if (src[k] === '}') {
      d--
      if (d === 0) return k
    } else if (src[k] === '\n') return -1
  }
  return -1
}
