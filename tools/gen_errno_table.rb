# Generates the Errno table embedded in main.mere between the ERRNO_TABLE
# markers: every name the reference ruby has, with its NUMBER and the system's
# own text for it.
#
#   . ./tools/ref_ruby.sh && ruby tools/gen_errno_table.rb
#
# The numbers are the platform's, not ruby's -- `Errno::EINVAL::Errno` is 22 on
# darwin and 22 on linux but ENOTSUP is 45 and 95 -- so they cannot be written
# down by hand any more than the case tables can. The text comes from the same
# place for the same reason: it is what `Errno::ENOENT.new.message` prints.
#
# Rows are "NAME:number:text", comma-separated.
rows = Errno.constants.sort.filter_map do |c|
  k = Errno.const_get(c)
  next unless k.is_a?(Class) && k.const_defined?(:Errno)
  num = k::Errno
  text = k.new.message.sub(/ - .*\z/, "")
  next if text.include?(",") || text.include?(":")
  "#{c}:#{num}:#{text}"
end
warn "#{rows.size} errno rows"
puts "let errno_raw = \"#{rows.join(",")}\";"
