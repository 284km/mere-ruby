require 'nkf'
require 'json'
inputs = ['', 'ASCII\nRuby', "あいう漢字ｶﾞ①～😀e\u0301\r\nEND", "\0\xFF\x80\x81".b,
          (0..255).to_a.pack('C*'), '=?ISO-2022-JP?B?GyRCJCIbKEI=?=', '=?UTF-8?Q?=E3=81=82?=',
          "\x1b$B$\"\x1b(B".b, '%E3%81%82', ':e3:81:82', '&#x3042;&#12354;']
%w[EUC-JP Shift_JIS Windows-31J ISO-2022-JP UTF-16LE UTF-16BE UTF-32LE UTF-32BE].each { |e| inputs << 'あいう漢字'.encode(e) }
opts = %w[-j -e -s -w -w8 -w16 -w16L -w16B -w32 -w32L -w32B --utf8 --utf16 --jis --sjis --euc --mac --unix --windows --mime --base64]
flags = %w[-x -X -Z -Z0 -Z1 -Z2 -Z3 -Z4 -h1 -h2 -h3 -Lu -Lw -Lm -r -f12 -F12 -m0 -mB -mQ -MB -MQ -M -B -I -t -t2 --cap-input --url-input --numchar-input --no-output --cp932 --no-cp932 --cp932inv --x0212 --ms-ucs-map --utf8mac-input --no-cp932ext --no-best-fit-chars --fb-skip --fb-html --fb-xml --fb-java --fb-perl --fb-subchar=0x3f --prefix=\\]
opts += flags.map { |f| '-w '+f }
opts += ['', '-t', '--oc=missing', '-w --ic=missing', '-w --ic=UTF-8', '-w --oc=UTF-8-BOM', '-w --oc=eucJP-nkf', '-w -- "-s"', '"-w"', "'-w'", '-w '+('x'*256)]
rows = opts.product(inputs).map do |option,input|
  begin
    result = NKF.nkf(option,input)
    [option,input.bytes,result.bytes,result.encoding.name]
  rescue => e
    [option,input.bytes,nil,e.class.name,e.message]
  end
end
puts JSON.generate({source:'ruby/nkf 65506fecfd6bec82552746473bb91899d861a849',gem:NKF::GEM_VERSION,rows:rows,guesses:inputs.map { |s| [s.bytes,NKF.guess(s).name] }})
