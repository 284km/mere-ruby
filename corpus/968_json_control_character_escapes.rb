require "json"
# JSON 2.18.3 distinguishes a raw control byte from a malformed escape.
[false, true].each do |allowed|
  [0, 1, 9, 10, 13, 31].each do |byte|
    ["\"a" + byte.chr + "\"", "\"" + "a" * 30 + "\\" + byte.chr + "\""].each do |source|
      begin
        p [allowed, byte, JSON.parse(source, allow_control_characters: allowed)]
      rescue JSON::ParserError => error
        p [allowed, byte, error.class.name]
      end
    end
  end
end
