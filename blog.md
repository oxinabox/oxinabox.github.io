---
layout: default
title: A Technical Blog
---

<section class="column_block">
    <h3>Index</h3>
    <ul>
      {% for post in site.posts %}
        <li>
          <a href="{{ post.url }}">{{ post.title }}</a>
        </li>
      {% endfor %}
    </ul>
</section>

<div class="column_block_wide">
  {% for post in site.posts %}
    <section>
      <h2><a href="{{ post.url }}">{{ post.title }}</a></h2>
      {{ post.excerpt }}
      <a href="{{ post.url }}"><emph>more ...</emph></a>
    </section>
  {% endfor %}
<div>
