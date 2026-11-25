child = <<~'CODE'
  first = Ruby::Box.new
  second = Ruby::Box.new
  first.eval('class Example1112; VALUE = :first; def value = VALUE; end; Alias1112 = Example1112')
  second.eval('class Example1112; VALUE = :second; def value = VALUE; end; Alias1112 = Example1112')
  %w[Example1112::VALUE ::Example1112::VALUE Alias1112::VALUE ::Alias1112::VALUE Example1112.const_get(:VALUE) Example1112.new.value].each do |source|
    p [first.eval(source), second.eval(source)]
  end
  p first.eval('Example1112').equal?(second.eval('Example1112'))
  p [first.eval('Example1112.name'), second.eval('Example1112.name')]
  second.eval('class Example1112; VALUE = :second_updated; end')
  p [first.eval('Example1112::VALUE'), second.eval('Example1112::VALUE')]
  first.eval('module Outer1112; module Inner; VALUE = :first_nested; end; end')
  second.eval('module Outer1112; module Inner; VALUE = :second_nested; end; end')
  p [first.eval('Outer1112::Inner::VALUE'), second.eval('Outer1112::Inner::VALUE')]
  p [first.eval('::Outer1112::Inner::VALUE'), second.eval('::Outer1112::Inner::VALUE')]
  first.eval('module Mix1112; module Middle; module Inner; def mixed = :first_mixed; end; end; end; class Included1112; include Mix1112::Middle::Inner; end')
  second.eval('module Mix1112; module Middle; module Inner; def mixed = :second_mixed; end; end; end; class Included1112; include Mix1112::Middle::Inner; end')
  p [first.eval('Included1112.new.mixed'), second.eval('Included1112.new.mixed')]
  p defined?(Example1112)
CODE
print IO.popen([{'RUBY_BOX' => '1'}, RbConfig.ruby, '-W0', '-e', child, err: File::NULL], &:read)
p $?.exitstatus
