# Round the original double, keep carries in decimal digits and preserve -0.
# The shortest-decimal ties and the exact high-precision tail are different.
values = [3.7517675036461267e17, 1.005, 2.675, 9.995,
          9.999999999999998, 1.0e-300, 1.0e300, 5.0e-324,
          Float::MAX, 9.544810760429053e-300, 4.273233245450051e-28,
          6267035465.437347,
          0.0, -0.0]
formats = ["%.0e", "%.2e", "%.13e", "%.14e", "%.16e", "%.17E",
           "%.20e", "%.64e", "%.0g", "%.3g", "%.14g", "%.16g", "%.20G",
           "%#.0e", "%#.3g", "%+025.16e", "%- 26.16E"]
values.each do |value|
  formats.each { |format| p [format, value, sprintf(format, value)] }
end
[-0.0, 0.0, Float::INFINITY, -Float::INFINITY, Float::NAN].each do |value|
  ["%f", "%e", "%g", "%+f", "% f", "%020e"].each do |format|
    p [format, sprintf(format, value)]
  end
end
[0.00009995, 999.5, 9999.5, 0.000009995].each do |value|
  p [sprintf("%.3g", value), sprintf("%#.3G", value)]
end
