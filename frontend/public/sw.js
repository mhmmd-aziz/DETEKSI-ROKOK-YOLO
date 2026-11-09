/* SmokeGuard AI — PWA & Hybrid FCM/Local Service Worker */
const CACHE_NAME = 'smokeguard-pwa-v2'

self.addEventListener('install', (event) => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

/* Handle Push Events from FCM / Web Push Server */
self.addEventListener('push', (event) => {
  let payload = {
    title: 'PERINGATAN: Pelanggaran Merokok Terdeteksi',
    body: 'Terdeteksi aktivitas merokok pada kamera pengawas KTR.',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    image: null,
    tag: 'smokeguard-alert',
    data: { url: '/' },
  }

  if (event.data) {
    try {
      const json = event.data.json()
      const notif = json.notification || json
      payload.title = notif.title || payload.title
      payload.body = notif.body || payload.body
      if (notif.image) payload.image = notif.image
      if (json.data) payload.data = json.data
    } catch (e) {
      payload.body = event.data.text()
    }
  }

  const options = {
    body: payload.body,
    icon: payload.icon,
    badge: payload.badge,
    tag: payload.tag,
    renotify: true,
    requireInteraction: false,
    vibrate: [250, 120, 250, 120, 400],
    data: payload.data,
  }
  if (payload.image) {
    options.image = payload.image
  }

  event.waitUntil(self.registration.showNotification(payload.title, options))
})

/* Handle Direct Trigger from PWA Client (Zero-Latency USB/Localhost Notification) */
self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'SHOW_INCIDENT_NOTIFICATION') return

  const { title, body, image, tag, incident } = event.data.payload || {}
  const options = {
    body: body || 'Aktivitas merokok terkonfirmasi pada kawasan tanpa rokok.',
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    tag: tag || 'smokeguard-incident',
    renotify: true,
    requireInteraction: false,
    vibrate: [250, 120, 250, 120, 400],
    data: { url: '/', incident: incident || null },
  }
  if (image) {
    options.image = image
  }

  event.waitUntil(
    self.registration.showNotification(
      title || 'PERINGATAN KTR: Merokok Terdeteksi',
      options
    )
  )
})

/* Click on Notification -> Focus or Open PWA Window */
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
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
