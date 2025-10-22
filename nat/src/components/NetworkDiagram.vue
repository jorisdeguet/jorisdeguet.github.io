<template>
  <div class="diagram-container">

    <svg viewBox="0 0 1200 450" class="network-svg">
      <!-- Connection lines -->
      <path d="M 150,100 Q 300,225 450,225" stroke="#cbd5e1" stroke-width="2" fill="none" stroke-dasharray="5,5"/>
      <path d="M 150,350 Q 300,225 450,225" stroke="#cbd5e1" stroke-width="2" fill="none" stroke-dasharray="5,5"/>
      <line x1="600" y1="225" x2="750" y2="225" stroke="#cbd5e1" stroke-width="3" />
      <path d="M 900,225 L 1000,200" stroke="#cbd5e1" stroke-width="2" stroke-dasharray="5,5"/>

      <!-- Laptop A -->
      <g :class="{active: selected==='A'}">
        <rect x="50" y="50" width="200" height="100" rx="8" fill="white" stroke="#64748b" stroke-width="2"/>
        <text x="150" y="85" text-anchor="middle" font-size="13" font-weight="600">💻 Laptop A - <tspan fill="#64748b" font-size="12">10.0.0.2</tspan></text>

        <!-- Button for Laptop A -->
        <g @click="sendRequestFrom('A')" class="clickable-button" :class="{disabled: running}">
          <rect x="60" y="105" width="180" height="24" rx="4" :fill="running ? '#cbd5e1' : '#3b82f6'" stroke="#1e40af" stroke-width="1"/>
          <text x="150" y="121" text-anchor="middle" font-size="11" font-weight="600" fill="white">📤 Envoyer une requête</text>
        </g>
      </g>

      <!-- Laptop B -->
      <g :class="{active: selected==='B'}">
        <rect x="50" y="300" width="200" height="100" rx="8" fill="white" stroke="#64748b" stroke-width="2"/>
        <text x="150" y="335" text-anchor="middle" font-size="13" font-weight="600">💻 Laptop B - <tspan fill="#64748b" font-size="12">10.0.0.3</tspan></text>

        <!-- Button for Laptop B -->
        <g @click="sendRequestFrom('B')" class="clickable-button" :class="{disabled: running}">
          <rect x="60" y="355" width="180" height="24" rx="4" :fill="running ? '#cbd5e1' : '#3b82f6'" stroke="#1e40af" stroke-width="1"/>
          <text x="150" y="371" text-anchor="middle" font-size="11" font-weight="600" fill="white">📤 Envoyer une requête</text>
        </g>
      </g>

      <!-- Router with NAT table -->
      <g>
        <rect x="400" y="125" width="250" height="200" rx="10" fill="white" stroke="#3b82f6" stroke-width="3"/>
        <rect x="410" y="135" width="230" height="30" rx="5" fill="#3b82f6"/>
        <text x="525" y="157" text-anchor="middle" font-size="16" font-weight="700" fill="white">🔀 Routeur NAT</text>

        <!-- Left side: Local Network IP (rotated 90°) -->
        <text x="370" y="225" text-anchor="middle" font-size="11" font-weight="600" fill="#64748b" transform="rotate(-90 370 225)">
          🏠 IP local: 10.0.0.1
        </text>

        <!-- Right side: Public IP (rotated 90°) -->
        <text x="680" y="225" text-anchor="middle" font-size="11" font-weight="600" fill="#64748b" transform="rotate(90 680 225)">
          🌐 IP publique: 198.51.100.10
        </text>

        <!-- NAT Table -->
        <rect x="415" y="175" width="220" height="100" rx="4" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1"/>
        <text x="425" y="190" font-size="10" font-weight="700">Private IP</text>
        <text x="510" y="190" font-size="10" font-weight="700">Src Port</text>
        <text x="590" y="190" font-size="10" font-weight="700">Public Port</text>
        <line x1="415" y1="195" x2="635" y2="195" stroke="#cbd5e1" stroke-width="1"/>

        <g v-for="(e, i) in natTable" :key="i" :class="{highlighted: highlightedEntry === i}">
          <rect x="415" :y="200 + i * 18" width="220" height="16" :fill="highlightedEntry === i ? '#dbeafe' : 'transparent'" rx="2"/>
          <text x="425" :y="211 + i * 18" font-size="9" fill="#0f172a">{{ e.private }}</text>
          <text x="510" :y="211 + i * 18" font-size="9" fill="#0f172a">{{ e.src }}</text>
          <text x="590" :y="211 + i * 18" font-size="9" fill="#0f172a">{{ e.publicPort }}</text>
        </g>

        <!-- Reset button in router -->
        <g @click="resetTable" class="clickable-button" :class="{disabled: running}">
          <rect x="425" y="290" width="190" height="26" rx="5" :fill="running ? '#e2e8f0' : '#ef4444'" stroke="#dc2626" stroke-width="1"/>
          <text x="520" y="307" text-anchor="middle" font-size="10" font-weight="600" fill="white">🔄 Réinitialiser table NAT</text>
        </g>
      </g>

      <!-- Cloud -->
      <g>
        <ellipse cx="825" cy="205" rx="80" ry="50" fill="#e0e7ff" stroke="#818cf8" stroke-width="2"/>
        <ellipse cx="795" cy="220" rx="50" ry="35" fill="#eef2ff" stroke="#818cf8" stroke-width="1.5"/>
        <ellipse cx="855" cy="220" rx="50" ry="35" fill="#eef2ff" stroke="#818cf8" stroke-width="1.5"/>
        <text x="825" y="210" text-anchor="middle" font-size="13" font-weight="600">☁️ Internet</text>
        <text x="825" y="230" text-anchor="middle" font-size="11" fill="#64748b">(Cloud)</text>
      </g>

      <!-- Serveur -->
      <g>
        <rect x="950" y="125" width="180" height="140" rx="8" fill="white" stroke="#8b5cf6" stroke-width="3"/>
        <rect x="960" y="135" width="160" height="20" rx="4" fill="#8b5cf6"/>
        <text x="1040" y="205" text-anchor="middle" font-size="14" font-weight="600">🖥️ Serveur</text>

        <!-- Left side: Serveur IP (rotated 90°) -->
        <text x="920" y="195" text-anchor="middle" font-size="11" font-weight="600" fill="#64748b" transform="rotate(-90 920 195)">
          🌐 Serveur: 203.0.113.5
        </text>
      </g>

      <!-- Animated packet -->
      <g v-show="visiblePacket" :transform="`translate(${packetX}, ${packetY})`">
        <rect x="-75" y="-35" width="150" height="70" rx="6" fill="url(#packetGradient)" stroke="#7c3aed" stroke-width="2"/>
        <text x="0" y="-18" text-anchor="middle" font-size="9" fill="white" font-weight="700">{{ currentStep <= 4 ? '📦 Requête HTTPS' : '📦 Réponse HTTPS' }}</text>
        <line x1="-65" y1="-10" x2="65" y2="-10" stroke="white" stroke-width="0.5" opacity="0.5"/>
        <text x="0" y="0" text-anchor="middle" font-size="8" fill="white" font-weight="600">{{ packetInfo.srcIP }}:{{ packetInfo.srcPort }}</text>
        <text x="0" y="12" text-anchor="middle" font-size="7" fill="#e0e7ff">↓</text>
        <text x="0" y="24" text-anchor="middle" font-size="8" fill="white" font-weight="600">{{ packetInfo.destIP }}:{{ packetInfo.destPort }}</text>
      </g>

      <!-- Gradient for packet -->
      <defs>
        <linearGradient id="packetGradient" x1="0%" y1="0%" x2="100%" y2="0%">
          <stop offset="0%" style="stop-color:#0ea5e9;stop-opacity:1" />
          <stop offset="100%" style="stop-color:#7c3aed;stop-opacity:1" />
        </linearGradient>
      </defs>
    </svg>

    <div class="status-text" v-if="statusMessage">
      <strong>État:</strong> {{ statusMessage }}
    </div>

    <div class="bottom-section">
      <div class="animation-controls">
        <strong>🎮 Contrôles :</strong>

        <div class="control-group" v-if="paused">
          <button @click="nextStep" class="step-button">
            ➡️ Étape suivante
          </button>
        </div>

        <div class="step-info">
          <small>Étape {{ currentStep }} / {{ totalSteps }}</small>
        </div>

        <div class="step-description" v-if="stepDescriptions[currentStep]">
          <div class="desc-header">📝 Étape {{ currentStep }} :</div>
          <p>{{ stepDescriptions[currentStep] }}</p>
        </div>

        <div class="step-description" v-if="currentStep === 0">
          <div class="desc-header">ℹ️ En attente</div>
          <p>Cliquez sur "Envoyer une requête" sur un laptop pour démarrer.</p>
        </div>
      </div>

      <div class="layer-section https-layer" v-if="currentStep >= 1">
        <div class="layer-header">🔹 HTTPS</div>
        <div class="layer-content">
          <!-- Show encrypted content for specific steps -->
          <div v-if="[2, 3, 4, 6, 7, 8].includes(currentStep)" class="encrypted-content">
            <div class="detail-row">
              <span class="label">Payload (AES-256):</span>
              <span class="value encrypted-text">{{ encryptedPayload }}</span>
            </div>
            <div class="detail-row">
              <span class="label">État:</span>
              <span class="value">🔐 Chiffré en transit</span>
            </div>
          </div>
          <!-- Show normal content for other steps -->
          <div v-else>
            <div class="detail-row">
              <span class="label">URL:</span>
              <span class="value">monsuperserveur.com</span>
            </div>
            <div class="detail-row">
              <span class="label">Méthode:</span>
              <span class="value">GET</span>
            </div>
            <div class="detail-row">
              <span class="label">État:</span>
              <span class="value">🔒 Encrypté</span>
            </div>
          </div>
        </div>
      </div>

      <div class="layer-section tcp-layer" v-if="currentStep >= 1">
        <div class="layer-header">🔹 TCP</div>
        <div class="layer-content">
          <div class="detail-row">
            <span class="label">Port src:</span>
            <span class="value highlight">{{ packetInfo.srcPort }}</span>
          </div>
          <div class="detail-row">
            <span class="label">Port dest:</span>
            <span class="value highlight">{{ packetInfo.destPort }}</span>
          </div>
        </div>
      </div>

      <div class="layer-section ip-layer" v-if="currentStep >= 1">
        <div class="layer-header">🔹 IP</div>
        <div class="layer-content">
          <div class="detail-row">
            <span class="label">IP src:</span>
            <span class="value highlight">{{ packetInfo.srcIP }}</span>
          </div>
          <div class="detail-row">
            <span class="label">IP dest:</span>
            <span class="value highlight">{{ packetInfo.destIP }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'

const selected = ref('A')
const natTable = reactive([])
const running = ref(false)
const visiblePacket = ref(false)
const packetX = ref(150)
const packetY = ref(150)
const statusMessage = ref('')
const highlightedEntry = ref(-1)
const paused = ref(false)
const currentStep = ref(0)
const totalSteps = ref(10)
const packetInfo = reactive({
  srcIP: '10.0.0.2',
  srcPort: '40000',
  destIP: '203.0.113.5',
  destPort: '443'
})

let publicPortCounter = 40000
let resumeAnimation = null
let encryptedPayload = '' // Store generated encrypted content

// Function to generate fake encrypted content (looks like AES encrypted data)
function generateFakeEncrypted() {
  const chars = '0123456789ABCDEF'
  let result = ''
  for (let i = 0; i < 64; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return result
}

// Step descriptions
const stepDescriptions = {
  1: "Le laptop prépare une requête HTTPS. Il crée un paquet contenant l'URL de destination (monsuperserveur.com), la méthode HTTP (GET). Le paquet n'a pas encore quitté le laptop.",
  2: "Le laptop envoie une requête HTTPS au serveur distant. Le paquet contient l'IP source privée (10.0.0.x) et un port source aléatoire. Il traverse d'abord le réseau local pour atteindre le routeur.",
  3: "Le routeur analyse le paquet sortant et crée une nouvelle entrée dans sa table NAT. Il associe l'IP privée et le port source à un port public unique. Cette mapping permet de router correctement les réponses.",
  4: "Le routeur réécrit l'en-tête IP du paquet : il remplace l'IP source privée (10.0.0.x) par son IP publique (198.51.100.10) et change le port source. Le paquet modifié est envoyé sur Internet.",
  5: "Le paquet traverse Internet et arrive au serveur de destination (203.0.113.5:443). Le serveur ne voit que l'IP publique du routeur, pas l'IP privée du laptop. Il prépare une réponse.",
  6: "Le serveur envoie sa réponse HTTPS. L'IP source devient 203.0.113.5:443 et l'IP destination est l'IP publique du routeur (198.51.100.10) avec le port public mappé. Le paquet repart vers Internet.",
  7: "Le paquet de réponse arrive au routeur. Le routeur doit maintenant déterminer quel laptop du réseau local doit recevoir ce paquet en consultant sa table NAT.",
  8: "Le routeur cherche dans sa table NAT : il trouve la correspondance entre le port public destination et l'IP privée + port d'origine. Cela lui permet d'identifier le bon laptop destinataire.",
  9: "Le routeur réécrit l'en-tête IP : il remplace l'IP destination publique par l'IP privée du laptop (10.0.0.x) et restaure le port source original. Le paquet est délivré au bon laptop qui reçoit la réponse HTTPS.",
  10: "✅ La requête HTTPS est complétée avec succès. Le laptop a reçu la réponse du serveur distant via le NAT du routeur."
}

// SVG coordinates for devices
const positions = {
  laptopA: { x: 150, y: 100 },
  laptopB: { x: 150, y: 350 },
  router: { x: 525, y: 225 },
  cloud: { x: 825, y: 225 },
  server: { x: 1040, y: 200 }
}

function randPort() {
  return Math.floor(40000 + Math.random() * 25000)
}

async function waitForStep() {
  paused.value = true
  await new Promise(resolve => {
    resumeAnimation = resolve
  })
  paused.value = false
}

function nextStep() {
  if (resumeAnimation) {
    currentStep.value++
    resumeAnimation()
    resumeAnimation = null
  }
}

async function animatePath(points, msPerStep = 6) {
  visiblePacket.value = true
  for (let i = 0; i < points.length; i++) {
    const p = points[i]
    packetX.value = p.x
    packetY.value = p.y
    await new Promise(r => setTimeout(r, msPerStep))
  }
}

function bezierPath(p1, p2, steps = 80) {
  const pts = []
  // Create a curved path using quadratic bezier
  const controlX = (p1.x + p2.x) / 2
  const controlY = Math.min(p1.y, p2.y) - 50

  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const x = (1-t)*(1-t)*p1.x + 2*(1-t)*t*controlX + t*t*p2.x
    const y = (1-t)*(1-t)*p1.y + 2*(1-t)*t*controlY + t*t*p2.y
    pts.push({ x, y })
  }
  return pts
}

function linearPath(p1, p2, steps = 60) {
  const pts = []
  for (let i = 0; i <= steps; i++) {
    const t = i / steps
    const x = p1.x + (p2.x - p1.x) * t
    const y = p1.y + (p2.y - p1.y) * t
    pts.push({ x, y })
  }
  return pts
}

function sendRequestFrom(laptop) {
  selected.value = laptop
  sendRequest()
}

async function sendRequest() {
  if (running.value) return
  running.value = true
  highlightedEntry.value = -1
  currentStep.value = 1
  encryptedPayload = generateFakeEncrypted() // Generate encrypted content at the start

  const srcIP = selected.value === 'A' ? '10.0.0.2' : '10.0.0.3'
  const srcPort = randPort()
  const srcPos = selected.value === 'A' ? positions.laptopA : positions.laptopB

  // 1) Laptop preparing request
  currentStep.value = 1
  packetInfo.srcIP = srcIP
  packetInfo.srcPort = srcPort.toString()
  packetInfo.destIP = '203.0.113.5'
  packetInfo.destPort = '443'
  statusMessage.value = `${srcIP}: Préparation de la requête HTTPS...`
  visiblePacket.value = true
  packetX.value = srcPos.x
  packetY.value = srcPos.y
  await new Promise(r => setTimeout(r, 600))
  await waitForStep()

  // 2) Laptop to router
  currentStep.value = 2
  packetInfo.srcIP = srcIP
  packetInfo.srcPort = srcPort.toString()
  packetInfo.destIP = '203.0.113.5'
  packetInfo.destPort = '443'
  statusMessage.value = `${srcIP}:${srcPort} → Routeur (requête HTTPS)`
  await animatePath(bezierPath(srcPos, positions.router), 8)
  await new Promise(r => setTimeout(r, 300))
  await waitForStep()

  // 3) Router creates NAT entry
  currentStep.value = 3
  const publicPort = publicPortCounter++
  const entryIndex = natTable.length
  natTable.push({
    private: srcIP,
    src: srcPort.toString(),
    publicPort: publicPort.toString()
  })
  highlightedEntry.value = entryIndex
  statusMessage.value = `Routeur: NAT créé → 198.51.100.10:${publicPort}`
  await new Promise(r => setTimeout(r, 700))
  await waitForStep()

  // 4) Router to cloud (NAT translation applied)
  currentStep.value = 4
  packetInfo.srcIP = '198.51.100.10'
  packetInfo.srcPort = publicPort.toString()
  packetInfo.destIP = '203.0.113.5'
  packetInfo.destPort = '443'
  statusMessage.value = `198.51.100.10:${publicPort} → Internet (IP source traduite par NAT)`
  await animatePath(linearPath(positions.router, positions.cloud), 8)
  await waitForStep()

  // 5) Cloud to server
  currentStep.value = 5
  statusMessage.value = `198.51.100.10:${publicPort} → Server (203.0.113.5:443)`
  await animatePath(linearPath(positions.cloud, positions.server), 8)
  await new Promise(r => setTimeout(r, 600))
  await waitForStep()

  // 6) Server response (swap src/dest)
  currentStep.value = 6
  packetInfo.srcIP = '203.0.113.5'
  packetInfo.srcPort = '443'
  packetInfo.destIP = '198.51.100.10'
  packetInfo.destPort = publicPort.toString()
  statusMessage.value = `Server → 198.51.100.10:${publicPort} (réponse HTTPS)`
  await animatePath(linearPath(positions.server, positions.cloud), 8)
  await waitForStep()

  // 7) Cloud to router
  currentStep.value = 7
  await animatePath(linearPath(positions.cloud, positions.router), 8)
  await new Promise(r => setTimeout(r, 400))
  await waitForStep()

  // 8) Router lookup NAT table
  currentStep.value = 8
  highlightedEntry.value = entryIndex
  statusMessage.value = `Routeur: lookup NAT table (port ${publicPort} → ${srcIP}:${srcPort})`
  await new Promise(r => setTimeout(r, 900))
  await waitForStep()

  // 9) Router to destination laptop (NAT reverse translation)
  currentStep.value = 9
  packetInfo.srcIP = '203.0.113.5'
  packetInfo.srcPort = '443'
  packetInfo.destIP = srcIP
  packetInfo.destPort = srcPort.toString()
  statusMessage.value = `Routeur → ${srcIP}:${srcPort} (réponse délivrée, IP dest traduite)`
  await animatePath(bezierPath(positions.router, srcPos), 8)
  await new Promise(r => setTimeout(r, 700))

  // 10) Completion
  currentStep.value = 10
  statusMessage.value = `✅ Requête HTTPS complétée avec succès!`
  await new Promise(r => setTimeout(r, 1000))

  visiblePacket.value = false
  highlightedEntry.value = -1
  statusMessage.value = ''
  currentStep.value = 0
  running.value = false
}

function resetTable() {
  natTable.length = 0
  publicPortCounter = 40000
  highlightedEntry.value = -1
  statusMessage.value = 'Table NAT réinitialisée'
  setTimeout(() => { statusMessage.value = '' }, 2000)
}
</script>

<style scoped>
.diagram-container {
  width: 100%;
  margin: 0 auto;
  padding: 1rem;
}

.controls {
  display: flex;
  gap: 12px;
  align-items: center;
  margin-bottom: 1rem;
  padding: 12px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.controls label {
  font-weight: 500;
}

.controls select {
  padding: 6px 10px;
  border: 1px solid #cbd5e1;
  border-radius: 6px;
  font-size: 14px;
}

.controls button {
  padding: 8px 16px;
  background: #3b82f6;
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.2s;
}

.controls button:hover:not(:disabled) {
  background: #2563eb;
}

.controls button:disabled {
  background: #cbd5e1;
  cursor: not-allowed;
}

.network-svg {
  width: 100%;
  height: auto;
  background: white;
  border-radius: 10px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
  border: 1px solid #e2e8f0;
}

.network-svg g.active {
  filter: drop-shadow(0 0 8px rgba(34, 197, 94, 0.4));
}

.network-svg g.highlighted rect {
  transition: fill 0.3s ease;
}

.clickable-button {
  cursor: pointer;
}

.clickable-button:not(.disabled):hover rect {
  filter: brightness(1.1);
}

.clickable-button.disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

.info-text {
  color: #475569;
  font-size: 0.95rem;
  font-style: italic;
}

.status-text {
  margin-top: 1rem;
  padding: 12px 16px;
  background: #f0f9ff;
  border-left: 4px solid #0ea5e9;
  border-radius: 6px;
  font-size: 14px;
  min-height: 20px;
}

.bottom-section {
  display: grid;
  grid-template-columns: 1fr 1fr 1fr 1fr;
  gap: 16px;
  margin-top: 1.5rem;
}

.legend {
  padding: 16px;
  background: #f8fafc;
  border-radius: 8px;
  font-size: 0.9rem;
  border: 1px solid #e2e8f0;
}

.legend strong {
  display: block;
  margin-bottom: 8px;
  color: #0f172a;
}

.legend ul {
  margin: 0;
  padding-left: 20px;
}

.legend li {
  margin: 6px 0;
  color: #475569;
}

.animation-controls {
  padding: 16px;
  background: #fefce8;
  border-radius: 8px;
  border: 1px solid #fde047;
}

.animation-controls strong {
  display: block;
  margin-bottom: 12px;
  color: #0f172a;
}

.layer-section {
  padding: 16px;
  border-radius: 8px;
  border: 2px solid;
}

.https-layer {
  background: #fef3c7;
  border-color: #f59e0b;
}

.tcp-layer {
  background: #dbeafe;
  border-color: #3b82f6;
}

.ip-layer {
  background: #e9d5ff;
  border-color: #8b5cf6;
}

.layer-header {
  font-weight: 700;
  font-size: 1rem;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 2px solid rgba(0,0,0,0.1);
}

.layer-content {
  min-height: 100px;
}

.layer-content .waiting {
  text-align: center;
  color: #64748b;
  font-style: italic;
  margin: 20px 0;
}

.packet-details {
  padding: 16px;
  background: #f0f9ff;
  border-radius: 8px;
  border: 1px solid #7dd3fc;
}

.packet-details strong {
  display: block;
  margin-bottom: 12px;
  color: #0f172a;
  font-size: 1rem;
}

.detail-section {
  margin: 16px 0;
  padding: 12px;
  background: white;
  border-radius: 6px;
  border: 1px solid #e0f2fe;
}

.section-header {
  font-weight: 700;
  color: #0c4a6e;
  margin-bottom: 10px;
  font-size: 0.95rem;
  padding-bottom: 6px;
  border-bottom: 2px solid #e0f2fe;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  padding: 6px 4px;
  font-size: 0.9rem;
  border-bottom: 1px solid #f1f5f9;
}

.detail-row:last-child {
  border-bottom: none;
}

.detail-row .label {
  color: #64748b;
  font-weight: 500;
}

.detail-row .value {
  color: #0f172a;
  font-weight: 600;
  font-family: 'Courier New', monospace;
}

.detail-row .value.highlight {
  color: #0369a1;
  background: #e0f2fe;
  padding: 2px 8px;
  border-radius: 4px;
}

.encrypted-content {
  padding: 8px 0;
}

.encrypted-text {
  font-family: 'Courier New', monospace !important;
  font-size: 0.75rem !important;
  letter-spacing: 0.5px;
  word-break: break-all;
  background: #1f2937;
  color: white !important;
  padding: 8px !important;
  border-radius: 4px;
  display: inline-block;
  max-width: 100%;
}

.encrypted-label {
  color: white !important;
}

.encrypted-state {
  color: white !important;
}

.step-description {
  margin-top: 16px;
  padding: 14px;
  background: #fefce8;
  border-radius: 6px;
  border-left: 4px solid #facc15;
}

.desc-header {
  font-weight: 700;
  color: #854d0e;
  margin-bottom: 8px;
  font-size: 0.95rem;
}

.step-description p {
  margin: 0;
  color: #3f3f46;
  font-size: 0.9rem;
  line-height: 1.6;
}

.control-group {
  margin: 12px 0;
}

.control-group label {
  display: block;
  font-size: 0.9rem;
  color: #475569;
  margin-bottom: 6px;
  font-weight: 500;
}

.control-group input[type="checkbox"] {
  margin-right: 6px;
  cursor: pointer;
}

.speed-buttons {
  display: flex;
  gap: 8px;
  margin-top: 6px;
}

.speed-buttons button {
  flex: 1;
  padding: 8px 12px;
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 6px;
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s;
}

.speed-buttons button:hover:not(:disabled) {
  border-color: #fbbf24;
  background: #fffbeb;
}

.speed-buttons button.active {
  background: #fbbf24;
  border-color: #f59e0b;
  color: white;
  font-weight: 600;
}

.speed-buttons button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.step-button {
  width: 100%;
  padding: 10px 16px;
  background: #10b981;
  color: white;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
  font-size: 0.95rem;
}

.step-button:hover {
  background: #059669;
}

.step-info {
  margin-top: 8px;
  padding: 8px;
  background: white;
  border-radius: 4px;
  text-align: center;
}

.step-info small {
  color: #64748b;
  font-weight: 500;
}

@media (max-width: 768px) {
  .bottom-section {
    grid-template-columns: 1fr;
  }
}
</style>

