require 'stringio'
require 'yaml'

stream = StringIO.new('hello')
p stream.instance_variables
p stream.instance_variable_defined?(:@st)
stream.instance_variable_set(:@st, :user_value)
stream.instance_variable_set(:@label, 'visible')
p stream.string
p stream.instance_variables.sort
p stream.read(2)
p stream.dup.pos

serialized = YAML.dump({'stream' => stream})
puts serialized
restored = YAML.unsafe_load(serialized)['stream']
p restored.class
p restored.instance_variables.sort
p restored.instance_variable_get(:@st)
p restored.instance_variable_get(:@label)
