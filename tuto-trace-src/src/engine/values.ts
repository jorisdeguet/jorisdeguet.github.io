import { isJs, type Lang } from './ast'

export type Value =
  | { k: 'int'; v: number }
  | { k: 'double'; v: number }
  | { k: 'str'; v: string }
  | { k: 'char'; v: string }
  | { k: 'bool'; v: boolean }
  | { k: 'null' }
  | { k: 'undef' } // JavaScript : undefined
  | { k: 'list'; items: Value[]; id: number; elem?: string; array?: boolean }
  | { k: 'range'; start: number; stop: number; step: number }

export const NULL: Value = { k: 'null' }
export const UNDEF: Value = { k: 'undef' }
export const int = (v: number): Value => ({ k: 'int', v })
export const dbl = (v: number): Value => ({ k: 'double', v })
export const str = (v: string): Value => ({ k: 'str', v })
export const bool = (v: boolean): Value => ({ k: 'bool', v })

let listIds = 1
export function list(items: Value[], elem?: string, array = false): Value {
  return { k: 'list', items, id: listIds++, elem, array }
}

function fmtDouble(lang: Lang, v: number): string {
  if (isJs(lang)) return String(v) // 3.5, 2, Infinity, NaN
  if (Number.isNaN(v)) return lang === 'python' ? 'nan' : 'NaN'
  if (!Number.isFinite(v)) {
    if (lang === 'python') return v > 0 ? 'inf' : '-inf'
    if (lang === 'csharp') return v > 0 ? '∞' : '-∞'
    return v > 0 ? 'Infinity' : '-Infinity'
  }
  if (lang === 'csharp') {
    // C# affiche 3.0 comme "3" et limite à ~15 chiffres significatifs
    return String(Number(v.toPrecision(15)))
  }
  if (Number.isInteger(v) && Math.abs(v) < 1e16) return v.toFixed(1)
  return String(v)
}

/** Représentation d'une valeur telle qu'écrite dans le code (pour la pile et la trace). */
export function repr(lang: Lang, v: Value): string {
  switch (v.k) {
    case 'int':
      return String(v.v)
    case 'double':
      return fmtDouble(lang, v.v)
    case 'str':
      return lang === 'python' ? pyStrRepr(v.v) : JSON.stringify(v.v)
    case 'char':
      return `'${v.v}'`
    case 'bool':
      return lang === 'python' ? (v.v ? 'True' : 'False') : v.v ? 'true' : 'false'
    case 'null':
      return lang === 'python' ? 'None' : 'null'
    case 'undef':
      return 'undefined'
    case 'list':
      if (lang === 'csharp') return (v.array ? '{' : '[') + v.items.map((x) => repr(lang, x)).join(', ') + (v.array ? '}' : ']')
      return '[' + v.items.map((x) => repr(lang, x)).join(', ') + ']'
    case 'range':
      return v.step === 1 ? `range(${v.start}, ${v.stop})` : `range(${v.start}, ${v.stop}, ${v.step})`
  }
}

function pyStrRepr(s: string): string {
  const q = s.includes("'") && !s.includes('"') ? '"' : "'"
  return q + s.replace(/\\/g, '\\\\').replace(/\n/g, '\\n').replace(/\t/g, '\\t') + q
}

const CS_TYPE: Record<string, string> = { int: 'System.Int32', double: 'System.Double', string: 'System.String', bool: 'System.Boolean', char: 'System.Char' }

/** Texte produit par print / Console.WriteLine. */
export function display(lang: Lang, v: Value): string {
  if (isJs(lang)) return jsInspect(v, true)
  switch (v.k) {
    case 'str':
    case 'char':
      return v.v
    case 'bool':
      if (lang === 'csharp') return v.v ? 'True' : 'False'
      return repr(lang, v)
    case 'null':
      return lang === 'csharp' ? '' : repr(lang, v)
    case 'list':
      if (lang === 'csharp') {
        const t = CS_TYPE[v.elem ?? 'int'] ?? 'System.Object'
        return v.array ? `${t}[]` : `System.Collections.Generic.List\`1[${t}]`
      }
      if (lang === 'dart') return '[' + v.items.map((x) => display(lang, x)).join(', ') + ']'
      return repr(lang, v)
    default:
      return repr(lang, v)
  }
}

/** JavaScript : ce qu'affiche console.log (Node). Les chaînes dans un tableau sont entre apostrophes. */
function jsInspect(v: Value, top: boolean): string {
  switch (v.k) {
    case 'str':
    case 'char':
      if (top) return v.v
      return v.v.includes("'") && !v.v.includes('"') ? `"${v.v}"` : `'${v.v.replace(/'/g, "\\'")}'`
    case 'list':
      return v.items.length ? '[ ' + v.items.map((x) => jsInspect(x, false)).join(', ') + ' ]' : '[]'
    default:
      return repr('javascript', v)
  }
}

/** JavaScript : conversion en chaîne (concaténation `"x" + v`, gabarit `${v}`). */
export function jsToString(v: Value): string {
  switch (v.k) {
    case 'str':
    case 'char':
      return v.v
    case 'list':
      return v.items.map((x) => (x.k === 'null' || x.k === 'undef' ? '' : jsToString(x))).join(',')
    default:
      return repr('javascript', v)
  }
}

/** Nom du type à l'exécution, dans le vocabulaire du langage. */
export function typeName(lang: Lang, v: Value): string {
  const names: Record<Lang, Record<string, string>> = {
    python: { int: 'int', double: 'float', str: 'str', char: 'str', bool: 'bool', null: 'NoneType', list: 'list', range: 'range' },
    csharp: { int: 'int', double: 'double', str: 'string', char: 'char', bool: 'bool', null: 'null', list: 'List', range: 'range' },
    dart: { int: 'int', double: 'double', str: 'String', char: 'String', bool: 'bool', null: 'Null', list: 'List', range: 'range' },
    javascript: { int: 'number', double: 'number', str: 'string', char: 'string', bool: 'boolean', null: 'null', undef: 'undefined', list: 'Array', range: 'range' },
    typescript: { int: 'number', double: 'number', str: 'string', char: 'string', bool: 'boolean', null: 'null', undef: 'undefined', list: 'Array', range: 'range' },
  }
  if (v.k === 'list' && lang === 'typescript') return `${v.elem ?? 'any'}[]`
  if (v.k === 'list' && lang !== 'python' && !isJs(lang)) return v.array ? `${v.elem ?? 'int'}[]` : `List<${v.elem ?? 'dynamic'}>`
  return names[lang][v.k]
}

export function truthy(v: Value): boolean {
  switch (v.k) {
    case 'bool':
      return v.v
    case 'int':
    case 'double':
      return v.v !== 0 && !Number.isNaN(v.v)
    case 'str':
    case 'char':
      return v.v.length > 0
    case 'null':
    case 'undef':
      return false
    case 'list':
      return v.items.length > 0
    case 'range':
      return rangeLen(v) > 0
  }
}

export function rangeLen(r: { start: number; stop: number; step: number }): number {
  const n = Math.ceil((r.stop - r.start) / r.step)
  return Math.max(0, n)
}

export function valueEquals(a: Value, b: Value): boolean {
  if ((a.k === 'int' || a.k === 'double') && (b.k === 'int' || b.k === 'double')) return a.v === b.v
  if ((a.k === 'str' || a.k === 'char') && (b.k === 'str' || b.k === 'char')) return a.v === b.v
  if (a.k === 'bool' && b.k === 'bool') return a.v === b.v
  if (a.k === 'null' && b.k === 'null') return true
  if (a.k === 'undef' && b.k === 'undef') return true
  if (a.k === 'list' && b.k === 'list') return a.items.length === b.items.length && a.items.every((x, i) => valueEquals(x, b.items[i]))
  return false
}
