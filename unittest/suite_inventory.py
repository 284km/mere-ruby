#!/usr/bin/env python3
"""Inventory upstream suite inputs separately from measured test outcomes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def inventory(source):
    source = source.resolve()
    ruby_ref = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    unit = subprocess.check_output(['sh', str(Path(__file__).with_name('list.sh')), str(source), '--all'], text=True).splitlines()
    inputs = {'test': ['test/' + name for name in unit]}
    inputs['bootstraptest'] = sorted(str(p.relative_to(source)) for p in (source / 'bootstraptest').glob('test_*.rb'))
    inputs['basictest'] = ['basictest/test.rb']
    inputs['tool/test'] = sorted(str(p.relative_to(source)) for p in (source / 'tool/test').rglob('*.rb') if p.name.startswith('test_') or p.name.endswith('_test.rb'))
    for name in ('ruby', 'bundler', 'syntax_suggest', 'mspec'):
        directory = 'spec/' + name
        inputs[directory] = sorted(str(p.relative_to(source)) for p in (source / directory).rglob('*_spec.rb'))
    inputs['spec-root'] = sorted(str(p.relative_to(source)) for p in (source / 'spec').glob('*_spec.rb'))
    inputs['knownbugs'] = ['KNOWNBUGS.rb'] if (source / 'KNOWNBUGS.rb').exists() else []
    runners = {'test': 'test/runner.rb', 'bootstraptest': 'bootstraptest/runner.rb',
               'basictest': 'basictest/runner.rb', 'tool/test': 'tool/test/runner.rb',
               'spec/ruby': 'spec/mspec/bin/mspec', 'spec/bundler': 'spec/bin/rspec',
               'spec/syntax_suggest': 'common.mk:test-syntax-suggest',
               'spec/mspec': 'spec/mspec: ruby -S bundle exec rspec (see README.md and Gemfile)',
               'spec-root': 'common.mk:bundled_gems_spec-run', 'knownbugs': 'bootstraptest/runner.rb'}
    measured = {'test': 'unittest-report', 'bootstraptest': 'bootstrap-report'}
    suites = []
    for name, paths in inputs.items():
        if len(paths) != len(set(paths)):
            raise ValueError('duplicate suite input: ' + name)
        records = []
        for path in paths:
            records.append(dict(path=path, sha256=hashlib.sha256((source / path).read_bytes()).hexdigest()))
        suites.append(dict(suite=name, runner=runners[name], candidate_files=len(records), files=records,
                           report_artifact=measured.get(name),
                           execution='separate CI artifact; inventory is not an execution result' if name in measured else 'measurement pending'))
    unit_paths = set(inputs['test'])
    helpers = [dict(path=str(p.relative_to(source)), sha256=hashlib.sha256(p.read_bytes()).hexdigest(),
                    role='needs helper/fixture/runner/test-body audit')
               for p in sorted((source / 'test').rglob('*.rb')) if str(p.relative_to(source)) not in unit_paths]
    common = (source / 'common.mk').read_text()
    targets = sorted(set(re.findall(r'^(?:yes-|no-)?((?:test[-\w]*|btest[-\w]*|check|exam))\s*:', common, re.MULTILINE)))
    bundled = source / 'gems/bundled_gems'
    return dict(schema=1, ruby_ref=ruby_ref, scope='static suite inputs, not the number of executed test cases', suites=suites,
                test_non_candidates=helpers, make_targets=targets,
                bundled_gems=dict(manifest='gems/bundled_gems', sha256=hashlib.sha256(bundled.read_bytes()).hexdigest(),
                                  execution='per-gem repository revisions, dependency setup and measurements pending') if bundled.exists() else None)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ruby-src', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inventory(args.ruby_src)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(ruby_ref=result['ruby_ref'], suites={s['suite']: s['candidate_files'] for s in result['suites']},
                          test_non_candidates=len(result['test_non_candidates']))))
