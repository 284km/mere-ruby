"""Verify the immutable package/source lock before and after a load measurement."""
import hashlib
import json
import os
from pathlib import Path
import re


def tree_digest(folder):
    folder=Path(folder)
    assert folder.is_dir(),f'package source missing: {folder.name}'
    entries=[]
    for root,dirs,files in os.walk(folder,followlinks=False):
        base=Path(root)
        entries.extend(base/name for name in files)
        entries.extend(base/name for name in dirs if (base/name).is_symlink())
    digest=hashlib.sha256()
    for file in sorted(entries,key=lambda p:p.relative_to(folder).as_posix()):
        relative=os.fsencode(file.relative_to(folder).as_posix())
        if file.is_symlink():
            digest.update(b'L\0'+relative+b'\0'+os.fsencode(os.readlink(file))+b'\0')
        else:
            digest.update(b'F\0'+relative+b'\0'+hashlib.sha256(file.read_bytes()).hexdigest().encode()+b'\0')
    return digest.hexdigest()


def verify_snapshot(home,lockfile,requested=None):
    home=Path(home)
    lockfile=Path(lockfile)
    raw=lockfile.read_bytes()
    lock=json.loads(raw)
    assert lock['format']==1 and lock['reference_ruby']=='4.0.9','snapshot format/reference drift'
    if requested is not None:assert lock['requested']==requested,'snapshot requested gem list drift'
    expected=set()
    for package in lock['packages']:
        filename=package['file']
        assert re.fullmatch(r'[A-Za-z0-9_.-]+\.gem',filename),'invalid package filename'
        stem=filename[:-4]
        expected.add(stem+'.gemspec')
        assert tree_digest(home/'gems'/stem)==package['source_tree_sha256'],f'package source changed: {filename}'
    actual={p.name for p in (home/'specifications').glob('*.gemspec')}
    assert expected==actual,'snapshot installed gemspec set changed'
    return {'lock_sha256':hashlib.sha256(raw).hexdigest(),'package_count':len(expected),
            'source_unavailable':lock['unavailable'],'native_extension_policy':lock['native_extension_policy']}
