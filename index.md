---
layout: default
full_title: "Ryan Ye — Computer Science Student at Cornell University"
description: "Personal website of Ryan Ye, a computer science student at Cornell University (College of Engineering) doing AI for science research: agents for scientific discovery and computer vision."
---

{%- comment -%}
  Editorial, featured-first homepage:
  1. Hero: name; the credential line ("Cornell University · B.S. Computer
     Science · Class of 2028", 18px --text-2, built from about.education:
     institution linked to institution_url, degree_short, the year of
     expected); the internship ask (about.seeking, 18px/600, 16px under
     the credential line; no headline between them); the intro (about.intro,
     20px under the ask),
     the outside-academics paragraph (about.outside) and, last in the
     text column, the Spotify line. The identity block (.hero-aside): the
     round headshot (280px at >= 1024px, 200px from 700px, 160px on
     phones; 640px source), then under it an icon row (Email, GitHub,
     LinkedIn, Google Scholar), the word "Resume" (underlined link to the
     PDF) and "Jesus is King", one centered column the photo's width at
     >= 700px. DOM order is lead, aside, intro, so the tab order is nav,
     the Cornell link, icons, Resume, then the intro links. On phones the whole aside moves
     above the name (CSS order): the 160px photo centered, the icons,
     Resume and "Jesus is King" centered on it.
  2. Selected work: the three research positions as the site's only cards,
     each with a two-sentence card_summary (what it is, what he did; no
     metric) and a link to its /research/ section.
  3. Two columns at >= 1024px: Projects (featured with `short`, else
     `summary`; the rest title + context) on the left; Publications (by
     rank) and Updates (quieter, 15px) on the right.
  4. From the blog: the three newest entries of the list /blog/ shows
     (_includes/blog_entries.html), full width, 3-up at >= 900px: the
     cover's thumb (16:10) when it has photos, the title, "Mar 17, 2026"
     (albums add "· Album · N photos") and the /blog/ line
     (_includes/blog_line.html), clamped to two lines. No boxes.
{%- endcomment -%}
{% assign about = site.data.about %}
<header class="hero">
  <div class="hero-lead">
    <h1 class="hero-name">{{ site.author }}</h1>
    {%- assign edu = about.education %}
    <p class="hero-credential"><span class="cred-item"><a href="{{ edu.institution_url }}" target="_blank" rel="noopener noreferrer">{{ edu.institution }}</a></span><span class="cred-group"><span class="visually-hidden">, </span><span class="cred-item">{{ edu.degree_short }}</span><span class="visually-hidden">, </span><span class="cred-item">Class of {{ edu.expected | split: ' ' | last }}</span></span></p>
    <p class="hero-seeking">{{ about.seeking }}</p>
  </div>
  <div class="hero-aside">
    <img class="hero-photo" src="{{ '/assets/images/headshot.jpeg' | relative_url }}" alt="Ryan Ye" width="280" height="280" decoding="async" fetchpriority="high">
    <div class="hero-id">
      <ul class="profile-icons" role="list">
        <li><a href="mailto:{{ site.email }}" aria-label="Email" title="Email">{% include icon.html name="envelope" class="i-mail" %}</a></li>
        <li><a href="https://github.com/{{ site.github_username }}" target="_blank" rel="me noopener noreferrer" aria-label="GitHub" title="GitHub">{% include icon.html name="github" class="i-github" %}</a></li>
        <li><a href="https://linkedin.com/in/{{ site.linkedin_username }}" target="_blank" rel="me noopener noreferrer" aria-label="LinkedIn" title="LinkedIn">{% include icon.html name="linkedin" class="i-linkedin" %}</a></li>
        <li><a href="{{ site.data.research.google_scholar }}" target="_blank" rel="me noopener noreferrer" aria-label="Google Scholar" title="Google Scholar">{% include icon.html name="graduation-cap" class="i-scholar" %}</a></li>
      </ul>
      <a class="resume-link" href="{{ '/resume.pdf' | relative_url }}" aria-label="Resume (PDF)">Resume</a>
      <p class="profile-faith-note">Jesus is King</p>
    </div>
  </div>
  <div class="hero-intro">
    {{ about.intro | markdownify }}{{ about.outside | markdownify }}
    <p class="spotify-widget" id="spotify-widget" hidden>
      {% include icon.html name="spotify" class="spotify-icon" %}
      <span id="spotify-now-playing"></span>
    </p>
  </div>
</header>

<section class="home-section" aria-labelledby="home-work">
  <div class="section-head">
    <h2 class="section-title" id="home-work">Selected work</h2>
    <a class="section-more" href="{{ '/research/' | relative_url }}">All research &rarr;</a>
  </div>
  <ul class="work-grid" role="list">
    {% for position in site.data.research.positions %}{% if position.homepage %}
    <li class="work-card">
      <p class="eyebrow">Research &middot; {{ position.date }}</p>
      <div class="work-body">
        <h3 class="work-title">{{ position.index_title | default: position.title }}</h3>
        {% if position.card_summary %}<p class="work-summary">{{ position.card_summary | markdownify | remove: '<p>' | remove: '</p>' | strip }}</p>{% endif %}
      </div>
      <a class="work-more" href="{{ '/research/' | relative_url }}#{{ position.slug }}">Details<span class="visually-hidden"> on {{ position.index_title | default: position.title }}</span> <span aria-hidden="true">&rarr;</span></a>
    </li>
    {% endif %}{% endfor %}
  </ul>
</section>

<div class="home-columns">
  <div class="home-main">
  <section class="home-section" aria-labelledby="home-projects">
    <div class="section-head">
      <h2 class="section-title" id="home-projects">Projects</h2>
      <a class="section-more" href="{{ '/projects/' | relative_url }}">All projects &rarr;</a>
    </div>
    {% include project_rows.html %}
  </section>
  </div>

  <div class="home-side">
    {% assign selected_pubs = site.data.research.publications | where: "selected", true | sort: "rank" %}
    {% if selected_pubs.size > 0 %}
    <section class="home-section side-section" aria-labelledby="home-pubs">
      <div class="section-head">
        <h2 class="section-title" id="home-pubs">Publications</h2>
        <a class="section-more" href="{{ '/publications/' | relative_url }}">All publications &rarr;</a>
      </div>
      <ul class="side-list" role="list">
        {% for pub in selected_pubs %}
        <li>
          <p class="side-title">{% if pub.url %}<a href="{{ pub.url }}" target="_blank" rel="noopener noreferrer">{{ pub.title }}</a>{% else %}{{ pub.title }}{% endif %}</p>
          <p class="side-meta">{{ pub.venue }}{% if pub.role %} &middot; {{ pub.role | downcase }}{% endif %}</p>
        </li>
        {% endfor %}
      </ul>
    </section>
    {% endif %}

    <section class="home-section side-section" aria-labelledby="home-updates">
      <h2 class="section-title" id="home-updates">Updates</h2>
      {% assign updates = site.data.news | sort: "date" | reverse %}
      <dl class="side-list updates">
        {% for item in updates limit:3 %}
        <div>
          <dt class="side-date"><time datetime="{{ item.date | date: '%Y-%m-%d' }}">{% if item.display %}{{ item.display }}{% else %}{{ item.date | date: "%b %Y" }}{% endif %}</time></dt>
          <dd class="side-text">{{ item.text | markdownify | remove: '<p>' | remove: '</p>' | strip }}</dd>
        </div>
        {% endfor %}
      </dl>
    </section>

  </div>
</div>

{% include blog_entries.html %}
{% if blog_entries.size > 0 %}
<section class="home-section" aria-labelledby="home-blog">
  <div class="section-head">
    <h2 class="section-title" id="home-blog">From the blog</h2>
    <a class="section-more" href="{{ '/blog/' | relative_url }}">All posts &rarr;</a>
  </div>
  <ul class="teasers" role="list">
    {% for entry in blog_entries limit:3 %}
    {% assign has_images = false %}{% if entry.images and entry.images.size > 0 %}{% assign has_images = true %}{% endif %}
    <li class="teaser">
      {% if has_images %}
      {% assign cover = entry.images[0] %}
      {% capture t_src %}{% include image_src.html src=cover.src variant="thumb" %}{% endcapture %}
      <img class="teaser-thumb" src="{{ t_src | strip }}" alt="" width="600" height="375" loading="lazy" decoding="async">
      {% endif %}
      <div class="teaser-body">
        <h3 class="teaser-title"><a href="{{ entry.url | relative_url }}">{{ entry.title }}</a></h3>
        <p class="teaser-meta"><time datetime="{{ entry.date | date_to_xmlschema }}">{{ entry.date | date: "%b %-d, %Y" }}</time>{% if entry.collection == "albums" %} &middot; Album{% if has_images %} &middot; {{ entry.images.size }} photo{% if entry.images.size != 1 %}s{% endif %}{% endif %}{% endif %}</p>
        {% capture entry_line %}{% include blog_line.html entry=entry %}{% endcapture %}{% assign entry_line = entry_line | strip %}
        {% if entry_line != "" %}<p class="teaser-line">{{ entry_line }}</p>{% endif %}
      </div>
    </li>
    {% endfor %}
  </ul>
</section>
{% endif %}

<script>
(function () {
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
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
              .replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }

  /* Long names are shortened (with an ellipsis; the full name stays in the
     link title) so the whole line, "(N hours ago)" included, fits in the
     two reserved lines at desktop widths. */
  function clip(str, n) {
    str = String(str || '');
    return str.length > n ? str.slice(0, n - 1).replace(/\s+$/, '') + '\u2026' : str;
  }

  function link(href, name, n) {
    var shown = escapeHtml(clip(name, n));
    return href ? '<a href="' + href + '" target="_blank" rel="noopener noreferrer" title="' + escapeHtml(name) + '">' + shown + '</a>' : shown;
  }

  function safeUrl(u) {
    return /^https:\/\/open\.spotify\.com\//.test(u) ? u : '';
  }

  /* Spotify "recently listened". The JSON lives on the spotify-data branch
     (written by .github/workflows/update-spotify.yml) so updates never touch
     main or trigger a deploy. If anything fails the widget stays hidden. */
  var widget = document.getElementById('spotify-widget');
  var spotifyEl = document.getElementById('spotify-now-playing');
  if (widget && spotifyEl) {
    var controller = new AbortController();
    var timeoutId = setTimeout(function () { controller.abort(); }, 5000);
    var url = 'https://raw.githubusercontent.com/{{ site.github_username }}/{{ site.github_username }}.github.io/spotify-data/now-playing.json';
    fetch(url, { signal: controller.signal, cache: 'no-cache' })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (data) {
        if (!data || !data.track) return;
        var t = data.track;
        var artistLinks = (t.artists || []).slice(0, 2).map(function (a) {
          var href = safeUrl(a.url);
          return link(href, a.name, 28);
        }).join(', ');
        var trackHref = safeUrl(t.url);
        var html = 'listened to ' + link(trackHref, t.name, 48) +
          (artistLinks ? ' by ' + artistLinks : '');
        if (data.context && data.context.name) {
          var ctxType = data.context.type || '';
          var ctxLabel = ctxType === 'playlist' ? 'playlist' : ctxType === 'album' ? 'album' : ctxType === 'artist' ? 'artist' : '';
          var ctxHref = safeUrl(data.context.url || '');
          html += ' from ' + (ctxLabel ? ctxLabel + ' ' : '') +
            link(ctxHref, data.context.name, 36);
        }
        if (t.played_at) html += ' <span class="spotify-time">(' + timeAgo(t.played_at) + ')</span>';
        spotifyEl.innerHTML = html;
        widget.hidden = false;
      })
      .catch(function () { /* keep hidden */ })
      .finally(function () { clearTimeout(timeoutId); });
  }
})();
</script>
