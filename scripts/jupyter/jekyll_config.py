try:
    from urllib.parse import quote  # Py 3
except ImportError:
    from urllib2 import quote  # Py 2
import os
import sys

c = get_config()
c.NbConvertApp.export_format = 'markdown'
c.Exporter.file_extension = '.md'

def path2url(path):
    return "{{site.url}}/posts_assets/" +  path
c.MarkdownExporter.filters = {'path2url': path2url}
