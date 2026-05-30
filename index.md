---
layout: default
title: "Computer Science Student at Cornell University"
description: "CS student at Cornell (College of Engineering) working on computer vision and machine learning."
---

<div class="profile-section">
  <div class="profile-left">
    <div class="profile-avatar">
      <img src="{{ '/assets/images/headshot.jpeg' | relative_url }}" alt="Ryan Ye - Cornell University Computer Science Student" width="160" height="160" decoding="async">
    </div>
    <h1 class="profile-name">{{ site.author }}</h1>
    <p class="profile-position">
      Computer Science<br>
      <a href="https://www.cs.cornell.edu/" target="_blank" rel="noopener noreferrer">Cornell University</a>
    </p>
    <div class="profile-social">
      <a href="mailto:{{ site.email }}" title="Email"><i class="fas fa-envelope" aria-hidden="true"></i></a>
      <a href="https://github.com/{{ site.github_username }}" target="_blank" rel="me noopener noreferrer" title="GitHub"><i class="fab fa-github" aria-hidden="true"></i></a>
      <a href="https://linkedin.com/in/{{ site.linkedin_username }}" target="_blank" rel="me noopener noreferrer" title="LinkedIn"><i class="fab fa-linkedin" aria-hidden="true"></i></a>
    </div>
    <p class="profile-faith-note">Jesus is King</p>
  </div>

  <div class="profile-right">
    {{ site.data.about.bio_profile | markdownify }}
    <p class="profile-edu-line">
      <strong>{{ site.data.about.education.institution }}</strong>
      &middot; {{ site.data.about.education.degree }}
      &middot; GPA {{ site.data.about.education.gpa }}
    </p>
    <p class="spotify-widget" aria-live="polite" aria-atomic="true">
      <i class="fab fa-spotify spotify-icon" aria-hidden="true"></i>
      <span id="spotify-now-playing">Loading&hellip;</span>
    </p>
  </div>
</div>

<div class="content-section">
  <div class="section-header">
    <h2 class="section-title" style="border:none;padding:0;margin:0">Research</h2>
    <a href="{{ '/research' | relative_url }}">see more &rarr;</a>
  </div>

  {% for position in site.data.research.positions %}{% if position.homepage %}
  <div class="research-entry">
    <h3>{{ position.index_title }}</h3>
    <p class="research-meta">
      <span class="research-role">{{ position.role }}</span> &mdash; {{ position.lab }}, {{ position.institution }}
    </p>
    <p>{{ position.index_description }}</p>
    <p style="font-size:0.875rem;color:var(--muted)">{{ position.note }}</p>
  </div>
  {% endif %}{% endfor %}

  {% assign selected_pubs = site.data.research.publications | where: "selected", true %}
  {% if selected_pubs.size > 0 %}
  <h3 style="margin-top:1.5rem;margin-bottom:0.25rem;font-size:1rem;font-weight:600;">Selected Publications</h3>
  {% for pub in selected_pubs limit:3 %}
  <div class="pub-tile">
    <div class="pub-tile-image">
      {% if pub.image %}
      <img src="{{ pub.image | relative_url }}" alt="{{ pub.title }}">
      {% else %}
      <i class="fas fa-file-alt pub-tile-icon" aria-hidden="true"></i>
      {% endif %}
    </div>
    <div class="pub-tile-body">
      <p class="pub-tile-title">{% if pub.url %}<a href="{{ pub.url }}" target="_blank" rel="noopener noreferrer">{{ pub.title }}</a>{% else %}{{ pub.title }}{% endif %}</p>
      <p class="pub-tile-authors">{{ pub.authors }}</p>
      <p class="pub-tile-venue">{{ pub.venue }}</p>
      {% if pub.description %}<p class="pub-tile-description">{{ pub.description }}</p>{% endif %}
      {% if pub.tags %}
      <div class="tags">{% for tag in pub.tags %}<span class="tag">{{ tag }}</span>{% endfor %}</div>
      {% endif %}
    </div>
  </div>
  {% endfor %}
  <a href="{{ '/research' | relative_url }}" style="font-size:0.9rem;">see more &rarr;</a>
  {% endif %}
</div>

<div class="content-section">
  <div class="section-header">
    <h2 class="section-title" style="border:none;padding:0;margin:0">Blog</h2>
    <a href="{{ '/blog' | relative_url }}">all posts &rarr;</a>
  </div>
  <p style="margin:0.4rem 0 1rem;color:var(--muted);font-size:0.95rem;">{{ site.data.about.blog_blurb }}</p>

  {% if site.posts.size > 0 %}
  <table class="news-table post-preview-table">
    <thead>
      <tr>
        <th scope="col">Date</th>
        <th scope="col">Post</th>
      </tr>
    </thead>
    <tbody>
    {% for post in site.posts limit:3 %}
    <tr>
      <td class="news-date">
        <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%b %-d, %Y" }}</time>
      </td>
      <td class="news-content">
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
        {% if post.excerpt %}
        <span class="post-preview-text"> — {{ post.excerpt | strip_html | truncate: 80 }}</span>
        {% endif %}
      </td>
    </tr>
    {% endfor %}
    </tbody>
  </table>
  {% else %}
  <p class="news-empty">No posts yet — check back soon!</p>
  {% endif %}
</div>

<script>
(function () {
  /* ── shared utilities ── */
  function timeAgo(isoStr) {
    var d    = new Date(isoStr);
    var now  = new Date();
    var secs = Math.floor((now - d) / 1000);
    if (secs < 60)  return secs + ' second' + (secs === 1 ? '' : 's') + ' ago';
    var mins = Math.floor(secs / 60);
    if (mins < 60)  return mins + ' minute' + (mins === 1 ? '' : 's') + ' ago';
    var hrs  = Math.floor(mins / 60);
    if (hrs  < 24)  return hrs  + ' hour'   + (hrs  === 1 ? '' : 's') + ' ago';
    var days = Math.floor(hrs  / 24);
    return days + ' day' + (days === 1 ? '' : 's') + ' ago';
  }

  function escapeHtml(str) {
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
              .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /* ── Spotify "recently listened" ── */
  var spotifyEl = document.getElementById('spotify-now-playing');
  if (spotifyEl) {
    var controller = new AbortController();
    var timeoutId = setTimeout(function () { controller.abort(); }, 5000);
    fetch('{{ "/assets/data/now-playing.json" | relative_url }}?t=' + Date.now(), { signal: controller.signal })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (!data.track) { spotifyEl.textContent = 'No recent tracks.'; return; }
        var t = data.track;
        var artistLinks = t.artists.map(function (a) {
          return '<a href="' + a.url + '" target="_blank" rel="noopener noreferrer">' +
                 escapeHtml(a.name) + '</a>';
        }).join(', ');
        var html = 'listened to <a href="' + t.url + '" target="_blank" rel="noopener noreferrer">' +
          escapeHtml(t.name) + '</a> by ' + artistLinks;
        if (data.context && data.context.name && data.context.url) {
          var ctxType = data.context.type || '';
          var ctxLabel = ctxType === 'playlist' ? 'playlist' : ctxType === 'album' ? 'album' : ctxType === 'artist' ? 'artist' : '';
          html += ' from ' + (ctxLabel ? ctxLabel + ' ' : '') +
            '<a href="' + data.context.url + '" target="_blank" rel="noopener noreferrer">' +
            escapeHtml(data.context.name) + '</a>';
        }
        html += ' <span class="spotify-time">(' + timeAgo(t.played_at) + ')</span>';
        spotifyEl.innerHTML = html;
      })
      .catch(function () { spotifyEl.textContent = 'Could not load recent track.'; })
      .finally(function () { clearTimeout(timeoutId); });
  }
})();
</script>
