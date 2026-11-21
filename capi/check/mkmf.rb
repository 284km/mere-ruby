# The library extconf.rb and make built, loaded: what mkmf's questions were
# answered with is read out of it.
require 'mkmf_probe'
$count = 0
def check(value)
  raise 'mkmf contract failed' unless value
  $count += 1
end
answers = MkmfProbe.answers
check(answers['stdint.h'] == true)
check(answers['no_such_header_anywhere.h'] == false)
check(answers['strlen'] == true)
check(answers['no_such_function_anywhere'] == false)
# A function of the C API is there when this ruby has it. TracePoint from C
# is one mere-ruby does not provide (capi/unsupported.c): there the answer is
# no, and an extension takes its other path instead of meeting
# NotImplementedError when it runs.
check(answers['rb_ary_new'] == true)
check(answers['rb_no_such_function_anywhere'] == false)
check(answers['rb_tracepoint_new'] == (ENV['CAPI_CHECK_SIDE'] != 'mere'))
check(answers['__STDC__'] == true)
check(answers['NO_SUCH_MACRO_ANYWHERE'] == false)
check(answers['sizeof(long)'] == [0].pack('l!').bytesize)
check(answers['note'] == 7)
check(MkmfProbe.floor(2.75) == 2.0)
# ruby's own ext/-test-/float, through its own extconf.rb
require '-test-/float'
check(Bug::Float.system_nextafter(1, 2) == 1.0.next_float)
check($LOADED_FEATURES.any? { |f| f.end_with?('/mkmf_probe.' + RbConfig::CONFIG['DLEXT']) })
puts "mkmf contracts: #{$count} passed"
