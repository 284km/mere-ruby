require 'nkf'
$nkf_log = []
class NkfCoercion
  def initialize(value, label)
    @value, @label = value, label
  end
  def to_str
    $nkf_log << @label
    @value
  end
end
def nkf_error
  yield
rescue => error
  p [error.class, error.message]
end
nkf_error { NKF.nkf }
nkf_error { NKF.nkf('-w') }
nkf_error { NKF.nkf('-w', '', '') }
nkf_error { NKF.guess }
nkf_error { NKF.guess('', '') }
[nil, false, 1, [], Object.new].each do |bad|
  nkf_error { NKF.nkf(bad, '') }
  nkf_error { NKF.nkf('-w', bad) }
  nkf_error { NKF.guess(bad) }
end
nkf_error { NKF.nkf(NkfCoercion.new(nil, :bad_option), NkfCoercion.new('', :unused)) }
nkf_error { NKF.nkf(NkfCoercion.new("-w\0-s", :nul_option), NkfCoercion.new('', :unused)) }
nkf_error { NKF.nkf(NkfCoercion.new('', :empty_option), NkfCoercion.new('', :unused)) }
nkf_error { NKF.nkf('-w', NkfCoercion.new(12, :bad_source)) }
p $nkf_log
p NKF.nkf(NkfCoercion.new('-w', :option), NkfCoercion.new('あ', :source))
p $nkf_log
class NkfNestedOption
  def to_str
    NKF.nkf('-w', 'inner')
    ''
  end
end
class NkfNestedSource
  def to_str
    NKF.nkf('-s', 'inner')
    'あ'
  end
end
p NKF.nkf(NkfNestedOption.new, 'あ')
result = NKF.nkf('-w', NkfNestedSource.new)
p [result.bytes, result.encoding.name]
p NKF.guess(NkfNestedSource.new).name
p NKF.nkf('-w', "a\0b").bytes
p NKF.nkf('-w ' + 'x' * 256, 'あ')
p NKF.nkf('-w', 'あ')
