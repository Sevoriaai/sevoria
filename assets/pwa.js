// Register the service worker so Sevoria is installable to the home screen.
// Scope is the page's directory (the /sevoria/ GitHub Pages subpath).
if ("serviceWorker" in navigator) {
  window.addEventListener("load", function () {
    navigator.serviceWorker.register("sw.js").catch(function () {});
  });
}

// Mobile-only "get the app" banner. Hidden once installed or dismissed, and
// never shown on the download page itself.
(function () {
  try {
    var standalone = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone;
    var isMobile = window.matchMedia("(max-width: 820px)").matches || /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
    if (standalone || !isMobile) return;
    if (localStorage.getItem("app_banner_dismissed") === "1") return;
    if (/download\.html$/.test(location.pathname)) return;
  } catch (e) { return; }

  window.addEventListener("load", function () {
    var bar = document.createElement("div");
    bar.style.cssText =
      "position:fixed;left:12px;right:12px;bottom:12px;max-width:520px;margin:0 auto;z-index:9998;" +
      "display:flex;align-items:center;gap:12px;background:#16181d;color:#ece7db;" +
      "border:1px solid rgba(236,231,219,.14);border-radius:16px;padding:12px 14px;" +
      "box-shadow:0 18px 50px -20px rgba(0,0,0,.6);font:14px/1.4 'Hanken Grotesk',system-ui,sans-serif;";
    bar.innerHTML =
      '<span style="font-size:22px;color:#c2922e;line-height:1;flex:none">&#10022;</span>' +
      '<span style="flex:1;min-width:0">Get the Sevoria app — <b style="color:#c2922e">+300 credits</b></span>';
    var go = document.createElement("a");
    go.href = "download.html"; go.textContent = "Get it";
    go.style.cssText = "background:#c2922e;color:#1c1407;border-radius:9px;padding:8px 16px;font-weight:600;text-decoration:none;flex:none;";
    var x = document.createElement("button");
    x.setAttribute("aria-label", "Dismiss"); x.innerHTML = "&times;";
    x.style.cssText = "background:none;border:none;color:#9a958a;font-size:22px;line-height:1;cursor:pointer;flex:none;padding:0 2px;";
    x.onclick = function () { try { localStorage.setItem("app_banner_dismissed", "1"); } catch (e) {} bar.remove(); };
    bar.appendChild(go); bar.appendChild(x);
    document.body.appendChild(bar);
  });
})();
