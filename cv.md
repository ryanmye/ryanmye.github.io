---
layout: default
title: "CV"
permalink: /cv/
description: "CV of Ryan Ye, computer science student at Cornell University — research experience, publications, projects, teaching, and honors."
---

{%- comment -%}
  Fully data-driven: edit _data/about.yml, research.yml and projects.yml, not
  this file. A classic wide CV: at >= 1024px each section's heading sits in
  a left rail (3 of 12 columns) and its rows fill the rest, with dates
  right-aligned. Education and Skills come first; the one-sentence
  about.cv_summary sits under the h1.
{%- endcomment -%}
<header class="page-head">
  <h1>CV</h1>
  <p class="page-lede">{{ site.data.about.cv_summary }}</p>
  <p class="page-links">
    <a href="mailto:{{ site.email }}">{{ site.email }}</a><span class="sep" aria-hidden="true"> &middot; </span>
    <a href="https://github.com/{{ site.github_username }}" target="_blank" rel="noopener noreferrer">GitHub</a><span class="sep" aria-hidden="true"> &middot; </span>
    <a href="https://linkedin.com/in/{{ site.linkedin_username }}" target="_blank" rel="noopener noreferrer">LinkedIn</a><span class="sep" aria-hidden="true"> &middot; </span>
    <a href="{{ '/resume.pdf' | relative_url }}">Resume (PDF)</a>
  </p>
</header>

<section class="cv-block" aria-labelledby="cv-education">
  <h2 class="section-title" id="cv-education">Education</h2>
  <div class="cv-body">
    <ul class="rows" role="list">
      <li class="row">
        <div class="row-main">
          <h3 class="row-title">{{ site.data.about.education.institution }}</h3>
          <p class="row-meta">{{ site.data.about.education.degree }}</p>
          <ul class="row-bullets">
            <li>GPA {{ site.data.about.education.gpa }}</li>
            <li>Coursework: {{ site.data.about.education.coursework | join: ", " }}</li>
          </ul>
        </div>
        <p class="row-date">Expected {{ site.data.about.education.expected }}</p>
      </li>
    </ul>
  </div>
</section>

<section class="cv-block" aria-labelledby="cv-skills">
  <h2 class="section-title" id="cv-skills">Skills</h2>
  <dl class="cv-body skill-grid">
    <dt>Languages</dt><dd>{{ site.data.about.skills.languages }}</dd>
    <dt>Libraries</dt><dd>{{ site.data.about.skills.libraries }}</dd>
    <dt>Tools</dt><dd>{{ site.data.about.skills.tools }}</dd>
  </dl>
</section>

<section class="cv-block" aria-labelledby="cv-research">
  <h2 class="section-title" id="cv-research">Research</h2>
  <div class="cv-body">
    {%- comment -%} The role is stated once; entry titles are "Sun Lab · <project>". {%- endcomment -%}
    {% assign cv_positions = site.data.research.positions | where: "cv", true %}
    {% assign lead = cv_positions.last %}
    <p class="cv-role">{{ lead.role }}, {{ lead.lab }} (PI {{ lead.pi }}), {{ lead.institution }}</p>
    <ul class="rows" role="list">
      {% for position in cv_positions %}
      <li class="row">
        <div class="row-main">
          <h3 class="row-title">{{ position.cv_title }}</h3>
          {% if position.cv_subtitle %}<p class="row-meta">{{ position.cv_subtitle }}</p>{% endif %}
          <ul class="row-bullets">
            {% for bullet in position.cv_bullets %}<li>{{ bullet }}</li>
            {% endfor %}
          </ul>
        </div>
        <p class="row-date">{{ position.cv_date }}</p>
      </li>
      {% endfor %}
    </ul>
  </div>
</section>

<section class="cv-block" aria-labelledby="cv-pubs">
  <h2 class="section-title" id="cv-pubs">Publications</h2>
  <div class="cv-body">
    {% assign ranked_pubs = site.data.research.publications | sort: "rank" %}
    {% include pub_rows.html pubs=ranked_pubs descriptions=false %}
  </div>
</section>

<section class="cv-block" aria-labelledby="cv-projects">
  <h2 class="section-title" id="cv-projects">Projects</h2>
  <div class="cv-body">
    <ul class="rows" role="list">
      {% for project in site.data.projects.projects %}{% if project.cv %}
      <li class="row">
        <div class="row-main">
          <h3 class="row-title">{{ project.title }}{% if project.url %} <a class="row-link" href="{{ project.url }}" target="_blank" rel="noopener noreferrer">code<span class="visually-hidden"> for {{ project.title }}</span> <span aria-hidden="true">&rarr;</span></a>{% endif %}</h3>
          <p class="row-meta">{{ project.cv_tech }}</p>
          <ul class="row-bullets">
            {% for bullet in project.cv_bullets %}<li>{{ bullet }}</li>
            {% endfor %}
          </ul>
        </div>
        <p class="row-date">{{ project.date }}</p>
      </li>
      {% endif %}{% endfor %}
    </ul>
  </div>
</section>

<section class="cv-block" aria-labelledby="cv-teaching">
  <h2 class="section-title" id="cv-teaching">Teaching &amp; leadership</h2>
  <div class="cv-body">
    <ul class="rows" role="list">
      {% for entry in site.data.about.teaching %}
      <li class="row">
        <div class="row-main">
          <h3 class="row-title">{{ entry.title }}</h3>
          <p class="row-meta">{{ entry.subtitle }}</p>
          <ul class="row-bullets">
            {% for bullet in entry.bullets %}<li>{{ bullet }}</li>
            {% endfor %}
          </ul>
        </div>
        <p class="row-date">{{ entry.date }}</p>
      </li>
      {% endfor %}
    </ul>
  </div>
</section>

<section class="cv-block" aria-labelledby="cv-interests">
  <h2 class="section-title" id="cv-interests">Interests</h2>
  <ul class="cv-body cv-list" role="list">
    {% for interest in site.data.research.interests %}<li><strong>{{ interest | split: " — " | first }}:</strong> {{ interest | split: " — " | last }}</li>
    {% endfor %}
  </ul>
</section>

<section class="cv-block" aria-labelledby="cv-honors">
  <h2 class="section-title" id="cv-honors">Honors</h2>
  <ul class="cv-body cv-list" role="list">
    {% for honor in site.data.about.honors %}<li>{{ honor }}</li>
    {% endfor %}
  </ul>
</section>
