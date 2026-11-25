require 'tmpdir'
require 'rbconfig'

source = <<~'RUBY'
  中 = 1
  p [中, ?中.bytes, :中.to_s.bytes]
  p ["中".bytes, '中'.bytes, %w[中 a].map(&:bytes)]
RUBY
Dir.mktmpdir('corpus-988-') do |dir|
  %w[Big5 GBK].each_with_index do |encoding, index|
    path = File.join(dir, "source_#{index}.rb")
    File.binwrite(path, ("# coding: #{encoding}\n" + source).encode(encoding))
    IO.popen([RbConfig.ruby, path]) { |io| print io.read }
    raise 'main script failed' unless $?.success?
    require path
  end
end

# Check valid_encoding? as well as the shared width used by Integer#chr.
%w[Big5 CP950 CP951 Big5-HKSCS Big5-UAO GBK CP936].each do |encoding|
  p [encoding, [0x80, 0x8140, 0xa140, 0xa17f, 0xa180, 0xa1a1, 0xfe7e, 0xfeff].map { |n|
    bytes = n < 256 ? [n] : [n >> 8, n & 255]
    s = bytes.pack('C*').force_encoding(encoding)
    chr = begin
      n.chr(encoding).bytes
    rescue RangeError
      :invalid
    end
    [s.valid_encoding?, chr]
  }]
end
