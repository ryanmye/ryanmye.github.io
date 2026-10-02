// Studio: the local editor for posts, drafts, and albums (/editor/, dev-only).
// Talks to scripts/local_editor_server.rb (default http://127.0.0.1:4001).
// Plain JS, no build step. Sections: helpers, API, toasts/dialogs, library,
// body editor, tags, photos, form state + local backups, actions, git publish,
// wiring.
(function () {
  'use strict';

  var root = document.getElementById('main-content');
  if (!root || !root.classList.contains('studio')) return;

  // API origin: ?api=<port> in the page URL wins, then the layout's
  // data-api-origin (bin/dev sets the port through STUDIO_API_PORT).
  var apiParam = new URLSearchParams(location.search).get('api');
  var API = /^\d+$/.test(apiParam || '') ? 'http://127.0.0.1:' + apiParam : (root.dataset.apiOrigin || 'http://127.0.0.1:4001');
  // Previews open on the Jekyll dev server that served this page.
  var SITE = window.location.origin;
  var MAX_PHOTOS = 25;
  var UNDO_MS = 5000;
  var BACKUP_PREFIX = 'studio:backup:';
  var isMac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  // ---------- helpers ----------

  function $(id) { return document.getElementById(id); }
  function enc(s) { return encodeURIComponent(s); }

  // el('input', 'cls', null, { type: 'text' }): props are set as DOM properties.
  function el(tag, cls, text, props) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    for (var k in props || {}) node[k] = props[k];
    return node;
  }

  function button(label, cls, onClick, props) {
    var b = el('button', cls, label, props);
    b.type = 'button';
    if (onClick) b.addEventListener('click', onClick);
    return b;
  }

  function each(list, fn) { Array.prototype.forEach.call(typeof list === 'string' ? document.querySelectorAll(list) : list, fn); }

  function esc(s) { return String(s).replace(/[&<>"]/g, function (c) { return '&#' + c.charCodeAt(0) + ';'; }); }

  function debounce(fn, ms) {
    var t;
    return function () { clearTimeout(t); t = setTimeout(fn, ms); };
  }

  var uidN = 0;
  function uid() { uidN += 1; return 'p' + uidN; }

  function storage(fn) {
    try { return fn(window.localStorage); } catch (e) { return null; }
  }

  // "2026-03-17T01:15:00-05:00" -> "Mar 17, 2026" (reads the literal date, no TZ shifts)
  function shortDate(s) {
    var m = String(s || '').match(/^(\d{4})-(\d{2})-(\d{2})/);
    return m ? MONTHS[+m[2] - 1] + ' ' + (+m[3]) + ', ' + m[1] : '';
  }

  // Front matter date -> value for <input type="datetime-local"> (wall time as written)
  function toInputDate(s) {
    var d = String(s || '').trim().match(/^(\d{4}-\d{2}-\d{2})(?:[T\s](\d{2}):(\d{2}))?/);
    return d ? d[1] + 'T' + (d[2] || '00') + ':' + (d[3] || '00') : '';
  }

  function nowInputDate() {
    var d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 16);
  }

  function relTime(ts) {
    var s = Math.round((Date.now() - ts) / 1000);
    if (s < 45) return 'just now';
    if (s < 3600) return Math.round(s / 60) + ' min ago';
    if (s < 86400) return Math.round(s / 3600) + ' h ago';
    return Math.round(s / 86400) + ' d ago';
  }

  function plural(n, word) { return n + ' ' + word + (n === 1 ? '' : 's'); }

  function isTyping(t) {
    return t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName));
  }

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) return navigator.clipboard.writeText(text);
    var ta = document.body.appendChild(el('textarea', null, null, { value: text }));
    ta.select();
    document.execCommand('copy');
    ta.remove();
    return Promise.resolve();
  }

  // ---------- API ----------

  function api(method, path, body) {
    var opts = { method: method, headers: {} };
    if (body !== undefined) {
      opts.headers['Content-Type'] = 'application/json';
      opts.body = JSON.stringify(body);
    }
    return fetch(API + path, opts).then(function (res) {
      if (res.status === 204) return null;
      return res.text().then(function (text) {
        var data = null;
        try { data = text ? JSON.parse(text) : null; } catch (e) { /* plain-text error */ }
        if (res.status === 403 && /Forbidden origin/.test(text)) apiRejected();
        if (!res.ok) {
          var err = new Error((data && data.error) || text || ('HTTP ' + res.status));
          err.status = res.status;
          err.data = data;
          throw err;
        }
        return data;
      });
    }, function () {
      apiDown();
      throw new Error('The editor API is not reachable.');
    });
  }

  // Multipart upload with progress (fetch has no upload progress).
  function upload(file, opts, onProgress) {
    return new Promise(function (resolve, reject) {
      var fd = new FormData();
      fd.append('image', file, file.name || 'image.png');
      if (opts.album) fd.append('album', 'true');
      else fd.append('draft', opts.draft ? 'true' : 'false');
      var xhr = new XMLHttpRequest();
      xhr.open('POST', API + '/images');
      xhr.upload.onprogress = function (e) {
        if (e.lengthComputable && onProgress) onProgress(e.loaded / e.total);
      };
      xhr.onload = function () {
        if (xhr.status >= 200 && xhr.status < 300) resolve(JSON.parse(xhr.responseText));
        else reject(new Error('Upload failed: ' + (xhr.responseText || xhr.status)));
      };
      xhr.onerror = function () { apiDown(); reject(new Error('Upload failed: the editor API is not reachable.')); };
      xhr.send(fd);
    });
  }

  function imgUrl(src, thumb) {
    return /^\/assets\//.test(src) ? API + src + (thumb ? '?variant=thumb' : '') : src;
  }

  // ---------- toasts + dialogs ----------

  var toastBox = $('studio-toasts');

  // toast(message, {type, duration (0 = sticky), action, onAction, onExpire})
  function toast(message, opts) {
    opts = opts || {};
    var t = el('div', 'studio-toast' + (opts.type ? ' is-' + opts.type : ''));
    var text = el('span', null);
    if (message instanceof Node) text.appendChild(message); else text.textContent = message;
    t.appendChild(text);
    var done = false;
    var timer = null;
    function dismiss(expired) {
      if (done) return;
      done = true;
      clearTimeout(timer);
      t.remove();
      if (expired && opts.onExpire) opts.onExpire();
    }
    if (opts.action) t.appendChild(button(opts.action, null, function () { dismiss(false); if (opts.onAction) opts.onAction(); }));
    t.appendChild(button('×', null, function () { dismiss(true); }, { ariaLabel: 'Dismiss' }));
    var duration = opts.duration == null ? (opts.type === 'error' ? 8000 : 3500) : opts.duration;
    if (duration) {
      var bar = el('span', 'studio-toast-timer');
      bar.style.animationDuration = duration + 'ms';
      t.appendChild(bar);
      timer = setTimeout(function () { dismiss(true); }, duration);
    }
    toastBox.appendChild(t);
    return { dismiss: dismiss, setText: function (s) { text.textContent = s; } };
  }

  function fail(err) {
    setStatus('error', 'Error');
    toast(err && err.message ? err.message : String(err), { type: 'error' });
  }

  // Resolves true when the user confirms.
  function confirmDialog(title, body, okLabel) {
    var dlg = $('dlg-confirm');
    $('confirm-title').textContent = title;
    $('confirm-body').textContent = body;
    $('confirm-ok').textContent = okLabel || 'OK';
    dlg.returnValue = '';
    dlg.showModal();
    return new Promise(function (resolve) {
      dlg.addEventListener('close', function () { resolve(dlg.returnValue === 'ok'); }, { once: true });
    });
  }

  // Typed confirmation: the Delete button unlocks only when the slug matches.
  function deleteDialog(name, path, slug) {
    var dlg = $('dlg-delete');
    var input = $('delete-input');
    var ok = $('delete-ok');
    $('delete-name').textContent = '“' + name + '”';
    $('delete-path').textContent = path;
    $('delete-slug').textContent = slug;
    input.value = '';
    ok.disabled = true;
    input.oninput = function () { ok.disabled = input.value.trim() !== slug; };
    dlg.returnValue = '';
    dlg.showModal();
    input.focus();
    return new Promise(function (resolve) {
      dlg.addEventListener('close', function () { resolve(dlg.returnValue === 'ok' && input.value.trim() === slug); }, { once: true });
    });
  }

  // ---------- state ----------

  var state = {
    items: { post: [], draft: [], album: [] },
    current: null,   // { type: 'post'|'album', kind: 'post'|'draft'|null, slug: string|null }
    loaded: null,    // last item fetched from the API (path, url, ...)
    photos: [],      // [{ id, src, caption, album, fromBody, uploading, progress, localUrl }]
    tags: [],
    baseline: '',    // snapshot() right after load/save; differs => unsaved changes
    saving: false,
    savedAt: 0,
    filling: false,
    online: true,
    git: null,
    pendingDeletes: {},
    version: null     // content hash of the open file, sent back on save (409 if stale)
  };

  function isPost() { return !!state.current && state.current.type === 'post'; }
  function isAlbum() { return !!state.current && state.current.type === 'album'; }

  function refKey(ref) {
    if (!ref) return '';
    if (!ref.slug) return 'new-' + ref.type;
    return ref.type === 'album' ? 'album:' + ref.slug : ref.kind + ':' + ref.slug;
  }

  function refHash(ref) {
    if (!ref.slug) return '#new-' + ref.type;
    return ref.type === 'album' ? '#album/' + ref.slug : '#' + ref.kind + '/' + ref.slug;
  }

  function sameRef(a, b) { return !!a && !!b && refKey(a) === refKey(b); }

  function itemPath(ref) {
    return ref.type === 'album' ? '/albums/' + enc(ref.slug) : '/posts/' + enc(ref.kind) + '/' + enc(ref.slug);
  }

  // ---------- library (sidebar) ----------

  var search = $('studio-search');
  var groups = {};
  each('.studio-group', function (g) {
    groups[g.dataset.group] = g;
    var head = g.querySelector('.studio-group-head');
    var saved = storage(function (s) { return s.getItem('studio:group:' + g.dataset.group); });
    if (saved === 'closed') head.setAttribute('aria-expanded', 'false');
    head.addEventListener('click', function () {
      var open = head.getAttribute('aria-expanded') !== 'true';
      head.setAttribute('aria-expanded', String(open));
      storage(function (s) { s.setItem('studio:group:' + g.dataset.group, open ? 'open' : 'closed'); });
    });
  });

  function loadLists() {
    return Promise.all([api('GET', '/posts'), api('GET', '/albums')]).then(function (res) {
      var byDate = function (a, b) { return String(b.date || '').localeCompare(String(a.date || '')); };
      state.items.post = res[0].filter(function (p) { return p.kind === 'post'; }).sort(byDate);
      state.items.draft = res[0].filter(function (p) { return p.kind === 'draft'; })
        .sort(function (a, b) { return a.title.localeCompare(b.title); });
      state.items.album = res[1].sort(byDate);
      setOnline(true);
      renderSidebar();
      renderWelcome();
    });
  }

  function mostRecentItem() {
    return state.items.post.concat(state.items.draft, state.items.album)
      .filter(function (it) { return !it.error; })
      .sort(function (a, b) { return (b.mtime || 0) - (a.mtime || 0); })[0] || null;
  }

  function itemRef(item) {
    return item.kind === 'album' ? { type: 'album', kind: null, slug: item.slug } : { type: 'post', kind: item.kind, slug: item.slug };
  }

  function rowFor(item) {
    var ref = itemRef(item);
    var btn = button(null, 'studio-row', function () { openItem(ref); closeSidebar(); });
    var title = el('span', 'studio-row-title', item.title);
    if (readBackup(refKey(ref))) {
      title.appendChild(el('span', 'studio-row-dot', null, { title: 'Has unsaved changes backed up in this browser' }));
    }
    var bits = [item.error ? '⚠ front matter does not parse' : item.kind === 'draft' ? (item.date ? 'Draft · ' + shortDate(item.date) : 'Draft') : shortDate(item.date)];
    if (item.kind === 'album' && item.draft) bits.push('draft');
    if (item.image_count) bits.push(plural(item.image_count, 'photo'));
    btn.appendChild(title);
    btn.appendChild(el('span', 'studio-row-meta', bits.filter(Boolean).join(' · ')));
    if (sameRef(ref, state.current)) {
      btn.classList.add('is-current');
      btn.setAttribute('aria-current', 'true');
    }
    return btn;
  }

  function renderSidebar() {
    var q = search.value.trim().toLowerCase();
    Object.keys(groups).forEach(function (key) {
      var list = groups[key].querySelector('.studio-list');
      var items = state.items[key].filter(function (it) {
        if (!q) return true;
        return [it.title, it.slug, it.description, it.excerpt, it.album_title, it.album_caption].concat(it.tags || [])
          .join(' ').toLowerCase().indexOf(q) !== -1;
      });
      list.innerHTML = '';
      groups[key].querySelector('.studio-count').textContent = items.length;
      items.forEach(function (it) { list.appendChild(el('li')).appendChild(rowFor(it)); });
      if (!items.length) list.appendChild(el('li', 'studio-empty', q ? 'No matches' : 'Nothing here yet'));
    });
  }

  function renderWelcome() {
    var box = $('welcome-recent');
    box.innerHTML = '';
    var recent = state.items.post.concat(state.items.album).sort(function (a, b) {
      return String(b.date || '').localeCompare(String(a.date || ''));
    }).slice(0, 4);
    var drafts = state.items.draft.slice(0, 2);
    var all = drafts.concat(recent);
    if (!all.length) return;
    box.appendChild(el('p', 'studio-recent-title', 'Pick up where you left off'));
    var ul = el('ul', 'studio-recent');
    all.forEach(function (it) { ul.appendChild(el('li')).appendChild(rowFor(it)); });
    box.appendChild(ul);
  }

  // Arrow keys move between rows; Enter in the search box opens the first match.
  $('studio-sidebar').addEventListener('keydown', function (e) {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp' && !(e.key === 'Enter' && e.target === search)) return;
    var rows = Array.prototype.slice.call(document.querySelectorAll('.studio-groups .studio-row'))
      .filter(function (r) { return r.offsetParent !== null; });
    if (!rows.length) return;
    if (e.key === 'Enter') { rows[0].click(); return; }
    e.preventDefault();
    var i = rows.indexOf(document.activeElement);
    var next = e.key === 'ArrowDown' ? (i < 0 ? 0 : Math.min(i + 1, rows.length - 1)) : i - 1;
    if (next < 0) search.focus(); else rows[next].focus();
  });
  search.addEventListener('input', renderSidebar);

  // Narrow windows: the library slides over the editor.
  function sidebar(open) {
    root.classList.toggle('is-sidebar-open', open);
    $('studio-scrim').hidden = !open;
    $('btn-sidebar').setAttribute('aria-expanded', String(open));
  }
  function openSidebar() { sidebar(true); }
  function closeSidebar() { sidebar(false); }
  $('btn-sidebar').addEventListener('click', function () { sidebar(!root.classList.contains('is-sidebar-open')); });
  $('studio-scrim').addEventListener('click', closeSidebar);

  // ---------- body editor (Toast UI) ----------

  var editor = null;

  function initEditor() {
    if (editor) return;
    if (!(window.toastui && window.toastui.Editor)) {
      toast('Toast UI Editor did not load (no network?). The body editor is unavailable.', { type: 'error', duration: 0 });
      return;
    }
    editor = new window.toastui.Editor({
      el: $('post-editor'),
      height: '100%',
      initialEditType: 'wysiwyg',
      previewStyle: 'tab',
      usageStatistics: false,
      placeholder: 'Start writing…',
      toolbarItems: [
        ['heading', 'bold', 'italic', 'strike'],
        ['link', 'quote', 'code', 'codeblock'],
        ['ul', 'ol', 'hr'],
        ['image']
      ],
      hooks: { addImageBlobHook: bodyImageHook },
      events: { change: onBodyChange }
    });
    applyEditorTheme();
  }

  function stripApi(md) {
    return md.split(API).join('').split('http://localhost:4001').join('');
  }

  // Markdown as it will be saved: relative image paths wrapped in relative_url.
  function getBody() {
    if (!editor) return '';
    var md = stripApi(editor.getMarkdown());
    return md.replace(/!\[([^\]]*)\]\((\/assets\/[^)\s]+)\)/g, function (_, alt, src) {
      return '![' + alt + "]({{ '" + src + "' | relative_url }})";
    });
  }

  function setBody(md) {
    if (!editor) return;
    var display = String(md || '').replace(/\{\{\s*'(\/assets\/[^']+)'\s*\|\s*relative_url\s*\}\}/g, function (_, src) {
      return API + src;
    });
    editor.setMarkdown(display, false);
    editor.moveCursorToStart(false);
    editor.setScrollTop(0);
  }

  function normSrc(s) {
    s = s.trim();
    var m = s.match(/^\{\{\s*'([^']+)'\s*\|\s*relative_url\s*\}\}$/);
    if (m) s = m[1];
    return stripApi(s);
  }

  // Same rule as the server's extract_body_images: an image alone on its line,
  // optionally followed by a blank line and an *italic caption*.
  function bodyImages(md) {
    var lines = md.split('\n');
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^!\[([^\]]*)\]\(([^)]+)\)\s*$/);
      if (!m) continue;
      var src = normSrc(m[2]);
      if (src.indexOf('/assets/images/') !== 0) continue;
      var cap = m[1];
      var c = (lines[i + 2] || '').match(/^\*(.+)\*$|^_(.+)_$/);
      if ((lines[i + 1] || '').trim() === '' && c) cap = c[1] || c[2];
      out.push({ src: src, caption: cap.trim() });
    }
    return out;
  }

  // Image + *caption* as markdown. WYSIWYG mode cannot insert markdown text,
  // so it hops to the Markdown tab for the insert and back.
  function insertImage(src, alt, caption) {
    if (!editor) return;
    var wysiwyg = !editor.isMarkdownMode();
    if (wysiwyg) editor.changeMode('markdown', true);
    editor.insertText('\n\n![' + alt + '](' + API + src + ')\n\n' + (caption ? '*' + caption + '*\n\n' : ''));
    if (wysiwyg) editor.changeMode('wysiwyg', true);
    syncBodyPhotosSoon();
  }

  // Paste, drag, or the toolbar image button: upload, then let Toast UI insert it.
  // The API keeps JPEG, PNG, GIF, WebP and SVG (sanitized), and converts
  // HEIC/HEIF/AVIF and TIFF/BMP to JPEG. Anything else is skipped here with a
  // toast. Returns the files to keep. (The API checks the bytes again.)
  var IMAGE_EXT = /\.(jpe?g|png|gif|webp|svg|hei[cf]|avif|tiff?|bmp)$/i;
  var IMAGE_TYPE = /^image\/(jpe?g|pjpeg|png|gif|webp|svg\+xml|hei[cf](-sequence)?|avif|tiff|bmp|x-ms-bmp)$/i;
  var SUPPORTED = 'JPEG, PNG, GIF, WebP, SVG, HEIC, AVIF, TIFF or BMP';
  var NEEDS_NEW_API = /\.(svg|hei[cf]|avif|tiff?|bmp)$|^image\/(svg|hei|avif|tiff|bmp|x-ms-bmp)/i;
  var oldApi = false;
  function usableImages(list) {
    var out = [];
    Array.prototype.forEach.call(list, function (f) {
      var name = f.name || 'pasted image';
      if (oldApi && (NEEDS_NEW_API.test(name) || NEEDS_NEW_API.test(f.type || ''))) {
        toast('Skipped ' + name + ': restart bin/dev first, the running editor API cannot handle this type yet.', { type: 'error', duration: 9000 });
      } else if (IMAGE_TYPE.test(f.type || '') || IMAGE_EXT.test(name)) out.push(f);
      else {
        var ext = (name.match(/\.([^.]+)$/) || [])[1];
        toast('Skipped ' + name + ': ' + (ext ? '.' + ext.toLowerCase() + ' files are' : 'that file is') +
          ' not supported. Use ' + SUPPORTED + '.', { type: 'error', duration: 9000 });
      }
    });
    return out;
  }

  // Browsers cannot draw these before upload (HEIC/TIFF), so the tile shows the
  // file name until the API answers with the converted JPEG.
  function needsServerPreview(f) {
    return /hei[cf]|tiff/i.test(f.type || '') || /\.(hei[cf]|tiff?)$/i.test(f.name || '');
  }

  // A toast for what the API did to the file: converted it, or took unsafe
  // parts out of an SVG.
  function uploadNote(name, res) {
    if (res.converted_from) toast('Converted ' + name + ' to JPEG.');
    var n = (res.svg_removed || []).length;
    if (n) toast('Cleaned ' + name + ': removed ' + plural(n, 'part') + ' that could run code or load outside files.', { duration: 7000 });
  }

  // Uploads into the text of the item it started in; if another item is open
  // by the time it finishes, it is not inserted (the temp file is left for
  // "Clean up abandoned uploads").
  function bodyImageHook(blob, callback) {
    if (!usableImages([blob]).length) return;
    var ref = state.current;
    var itemTitle = f.postTitle.value.trim() || 'the new post';
    var name = blob.name || 'pasted image';
    var t = toast('Uploading ' + name + '…', { duration: 0 });
    upload(blob, { draft: $('post-draft').checked }, function (p) {
      t.setText('Uploading ' + name + '… ' + Math.round(p * 100) + '%');
    }).then(function (res) {
      t.dismiss();
      uploadNote(name, res);
      if (!sameRef(ref, state.current)) {
        toast('Image uploaded for “' + itemTitle + '”; it was not inserted because you switched posts.', { duration: 7000 });
        return;
      }
      callback(API + res.url, name.replace(/\.[^.]+$/, ''));
      syncBodyPhotosSoon();
    }, function (err) { t.dismiss(); fail(err); });
  }

  $('body-image-input').addEventListener('change', function (e) {
    each(e.target.files, function (file) {
      bodyImageHook(file, function (url, alt) { insertImage(normSrc(url), alt, ''); });
    });
    e.target.value = '';
  });

  function onBodyChange() {
    if (state.filling) return;
    syncBodyPhotosSoon();
    onFormChange();
  }

  // Keep Toast UI's toolbar icons in step with the site theme.
  function effectiveDark() {
    var t = document.documentElement.getAttribute('data-theme');
    if (t) return t === 'dark';
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }
  function applyEditorTheme() {
    var ui = document.querySelector('#post-editor .toastui-editor-defaultUI');
    if (ui) ui.classList.toggle('toastui-editor-dark', effectiveDark());
  }
  new MutationObserver(applyEditorTheme).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', applyEditorTheme);

  // ---------- tags ----------

  var tagBox = $('post-tags');
  var tagInput = $('post-tag-input');

  function renderTags() {
    each(tagBox.querySelectorAll('.studio-chip'), function (c) { c.remove(); });
    state.tags.forEach(function (tag, i) {
      var chip = el('span', 'studio-chip', tag);
      chip.appendChild(button('×', null, function () {
        state.tags.splice(i, 1); renderTags(); onFormChange(); tagInput.focus();
      }, { ariaLabel: 'Remove tag ' + tag }));
      tagBox.insertBefore(chip, tagInput);
    });
  }

  function addTags(text) {
    var added = false;
    String(text).split(',').forEach(function (t) {
      t = t.trim();
      if (t && state.tags.indexOf(t) === -1) { state.tags.push(t); added = true; }
    });
    if (added) { renderTags(); onFormChange(); }
  }

  tagInput.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' || e.key === ',') {
      e.preventDefault();
      addTags(tagInput.value);
      tagInput.value = '';
    } else if (e.key === 'Backspace' && !tagInput.value && state.tags.length) {
      state.tags.pop();
      renderTags();
      onFormChange();
    }
  });
  tagInput.addEventListener('blur', function () { addTags(tagInput.value); tagInput.value = ''; });
  tagInput.addEventListener('paste', function (e) {
    var text = (e.clipboardData || window.clipboardData).getData('text');
    if (text.indexOf(',') === -1) return;
    e.preventDefault();
    addTags(text);
  });
  tagBox.addEventListener('click', function (e) { if (e.target === tagBox) tagInput.focus(); });

  // ---------- photos ----------

  var panel = $('photos-panel');
  var grid = $('photo-grid');
  var photoSig = '';

  function newPhoto(src, caption, album) {
    return { id: uid(), src: src, caption: caption || '', album: album, fromBody: false };
  }

  function placePhotos(slotId) {
    $(slotId).appendChild(panel);
    panel.classList.add('is-placed');
    $('post-card-fields').hidden = !isPost();
    $('photos-hint').textContent = isAlbum()
      ? 'The first photo is the cover. Drag to reorder.'
      : 'Shown as an album under the post. Dimmed photos are in the text; edit their captions there.';
  }

  // Posts: the album title/caption only show on /gallery/ once there are
  // photos, but stay editable either way.
  function updateCardHint() {
    var has = state.photos.length > 0;
    $('post-card-fields').classList.toggle('is-idle', !has);
    $('card-fields-hint').textContent = has
      ? 'How this post’s photos appear as a card on the gallery page.'
      : 'Used on the gallery page once this post has photos.';
  }

  // Posts: photos found in the body are flagged (dimmed, read-only); body
  // images that disappeared from the text leave the grid unless they were
  // also added as album photos.
  function syncBodyPhotos() {
    if (!isPost() || !editor) return;
    var seen = {};
    var found = bodyImages(getBody());
    found.forEach(function (f) { seen[f.src] = f; });
    state.photos = state.photos.filter(function (p) { return p.uploading || p.album || seen[p.src]; });
    found.forEach(function (f) {
      if (!state.photos.some(function (p) { return p.src === f.src; })) state.photos.push(newPhoto(f.src, f.caption, false));
    });
    state.photos.forEach(function (p) {
      p.fromBody = !!seen[p.src];
      if (p.fromBody) p.caption = seen[p.src].caption;
    });
    renderPhotos();
  }
  var syncBodyPhotosSoon = debounce(syncBodyPhotos, 400);

  function tileAction(label, fn, cls) {
    return button(label, cls, function (e) { e.stopPropagation(); fn(); });
  }

  function renderPhotos(force) {
    var sig = JSON.stringify(state.photos.map(function (p) {
      return [p.id, p.src, p.fromBody, p.uploading, isAlbum(), p.fromBody ? p.caption : ''];
    }));
    $('photos-count').textContent = state.photos.length + ' / ' + MAX_PHOTOS;
    updateCardHint();
    if (!force && sig === photoSig) return;
    photoSig = sig;
    grid.innerHTML = '';
    state.photos.forEach(function (p, i) {
      var fig = el('figure', 'studio-photo' + (p.fromBody ? ' is-body' : '') + (p.uploading ? ' is-uploading' : ''), null, {
        tabIndex: 0, draggable: !p.uploading, ariaLabel: 'Photo ' + (i + 1) + (p.caption ? ': ' + p.caption : '')
      });
      fig.dataset.id = p.id;
      var frame = el('div', 'studio-photo-frame');
      if (p.localUrl || p.src) frame.appendChild(el('img', null, null, { alt: '', loading: 'lazy', draggable: false, src: p.localUrl || imgUrl(p.src, true) }));
      else frame.appendChild(el('span', 'studio-photo-name', p.fileName || 'Uploading'));
      var badge = p.fromBody ? 'In text' : (isAlbum() && i === 0 ? 'Cover' : '');
      if (badge) frame.appendChild(el('span', 'studio-photo-badge', badge));
      if (p.uploading) {
        frame.appendChild(el('div', 'studio-progress')).appendChild(el('span')).style.width = Math.round((p.progress || 0) * 100) + '%';
      } else {
        var acts = el('div', 'studio-photo-actions');
        if (isAlbum() && i > 0) acts.appendChild(tileAction('Use as cover', function () { movePhoto(p.id, 0); }));
        if (isPost() && !p.fromBody) acts.appendChild(tileAction('Insert in body', function () { insertImage(p.src, p.caption || 'photo', p.caption); }));
        if (!p.fromBody) acts.appendChild(tileAction('Remove', function () { removePhoto(p.id); }, 'is-danger'));
        frame.appendChild(acts);
      }
      fig.appendChild(frame);
      var cap = el('input', 'studio-photo-caption', null, {
        type: 'text', value: p.caption, placeholder: p.fromBody ? 'No caption' : 'Add a caption', ariaLabel: 'Caption for photo ' + (i + 1),
        readOnly: p.fromBody, title: p.fromBody ? 'Edit this caption in the text' : ''
      });
      cap.addEventListener('input', function () { p.caption = cap.value; onFormChange(); });
      fig.appendChild(cap);
      grid.appendChild(fig);
    });
  }

  function photoIndex(id) {
    for (var i = 0; i < state.photos.length; i++) if (state.photos[i].id === id) return i;
    return -1;
  }

  function movePhoto(id, to) {
    var from = photoIndex(id);
    if (from < 0 || to < 0 || to >= state.photos.length || from === to) return;
    state.photos.splice(to, 0, state.photos.splice(from, 1)[0]);
    renderPhotos();
    onFormChange();
    var tile = grid.querySelector('[data-id="' + id + '"]');
    if (tile) tile.focus();
  }

  function addFiles(fileList) {
    if (!state.current) return;
    var files = usableImages(fileList);
    var room = MAX_PHOTOS - state.photos.length;
    if (!files.length) return;
    if (room <= 0) { toast('This already has ' + MAX_PHOTOS + ' photos, the maximum.', { type: 'error' }); return; }
    if (files.length > room) {
      toast('Only ' + plural(room, 'more photo') + ' fit (' + MAX_PHOTOS + ' max). Added the first ' + room + '.');
      files = files.slice(0, room);
    }
    files.forEach(function (file) {
      var p = newPhoto('', '', true);
      p.uploading = true;
      p.fileName = file.name || 'image';
      if (!needsServerPreview(file)) p.localUrl = URL.createObjectURL(file);
      state.photos.push(p);
      var ref = state.current;
      upload(file, { album: isAlbum(), draft: isPost() && $('post-draft').checked }, function (frac) {
        p.progress = frac;
        var bar = grid.querySelector('[data-id="' + p.id + '"] .studio-progress span');
        if (bar) bar.style.width = Math.round(frac * 100) + '%';
      }).then(function (res) {
        p.src = res.url;
        p.uploading = false;
        uploadNote(p.fileName, res);
        // Show what was stored (the sanitized SVG, the converted JPEG), not the local file.
        if (p.localUrl && (res.svg_removed || res.converted_from)) { URL.revokeObjectURL(p.localUrl); p.localUrl = null; photoSig = ''; }
        // Only touch the grid of the item this upload started in.
        if (sameRef(ref, state.current)) { renderPhotos(); onFormChange(); }
        else toast('An upload finished after you left that ' + ref.type + ', so it was not added. Add it again there.');
      }, function (err) {
        var i = sameRef(ref, state.current) ? photoIndex(p.id) : -1;
        if (i >= 0) { state.photos.splice(i, 1); renderPhotos(); }
        fail(err);
      });
    });
    renderPhotos();
  }

  // Remove now, with a 5 s undo. The file itself is only deleted after the undo
  // window, and only once no saved post/album references it (see flushDeletes).
  function removePhoto(id) {
    var i = photoIndex(id);
    if (i < 0) return;
    var p = state.photos.splice(i, 1)[0];
    var ref = state.current;
    renderPhotos();
    onFormChange();
    toast('Photo removed', {
      action: 'Undo',
      duration: UNDO_MS,
      onAction: function () {
        if (!sameRef(ref, state.current)) return;
        state.photos.splice(Math.min(i, state.photos.length), 0, p);
        renderPhotos();
        onFormChange();
      },
      onExpire: function () {
        if (p.src) { state.pendingDeletes[p.src] = true; flushDeletes(); }
      }
    });
  }

  // The server refuses ("still referenced") while any saved file still uses the
  // image, so an unsaved removal keeps waiting here until the next save.
  function flushDeletes() {
    Object.keys(state.pendingDeletes).forEach(function (src) {
      if (state.photos.some(function (p) { return p.src === src; })) { delete state.pendingDeletes[src]; return; }
      api('POST', '/images/delete', { src: src }).then(function (res) {
        if (res && (res.deleted || res.reason === 'file not found')) delete state.pendingDeletes[src];
      }, function () { /* retried after the next save */ });
    });
  }

  // Reorder: HTML5 drag and drop, moving the tile live and committing on dragend.
  var dragTile = null;
  grid.addEventListener('dragstart', function (e) {
    var tile = e.target.closest && e.target.closest('.studio-photo');
    if (!tile || e.target.tagName === 'INPUT') return;
    dragTile = tile;
    tile.classList.add('is-dragging');
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', tile.dataset.id);
  });
  grid.addEventListener('dragover', function (e) {
    if (!dragTile) return;
    e.preventDefault();
    var over = e.target.closest && e.target.closest('.studio-photo');
    if (!over || over === dragTile) return;
    var r = over.getBoundingClientRect();
    grid.insertBefore(dragTile, (e.clientX - r.left) > r.width / 2 ? over.nextSibling : over);
  });
  grid.addEventListener('dragend', function () {
    if (!dragTile) return;
    dragTile.classList.remove('is-dragging');
    dragTile = null;
    var order = Array.prototype.map.call(grid.children, function (t) { return t.dataset.id; });
    state.photos.sort(function (a, b) { return order.indexOf(a.id) - order.indexOf(b.id); });
    renderPhotos(true);
    onFormChange();
  });
  grid.addEventListener('keydown', function (e) {
    var tile = e.target.classList && e.target.classList.contains('studio-photo') ? e.target : null;
    if (!tile) return;
    var i = photoIndex(tile.dataset.id);
    if (e.altKey && (e.key === 'ArrowLeft' || e.key === 'ArrowRight')) {
      e.preventDefault();
      movePhoto(tile.dataset.id, i + (e.key === 'ArrowLeft' ? -1 : 1));
    } else if ((e.key === 'Delete' || e.key === 'Backspace') && !state.photos[i].fromBody) {
      e.preventDefault();
      removePhoto(tile.dataset.id);
    }
  });

  // Files dropped anywhere on the panel upload; stray drops elsewhere never
  // navigate the page away.
  function hasFiles(e) { return e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types, 'Files') !== -1; }
  panel.addEventListener('dragover', function (e) {
    if (dragTile || !hasFiles(e)) return;
    e.preventDefault();
    panel.classList.add('is-dropping');
  });
  panel.addEventListener('dragleave', function (e) {
    if (!panel.contains(e.relatedTarget)) panel.classList.remove('is-dropping');
  });
  panel.addEventListener('drop', function (e) {
    panel.classList.remove('is-dropping');
    if (dragTile || !hasFiles(e)) return;
    e.preventDefault();
    addFiles(e.dataTransfer.files);
  });
  document.addEventListener('dragover', function (e) { if (hasFiles(e)) e.preventDefault(); });
  document.addEventListener('drop', function (e) { if (hasFiles(e) && !e.defaultPrevented) e.preventDefault(); });
  $('photo-input').addEventListener('change', function (e) { addFiles(e.target.files); e.target.value = ''; });

  // ---------- form state, status, local backups ----------

  var f = {
    postTitle: $('post-title'), postDate: $('post-date'), postDesc: $('post-description'), postDraft: $('post-draft'),
    postExcerpt: $('post-excerpt'), postAlbumTitle: $('post-album-title'), postAlbumCaption: $('post-album-caption'),
    albumTitle: $('album-title'), albumDate: $('album-date'), albumDesc: $('album-description'), albumDraft: $('album-draft'),
    albumCaption: $('album-caption')
  };

  // Same rule as the server's one_line: the one-line front matter fields.
  function oneLine(s) { return String(s || '').replace(/\s+/g, ' ').trim(); }

  function photosOut() {
    return state.photos.filter(function (p) { return !p.uploading && p.src; })
      .map(function (p) { return { src: p.src, caption: p.caption.trim() }; });
  }

  function formData() {
    if (isAlbum()) {
      return {
        title: f.albumTitle.value.trim(), date: f.albumDate.value, description: f.albumDesc.value.trim(),
        album_caption: oneLine(f.albumCaption.value), draft: f.albumDraft.checked, images: photosOut()
      };
    }
    if (isPost()) {
      return {
        title: f.postTitle.value.trim(), date: f.postDate.value, tags: state.tags.slice(),
        description: f.postDesc.value.trim(), excerpt: oneLine(f.postExcerpt.value),
        album_title: oneLine(f.postAlbumTitle.value), album_caption: oneLine(f.postAlbumCaption.value),
        draft: f.postDraft.checked, body: getBody(), images: photosOut()
      };
    }
    return null;
  }

  function snapshot() { return JSON.stringify(formData()); }
  function isDirty() { return !!state.current && snapshot() !== state.baseline; }

  var statusEl = $('studio-status');
  function setStatus(kind, text) {
    statusEl.dataset.state = kind;
    statusEl.textContent = text;
  }

  function refreshStatus() {
    if (state.saving) return;
    if (!state.current) { setStatus('idle', ''); return; }
    if (isDirty()) setStatus('dirty', state.current.slug ? 'Unsaved changes' : 'Not saved yet');
    else if (!state.current.slug) setStatus('idle', 'New');
    else setStatus('saved', 'Saved' + (state.savedAt ? ' · ' + relTime(state.savedAt) : ''));
  }

  function readBackup(key) {
    return storage(function (s) { var v = s.getItem(BACKUP_PREFIX + key); return v ? JSON.parse(v) : null; });
  }
  function clearBackup(key) { storage(function (s) { s.removeItem(BACKUP_PREFIX + key); }); }
  function writeBackup() {
    if (!state.current || state.filling) return;
    var key = refKey(state.current);
    // `version` is the disk version the edits were based on (see offerRestore).
    if (isDirty()) storage(function (s) { s.setItem(BACKUP_PREFIX + key, JSON.stringify({ at: Date.now(), version: state.version, data: formData() })); });
    else clearBackup(key);
  }
  var writeBackupSoon = debounce(writeBackup, 800);
  var refreshStatusSoon = debounce(refreshStatus, 150);

  function onFormChange() {
    if (state.filling) return;
    refreshStatusSoon();
    writeBackupSoon();
  }

  [f.postTitle, f.postDate, f.postDesc, f.postExcerpt, f.postAlbumTitle, f.postAlbumCaption,
    f.albumTitle, f.albumDate, f.albumDesc, f.albumCaption].forEach(function (input) {
    input.addEventListener('input', onFormChange);
  });
  [f.postDraft, f.albumDraft].forEach(function (input) {
    input.addEventListener('change', function () { updateChrome(); onFormChange(); });
  });
  f.postTitle.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && editor) { e.preventDefault(); editor.focus(); }
  });
  [f.postDesc, f.postExcerpt, f.postAlbumCaption, f.albumCaption].forEach(function (input) {
    input.addEventListener('input', updateCounters);
  });
  f.postDate.addEventListener('input', updateDateHint);

  // Drafts may have no date: empty means "dated when published".
  function updateDateHint() {
    $('post-date-hint').hidden = !(isPost() && f.postDraft.checked && !f.postDate.value);
  }
  f.albumDesc.addEventListener('input', updateCounters);

  // Soft limits: past them the counter turns accent, nothing is cut.
  function softCount(input, id, limit) {
    var n = input.value.length;
    var c = $(id);
    c.textContent = n ? n + ' / ' + limit : '';
    c.classList.toggle('is-over', n > limit);
  }

  function updateCounters() {
    softCount(f.postDesc, 'post-desc-count', 160);
    softCount(f.postExcerpt, 'post-excerpt-count', 160);
    softCount(f.postAlbumCaption, 'post-album-caption-count', 120);
    softCount(f.albumCaption, 'album-caption-count', 120);
    $('album-desc-count').textContent = f.albumDesc.value.length + ' / 500';
  }

  // Fill the form from an item (from the API or a local backup).
  function fill(item) {
    state.filling = true;
    try {
      if (isAlbum()) {
        f.albumTitle.value = item.title || '';
        f.albumDate.value = toInputDate(item.date);
        f.albumDesc.value = item.description || '';
        f.albumCaption.value = item.album_caption || '';
        f.albumDraft.checked = !!item.draft;
        state.photos = (item.images || []).map(function (img) { return newPhoto(img.src, img.caption, true); });
      } else {
        initEditor();
        f.postTitle.value = item.title || '';
        f.postDate.value = toInputDate(item.date);
        f.postDesc.value = item.description || '';
        f.postExcerpt.value = item.excerpt || '';
        f.postAlbumTitle.value = item.album_title || '';
        f.postAlbumCaption.value = item.album_caption || '';
        f.postDraft.checked = item.kind ? item.kind === 'draft' : !!item.draft;
        state.tags = (item.tags || []).slice();
        renderTags();
        var body = item.body || '';
        setBody(body);
        state.photos = (item.images || []).map(function (img) { return newPhoto(img.src, img.caption, body.indexOf(img.src) === -1); });
        syncBodyPhotos();
      }
      renderPhotos(true);
      updateCounters();
      updateChrome();
    } finally {
      state.filling = false;
    }
  }

  function showView(name) {
    ['empty', 'post', 'album', 'offline'].forEach(function (v) { $('view-' + v).hidden = v !== name; });
    if (name === 'post') placePhotos('post-photos-slot');
    if (name === 'album') placePhotos('album-photos-slot');
    if (name !== 'post' && name !== 'album') panel.classList.remove('is-placed');
  }

  // Top bar: breadcrumb and which actions make sense right now.
  function updateChrome() {
    var c = state.current;
    var crumb = $('studio-crumb');
    crumb.innerHTML = '';
    $('studio-actions').hidden = !c;
    if (!c) { refreshStatus(); return; }
    var group = c.type === 'album' ? 'Albums' : (c.kind === 'draft' ? 'Drafts' : 'Posts');
    crumb.appendChild(document.createTextNode(c.slug ? group + ' / ' : ''));
    crumb.appendChild(el('strong', null, c.slug || (c.type === 'album' ? 'New album' : 'New post')));
    var draftPost = isPost() && c.kind === 'draft' && !!c.slug;
    $('btn-publish-draft').hidden = !draftPost;
    $('btn-preview').disabled = !c.slug;
    updateDateHint();
    $('menu-delete').textContent = c.slug ? 'Delete…' : 'Discard new ' + c.type;
    $('menu-file').disabled = !c.slug;
    refreshStatus();
    renderSidebar();
  }

  // Offer to restore a local backup that differs from what is on disk.
  function offerRestore() {
    var banner = $('restore-banner');
    var key = refKey(state.current);
    var b = readBackup(key);
    if (!b || JSON.stringify(b.data) === state.baseline) {
      if (b) clearBackup(key);
      banner.hidden = true;
      return;
    }
    var newer = b.version && state.version && b.version !== state.version;
    $('restore-text').textContent = 'This browser has unsaved changes from ' + relTime(b.at) + '. Restore them?' +
      (newer ? ' Careful: the file changed on disk after that backup, and saving the restored version replaces those changes.' : '');
    banner.hidden = false;
    $('restore-yes').onclick = function () {
      banner.hidden = true;
      var d = b.data;
      d.kind = state.current.type === 'post' ? (d.draft ? 'draft' : 'post') : undefined;
      fill(d);
      onFormChange();
    };
    $('restore-no').onclick = function () { banner.hidden = true; clearBackup(key); renderSidebar(); };
  }

  function setHash(h) {
    if (location.hash !== h) history.replaceState(null, '', location.pathname + h);
  }

  // Leaving an item with unsaved edits keeps them as a local backup.
  function leaveCurrent() {
    if (!state.current) return;
    if (isDirty()) {
      writeBackup();
      var name = (isAlbum() ? f.albumTitle.value : f.postTitle.value) || 'the new ' + state.current.type;
      toast('Kept unsaved changes to “' + name + '” in this browser. Open it again to restore.');
    }
    $('restore-banner').hidden = true;
  }

  // ---------- actions ----------

  function openItem(ref, opts) {
    opts = opts || {};
    if (!opts.force && sameRef(ref, state.current)) return Promise.resolve();
    return api('GET', itemPath(ref)).then(function (item) {
      leaveCurrent();
      state.current = { type: ref.type, kind: ref.type === 'album' ? null : item.kind, slug: item.slug };
      state.loaded = item;
      state.version = item.version;
      state.savedAt = 0;
      showView(ref.type);
      fill(item);
      state.baseline = snapshot();
      setHash(refHash(state.current));
      offerRestore();
      updateChrome();
    }).catch(function (err) {
      if (err.status === 404) { toast('That item no longer exists.', { type: 'error' }); showEmpty(); }
      // 422: the front matter does not parse; the server refuses to load or save it.
      else if (err.status === 422) toast(err.message + ' Fix the file by hand, then reopen it.', { type: 'error', duration: 0 });
      else fail(err);
    });
  }

  function newItem(type) {
    leaveCurrent();
    state.current = { type: type, kind: type === 'post' ? 'draft' : null, slug: null };
    state.loaded = null;
    state.version = null;
    state.savedAt = 0;
    showView(type);
    // New posts start as drafts (gitignored, never deployed until published).
    fill(type === 'post'
      ? { title: '', kind: 'draft', tags: [], body: '', images: [] }
      : { title: '', date: nowInputDate(), description: '', draft: false, images: [] });
    state.baseline = snapshot();
    setHash(refHash(state.current));
    offerRestore();
    updateChrome();
    (type === 'post' ? f.postTitle : f.albumTitle).focus();
  }

  function showEmpty() {
    leaveCurrent();
    state.current = null;
    state.loaded = null;
    showView('empty');
    setHash('');
    updateChrome();
  }

  // Send the form. The snapshot taken at send time becomes the new baseline,
  // so anything typed while the request was in flight stays "unsaved" (and in
  // the local backup) instead of being marked saved. opts: publish (draft ->
  // post via POST /publish), force (overwrite a file that changed on disk).
  function save(opts) {
    opts = opts || {};
    var c = state.current;
    if (!c || state.saving) return Promise.resolve(false);
    var d = formData();
    if (!d.title) { toast('Give it a title first.', { type: 'error' }); (isAlbum() ? f.albumTitle : f.postTitle).focus(); return Promise.resolve(false); }
    if (isPost() && !d.body.trim()) { toast('Write something in the body first.', { type: 'error' }); if (editor) editor.focus(); return Promise.resolve(false); }
    if (state.photos.some(function (p) { return p.uploading; })) { toast('Wait for the uploads to finish.'); return Promise.resolve(false); }
    if (opts.publish) d.draft = false;
    var sent = JSON.stringify(d);
    d.version = state.version;
    if (opts.force) d.force = true;
    var oldKey = refKey(c);
    var req = opts.publish ? api('POST', '/publish/' + enc(c.slug), d)
      : c.slug ? api('PUT', itemPath(c), d) : api('POST', c.type === 'album' ? '/albums' : '/posts', d);
    state.saving = true;
    setStatus('saving', opts.publish ? 'Publishing…' : 'Saving…');
    return req.then(function (res) {
      state.saving = false;
      var ref = { type: c.type, kind: c.type === 'album' ? null : res.kind, slug: res.slug };
      state.current = ref;
      state.version = res.version;
      state.savedAt = Date.now();
      state.loaded = { path: res.path, url: res.url || '/albums/' + res.slug + '/', version: res.version };
      if (opts.publish) f.postDraft.checked = false;
      var edited = snapshot() !== sent;
      // Publishing rewrites drafts/ image paths to posts/ on disk: load that,
      // unless the user kept typing (their next save rewrites them as well).
      var reload = !edited && ref.type === 'post' && (opts.publish || (res.kind === 'post' && /\/assets\/images\/drafts\//.test(d.body)));
      return (reload ? api('GET', itemPath(ref)).then(function (item) {
        state.loaded = item;
        // Typing while this GET was pending wins: keep the form, stay dirty.
        if (snapshot() !== sent) { edited = true; return; }
        fill(item);
      }) : Promise.resolve())
        .then(function () {
          if (!edited) {
            // The server picks a date when none was given.
            if (isPost() && !f.postDate.value && res.kind === 'post') f.postDate.value = toInputDate(res.date);
            if (isAlbum() && !f.albumDate.value) f.albumDate.value = toInputDate(res.date);
            state.baseline = snapshot();
            clearBackup(oldKey);
            clearBackup(refKey(ref));
          } else {
            state.baseline = sent;
            if (oldKey !== refKey(ref)) clearBackup(oldKey);
            writeBackup();
            toast('Saved what you had when you pressed Save. Your newer edits are not saved yet.');
          }
          setHash(refHash(ref));
          updateChrome();
          flushDeletes();
          loadLists();
          refreshGit();
          return true;
        });
    }).catch(function (err) {
      state.saving = false;
      if (err.status === 409 && err.data && err.data.code === 'stale') return resolveStale(opts);
      fail(err);
      return false;
    });
  }

  // The file changed on disk since it was opened (another tab, git, an editor).
  function resolveStale(opts) {
    setStatus('error', 'Changed on disk');
    var dlg = $('dlg-stale');
    dlg.returnValue = '';
    dlg.showModal();
    return new Promise(function (resolve) {
      dlg.addEventListener('close', function () { resolve(dlg.returnValue); }, { once: true });
    }).then(function (choice) {
      if (choice === 'overwrite') return save({ publish: opts.publish, force: true });
      // Reload keeps the edits as a local backup, offered back by the banner.
      if (choice === 'reload') return openItem(state.current, { force: true }).then(function () { return false; });
      return false;
    });
  }

  function publishDraft() {
    var c = state.current;
    if (!(isPost() && c.kind === 'draft' && c.slug)) return;
    if (!f.postTitle.value.trim() || !getBody().trim()) { toast('A draft needs a title and a body to publish.', { type: 'error' }); return; }
    var when = f.postDate.value ? 'dated ' + shortDate(f.postDate.value) : 'dated now';
    confirmDialog('Publish this draft?',
      'It moves from _drafts/ to _posts/, ' + when + '. It goes live on the site after you use Publish to site.',
      'Publish draft').then(function (ok) {
      if (!ok) return;
      var title = f.postTitle.value.trim();
      save({ publish: true }).then(function (done) {
        if (done) toast('Published “' + title + '” as a post.', { action: 'Publish to site…', onAction: openPublish, duration: 7000 });
      });
    });
  }

  function deleteCurrent() {
    var c = state.current;
    if (!c) return;
    var title = (isAlbum() ? f.albumTitle.value : f.postTitle.value) || 'Untitled';
    if (!c.slug) {
      confirmDialog('Discard this new ' + c.type + '?', 'Nothing has been saved yet.', 'Discard').then(function (ok) {
        if (!ok) return;
        clearBackup(refKey(c));
        state.baseline = snapshot();
        showEmpty();
      });
      return;
    }
    deleteDialog(title, state.loaded ? state.loaded.path : c.slug, c.slug).then(function (ok) {
      if (!ok) return;
      api('DELETE', itemPath(c) + '?version=' + enc(state.version || '')).then(function () {
        clearBackup(refKey(c));
        state.baseline = snapshot();
        showEmpty();
        loadLists();
        refreshGit();
        toast('Deleted “' + title + '”.');
      }).catch(function (err) {
        if (err.status === 409) toast('Not deleted: the file changed on disk since you opened it. Reopen it and check first.', { type: 'error', duration: 9000 });
        else fail(err);
      });
    });
  }

  function preview() {
    var c = state.current;
    if (!c || !c.slug || !state.loaded) return;
    if (isAlbum() && f.albumDraft.checked) {
      toast('Draft albums have published: false, so Jekyll does not build them. Turn off Draft and save to preview.', { duration: 7000 });
      return;
    }
    // Open the tab now (inside the click) so it is not popup-blocked; point it
    // at the page once any save and the draft check are done.
    var win = window.open('about:blank', '_blank');
    var ready = isDirty() ? save() : Promise.resolve(true);
    ready.then(function (ok) {
      var url = SITE + state.loaded.url;
      if (!ok) { if (win) win.close(); return; }
      if (c.kind !== 'draft') { if (win) win.location.href = url; return; }
      fetch(url, { method: 'HEAD' }).then(function (res) {
        if (res.ok) { if (win) win.location.href = url; return; }
        throw new Error('not built');
      }).catch(function () {
        if (win) win.close();
        toast('Jekyll only builds drafts when started with --drafts. Restart with bin/dev (it passes --drafts) to preview drafts.', {
          duration: 9000, action: 'Open anyway', onAction: function () { window.open(url, '_blank'); }
        });
      });
    });
  }

  // The form's text fields as a front matter block (strings JSON-quoted, as
  // the server writes them; empty fields left out). Photos are not included.
  function frontMatterText(d) {
    var keys = isPost()
      ? ['title', 'date', 'tags', 'description', 'excerpt', 'album_title', 'album_caption']
      : ['title', 'date', 'description', 'album_caption'];
    var lines = keys.map(function (k) {
      var v = d[k];
      if (k === 'tags') return v.length ? 'tags: [' + v.map(function (t) { return JSON.stringify(t); }).join(', ') + ']' : '';
      if (k === 'date') return v ? 'date: ' + v : '';
      return v ? k + ': ' + JSON.stringify(v) : '';
    }).filter(Boolean);
    return '---\n' + lines.join('\n') + '\n---\n\n';
  }

  function copyMarkdown() {
    var d = formData();
    if (!d) return;
    var md;
    if (isPost()) md = d.body;
    else md = d.images.map(function (p) {
      return '![' + (p.caption || '') + '](' + p.src + ')' + (p.caption ? '\n\n*' + p.caption + '*' : '');
    }).join('\n\n');
    copyText(frontMatterText(d) + md).then(function () {
      toast('Copied the front matter and ' + (isPost() ? 'the body' : 'the photo list') + ' as markdown.');
    }, fail);
  }

  function showFile() {
    if (!state.loaded) return;
    var path = state.loaded.path;
    var msg = el('span', null, 'File: ');
    msg.appendChild(el('code', null, path));
    toast(msg, { duration: 8000, action: 'Copy path', onAction: function () { copyText(path); } });
  }

  // ---------- git: publish to site ----------

  // fetch: also `git fetch` first so "behind" is current (the drawer does this).
  function refreshGit(fetch) {
    return api('GET', '/git/status' + (fetch ? '?fetch=1' : '')).then(function (g) {
      state.git = g;
      var n = g.files.length;
      var btn = $('btn-site-publish');
      btn.dataset.count = String(n);
      $('site-publish-count').textContent = n;
      btn.title = n ? plural(n, 'changed content file') + ' ready to publish' : 'All content is committed';
      var bits = [g.branch || '?'];
      if (g.ahead) bits.push(g.ahead + ' unpushed');
      if (g.behind) bits.push(g.behind + ' behind');
      $('git-summary').textContent = '⎇ ' + bits.join(' · ');
      return g;
    }).catch(function () { return null; });
  }

  var FILE_GROUPS = [
    ['_posts/', 'Posts'], ['_drafts/', 'Drafts'], ['_albums/', 'Albums'],
    ['assets/images/posts/', 'Post photos'], ['assets/images/albums/', 'Album photos'], ['_data/', 'Image manifest']
  ];
  var STATUS_LABEL = { '??': 'new', A: 'new', M: 'edited', D: 'deleted', AM: 'new', MM: 'edited' };
  var publishState = { blocked: false, messageTouched: false };

  function callout(html, warn) {
    return el('p', 'studio-callout' + (warn ? ' is-warning' : ''), null, { innerHTML: html });
  }

  // Titles of items with unsaved edits: the open one and any local backups.
  // Publishing waits until they are saved or discarded.
  function unsavedItems() {
    var names = [];
    var dirty = isDirty();
    if (dirty) names.push((isAlbum() ? f.albumTitle.value : f.postTitle.value) || 'the open item');
    storage(function (s) {
      for (var i = 0; i < s.length; i++) {
        var key = s.key(i);
        if (key.indexOf(BACKUP_PREFIX) !== 0) continue;
        key = key.slice(BACKUP_PREFIX.length);
        if (dirty && key === refKey(state.current)) continue;
        var b = readBackup(key);
        names.push((b && b.data && b.data.title) || key);
      }
    });
    return names;
  }

  function checkedPaths() {
    return Array.prototype.map.call(document.querySelectorAll('.publish-path:checked'), function (cb) { return cb.value; });
  }

  // One changed post/album -> "content: <title>", else "content: update N files".
  function defaultMessage(paths) {
    var titled = ((state.git && state.git.files) || []).filter(function (x) { return x.title && paths.indexOf(x.path) !== -1; });
    return titled.length === 1 ? 'content: ' + titled[0].title : 'content: update ' + plural(paths.length, 'file');
  }

  // With nothing ticked but commits waiting, the button pushes those instead.
  function updatePublishButton() {
    var g = state.git;
    var paths = checkedPaths();
    var pushOnly = !paths.length && !!g && g.ahead > 0;
    var go = $('publish-go');
    go.textContent = pushOnly ? 'Push ' + plural(g.ahead, 'commit') + ' to main' : 'Commit & push to main';
    go.disabled = publishState.blocked || (!paths.length && !pushOnly);
    $('publish-message').disabled = pushOnly;
    if (!publishState.messageTouched) $('publish-message').value = pushOnly ? '' : defaultMessage(paths);
  }

  function fileGroup(title, files, checked, note) {
    var det = el('details', null, null, { open: files.length <= 6 });
    var sum = det.appendChild(el('summary'));
    var all = sum.appendChild(el('input', null, null, { type: 'checkbox', checked: checked, ariaLabel: 'Include all ' + title }));
    sum.appendChild(el('span', null, title));
    sum.appendChild(el('span', 'studio-muted', String(files.length)));
    if (note) det.appendChild(el('p', 'studio-small studio-muted studio-group-note', note));
    var ul = det.appendChild(el('ul'));
    files.forEach(function (x) {
      var li = ul.appendChild(el('li'));
      li.appendChild(el('input', 'publish-path', null, { type: 'checkbox', checked: checked, value: x.path }));
      li.appendChild(el('span', 'studio-file-status', STATUS_LABEL[x.status] || x.status));
      li.appendChild(el('span', null, x.title || x.path.replace(/^.*\//, ''), { title: x.path }));
    });
    all.addEventListener('click', function (e) { e.stopPropagation(); });
    all.addEventListener('change', function () {
      each(ul.querySelectorAll('input'), function (cb) { cb.checked = all.checked; });
      updatePublishButton();
    });
    ul.addEventListener('change', updatePublishButton);
    return det;
  }

  function renderPublish(g) {
    var warn = $('publish-warnings');
    var list = $('publish-files');
    warn.innerHTML = '';
    list.innerHTML = '';
    publishState.blocked = true;
    if (!g) { warn.appendChild(callout('Could not read git status from the API.', true)); updatePublishButton(); return; }
    var blocked = false;
    if (g.branch !== 'main') { blocked = true; warn.appendChild(callout('You are on branch <code>' + esc(g.branch) + '</code>. Publishing only runs on <code>main</code>.', true)); }
    if (g.busy) { blocked = true; warn.appendChild(callout('A ' + esc(g.busy) + ' is in progress. Finish or abort it in a terminal first.', true)); }
    if (g.fetch_error) { blocked = true; warn.appendChild(callout('Could not reach GitHub (<code>git fetch</code> failed): ' + esc(g.fetch_error), true)); }
    if (g.behind) { blocked = true; warn.appendChild(callout('<code>main</code> is ' + plural(g.behind, 'commit') + ' behind GitHub. Run <code>git pull --rebase</code> first.', true)); }
    if (g.ahead) {
      warn.appendChild(callout('<code>main</code> also has ' + plural(g.ahead, 'earlier commit') + (g.ahead === 1 ? ' that is' : ' that are') + ' not on GitHub yet. ' + (g.ahead === 1 ? 'It' : 'They') + ' will be pushed too:<br>' +
        g.unpushed.map(function (c) { return '<code>' + esc(c) + '</code>'; }).join('<br>'), true));
    }
    var unsaved = unsavedItems();
    if (unsaved.length) {
      blocked = true;
      var p = warn.appendChild(callout('Save or discard unsaved changes first: ' + unsaved.map(esc).join(', ') + '. ', true));
      if (isDirty()) p.appendChild(button('Save now', 'studio-btn studio-btn-sm', function () { save().then(function () { refreshGit().then(renderPublish); }); }));
    }
    publishState.blocked = blocked;
    var live = g.files.filter(function (x) { return !x.draft_only; });
    var drafts = g.files.filter(function (x) { return x.draft_only; });
    if (!live.length) list.appendChild(el('p', 'studio-empty', g.ahead ? 'Nothing new to commit.' : 'Nothing to publish: all content is committed.'));
    FILE_GROUPS.forEach(function (grp) {
      var files = live.filter(function (x) { return x.path.indexOf(grp[0]) === 0; });
      if (files.length) list.appendChild(fileGroup(grp[1], files, true));
    });
    if (drafts.length) {
      list.appendChild(fileGroup('Drafts (not recommended)', drafts, false,
        'Draft albums and photos only draft albums use. The album stays hidden, but committing pushes its photos to GitHub.'));
    }
    updatePublishButton();
  }

  function openPublish() {
    publishState.messageTouched = false;
    $('publish-files').innerHTML = '<p class="studio-empty">Checking git (fetching from GitHub)…</p>';
    $('publish-warnings').innerHTML = '';
    $('publish-result').innerHTML = '';
    $('publish-go').disabled = true;
    $('dlg-publish').showModal();
    refreshGit(true).then(renderPublish);
  }
  $('publish-message').addEventListener('input', function () { publishState.messageTouched = true; });

  function publishToSite() {
    var paths = checkedPaths();
    var pushOnly = !paths.length && !!state.git && state.git.ahead > 0;
    var message = $('publish-message').value.trim();
    var out = $('publish-result');
    if (unsavedItems().length) { toast('Save or discard unsaved changes first.', { type: 'error' }); return; }
    if (!pushOnly && !message) { toast('Write a commit message.', { type: 'error' }); $('publish-message').focus(); return; }
    if (!pushOnly && !paths.length) { toast('Pick at least one file.', { type: 'error' }); return; }
    var go = $('publish-go');
    go.disabled = true;
    go.textContent = pushOnly ? 'Pushing…' : 'Publishing…';
    out.innerHTML = '';
    function showSteps(steps) {
      if (!steps || !steps.length) return;
      out.appendChild(el('pre', 'studio-output', steps.map(function (s) {
        return '$ ' + s.cmd + (s.ok ? '' : '  (failed)') + '\n' + (s.stdout || '') + (s.stderr || '');
      }).join('\n')));
    }
    api('POST', '/git/publish', pushOnly ? { push_only: true } : { message: message, paths: paths }).then(function (res) {
      var ok = el('p', 'studio-result-ok', 'Pushed ' + res.head + ' to main. GitHub Actions is deploying it now. ');
      ok.appendChild(el('a', null, 'Watch the deploy →', { href: res.actions_url, target: '_blank', rel: 'noopener noreferrer' }));
      out.appendChild(ok);
      showSteps(res.steps);
    }).catch(function (err) {
      out.appendChild(el('p', 'studio-result-err', err.message));
      showSteps(err.data && err.data.steps);
    }).then(function () {
      // Re-read git: after a rejected push the button offers "Push N commits".
      return refreshGit().then(renderPublish);
    });
  }

  // ---------- API up/down ----------

  var retryTimer = null;

  function setOnline(on) {
    $('btn-site-publish').hidden = !on;
    if (on && !state.online) {
      state.online = true;
      clearInterval(retryTimer);
      retryTimer = null;
      // Reopen whatever the URL points at (#post/..., #album/...).
      if (!state.current) routeFromHash();
      toast('Connected to the editor API.');
    }
    state.online = on;
  }

  // The API answered but refuses this page's origin (Jekyll on another port
  // than the API was started for).
  var rejectedShown = false;
  function apiRejected() {
    if (rejectedShown) return;
    rejectedShown = true;
    var msg = 'The editor API at ' + API + ' refuses this page (' + location.origin + '). Restart it for this port: ' +
      'STUDIO_SITE_PORT=' + location.port + ' bin/dev';
    $('offline-reason').textContent = msg;
    $('offline-reason').hidden = false;
    if (!state.current) showView('offline');
    toast(msg, { type: 'error', duration: 0 });
  }

  function apiDown() {
    if (!state.online && retryTimer) return;
    state.online = false;
    $('btn-site-publish').hidden = true;
    if (state.current) {
      setStatus('error', 'API offline');
      toast('The editor API stopped responding. Your edits are backed up in this browser; start it with bin/dev.', { type: 'error' });
    } else {
      showView('offline');
    }
    if (!retryTimer) retryTimer = setInterval(function () { loadLists().then(refreshGit, function () {}); }, 4000);
  }

  // ---------- wiring ----------

  $('new-post').addEventListener('click', function () { newItem('post'); closeSidebar(); });
  $('new-album').addEventListener('click', function () { newItem('album'); closeSidebar(); });
  each('[data-new]', function (b) {
    b.addEventListener('click', function () { newItem(b.dataset.new); });
  });
  each('[data-copy]', function (b) {
    b.addEventListener('click', function () { copyText(b.dataset.copy).then(function () { toast('Copied.'); }); });
  });
  $('btn-retry').addEventListener('click', function () { loadLists().then(refreshGit, function () {}); });
  $('btn-save').addEventListener('click', function () { save(); });
  $('btn-preview').addEventListener('click', preview);
  $('btn-publish-draft').addEventListener('click', publishDraft);
  $('btn-site-publish').addEventListener('click', openPublish);
  $('publish-go').addEventListener('click', publishToSite);
  $('btn-shortcuts').addEventListener('click', function () { $('dlg-shortcuts').showModal(); });

  // Overflow menu
  var menu = $('more-menu');
  var moreBtn = $('btn-more');
  function toggleMenu(open) {
    menu.hidden = !open;
    moreBtn.setAttribute('aria-expanded', String(open));
    if (open) menu.querySelector('button:not(:disabled)').focus();
  }
  moreBtn.addEventListener('click', function (e) { e.stopPropagation(); toggleMenu(menu.hidden); });
  document.addEventListener('click', function (e) { if (!menu.hidden && !menu.contains(e.target)) toggleMenu(false); });
  menu.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { toggleMenu(false); moreBtn.focus(); }
  });
  $('menu-copy').addEventListener('click', function () { toggleMenu(false); copyMarkdown(); });
  $('menu-file').addEventListener('click', function () { toggleMenu(false); showFile(); });
  $('menu-delete').addEventListener('click', function () { toggleMenu(false); deleteCurrent(); });
  $('menu-cleanup').addEventListener('click', function () { toggleMenu(false); cleanupUploads(); });

  // Image srcs that unsaved edits (open item + local backups) still use.
  function backupSrcs() {
    var text = JSON.stringify(state.current ? formData() : null);
    storage(function (s) {
      for (var i = 0; i < s.length; i++) if (s.key(i).indexOf(BACKUP_PREFIX) === 0) text += s.getItem(s.key(i));
    });
    return text.match(/\/assets\/images\/[^\s)"'<>\\]+/g) || [];
  }

  // Uploads left in _editor_tmp/ by edits that were never saved.
  function cleanupUploads() {
    api('GET', '/uploads/stale').then(function (r) {
      if (!r.count) { toast('No abandoned uploads older than a day.'); return; }
      return confirmDialog('Delete ' + plural(r.count, 'abandoned upload') + '?',
        'These files in _editor_tmp/ are more than a day old and were never saved into a post or album (' +
        (r.bytes / 1048576).toFixed(1) + ' MB). Photos used by unsaved edits in this browser are kept.', 'Delete').then(function (ok) {
        if (!ok) return;
        return api('POST', '/uploads/cleanup', { keep: backupSrcs() }).then(function (res) { toast('Deleted ' + plural(res.deleted, 'file') + '.'); });
      });
    }).catch(fail);
  }

  if (isMac) {
    each('kbd.mod', function (k) { k.textContent = '⌘'; });
    $('btn-save').title = 'Save (⌘S)';
  }

  document.addEventListener('keydown', function (e) {
    var mod = isMac ? e.metaKey : e.ctrlKey;
    var k = (e.key || '').toLowerCase();
    // Cmd/Ctrl+S never opens the browser's Save dialog, and does nothing while a dialog is open.
    if (mod && !e.shiftKey && !e.altKey && k === 's') { e.preventDefault(); if (!document.querySelector('dialog[open]')) save(); return; }
    if (e.key === 'Escape' && root.classList.contains('is-sidebar-open')) { closeSidebar(); $('btn-sidebar').focus(); return; }
    if (mod && e.shiftKey && k === 'k') { e.preventDefault(); if (isPost()) $('body-image-input').click(); return; }
    if (isTyping(e.target) || mod || e.altKey || document.querySelector('dialog[open]')) return;
    if (e.key === '/') { e.preventDefault(); openSidebar(); search.focus(); search.select(); }
    else if (e.key === '?') { e.preventDefault(); $('dlg-shortcuts').showModal(); }
  }, true);

  window.addEventListener('beforeunload', function (e) {
    writeBackup();
    if (isDirty()) { e.preventDefault(); e.returnValue = ''; }
  });

  // Jekyll's livereload would reload this page after every save (each save
  // rebuilds the site). Replace the reload with a quiet "site rebuilt" note.
  function tameLiveReload() {
    var lr = window.LiveReload;
    if (!lr || lr.studioTamed) return;
    lr.studioTamed = true;
    var note = $('studio-rebuilt');
    var hide;
    lr.performReload = function () {
      note.hidden = false;
      note.textContent = 'site rebuilt';
      clearTimeout(hide);
      hide = setTimeout(function () { note.hidden = true; }, 6000);
    };
  }

  function routeFromHash() {
    var h = decodeURIComponent(location.hash.slice(1));
    var m = h.match(/^(post|draft)\/(.+)$/);
    if (m) return openItem({ type: 'post', kind: m[1], slug: m[2] });
    m = h.match(/^album\/(.+)$/);
    if (m) return openItem({ type: 'album', kind: null, slug: m[1] });
    if (h === 'new-post' || h === 'new-album') return newItem(h.slice(4));
    if (h === 'albums') {
      var head = groups.album.querySelector('.studio-group-head');
      head.setAttribute('aria-expanded', 'true');
      head.scrollIntoView({ block: 'start' });
    }
    // No hash: pick up the most recently modified post, draft, or album
    // (openItem sets the hash, so a reload stays on it; a backup still gets
    // its Restore banner).
    var last = h ? null : mostRecentItem();
    if (last) return openItem(itemRef(last));
    showView('empty');
    updateChrome();
  }
  window.addEventListener('hashchange', function () {
    var h = location.hash;
    if (!state.current || h !== refHash(state.current)) routeFromHash();
  });

  // Refresh the "Saved · 3 min ago" text and git status now and then.
  setInterval(refreshStatus, 30000);
  window.addEventListener('focus', function () { if (state.online) { refreshGit(); loadLists().catch(function () {}); } });

  // One-time notice when the API cannot make thumbnails (no ImageMagick).
  function checkServer() {
    api('GET', '/info').then(function (info) {
      // An API started before the image-format update has no `heic` field and
      // would store a HEIC as-is or refuse an SVG.
      oldApi = !('heic' in info);
      if (oldApi) toast('The editor API is running old code. Restart bin/dev to upload HEIC, AVIF, SVG, TIFF or BMP files.', { type: 'error', duration: 0 });
      if (info.thumbnails || storage(function (s) { return s.getItem('studio:warned-thumbs'); })) return;
      storage(function (s) { s.setItem('studio:warned-thumbs', '1'); });
      toast('Thumbnails are off: the API cannot find ImageMagick (brew install imagemagick), so new photos get no -thumb/-med versions.', { type: 'error', duration: 0 });
    }, function () {});
  }

  tameLiveReload();
  updateChrome();
  loadLists().then(function () {
    refreshGit();
    checkServer();
    routeFromHash();
  }, function () { /* apiDown() already showed the offline view */ });
})();
