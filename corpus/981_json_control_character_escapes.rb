require "json"
# JSON 2.18.3 rejects malformed escapes with allow_control_characters while
# preserving the default diagnostics, including the escaped-newline message.
[:default, false, true].each do |mode|
  options = mode == :default ? {} : { allow_control_characters: mode }
  [0, 1, 9, 10, 13, 31].each do |byte|
    sources = [[34, 97, byte, 34].pack("C*"),
               [34, 92, byte, 34].pack("C*"),
               [34, *([97] * 30), 92, byte, 34].pack("C*")]
    sources.each do |source|
      begin
        p [mode, byte, JSON.parse(source, **options)]
      rescue JSON::ParserError => error
        p [mode, byte, error.class.name, error.message]
      end
    end
  end
end
