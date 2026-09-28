---
layout: null
permalink: /album-editor/
sitemap: false
---
{%- comment -%}
  The album editor merged into the studio at /editor/. This page keeps the
  old URL (and the navbar's "albums" link) working. Dev-only: excluded from
  production builds in _config_prod.yml.
{%- endcomment -%}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="robots" content="noindex, noai, noimageai">
  <meta name="tdm-reservation" content="1">
  <title>Studio</title>
  <meta http-equiv="refresh" content="0; url={{ '/editor/#albums' | relative_url }}">
</head>
<body>
  <p>The album editor is now part of the <a href="{{ '/editor/#albums' | relative_url }}">studio</a>.</p>
</body>
</html>
