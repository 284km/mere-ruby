"""Keep original iclass failures authoritative in a fixed compiler replay."""
from cache_compiler_compare import method_side_passed

SOURCE = 'c22ad34649707cbcf58105d60401c6417cece828'
RUBY = '3e93b23afcec3433f6aecc34b5d832799d754238'
TEST_SHA = '6b9b0fe714d15e2d08ac9ac6954b5f429754b2507eec2960b9544bc54eb8cdbc'
INPUT_SHA = '79298f273c647ae9dea709fb32021af830f484101218bf74b87069d49af88d8a'
PROGRAM_SHA = '9bb9dd80ebc082cdb1c356e415f688598228cf8e075ddfb4ae509f5581ca38a3'
COMPILERS = dict(before='43f2994b7d2bc664e47afa1c9555f2dcf26214f2',
                 repair='408b03d9cfc9f56331490a8912f3ea1254d488dd')
ORDER = ['reference', 'before', 'repair', 'repair', 'before']
BOUNDS = dict(wall_seconds=600, rss_kb=2097152, child_seconds=10)
CASE = 'TestModule#test_iclass_memory_leak'


def method_complete(pair):
    result = pair.get('result', {})
    sides = result.get('sides', {})
    if (pair.get('program_sha256') != PROGRAM_SHA
            or type(pair.get('driver_exit')) is not int
            or result.get('bounds') != dict(wall_seconds=600, rss_kb=2097152, post_gc_growth=2.0)
            or set(sides) != {'mere', 'reference'}):
        return False
    for side in sides.values():
        samples = side.get('samples_kb', [])
        if ([r[0] for r in samples] != list(range(21))
                or any(type(r[0]) is not int or type(r[1]) is not int or r[1] <= 0 for r in samples)
                or type(side.get('healthy')) is not bool
                or type(side.get('execution', {}).get('exit')) is not int
                or 'limit' not in side['execution']):
            return False
        if max(r[1] for r in samples[1:]) / samples[0][1] != side.get('post_gc_peak_to_initial'):
            return False
    return True


def assess(record):
    selected = record.get('selected', [])
    complete = (record.get('source_ref') == SOURCE and record.get('compiler_refs') == COMPILERS
        and record.get('ruby_ref') == RUBY and record.get('test_sha256') == TEST_SHA
        and record.get('map_slots_only') is True and record.get('clear_sites') == 32
        and record.get('delete_sites') == 32 and record.get('bounds') == BOUNDS
        and record.get('order') == ORDER and [r['label'] for r in selected] == ORDER)
    candidate_ok, reference_ok = complete, complete
    for run in selected:
        parsed, execution, usage = run['parsed'], run['execution'], run.get('usage')
        complete &= (run.get('canonical_input_sha256') == INPUT_SHA and run.get('canonical_nonce_count') == 2
            and parsed['state'] == 'COMPLETE' and not parsed['issues'] and set(parsed['cases']) == {CASE}
            and parsed['discovered'] == 1 and parsed['summary'] is not None
            and parsed['summary']['tests'] == 1 and usage is not None
            and usage['exit'] == execution['exit']
            and usage['wait4_user_seconds'] >= 0 and usage['wait4_system_seconds'] >= 0)
        passed = (execution['exit'] == 0 and execution['limit'] is None
            and parsed['cases'] == {CASE: '.'}
            and parsed['summary'] == dict(tests=1, assertions=3, failures=0, errors=0, skips=0))
        if run['label'] == 'repair':
            candidate_ok &= passed
        elif run['label'] == 'reference':
            reference_ok &= passed
    module, lost = record.get('module', {}), []
    module_ok = set(module) == {'reference', 'before', 'repair'}
    if module_ok:
        reference, before, repair = [module[k]['parsed'] for k in ['reference', 'before', 'repair']]
        complete &= all(p['state'] == 'COMPLETE' and not p['issues'] and p['discovered'] == 195
                        and p['summary'] is not None and p['summary']['tests'] == 195 for p in [reference, before, repair])
        complete &= set(reference['cases']) == set(before['cases']) == set(repair['cases'])
        lost = sorted(n for n, state in before['cases'].items() if state == '.' and repair['cases'].get(n) != '.')
        for label in ['reference', 'repair']:
            value = module[label]
            module_ok &= (value['execution']['exit'] == 0 and value['execution']['limit'] is None
                and value['parsed']['summary'] == dict(tests=195, assertions=1240, failures=0, errors=0, skips=0))
        module_ok &= reference['cases'] == repair['cases'] and not lost
    method = record.get('method', {})
    methods_complete = (set(method) == {'before', 'repair'}
        and all(method_complete(pair) for pair in method.values()))
    complete &= methods_complete
    method_ok = False
    if methods_complete:
        reference_ok &= all(method_side_passed(pair['result']['sides']['reference']) for pair in method.values())
        repair = method['repair']
        method_ok = (repair['driver_exit'] == 0
            and all(method_side_passed(v) for v in repair['result']['sides'].values()))
    return dict(complete=bool(complete), candidate_selected_passed=bool(candidate_ok and complete),
        reference_passed=bool(reference_ok and complete), candidate_module_passed=bool(module_ok and complete),
        candidate_method_passed=bool(method_ok), lost_passing_cases=lost,
        passed=bool(complete and candidate_ok and reference_ok and module_ok and method_ok))
