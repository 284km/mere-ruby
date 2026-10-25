# A path written in Windows-31J or Latin-1 reaches the OS as UTF-8, and what
# comes back -- an error, Dir#inspect, a glob, a LoadError -- speaks the
# path's own

require "tmpdir"

sjis = "\u{3042}".encode("Windows-31J")
latin = "\u{ff}".encode("ISO-8859-1")
Dir.mktmpdir do |d|
  Dir.chdir(d) do
    # a refusal names the path in its encoding
    p [sjis, latin].map { |pa| (Dir.open(pa) rescue $!.message.encoding) }
    # mkdir of a non-UTF-8 name, and the Dir names it as written
    p [sjis, latin].map { |pa| Dir.mkdir(pa); Dir.open(pa) { |dd| [dd.path.encoding, dd.inspect.encoding] } }
    p Dir.exist?(sjis), Dir.children(".").size

    # each pattern's names carry that pattern's encoding
    %w[file_one.ext file_two.ext].each { |f| File.binwrite(f, "") }
    a = "file_one*".dup.force_encoding(Encoding::IBM437)
    b = "file_two*".dup.force_encoding(Encoding::EUC_JP)
    p Dir[a, b].map(&:encoding), Dir[a, b]

    # File.path and File.join keep it
    p File.path(sjis).encoding, File.join(sjis, "x").encoding, File.join("a", "b").encoding

    # require and load: the LoadError names the path as written
    [sjis, "\u{221e}"].each do |pa|
      begin
        require pa
      rescue LoadError => e
        p [e.message.encoding, e.message.end_with?(pa)]
      end
    end
    base = "test_load\u{3042 3044}".encode(Encoding::Windows_31J)
    begin
      load(File.join(d, base))
    rescue LoadError => e
      p e.message.encoding, e.message.end_with?(base)
    end
    File.write(File.join(d, base + ".rb"), "$loaded_ok = 1\n")
    load(File.join(d, base + ".rb"))
    p $loaded_ok
  end
end
p require("enc/trans/single_byte")
