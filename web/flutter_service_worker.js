// ─────────────────────────────────────────────────────────────────────────────
// Remaki Flutter Service Worker
// Strategy:
//   - App shell (HTML, JS, assets): cache-first with background update
//   - API calls: always network, never cached
// ─────────────────────────────────────────────────────────────────────────────

const CACHE_NAME = 'remaki-cache-v1';

// App shell files to precache
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/flutter_bootstrap.js',
  '/assets/AssetManifest.json',
  '/assets/FontManifest.json',
];

// ─────────────────────────────────────────────────────────────────────────────
// Install Event: Cache app shell
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[SW] Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Pre-caching app shell');
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('[SW] Pre-cache failed (non-critical):', err);
      });
    })
  );
  // Activate immediately but do NOT skipWaiting to avoid reload loops
  // Use self.skipWaiting() only if you explicitly want to force the new SW
});

// ─────────────────────────────────────────────────────────────────────────────
// Activate Event: Clean up old caches
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', cacheName);
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

  // Skip non-http requests (chrome-extension, etc.)
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // ── API calls: always go to network, never use cache ──────────────────────
  // Covers any path with /api/ in it, or calls to external API hosts
  const isApiCall =
    url.pathname.includes('/api/') ||
    url.hostname !== self.location.hostname;

  if (isApiCall || request.method !== 'GET') {
    // Pass through to network directly, no caching
    event.respondWith(fetch(request));
    return;
  }

  // ── App shell: cache-first ─────────────────────────────────────────────────
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) {
        // Serve from cache; update in background (stale-while-revalidate)
        fetch(request)
          .then((response) => {
            if (response && response.status === 200) {
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(request, response);
              });
            }
          })
          .catch(() => { /* Network unavailable - cache is fine */ });
        return cached;
      }

      // Not in cache — fetch from network and cache it
      return fetch(request).then((response) => {
        if (response && response.status === 200) {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
        }
        return response;
      }).catch((err) => {
        console.error('[SW] Fetch failed:', request.url, err);
        return caches.match(request);
      });
    })
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Message Handler
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Received SKIP_WAITING message');
    self.skipWaiting();
  }
});

console.log('[SW] Service Worker script loaded');