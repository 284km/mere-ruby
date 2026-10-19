# Regexps as test_regexp asks: subexpression calls, level backrefs,
# nested repeat reductions, POSIX brackets, named []= and fragments

def show(re, *strs)
  strs.each { |s| m = re.match(s); puts "#{re.source} =~ #{s.inspect}: #{m ? m.to_a.inspect : 'nil'}" }
end

# \g<name> and \g<n>: calls, recursion
show(/\A(?<paren>\((?:[^()]|\g<paren>)*\))\z/, "(a(b)c)", "((x)", "(())")
show(/\A(a|b\g<1>c)\z/, "a", "bac", "bbacc", "bbac")
show(/(?<w>\w)-\g<w>/, "a-b", "x-")
show(/\A(?<a>|.|(?:(?<b>.)\g<a>\k<b+0>))\z/, "abcba", "abba", "abcd", "")

# multiplex \k<x>
show(/(?<x>a)|(?<x>b)\k<x>/, "bb", "a", "ba")

# errors
[ '\g<foo>', '(?<x>a)(?<x>b)\g<x>', '(?<a>\g<a>)', '\g<2>(a)' ].each do |s|
  begin
    Regexp.new(s); puts "#{s}: ok"
  rescue RegexpError => e
    puts "#{s}: #{e.message}"
  end
end

# nested repeat warnings (always said)
def warns
  old = $stderr
  $stderr = StringIO.new
  yield
  $stderr.string
ensure
  $stderr = old
end
require 'stringio'
%w[(?:a?)? (?:a+)? (?:a*)* a?* (?:a??)+ (?:a*)?? (a?)? (?:a+?)+? (?i:a?)?].each do |q|
  w = warns { Regexp.new(q) }
  puts "#{q}: #{w.sub(/\A.*warning: /, '').chomp}"
end

# POSIX brackets: a long unknown name is plain members
r = nil
puts warns { r = Regexp.new('\A[[:abcdefghijklmnopqrstu:]]+\z') }.gsub(/^.*warning: /, '')
p r && r.match?("[]"), r && r.match?("a")
begin; Regexp.new('[[:ab12:]]'); rescue RegexpError => e; puts e.message; end
p(/[[:0]]/.match?("0"))

# s[re, name] = v
s = +"foo"; s[/(?<bar>o)/, "bar"] = "baz"; p s
s = +"xby"; s[/(?<a>a)|(?<a>b)/, :a] = "Q"; p s
begin; s[/(?<a>y)/, "zz"] = "1"; rescue IndexError => e; p e.message; end

# an interpolated piece is read on its own
x = "\\"
begin; /#{x}y/; rescue ArgumentError => e; p e.message; end
y = "\\x"
begin; /#{y}41/; rescue ArgumentError => e; p e.message; end
p(/#{"("}a)/)
begin; eval('/#{"\\\\"}y/'); rescue SyntaxError => e; p e.message[/too short.*/]; end
x = "b"
p(/a#{x}/, /#{}/, /#{x; x}c/, /#{x # c
}d/, /#{:"q"}/, /#{1}#{nil}/)
