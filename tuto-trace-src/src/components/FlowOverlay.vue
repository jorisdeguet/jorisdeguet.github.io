<script setup lang="ts">
// Flèches des chemins possibles, dessinées dans la marge de l'éditeur.
import type { EditorView } from '@codemirror/view'
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { constructAt, type Arc, type Construct, type Step } from '../engine'
import { t } from '../i18n'

const props = defineProps<{
  view?: EditorView
  wrap?: HTMLElement
  flow: Map<number, Construct>
  step: Step | null
}>()

const tick = ref(0)
const bump = () => tick.value++
let ro: ResizeObserver | null = null
let scroller: HTMLElement | null = null

watch(
  () => props.view,
  (v, _, onCleanup) => {
    if (!v) return
    scroller = v.scrollDOM
    scroller.addEventListener('scroll', bump, { passive: true })
    ro = new ResizeObserver(bump)
    ro.observe(v.dom)
    onCleanup(() => {
      scroller?.removeEventListener('scroll', bump)
      ro?.disconnect()
    })
    requestAnimationFrame(bump)
  },
  { immediate: true },
)
onBeforeUnmount(() => {
  scroller?.removeEventListener('scroll', bump)
  ro?.disconnect()
})

const current = computed<Construct | undefined>(() => {
  const s = props.step
  if (!s) return undefined
  const byId = s.construct !== undefined ? props.flow.get(s.construct) : undefined
  if (byId && byId.kind !== 'func') return byId
  return constructAt(props.flow, s.line)
})

interface Drawn {
  d: string
  cls: string
  label?: { x: number; y: number; text: string; rotate?: boolean; anchor?: string }
  key: string
}

const geometry = computed(() => {
  void tick.value
  void props.step
  const v = props.view
  const wrap = props.wrap
  if (!v || !wrap) return null
  const g = v.dom.querySelector('.cm-flow-gutter') as HTMLElement | null
  if (!g) return null
  const wr = wrap.getBoundingClientRect()
  const gr = g.getBoundingClientRect()
  const sr = v.scrollDOM.getBoundingClientRect()
  const doc = v.state.doc
  const lh = v.defaultLineHeight
  const yOf = (line: number) => {
    const n = Math.min(Math.max(1, line), doc.lines)
    const b = v.lineBlockAt(doc.line(n).from)
    return b.top + v.documentTop - wr.top + b.height / 2 + (line > doc.lines ? lh : 0)
  }
  // abscisse du premier caractère non blanc de la ligne (null si la ligne n'est pas affichée)
  const xIndent = (line: number) => {
    if (line < 1 || line > doc.lines) return null
    const l = doc.line(line)
    const c = v.coordsAtPos(l.from + /^\s*/.exec(l.text)![0].length)
    return c ? c.left - wr.left : null
  }
  // abscisse de la fin du texte de la ligne
  const xEnd = (line: number) => {
    if (line < 1 || line > doc.lines) return null
    const l = doc.line(line)
    const c = v.coordsAtPos(l.from + l.text.trimEnd().length)
    return c ? c.left - wr.left : null
  }
  return { left: gr.left - wr.left, right: gr.right - wr.left, top: sr.top - wr.top, height: sr.height, width: wr.width, yOf, xIndent, xEnd, lh, cw: v.defaultCharacterWidth }
})

function arcPath(x1: number, y1: number, xl: number, y2: number, x2: number): string {
  const r = Math.min(6, Math.abs(y2 - y1) / 2)
  const dir = y2 > y1 ? 1 : -1
  return `M ${x1} ${y1} H ${xl + r} Q ${xl} ${y1} ${xl} ${y1 + dir * r} V ${y2 - dir * r} Q ${xl} ${y2} ${xl + r} ${y2} H ${x2}`
}

const drawn = computed<Drawn[]>(() => {
  const geo = geometry.value
  const c = current.value
  const s = props.step
  const out: Drawn[] = []
  if (!geo || !s) return out
  const R = geo.right - 4
  const lane: Record<Arc['kind'], number> = { true: R - 12, false: R - 30, skip: R - 30, back: R - 50 }
  if (c) {
    for (const a of c.arcs) {
      const active = s.construct === c.id && s.arc === a.kind
      const y1 = geo.yOf(a.from)
      const toEnd = a.to === null
      const y2 = toEnd ? geo.yOf(c.endLine) + geo.lh * 0.8 : geo.yOf(a.to!)
      const cls = `arc arc-${a.kind}${active ? ' active' : ''}`
      const key = `${c.id}-${a.kind}-${a.from}-${a.to}`
      const word = t('legend.' + a.kind)
      // entrée dans le corps : la flèche descend sous l'en-tête puis suit l'indentation
      const hx = a.kind === 'true' && a.to !== null && a.to > a.from ? geo.xIndent(a.from) : null
      const bx = hx !== null ? geo.xIndent(a.to!) : null
      if (hx !== null && bx !== null && bx - hx >= geo.cw * 1.5) {
        // une ligne intermédiaire (« { » en C#) occupe la colonne de l'en-tête : on passe à sa droite
        const x = hx + geo.cw * (a.to! - a.from > 1 ? 1.5 : 0.5)
        const r = Math.min(5, (bx - x) / 3)
        const y0 = y1 + geo.lh * 0.5
        out.push({
          key,
          cls,
          d: `M ${x} ${y0} V ${y2 - r} Q ${x} ${y2} ${x + r} ${y2} H ${bx - 2}`,
          label: { x: x - 4, y: y2 + 3, text: word, anchor: 'end' },
        })
        continue
      }
      // retour à l'en-tête : la flèche remonte à droite du code (boucle : descente à gauche, remontée à droite)
      if (a.kind === 'back' && a.to !== null && a.to < a.from) {
        const ends: (number | null)[] = []
        for (let l = a.to; l <= a.from; l++) ends.push(geo.xEnd(l))
        if (ends.every((e) => e !== null)) {
          const x1 = ends[ends.length - 1]! + 6
          const x2 = ends[0]! + 8
          const xl = Math.min(Math.max(...(ends as number[])) + 22, geo.width - 14)
          const r = Math.min(6, Math.abs(y1 - y2) / 2)
          out.push({
            key,
            cls,
            d: `M ${x1} ${y1} H ${xl - r} Q ${xl} ${y1} ${xl} ${y1 - r} V ${y2 + r} Q ${xl} ${y2} ${xl - r} ${y2} H ${x2}`,
            label: { x: xl + 9, y: (y1 + y2) / 2, text: word, rotate: true },
          })
          continue
        }
      }
      if (a.kind === 'true' && a.to === a.from + 1) {
        out.push({ key, cls, d: `M ${R - 6} ${y1 + 6} V ${y2 - 6}`, label: { x: R - 10, y: (y1 + y2) / 2 + 3, text: word, anchor: 'end' } })
        continue
      }
      if (a.to === a.from) continue
      const x = lane[a.kind]
      const d = toEnd ? `M ${R} ${y1} H ${x + 6} Q ${x} ${y1} ${x} ${y1 + 6} V ${y2}` : arcPath(R, y1, x, y2, R)
      // étiquette le long du segment vertical
      const mid = (y1 + y2) / 2
      const text = toEnd ? `${word} → ${t('legend.end')}` : word
      out.push({ key, cls, d, label: { x: x - 3, y: mid, text, rotate: true } })
    }
  }
  if (s.jump && s.jump.from !== s.jump.to) {
    const y1 = geo.yOf(s.jump.from)
    const y2 = geo.yOf(s.jump.to)
    const xl = R - 68
    out.push({
      key: `jump-${s.i}`,
      cls: `arc arc-jump arc-${s.jump.kind} active`,
      d: arcPath(R, y1, xl, y2, R),
      label: { x: xl - 3, y: (y1 + y2) / 2, text: t('legend.' + s.jump.kind), rotate: true },
    })
  }
  return out
})
</script>

<template>
  <svg
    v-if="geometry"
    class="flow-overlay"
    :style="{ top: geometry.top + 'px', height: geometry.height + 'px' }"
    :viewBox="`0 ${geometry.top} ${geometry.width} ${geometry.height}`"
    :width="geometry.width"
    :height="geometry.height"
    aria-hidden="true"
  >
    <defs>
      <marker v-for="k in ['true', 'false', 'back', 'skip', 'jump', 'idle']" :id="`ah-${k}`" :key="k" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 0 L 10 5 L 0 10 z" :class="`ah ah-${k}`" />
      </marker>
    </defs>
    <g v-for="a in drawn" :key="a.key" :class="a.cls">
      <path :d="a.d" fill="none" :marker-end="`url(#ah-${a.cls.includes('active') ? a.cls.match(/arc-(true|false|back|skip|jump)/)?.[1] : 'idle'})`" />
      <text
        v-if="a.label"
        :x="a.label.x"
        :y="a.label.y"
        :text-anchor="a.label.rotate ? 'middle' : (a.label.anchor ?? 'start')"
        :transform="a.label.rotate ? `rotate(-90 ${a.label.x} ${a.label.y})` : undefined"
      >{{ a.label.text }}</text>
    </g>
  </svg>
</template>
