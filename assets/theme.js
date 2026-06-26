// Apply the user's saved theme (set in the chat app) or their OS preference to
// the marketing/legal pages, so moving between dark chat and these pages doesn't
// flash a bright screen. Runs synchronously in <head> before paint.
(function () {
  try {
    var m = localStorage.getItem("ls_theme") || "system";
    var dark = m === "dark" || (m === "system" && window.matchMedia && matchMedia("(prefers-color-scheme: dark)").matches);
    document.documentElement.setAttribute("data-theme", dark ? "dark" : "light");
  } catch (e) {}
})();
