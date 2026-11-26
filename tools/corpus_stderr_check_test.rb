require 'tmpdir'
require_relative 'corpus_stderr_check'
normalizer = CorpusStderr::Normalizer.new({'/ref/root' => '<repo>', '/candidate/root' => '<repo>'})
raise 'known paths differ' unless normalizer.call('/ref/root/a.rb:3: warning: x') == normalizer.call('/candidate/root/a.rb:3: warning: x')
raise 'line numbers hidden' if normalizer.call('/ref/root/a.rb:3: warning: x') == normalizer.call('/candidate/root/a.rb:4: warning: x')
raise 'filenames hidden' if normalizer.call('/ref/root/a.rb:3: warning: x') == normalizer.call('/candidate/root/b.rb:3: warning: x')
raise 'object addresses differ' unless normalizer.call('#<Object:0x123>') == normalizer.call('#<Object:0x456>')
raise 'hex literals hidden' if normalizer.call('0x123') == normalizer.call('0x456')
raise 'invalid byte comparison hidden' if normalizer.call("warning: \xFF\n".b) == normalizer.call("warning: \xFE\n".b)
Dir.mktmpdir do |dir|
  reference, on, off = %w[reference on off].map { |name| File.join(dir, name) }
  warning = "file.rb:3: warning: x\n"
  File.binwrite(reference, warning)
  File.binwrite(on, warning)
  File.binwrite(off, warning * 2)
  rows = [['corpus/warning.rb', reference, on, off]]
  result = CorpusStderr.compare(rows, mode: 'warnings', normalizer: normalizer)
  raise 'second execution ignored' unless result[:comparisons] == 2 && result[:selected_programs_differ] == 1 && result[:results].last[:selected_match] == false
  File.binwrite(off, "file.rb:3: warning: y\n")
  raise 'changed warning ignored' unless CorpusStderr.compare(rows, mode: 'warnings', normalizer: normalizer)[:selected_programs_differ] == 1
  File.binwrite(off, warning + "file.rb:3: uncaught exception (RuntimeError)\n")
  raise 'full stderr ignored' unless CorpusStderr.compare(rows, mode: 'all', normalizer: normalizer)[:selected_programs_differ] == 1
  raise 'warning mode mislabeled' unless CorpusStderr.compare(rows, mode: 'warnings', normalizer: normalizer)[:selected_programs_differ] == 0
  begin
    CorpusStderr.compare([['corpus/warning.rb', reference, on, '']], mode: 'all', normalizer: normalizer)
    raise 'missing execution accepted'
  rescue ArgumentError
  end
end
puts 'stderr comparison controls pass'

command_names = CorpusStderr::Normalizer.new({}, binary_names: ['ruby', 'mere-ruby'])
raise 'interpreter prefixes differ' unless command_names.call("ruby: warning: x\n") == command_names.call("mere-ruby: warning: x\n")
raise 'source filename changed' unless command_names.call("ruby_test.rb:1: warning: x\n") == "ruby_test.rb:1: warning: x\n"
