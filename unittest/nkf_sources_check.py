#!/usr/bin/env python3
"""Check pinned NKF licenses, source hashes, ordered patches and generated Kconv."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'vendor/nkf'
manifest = json.loads((VENDOR / 'UPSTREAM.json').read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
assert manifest['commit'] == '65506fecfd6bec82552746473bb91899d861a849'
for name, expected in manifest['unmodified_vendor_files'].items():
    assert digest(VENDOR / name) == expected, name
for name, record in manifest['locally_patched_files'].items():
    assert digest(VENDOR / name) == record['local_sha256'], name
    patches = [VENDOR / row['path'] for row in record['patches']]
    for path, row in zip(patches, record['patches']):
        assert digest(path) == row['sha256'], row['path']
    with tempfile.TemporaryDirectory(prefix='nkf-source-check-') as tmp:
        tree = Path(tmp)
        (tree / 'nkf-utf8').mkdir()
        target = tree / name
        shutil.copyfile(VENDOR / name, target)
        for path in reversed(patches):
            subprocess.run(['patch', '--batch', '-R', '-p1', '-i', str(path)], cwd=tree,
                           check=True, capture_output=True)
        assert digest(target) == record['upstream_sha256'], 'patch chain does not recover pinned source'
        for path in patches:
            subprocess.run(['patch', '--batch', '-p1', '-i', str(path)], cwd=tree,
                           check=True, capture_output=True)
        assert target.read_bytes() == (VENDOR / name).read_bytes()
generated = subprocess.check_output(['ruby', ROOT / 'tools/gen_nkf_lib.rb'])
assert generated == (ROOT / 'm_nkf_lib.mere').read_bytes(), 'regenerate m_nkf_lib.mere'
print('NKF pinned sources, original licenses, ordered local patches and generated Kconv passed')
