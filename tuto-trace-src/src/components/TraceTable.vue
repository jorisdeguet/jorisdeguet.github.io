<script setup lang="ts">
// Tableau de trace : une ligne par pas, une colonne par variable.
// On lit verticalement la succession des valeurs de chaque variable au fil du temps.
// Trois présentations (`format`) :
// - default : #, ligne, contexte, variables, événement, affichage ;
// - sn : gabarit du cours 420-SN1 (ligne, portées et variables, affichage, pile d'appels, fonction appelée, valeur retournée) ;
// - mobile : ligne, variables, puis une seule colonne pour l'appel, le retour ou l'affichage.
import { computed, nextTick, ref, watch } from 'vue'
import type { TraceFormat } from '../composables/useUrlState'
import type { Lang, Step } from '../engine'
import { t, tr } from '../i18n'
import { frameHue, summary } from '../summary'

const props = defineProps<{ steps: Step[]; cur: number; format: TraceFormat; lang: Lang }>()
const emit = defineEmits<{ goto: [number] }>()

interface Col {
  key: string
  fn: string // '' = contexte global
  name: string
}

interface Cell {
  text: string
  type?: string
  frameId: number
  changed: boolean
}

const box = ref<HTMLElement>()
const shown = computed(() => props.steps.slice(0, props.cur + 1))

// Les colonnes apparaissent quand la variable est créée (pas de spoiler sur la suite).
// Les variables d'une même portée restent contiguës : portées dans l'ordre d'apparition,
// variables dans l'ordre de création à l'intérieur de chaque portée.
const cols = computed<Col[]>(() => {
  const scopes = new Map<string, Map<string, Col>>()
  for (const s of shown.value)
    for (const f of s.frames) {
      const fn = f.global ? '' : f.fn
      let scope = scopes.get(fn)
      for (const v of f.vars) {
        if (!scope) scopes.set(fn, (scope = new Map()))
        if (!scope.has(v.name)) scope.set(v.name, { key: `${fn}:${v.name}`, fn, name: v.name })
      }
    }
  return [...scopes.values()].flatMap((m) => [...m.values()])
})

const multiCtx = computed(() => cols.value.some((c) => c.fn !== ''))
const sn = computed(() => props.format === 'sn')
const mobile = computed(() => props.format === 'mobile')
// le gabarit SN identifie toujours les portées, même avec le seul contexte global
const showGroups = computed(() => multiCtx.value || (sn.value && cols.value.length > 0))

// Groupes de colonnes par contexte, pour l'en-tête
const groups = computed(() => {
  const out: { fn: string; span: number }[] = []
  for (const c of cols.value) {
    const last = out[out.length - 1]
    if (last && last.fn === c.fn) last.span++
    else out.push({ fn: c.fn, span: 1 })
  }
  return out
})

/** Valeur de la colonne au pas `s` : celle du contexte le plus récent de cette fonction. */
function cell(s: Step, c: Col): Cell | null {
  const frames = s.frames.filter((f) => (c.fn === '' ? f.global : !f.global && f.fn === c.fn))
  for (let i = frames.length - 1; i >= 0; i--) {
    const v = frames[i].vars.find((x) => x.name === c.name)
    if (!v) continue
    return {
      text: v.unset ? '?' : v.text,
      type: v.type,
      frameId: frames[i].id,
      changed: s.changed?.frameId === frames[i].id && s.changed.name === c.name,
    }
  }
  return null
}

// Au-delà, seules les dernières lignes sont affichées (boucles longues)
const MAX_ROWS = 400

interface RowCell {
  cell: Cell
  isNew: boolean
  /** type précédent, quand la même variable vient de changer de type (Python) */
  typeFrom?: string
}
interface Row {
  s: Step
  cells: (RowCell | null)[]
}

// Une seule passe sur tous les pas : lignes affichées + types successifs de chaque colonne
// (même pour les lignes masquées, pour que l'en-tête garde l'historique des types).
const table = computed(() => {
  const all = shown.value
  const from = Math.max(0, all.length - MAX_ROWS)
  const rows: Row[] = []
  const types: string[][] = cols.value.map(() => [])
  let prev: (Cell | null)[] = []
  for (let i = 0; i < all.length; i++) {
    const s = all[i]
    const now = cols.value.map((c) => cell(s, c))
    const cells = now.map((v, k): RowCell | null => {
      if (!v) return null
      const p = prev[k]
      if (v.type && types[k][types[k].length - 1] !== v.type) types[k].push(v.type)
      return {
        cell: v,
        // « nouveau » : affecté à ce pas, ou valeur différente du pas précédent (paramètres d'un appel…)
        isNew: v.changed || !p || p.text !== v.text || p.frameId !== v.frameId,
        // même variable (même contexte), type différent : seul Python le permet
        typeFrom: p && p.frameId === v.frameId && p.type && v.type && p.type !== v.type ? p.type : undefined,
      }
    })
    if (i >= from) rows.push({ s, cells })
    prev = now
  }
  return { rows, types }
})
const rows = computed(() => table.value.rows)
const colTypes = computed(() => table.value.types)

/** Changement de type au pas courant : bandeau d'avertissement au-dessus de la trace. */
const typeWarnings = computed(() => {
  const last = rows.value[rows.value.length - 1]
  if (!last || last.s.i !== props.cur) return []
  return last.cells.flatMap((c, k) => (c?.typeFrom ? [{ name: cols.value[k].name, from: c.typeFrom, to: c.cell.type! }] : []))
})
const hidden = computed(() => Math.max(0, shown.value.length - MAX_ROWS))

// colonnes hors variables, selon le format
const leadCols = computed(() => (props.format === 'default' ? (multiCtx.value ? 3 : 2) : 1))
const tailCols = computed(() => (sn.value ? 4 : mobile.value ? 1 : 2))

const NOTE_KINDS = new Set(['cond', 'call', 'return', 'loopBack', 'break', 'continue', 'error', 'end', 'start', 'limit', 'expr'])
const note = (s: Step) => (NOTE_KINDS.has(s.kind) ? summary(s) : '')
const output = (s: Step) => (s.kind === 'print' ? JSON.parse(String(s.params.text)) : '')

const ctxName = (s: Step) => {
  const f = s.frames.find((x) => x.id === s.frameId)
  return f?.global ? t('stack.global') : (f?.fn ?? '')
}

// --- colonnes du gabarit SN ---
/** Pile d'appels : la fonction courante en haut, la plus ancienne en bas.
 *  Un contexte global vide (C#, Dart sans variable globale) est omis dès qu'une fonction s'exécute. */
const stackNames = (s: Step) =>
  [...s.frames]
    .reverse()
    .filter((f) => !f.global || f.vars.length || s.frames.length === 1)
    .map((f) => (f.global ? t('stack.global') : f.fn))
/** Fonction appelée, avec les valeurs finales des arguments : `f(5)`. */
const called = (s: Step) => (s.kind === 'call' ? `${s.params.name}(${s.params.args})` : '')
/** Valeur retournée ; une fonction Python sans `return` explicite retourne None. */
const returned = (s: Step) => {
  if (s.kind !== 'return') return ''
  if (s.key === 'return.value' || props.lang === 'python') return String(s.params.value)
  return '—'
}

// --- colonne unique du format mobile ---
const event = (s: Step) => {
  if (s.kind === 'call') return `→ ${called(s)}`
  if (s.kind === 'return') return `← ${returned(s)}`
  if (s.kind === 'print') return `⎙ ${output(s)}`
  if (s.kind === 'error' || s.kind === 'limit') return summary(s)
  return ''
}

watch(
  () => props.cur,
  async () => {
    await nextTick()
    const el = box.value?.querySelector('tr.current') as HTMLElement | null
    el?.scrollIntoView({ block: 'nearest' })
  },
)
</script>

<template>
  <section class="panel trace">
    <h2>{{ t('panel.trace') }}</h2>
    <p v-if="!shown.length" class="empty">{{ t('trace.empty') }}</p>
    <div v-for="w in typeWarnings" :key="w.name" class="type-warning" role="alert">
      <span class="type-warning-icon" aria-hidden="true">⚠</span>
      <span v-html="tr('trace.typeChanged', { name: w.name, from: w.from, to: w.to })"></span>
    </div>
    <div v-if="shown.length" ref="box" class="trace-scroll">
      <table class="trace-table" :class="`f-${format}`">
        <thead>
          <tr v-if="showGroups" class="groups">
            <th :colspan="leadCols"></th>
            <th v-for="(g, gi) in groups" :key="gi" :colspan="g.span" class="group" :class="{ global: !g.fn }">
              {{ g.fn ? g.fn + '()' : t('stack.global') }}
            </th>
            <th :colspan="tailCols"></th>
          </tr>
          <tr class="names">
            <th v-if="format === 'default'" class="c-num">#</th>
            <th class="c-ln">{{ t('trace.line') }}</th>
            <th v-if="format === 'default' && multiCtx" class="c-ctx">{{ t('trace.context') }}</th>
            <th
              v-for="(c, k) in cols"
              :key="c.key"
              class="c-var vert"
              :class="{ 'type-changed': colTypes[k].length > 1 }"
              :title="colTypes[k].length ? `${c.name} : ${colTypes[k].join(' → ')}` : c.name"
            >
              <span class="vlabel"><span class="vname">{{ c.name }}</span><span v-if="colTypes[k].length" class="vtype"> : {{ colTypes[k].join(' → ') }}</span></span>
            </th>
            <template v-if="format === 'default'">
              <th class="c-note">{{ t('trace.event') }}</th>
              <th class="c-out">{{ t('trace.output') }}</th>
            </template>
            <template v-else-if="sn">
              <th class="c-out">{{ t('trace.output') }}</th>
              <th class="c-stack">{{ t('trace.stack') }}</th>
              <th class="c-called">{{ t('trace.called') }}</th>
              <th class="c-ret">{{ t('trace.returned') }}</th>
            </template>
            <th v-else class="c-event">{{ t('trace.mobileEvent') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="hidden" class="more">
            <td :colspan="cols.length + leadCols + tailCols">{{ t('trace.hidden', { n: hidden }) }}</td>
          </tr>
          <tr
            v-for="{ s, cells } in rows"
            :key="s.i"
            :class="[`k-${s.kind}`, { current: s.i === cur }]"
            :style="{ '--hue': frameHue(s.frameId) }"
            @click="emit('goto', s.i)"
          >
            <td v-if="format === 'default'" class="c-num">{{ s.i + 1 }}</td>
            <td class="c-ln">{{ s.line }}</td>
            <td v-if="format === 'default' && multiCtx" class="c-ctx" :style="{ paddingLeft: 6 + s.depth * 8 + 'px' }">{{ ctxName(s) }}</td>
            <td
              v-for="(v, k) in cells"
              :key="cols[k].key"
              class="c-var"
              :class="[v ? (v.isNew ? 'new' : 'same') : 'none', { 'scope-start': k === 0 || cols[k - 1].fn !== cols[k].fn, 'type-changed': v?.typeFrom }]"
              :title="v?.typeFrom ? `⚠ ${v.typeFrom} → ${v.cell.type}` : undefined"
              :data-fly-var="s.i === cur && v ? `${v.cell.frameId}:${cols[k].name}` : undefined"
            >
              <span v-if="v" :class="{ flash: s.i === cur && v.isNew }"><b v-if="v.typeFrom" class="type-flag">⚠</b>{{ v.cell.text }}</span>
            </td>
            <template v-if="format === 'default'">
              <td class="c-note">{{ note(s) }}</td>
              <td class="c-out" :data-fly-console="s.i === cur ? '' : undefined">{{ output(s) }}</td>
            </template>
            <template v-else-if="sn">
              <td class="c-out" :data-fly-console="s.i === cur ? '' : undefined">{{ output(s) }}</td>
              <td class="c-stack">
                <span v-for="(n, ni) in stackNames(s)" :key="ni" :class="{ top: ni === 0 }">{{ n }}</span>
              </td>
              <td class="c-called">{{ called(s) }}</td>
              <td class="c-ret">{{ returned(s) }}</td>
            </template>
            <td v-else class="c-event" :data-fly-console="s.i === cur && s.kind === 'print' ? '' : undefined">{{ event(s) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
