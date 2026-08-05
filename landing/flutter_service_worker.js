// Kill switch for the service worker the app used to register at the root.
//
// Until now the Flutter app was served from `/`, so every previous visitor has
// a service worker registered with scope `/` that answers navigations from its
// own cache. Moving the app to `/app/` does not remove it: the browser would
// keep serving the cached app shell at `/` and the landing page would never
// appear — silently, and only for people who had visited before, which is the
// worst kind of bug to find.
//
// The browser re-fetches this file on navigation and, seeing it changed,
// installs it. It then clears every cache, unregisters itself, and reloads any
// open tab so the real page loads. After that first visit it is gone.
//
// This file must keep its name and stay at the root for as long as any
// returning visitor might still be carrying the old registration.

self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys()
      .then(function (names) {
        return Promise.all(names.map(function (n) { return caches.delete(n); }));
      })
      .then(function () { return self.registration.unregister(); })
      .then(function () { return self.clients.matchAll({ type: 'window' }); })
      .then(function (clients) {
        clients.forEach(function (client) { client.navigate(client.url); });
      })
  );
});

// Never answer from cache while we are on the way out.
self.addEventListener('fetch', function () {});
