import { compressToEncodedURIComponent, decompressFromEncodedURIComponent } from 'lz-string'
import type { Lang } from '../engine'
import type { UiLang } from '../i18n'

/** Présentation de la trace : `default` (détaillée), `sn` (gabarit 420-SN1), `mobile` (étroite). */
export type TraceFormat = 'default' | 'sn' | 'mobile'
export const FORMATS: TraceFormat[] = ['default', 'sn', 'mobile']

export interface UrlState {
  lang: Lang
  ui: UiLang
  ex?: string
  code?: string
  embed: boolean
  readonly: boolean
  autoplay: boolean
  speed?: number
  step?: number
  id?: string // identifiant de l'iframe (script d'intégration)
  theme?: 'light' | 'dark'
  format: TraceFormat
}

const LANGS: Lang[] = ['python', 'csharp', 'dart']
const LANG_ALIASES: Record<string, Lang> = { py: 'python', python: 'python', cs: 'csharp', csharp: 'csharp', 'c#': 'csharp', dart: 'dart' }
const UIS: UiLang[] = ['fr', 'en', 'es']

function browserUi(): UiLang {
  const l = (navigator.language || 'fr').slice(0, 2) as UiLang
  return UIS.includes(l) ? l : 'fr'
}

export function readUrl(): UrlState {
  const p = new URLSearchParams(location.hash.replace(/^#/, ''))
  const lang = LANG_ALIASES[(p.get('lang') ?? '').toLowerCase()] ?? 'python'
  const ui = (UIS as string[]).includes(p.get('ui') ?? '') ? (p.get('ui') as UiLang) : browserUi()
  let code: string | undefined
  const c = p.get('code')
  if (c) code = decompressFromEncodedURIComponent(c) ?? undefined
  const raw = p.get('src') // code non compressé (script d'intégration, liens écrits à la main)
  if (!code && raw) code = raw
  // le format peut aussi venir d'un vrai paramètre GET (?format=sn) ; le hash a priorité
  const fmt = (p.get('format') ?? new URLSearchParams(location.search).get('format') ?? '').toLowerCase()
  const num = (k: string) => (p.get(k) !== null && !isNaN(Number(p.get(k))) ? Number(p.get(k)) : undefined)
  return {
    lang,
    ui,
    ex: p.get('ex') ?? undefined,
    code,
    embed: p.get('embed') === '1',
    readonly: p.get('readonly') === '1',
    autoplay: p.get('autoplay') === '1',
    speed: num('speed'),
    step: num('step'),
    id: p.get('id') ?? undefined,
    theme: p.get('theme') === 'dark' || p.get('theme') === 'light' ? (p.get('theme') as 'light' | 'dark') : undefined,
    format: (FORMATS as string[]).includes(fmt) ? (fmt as TraceFormat) : 'default',
  }
}

export function buildHash(s: Partial<UrlState> & { lang: Lang; ui: UiLang }): string {
  const p = new URLSearchParams()
  p.set('lang', s.lang)
  p.set('ui', s.ui)
  if (s.code !== undefined) p.set('code', compressToEncodedURIComponent(s.code))
  else if (s.ex) p.set('ex', s.ex)
  if (s.embed) p.set('embed', '1')
  if (s.readonly) p.set('readonly', '1')
  if (s.autoplay) p.set('autoplay', '1')
  if (s.speed) p.set('speed', String(s.speed))
  if (s.id) p.set('id', s.id)
  if (s.theme) p.set('theme', s.theme)
  if (s.format && s.format !== 'default') p.set('format', s.format)
  return '#' + p.toString()
}

export function writeUrl(s: Partial<UrlState> & { lang: Lang; ui: UiLang }) {
  const h = buildHash(s)
  if (h !== location.hash) history.replaceState(null, '', h)
}

export function appUrl(): string {
  return location.href.replace(/#.*$/, '')
}

export { LANGS }
