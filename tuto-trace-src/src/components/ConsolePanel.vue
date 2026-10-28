<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import type { Lang, Step } from '../engine'
import { t } from '../i18n'
import { realRuntimeMessage } from '../i18n/real'

const props = defineProps<{ step: Step | null; lang: Lang }>()
const box = ref<HTMLElement>()

const errText = computed(() => {
  const s = props.step
  if (s?.kind === 'limit') return '…'
  if (!s?.error) return ''
  return realRuntimeMessage(props.lang, s.error.code, s.error.params) ?? t('err.' + s.error.code, s.error.params)
})

watch(
  () => props.step?.out,
  async () => {
    await nextTick()
    if (box.value) box.value.scrollTop = box.value.scrollHeight
  },
)
</script>

<template>
  <section class="panel console">
    <h2>{{ t('panel.console') }}</h2>
    <pre ref="box" class="console-box" data-console><span v-if="!step?.out && !errText" class="empty">{{ t('console.empty') }}</span>{{ step?.out ?? '' }}<span v-if="errText" class="console-err">{{ errText }}</span></pre>
  </section>
</template>
