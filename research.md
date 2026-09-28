---
layout: default
title: "Research"
permalink: /research/
description: "AI for science research at Cornell: agents for open-ended scientific discovery and computer vision for animal behavior."
---

{%- comment -%}
  One header line per lab (all positions are currently in the Sun Lab):
  "<lab>, <institution> · PI <pi> · since <start of the lab's oldest position>".
  Positions are listed newest first in research.yml, so the oldest is last.
  The positions follow the page header directly (their section heading is visually hidden); each position is an article whose id is its
  `slug` (the homepage cards link to /research/#<slug>): eyebrow, a 22px
  title (below the 28px section headings), the description, then a closed
  <details> with the focus items and the note. When research.yml sets a
  `figure`, it sits in a right column (columns 9 to 12 at >= 1024px) beside
  the text; without one the text is unchanged. The
  script at the bottom opens a section's <details> when the page is opened
  (or navigated) to its anchor; without JS it stays closed.
{%- endcomment -%}
{% assign labs = site.data.research.positions | group_by: "lab" %}
<header class="page-head">
  <h1>Research</h1>
  {% for lab in labs %}{% assign first = lab.items.first %}{% assign oldest = lab.items.last %}
  <p class="page-lede">{{ lab.name }}, {{ first.institution }} &middot; PI {{ first.pi }} &middot; <span class="nowrap">since {{ oldest.date | split: " – " | first }}</span></p>
  {% endfor %}
  <p class="page-links"><a href="{{ site.data.research.google_scholar }}" target="_blank" rel="noopener noreferrer">Google Scholar</a><span class="sep" aria-hidden="true"> &middot; </span><a href="{{ '/publications/' | relative_url }}">All publications</a></p>
</header>

<section class="page-section page-section-first" aria-labelledby="research-work">
<h2 class="visually-hidden" id="research-work">Research projects</h2>
{% for position in site.data.research.positions %}
{% assign sid = position.slug | default: forloop.index | prepend: "" %}
<article class="study" id="{{ sid }}" aria-labelledby="{{ sid }}-title">
  <p class="eyebrow">{{ position.date }} &middot; {{ position.role }}</p>
  <h3 class="study-title" id="{{ sid }}-title">{{ position.title }}</h3>
  <div class="study-body{% if position.figure %} has-figure{% endif %}">
    {% if position.figure %}<div class="study-media">{% include figure_slot.html figure=position.figure %}</div>{% endif %}
    <div class="study-text">
      <p class="study-desc">{{ position.description | strip }}</p>
      {% if position.focus or position.note %}
      <details class="more study-more">
        <summary>Details<span class="visually-hidden"> on {{ position.title }}</span></summary>
        <div class="more-body">
          {% if position.focus %}
          <ul class="focus-grid" role="list">
            {% for item in position.focus %}
            <li>
              <h4 class="focus-title">{{ item.title }}</h4>
              <p class="focus-detail">{{ item.detail }}</p>
            </li>
            {% endfor %}
          </ul>
          {% endif %}
          {% if position.note %}<p class="study-note">{{ position.note }}</p>{% endif %}
        </div>
      </details>
      {% endif %}
    </div>
  </div>
</article>
{% endfor %}
</section>

{% assign selected_pubs = site.data.research.publications | where: "selected", true | sort: "rank" %}
<section class="page-section" aria-labelledby="research-pubs">
  <div class="section-head">
    <h2 class="section-title" id="research-pubs">Publications</h2>
    <a class="section-more" href="{{ '/publications/' | relative_url }}">All publications &rarr;</a>
  </div>
  {% include pub_rows.html pubs=selected_pubs descriptions=true %}
</section>

<section class="page-section" aria-labelledby="research-interests">
  <h2 class="section-title" id="research-interests">Interests</h2>
  <ul class="interest-grid" role="list">
    {% for interest in site.data.research.interests %}<li><strong>{{ interest | split: " — " | first }}</strong> {{ interest | split: " — " | last }}</li>
    {% endfor %}
  </ul>
</section>

<script>
(function () {
  /* Opening /research/#<slug> (from a homepage card) opens that section's Details. */
  function openFromHash() {
    var id = decodeURIComponent(location.hash.slice(1));
    if (!id) return;
    var el = document.getElementById(id);
    var more = el && el.classList.contains('study') && el.querySelector('details.study-more');
    if (more) more.open = true;
  }
  openFromHash();
  window.addEventListener('hashchange', openFromHash);
})();
</script>
