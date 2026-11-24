begin
  eval 'class InvalidYield1010; yield; end', nil, 'generated1010.rb', 42
rescue SyntaxError => error
  p error.message
  p error.backtrace
  p error.backtrace_locations
end
begin
  eval 'missing_rhs1010 =', nil, 'generated1010.rb', 42
rescue SyntaxError => error
  p error.message.include?('syntax errors found')
  p error.message.include?('expected an expression after `=`')
  p error.message.include?('unexpected end-of-input')
end
