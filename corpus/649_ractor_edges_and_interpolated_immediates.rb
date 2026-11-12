# Round 28 of note 545: what a non-main ractor is refused -- fork, Etc's
# database calls, ENV's instance variables, a C-function block made
# shareable -- and what it has of its own (a default ThreadGroup); a
# shareability error names a Method as it inspects, through its singleton
# class too; an immediate whose #to_s answers no String interpolates as
# rb_any_to_s writes it; ENV runs instance_eval as itself.
Warning[:experimental] = false
require "etc"

p Ractor.new { Process.fork rescue $!.class }.value
p Ractor.new { Etc.passwd rescue $!.class }.value
p Ractor.new { Etc.nprocessors.is_a?(Integer) }.value
main_group = Thread.current.group
p Ractor.new { Thread.current.group.class }.value, Ractor.new { Thread.current.group }.value.equal?(main_group)

ENV.instance_eval { @mark = "set" }
p ENV.instance_variable_get(:@mark), ENV.instance_eval { self.equal?(ENV) }
p Ractor.new { ENV.instance_variable_get(:@mark) rescue $!.class }.value

x = (+"").instance_exec { method(:to_s) }
def x.to_s = raise("not called")
begin
  Ractor.make_shareable(x)
rescue Ractor::Error => e
  p e.message
end
[Hash.new { 1 }.to_proc, method(:p).to_proc].each do |pr|
  Ractor.make_shareable(pr)
rescue RuntimeError => e
  p e.message
end

class Symbol; alias __to_s_was to_s; undef to_s; def to_s = nil; end
p "#{:sym}".match?(/\A#<Symbol:0x\h{16}>\z/)
class Symbol; undef to_s; alias to_s __to_s_was; end
class NilClass; alias __to_s_was to_s; undef to_s; def to_s = 1; end
p "#{nil}"
class NilClass; undef to_s; alias to_s __to_s_was; end
p "#{nil}", RubyVM.keep_script_lines
# backticks in several threads at once each read their own command's output
p 8.times.map { |i| Thread.new { 20.times.all? { `echo #{i}` == "#{i}\n" } } }.map(&:value).all?
