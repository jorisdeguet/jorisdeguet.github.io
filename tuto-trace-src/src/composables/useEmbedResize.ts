import { onBeforeUnmount, onMounted } from 'vue'

/** En mode intégré, envoie la hauteur du contenu à la page parente (script embed.js). */
export function useEmbedResize(enabled: boolean, id: string | undefined) {
  let ro: ResizeObserver | null = null
  onMounted(() => {
    if (!enabled || window.parent === window) return
    // on mesure l'application elle-même : scrollHeight du document ne descend jamais sous la hauteur de l'iframe
    const app = document.querySelector('.app') as HTMLElement | null
    if (!app) return
    const send = () => window.parent.postMessage({ type: 'tuto-trace:height', id, height: Math.ceil(app.getBoundingClientRect().height) }, '*')
    ro = new ResizeObserver(send)
    ro.observe(app)
    send()
  })
  onBeforeUnmount(() => ro?.disconnect())
}
