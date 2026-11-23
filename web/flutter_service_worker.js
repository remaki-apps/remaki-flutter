// ─────────────────────────────────────────────────────────────────────────────
// Remaki Flutter Service Worker
// Strategy:
//   - Network-First for entry/boot files (index.html, flutter_bootstrap.js, version.json)
//   - Cache-First for static assets (fonts, icons, images)
//   - Never cache API calls
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_NAME = 'remaki-cache-v3';

// Essential entry files that must always be fresh from server when online
const NETWORK_FIRST_URLS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
  '/main.dart.js',
  '/version.json',
];

// App shell files to precache for offline availability
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/flutter_bootstrap.js',
  '/version.json',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
];

// ─────────────────────────────────────────────────────────────────────────────
// Install Event: Precache app shell
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[SW] Installing new Remaki service worker...');
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Precaching app shell');
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('[SW] Pre-cache failed (non-critical):', err);
      });
    })
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Activate Event: Purge old caches & claim clients
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating new Remaki service worker...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Purging outdated cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('[SW] Activation complete - claiming clients');
      return self.clients.claim();
    })
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Fetch Event
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip non-http requests
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // 1. API calls & Service Worker scripts: always network directly, never cached
  const isBypass =
    url.pathname.includes('/api/') ||
    url.pathname.includes('firebase-messaging-sw.js') ||
    url.hostname !== self.location.hostname;

  if (isBypass || request.method !== 'GET') {
    event.respondWith(fetch(request));
    return;
  }

  // 2. Network-First for entry and version files (always load fresh UI when online)
  const isNetworkFirst = NETWORK_FIRST_URLS.some((p) => url.pathname === p || url.pathname.endsWith(p));
  if (isNetworkFirst) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response && response.status === 200) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(async () => {
          // If offline or network error, fallback to cached entry
          const cached = await caches.match(request);
          if (cached) return cached;
          const fallback = await caches.match('/');
          if (fallback) return fallback;
          return new Response('Offline', { status: 503, statusText: 'Service Unavailable' });
        })
    );
    return;
  }

  // 3. Cache-First for static assets (hashed JS, icons, fonts)
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) {
        return cached;
      }
      return fetch(request).then((response) => {
        if (response && response.status === 200) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      });
    })
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Message Handler: skipWaiting support
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('message', (event) => {
  if (event.data && (event.data.type === 'SKIP_WAITING' || event.data === 'skipWaiting')) {
    console.log('[SW] skipWaiting requested');
    self.skipWaiting();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Notification Click Handler (Web Native Notifications)
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetRoute = event.notification.data?.route || '/';
  const targetUrl = targetRoute.startsWith('http')
    ? targetRoute
    : self.registration.scope + '#/' + (targetRoute.startsWith('/') ? targetRoute.slice(1) : targetRoute);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let client of windowClients) {
        if ('focus' in client) {
          if ('navigate' in client) {
            client.navigate(targetUrl);
          }
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

console.log('[SW] Service Worker script loaded');