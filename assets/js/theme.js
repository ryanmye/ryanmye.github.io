/* Light/dark theme toggle.
   All colors live in styles.css. This script only sets data-theme on <html>
   and keeps the toggle button's state in sync. With no saved choice the OS
   preference applies via the CSS media query, and the page follows OS changes
   live. A click saves an explicit choice to localStorage["theme"]. */
(function () {
  var KEY = 'theme';
  var root = document.documentElement;
  var mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  // Older versions of the site stored one of five palette names.
  function normalize(value) {
    if (value === 'warm' || value === 'linen' || value === 'pure') return 'light';
    if (value === 'barely' || value === 'dark-mono') return 'dark';
    return value === 'light' || value === 'dark' ? value : null;
  }

  function saved() {
    try { return normalize(localStorage.getItem(KEY)); } catch (e) { return null; }
  }

  function effective() {
    return root.getAttribute('data-theme') || (mq && mq.matches ? 'dark' : 'light');
  }

  // The label stays fixed ("Dark theme"); aria-pressed carries the state, so a
  // screen reader announces "Dark theme, toggle button, pressed/not pressed".
  function updateButton() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;
    btn.setAttribute('aria-pressed', effective() === 'dark' ? 'true' : 'false');
  }

  function apply(theme) {
    root.setAttribute('data-theme', theme);
    try { localStorage.setItem(KEY, theme); } catch (e) { /* private mode */ }
    updateButton();
  }

  var choice = saved();
  if (choice) root.setAttribute('data-theme', choice);
  updateButton();

  if (mq && mq.addEventListener) {
    mq.addEventListener('change', function () {
      if (saved()) return;
      root.removeAttribute('data-theme');
      updateButton();
    });
  }

  var btn = document.getElementById('theme-toggle');
  if (btn) {
    btn.addEventListener('click', function () {
      apply(effective() === 'dark' ? 'light' : 'dark');
    });
  }
})();
