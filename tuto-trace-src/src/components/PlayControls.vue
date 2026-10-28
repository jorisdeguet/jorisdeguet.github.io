<script setup lang="ts">
import { t } from '../i18n'

defineProps<{ cur: number; total: number; playing: boolean; disabled: boolean; status: string; statusKind: string }>()
const speed = defineModel<number>('speed', { required: true })
const emit = defineEmits<{ reset: []; back: []; step: []; toggle: []; end: [] }>()
</script>

<template>
  <div class="controls" :class="{ disabled }">
    <div class="buttons">
      <button type="button" :title="t('ctl.reset')" :aria-label="t('ctl.reset')" :disabled="disabled || cur < 0" @click="emit('reset')">
        <svg viewBox="0 0 16 16"><path d="M3 3v10M13 3L6 8l7 5z" /></svg>
      </button>
      <button type="button" :title="t('ctl.back')" :aria-label="t('ctl.back')" :disabled="disabled || cur < 0" @click="emit('back')">
        <svg viewBox="0 0 16 16"><path d="M11 3L5 8l6 5z" /></svg>
      </button>
      <button type="button" class="primary" :title="playing ? t('ctl.pause') : t('ctl.play')" :aria-label="playing ? t('ctl.pause') : t('ctl.play')" :disabled="disabled" @click="emit('toggle')">
        <svg v-if="playing" viewBox="0 0 16 16"><path d="M5 3v10M11 3v10" /></svg>
        <svg v-else viewBox="0 0 16 16"><path d="M4 2.5l10 5.5-10 5.5z" /></svg>
      </button>
      <button type="button" class="primary step" :title="t('ctl.step') + ' (→)'" :aria-label="t('ctl.step')" :disabled="disabled || cur >= total - 1" @click="emit('step')">
        <svg viewBox="0 0 16 16"><path d="M5 3l6 5-6 5z" /></svg>
        <span>{{ t('ctl.step') }}</span>
      </button>
      <button type="button" :title="t('ctl.end')" :aria-label="t('ctl.end')" :disabled="disabled || cur >= total - 1" @click="emit('end')">
        <svg viewBox="0 0 16 16"><path d="M13 3v10M3 3l7 5-7 5z" /></svg>
      </button>
    </div>
    <label class="speed">
      <span>{{ t('ctl.speed') }}</span>
      <input v-model.number="speed" type="range" min="0.5" max="10" step="0.5" />
      <output>{{ speed }} {{ t('ctl.perSec') }}</output>
    </label>
    <div class="progress">
      <span class="counter">{{ t('ctl.stepOf', { i: Math.max(0, cur + 1), n: total }) }}</span>
      <span class="status" :class="statusKind">{{ status }}</span>
    </div>
  </div>
</template>
