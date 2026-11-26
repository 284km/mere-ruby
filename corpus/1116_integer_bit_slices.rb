large = (0x123456789abcdef << 96) | 0x12345678
wide = 2**62 - 1
[-large, large, -16, 16, 0].each do |number|
  [-66, -5, 0, 5, 160, 300].each do |offset|
    [-7, -1, 0, 1, 12, 40, 71].each do |width|
      p [number, offset, width, number[offset, width]]
    end
  end
end
[large].each do |number|
  [-5, 0, 5, 300].each { |offset| p [number, offset, :wide, number[offset, wide]] }
end
[-large, large].each do |number|
  p [number, :below_zero, number[-(2**62), 100]]
end
events = []
start = Object.new
start.define_singleton_method(:to_int) { events << :start; -5 }
length = Object.new
length.define_singleton_method(:to_int) { events << :length; -1 }
p [large[start, length], events]
