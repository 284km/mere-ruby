# A radix is validated after conversion, including an ordinary Bignum.
big = 2**1024 - 1
[0, 1, 42, big, -1, -big].each do |value|
  [-big, -Float::MAX, Rational(-big, 3)].each do |base|
    begin
      p value.digits(base)
    rescue => error
      p [error.class, error.message]
    end
  end
end
[1, 42, big].each { |value| p value.digits(big * 2) }
[0, 1, -1].each do |base|
  begin
    p big.digits(base)
  rescue => error
    p [error.class, error.message]
  end
end
