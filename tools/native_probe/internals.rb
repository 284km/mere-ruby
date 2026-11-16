arrays = [[], [1]]
hashes = [{}, {a: 1}]
c = ObjectSpace.count_objects
p [:allocation_type_keys, c.key?(:T_ARRAY), c.key?(:T_HASH)]
p [:values_still_live, arrays.size, hashes.size]
p [:iseq_binary_prefix, RubyVM::InstructionSequence.compile('1 + 2').to_binary.byteslice(0, 6)]
p [:yjit_constant, defined?(RubyVM::YJIT)]
p [:zjit_constant, defined?(RubyVM::ZJIT)]
