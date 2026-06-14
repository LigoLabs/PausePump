/* PausePump — service worker (mode hors-ligne + cache-busting).
   __BUILD_VERSION__ est remplacé par le SHA du commit pendant la CI.
   Comme le nom du cache et les URLs versionnées changent à chaque déploiement,
   le SW se réinstalle et récupère toujours la dernière version. */
const VERSION = '__BUILD_VERSION__';
const CACHE = 'pausepump-' + VERSION;
const V = '?v=' + VERSION;

// Chemins relatifs (résolus depuis le scope du SW) → compatibles GitHub Pages (/PausePump/).
const ASSETS = [
  './',
  './index.html',
  './css/styles.css' + V,
  './js/app.js' + V,
  './manifest.json' + V,
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-512.png',
  './icons/apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  // Navigations : réseau d'abord (toujours la dernière page), repli sur le cache.
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req).catch(() => caches.match(req, { ignoreSearch: true })
        .then((r) => r || caches.match('./index.html')))
    );
    return;
  }

  // Autres ressources : cache d'abord (les URLs sont versionnées), sinon réseau.
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE).then((cache) => cache.put(req, copy));
        }
        return res;
      }).catch(() => caches.match(req, { ignoreSearch: true }));
    })
  );
});

// Clic sur une notification → ramène l'app au premier plan.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const c of clientsArr) { if ('focus' in c) return c.focus(); }
      if (self.clients.openWindow) return self.clients.openWindow('./');
    })
  );
});
