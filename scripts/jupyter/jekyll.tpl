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
<div class="jupyter-input jupyter-cell">
{{ '{% highlight julia %}' }}
{{ cell.source }}
{{ '{% endhighlight %}' }}
</div>
{% endblock input %}

{% block output_prompt %}
**Output:**
{% endblock output_prompt %}


{% block stream %}
<div class="jupyter-stream jupyter-cell">
{{ '{% highlight plaintext %}' }}
{{ output.text | strip_ansi}}
{{ '{% endhighlight %}' }}
</div>
{% endblock stream %}
