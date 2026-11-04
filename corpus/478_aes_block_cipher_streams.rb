require 'openssl'
# FIPS 197 Appendix C and SP 800-38A F.2: independent ciphertexts, in
# addition to streaming round trips (which alone cannot prove correctness).
plain = ['00112233445566778899aabbccddeeff'].pack('H*')
vectors = {
  128 => '69c4e0d86a7b0430d8cdb78070b4c55a',
  192 => 'dda97ca4864cdfe06eaf70a0ec0d7191',
  256 => '8ea2b7ca516745bfeafc49904b496089',
}
vectors.each do |bits, expected|
  key = (0...(bits / 8)).to_a.pack('C*')
  cipher = OpenSSL::Cipher.new("AES-#{bits}-ECB").encrypt
  cipher.padding = 0
  cipher.key = key
  encrypted = cipher.update(plain) + cipher.final
  raise 'FIPS encryption mismatch' unless encrypted.unpack1('H*') == expected
  cipher.decrypt
  cipher.padding = 0
  cipher.key = key
  raise 'FIPS decryption mismatch' unless cipher.update(encrypted) + cipher.final == plain
  p [bits, expected]
end

plain = ['6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e51'].pack('H*')
iv = ['000102030405060708090a0b0c0d0e0f'].pack('H*')
[
  ['2b7e151628aed2a6abf7158809cf4f3c', '7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b2'],
  ['8e73b0f7da0e6452c810f32b809079e562f8ead2522c6b7b', '4f021db243bc633d7178183a9fa071e8b4d9ada9ad7dedf4e5e738763f69145a'],
  ['603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4', 'f58c4c04d6e5f1ba779eabfb5f7bfbd69cfc4e967edb808d679f777bc6702c7d'],
].each do |key_hex, expected|
  cipher = OpenSSL::Cipher.new("AES-#{key_hex.length * 4}-CBC").encrypt
  cipher.key = [key_hex].pack('H*')
  cipher.iv = iv
  cipher.padding = 0
  encrypted = cipher.update(plain.byteslice(0, 7)) + cipher.update(plain.byteslice(7..)) + cipher.final
  raise 'CBC encryption mismatch' unless encrypted.unpack1('H*') == expected
  cipher.decrypt
  cipher.padding = 0
  cipher.key = [key_hex].pack('H*')
  cipher.iv = iv
  raise 'CBC decryption mismatch' unless cipher.update(encrypted) + cipher.final == plain
  p [cipher.name, expected]
end

[128, 192, 256].each do |bits|
  ['CBC', 'ECB'].each do |mode|
    cipher = OpenSSL::Cipher.new("AES-#{bits}-#{mode}").encrypt
    cipher.key = (0...(bits / 8)).to_a.pack('C*')
    cipher.iv = iv if mode == 'CBC'
    message = "stream\x00\xff".b * 5
    buffer = ''.b
    prefix = cipher.update(message.byteslice(0, 5))
    copy = cipher.dup
    suffix = cipher.update(message.byteslice(5..), buffer)
    raise 'output identity lost' unless suffix.equal?(buffer)
    encrypted = prefix + suffix + cipher.final
    raise 'duplicate state lost' unless copy.update(message.byteslice(5..)) + copy.final == suffix + encrypted.byteslice(suffix.bytesize..)
    cipher.reset
    raise 'reset state lost' unless cipher.update(message) + cipher.final == encrypted
    cipher.decrypt
    cipher.key = (0...(bits / 8)).to_a.pack('C*')
    cipher.iv = iv if mode == 'CBC'
    decrypted = ''.b
    encrypted.bytes.each { |byte| decrypted << cipher.update([byte].pack('C')) }
    decrypted << cipher.final
    raise 'streaming decryption mismatch' unless decrypted == message
    p [bits, mode, encrypted.unpack1('H*')]
  end
end

cipher = OpenSSL::Cipher.new('AES-128-CBC').encrypt
begin; cipher.key = 'short'; rescue ArgumentError => error; p error.class; end
begin; cipher.update('abc'); rescue OpenSSL::Cipher::CipherError => error; p error.class; end
cipher.key = 'a' * 16
cipher.iv = 'b' * 16
cipher.decrypt
begin; cipher.update('x' * 16); cipher.final; rescue OpenSSL::Cipher::CipherError => error; p error.class; end
begin; OpenSSL::Cipher.allocate.final; rescue RuntimeError => error; p error.class; end

# Initialization, key invalidation and metadata are also stateful APIs.
[:name, :key_len, :iv_len, :block_size, :authenticated?, :encrypt, :decrypt, :reset, :final, :random_key, :random_iv].each do |method|
  begin
    OpenSSL::Cipher.allocate.public_send(method)
    p [method, :no_error]
  rescue Exception => error
    p [method, error.class]
  end
end
cipher = OpenSSL::Cipher.new('aes-128-ecb')
cipher.key = (0...16).to_a.pack('C*')
cipher.padding = 0
p ['default', (cipher.update(['00112233445566778899aabbccddeeff'].pack('H*')) + cipher.final).unpack1('H*')]
cipher = OpenSSL::Cipher.new('aes-128-cbc').encrypt
cipher.key = 'a' * 16
cipher.iv = 'b' * 16
first = cipher.update('data') + cipher.final
cipher.encrypt
begin; cipher.update('data'); rescue OpenSSL::Cipher::CipherError => error; p error.class; end
cipher.key = 'a' * 16
second = cipher.update('data') + cipher.final
p ['encrypt resets IV', first == second]
name = cipher.name
name.replace('changed')
p cipher.name
['MD5', 'SHA256', 'SHA512'].each do |digest|
  cipher = OpenSSL::Cipher.new('AES-256-CBC').encrypt
  cipher.pkcs5_keyivgen("p\xc3\xa1ssword".b, "salt\xff\x00\x01\x02".b, 2, digest)
  p [digest, (cipher.update('derived key') + cipher.final).unpack1('H*')]
end
cipher = OpenSSL::Cipher.new('AES-128-CBC').encrypt
cipher.key = 'k' * 16
cipher.iv = 'i' * 16
begin
  cipher.update('data', ''.freeze)
rescue FrozenError => error
  p error.class
end
p (cipher.update('data') + cipher.final).unpack1('H*')
cipher.reset
same = 'data'
p cipher.update('data', same).equal?(same)
p (same + cipher.final).unpack1('H*')

# Supplied buffers retain their encoding, even when an update emits no bytes.
['UTF-8', 'UTF-16LE', 'ISO-8859-1'].each do |encoding|
  cipher = OpenSSL::Cipher.new('AES-128-CBC').encrypt
  cipher.key = 'k' * 16
  cipher.iv = 'i' * 16
  output = 'old'.dup.force_encoding(encoding)
  first = cipher.update('p', output)
  p [encoding, first.equal?(output), output.encoding.name, output.bytesize]
  second = cipher.update('p' * 15, output)
  p [encoding, second.equal?(output), output.encoding.name, output.unpack1('H*')]
end

# Explicit nil options have the same defaults as omitted arguments.
[[], [nil, nil, nil], [nil, 1, nil], [nil, 1, 'MD5']].each do |options|
  cipher = OpenSSL::Cipher.new('AES-128-ECB').encrypt
  p cipher.pkcs5_keyivgen('pw', *options)
  p (cipher.update('derived key') + cipher.final).unpack1('H*')
end
