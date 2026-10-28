<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import type { Lang } from '../engine'
import { GROUPS, hasExample } from '../examples'
import { t } from '../i18n'

const props = defineProps<{ lang: Lang; current: string }>()
const emit = defineEmits<{ pick: [string] }>()

const open = ref(false)
const root = ref<HTMLElement>()
function onDoc(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) open.value = false
}
onMounted(() => document.addEventListener('click', onDoc))
onBeforeUnmount(() => document.removeEventListener('click', onDoc))

function pick(id: string) {
  emit('pick', id)
  open.value = false
}
const items = (g: (typeof GROUPS)[number]) => g.items.filter((id) => hasExample(props.lang, id))
</script>

<template>
  <div ref="root" class="examples" :class="{ open }">
    <button type="button" class="tool-btn" :aria-expanded="open" @click="open = !open">
      <svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 3h12M2 8h12M2 13h8" /></svg>
      <span>{{ t('panel.examples') }}</span>
      <em>{{ t('examples.' + current) }}</em>
    </button>
    <div v-if="open" class="examples-menu">
      <div v-for="g in GROUPS" :key="g.id" class="ex-group">
        <h3>{{ t('groups.' + g.id) }}</h3>
        <button v-for="id in items(g)" :key="id" type="button" :class="{ selected: id === current }" @click="pick(id)">
          {{ t('examples.' + id) }}
        </button>
      </div>
    </div>
  </div>
</template>
