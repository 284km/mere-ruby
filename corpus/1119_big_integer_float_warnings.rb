# Public Integer-to-Float warnings and callback failure ordering.
# Private fdiv, exact comparisons and logarithms do not use rb_big2dbl.
warnings = []
warning_mode = []
Warning.define_singleton_method(:warn) do |message, **options|
  raise "warning refused" if warning_mode[0] == :raise
  warnings << [message.sub(/\A.*?:-?\d+: warning: /, ''), options]
end
class Integer
  alias warning_native_to_f to_f
end
big = 2**5000
cases = {
  to_f: -> { big.to_f },
  saved: -> { big.warning_native_to_f },
  method: -> { big.method(:to_f).call },
  float: -> { Float(big) },
  add: -> { big + 1.0 },
  radd: -> { 1.0 + big },
  sub: -> { big - 1.0 },
  mul: -> { big * 1.0 },
  divide: -> { big / 0.0 },
  rdivide: -> { 1.0 / big },
  fdiv_float: -> { big.fdiv(1.0) },
  fdiv_big: -> { big.fdiv(big) },
  float_fdiv: -> { 1.0.fdiv(big) },
  compare: -> { big <=> 1.0 },
  pow: -> { big ** 1.1 },
  div: -> { big.div(1.0) },
  div_zero: -> { big.div(0.0) },
  mod: -> { big % 1.0 },
  coerce: -> { big.coerce(1.0) },
  pack: -> { [big].pack('d').unpack('d') },
  sprintf: -> { format('%g', big) },
  fixed: -> { format('%f', big) },
  fixed_percent: -> { '%f' % big },
  fixed_precision: -> { format('%10.2f', -big) },
  exponential: -> { format('%e', big) },
  hexadecimal: -> { format('%a', big) },
  rational: -> { Rational(big, big).to_f },
  pow_zero: -> { big ** 0.0 },
  mod_zero: -> { big % 0.0 },
  modulo_zero: -> { big.modulo(0.0) },
  remainder_zero: -> { big.remainder(0.0) },
  divmod_zero: -> { big.divmod(0.0) },
  math_sqrt: -> { Math.sqrt(big) },
  math_log: -> { Math.log(big) },
  complex_float: -> { Complex(big, 0).to_f }
}
[nil, false, true].each do |verbose|
  $VERBOSE = verbose
  cases.each do |name, operation|
    warnings.clear
    begin
      result = operation.call
      result = [result.class, result.to_s]
    rescue Exception => error
      result = [error.class, error.message]
    end
    p [verbose, name, result, warnings]
  end
end

$VERBOSE = true
[:to_f, :float_soft, :complex_soft, :sprintf, :pack, :add, :radd, :mod_zero, :divmod_zero].each do |name|
  warning_mode.replace([:raise])
  begin
    result = case name
             when :to_f then big.to_f
             when :float_soft then Float(big, exception: false)
             when :complex_soft then Float(Complex(big, 0), exception: false)
             when :sprintf then format('%g', big)
             when :pack then [big].pack('d')
             when :add then big + 1.0
             when :radd then 1.0 + big
             when :mod_zero then big % 0.0
             when :divmod_zero then big.divmod(0.0)
             end
    p [name, :returned, result]
  rescue RuntimeError => error
    p [name, error.class, error.message]
  end
  warning_mode.clear
  begin
    result = Float('bad')
    p [:after_warning, :returned, result]
  rescue ArgumentError => error
    p [:after_warning, error.class]
  end
end
