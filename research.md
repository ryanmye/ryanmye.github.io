---
layout: default
title: "Research"
permalink: /research/
description: "Computer vision research at Cornell focused on animal behavior."
---

<div class="page-header">
  <h1>Research</h1>
  <p class="subtitle">{{ site.data.research.subtitle }}</p>
  <p style="margin-top:0.5rem;font-size:0.9rem">
    <a href="{{ site.data.research.google_scholar }}" target="_blank" rel="noopener noreferrer">
      {% include icon.html name="graduation-cap" %} Google Scholar
    </a>
  </p>
</div>

## Publications

{% assign selected_pubs = site.data.research.publications | where: "selected", true %}
{% for pub in selected_pubs %}
<div class="pub-tile">
  <div class="pub-tile-image">
    {% if pub.image %}
    <img src="{{ pub.image | relative_url }}" alt="{{ pub.title }}">
    {% else %}
    {% include icon.html name="file-lines" class="pub-tile-icon" %}
    {% endif %}
  </div>
  <div class="pub-tile-body">
    <p class="pub-tile-title">{% if pub.url %}<a href="{{ pub.url }}" target="_blank" rel="noopener noreferrer">{{ pub.title }}</a>{% else %}{{ pub.title }}{% endif %}</p>
    <p class="pub-tile-authors">{{ pub.authors }}</p>
    <p class="pub-tile-venue">{{ pub.venue }}</p>
    {% if pub.description %}<p class="pub-tile-description">{{ pub.description }}</p>{% endif %}
    {% if pub.tags %}<div class="tags">{% for tag in pub.tags %}<span class="tag">{{ tag }}</span>{% endfor %}</div>{% endif %}
  </div>
</div>
{% endfor %}
<a href="{{ '/publications' | relative_url }}">more publications &rarr;</a>

---

## Research Positions

{% for position in site.data.research.positions %}
<div class="research-entry">
  <h3>{{ position.title }}</h3>
  <p class="research-meta">
    <span class="research-role">{{ position.role }}</span> &mdash; {{ position.lab }}, {{ position.institution }}
    &mdash; <span class="research-date">{{ position.date }}</span>
  </p>
  <p>{{ position.description }}</p>
  <p><strong>My work has focused on:</strong></p>
  <ul>
    {% for item in position.focus %}
    <li>
      <strong>{{ item.title }}</strong> — {{ item.detail }}
    </li>
    {% endfor %}
  </ul>
  {% if position.note %}
  <p style="font-size:0.875rem;color:var(--muted)">
    {{ position.note }}
  </p>
  {% endif %}
</div>
{% unless forloop.last %}
---
{% endunless %}
{% endfor %}

---

## Research Interests

<ul>
{% for interest in site.data.research.interests %}
  <li><strong>{{ interest | split: " — " | first }}</strong> — {{ interest | split: " — " | last }}</li>
{% endfor %}
</ul>
