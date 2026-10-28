<script setup lang="ts">
// Tableau de trace : une ligne par pas, une colonne par variable.
// On lit verticalement la succession des valeurs de chaque variable au fil du temps.
import { computed, nextTick, ref, watch } from 'vue'
import type { Step } from '../engine'
import { t } from '../i18n'
import { frameHue, summary } from '../summary'

const props = defineProps<{ steps: Step[]; cur: number }>()
const emit = defineEmits<{ goto: [number] }>()

interface Col {
  key: string
  fn: string // '' = contexte global
  name: string
}

interface Cell {
  text: string
  frameId: number
  changed: boolean
}

const box = ref<HTMLElement>()
const shown = computed(() => props.steps.slice(0, props.cur + 1))

// Les colonnes apparaissent quand la variable est créée (pas de spoiler sur la suite).
const cols = computed<Col[]>(() => {
  const seen = new Map<string, Col>()
  for (const s of shown.value)
    for (const f of s.frames)
      for (const v of f.vars) {
        const fn = f.global ? '' : f.fn
        const key = `${fn}:${v.name}`
        if (!seen.has(key)) seen.set(key, { key, fn, name: v.name })
      }
  return [...seen.values()]
})

const multiCtx = computed(() => cols.value.some((c) => c.fn !== ''))

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
      frameId: frames[i].id,
      changed: s.changed?.frameId === frames[i].id && s.changed.name === c.name,
    }
  }
  return null
}

// Au-delà, seules les dernières lignes sont affichées (boucles longues)
const MAX_ROWS = 400

interface Row {
  s: Step
  cells: ({ cell: Cell; isNew: boolean } | null)[]
}

const rows = computed<Row[]>(() => {
  const all = shown.value
  const from = Math.max(0, all.length - MAX_ROWS)
  const out: Row[] = []
  let prev: (Cell | null)[] = from > 0 ? cols.value.map((c) => cell(all[from - 1], c)) : []
  for (let i = from; i < all.length; i++) {
    const s = all[i]
    const now = cols.value.map((c) => cell(s, c))
    out.push({
      s,
      // « nouveau » : affecté à ce pas, ou valeur différente du pas précédent (paramètres d'un appel…)
      cells: now.map((v, k) => (v ? { cell: v, isNew: v.changed || !prev[k] || prev[k]!.text !== v.text || prev[k]!.frameId !== v.frameId } : null)),
    })
    prev = now
  }
  return out
})
const hidden = computed(() => Math.max(0, shown.value.length - MAX_ROWS))

const NOTE_KINDS = new Set(['cond', 'call', 'return', 'loopBack', 'break', 'continue', 'error', 'end', 'start', 'def', 'limit', 'expr'])
const note = (s: Step) => (NOTE_KINDS.has(s.kind) ? summary(s) : '')
const output = (s: Step) => (s.kind === 'print' ? JSON.parse(String(s.params.text)) : '')

const ctxName = (s: Step) => {
  const f = s.frames.find((x) => x.id === s.frameId)
  return f?.global ? t('stack.global') : (f?.fn ?? '')
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
    <div v-else ref="box" class="trace-scroll">
      <table class="trace-table">
        <thead>
          <tr v-if="multiCtx" class="groups">
            <th :colspan="multiCtx ? 3 : 2"></th>
            <th v-for="(g, gi) in groups" :key="gi" :colspan="g.span" class="group" :class="{ global: !g.fn }">
              {{ g.fn ? g.fn + '()' : t('stack.global') }}
            </th>
            <th colspan="2"></th>
          </tr>
          <tr>
            <th class="c-num">#</th>
            <th class="c-ln">{{ t('trace.line') }}</th>
            <th v-if="multiCtx" class="c-ctx">{{ t('trace.context') }}</th>
            <th v-for="c in cols" :key="c.key" class="c-var">{{ c.name }}</th>
            <th class="c-note">{{ t('trace.event') }}</th>
            <th class="c-out">{{ t('trace.output') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="hidden" class="more">
            <td :colspan="cols.length + (multiCtx ? 5 : 4)">{{ t('trace.hidden', { n: hidden }) }}</td>
          </tr>
          <tr
            v-for="{ s, cells } in rows"
            :key="s.i"
            :class="[`k-${s.kind}`, { current: s.i === cur }]"
            :style="{ '--hue': frameHue(s.frameId) }"
            @click="emit('goto', s.i)"
          >
            <td class="c-num">{{ s.i + 1 }}</td>
            <td class="c-ln">{{ s.line }}</td>
            <td v-if="multiCtx" class="c-ctx" :style="{ paddingLeft: 6 + s.depth * 8 + 'px' }">{{ ctxName(s) }}</td>
            <td
              v-for="(v, k) in cells"
              :key="cols[k].key"
              class="c-var"
              :class="v ? (v.isNew ? 'new' : 'same') : 'none'"
              :data-fly-var="s.i === cur && v ? `${v.cell.frameId}:${cols[k].name}` : undefined"
            >
              <span v-if="v" :class="{ flash: s.i === cur && v.isNew }">{{ v.cell.text }}</span>
            </td>
            <td class="c-note">{{ note(s) }}</td>
            <td class="c-out" :data-fly-console="s.i === cur ? '' : undefined">{{ output(s) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
