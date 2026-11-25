require 'tmpdir'
require 'rbconfig'

# A trail backslash belongs to its character in every literal scanner.
# Run the encoded source both as the main script and through require (Prism
# reads the required file under the VM).
source = <<~'RUBY'
  p ["表", "表示", '表', "表u1234", "表#{1}"].map(&:bytes)
  p [%q[表], %Q[表], %q[ソ], %Q[能], "十"].map(&:bytes)
  p %w[表 a ソ 能 十].map(&:bytes)
  p %W[表 a 表#{1}].map(&:bytes)
  p %i[表 a].map { |s| s.to_s.bytes }
  p %I[表 a 表#{1}].map { |s| s.to_s.bytes }
  p [:"表", :'表', :表].map { |s| s.to_s.bytes }
  p [/表/, /表users/, /表cA/, %r[表], /表#{1}/].map { |r| r.source.bytes }
  a = <<TEXT
  表
  ソ"能
  TEXT
  b = <<'TEXT'
  表
  TEXT
  p [a.bytes, b.bytes]
RUBY
Dir.mktmpdir('corpus-987-') do |dir|
  %w[cp932 Shift_JIS].each_with_index do |encoding, index|
    path = File.join(dir, "source_#{index}.rb")
    File.binwrite(path, ("# coding: #{encoding}\n" + source).encode(encoding))
    IO.popen([RbConfig.ruby, path]) { |io| print io.read }
    raise 'main script failed' unless $?.success?
    require path
  end
end

# Review controls: classes and a backslash before an entire encoded character.
review_source = <<~'RUBY'
  p [/[CHAR]/ =~ "CHAR", /[aCHAR]+/ =~ "bCHAR", /[CHAR-CHAR]/ =~ "CHAR"]
  p Regexp.new("[CHAR]") =~ "aCHAR"
  p "aCHARb".scan(/[CHAR]/).size
  p ["\CHAR", "a\CHARb", :"\CHAR".to_s, /\CHAR/.source, %r[\CHAR].source].map(&:bytes)
  p %w[\CHAR x].map(&:bytes)
  p %W[\CHAR x].map(&:bytes)
  p "#{"\CHAR"}".bytes
  p "#{/\CHAR/.source}".bytes
  p "#{%Q[\CHAR]}".bytes
  x = <<TEXT
  \CHAR
  TEXT
  p x.bytes
RUBY
Dir.mktmpdir('corpus-991-review-') do |dir|
  [['Windows-31J', '表'], ['Big5', '許'], ['GBK', '乗']].each_with_index do |(encoding, char), index|
    path = File.join(dir, "class_#{index}.rb")
    source = ("# coding: #{encoding}\n" + review_source.gsub('CHAR', char)).encode(encoding)
    File.binwrite(path, source)
    IO.popen([RbConfig.ruby, path]) { |io| print io.read }
    raise 'main class/escape failed' unless $?.success?
    require path
    eval(source, binding, path)
    Object.new.instance_eval(source, path)
  end
end
