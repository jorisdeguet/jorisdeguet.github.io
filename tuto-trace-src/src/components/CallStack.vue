<script setup lang="ts">
import { computed } from 'vue'
import type { Step } from '../engine'
import { t } from '../i18n'
import { frameHue } from '../summary'

const props = defineProps<{ step: Step | null; typed: boolean }>()

// Le contexte le plus récent en haut, comme une pile.
const frames = computed(() => {
  const s = props.step
  if (!s) return []
  return [...s.frames].reverse().filter((f) => !(f.global && f.vars.length === 0 && s.frames.length > 1))
})

const isChanged = (fid: number, name: string) => props.step?.changed?.frameId === fid && props.step.changed.name === name
</script>

<template>
  <section class="panel stack">
    <h2>{{ t('panel.stack') }}</h2>
    <p v-if="!frames.length" class="empty">{{ t('stack.empty') }}</p>
    <TransitionGroup name="frame" tag="div" class="frames">
      <div
        v-for="(f, idx) in frames"
        :key="f.id"
        class="frame"
        :class="{ top: idx === 0, global: f.global }"
        :style="{ '--hue': frameHue(f.id) }"
        :data-frame="f.id"
      >
        <header>
          <span class="fn">{{ f.global ? t('stack.global') : f.fn + '()' }}</span>
          <span v-if="f.callLine" class="called">{{ t('stack.calledFrom', { line: f.callLine }) }}</span>
          <span v-if="idx === 0 && frames.length > 1" class="badge-top">{{ t('stack.top') }}</span>
        </header>
        <table v-if="f.vars.length">
          <tbody>
            <tr v-for="v in f.vars" :key="v.name" :class="{ changed: isChanged(f.id, v.name) }" :data-var="`${f.id}:${v.name}`">
              <td v-if="typed" class="vtype">{{ v.type }}</td>
              <td class="vname">{{ v.name }}</td>
              <td class="vval">
                <span :key="isChanged(f.id, v.name) ? step!.i : 0" class="val" :class="{ unset: v.unset, flash: isChanged(f.id, v.name) }">
                  <template v-if="v.items">
                    <span class="list"><span v-for="(it, i) in v.items" :key="i" class="cell"><small>{{ i }}</small>{{ it }}</span><span v-if="!v.items.length" class="cell empty-cell">∅</span></span>
                  </template>
                  <template v-else-if="v.unset">{{ t('stack.unset') }}</template>
                  <template v-else>{{ v.text }}</template>
                </span>
                <small v-if="!typed && v.type" class="rtype">{{ v.type }}</small>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="f.ret !== undefined" class="ret" :data-ret="f.id">{{ t('stack.returns') }} <code>{{ f.ret }}</code></div>
      </div>
    </TransitionGroup>
  </section>
</template>
