<script setup lang="ts">
import { computed } from 'vue'
import type { CompileError, Lang } from '../engine'
import { has, locale, t, tr } from '../i18n'
import { realCompileMessage } from '../i18n/real'

const props = defineProps<{ errors: CompileError[]; lang: Lang }>()
const emit = defineEmits<{ goto: [number] }>()

const blocking = computed(() => props.errors.some((e) => e.severity === 'error'))
const items = computed(() => {
  void locale.value
  return props.errors.map((e) => {
    const fixKey = 'err.' + e.code + '.fix'
    return {
      e,
      msg: tr('err.' + e.code, e.params),
      real: e.severity === 'error' ? realCompileMessage(props.lang, e.code, e.params) : null,
      // pas de piste « Vouliez-vous dire … ? » quand on n'a aucune suggestion
      fix: has(fixKey) && e.params.hint !== '' ? tr(fixKey, e.params) : null,
    }
  })
})
</script>

<template>
  <section v-if="errors.length" class="panel errors" :class="{ blocking }">
    <h2>{{ t('panel.errors') }}</h2>
    <p v-if="blocking" class="blocking-msg">{{ t('errors.blocking') }}</p>
    <ul>
      <li v-for="(it, i) in items" :key="i" :class="it.e.severity" @click="emit('goto', it.e.span.line)">
        <div class="err-head">
          <span class="sev">{{ it.e.severity === 'error' ? t('errors.error') : t('errors.warning') }}</span>
          <span class="where">{{ t('errors.line', { line: it.e.span.line }) }}</span>
        </div>
        <p v-html="it.msg"></p>
        <pre v-if="it.real" class="real-msg" :title="t('errors.compilerSays')">{{ it.real }}</pre>
        <p v-if="it.fix" class="hint"><strong>{{ t('errors.fix') }}</strong> <span v-html="it.fix"></span></p>
      </li>
    </ul>
  </section>
</template>
