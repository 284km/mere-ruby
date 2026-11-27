# frozen_string_literal: true
require 'json'

module CorpusStderr
  class Normalizer
    def initialize(roots, binary_names: [])
      @roots = roots.reject { |path, _| path.nil? || path.empty? }
                    .sort_by { |path, _| -path.bytesize }
                    .map { |path, label| [path.b, label.b] }
      @binary_names = binary_names.map { |name| Regexp.escape(name.b) }
    end

    def call(bytes)
      text = bytes.b
      @roots.each { |path, label| text = text.gsub(path, label) }
      @binary_names.each { |name| text = text.gsub(/^#{name}(?=:)/n, '<ruby>') }
      text.gsub(/(#<[^>\n]*?):0x[0-9a-fA-F]+(?=[\s>])/n, '\\1:0x<address>')
    end
  end

  module_function

  def warnings(text)
    text.b.lines("\n").select { |line| /(?:^|:\s*)warning:/n.match?(line) }.join.b
  end

  def printable(bytes)
    text = bytes.dup.force_encoding(Encoding::UTF_8)
    return text if text.valid_encoding?
    bytes.b.lines("\n").map do |line|
      utf8 = line.dup.force_encoding(Encoding::UTF_8)
      utf8.valid_encoding? ? utf8 : line.dump + "\n"
    end.join
  end

  def configured_dirs(binary)
    program = '["rubylibdir", "rubyarchdir"].each { |key| value=RbConfig::CONFIG[key]; puts "#{key}=#{value}" if value }'
    output = IO.popen([{'RUBYOPT' => nil, 'RUBYLIB' => nil}, binary,
                       '--disable=gems', '-rrbconfig', '-e', program], &:read)
    raise "cannot read interpreter directories: #{File.basename(binary)}" unless $?.success?
    output.lines.to_h { |line| line.chomp.split('=', 2) }
  end

  def process_normalizer(reference, candidate, repo:, temporary:)
    roots = {File.expand_path(reference) => '<ruby>', File.expand_path(candidate) => '<ruby>',
             File.expand_path(repo) => '<repo>', File.expand_path(temporary) => '<corpus-tmp>'}
    [reference, candidate].each do |binary|
      configured_dirs(binary).each do |key, value|
        roots[value] = key == 'rubyarchdir' ? '<archlib>' : '<stdlib>' unless value.empty?
      end
    end
    roots[ENV['HOME']] = '<HOME>' if ENV['HOME'] && !ENV['HOME'].empty?
    Normalizer.new(roots, binary_names: [File.basename(reference), File.basename(candidate), 'ruby', 'mere-ruby'].uniq)
  end

  # Each row names the reference stderr and BOTH actual execution files.
  # A missing requested execution is an error, never a skipped comparison.
  def compare(rows, mode:, normalizer:)
    raise ArgumentError, 'stderr mode must be warnings or all' unless %w[warnings all].include?(mode)
    raise ArgumentError, 'no corpus stderr records' if rows.empty?
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    results = []
    rows.each do |program, reference, on, off|
      expected = normalizer.call(File.binread(reference))
      [['on', on], ['off', off]].each do |index, path|
        next if index == 'off' && path == '-'
        raise ArgumentError, "missing stderr execution for #{program}" if path.nil? || path.empty?
        actual = normalizer.call(File.binread(path))
        expected_warnings, actual_warnings = warnings(expected), warnings(actual)
        full_match, warning_match = expected == actual, expected_warnings == actual_warnings
        match = mode == 'all' ? full_match : warning_match
        row = {program: program, hash_index: index, stderr_match: full_match,
               warnings_match: warning_match, selected_match: match}
        unless full_match
          row[:reference_stderr] = printable(expected)
          row[:candidate_stderr] = printable(actual)
        end
        unless match
          row[:reference_selected] = printable(mode == 'all' ? expected : expected_warnings)
          row[:candidate_selected] = printable(mode == 'all' ? actual : actual_warnings)
        end
        results << row
      end
    end
    count = ->(key) { results.reject { |row| row[key] }.map { |row| row[:program] }.uniq.length }
    {mode: mode, programs: rows.length, comparisons: results.length,
     stderr_programs_differ: count.call(:stderr_match), warning_programs_differ: count.call(:warnings_match),
     selected_programs_differ: count.call(:selected_match),
     comparison_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
     results: results}
  end

  def main(arguments)
    mode, manifest, reference, candidate, repo, temporary, report = arguments
    raise ArgumentError, 'usage: MODE MANIFEST REFERENCE CANDIDATE REPO TEMP [REPORT]' unless temporary
    rows = File.readlines(manifest, chomp: true).map { |line| line.split("\t", -1) }
    raise ArgumentError, 'invalid stderr manifest row' unless rows.all? { |row| row.length == 4 }
    normalizer = process_normalizer(reference, candidate, repo: repo, temporary: temporary)
    result = compare(rows, mode: mode, normalizer: normalizer)
    result[:engine] = ENV['MERE_RUBY_VM'] == '1' ? 'vm' : 'evaluator'
    File.write(report, JSON.pretty_generate(result) + "\n") if report && !report.empty?
    result[:results].reject { |row| row[:selected_match] }.each do |row|
      puts "FAIL stderr (#{mode}, hash index #{row[:hash_index]}) #{row[:program]}"
      puts '--- ruby'
      print row[:reference_selected].lines.map { |line| '- ' + line }.join
      puts '+++ mere-ruby'
      print row[:candidate_selected].lines.map { |line| '+ ' + line }.join
    end
    puts "stderr #{mode}: #{result[:programs]} programs / #{result[:comparisons]} executions, " \
         "#{result[:warning_programs_differ]} warning differences, #{result[:stderr_programs_differ]} full-stderr differences"
    result[:selected_programs_differ].zero? ? 0 : 1
  rescue ArgumentError, Errno::ENOENT => error
    warn "corpus stderr check: #{error.message}"
    2
  end
end

exit CorpusStderr.main(ARGV) if $PROGRAM_NAME == __FILE__
