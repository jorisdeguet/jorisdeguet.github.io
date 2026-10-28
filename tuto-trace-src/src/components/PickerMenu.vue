<script setup lang="ts">
// Menu déroulant commun au choix du langage informatique et de la langue.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

export interface PickerOption {
  id: string
  label: string
  badge: string
}

const props = defineProps<{ modelValue: string; options: PickerOption[]; title: string }>()
const emit = defineEmits<{ 'update:modelValue': [string] }>()

const open = ref(false)
const root = ref<HTMLElement>()
const current = computed(() => props.options.find((o) => o.id === props.modelValue) ?? props.options[0])

function pick(id: string) {
  emit('update:modelValue', id)
  open.value = false
}
function onDoc(e: MouseEvent) {
  if (root.value && !root.value.contains(e.target as Node)) open.value = false
}
function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') open.value = false
}
onMounted(() => {
  document.addEventListener('click', onDoc)
  document.addEventListener('keydown', onKey)
})
onBeforeUnmount(() => {
  document.removeEventListener('click', onDoc)
  document.removeEventListener('keydown', onKey)
})
</script>

<template>
  <div ref="root" class="picker" :class="{ open }">
    <button type="button" class="picker-btn" :title="title" :aria-label="title" aria-haspopup="listbox" :aria-expanded="open" @click="open = !open">
      <span class="picker-badge" :data-id="current.id">{{ current.badge }}</span>
      <span class="picker-label">{{ current.label }}</span>
      <svg class="caret" viewBox="0 0 10 6" aria-hidden="true"><path d="M1 1l4 4 4-4" /></svg>
    </button>
    <ul v-if="open" class="picker-menu" role="listbox" :aria-label="title">
      <li v-for="o in options" :key="o.id" role="option" :aria-selected="o.id === modelValue" :class="{ selected: o.id === modelValue }" @click="pick(o.id)">
        <span class="picker-badge" :data-id="o.id">{{ o.badge }}</span>
        <span>{{ o.label }}</span>
      </li>
    </ul>
  </div>
</template>
