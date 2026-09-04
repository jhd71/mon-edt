/* Emploi du temps — service worker
   Network First partout, cache seulement en secours hors ligne.
   (Ne jamais repasser en Cache First : une page neuve arriverait sans son style.) */
const CACHE = "edt-soleane-v11";
const FICHIERS = ["./", "./index.html", "./manifest.json", "./icon-192.png", "./icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(FICHIERS)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((noms) => Promise.all(noms.filter((n) => n !== CACHE).map((n) => caches.delete(n))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;                                  // pas les écritures Supabase
  if (new URL(req.url).origin !== self.location.origin) return;      // pas les CDN ni l'API

  e.respondWith(
    fetch(req)
      .then((res) => {
        const copie = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copie));
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match("./index.html")))
  );
});
