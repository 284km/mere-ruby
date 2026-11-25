# Set the real OS disposition immediately before exec. This asks about the
# new interpreter's inherited signal state, independently of spawn's defaults.
%w[INT HUP].each do |signal|
  source = 'p Signal.trap(ARGV.fetch(0), "DEFAULT")'
  output = IO.popen(['sh', '-c', 'trap "" "$1"; shift; exec "$@"',
                    'signal-child', signal, RbConfig.ruby, '-e', source, signal], &:read)
  p [signal, output, $?.exitstatus]
end
