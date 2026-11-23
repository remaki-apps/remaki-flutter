// Firebase Cloud Messaging Service Worker for Web Push
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker with remaki-apps credentials
firebase.initializeApp({
  apiKey: "AIzaSyCaLBY8wjDpL4EQVu1AtWIpjhtk1ZaxcuQ",
  projectId: "remaki-apps",
  messagingSenderId: "260854340023",
  appId: "1:260854340023:web:remaki_web"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'Remaki Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification banner click -> focus or open window and redirect route
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetRoute = event.notification.data?.route || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let client of windowClients) {
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          client.navigate(targetRoute);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetRoute);
      }
    })
  );
});
