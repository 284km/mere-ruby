['x =', '@x =', 'A =', 'h[:a] =', 'x ==', 'x +=', 'x !=', 'x >=', 'x <=', 'x ===', 'a ||=', 'def f ='].each do |source|
  begin
    eval(source, binding, 'unfinished.rb', 7)
  rescue SyntaxError => error
    p error.message
  end
end
