/*
 * tuto-trace — script d'intégration.
 *
 *   <script src="https://jorisdeguet.github.io/tuto-trace/embed.js" defer></script>
 *   <pre data-tuto-trace data-lang="python" data-ui="fr">i = 0
 *   while i < 3:
 *       i = i + 1</pre>
 *
 * Chaque bloc est remplacé par une iframe (mode compact) dont la hauteur s'ajuste au contenu.
 * Attributs : data-lang (python | csharp | dart), data-ui (fr | en | es), data-ex (exemple de la
 * bibliothèque, au lieu du code), data-readonly, data-autoplay, data-speed, data-theme (light | dark), data-height (hauteur initiale).
 */
(function () {
  var script = document.currentScript
  var base = script ? script.src.replace(/embed\.js(\?.*)?$/, '') : 'https://jorisdeguet.github.io/tuto-trace/'
  var frames = {}
  var count = 0

  function hashFor(el, id) {
    var p = new URLSearchParams()
    p.set('lang', el.getAttribute('data-lang') || 'python')
    if (el.getAttribute('data-ui')) p.set('ui', el.getAttribute('data-ui'))
    var ex = el.getAttribute('data-ex')
    if (ex) p.set('ex', ex)
    else p.set('src', dedent(el.textContent || ''))
    p.set('embed', '1')
    if (el.hasAttribute('data-readonly')) p.set('readonly', '1')
    if (el.hasAttribute('data-autoplay')) p.set('autoplay', '1')
    if (el.getAttribute('data-speed')) p.set('speed', el.getAttribute('data-speed'))
    if (el.getAttribute('data-theme')) p.set('theme', el.getAttribute('data-theme'))
    p.set('id', id)
    return '#' + p.toString()
  }

  // retire l'indentation commune et les lignes vides de début / fin
  function dedent(s) {
    var lines = s.replace(/\r/g, '').replace(/^\n+|\s+$/g, '').split('\n')
    var min = Infinity
    lines.forEach(function (l) {
      if (l.trim()) min = Math.min(min, l.match(/^ */)[0].length)
    })
    return lines
      .map(function (l) {
        return l.slice(min === Infinity ? 0 : min)
      })
      .join('\n') + '\n'
  }

  function mount(el) {
    var id = 'tt' + ++count
    var iframe = document.createElement('iframe')
    iframe.src = base + 'index.html' + hashFor(el, id)
    iframe.title = 'tuto-trace'
    iframe.loading = 'lazy'
    iframe.style.cssText = 'width:100%;border:0;display:block;height:' + (el.getAttribute('data-height') || '640') + 'px'
    frames[id] = iframe
    el.replaceWith(iframe)
  }

  window.addEventListener('message', function (e) {
    var d = e.data
    if (!d || d.type !== 'tuto-trace:height' || !frames[d.id]) return
    if (frames[d.id].contentWindow !== e.source) return
    frames[d.id].style.height = d.height + 'px'
  })

  function init() {
    document.querySelectorAll('[data-tuto-trace]').forEach(mount)
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init)
  else init()
})()
