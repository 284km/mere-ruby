# Per-flush cost, excluding fixture creation and interpreter startup.
# ruby bench/file_flush.rb <bytes=47185920> <flushes=100> <mode=r+> <--seed=1>
require 'tmpdir'
size = Integer(ARGV.fetch(0, '47185920'))
count = Integer(ARGV.fetch(1, '100'))
mode = ARGV.fetch(2, 'r+')
seed = Integer(ARGV.fetch(3, '--seed=1').delete_prefix('--seed='))
payload = '%020d' % Random.new(seed).rand(1_000_000)
Dir.mktmpdir('flush-cost-') do |dir|
  path = File.join(dir, 'data')
  File.binwrite(path, 'a' * size)
  File.open(path, mode) do |file|
    # A w handle starts empty; populate its file outside its write buffer.
    File.binwrite(path, 'a' * size) if mode.include?('w')
    GC.start
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    count.times do
      file.write(payload)
      file.flush
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    p [mode, size, count, seed, elapsed / count, File.size(path), file.pos]
  end
end
