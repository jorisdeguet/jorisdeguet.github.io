// Résumé court d'un pas, pour la trace.
import type { Step } from './engine'

export function summary(s: Step): string {
  const p = s.params
  switch (s.kind) {
    case 'start':
      return p.name ? `▶ ${p.name}()` : '▶'
    case 'decl':
      return p.value === '?' ? `${p.type} ${p.name}` : `${p.type} ${p.name} = ${p.value}`
    case 'assign':
      if (s.key === 'assign.index') return `${p.name}[${p.index}] = ${p.value}`
      return `${p.name} = ${p.value}`
    case 'incdec':
      return `${p.name} = ${p.value}`
    case 'forUpdate':
      return `${p.name} = ${p.value}`
    case 'cond':
      if (s.key === 'foreach.done') return `${p.iter} ✓`
      return p.vals ? `${p.cond} → ${p.vals} → ${p.value}` : `${p.cond} → ${p.value}`
    case 'forNext':
      return `${p.name} = ${p.value}`
    case 'loopBack':
      return `↩ L${p.line}`
    case 'call':
      return `→ ${p.name}(${p.passing ?? p.args})`
    case 'return':
      return s.key === 'return.value' ? `← ${p.value}` : `← ${p.name}`
    case 'print':
      return `⎙ ${p.text}`
    case 'mutate':
      return s.key === 'list.add' ? `${p.name} += ${p.value}` : s.key === 'list.remove' ? `${p.name} −= ${p.value}` : `${p.name}[${p.index}] ⇐ ${p.value}`
    case 'expr':
      return s.key === 'pass' ? 'pass' : `${p.value}`
    case 'break':
      return 'break'
    case 'continue':
      return 'continue'
    case 'error':
      return `✖ ${s.error?.code ?? ''}`
    case 'limit':
      return '∞'
    case 'end':
      return '■'
  }
  return ''
}

/** Couleur stable par contexte d'appel. */
export function frameHue(id: number): number {
  return (id * 67 + 200) % 360
}
