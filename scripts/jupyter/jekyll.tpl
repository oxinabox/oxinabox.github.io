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
**Input:**
{% endblock in_prompt %}


{% block input %}
{{ '{% highlight julia %}' }}
{{ cell.source }}
{{ '{% endhighlight %}' }}
{% endblock input %}

{% block output_prompt %}
**Output:**
{% endblock output_prompt %}


{% block stream %}
{{ '{% highlight plaintext %}' }}
{{ output.text | strip_ansi}}
{{ '{% endhighlight %}' }}
{% endblock stream %}
