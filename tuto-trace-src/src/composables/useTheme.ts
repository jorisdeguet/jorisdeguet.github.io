import { computed, ref, watch } from 'vue'

export type Theme = 'light' | 'dark'

const KEY = 'tuto-trace:theme'
const media = window.matchMedia?.('(prefers-color-scheme: dark)')

function stored(): Theme | null {
  try {
    const v = localStorage.getItem(KEY)
    return v === 'light' || v === 'dark' ? v : null
  } catch {
    return null
  }
}

// null = suit le réglage du système
const choice = ref<Theme | null>(stored())
const systemDark = ref(!!media?.matches)
media?.addEventListener('change', (e) => (systemDark.value = e.matches))

export const theme = computed<Theme>(() => choice.value ?? (systemDark.value ? 'dark' : 'light'))

watch(
  choice,
  (c) => {
    if (c) document.documentElement.dataset.theme = c
    else delete document.documentElement.dataset.theme
  },
  { immediate: true },
)

/** Thème imposé par le lien (iframe) : non mémorisé. */
export function forceTheme(t: Theme) {
  choice.value = t
}

export function toggleTheme() {
  choice.value = theme.value === 'dark' ? 'light' : 'dark'
  try {
    localStorage.setItem(KEY, choice.value)
  } catch {
    /* stockage indisponible : le choix vaut pour la session */
  }
}
