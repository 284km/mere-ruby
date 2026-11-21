"""Extend only the separate native observer; do not change ordinary emitted C."""
from pathlib import Path
import re


def extend(source, observer):
    names = re.findall(r'^static mere_map_\w+\* mu_(\w+);$', source, re.M)
    existing = set(re.findall(r'GEM_RSS_MAP\((\w+)\);', observer))
    if not existing <= set(names) or len(names) != len(set(names)):
        raise ValueError('changed locked native map declarations')
    # Shared default storage is already reported once. Extra independent
    # maps below 64 KiB are omitted from this diagnostic printout only.
    extra = ''.join(
        '    if (mu_' + name + ' && mu_' + name + '->region != &__lang_default_region'
        ' && gem_rss_capacity(mu_' + name + '->region) >= 65536) GEM_RSS_MAP(' + name + ');\n'
        for name in names if name not in existing)
    if observer.count('#undef GEM_RSS_MAP') != 1:
        raise ValueError('changed native map observation boundary')
    observer = observer.replace('#undef GEM_RSS_MAP', extra + '#undef GEM_RSS_MAP')
    needle = 'unsigned index = sample++;'
    if observer.count(needle) != 1:
        raise ValueError('changed native sample boundary')
    observer = observer.replace(needle, needle + '\n    gem_heap_snapshot(index);')
    return (Path(__file__).with_suffix('.c').read_text() + observer)
