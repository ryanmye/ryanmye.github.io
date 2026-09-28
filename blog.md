---
layout: default
title: "Blog"
permalink: /blog/
description: "Blog of Ryan Ye, computer science student at Cornell University: notes on research, school, and life."
---

<header class="page-head">
  <h1>Blog</h1>
  <p class="page-lede">{{ site.data.about.blog_blurb }}</p>
  <p class="page-links"><a href="{{ '/gallery/' | relative_url }}">Gallery <span aria-hidden="true">&rarr;</span></a></p>
</header>

{%- comment -%}
  Posts and standalone albums together, grouped by year, newest first: a
  small uppercase year label, then one row per item: a 120x90 thumbnail (the
  `thumb` variant of images[0]) when it has `images` (the column is kept for
  every row of a year that has any thumbnail, so titles align), the linked
  22px title, a line of text and, right-aligned, the date with the photo
  count under it (an album's reads "Album · N photos"). The list comes
  from _includes/blog_entries.html and each line from
  _includes/blog_line.html, both shared with the homepage "From the blog".
{%- endcomment -%}
{% include blog_entries.html %}{% assign entries = blog_entries %}
{% if entries.size > 0 %}
{% assign years = entries | group_by_exp: "item", "item.date | date: '%Y'" %}
{% for year in years %}
{%- comment -%} Reserve the thumbnail column for the whole year when any row in it has photos, so titles line up. {%- endcomment -%}
{% assign year_thumbs = false %}{% for p in year.items %}{% if p.images and p.images.size > 0 %}{% assign year_thumbs = true %}{% endif %}{% endfor %}
<section class="page-section blog-year{% if forloop.first %} page-section-first{% endif %}" aria-labelledby="blog-{{ year.name }}">
  <h2 class="year-label" id="blog-{{ year.name }}">{{ year.name }}</h2>
  <ul class="rows post-rows{% if year_thumbs %} rows-thumbs{% endif %}" role="list">
    {% for post in year.items %}
    {% assign is_album = false %}{% if post.collection == "albums" %}{% assign is_album = true %}{% endif %}
    {% assign has_images = false %}{% if post.images and post.images.size > 0 %}{% assign has_images = true %}{% endif %}
    <li class="row{% if has_images %} has-thumb{% endif %}">
      {% if has_images %}
      {% assign t = post.images[0] %}
      {% capture t_src %}{% include image_src.html src=t.src variant="thumb" %}{% endcapture %}
      <img class="row-thumb" src="{{ t_src | strip }}" alt="" width="120" height="90" loading="lazy" decoding="async">
      {% endif %}
      <div class="row-main">
        <h3 class="row-title post-row-title"><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
        {% capture entry_line %}{% include blog_line.html entry=post %}{% endcapture %}{% assign entry_line = entry_line | strip %}
        {% if entry_line != "" or is_album == false %}<p class="row-line">{{ entry_line }}</p>{% endif %}
      </div>
      <p class="row-date"><time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%b %-d" }}</time>{% if has_images or is_album %}<span class="row-count">{% if is_album %}Album{% if has_images %} &middot; {% endif %}{% endif %}{% if has_images %}{{ post.images.size }} photo{% if post.images.size != 1 %}s{% endif %}{% endif %}</span>{% endif %}</p>
    </li>
    {% endfor %}
  </ul>
</section>
{% endfor %}
{% else %}
<p class="empty-note">No posts yet.</p>
{% endif %}
