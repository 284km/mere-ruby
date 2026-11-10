#!/usr/bin/env python3
"""Measure the same installed gems with pinned reference, bundled and external stdlib."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'unittest'))
from ci import supervise

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=str(ROOT/'mere-ruby'))
    parser.add_argument('--reference',required=True)
    parser.add_argument('--gem-home',required=True,type=Path)
    parser.add_argument('--rubygems',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    assert (args.gem_home/'specifications').is_dir()
    assert (args.rubygems/'lib/rubygems.rb').is_file()
    version=subprocess.check_output([args.reference,'-e','print RUBY_VERSION'],text=True)
    assert version=='4.0.9',version
    stdlib=subprocess.check_output([args.reference,'-rrbconfig','-rrubygems','-e',
        'print ([RbConfig::CONFIG["rubylibdir"]]+Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":")'],text=True)
    gems=[s.strip() for s in (ROOT/'gemtest/gems.txt').read_text().splitlines() if s.strip() and not s.startswith('#')]
    specs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((args.gem_home/'specifications').glob('*.gemspec'))}
    rows=[]
    for gem in gems:
        row={'gem':gem}
        for mode in ('reference','bundled','external'):
            env=dict(os.environ,GEM_HOME=str(args.gem_home.resolve()),GEM_PATH=str(args.gem_home.resolve()),
                     RUBYGEMS_LIB=str((args.rubygems/'lib').resolve()),MERE_RUBY_NO_GEMS='1')
            env.pop('RUBYLIB',None)
            env.pop('RUBYOPT',None)
            command=[args.reference,'--disable-gems'] if mode=='reference' else [args.binary]
            if mode=='external':command+=['-I',stdlib]
            command += [str(ROOT/'gemtest/load_one.rb'),gem]
            log=args.output/(gem+'.'+mode+'.log')
            result=supervise(command,env,log,2097152,120)
            lines=log.read_text(errors='replace').splitlines()
            report=next((s for s in lines if s.startswith(('OK   ','FAIL '))),None)
            result['loaded']=result['exit']==0 and result['limit'] is None and report==('OK   '+gem)
            result['report']=report or '\n'.join(lines[-3:])
            row[mode]=result
        row['classification']='reference-unavailable' if not row['reference']['loaded'] else 'eligible'
        rows.append(row)
        print(gem,*(mode+':'+('OK' if row[mode]['loaded'] else 'FAIL') for mode in ('reference','bundled','external')),flush=True)
        (args.output/'results.json').write_text(json.dumps({'reference_version':version,'gemspec_sha256':specs,'rows':rows},indent=2)+'\n')
    eligible=[r for r in rows if r['classification']=='eligible']
    summary={'date':'2026-11-10','reference_version':version,'listed':len(rows),'reference_loads':len(eligible),
             'reference_unavailable':len(rows)-len(eligible),
             'bundled_loads':sum(r['bundled']['loaded'] for r in eligible),
             'external_loads':sum(r['external']['loaded'] for r in eligible)}
    (args.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary),flush=True)

if __name__=='__main__':main()
