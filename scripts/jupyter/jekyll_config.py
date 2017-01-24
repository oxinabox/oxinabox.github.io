try:
    from urllib.parse import quote  # Py 3
except ImportError:
    from urllib2 import quote  # Py 2
import os
import sys
import re


c = get_config()
c.NbConvertApp.export_format = 'markdown'
c.Exporter.file_extension = '.md'

def path2url(path):
    return "{{site.url}}/posts_assets/" +  path


def strip_ansi(source):
    # The included strip_ansi is borked, because it doesn't filter strings from
    # nonstrings

    _ANSI_RE = re.compile('\x1b\\[(.*?)([@-~])')
    if type(source)==str:
        return _ANSI_RE.sub('', source)



c.MarkdownExporter.filters = {
    'path2url': path2url,
    'strip_ansi': strip_ansi
}
