---
layout: default
title: "Gallery"
permalink: /gallery/
description: "Photo gallery from Ryan Ye's blog: campus life, travel, and events."
---

<header class="page-head">
  <h1>Gallery</h1>
</header>

{%- comment -%}
  Album cards only (the photos themselves live on each post or album page).
  Cards come from both blog posts with `images` and standalone albums (the
  `albums` collection), merged and sorted newest first. Standalone albums
  with `draft: true` are skipped here; they also need `published: false` in
  their front matter or Jekyll will still build the page.
{%- endcomment -%}
{% assign with_photos = "" | split: "" %}
{% for post in site.posts %}
  {% if post.images and post.images.size > 0 %}
    {% assign with_photos = with_photos | push: post %}
  {% endif %}
{% endfor %}
{% for album in site.albums %}
  {% unless album.draft == true or album.published == false %}
    {% if album.images and album.images.size > 0 %}
      {% assign with_photos = with_photos | push: album %}
    {% endif %}
  {% endunless %}
{% endfor %}
{% assign albums_sorted = with_photos | sort: "date" | reverse %}

{% if albums_sorted.size > 0 %}
<section class="page-section page-section-first" aria-label="Albums">
  <div class="gallery-grid">
    {% for item in albums_sorted %}
      {% assign cover = item.images[0] %}
      {% assign cover_key = cover.src | remove_first: '/assets/images/' %}
      {% assign cover_meta = site.data.image_meta[cover_key] %}
      {% capture cover_src %}{% include image_src.html src=cover.src variant="thumb" %}{% endcapture %}
      <a href="{{ item.url | relative_url }}" class="gallery-album-card">
        <div class="gallery-album-cover">
          <img src="{{ cover_src | strip }}" alt="" {% if cover_meta and cover_meta.thumb %}width="{{ cover_meta.thumb.w }}" height="{{ cover_meta.thumb.h }}"{% endif %} {% if forloop.index > 2 %}loading="lazy"{% else %}fetchpriority="high"{% endif %} decoding="async">
        </div>
        <div class="gallery-album-info">
          {%- comment -%}
            Card title: a post's `album_title`, else its title. Caption (one
            line, hidden when empty): `album_caption`; for a standalone album
            without one, the first sentence of its `description`.
          {%- endcomment -%}
          {% assign card_caption = item.album_caption %}
          {% if card_caption == nil or card_caption == "" %}
            {% if item.collection == "albums" and item.description and item.description != "" %}
              {% assign first_sentence = item.description | split: ". " | first %}
              {% if first_sentence != item.description %}{% assign card_caption = first_sentence | append: "." %}{% else %}{% assign card_caption = item.description %}{% endif %}
            {% endif %}
          {% endif %}
          <h2 class="gallery-album-title">{{ item.album_title | default: item.title }}</h2>
          {% if card_caption and card_caption != "" %}<p class="gallery-album-caption">{{ card_caption }}</p>{% endif %}
          <p class="gallery-album-meta">
            {% if item.date %}<time datetime="{{ item.date | date_to_xmlschema }}">{{ item.date | date: "%b %-d, %Y" }}</time> &middot; {% endif %}
            {{ item.images.size }} photo{% if item.images.size != 1 %}s{% endif %}
          </p>
        </div>
      </a>
    {% endfor %}
  </div>
</section>
{% else %}
<p class="empty-note">No photo albums yet.</p>
{% endif %}
