# Minitest's expected message continues its format string onto the % line.
message = "Expected foo(%p) => nil, got [foo(%p) => nil]" \
  % [{kw: false}, {kw: true}]
puts message
p(13 \
  % 5)
p("%s:%d" \
  \
  % ["value", 7])
# A value is still expected when the continued line follows an assignment.
literal = \
  % hello 
p literal
literal = \
	%Q world 
p literal
