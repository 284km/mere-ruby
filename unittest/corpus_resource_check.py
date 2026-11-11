#!/usr/bin/env python3
"""Run the complete corpus with both hash modes under original resource bounds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
sys.dont_write_bytecode = True
from ci import supervise

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
p.add_argument('--ruby', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
files = sorted((ROOT / 'corpus').glob('*.rb'))
assert files
before = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
log = a.output / 'corpus.out'
environment = dict(os.environ, MR_BIN=str(a.binary.resolve()), REF_RUBY_BIN=a.ruby)
os.chdir(ROOT)
result = supervise(['sh', str(ROOT / 'run_corpus.sh'), '--both'], environment, log, 2097152, 900)
result.update(binary_sha256=hashlib.sha256(a.binary.read_bytes()).hexdigest(),
              bounds={'wall_seconds': 900, 'rss_family_kb': 2097152}, files=before)
(a.output / 'results.json').write_text(json.dumps(result, indent=2) + '\n')
assert before == {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
assert result['exit'] == 0 and result['limit'] is None, (result, log.read_text()[-2000:])
summary = re.findall(r'(\d+)/(\d+) corpus programs match ruby, with the hash index ON and OFF', log.read_text())
assert summary == [(str(len(files)), str(len(files)))], summary
print(log.read_text()[-1000:], flush=True)
