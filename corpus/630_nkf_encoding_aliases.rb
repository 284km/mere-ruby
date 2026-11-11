# Every encoding spelling in the pinned NKF conversion table.
require 'nkf'
names = ["US-ASCII", "ASCII", "646", "ROMAN8", "ISO-2022-JP", "ISO2022JP-CP932", "CP50220", "CP50221", "CSISO2022JP", "CP50222", "ISO-2022-JP-1", "ISO-2022-JP-3", "ISO-2022-JP-2004", "SHIFT_JIS", "SJIS", "MS_Kanji", "PCK", "WINDOWS-31J", "CSWINDOWS31J", "CP932", "MS932", "CP10001", "EUCJP", "EUC-JP", "EUCJP-NKF", "CP51932", "EUC-JP-MS", "EUCJP-MS", "EUCJPMS", "EUC-JP-ASCII", "EUCJP-ASCII", "SHIFT_JISX0213", "SHIFT_JIS-2004", "EUC-JISX0213", "EUC-JIS-2004", "UTF-8", "UTF-8N", "UTF-8-BOM", "UTF8-MAC", "UTF-8-MAC", "UTF-16", "UTF-16BE", "UTF-16BE-BOM", "UTF-16LE", "UTF-16LE-BOM", "UTF-32", "UTF-32BE", "UTF-32BE-BOM", "UTF-32LE", "UTF-32LE-BOM", "BINARY"]
names.each do |name|
  begin
    encoded = NKF.nkf('-W --oc=' + name, "あいう漢字ｶﾞ①～😀")
    p [name, encoded.bytes, encoded.encoding.name]
    decoded = NKF.nkf('-w --ic=' + name, encoded)
    p [name, decoded.bytes, decoded.encoding.name]
  rescue => error
    p [name, error.class.name, error.message]
  end
end
