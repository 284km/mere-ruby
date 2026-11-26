require 'tmpdir'
Dir.mktmpdir('file-flush-1115-') do |dir|
  path = File.join(dir, 'data')
  File.open(path, 'w+') do |file|
    file.write('abcdefghij')
    file.flush
    file.seek(3)
    file.write('XY')
    file.flush
    p [file.pos, File.binread(path)]
    file.seek(15)
    file.write('Z')
    file.flush
    p [file.pos, File.binread(path).bytes]
    file.truncate(2)
    file.write('Q')
    file.flush
    p [file.pos, File.binread(path).bytes]
  end

  File.binwrite(path, 'abcdefghij')
  File.open(path, 'r+') do |first|
    File.open(path, 'r+') do |second|
      first.seek(1)
      first.write('12')
      second.seek(7)
      second.write('89')
      first.flush
      second.flush
      p File.binread(path)
      first.seek(4)
      first.write('W')
      # Bytes changed outside the buffered object survive its later flush.
      File.binwrite(path, 'external-data')
      first.flush
      p File.binread(path)
      first.seek(2)
      first.write('XX')
      p [first.pos, first.read(5), File.binread(path)]
      first.sync = true
      first.seek(0)
      first.write('S')
      p File.binread(path)
    end
  end

  File.open(path, 'w') do |file|
    file.sync = true
    file.write('first')
    File.binwrite(path, 'outside-longer')
    file.write('LAST')
    p File.binread(path)
  end
end
