#!/usr/bin/env python3
"""Bound scheduler regressions so broken handoffs cannot stall the corpus job."""
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BASE = '''Warning[:experimental] = false
class SchedulerProbe
  def block(*) = nil
  def unblock(*) = nil
  def io_wait(*) = nil
  def kernel_sleep(*) = nil
  def fiber_interrupt(*) = nil
  def scheduler_close
    p [:closed, Fiber.scheduler.equal?(self)]
    GC.start
  end
end
'''
CASES = {
    'worker value survives close GC': BASE + '''
t = Thread.new do
  Fiber.set_scheduler(SchedulerProbe.new)
  ['retained'.dup, {key: ['nested'.dup]}]
end
p t.value
''',
    'main exit order': BASE + '''
Fiber.set_scheduler(SchedulerProbe.new)
at_exit { p [:at_exit, Fiber.scheduler.nil?] }
''',
    'worker failure': BASE + '''
t = Thread.new do
  Thread.current.report_on_exception = false
  Fiber.set_scheduler(SchedulerProbe.new)
  raise 'body failed'
end
begin; t.value; rescue => e; p e.message; end
''',
    'close failure overrides worker failure': BASE + '''
class SchedulerProbe
  def scheduler_close = raise('close failed')
end
t = Thread.new do
  Thread.current.report_on_exception = false
  Fiber.set_scheduler(SchedulerProbe.new)
  raise 'body failed'
end
begin; t.value; rescue => e; p e.message; end
''',
    'legacy close': BASE + '''
class SchedulerProbe
  undef scheduler_close
  def close = p(:legacy)
end
Fiber.set_scheduler(SchedulerProbe.new)
Fiber.set_scheduler(nil)
''',
    'main close failure status': BASE + '''
class SchedulerProbe
  def scheduler_close = raise('close failed')
end
Fiber.set_scheduler(SchedulerProbe.new)
''',
}


def run(binary, arguments, env):
    result = subprocess.run([binary, *arguments], env=env, capture_output=True,
                            text=True, timeout=15)
    return result.returncode, result.stdout


def main():
    reference = shutil.which(os.environ.get('REF_RUBY_BIN', 'ruby'))
    assert reference, 'reference Ruby was not found'
    candidate = str(ROOT / 'mere-ruby')
    cases = {'scheduler corpus': [str(ROOT / 'corpus/497_fiber_scheduler_io.rb')]}
    cases.update({name: ['-e', source] for name, source in CASES.items()})
    for name, arguments in cases.items():
        expected = run(reference, arguments, os.environ.copy())
        assert expected[0] == (1 if name == 'main close failure status' else 0), name
        for mode in ('on', 'off'):
            env = os.environ.copy()
            env.pop('MERE_RUBY_NO_HASH_INDEX', None)
            if mode == 'off':
                env['MERE_RUBY_NO_HASH_INDEX'] = '1'
            actual = run(candidate, arguments, env)
            assert actual == expected, (name, mode, expected, actual)
        print(f'{name}: matches reference in both hash-index modes', flush=True)


if __name__ == '__main__':
    main()
