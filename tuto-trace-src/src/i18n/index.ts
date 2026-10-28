import { ref } from 'vue'
import en from './en'
import es from './es'
import fr from './fr'

export type UiLang = 'fr' | 'en' | 'es'
export const UI_LANGS: { id: UiLang; label: string; short: string }[] = [
  { id: 'fr', label: 'Français', short: 'FR' },
  { id: 'en', label: 'English', short: 'EN' },
  { id: 'es', label: 'Español', short: 'ES' },
]

const messages: Record<UiLang, typeof fr> = { fr, en, es }
export const locale = ref<UiLang>('fr')

type Params = Record<string, string | number | undefined>

function lookup(dict: unknown, key: string): string | undefined {
  // les clés de feuilles peuvent contenir des points (ex. err['syntax.expected'])
  const [head, ...rest] = key.split('.')
  const section = (dict as Record<string, unknown>)[head]
  if (section && typeof section === 'object' && rest.length) {
    const leaf = (section as Record<string, unknown>)[rest.join('.')]
    if (typeof leaf === 'string') return leaf
    return lookup(section, rest.join('.'))
  }
  return typeof section === 'string' && !rest.length ? section : undefined
}

export function has(key: string): boolean {
  return lookup(messages[locale.value], key) !== undefined
}

/** Traduit une clé ; les {params} sont remplacés. */
export function t(key: string, params: Params = {}): string {
  const raw = lookup(messages[locale.value], key) ?? lookup(messages.fr, key) ?? key
  return raw.replace(/\{(\w+)\}/g, (m, k) => (params[k] !== undefined ? String(params[k]) : m))
}

function esc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

/** Texte enrichi : `code` et **gras**. Le texte est échappé avant mise en forme. */
export function rich(s: string): string {
  return esc(s)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
}

export function tr(key: string, params: Params = {}): string {
  return rich(t(key, params))
}
