<script setup lang="ts">
// Petit organigramme de la structure courante ; le chemin emprunté est surligné.
import { t } from '../i18n'

defineProps<{
  kind: 'while' | 'for' | 'foreach' | 'if' | 'dowhile' | 'func'
  active?: string // true | false | back | init | update | call | return
  hasElse?: boolean
}>()
</script>

<template>
  <svg class="flow-figure" viewBox="0 0 260 168" role="img" :aria-label="kind">
    <defs>
      <marker id="fig-ah" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 0 L 10 5 L 0 10 z" class="fig-ah" />
      </marker>
      <marker id="fig-ah-on" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
        <path d="M 0 0 L 10 5 L 0 10 z" class="fig-ah-on" />
      </marker>
    </defs>

    <!-- while / foreach : losange, corps, retour, suite -->
    <template v-if="kind === 'while' || kind === 'foreach'">
      <path d="M 130 20 V 34" class="fig-edge" marker-end="url(#fig-ah)" />
      <polygon points="130,36 196,60 130,84 64,60" class="fig-cond" />
      <text x="130" y="64" class="fig-t">{{ kind === 'while' ? t('fig.cond') : t('fig.next') }}</text>
      <path d="M 130 84 V 108" :class="['fig-edge', { on: active === 'true' }]" :marker-end="active === 'true' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="138" y="100" class="fig-l">{{ t('legend.true') }}</text>
      <rect x="90" y="110" width="80" height="28" rx="6" class="fig-box" />
      <text x="130" y="128" class="fig-t">{{ t('fig.body') }}</text>
      <path d="M 90 124 H 30 V 60 H 62" :class="['fig-edge', { on: active === 'back' }]" :marker-end="active === 'back' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="34" y="96" class="fig-l">{{ t('legend.back') }}</text>
      <path d="M 196 60 H 222 V 140" :class="['fig-edge', { on: active === 'false' }]" :marker-end="active === 'false' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="204" y="54" class="fig-l">{{ t('legend.false') }}</text>
      <rect x="196" y="142" width="56" height="22" rx="6" class="fig-box fig-after" />
      <text x="224" y="157" class="fig-t">{{ t('fig.after') }}</text>
    </template>

    <!-- for classique -->
    <template v-else-if="kind === 'for'">
      <rect x="92" y="2" width="76" height="22" rx="6" :class="['fig-box', { on: active === 'init' }]" />
      <text x="130" y="17" class="fig-t">{{ t('fig.init') }}</text>
      <path d="M 130 24 V 38" class="fig-edge" marker-end="url(#fig-ah)" />
      <polygon points="130,40 190,60 130,80 70,60" class="fig-cond" />
      <text x="130" y="64" class="fig-t">{{ t('fig.cond') }}</text>
      <path d="M 130 80 V 96" :class="['fig-edge', { on: active === 'true' }]" :marker-end="active === 'true' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="138" y="92" class="fig-l">{{ t('legend.true') }}</text>
      <rect x="92" y="98" width="76" height="24" rx="6" class="fig-box" />
      <text x="130" y="114" class="fig-t">{{ t('fig.body') }}</text>
      <path d="M 130 122 V 134" class="fig-edge" marker-end="url(#fig-ah)" />
      <rect x="86" y="136" width="88" height="24" rx="6" :class="['fig-box', { on: active === 'back' }]" />
      <text x="130" y="152" class="fig-t">{{ t('fig.update') }}</text>
      <path d="M 86 148 H 30 V 60 H 68" :class="['fig-edge', { on: active === 'back' }]" :marker-end="active === 'back' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <path d="M 190 60 H 222 V 130" :class="['fig-edge', { on: active === 'false' }]" :marker-end="active === 'false' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="198" y="54" class="fig-l">{{ t('legend.false') }}</text>
      <rect x="196" y="132" width="56" height="22" rx="6" class="fig-box fig-after" />
      <text x="224" y="147" class="fig-t">{{ t('fig.after') }}</text>
    </template>

    <!-- do … while -->
    <template v-else-if="kind === 'dowhile'">
      <rect x="90" y="8" width="80" height="28" rx="6" class="fig-box" />
      <text x="130" y="26" class="fig-t">{{ t('fig.body') }}</text>
      <path d="M 130 36 V 58" class="fig-edge" marker-end="url(#fig-ah)" />
      <polygon points="130,60 196,84 130,108 64,84" class="fig-cond" />
      <text x="130" y="88" class="fig-t">{{ t('fig.cond') }}</text>
      <path d="M 64 84 H 30 V 22 H 88" :class="['fig-edge', { on: active === 'back' }]" :marker-end="active === 'back' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="34" y="78" class="fig-l">{{ t('legend.true') }}</text>
      <path d="M 130 108 V 134" :class="['fig-edge', { on: active === 'false' }]" :marker-end="active === 'false' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="138" y="126" class="fig-l">{{ t('legend.false') }}</text>
      <rect x="100" y="136" width="60" height="24" rx="6" class="fig-box fig-after" />
      <text x="130" y="152" class="fig-t">{{ t('fig.after') }}</text>
    </template>

    <!-- if / else -->
    <template v-else-if="kind === 'if'">
      <path d="M 130 4 V 16" class="fig-edge" marker-end="url(#fig-ah)" />
      <polygon points="130,18 192,40 130,62 68,40" class="fig-cond" />
      <text x="130" y="44" class="fig-t">{{ t('fig.cond') }}</text>
      <path d="M 68 40 H 50 V 80" :class="['fig-edge', { on: active === 'true' }]" :marker-end="active === 'true' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="40" y="34" class="fig-l">{{ t('legend.true') }}</text>
      <rect x="8" y="82" width="84" height="26" rx="6" class="fig-box" />
      <text x="50" y="99" class="fig-t">{{ t('fig.then') }}</text>
      <template v-if="hasElse">
        <path d="M 192 40 H 210 V 80" :class="['fig-edge', { on: active === 'false' }]" :marker-end="active === 'false' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
        <rect x="168" y="82" width="84" height="26" rx="6" class="fig-box" />
        <text x="210" y="99" class="fig-t">{{ t('fig.else') }}</text>
        <path d="M 210 108 V 128 H 162" class="fig-edge" marker-end="url(#fig-ah)" />
      </template>
      <template v-else>
        <path d="M 192 40 H 210 V 140 H 162" :class="['fig-edge', { on: active === 'false' }]" :marker-end="active === 'false' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      </template>
      <text x="214" y="34" class="fig-l">{{ t('legend.false') }}</text>
      <path d="M 50 108 V 128 H 98" class="fig-edge" marker-end="url(#fig-ah)" />
      <rect x="100" y="120" width="60" height="26" rx="6" class="fig-box fig-after" />
      <text x="130" y="137" class="fig-t">{{ t('fig.after') }}</text>
    </template>

    <!-- appel de fonction -->
    <template v-else-if="kind === 'func'">
      <rect x="10" y="30" width="96" height="100" rx="8" class="fig-box" />
      <text x="58" y="22" class="fig-t">{{ t('fig.caller') }}</text>
      <rect x="22" y="70" width="72" height="20" rx="4" class="fig-callsite" />
      <text x="58" y="84" class="fig-t fig-mono">f(…)</text>
      <rect x="154" y="30" width="96" height="100" rx="8" class="fig-box" />
      <text x="202" y="22" class="fig-t">{{ t('fig.callee') }}</text>
      <text x="202" y="56" class="fig-t fig-mono">def / {</text>
      <text x="202" y="112" class="fig-t fig-mono">return</text>
      <path d="M 94 74 C 124 74 124 52 152 52" :class="['fig-edge', { on: active === 'call' }]" :marker-end="active === 'call' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="124" y="48" class="fig-l">{{ t('fig.call') }}</text>
      <path d="M 154 108 C 124 108 124 86 96 86" :class="['fig-edge', { on: active === 'return' }]" :marker-end="active === 'return' ? 'url(#fig-ah-on)' : 'url(#fig-ah)'" />
      <text x="124" y="124" class="fig-l">{{ t('fig.return') }}</text>
    </template>
  </svg>
</template>
