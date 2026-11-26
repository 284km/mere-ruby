require 'tmpdir'
require 'fileutils'

previous = %w[TMPDIR TMP TEMP].to_h { |name| [name, ENV[name]] }
Dir.mktmpdir('mere-process-scratch-') do |parent|
  valid = File.join(parent, 'valid')
  Dir.mkdir(valid)
  file = File.join(parent, 'file')
  File.write(file, 'not a directory')
  ENV['TMP'] = nil
  ENV['TEMP'] = nil
  [[:valid, valid], [:missing, File.join(parent, 'missing')],
   [:file, file], [:empty, ''], [:unset, nil]].each do |label, value|
    ENV['TMPDIR'] = value
    output = Thread.new { `printf child-ok` }.value
    pid = Process.spawn('sh', '-c', 'exit 7')
    _, status = Process.wait2(pid)
    p [label, output, status.exitstatus]
  end
ensure
  previous.each { |name, value| ENV[name] = value }
end
