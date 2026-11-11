p defined?(NKF)
p require('nkf')
p [require('nkf'), require('nkf.rb'), require('nkf.so')]
p NKF.constants(false).sort
p [NKF::AUTO, NKF::NOCONV, NKF::UNKNOWN]
p [NKF::BINARY.equal?(Encoding::BINARY), NKF::ASCII.equal?(Encoding::US_ASCII),
   NKF::JIS.equal?(Encoding::ISO_2022_JP), NKF::EUC.equal?(Encoding::EUC_JP),
   NKF::SJIS.equal?(Encoding::Shift_JIS), NKF::UTF8.equal?(Encoding::UTF_8),
   NKF::UTF16.equal?(Encoding::UTF_16BE), NKF::UTF32.equal?(Encoding::UTF_32BE)]
p [NKF::VERSION, NKF::NKF_VERSION, NKF::NKF_RELEASE_DATE, NKF::GEM_VERSION].map { |s| [s, s.encoding.name, s.frozen?] }
p NKF.singleton_methods(false).sort
p NKF.private_instance_methods(false).sort
p NKF.public_instance_methods(false).sort
[:nkf, :guess].each do |name|
  method = NKF.method(name)
  p [name, method.arity, method.parameters, method.source_location,
     method.owner.equal?(NKF.singleton_class), NKF.instance_method(name).owner.equal?(NKF)]
end
sample = "あいう漢字ｶﾞ①～😀\r\nEND"
%w[-j -e -s -w -w16L -w32B].each do |option|
  result = NKF.nkf(option, sample)
  p [option, result.bytes, result.encoding.name, NKF.guess(result).name]
end
p NKF.nkf('-w', '=?ISO-2022-JP?B?GyRCJCIbKEI=?=')
p NKF.nkf('-w', '=?UTF-8?Q?=E3=81=82?=')
p NKF.nkf('-w -MQ', 'あ').encoding.name
p NKF.nkf('-w --url-input', '%E3%81%82')
p NKF.nkf('-w --numchar-input', '&#x3042;')
p NKF.nkf('-w -Lu', "a\r\nb\rc\n")
p NKF.nkf('-w --oc=UTF-8-BOM', 'あ').bytes
class NkfInput < String; end
source = NkfInput.new('abc').freeze
result = NKF.nkf('-w', source)
p [result.class, result.frozen?, result.equal?(source), source.bytes, source.frozen?]
p defined?(Kconv)
p require('kconv')
p ['あ'.tosjis.bytes, 'あ'.toeuc.bytes, 'あ'.toutf16.bytes, 'あ'.toutf32.bytes]
%w[UTF-8 EUC-JP].each do |encoding|
  source = "\xc2\xa1".dup.force_encoding(encoding)
  p [source.kconv(encoding).bytes, source.kconv(encoding).encoding.name]
end
