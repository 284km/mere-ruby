bases = [-(2**80), -(2**63)-1, -(2**63), -(2**31)-1, -(2**31),
         -1, 0, 1, 2, 10, 36, 37, 2**31-1, 2**31, 2**32,
         2**63-1, 2**63, 2**80]
[0, -123, 2**100].each do |number|
  bases.each do |base|
    begin
      p [number, base, number.to_s(base)]
    rescue => error
      p [number, base, error.class, error.message]
    end
  end
end
class Integer
  alias radix_native_1117 to_s
end
[0, 2**100].each do |number|
  [:to_s, :radix_native_1117].each do |name|
    [2, 2**32, 2**80].each do |base|
      begin
        p [name, number.method(name).call(base)]
      rescue => error
        p [name, error.class, error.message]
      end
    end
  end
end
