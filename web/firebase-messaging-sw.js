// ─────────────────────────────────────────────────────────────────────────────
// Firebase Cloud Messaging Service Worker
// Handles background push messages and notification click events for Remaki Web.
// ─────────────────────────────────────────────────────────────────────────────

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
firebase.initializeApp({
  apiKey: "AIzaSyCaLBY8wjDpL4EQVu1AtWIpjhtk1ZaxcuQ",
  projectId: "remaki-apps",
  messagingSenderId: "260854340023",
  appId: "1:260854340023:web:9bf29859f0bb5c87723032"
});

const messaging = firebase.messaging();

// ── Handle background messages (tab hidden / browser minimised) ───────────────
// Called when Firebase JS SDK routes the push to this service worker.
messaging.onBackgroundMessage((payload) => {
  console.log('[FCM-SW] onBackgroundMessage received:', payload);
  const title = payload.notification?.title || payload.data?.title || 'Remaki';
  const body  = payload.notification?.body  || payload.data?.body  || '';
  const route = payload.data?.route || '/';

  self.registration.showNotification(title, {
    body,
    icon:              '/icons/Icon-192.png',
    badge:             '/icons/Icon-192.png',
    data:              { route, ...(payload.data || {}) },
    requireInteraction: true,
    tag:               `remaki-${payload.data?.entityType || 'push'}-${Date.now()}`,
  });
});

// ── Raw push event fallback ───────────────────────────────────────────────────
// Belt-and-suspenders: if the Firebase compat SDK does NOT intercept the push
// event (e.g. when the payload has no notification field), this raw handler
// still shows a notification so nothing is silently dropped.
self.addEventListener('push', (event) => {
  // The compat SDK sets self._firebaseMessagingHandled = true when it handles the event.
  // We only act if it did NOT handle it.
  if (self._firebaseMessagingHandled) return;

  console.log('[FCM-SW] Raw push event (compat SDK did not handle):', event.data?.text());
  let payload = {};
  try { payload = event.data?.json() || {}; } catch (_) {}

  const title = payload.notification?.title || payload.data?.title || 'Remaki';
  const body  = payload.notification?.body  || payload.data?.body  || '';
  const route = payload.data?.route || '/';

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon:              '/icons/Icon-192.png',
      badge:             '/icons/Icon-192.png',
      data:              { route, ...(payload.data || {}) },
      requireInteraction: true,
      tag:               `remaki-raw-${Date.now()}`,
    })
  );
});

// ── Notification click → focus the app tab and deep-link ─────────────────────
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const route = event.notification.data?.route || '/';
  // Build a proper hash URL: https://remaki-flutter-qa.vercel.app/#/tenant_complaints
  const targetUrl = route.startsWith('http')
    ? route
    : self.registration.scope.replace(/\/$/, '') + '/#' + (route.startsWith('/') ? route : '/' + route);

  console.log('[FCM-SW] notificationclick → navigate to:', targetUrl);

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // Focus any existing open Remaki tab
      for (const client of windowClients) {
        if ('focus' in client) {
          if ('navigate' in client) client.navigate(targetUrl);
          return client.focus();
        }
      }
      // No open tab → open a new one
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});
