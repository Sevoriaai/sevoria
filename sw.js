// Sevoria service worker — makes the site installable + works offline-ish.
// Network-first for same-origin GETs (so new deploys always win), with a cache
// fallback when offline. Never touches Supabase, the AI tunnel, or CDNs.
const CACHE = "sevoria-v0_8";
const SHELL = [
  "./", "./index.html", "./chat.html", "./login.html",
  "./assets/styles.css", "./manifest.webmanifest",
  "./assets/icon-192.png", "./assets/icon-512.png", "./assets/favicon.svg",
];

self.addEventListener("install", (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL).catch(() => {})));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return; // leave Supabase / AI / CDN alone
  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match("./index.html")))
  );
});
