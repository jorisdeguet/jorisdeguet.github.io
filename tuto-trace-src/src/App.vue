<script setup lang="ts">
import type { EditorView } from '@codemirror/view'
import { computed, nextTick, onBeforeUnmount, onMounted, ref, shallowRef, watch } from 'vue'
import CallStack from './components/CallStack.vue'
import CodeEditor, { type EditorDiag } from './components/CodeEditor.vue'
import CompileErrors from './components/CompileErrors.vue'
import ConsolePanel from './components/ConsolePanel.vue'
import ExamplePicker from './components/ExamplePicker.vue'
import ExplainPanel from './components/ExplainPanel.vue'
import FlowOverlay from './components/FlowOverlay.vue'
import PickerMenu, { type PickerOption } from './components/PickerMenu.vue'
import PlayControls from './components/PlayControls.vue'
import ShareDialog from './components/ShareDialog.vue'
import TraceTable from './components/TraceTable.vue'
import { useEmbedResize } from './composables/useEmbedResize'
import { flyStep } from './composables/useFly'
import { forceTheme, theme, toggleTheme } from './composables/useTheme'
import { appUrl, buildHash, readUrl, writeUrl } from './composables/useUrlState'
import { analyze, hasBlockingErrors, trace, type Analysis, type Lang, type Step } from './engine'
import { DEFAULT_EXAMPLE, getExample, hasExample } from './examples'
import { locale, t, UI_LANGS, type UiLang } from './i18n'

const LANG_OPTIONS: PickerOption[] = [
  { id: 'python', label: 'Python', badge: 'Py' },
  { id: 'csharp', label: 'C#', badge: 'C#' },
  { id: 'dart', label: 'Dart', badge: 'Dt' },
]
const UI_OPTIONS: PickerOption[] = UI_LANGS.map((l) => ({ id: l.id, label: l.label, badge: l.short }))

// ---------- état initial depuis le lien ----------
const url = readUrl()
locale.value = url.ui
const lang = ref<Lang>(url.lang)
const exId = ref<string>(url.code !== undefined ? 'custom' : url.ex && hasExample(url.lang, url.ex) ? url.ex : DEFAULT_EXAMPLE)
const code = ref<string>(url.code ?? getExample(lang.value, exId.value) ?? '')
const speed = ref<number>(Math.min(10, Math.max(0.5, url.speed ?? 2)))
const embed = url.embed
const readonly = url.readonly
const showShare = ref(false)

useEmbedResize(embed, url.id)
if (url.theme) forceTheme(url.theme)

// ---------- panneaux flottants (explication, pile, console) ----------
type PanelId = 'explain' | 'stack' | 'console'
const PANELS_KEY = 'tuto-trace:panels'
function storedPanels(): PanelId[] {
  try {
    return JSON.parse(localStorage.getItem(PANELS_KEY) ?? '[]')
  } catch {
    return []
  }
}
const openPanels = ref<PanelId[]>(storedPanels())
const isOpen = (p: PanelId) => openPanels.value.includes(p)
function togglePanel(p: PanelId) {
  openPanels.value = isOpen(p) ? openPanels.value.filter((x) => x !== p) : [...openPanels.value, p]
  try {
    localStorage.setItem(PANELS_KEY, JSON.stringify(openPanels.value))
  } catch {
    /* stockage indisponible */
  }
}

// code mémorisé par langage, pour revenir sans perdre ses modifications
const memory = new Map<Lang, { code: string; exId: string }>()

const view = shallowRef<EditorView>()
const wrap = ref<HTMLElement>()
const editor = ref<InstanceType<typeof CodeEditor>>()

// ---------- analyse + exécution ----------
const analysis = shallowRef<Analysis>({ program: null, errors: [], flow: new Map() })
const steps = shallowRef<Step[]>([])
const cur = ref(-1)
const blocking = computed(() => hasBlockingErrors(analysis.value))

let analyzed = { lang: '', code: '' }
function recompute() {
  if (analyzed.lang === lang.value && analyzed.code === code.value) return
  analyzed = { lang: lang.value, code: code.value }
  stop()
  analysis.value = analyze(lang.value, code.value)
  steps.value = hasBlockingErrors(analysis.value) ? [] : trace(analysis.value, code.value)
  cur.value = -1
}

let debounce: number | undefined
watch(code, () => {
  clearTimeout(debounce)
  debounce = window.setTimeout(recompute, 300)
})

const step = computed<Step | null>(() => (cur.value >= 0 ? (steps.value[cur.value] ?? null) : null))

const diags = computed<EditorDiag[]>(() => {
  void locale.value
  return analysis.value.errors.map((e) => ({
    start: e.span.start,
    end: e.span.end,
    line: e.span.line,
    severity: e.severity,
    message: t('err.' + e.code, e.params),
  }))
})

const status = computed(() => {
  void locale.value
  if (blocking.value) return { text: t('status.compile'), kind: 'bad' }
  const s = step.value
  if (!s) return { text: t('status.ready'), kind: '' }
  if (s.kind === 'error') return { text: t('status.error'), kind: 'bad' }
  if (s.kind === 'limit') return { text: t('status.limit'), kind: 'bad' }
  if (s.kind === 'end') return { text: t('status.done'), kind: 'good' }
  return { text: t('status.running'), kind: 'run' }
})

// ---------- navigation ----------
const playing = ref(false)
let timer: number | undefined
const interval = computed(() => 1000 / speed.value)

async function goto(i: number, animate = false) {
  const n = steps.value.length
  if (!n) return
  cur.value = Math.max(-1, Math.min(i, n - 1))
  if (animate && step.value) {
    await nextTick()
    flyStep(view.value, step.value, Math.max(250, Math.min(800, interval.value * 0.9)))
  }
}
const next = () => goto(cur.value + 1, true)
const back = () => goto(cur.value - 1)
const reset = () => {
  stop()
  goto(-1)
}
const toEnd = () => {
  stop()
  goto(steps.value.length - 1)
}

function stop() {
  playing.value = false
  clearTimeout(timer)
}
function tick() {
  if (!playing.value) return
  if (cur.value >= steps.value.length - 1) return stop()
  next()
  timer = window.setTimeout(tick, interval.value)
}
function toggle() {
  if (playing.value) return stop()
  if (blocking.value || !steps.value.length) return
  if (cur.value >= steps.value.length - 1) cur.value = -1
  playing.value = true
  tick()
}

recompute()
if (url.step !== undefined) cur.value = Math.min(url.step, steps.value.length - 1)

// ---------- exemples et langages ----------
function loadExample(id: string) {
  const src = getExample(lang.value, id)
  if (src === undefined) return
  exId.value = id
  code.value = src
}
function onCodeEdit(v: string) {
  code.value = v
  if (exId.value !== 'custom' && v !== getExample(lang.value, exId.value)) exId.value = 'custom'
}
watch(lang, (l, old) => {
  memory.set(old, { code: code.value, exId: exId.value })
  const saved = memory.get(l)
  if (saved) {
    code.value = saved.code
    exId.value = saved.exId
  } else loadExample(hasExample(l, exId.value) ? exId.value : DEFAULT_EXAMPLE)
  clearTimeout(debounce)
  recompute()
})

const langModel = computed({ get: () => lang.value, set: (v: string) => (lang.value = v as Lang) })
const uiModel = computed({ get: () => locale.value, set: (v: string) => (locale.value = v as UiLang) })
watch(locale, (l) => (document.documentElement.lang = l), { immediate: true })

// ---------- lien toujours à jour ----------
watch([lang, locale, exId, code, speed], () => {
  writeUrl({
    lang: lang.value,
    ui: locale.value,
    ex: exId.value === 'custom' ? undefined : exId.value,
    code: exId.value === 'custom' ? code.value : undefined,
    embed,
    readonly,
    speed: speed.value !== 2 ? speed.value : undefined,
    id: url.id,
    theme: url.theme,
  })
})
const fullAppLink = computed(() =>
  appUrl() + buildHash({ lang: lang.value, ui: locale.value, ex: exId.value === 'custom' ? undefined : exId.value, code: exId.value === 'custom' ? code.value : undefined }),
)

// ---------- clavier ----------
function onKey(e: KeyboardEvent) {
  const el = document.activeElement as HTMLElement | null
  if (el && (el.closest('.cm-editor') || ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName))) return
  if (e.key === 'ArrowRight') {
    e.preventDefault()
    stop()
    next()
  } else if (e.key === 'ArrowLeft') {
    e.preventDefault()
    stop()
    back()
  } else if (e.key === ' ') {
    e.preventDefault()
    toggle()
  }
}
onMounted(() => {
  document.addEventListener('keydown', onKey)
  if (url.autoplay) setTimeout(toggle, 600)
})
onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKey)
  stop()
})
</script>

<template>
  <div class="app" :class="{ embed }">
    <header v-if="!embed" class="topbar">
      <div class="brand">
        <svg class="logo" viewBox="0 0 32 32" aria-hidden="true"><path d="M7 6h12M7 12h8M11 18h10M11 24h6" /><path class="logo-arrow" d="M4 6v18h3" /></svg>
        <strong>tuto-trace</strong>
        <span class="tagline">{{ t('app.tagline') }}</span>
      </div>
      <div class="top-right">
        <PickerMenu v-model="langModel" :options="LANG_OPTIONS" :title="t('pick.lang')" />
        <PickerMenu v-model="uiModel" :options="UI_OPTIONS" :title="t('pick.ui')" />
        <button type="button" class="theme-btn" :title="theme === 'dark' ? t('theme.toLight') : t('theme.toDark')" :aria-label="theme === 'dark' ? t('theme.toLight') : t('theme.toDark')" @click="toggleTheme">
          <svg v-if="theme === 'dark'" viewBox="0 0 20 20" aria-hidden="true"><circle cx="10" cy="10" r="3.6" /><path d="M10 1.8v2.2M10 16v2.2M1.8 10H4M16 10h2.2M4.2 4.2l1.6 1.6M14.2 14.2l1.6 1.6M4.2 15.8l1.6-1.6M14.2 5.8l1.6-1.6" /></svg>
          <svg v-else viewBox="0 0 20 20" aria-hidden="true"><path d="M16.5 12.5A7 7 0 017.5 3.5a7 7 0 109 9z" /></svg>
        </button>
      </div>
    </header>

    <main class="layout">
      <div class="col-code">
        <section class="panel code-panel">
          <div class="code-toolbar">
            <ExamplePicker v-if="!embed" :lang="lang" :current="exId" @pick="loadExample" />
            <span v-else class="lang-chip">{{ LANG_OPTIONS.find((o) => o.id === lang)?.label }}</span>
            <span class="spacer"></span>
            <a v-if="embed" class="tool-btn" :href="fullAppLink" target="_blank" rel="noopener">tuto-trace ↗</a>
            <button v-else type="button" class="tool-btn" @click="showShare = true">
              <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M6 10l4-4M5 7L3.5 8.5a2.5 2.5 0 003.5 3.5L8.5 10.5M11 9l1.5-1.5A2.5 2.5 0 009 4L7.5 5.5" /></svg>
              <span>{{ t('share.button') }}</span>
            </button>
          </div>
          <div ref="wrap" class="editor-wrap">
            <CodeEditor ref="editor" :model-value="code" :lang="lang" :readonly="readonly" :step="step" :diags="diags" @update:model-value="onCodeEdit" @ready="(v) => (view = v)" />
            <FlowOverlay :view="view" :wrap="wrap" :flow="analysis.flow" :step="step" />
          </div>
          <PlayControls
            v-model:speed="speed"
            :cur="cur"
            :total="steps.length"
            :playing="playing"
            :disabled="blocking"
            :status="status.text"
            :status-kind="status.kind"
            @reset="reset"
            @back="
              stop();
              back()
            "
            @step="
              stop();
              next()
            "
            @toggle="toggle"
            @end="toEnd"
          />
        </section>
        <CompileErrors :errors="analysis.errors" :lang="lang" @goto="(l) => editor?.focusLine(l)" />
      </div>
      <div class="col-trace">
        <TraceTable :steps="steps" :cur="cur" @goto="(i) => (stop(), goto(i))" />
      </div>
    </main>

    <!-- panneaux à la demande -->
    <div v-if="openPanels.length" class="dock">
      <ExplainPanel v-if="isOpen('explain')" :step="step" :lang="lang" :flow="analysis.flow" :blocked="blocking" />
      <CallStack v-if="isOpen('stack')" :step="step" :typed="lang !== 'python'" />
      <ConsolePanel v-if="isOpen('console')" :step="step" :lang="lang" />
    </div>
    <nav class="fabs" :aria-label="t('dock.toggle')">
      <button type="button" class="fab" :class="{ on: isOpen('explain'), alert: !isOpen('explain') && (step?.kind === 'error' || step?.kind === 'limit') }" :aria-pressed="isOpen('explain')" :title="t('panel.explain')" @click="togglePanel('explain')">
        <svg viewBox="0 0 20 20" aria-hidden="true"><path d="M10 2.5a7.5 7.5 0 00-6.5 11.2L2.5 17.5l3.8-1A7.5 7.5 0 1010 2.5z" /><path d="M10 9v4M10 6.2v.1" /></svg>
        <span>{{ t('panel.explain') }}</span>
      </button>
      <button type="button" class="fab" :class="{ on: isOpen('stack') }" :aria-pressed="isOpen('stack')" :title="t('panel.stack')" @click="togglePanel('stack')">
        <svg viewBox="0 0 20 20" aria-hidden="true"><rect x="3" y="3" width="14" height="4" rx="1" /><rect x="3" y="8.5" width="14" height="4" rx="1" /><rect x="3" y="14" width="14" height="4" rx="1" /></svg>
        <span>{{ t('panel.stack') }}</span>
      </button>
      <button type="button" class="fab" :class="{ on: isOpen('console'), dot: !isOpen('console') && !!step?.out }" :aria-pressed="isOpen('console')" :title="t('panel.console')" @click="togglePanel('console')">
        <svg viewBox="0 0 20 20" aria-hidden="true"><rect x="2" y="3.5" width="16" height="13" rx="2" /><path d="M5.5 8l2.5 2-2.5 2M10 13h4" /></svg>
        <span>{{ t('panel.console') }}</span>
      </button>
    </nav>
    <p class="vibed">{{ t('vibed') }}</p>

    <ShareDialog v-if="showShare" :lang="lang" :ui="locale" :code="code" :ex="exId" :custom="exId === 'custom'" :speed="speed" @close="showShare = false" />
  </div>
</template>
