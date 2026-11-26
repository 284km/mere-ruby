# IO's and File's methods as reflection names them: IO's own public methods,
# File's own (the stat-like few: ruby's File inherits read, close and the rest
# from IO), and none of an implementation's internal helpers.
COMMON = %i[<< autoclose? binmode close closed? each each_line eof eof? fileno flush getc gets
            inspect lineno pos print printf putc puts read readline readlines readpartial reopen
            rewind seek stat sync sync= sysread syswrite tell to_i tty? ungetc write]
p (COMMON - IO.instance_methods(false)), (COMMON - IO.public_instance_methods(false))
p (COMMON & File.instance_methods(false))
p File.instance_methods(false).sort
p File.public_instance_methods(false).sort
p (IO.instance_methods(false) - IO.instance_methods).size
r, w = IO.pipe
internal = ->(list) { list.grep(/\A__/) - %i[__id__ __send__] }
p internal[IO.instance_methods(false)], internal[IO.public_instance_methods(false)],
  internal[IO.instance_methods], internal[File.instance_methods], internal[r.methods],
  internal[r.public_methods], internal[File.open(__FILE__).methods]
p (COMMON - r.methods), (COMMON - File.open(__FILE__).methods)
p File.instance_methods.include?(:close_write), File.instance_methods.include?(:read)
p IO.method_defined?(:closed?), IO.public_method_defined?(:read), File.method_defined?(:read)
# undef_method of an IO method in an IO's singleton class: ruby's Bug #18077
r.close; w.close
begin; Marshal.dump(r); rescue TypeError => e; p e.message; end
class << r
  undef_method :closed?
end
p r.respond_to?(:closed?)
begin; Marshal.dump(r); rescue TypeError => e; p e.message; end
s, t = IO.pipe
s.singleton_class.send(:undef_method, :read)
p s.respond_to?(:read), t.respond_to?(:read)
f = File.open(__FILE__)
class << f
  undef_method :read
end
p f.respond_to?(:read), f.respond_to?(:gets)
f.close
# a name no class has is still refused
begin
  class << t
    undef_method :no_such_io_method
  end
rescue NameError => e
  puts e.message.sub(/#<Class:#<IO:[^>]*>>/, "#<Class:#<IO>>")
end
s.close; t.close
