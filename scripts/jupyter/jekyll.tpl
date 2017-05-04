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


{% block input %}
{{ '{% highlight julia %}' }}
{{ cell.source }}
{{ '{% endhighlight %}' }}
{% endblock input %}

{% block stream %}
{{ '{% highlight plaintext %}' }}
{{ output.text | strip_ansi}}
{{ '{% endhighlight %}' }}
{% endblock stream %}
