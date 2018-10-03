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
{# For now only do plain text
{% for type in output.data | filter_data_type %}
{% if type in ['text/plain'] %}
#}

{{ '{% highlight plaintext %}' }}
{{ output.data['text/plain'] | strip_ansi}}
{{ '{% endhighlight %}' }}

{# Later renable this
{% else %}
<div class="jupyter-other-output">
{{ output.data[type] }}
</div>
{% endif %}
{% endfor %}
#}
</div>
{% endblock execute_result %}



