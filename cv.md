---
layout: default
title: "CV"
permalink: /cv/
description: "CV of Ryan Ye, computer science student at Cornell University — research experience, publications, projects, teaching, and honors."
---

<div class="page-header page-header-resume">
  <h1>CV</h1>
  <p class="resume-download">
    <a href="{{ '/25Dec_Ye_Ryan_Resume.pdf' | relative_url }}" target="_blank" rel="noopener noreferrer" class="btn-download">
      <i class="fas fa-file-pdf"></i> Download PDF
    </a>
  </p>
</div>

<div class="resume-section">
  <h2>Education</h2>
  <div class="resume-item">
    <div class="resume-item-header">
      <span class="resume-item-title">{{ site.data.about.education.institution }}</span>
      <span class="resume-item-date">Expected {{ site.data.about.education.expected }}</span>
    </div>
    <p class="resume-item-sub">{{ site.data.about.education.degree }}</p>
    <ul>
      <li>GPA: {{ site.data.about.education.gpa }}</li>
      <li>Relevant coursework: {{ site.data.about.education.coursework | join: ", " }}</li>
    </ul>
  </div>
</div>

<div class="resume-section">
  <h2>Skills</h2>
  <div class="resume-item">
    <div class="profile-skills">
      <span class="profile-skills-label">Programming:</span>
      <div class="profile-skills-row">
        {% assign prog = site.data.about.skills.programming | split: ", " %}
        {% for s in prog %}<span class="tag">{{ s }}</span>{% endfor %}
      </div>
      <span class="profile-skills-label">ML & tools:</span>
      <div class="profile-skills-row">
        {% assign ml = site.data.about.skills.machine_learning | split: ", " %}
        {% assign tools = site.data.about.skills.tools | split: ", " %}
        {% for s in ml %}<span class="tag">{{ s }}</span>{% endfor %}
        {% for s in tools %}<span class="tag">{{ s }}</span>{% endfor %}
      </div>
    </div>
  </div>
</div>

<div class="resume-section">
  <h2>Research</h2>
  {% for position in site.data.research.positions %}{% if position.cv %}
  <div class="resume-item">
    <div class="resume-item-header">
      <span class="resume-item-title">{{ position.cv_title }}</span>
      <span class="resume-item-date">{{ position.cv_date }} &middot; {{ position.institution }}</span>
    </div>
    <p class="resume-item-sub">{{ position.cv_subtitle }}</p>
    <ul>
      {% for bullet in position.cv_bullets %}<li>{{ bullet }}</li>
      {% endfor %}
    </ul>
  </div>
  {% endif %}{% endfor %}
</div>

<div class="resume-section">
  <h2>Publications</h2>
  {% for pub in site.data.research.publications %}
  <div class="resume-item">
    <div class="resume-item-header">
      <span class="resume-item-title">{{ pub.title }}</span>
      <span class="resume-item-date">{{ pub.cv_year }}</span>
    </div>
    <p class="resume-item-sub">{{ pub.cv_subtitle }}</p>
  </div>
  {% endfor %}
</div>

<div class="resume-section">
  <h2>Projects</h2>
  {% for project in site.data.projects.projects %}{% if project.cv %}
  <div class="resume-item">
    <div class="resume-item-header">
      <span class="resume-item-title">{% if project.url %}<a href="{{ project.url }}" target="_blank" rel="noopener noreferrer">{{ project.title }}</a>{% else %}{{ project.title }}{% endif %}</span>
      <span class="resume-item-date">{{ project.date }}</span>
    </div>
    <p class="resume-item-sub">{{ project.cv_tech }}{% if project.url %} &middot; <a href="{{ project.url }}" target="_blank" rel="noopener noreferrer">GitHub</a>{% endif %}</p>
    <ul>
      {% for bullet in project.cv_bullets %}<li>{{ bullet }}</li>
      {% endfor %}
    </ul>
  </div>
  {% endif %}{% endfor %}
</div>

<div class="resume-section">
  <h2>Teaching &amp; Leadership</h2>
  {% for entry in site.data.about.teaching %}
  <div class="resume-item">
    <div class="resume-item-header">
      <span class="resume-item-title">{{ entry.title }}</span>
      <span class="resume-item-date">{{ entry.date }}</span>
    </div>
    <p class="resume-item-sub">{{ entry.subtitle }}</p>
    <ul>
      {% for bullet in entry.bullets %}<li>{{ bullet }}</li>
      {% endfor %}
    </ul>
  </div>
  {% endfor %}
</div>

<div class="resume-section">
  <h2>Interests</h2>
  <div class="resume-item">
    <ul>
      {% for interest in site.data.about.interests %}
      <li><strong>{{ interest | split: " — " | first }}</strong> — {{ interest | split: " — " | last }}</li>
      {% endfor %}
    </ul>
  </div>
</div>

<div class="resume-section">
  <h2>Honors</h2>
  <div class="resume-item">
    <ul>
      {% for honor in site.data.about.honors %}<li>{{ honor }}</li>
      {% endfor %}
    </ul>
  </div>
</div>
