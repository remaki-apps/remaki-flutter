// ─────────────────────────────────────────────────────────────────────────────
// Remaki Flutter Service Worker
// Strategy:
//   - Network-First for entry/boot files (index.html, flutter_bootstrap.js, version.json)
//   - Cache-First for static assets (fonts, icons, images)
//   - Never cache API calls
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_NAME = 'remaki-cache-v2';

// Essential entry files that must always be fresh from server when online
const NETWORK_FIRST_URLS = [
  '/',
  '/index.html',
  '/flutter_bootstrap.js',
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

  // 1. API calls: always network directly, never cached
  const isApiCall =
    url.pathname.includes('/api/') ||
    url.hostname !== self.location.hostname;

  if (isApiCall || request.method !== 'GET') {
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
        .catch(() => {
          // If offline or network error, fallback to cached entry
          return caches.match(request);
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

console.log('[SW] Service Worker script loaded');