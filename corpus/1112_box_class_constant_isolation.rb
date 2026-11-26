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
  absolute = <<~'RUBY'
    module Root1112; X = :top; end
    module Scope1112
      module Root1112; X = :inner; end
      p [Root1112::X, ::Root1112::X]
    end
  RUBY
  eval(absolute)
  first.eval(absolute)
  second.eval(absolute)
  hooked = <<~'RUBY'
    module Hooked1112
      Real = Module.new { def value = :ok }
      Namespace = Module.new
      Namespace.const_set(:Feature, Real)
      def self.const_missing(name)
        ($calls1112 ||= []) << name
        name == :Alias ? Namespace : super
      end
    end
    class Receiver1112
      include Hooked1112::Alias::Feature
    end
    p [Receiver1112.new.value, $calls1112]
    module Hooked1112
      def self.const_missing(name)
        ($nil_calls1112 ||= []) << name
        name == :Absent ? nil : super
      end
    end
    p [Hooked1112::Absent, $nil_calls1112]
  RUBY
  eval(hooked)
  first.eval(hooked)
  second.eval(hooked)
  inheritance = <<~'RUBY'
    module ErrOuter1112
      class Base < StandardError; end
      class Child < Base; end
    end
    p [ErrOuter1112::Child.superclass.equal?(ErrOuter1112::Base), ErrOuter1112::Child.name]
    class RuntimeChild1112 < Class.new(StandardError); end
    p [RuntimeChild1112.superclass.name, RuntimeChild1112.superclass.superclass.equal?(StandardError)]
  RUBY
  eval(inheritance)
  first.eval(inheritance)
  second.eval(inheritance)
  labels = <<~'RUBY'
    begin
      class Label1112
        raise "box label"
      end
    rescue RuntimeError => error
      p error.backtrace_locations.first.label
    end
    p [Label1112.name, Label1112.inspect]
    begin
      Label1112::Missing
    rescue NameError => error
      p [error.name, error.receiver.equal?(Label1112), error.message.lines.first.chomp]
    end
    module ModuleLabel1112
      p caller_locations(0, 1).first.label
    end
    p [ModuleLabel1112.name, ModuleLabel1112.inspect]
  RUBY
  eval(labels)
  first.eval(labels)
  second.eval(labels)
CODE
print IO.popen([{'RUBY_BOX' => '1'}, RbConfig.ruby, '-W0', '-e', child, err: File::NULL], &:read)
p $?.exitstatus
