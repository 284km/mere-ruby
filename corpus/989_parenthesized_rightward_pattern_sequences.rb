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

# Pattern tests share sequence and modifier continuation with rightward binds.
p (h in {a:}; a)
def pattern_test_sequence(h) = (h in {a: 1}; :ok)
p pattern_test_sequence({a: 1})
[
  '(h in {a:} and true; a)', '(h in {a:} or false; a)',
  "(h in {a:}\n a)", '(h => [x] rescue :rescued)',
  '(h => {a:} if true)', '(h => {a:} unless false; a)',
  '(h in {a:} if true; a)', '(h => {a: 0} if false)',
  '(h => {a:} while (count += 1) < 2; a)',
  '(h in {a:} until (count += 1) > 1; a)'
].each do |source|
  p eval('h = {a: 5}; count = 0; ' + source)
end
