import type { EditorView } from '@codemirror/view'
import type { Fly, Step } from '../engine'

/**
 * Animation « la valeur vole » : du code vers la case de la variable dans la pile,
 * vers la console, ou de return vers le site d'appel.
 */
export function flyStep(view: EditorView | undefined, step: Step, duration: number) {
  if (!view || !step.flies?.length) return
  if (window.matchMedia?.('(prefers-reduced-motion: reduce)').matches) return
  for (const f of step.flies) flyOne(view, f, duration)
}

function targetRect(view: EditorView, f: Fly): DOMRect | null {
  const to = f.to
  // cible dans la pile si elle est affichée, sinon dans la ligne courante du tableau de trace
  if ('var' in to) {
    const id = `${to.var.frameId}:${CSS.escape(to.var.name)}`
    const el = shown(`[data-var="${id}"] .val`) ?? shown(`[data-fly-var="${id}"]`)
    return el ? el.getBoundingClientRect() : null
  }
  if ('console' in to) {
    const con = shown('[data-console]')
    if (con) {
      const r = con.getBoundingClientRect()
      return new DOMRect(r.left + 12, r.bottom - 28, 40, 20)
    }
    const cell = shown('[data-fly-console]')
    return cell ? cell.getBoundingClientRect() : null
  }
  if ('span' in to) {
    const c = view.coordsAtPos(Math.min(to.span.start, view.state.doc.length))
    return c ? new DOMRect(c.left, c.top, 10, c.bottom - c.top) : null
  }
  return null
}

function shown(sel: string): HTMLElement | null {
  const el = document.querySelector(sel) as HTMLElement | null
  return el && el.offsetParent !== null ? el : null
}

function visible(r: DOMRect) {
  return r.bottom > 0 && r.top < window.innerHeight && r.width + r.height > 0
}

function flyOne(view: EditorView, f: Fly, duration: number) {
  const pos = Math.min(f.from.start, view.state.doc.length)
  const from = view.coordsAtPos(pos)
  const to = targetRect(view, f)
  if (!from || !to || !visible(to)) return
  const el = document.createElement('div')
  el.className = 'fly'
  el.textContent = f.text.length > 40 ? f.text.slice(0, 39) + '…' : f.text
  el.style.left = `${from.left}px`
  el.style.top = `${from.top}px`
  document.body.appendChild(el)
  const dx = to.left - from.left
  const dy = to.top + to.height / 2 - (from.top + (from.bottom - from.top) / 2)
  const anim = el.animate(
    [
      { transform: 'translate(0, 0) scale(1)', opacity: 0 },
      { transform: 'translate(0, -6px) scale(1.1)', opacity: 1, offset: 0.15 },
      { transform: `translate(${dx}px, ${dy}px) scale(1)`, opacity: 1, offset: 0.85 },
      { transform: `translate(${dx}px, ${dy}px) scale(0.9)`, opacity: 0 },
    ],
    { duration, easing: 'cubic-bezier(.5,0,.3,1)' },
  )
  anim.onfinish = () => el.remove()
  anim.oncancel = () => el.remove()
}
