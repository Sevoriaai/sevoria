// Register the service worker so Sevoria is installable to the home screen.
// Scope is the page's directory (the /sevoria/ GitHub Pages subpath).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", function () {
    navigator.serviceWorker.register("sw.js").catch(function () {});
  });
}
