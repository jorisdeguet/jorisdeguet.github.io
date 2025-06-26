<template>
  <div class="d-flex flex-wrap align-items-center gap-2">
    <span
      v-for="tag in tags"
      :key="tag"
      :class="['badge', tag === selectedTag ? 'bg-primary' : 'bg-light text-dark', 'tag-cloud-badge']"
      style="cursor:pointer;"
      @click="$emit('select', tag)"
    >
      {{ tag }}
    </span>
    <span v-if="selectedTag" class="ms-2 text-danger fw-bold" style="cursor:pointer;" @click="$emit('select', null)">✕</span>
  </div>
</template>

<script setup>
const props = defineProps({
  tags: Array,
  selectedTag: String
});
</script>

<!-- Plus de style custom, tout est Bootstrap -->
