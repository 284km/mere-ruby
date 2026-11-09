require 'tmpdir'

Dir.mktmpdir('mere-device-flush-') do |dir|
  link = File.join(dir, 'sink')
  File.symlink(File::NULL, link)
  [File::NULL, link].each do |path|
    File.open(path, 'w') do |f|
      100.times do
        raise 'write count' unless f.write("x" * 100 + "\n") == 101
        raise 'flush receiver' unless f.flush.equal?(f)
      end
      GC.start
      raise 'device EOF' unless File.read(path) == ''
    end
  end

  path = File.join(dir, 'regular')
  File.open(path, 'w+') do |f|
    f.write('abcdef')
    f.flush
    f.seek(2)
    f.write('XY')
    f.flush
    raise 'overwrite' unless File.read(path) == 'abXYef'
    f.seek(8)
    f.write('!')
    f.flush
    raise 'sparse write' unless File.binread(path) == "abXYef\0\0!"
  end
  File.open(path, 'a') { |f| f.write('?'); f.flush }
  raise 'append' unless File.binread(path) == "abXYef\0\0!?"
end

f = File.open(File::NULL, 'w')
f.write('buffered')
IO.for_fd(f.fileno).close
2.times do
  begin
    f.flush
    raise 'closed descriptor accepted'
  rescue Errno::EBADF
  end
end
begin
  f.close
rescue Errno::EBADF
end

raise 'close must finish after EBADF' unless f.closed?
raise 'repeated close' unless f.close.nil?

if File.exist?('/dev/full')
  f = File.open('/dev/full', 'w')
  f.write('buffered')
  begin
    f.flush
    raise 'full device accepted'
  rescue Errno::ENOSPC
  ensure
    begin
      f.close
    rescue Errno::ENOSPC
    end
    raise 'close must finish after ENOSPC' unless f.closed?
    raise 'repeated close after ENOSPC' unless f.close.nil?
  end
end
puts 'device flush, error propagation and regular-file positions preserved'
