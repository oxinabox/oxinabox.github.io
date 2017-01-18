{% extends 'markdown.tpl' %}

{%- block header -%}
---
layout: default
title: "{{resources['metadata']['name']}}"
tags:
    - julia
    - jupyter-notebook
---
{%- endblock header -%}

{% block in_prompt %}
**In [{{ cell.execution_count }}]:**
{% endblock in_prompt %}

{% block input %}
{{ '{% highlight julia %}' }}
{{ cell.source }}
{{ '{% endhighlight %}' }}
{% endblock input %}
