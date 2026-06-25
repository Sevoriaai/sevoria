// Lightweight cookie/storage notice. Essential-only, so this is a notice (not a
// consent gate). Shows once until dismissed; stores the choice in localStorage.
(function () {
  try {
    if (localStorage.getItem("ck_ok") === "1") return;
  } catch (e) { return; }

  function mk() {
    var bar = document.createElement("div");
    bar.setAttribute("role", "note");
    bar.style.cssText =
      "position:fixed;left:16px;right:16px;bottom:16px;max-width:560px;margin:0 auto;z-index:9999;" +
      "background:#16181d;color:#ece7db;border:1px solid rgba(236,231,219,.14);border-radius:14px;" +
      "padding:14px 16px;display:flex;gap:14px;align-items:center;flex-wrap:wrap;" +
      "box-shadow:0 18px 50px -20px rgba(0,0,0,.6);font:14px/1.5 'Hanken Grotesk',system-ui,sans-serif;";
    bar.innerHTML =
      '<span style="flex:1;min-width:220px">Sevoria uses essential cookies and local storage to keep you signed in and remember your settings. No ads, no tracking. ' +
      '<a href="cookies.html" style="color:#c2922e;text-decoration:underline">Learn more</a>.</span>';
    var btn = document.createElement("button");
    btn.textContent = "Got it";
    btn.style.cssText =
      "background:#c2922e;color:#1c1407;border:none;border-radius:9px;padding:9px 18px;font:inherit;font-weight:600;cursor:pointer;flex:none;";
    btn.onclick = function () { try { localStorage.setItem("ck_ok", "1"); } catch (e) {} bar.remove(); };
    bar.appendChild(btn);
    document.body.appendChild(bar);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mk);
  else mk();
})();
