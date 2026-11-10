require 'socket'
require 'io/nonblock'
require 'ipaddr'

module OpenSSL
  module SSL
    class SSLError < OpenSSLError; end
    class SSLErrorWaitReadable < SSLError; include IO::WaitReadable; end
    class SSLErrorWaitWritable < SSLError; include IO::WaitWritable; end
    if OpenSSL.__native_available
      Backend.call('tls.constants').each { |name, value| const_set(name, value) }
    end
    class SSLContext < NativeObject
      SSL.constants.grep(/^SESSION_CACHE_/).each { |name| const_set(name, SSL.const_get(name)) }
      CALLBACKS = {verify_callback: 1, servername_cb: 2, alpn_select_cb: 4,
        client_cert_cb: 8, keylog_cb: 16, session_new_cb: 32,
        session_get_cb: 64, renegotiation_cb: 128, tmp_dh_callback: 256, npn_select_cb: 512,
        session_remove_cb: 1024}.freeze
      attr_accessor :cert, :key, :extra_chain_cert, :client_ca, :ca_file, :ca_path,
        :verify_mode, :verify_depth, :verify_callback, :verify_hostname, :cert_store,
        :client_cert_cb, :renegotiation_cb, :session_id_context, :session_get_cb,
        :session_new_cb, :session_remove_cb, :alpn_protocols, :alpn_select_cb,
        :keylog_cb, :tmp_dh_callback
      if Backend.call('tls.npn_available')
        attr_accessor :npn_protocols, :npn_select_cb
      end
      undef_method :initialize_copy
      def __native_id
        OpenSSL.__native_handle(self)
      rescue TypeError
        __take(Backend.call('tls_context.new'))
        OpenSSL.__native_handle(self)
      end
      def __change(name, value)
        raise FrozenError, "can't modify frozen SSLContext" if frozen?
        Backend.call('tls_context.set_' + name, self, value)
        value
      end
      def options; Backend.call('tls_context.options', self); end
      def options=(value); __change('options', value.nil? ? SSL::OP_ALL : Integer(value)); value; end
      def self.version_number(value)
        return 0 if value.nil?
        return value if value.is_a?(Integer)
        name = value.to_s
        name = name.sub(/\ATLS1/, 'TLSv1')
        {'SSL2'=>SSL::SSL2_VERSION, 'SSL3'=>SSL::SSL3_VERSION, 'SSLv2'=>SSL::SSL2_VERSION, 'SSLv3'=>SSL::SSL3_VERSION, 'TLSv1'=>SSL::TLS1_VERSION,
          'TLSv1_1'=>SSL::TLS1_1_VERSION, 'TLSv1_2'=>SSL::TLS1_2_VERSION, 'TLSv1_3'=>SSL::TLS1_3_VERSION}.fetch(name) {
          raise ArgumentError, "unrecognized version #{value.inspect}"
        }
      end
      def min_version=(value); __change('min_version', SSLContext.version_number(value)); value; end
      def max_version=(value); __change('max_version', SSLContext.version_number(value)); value; end
      def ciphers; Backend.call('tls_context.ciphers', self); end
      def ciphers=(value)
        raise FrozenError, "can't modify frozen SSLContext" if frozen?
        return nil if value.nil?
        text = value.is_a?(Array) ? value.map { |entry| entry.is_a?(Array) ? entry[0] : entry }.join(':') : ::OpenSSL::PKey.string(value)
        __change('ciphers', text)
        value
      end
      def ciphersuites=(value)
        raise FrozenError, "can't modify frozen SSLContext" if frozen?
        return nil if value.nil?
        text = value.is_a?(Array) ? value.map { |entry| entry.is_a?(Array) ? entry[0] : entry }.join(':') : ::OpenSSL::PKey.string(value)
        __change('ciphersuites', text)
        value
      end
      def sigalgs=(value); __change('sigalgs', ::OpenSSL::PKey.string(value)); value; end
      def client_sigalgs=(value); __change('client_sigalgs', ::OpenSSL::PKey.string(value)); value; end
      def groups=(value); __change('groups', ::OpenSSL::PKey.string(value)); value; end
      alias ecdh_curves= groups=
      def tmp_dh=(value); __change('tmp_dh', value); value; end
      def security_level; Backend.call('tls_context.security_level', self); end
      def security_level=(value); __change('security_level', Integer(value)); value; end
      def timeout; Backend.call('tls_context.timeout', self); end
      def timeout=(value); __change('timeout', Integer(value)); value; end
      alias ssl_timeout timeout
      alias ssl_timeout= timeout=
      def enable_fallback_scsv
        raise FrozenError, "can't modify frozen SSLContext" if frozen?
        Backend.call('tls_context.fallback_scsv', self)
        nil
      end
      def add_certificate(cert, key, chain = nil)
        raise FrozenError, "can't modify frozen SSLContext" if frozen?
        Backend.call('tls_context.add_certificate', self, cert, key, chain)
        self
      end
      def session_cache_mode; Backend.call('tls_context.session_cache_mode', self); end
      def session_cache_mode=(value); __change('session_cache_mode', Integer(value)); value; end
      def session_cache_size; Backend.call('tls_context.session_cache_size', self); end
      def session_cache_size=(value); __change('session_cache_size', Integer(value)); value; end
      def session_cache_stats; Backend.call('tls_context.session_cache_stats', self).transform_keys(&:to_sym); end
      def session_add(session); Backend.call('tls_context.session_add', self, session); end
      def __removed_sessions
        return unless @session_remove_cb
        Backend.call('tls_context.removed_sessions', self).each do |session|
          begin
            @session_remove_cb.call([self, session])
          rescue Exception
            warn 'exception in session_remove_cb is ignored'
          end
        end
      end
      def session_remove(session)
        result = Backend.call('tls_context.session_remove', self, session)
        __removed_sessions
        result
      end
      def flush_sessions(time = Time.now)
        Backend.call('tls_context.flush_sessions', self, time.to_i)
        __removed_sessions
        self
      end
      def setup
        return nil if frozen?
        [:cert_store, :ca_file, :ca_path, :cert, :key, :verify_mode, :verify_depth, :session_id_context].each do |field|
          value = public_send(field)
          Backend.call('tls_context.set_' + field.to_s, self, value) unless value.nil?
        end
        Backend.call('tls_context.check_key', self) if @cert && @key
        @extra_chain_cert&.each { |cert| Backend.call('tls_context.add_chain_cert', self, cert) }
        if @client_ca
          names = Array(@client_ca).map { |value| value.is_a?(X509::Certificate) ? value.subject : value }
          Backend.call('tls_context.set_client_ca', self, names)
        end
        if @alpn_protocols
          bytes = @alpn_protocols.map do |protocol|
            protocol = ::OpenSSL::PKey.string(protocol)
            raise SSL::SSLError, 'protocol must have 1 to 255 bytes' unless (1..255).include?(protocol.bytesize)
            [protocol.bytesize].pack('C') + protocol.b
          end.join.b
          Backend.call('tls_context.set_alpn_protocols', self, bytes)
        end
        if @npn_protocols
          bytes = @npn_protocols.map do |protocol|
            protocol = ::OpenSSL::PKey.string(protocol)
            raise SSL::SSLError, 'protocol must have 1 to 255 bytes' unless (1..255).include?(protocol.bytesize)
            [protocol.bytesize].pack('C') + protocol.b
          end.join.b
          Backend.call('tls_context.set_npn_protocols', self, bytes)
        end
        callbacks = CALLBACKS.sum { |name, bit| respond_to?(name) && public_send(name) ? bit : 0 }
        Backend.call('tls_context.callbacks', self, callbacks)
        Object.instance_method(:freeze).bind_call(self)
        true
      end
      alias freeze setup
    end

    class Session < NativeObject
      class SessionError < SSLError; end
      def initialize(value)
        object = value.is_a?(SSLSocket) ? Backend.call('tls_socket.session', value) : Backend.call('tls_session.new', ::OpenSSL::PKey.data(value))
        __take(object)
      end
      def time; value=Backend.call('tls_session.time', self); value==0 ? nil : Time.at(value); end
      def time=(value)
        number = value.is_a?(Time) ? value.to_i : Integer.try_convert(value)
        raise TypeError, 'no implicit conversion to Integer' unless number
        Backend.call('tls_session.set_time', self, number)
        value
      end
      def timeout; Backend.call('tls_session.timeout', self); end
      def timeout=(value)
        number = Integer.try_convert(value)
        raise TypeError, 'no implicit conversion to Integer' unless number
        Backend.call('tls_session.set_timeout', self, number)
        value
      end
      def id; Backend.call('tls_session.id', self); end
      def ==(other); other.is_a?(Session) && Backend.call('tls_session.equal', self, other); end
      def to_der; Backend.call('tls_session.to_der', self); end
      def to_pem; Backend.call('tls_session.to_pem', self); end
      def to_text; Backend.call('tls_session.to_text', self); end
    end

    class SSLSocket < NativeObject
      undef_method :initialize_copy
      def initialize(io, context = nil, sync_close: false)
        raise TypeError, 'expected an IO object' unless io.is_a?(IO)
        @io = io
        @context = context || SSLContext.new
        raise TypeError, 'expected SSLContext' unless @context.is_a?(SSLContext)
        @context.setup
        @sync_close = sync_close
        __take(Backend.call('tls_socket.new', @context, @io.fileno))
        super()
      end
      def __callback(kind, data)
        case kind
        when 1
          begin
            @context.verify_callback.call(*data) == true
          rescue Exception
            warn 'exception in verify_callback is ignored'
            false
          end
        when 2
          context = @context.servername_cb.call([self, data.empty? ? nil : data])
          raise ArgumentError, 'servername_cb must return an SSLContext or nil' if context && !context.is_a?(SSLContext)
          context&.setup
          @context = context if context
          context
        when 4, 512
          protocols = []
          position = 0
          while position < data.bytesize
            length = data.getbyte(position)
            raise SSLError, 'invalid ALPN list' unless length && length>0 && position+1+length<=data.bytesize
            protocols << data.byteslice(position+1,length)
            position += 1+length
          end
          callback = kind == 4 ? @context.alpn_select_cb : @context.npn_select_cb
          protocol = ::OpenSSL::PKey.string(callback.call(protocols))
          raise SSLError, 'ALPN protocol must have 1 to 255 bytes' unless (1..255).include?(protocol.bytesize)
          protocol
        when 8
          begin
            @context.client_cert_cb.call(self)
          rescue Exception
            warn 'exception in client_cert_cb is ignored'
            nil
          end
        when 16
          @context.keylog_cb.call(self, data)
          true
        when 32
          @context.session_new_cb.call([self, data])
          true
        when 64 then @context.session_get_cb.call([self, data])
        when 128
          @context.renegotiation_cb.call(self)
          true
        when 256 then @context.tmp_dh_callback.call(self, *data)
        else raise SSLError, 'unsupported TLS callback'
        end
      end
      def __operation(operation, value = nil)
        raise IOError, 'closed stream' if @io.closed?
        begin
          Backend.call('tls_job.start', self, operation, value)
          loop do
            step = Backend.call('tls_job.poll', self)
            case step[0]
            when 'pending' then sleep(0.001)
            when 'callback'
              response = __callback(step[1], step[2])
              Backend.call('tls_job.respond', self, response)
            when 'done'
              @context.__removed_sessions
              return [step[1], step[2]]
            else raise SSLError, 'invalid TLS operation state'
            end
          end
        ensure
          Backend.call('tls_job.stop', self)
        end
      end
      def __blocking(operation, value = nil)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        loop do
          status, result = __operation(operation, value)
          return [status, result] unless status == 'wait_readable' || status == 'wait_writable'
          timeout = @io.respond_to?(:timeout) ? @io.timeout : nil
          unless timeout.nil?
            timeout = IO.__interval_number(timeout)
            IO.__timeout_ms(timeout)
            timeout -= Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
            raise IO::TimeoutError, 'execution expired' if timeout <= 0
          end
          ready = status == 'wait_readable' ? @io.wait_readable(timeout) : @io.wait_writable(timeout)
          raise IO::TimeoutError, 'execution expired' unless ready
        end
      end
      def __handshake(operation, nonblock, exception)
        if @context.verify_hostname && !@hostname && operation==1
          warn 'verify_hostname requires hostname to be set'
        end
        status, value = nonblock ? __operation(operation) : __blocking(operation)
        __wait_result(status, exception) unless status == 'ok'
        return status.to_sym if status == 'wait_readable' || status == 'wait_writable'
        @started = true
        self
      rescue SSLError => error
        if operation == 2
          begin
            peer = @io.remote_address.ip_address
          rescue StandardError
            peer = nil
          end
          raise error.class, "#{error.message} (peeraddr=#{peer})", error.backtrace if peer
        end
        raise
      end
      def __wait_result(status, exception)
        return status.to_sym unless exception
        case status
        when 'wait_readable' then raise SSLErrorWaitReadable, 'read would block'
        when 'wait_writable' then raise SSLErrorWaitWritable, 'write would block'
        when 'eof' then raise EOFError, 'end of file reached'
        else raise SSLError, 'unexpected SSL operation result'
        end
      end
      def connect; __handshake(1, false, true); end
      def accept; __handshake(2, false, true); end
      def connect_nonblock(exception: true); __handshake(1, true, exception); end
      def accept_nonblock(exception: true); __handshake(2, true, exception); end
      def sysread(length, buffer = nil)
        raise SSLError, 'SSL session is not started yet' unless @started
        length = Integer(length)
        raise ArgumentError, 'negative string size' if length < 0
        result = if length==0 then ''.b
          else
            status, value = __blocking(3, length)
            __wait_result(status, true) unless status=='ok'
            value
          end
        buffer ? buffer.replace(result) : result
      end
      def sysread_nonblock(length, buffer = nil, exception: true)
        raise SSLError, 'SSL session is not started yet' unless @started
        length = Integer(length)
        raise ArgumentError, 'negative string size' if length < 0
        return buffer ? buffer.replace(''.b) : ''.b if length==0
        status, value = __operation(3, length)
        return nil if status=='eof' && !exception
        return __wait_result(status, exception) unless status=='ok'
        buffer ? buffer.replace(value) : value
      end
      def syswrite(value)
        raise SSLError, 'SSL session is not started yet' unless @started
        value = ::OpenSSL::PKey.string(value)
        return 0 if value.empty?
        status, result = __blocking(4, value)
        __wait_result(status, true) unless status=='ok'
        result
      end
      def syswrite_nonblock(value, exception: true)
        raise SSLError, 'SSL session is not started yet' unless @started
        value = ::OpenSSL::PKey.string(value)
        return 0 if value.empty?
        status, result = __operation(4, value)
        return __wait_result(status, exception) unless status=='ok'
        result
      end
      private :sysread_nonblock, :syswrite_nonblock
      def stop
        __operation(5) if @started && !@io.closed?
        nil
      rescue SSLError
        # SSL_shutdown is best effort, as in Ruby/OpenSSL. A peer may have
        # already closed its transport; closing this stream still succeeds.
        nil
      end
      def hostname=(value)
        value = ::OpenSSL::PKey.string(value)
        Backend.call('tls_socket.set_hostname', self, value, !!@context.verify_hostname)
        @hostname = value
      end
      def cert; Backend.call('tls_socket.cert', self); end
      def peer_cert; Backend.call('tls_socket.peer_cert', self); end
      def peer_cert_chain; Backend.call('tls_socket.peer_cert_chain', self); end
      def cipher; Backend.call('tls_socket.cipher', self); end
      def ssl_version; Backend.call('tls_socket.ssl_version', self); end
      def state; Backend.call('tls_socket.state', self); end
      def pending; Backend.call('tls_socket.pending', self); end
      def session_reused?; Backend.call('tls_socket.session_reused', self); end
      def session=(value); Backend.call('tls_socket.set_session', self, value); value; end
      def verify_result; Backend.call('tls_socket.verify_result', self); end
      def client_ca; Backend.call('tls_socket.client_ca', self); end
      def finished_message; Backend.call('tls_socket.finished_message', self); end
      def peer_finished_message; Backend.call('tls_socket.peer_finished_message', self); end
      def tmp_key; Backend.call('tls_socket.tmp_key', self); end
      def alpn_protocol; Backend.call('tls_socket.alpn_protocol', self); end
      if Backend.call('tls.npn_available')
        def npn_protocol; Backend.call('tls_socket.npn_protocol', self); end
      end
      def export_keying_material(label, length, context = nil)
        Backend.call('tls_socket.export_keying_material', self, ::OpenSSL::PKey.string(label), Integer(length), context.nil? ? nil : ::OpenSSL::PKey.string(context))
      end
      if defined?(OpenSSL::OPENSSL_VERSION_NUMBER) && OpenSSL::OPENSSL_VERSION_NUMBER >= 0x30500000
        def sigalg; Backend.call('tls_socket.sigalg', self); end
        def peer_sigalg; Backend.call('tls_socket.peer_sigalg', self); end
      end
      if defined?(OpenSSL::OPENSSL_VERSION_NUMBER) && OpenSSL::OPENSSL_VERSION_NUMBER >= 0x30200000
        def group; Backend.call('tls_socket.group', self); end
      end
    end
    class SSLServer; end
  end
end
