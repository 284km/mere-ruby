# A line that is exactly `__END__` ends the program where the lexer meets it
# in code -- and not inside a heredoc, where it is text (CRuby's test_io has
# one in an assert_separately source, and the whole file read as cut there).
src = <<-SRC
first line
__END__
last line
SRC
p src.lines.size, src.include?("__END__")
squiggly = <<~EOS
  __END__ is only text here
EOS
p squiggly
p eval("1 + 2\n__END__\nnot code")
p DATA.read
__END__
the data
  after the end
