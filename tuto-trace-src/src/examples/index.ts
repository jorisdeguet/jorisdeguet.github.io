import type { Lang } from '../engine'

export interface ExampleGroup {
  id: string // clé i18n : groups.<id>
  items: string[] // clé i18n : examples.<id>
}

// Même série d'exemples pour les trois langages (certains n'existent que pour un langage).
export const GROUPS: ExampleGroup[] = [
  { id: 'sequence', items: ['variables', 'swap'] },
  { id: 'if', items: ['if-simple', 'if-else', 'if-elif'] },
  { id: 'while', items: ['fact-loop', 'while-counter', 'while-sum', 'while-search'] },
  { id: 'for', items: ['for-range', 'for-each', 'for-nested', 'list-ops'] },
  { id: 'functions', items: ['func-simple', 'func-chain', 'func-recursion'] },
  { id: 'errors', items: ['err-type', 'err-undeclared', 'err-semicolon', 'err-indent', 'err-runtime'] },
]

export const EXT: Record<Lang, string> = { python: 'py', csharp: 'cs', dart: 'dart' }

const files = import.meta.glob('./*/*.{py,cs,dart}', { query: '?raw', import: 'default', eager: true }) as Record<string, string>

export function getExample(lang: Lang, id: string): string | undefined {
  return files[`./${lang}/${id}.${EXT[lang]}`]
}

export function hasExample(lang: Lang, id: string): boolean {
  return getExample(lang, id) !== undefined
}

export const DEFAULT_EXAMPLE = 'fact-loop'
