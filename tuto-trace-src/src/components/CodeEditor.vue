<script setup lang="ts">
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands'
import { python } from '@codemirror/lang-python'
import { bracketMatching, HighlightStyle, indentOnInput, indentUnit, StreamLanguage, syntaxHighlighting } from '@codemirror/language'
import { tags } from '@lezer/highlight'
import { csharp, dart } from '@codemirror/legacy-modes/mode/clike'
import { Compartment, EditorState, StateEffect, StateField, type Extension } from '@codemirror/state'
import { Decoration, EditorView, GutterMarker, gutter, keymap, lineNumbers, type DecorationSet } from '@codemirror/view'
import { onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import type { Lang, Step } from '../engine'

export interface EditorDiag {
  start: number
  end: number
  line: number
  severity: 'error' | 'warning'
  message: string
}

const props = defineProps<{
  modelValue: string
  lang: Lang
  readonly?: boolean
  step?: Step | null
  diags: EditorDiag[]
}>()
const emit = defineEmits<{ 'update:modelValue': [string]; ready: [EditorView] }>()

const host = ref<HTMLDivElement>()
const view = shallowRef<EditorView>()
const langConf = new Compartment()
const roConf = new Compartment()

function langExt(l: Lang): Extension {
  if (l === 'python') return [python(), indentUnit.of('    ')]
  if (l === 'csharp') return [StreamLanguage.define(csharp), indentUnit.of('    ')]
  return [StreamLanguage.define(dart), indentUnit.of('  ')]
}

// couleurs via variables CSS : suivent le thème clair / sombre
const highlight = HighlightStyle.define([
  { tag: [tags.keyword, tags.controlKeyword, tags.definitionKeyword, tags.modifier, tags.operatorKeyword], color: 'var(--hl-kw)' },
  { tag: [tags.string, tags.special(tags.string)], color: 'var(--hl-str)' },
  { tag: [tags.number, tags.bool, tags.null, tags.atom], color: 'var(--hl-num)' },
  { tag: [tags.comment, tags.lineComment, tags.blockComment], color: 'var(--hl-com)', fontStyle: 'italic' },
  { tag: [tags.function(tags.variableName), tags.function(tags.definition(tags.variableName))], color: 'var(--hl-fn)' },
  { tag: [tags.typeName, tags.className, tags.standard(tags.variableName)], color: 'var(--hl-type)' },
])

// ----- décorations : pas courant + erreurs -----
const setDecos = StateEffect.define<DecorationSet>()
const decoField = StateField.define<DecorationSet>({
  create: () => Decoration.none,
  update(deco, tr) {
    deco = deco.map(tr.changes)
    for (const e of tr.effects) if (e.is(setDecos)) deco = e.value
    return deco
  },
  provide: (f) => EditorView.decorations.from(f),
})

// gouttière vide qui réserve la place des flèches de chemins
class Spacer extends GutterMarker {
  toDOM() {
    const d = document.createElement('div')
    d.style.width = '84px'
    return d
  }
}
const flowGutter = gutter({ class: 'cm-flow-gutter', initialSpacer: () => new Spacer() })

function buildDecos(): DecorationSet {
  const v = view.value
  if (!v) return Decoration.none
  const doc = v.state.doc
  const clamp = (n: number) => Math.max(0, Math.min(doc.length, n))
  const ranges: { from: number; to: number; deco: Decoration }[] = []
  for (const d of props.diags) {
    const ln = doc.line(Math.min(Math.max(1, d.line), doc.lines))
    ranges.push({ from: ln.from, to: ln.from, deco: Decoration.line({ class: d.severity === 'error' ? 'cm-err-line' : 'cm-warn-line' }) })
    let from = clamp(d.start)
    let to = clamp(Math.max(d.end, d.start + 1))
    if (from >= to) {
      from = clamp(to - 1)
    }
    if (from < to)
      ranges.push({ from, to, deco: Decoration.mark({ class: d.severity === 'error' ? 'cm-err' : 'cm-warn', attributes: { title: d.message } }) })
  }
  const s = props.step
  if (s && s.line >= 1 && s.line <= doc.lines) {
    const ln = doc.line(s.line)
    const cls = s.kind === 'error' ? 'cm-step-line cm-step-error' : 'cm-step-line'
    ranges.push({ from: ln.from, to: ln.from, deco: Decoration.line({ class: cls }) })
    const from = clamp(s.span.start)
    const to = clamp(s.span.end)
    if (from < to && s.kind !== 'loopBack' && s.kind !== 'end') ranges.push({ from, to, deco: Decoration.mark({ class: 'cm-step-span' }) })
  }
  return Decoration.set(
    ranges.map((r) => r.deco.range(r.from, r.to)),
    true,
  )
}

function refresh() {
  const v = view.value
  if (!v) return
  v.dispatch({ effects: setDecos.of(buildDecos()) })
  const s = props.step
  if (s && s.line <= v.state.doc.lines) {
    const pos = v.state.doc.line(s.line).from
    v.dispatch({ effects: EditorView.scrollIntoView(pos, { y: 'nearest', yMargin: 40 }) })
  }
}

onMounted(() => {
  view.value = new EditorView({
    parent: host.value!,
    state: EditorState.create({
      doc: props.modelValue,
      extensions: [
        lineNumbers(),
        flowGutter,
        history(),
        indentOnInput(),
        bracketMatching(),
        syntaxHighlighting(highlight),
        keymap.of([...defaultKeymap, ...historyKeymap, indentWithTab]),
        langConf.of(langExt(props.lang)),
        roConf.of(EditorState.readOnly.of(!!props.readonly)),
        decoField,
        EditorView.updateListener.of((u) => {
          if (u.docChanged) emit('update:modelValue', u.state.doc.toString())
        }),
        EditorView.contentAttributes.of({ spellcheck: 'false', autocapitalize: 'off', 'aria-label': 'code' }),
      ],
    }),
  })
  emit('ready', view.value)
  refresh()
})

onBeforeUnmount(() => view.value?.destroy())

watch(
  () => props.modelValue,
  (code) => {
    const v = view.value
    if (v && code !== v.state.doc.toString()) v.dispatch({ changes: { from: 0, to: v.state.doc.length, insert: code } })
  },
)
watch(
  () => props.lang,
  (l) => view.value?.dispatch({ effects: langConf.reconfigure(langExt(l)) }),
)
watch(
  () => props.readonly,
  (r) => view.value?.dispatch({ effects: roConf.reconfigure(EditorState.readOnly.of(!!r)) }),
)
watch(() => [props.step, props.diags], refresh)

/** Déplace le curseur sur une ligne (clic sur une erreur). */
function focusLine(line: number) {
  const v = view.value
  if (!v) return
  const pos = v.state.doc.line(Math.min(line, v.state.doc.lines)).from
  v.dispatch({ selection: { anchor: pos }, effects: EditorView.scrollIntoView(pos, { y: 'center' }) })
  v.focus()
}

defineExpose({ view, focusLine })
</script>

<template>
  <div ref="host" class="code-editor"></div>
</template>
