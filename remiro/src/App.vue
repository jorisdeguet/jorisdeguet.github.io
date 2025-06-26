<script setup>
import { ref, computed, onMounted } from 'vue'
import CardList from './components/CardList.vue'
import TagCloud from './components/TagCloud.vue'

const items = ref([])
const search = ref('')
const selectedTag = ref(null)

// Charger data.json dynamiquement
onMounted(async () => {
  const response = await fetch('https://raw.githubusercontent.com/jorisdeguet/jorisdeguet.github.io/refs/heads/master/remiro/data.json')
  items.value = await response.json()
})

// Extraire tous les tags uniques
const allTags = computed(() => {
  const tags = new Set()
  items.value.forEach(item => {
    (item.tags || []).forEach(tag => tags.add(tag))
  })
  return Array.from(tags).sort()
})

// Filtrer les items selon la recherche et le tag sélectionné
const filteredItems = computed(() => {
  return items.value.filter(item => {
    const matchSearch =
      !search.value ||
      item.nom_de_projet.toLowerCase().includes(search.value.toLowerCase()) ||
      (item.description && item.description.toLowerCase().includes(search.value.toLowerCase()))
    const matchTag = !selectedTag.value || (item.tags || []).includes(selectedTag.value)
    return matchSearch && matchTag
  })
})
</script>

<template>
  <main class="container-fluid py-4">
    <div class="row">
      <section class="col-md-9 mb-4">
        <input
          v-model="search"
          type="text"
          placeholder="Rechercher un projet..."
          class="form-control mb-3"
        />
        <CardList :items="filteredItems" />
      </section>
      <aside class="col-md-3">
        <h2 class="h5 mb-3">Tags</h2>
        <TagCloud :tags="allTags" :selectedTag="selectedTag" @select="tag => selectedTag = tag" />
      </aside>
    </div>
  </main>
</template>

<style scoped>
@import 'https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css';
</style>
