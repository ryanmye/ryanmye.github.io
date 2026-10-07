---
layout: default
title: "Projects"
permalink: /projects/
description: "Projects by Ryan Ye, Cornell CS student: machine learning and software projects from courses, hackathons, and personal work."
---

<header class="page-head">
  <h1>Projects</h1>
  <p class="page-lede">Course, hackathon, and personal projects. Research is on the <a href="{{ '/research/' | relative_url }}">research page</a>.</p>
  {% include spotify_line.html %}
</header>

{%- comment -%}
  The same compact rows as the homepage (title, "code →", one-line summary,
  date on the right), each with a <details> holding the description and
  bullets. projects.yml order.
{%- endcomment -%}
<section class="page-section page-section-first" aria-label="All projects">
  {% include project_rows.html details=true heading="h2" %}
</section>
