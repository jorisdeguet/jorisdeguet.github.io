<script setup lang="ts">
import { computed } from 'vue'
import { constructAt, type Construct, type Lang, type Step } from '../engine'
import { has, locale, t, tr } from '../i18n'
import { realRuntimeMessage } from '../i18n/real'
import FlowFigure from './FlowFigure.vue'

const props = defineProps<{ step: Step | null; lang: Lang; flow: Map<number, Construct>; blocked?: boolean }>()

// erreurs Python qu'un compilateur C# / Dart aurait détectées
const PY_STATIC = new Set(['py.strConcat', 'runtime.badOperands', 'py.nameError', 'py.typeError.len'])

const text = computed(() => {
  void locale.value
  const s = props.step
  if (!s) return tr(props.blocked ? 'errors.blocking' : 'explain.empty')
  if (s.kind === 'error' && s.error) return tr('steps.error') + ' ' + tr('err.' + s.error.code, s.error.params)
  return tr('steps.' + s.key, s.params)
})

const errorInfo = computed(() => {
  void locale.value
  const s = props.step
  if (!s?.error) return null
  const fixKey = 'err.' + s.error.code + '.fix'
  return {
    real: realRuntimeMessage(props.lang, s.error.code, s.error.params),
    fix: has(fixKey) ? tr(fixKey, s.error.params) : null,
    pyNote: props.lang === 'python' && PY_STATIC.has(s.error.code) ? tr('errors.pyNoCompile') : null,
  }
})

const ctx = computed(() => {
  const s = props.step
  if (!s) return null
  const py = props.lang === 'python'
  if (s.kind === 'call' || s.kind === 'return') {
    return { fig: 'func' as const, concept: s.key === 'call.recursive' || s.depth > (s.kind === 'call' ? 0 : 1) ? 'recursion' : 'func', active: s.kind }
  }
  const c = (s.construct !== undefined ? props.flow.get(s.construct) : undefined) ?? constructAt(props.flow, s.line)
  if (!c || c.kind === 'func') return { fig: null, concept: 'sequence', active: undefined }
  const own = s.construct === c.id
  let active: string | undefined = own ? s.arc : undefined
  if (own && s.key === 'for.init') active = 'init'
  const concept =
    c.kind === 'while' ? (py ? 'while.py' : 'while.c')
    : c.kind === 'if' ? (py ? 'if.py' : 'if.c')
    : c.kind === 'for' ? 'for.c'
    : c.kind === 'foreach' ? (py ? 'for.py' : 'foreach.c')
    : 'dowhile.c'
  return { fig: c.kind, concept, active, hasElse: c.arcs.some((a) => a.kind === 'skip') }
})

const conceptText = computed(() => {
  void locale.value
  if (!ctx.value) return ''
  return tr('concepts.' + ctx.value.concept, { kw: props.lang === 'csharp' ? 'foreach' : 'for … in' })
})
</script>

<template>
  <section class="panel explain" :class="{ 'is-error': step?.kind === 'error' || step?.kind === 'limit' }">
    <h2>{{ t('panel.explain') }}</h2>
    <p class="explain-main" v-html="text"></p>
    <div v-if="errorInfo" class="explain-error">
      <pre v-if="errorInfo.real" class="real-msg">{{ errorInfo.real }}</pre>
      <p v-if="errorInfo.fix" class="hint"><strong>{{ t('errors.fix') }}</strong> <span v-html="errorInfo.fix"></span></p>
      <p v-if="errorInfo.pyNote" class="note" v-html="errorInfo.pyNote"></p>
    </div>
    <div v-if="ctx && step?.kind !== 'error'" class="concept">
      <FlowFigure v-if="ctx.fig" :kind="ctx.fig" :active="ctx.active" :has-else="ctx.hasElse" />
      <div class="concept-text">
        <h3>{{ t('explain.concept') }}</h3>
        <p v-html="conceptText"></p>
      </div>
    </div>
  </section>
</template>
