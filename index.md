
<style>
.site-footer { display: none; }
.site-footer-owner { display: none; }
.site-footer-credits { display: none; }
</style>


# New Posts 

<ul>
  {% for post in site.posts %}
    {% unless post.draft %}
      <li>
        <a href="{{ post.url }}">{{ post.title }}</a>
      </li>
    {% endunless %}
  {% endfor %}
</ul>

<br/>
{% include nav.html %}

