---
layout: default
---
<div>
    <section>
    Note that up until 2022, I was publishing under the pen-name Lyndon White.
    </section>

    <section id="publications">
        <ul>
        {% for pub in site.data.publications %}
        <li>{{pub.year}}: {{pub.title}}, {{pub.author}}. {{pub.venue}} 
	    {% if pub.award %} <em> {{pub.award}} </em> {% endif %}
            <span>
                [
                {% if pub.key %}
                    <a href="{{site.url}}/publications/{{pub.key}}.pdf">pdf</a>,
                    <a href="{{site.url}}/publications/{{pub.key}}.bib">bib</a>,
                {% endif %}
                {% if pub.link %}
                    <a href="{{pub.link}}">link</a>,
                {% endif %}
                {% if pub.supl %}
                    <a href="{{site.url}}/{{pub.supl}}">site</a>,
                {% endif %}
                ]
             </span>
        
        {% endfor %}
        </ul>
    </section>
</div>
