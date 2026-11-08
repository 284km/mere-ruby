# Before the fix, even this one-node graph recursively expands until failure.
require 'psych'
value = []
value << value
output = Psych.dump(value)
raise 'cycle was not represented by an alias' unless output == "--- &1\n- *1\n"
puts output
