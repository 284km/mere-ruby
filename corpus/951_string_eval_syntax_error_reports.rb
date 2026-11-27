source = "def broken\n  nil(\nend\n"
[:module_eval, :class_eval, :instance_eval].each do |method|
  receiver = Class.new
  [1, 17, 0].each do |line|
    begin
      receiver.public_send(method, source, 'syntax-probe', line)
    rescue SyntaxError => error
      p [method, line, error.class.name, error.message]
    end
  end
end

object = Object.new
begin
  object.instance_eval(source, 'object-syntax-probe', 3)
rescue SyntaxError => error
  p [:object, error.class.name, error.message]
end

begin
  Class.new.module_eval(source)
rescue SyntaxError => error
  p [:default_path, error.class.name, error.message.include?('syntax')]
end

target = Class.new
target.module_eval('def value = 42', 'valid-probe', 1)
p [:valid, target.new.value]

target.instance_eval('def singleton_source951; [__FILE__, __LINE__]; end', 'valid-instance-probe', 11)
p [:valid_instance_source, target.singleton_source951]
p [:caller_restored, caller(0).first.include?('951_string_eval_syntax_error_reports.rb')]
