h = {a: 7}
x = (h => {a:}; a)
p [x, a]
def pattern_sequence(h) = (h => {a: 1}; :ok)
p pattern_sequence({a: 1})

p eval('h = {a: 3}; x = (h => {a:}; a); [x, a]')
p eval('def sequence_eval(h) = (h => {a: 1}; :ok); sequence_eval({a: 1})')
p eval("({a: 2} => {a:}\na)")
p eval('({a: 2} => {a:};)')

# A newline/semicolon is required between the match and a second statement.
['({a: 1} => {a:} a)', '({a: 1} => {a: 2}; :unreachable)'].each do |source|
  begin
    eval(source)
  rescue Exception => error
    p error.class
  end
end
