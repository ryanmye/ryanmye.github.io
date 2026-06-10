---
layout: default
title: "Publications"
permalink: /publications/
description: "Publications by Ryan Ye — research papers on AI, computer vision, and economics."
---

<div class="page-header">
  <h1>Publications</h1>
  <p style="margin-top:0.5rem;font-size:0.9rem">
    <a href="{{ site.data.research.google_scholar }}" target="_blank" rel="noopener noreferrer">
      {% include icon.html name="graduation-cap" %} Google Scholar
    </a>
  </p>
</div>

{% for pub in site.data.research.publications %}
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
