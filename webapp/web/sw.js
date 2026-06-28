// Minimal service worker: caches the app shell for installability and offline
// loading. API requests are always fetched fresh (network-only).
const CACHE = "ambilight-shell-v1";
const SHELL = [
  ".",
  "index.html",
  "style.css",
  "app.js",
  "manifest.webmanifest",
  "icon.svg",
];

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Base path under which the SW is registered (e.g. "/" or "/ambilight/"),
// derived from the SW's own location so it works at root or behind a sub-path.
const BASE = new URL("./", self.location).pathname;

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (url.pathname.startsWith(BASE + "api/") || url.pathname.startsWith("/api/")) {
    return; // never cache API calls
  }
  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
