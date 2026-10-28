<script setup lang="ts">
import { computed, ref } from 'vue'
import { appUrl, buildHash } from '../composables/useUrlState'
import type { Lang } from '../engine'
import { t, type UiLang } from '../i18n'

const props = defineProps<{ lang: Lang; ui: UiLang; code: string; ex?: string; custom: boolean; speed: number }>()
const emit = defineEmits<{ close: [] }>()

const readonly = ref(false)
const autoplay = ref(false)
const embed = ref(true)
const copied = ref('')

const state = computed(() => ({
  lang: props.lang,
  ui: props.ui,
  ex: props.custom ? undefined : props.ex,
  code: props.custom ? props.code : undefined,
  readonly: readonly.value,
  autoplay: autoplay.value,
  speed: props.speed !== 2 ? props.speed : undefined,
}))

const link = computed(() => appUrl() + buildHash(state.value))
const embedLink = computed(() => appUrl() + buildHash({ ...state.value, embed: embed.value }))
const iframe = computed(() => `<iframe src="${embedLink.value}" width="100%" height="720" style="border:0" loading="lazy" title="tuto-trace"></iframe>`)
const scriptBase = computed(() => appUrl().replace(/index\.html$/, '') + 'embed.js')
const escapeHtml = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
const script = computed(
  () =>
    `<script src="${scriptBase.value}" defer><\/script>\n<pre data-tuto-trace data-lang="${props.lang}" data-ui="${props.ui}"${readonly.value ? ' data-readonly' : ''}${autoplay.value ? ' data-autoplay' : ''}>${escapeHtml(props.code)}</pre>`,
)

async function copy(which: string, text: string) {
  try {
    await navigator.clipboard.writeText(text)
    copied.value = which
    setTimeout(() => (copied.value = ''), 1500)
  } catch {
    copied.value = ''
  }
}
</script>

<template>
  <div class="modal-back" @click.self="emit('close')">
    <div class="modal" role="dialog" aria-modal="true" :aria-label="t('share.title')">
      <header>
        <h2>{{ t('share.title') }}</h2>
        <button type="button" class="close" :aria-label="t('share.close')" @click="emit('close')">×</button>
      </header>
      <p class="note">{{ t('share.note') }}</p>
      <div class="opts">
        <label><input v-model="readonly" type="checkbox" /> {{ t('share.readonly') }}</label>
        <label><input v-model="autoplay" type="checkbox" /> {{ t('share.autoplay') }}</label>
        <label><input v-model="embed" type="checkbox" /> {{ t('share.embed') }}</label>
      </div>
      <div class="share-field">
        <h3>{{ t('share.link') }}</h3>
        <div class="copy-row">
          <input :value="link" readonly @focus="($event.target as HTMLInputElement).select()" />
          <button type="button" @click="copy('link', link)">{{ copied === 'link' ? t('share.copied') : t('share.copy') }}</button>
        </div>
      </div>
      <div class="share-field">
        <h3>{{ t('share.iframe') }}</h3>
        <div class="copy-row">
          <textarea :value="iframe" readonly rows="3"></textarea>
          <button type="button" @click="copy('iframe', iframe)">{{ copied === 'iframe' ? t('share.copied') : t('share.copy') }}</button>
        </div>
      </div>
      <div class="share-field">
        <h3>{{ t('share.script') }}</h3>
        <div class="copy-row">
          <textarea :value="script" readonly rows="5"></textarea>
          <button type="button" @click="copy('script', script)">{{ copied === 'script' ? t('share.copied') : t('share.copy') }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
