---
layout: default
title: "Publications"
permalink: /publications/
description: "Publications by Ryan Ye: research papers and posters on computer vision, deep learning, and economics."
---

<header class="page-head">
  <h1>Publications</h1>
  <p class="page-links"><a href="{{ site.data.research.google_scholar }}" target="_blank" rel="noopener noreferrer">Google Scholar</a></p>
</header>

{%- comment -%}
  All publications sorted by `rank` (1 = most significant), then grouped by
  `type`, so the group holding the best-ranked entry comes first (Posters,
  for the ADSA poster) and each group keeps rank order: "poster" is
  Posters, "journal" is Journal articles.
{%- endcomment -%}
{% assign ranked = site.data.research.publications | sort: "rank" %}
{% assign groups = ranked | group_by: "type" %}
{% for group in groups %}
<section class="page-section{% if forloop.first %} page-section-first{% endif %}" aria-labelledby="pubs-{{ group.name | default: 'other' }}">
  <h2 class="section-title" id="pubs-{{ group.name | default: 'other' }}">{% case group.name %}{% when "poster" %}Posters{% when "journal" %}Journal articles{% else %}Other{% endcase %}</h2>
  {% include pub_rows.html pubs=group.items descriptions=true %}
</section>
{% endfor %}
