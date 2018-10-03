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

{% block execute_result scoped %}
<div class="jupyter-cell">
{% for type in output.data | filter_data_type %}  {# Not actually a for-loop, only gives the single preferred type #}
{% if type in ['text/plain'] %}
{{ '{% highlight plaintext %}' }}
{{ output.data['text/plain'] | strip_ansi}}
{{ '{% endhighlight %}' }}
{% else %}
{{ output.data[type] }}
{% endif %}

{% endfor %}

</div>
{% endblock execute_result %}



