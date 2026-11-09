/* SmokeGuard AI — FCM Web Push + Background Service Worker (v3) */
const CACHE_NAME = 'smokeguard-pwa-v3'
const notifiedIncidentIds = new Set()
let lastSeenIncidentId = null
let bgWatcherRunning = false

self.addEventListener('install', (event) => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      await self.clients.claim()
      startBackgroundPollLoop()
    })()
  )
})

function buildHeadsUpOptions(payload) {
  const origin = self.location.origin
  let fullImage = undefined
  if (payload.image) {
    fullImage = payload.image.startsWith('http')
      ? payload.image
      : `${origin}${payload.image}`
  }

  const options = {
    body: payload.body || 'Aktivitas merokok terkonfirmasi pada kawasan tanpa rokok.',
    icon: `${origin}/icon-192.png`,
    badge: `${origin}/icon-192.png`,
    tag: payload.tag || `smokeguard-alert-${Date.now()}`,
    renotify: true,
    requireInteraction: true,
    silent: false,
    timestamp: Date.now(),
    vibrate: [500, 150, 500, 150, 700],
    actions: [
      { action: 'open', title: 'Lihat Bukti Foto' },
      { action: 'dismiss', title: 'Tutup' },
    ],
    data: {
      url: '/',
      incident: payload.incident || null,
    },
  }
  if (fullImage) {
    options.image = fullImage
  }
  return options
}

/* 1. Handle Real FCM Web Push Events (Wakes up Service Worker even when PWA is completely closed) */
self.addEventListener('push', (event) => {
  let payload = {
    title: 'PERINGATAN KTR: Merokok Terdeteksi',
    body: 'Terdeteksi aktivitas merokok pada kamera pengawas KTR.',
    image: null,
    tag: `smokeguard-fcm-${Date.now()}`,
    incident: null,
  }

  if (event.data) {
    try {
      const json = event.data.json()
      const notif = json.notification || json
      payload.title = notif.title || payload.title
      payload.body = notif.body || payload.body
      if (notif.image) payload.image = notif.image
      if (json.tag) payload.tag = json.tag
      if (json.incident) payload.incident = json.incident
    } catch (e) {
      payload.body = event.data.text()
    }
  }

  const incId = payload.incident?.id
  if (incId) {
    if (notifiedIncidentIds.has(incId)) {
      return
    }
    notifiedIncidentIds.add(incId)
    lastSeenIncidentId = Math.max(lastSeenIncidentId || 0, incId)
  }

  const options = buildHeadsUpOptions(payload)
  event.waitUntil(
    (async () => {
      await self.registration.showNotification(payload.title, options)
      const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      for (const client of clients) {
        client.postMessage({
          type: 'HEADS_UP_BANNER',
          payload: {
            title: payload.title,
            body: payload.body,
            image: options.image,
            incident: payload.incident,
          },
        })
      }
    })()
  )
})

/* 2. Background Polling Watcher inside Service Worker (USB Localhost Keep-Alive when PWA is closed/minimized) */
async function startBackgroundPollLoop() {
  if (bgWatcherRunning) return
  bgWatcherRunning = true
  try {
    for (let i = 0; i < 600; i++) {
      try {
        const res = await fetch('/api/status/', { cache: 'no-store' })
        if (res.ok) {
          const data = await res.json()
          const inc = data.latest_incident
          if (inc && inc.id) {
            if (lastSeenIncidentId === null) {
              lastSeenIncidentId = inc.id
              notifiedIncidentIds.add(inc.id)
            } else if (inc.id > lastSeenIncidentId && !notifiedIncidentIds.has(inc.id)) {
              lastSeenIncidentId = inc.id
              notifiedIncidentIds.add(inc.id)
              const title = `PERINGATAN KTR • ${inc.camera_name}`
              const body = `Terdeteksi ${inc.cigarette_count} titik rokok (${inc.person_count} orang) di ${inc.location} • Conf ${Math.round(
                (inc.max_confidence || 0) * 100
              )}%`
              const options = buildHeadsUpOptions({
                title,
                body,
                image: inc.snapshot_url,
                tag: `smokeguard-bg-${inc.id}`,
                incident: inc,
              })
              await self.registration.showNotification(title, options)
            }
          } else if (lastSeenIncidentId === null) {
            lastSeenIncidentId = 0
          }
        }
      } catch (e) {
        // ignore transient network errors
      }
      await new Promise((r) => setTimeout(r, 1500))
    }
  } finally {
    bgWatcherRunning = false
  }
}

/* 3. Handle Messages from PWA Client */
self.addEventListener('message', (event) => {
  if (!event.data) return

  if (event.data.type === 'SYNC_LAST_INCIDENT_ID') {
    if (typeof event.data.lastId === 'number') {
      lastSeenIncidentId = event.data.lastId
      notifiedIncidentIds.add(event.data.lastId)
    }
    event.waitUntil(startBackgroundPollLoop())
    return
  }

  if (event.data.type === 'START_BACKGROUND_WATCH') {
    if (typeof event.data.lastId === 'number') {
      lastSeenIncidentId = event.data.lastId
      notifiedIncidentIds.add(event.data.lastId)
    }
    event.waitUntil(startBackgroundPollLoop())
    return
  }

  if (event.data.type === 'SHOW_INCIDENT_NOTIFICATION') {
    const payload = event.data.payload || {}
    if (payload.incident?.id) {
      notifiedIncidentIds.add(payload.incident.id)
      lastSeenIncidentId = Math.max(lastSeenIncidentId || 0, payload.incident.id)
    }
    const options = buildHeadsUpOptions(payload)
    event.waitUntil(
      self.registration.showNotification(
        payload.title || 'PERINGATAN KTR: Merokok Terdeteksi',
        options
      )
    )
  }
})

/* 4. Click on Notification -> Focus or Open PWA Window */
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  if (event.action === 'dismiss') {
    return
  }
  const incidentData = event.notification.data?.incident || null

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.focus()
          client.postMessage({
            type: 'NOTIFICATION_CLICK_OPEN_INCIDENTS',
            incident: incidentData,
          })
          return
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow('/')
      }
    })
  )
})
