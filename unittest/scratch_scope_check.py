#!/usr/bin/env python3
"""Temporary expression scopes must return to the frame pool as a loop grows."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
binary = os.environ.get('MR_BIN', str(ROOT / 'mere-ruby'))
for indexing in ('1', '0'):
    news = []
    for count in (100, 10000):
        env = dict(os.environ, MERE_RUBY_STORE_STATS='1')
        if indexing == '0':
            env['MERE_RUBY_NO_HASH_INDEX'] = '1'
        else:
            env.pop('MERE_RUBY_NO_HASH_INDEX', None)
        result = subprocess.run([binary, str(ROOT / 'bench/scratch_scopes.rb'), str(count)],
                                env=env, capture_output=True, text=True, timeout=60, check=True)
        assert result.stdout == 'scratch scopes: values, captures and exceptions preserved\n', result.stdout
        match = re.search(r'^pool_news\t(\d+)$', result.stderr, re.M)
        assert match, result.stderr
        news.append(int(match[1]))
    # This measures allocation counts, not a platform-dependent RSS threshold.
    assert news[1] <= news[0] + 32, (indexing, news)
    print(f'hash indexing {indexing}: fresh frames at 100/10000 iterations = {news}')
