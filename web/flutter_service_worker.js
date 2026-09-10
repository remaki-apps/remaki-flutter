// ─────────────────────────────────────────────────────────────────────────────
// Remaki Flutter Service Worker - Enhanced with Cache Management
// ─────────────────────────────────────────────────────────────────────────────

// Update this on every deployment for cache busting
const CACHE_VERSION = 'remaki-cache-v' + new Date().getTime();
const CACHE_NAME = CACHE_VERSION;

// List of URLs to precache
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
        // Don't fail installation if precache fails - app can work online
      });
    })
  );
  // Force activation immediately
  self.skipWaiting();
});

// ─────────────────────────────────────────────────────────────────────────────
// Activate Event: Clean up old caches
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      console.log('[SW] Found caches:', cacheNames);
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
      return self.clients.claim(); // Take control immediately
    })
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Fetch Event: Network-first strategy with fallback to cache
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Skip chrome extensions and other schemes
  if (!url.protocol.startsWith('http')) {
    return;
  }

  // For navigation requests (HTML), use network-first
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          // Cache the new response
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(request, responseToCache);
          });
          return response;
        })
        .catch(() => {
          // Fall back to cache if offline
          return caches.match(request).then((cached) => {
            if (cached) {
              console.log('[SW] Serving from cache (offline):', request.url);
              return cached;
            }
            // If no cache, return offline page if needed
            return fetch(request);
          });
        })
    );
    return;
  }

  // For assets and API calls, use cache-first with network fallback
  if (request.method === 'GET') {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) {
          // Check for updates in background
          fetch(request)
            .then((response) => {
              if (response && response.status === 200) {
                caches.open(CACHE_NAME).then((cache) => {
                  cache.put(request, response);
                });
              }
            })
            .catch(() => {
              // Network failed, use cache
            });
          return cached;
        }

        // Not in cache, fetch from network
        return fetch(request)
          .then((response) => {
            // Cache successful responses
            if (response && response.status === 200) {
              const responseToCache = response.clone();
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(request, responseToCache);
              });
            }
            return response;
          })
          .catch((err) => {
            console.error('[SW] Fetch failed:', request.url, err);
            // Try cache as last resort
            return caches.match(request);
          });
      })
    );
    return;
  }

  // For non-GET requests, go straight to network
  event.respondWith(fetch(request));
});

// ─────────────────────────────────────────────────────────────────────────────
// Message Handler: Support SKIP_WAITING from index.html
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    console.log('[SW] Received SKIP_WAITING message');
    self.skipWaiting();
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// Periodic Background Sync (optional - update app periodically)
// ─────────────────────────────────────────────────────────────────────────────
self.addEventListener('sync', (event) => {
  if (event.tag === 'remaki-sync') {
    console.log('[SW] Background sync triggered');
    event.waitUntil(
      fetch('/api/health')
        .then(() => console.log('[SW] Sync successful'))
        .catch((err) => console.log('[SW] Sync failed (offline):', err))
    );
  }
});

console.log('[SW] Service Worker script loaded');