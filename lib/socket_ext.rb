# frozen_string_literal: false
#
# socket, as mere-ruby answers `require "socket"`: BasicSocket, IPSocket,
# TCPSocket/Server, UDPSocket, UNIXSocket/Server, Socket, Addrinfo and
# Socket::Option / AncillaryData, written in Ruby over the interpreter's
# Socket.__* and IO.__fd* primitives (main.mere). Shipped through
# tools/gen_pathname_lib.rb (it lived as a string in m_eval_leaf.mere until
# 2026-11-09).
class SocketError < StandardError; end
class BasicSocket < IO
  # BasicSocket.do_not_reverse_lookup is ONE process-wide flag in CRuby, and a
  # socket copies it when it is made.
  @__dnrl = true
  def self.do_not_reverse_lookup
    BasicSocket.instance_variable_get(:@__dnrl)
  end
  def self.do_not_reverse_lookup=(v)
    BasicSocket.instance_variable_set(:@__dnrl, v ? true : false)
    v
  end
  # IO.open's contract: new, and with a block, yield and close
  def self.open(*args, **kw)
    s = kw.empty? ? new(*args) : new(*args, **kw)
    return s unless block_given?
    begin
      yield s
    ensure
      s.close unless s.closed?
    end
  end
  def self.for_fd(fd)
    # (rsock_init_sock asks fstat(2) first: a descriptor that is none is EBADF)
    raise Errno::EBADF, "fstat(2)" if IO.__fd_int(fd) < 0
    s = allocate
    # (the kernel's SO_TYPE: a datagram socket wrapped by for_fd is one)
    h = Socket.__getopt(IO.__fd_int(fd), Socket::SOL_SOCKET, Socket::SO_TYPE)
    ty = h.is_a?(String) && h.size >= 8 ? [h].pack("H*").unpack1("i") : nil
    ty ? s.__setup(fd, ty) : s.__setup(fd)
    s
  end
  # rsock_init_sock: a read-write stream, binary (ASCII-8BIT, binmode?), sync,
  # and non-blocking as every ruby 3 socket is -- the layer waits in its
  # readiness loop on a read that would block, so under the thread scheduler
  # the peer runs meanwhile. The class is registered with the layer so its
  # stream methods are routed there (fdio_route), and a subclass is too.
  def __setup(fd, socktype = Socket::SOCK_STREAM)
    # SIGPIPE ignored, as ruby has it, before the first socket can be written
    unless BasicSocket.instance_variable_get(:@__nosig)
      Socket.__nosigpipe
      BasicSocket.instance_variable_set(:@__nosig, true)
    end
    IO.__fdclass(self.class)
    __fd_setup(fd, IO::RDWR, true, Encoding::BINARY, nil, false)
    @__io_sync = true
    IO.__fdnonblock(fd)
    @socktype = socktype
    @do_not_reverse_lookup = BasicSocket.do_not_reverse_lookup
    self
  end
  # `connect` hands back a NEW descriptor (the runtime's connect makes its
  # own socket; see KNOWN_GAPS): the stream moves onto it
  def __move_to(fd)
    IO.__fdclose(@__io_fd)
    @__io_fd = fd
    IO.__fdnonblock(fd)
  end
  def do_not_reverse_lookup
    @do_not_reverse_lookup
  end
  def do_not_reverse_lookup=(v)
    @do_not_reverse_lookup = v ? true : false
  end
  # rb_io_s_new: an IO class's ::new takes no block, and says so
  def __new_block_warn
    warn("warning: #{self.class}::new() does not take block; use #{self.class}::open() instead")
  end
  def __check_open
    __fd_closed!
  end
  # a write the kernel refused on a socket, as the kernel named it (EPIPE,
  # ECONNRESET, ...); with no errno behind it, a peer that has gone
  def __fd_wfail(n = -1)
    IO.__fd_raise(n) if n < -1
    raise Errno::EPIPE
  end
  # read(2) on a listening socket is ENOTCONN; waiting for it to become
  # readable would wait for a connection instead
  def __fd_fill(want = 65536, timeout = @__io_timeout)
    raise Errno::ENOTCONN, "read(2)" if @listening
    super(want, timeout)
  end
  # poll(2) for this descriptor with no wait: is it readable (or at its
  # end), writable, now?
  def __ready?(bits)
    (IO.__poll([@__io_fd], [bits], 0)[0] & (bits == 1 ? 5 : 6)) != 0
  end
  # ONE DATAGRAM, as recv/recvfrom/recvmsg take it: [data, the sender as
  # the runtime writes it, the datagram's whole size] (the runtime's
  # recvfrom), or nil when nonblock and there is none (MSG_DONTWAIT)
  def __dgram_take(maxlen, flags, nonblock, what = "recvfrom(2)")
    __check_open
    fl = flags.nil? ? 0 : IO.__fd_cint(flags)
    fl |= Socket::MSG_DONTWAIT if nonblock
    maxlen = __fd_len!(IO.__fd_cint(maxlen))
    loop do
      __check_open
      # (one byte more than asked for tells a longer datagram -- recvfrom(2)
      #  on macOS answers what it copied, not the datagram's length)
      pk = Socket.__udp_packet(@__io_fd, maxlen + 1, fl)
      unless pk.is_a?(Integer)
        data, addr, n = pk
        return [data, addr, [n.to_i, data.bytesize].max] if data.bytesize <= maxlen
        return [data.byteslice(0, maxlen), addr, data.bytesize]
      end
      IO.__fd_raise(pk, what) unless IO.__again?(pk)
      return nil if nonblock
      __wait_readable
    end
  end
  private :__dgram_take
  # the sender of a datagram as an Addrinfo (nil when the runtime could not
  # name its family)
  def __dgram_ai(text, what)
    return nil if text.nil? || text.start_with?("other ")
    Socket::Endpoint__.addrinfo(text, what, @socktype || Socket::SOCK_DGRAM)
  end
  private :__dgram_ai
  def __would_block(what, exception)
    return :wait_readable unless exception
    raise IO::EAGAINWaitReadable, "#{what} would block"
  end
  private :__would_block
  # recvmsg(2): [message, sender Addrinfo, flags, *Socket::AncillaryData] --
  # MSG_TRUNC when the datagram was longer than asked for; with no length
  # given, the whole datagram (ruby grows its buffer to fit). The control
  # messages are Mere v0.1.724's sock_recvmsg; a descriptor that arrives with
  # SCM_RIGHTS is an IO when scm_rights: is true, and closed when it is not
  # (rsock_discard_cmsg_resource).
  def recvmsg(dlen = nil, flags = 0, clen = nil, scm_rights: false)
    __recvmsg(dlen, flags, clen, scm_rights, false, true)
  end
  def recvmsg_nonblock(dlen = nil, flags = 0, clen = nil, scm_rights: false, exception: true)
    __recvmsg(dlen, flags, clen, scm_rights, true, exception)
  end
  def __recvmsg(dlen, flags, clen, scm_rights, nonblock, exception)
    __check_open
    rb = @__io_rbuf
    # (a datagram socket whose peer is remembered here, or that holds a
    #  peeked datagram, is the datagram layer's; the rest is recvmsg(2))
    if (@socktype == Socket::SOCK_DGRAM && (@__dg_peer || @__dg_peek)) || (rb.is_a?(String) && !rb.empty?)
      return __recvmsg_plain(dlen, flags, nonblock, exception)
    end
    cap = dlen.nil? ? 65536 : IO.__fd_cint(dlen)
    fl = flags.nil? ? 0 : IO.__fd_cint(flags)
    ccap = clen.nil? ? 4096 : IO.__fd_cint(clen)
    if nonblock
      fl |= Socket::MSG_DONTWAIT
    else
      IO.select([self])
    end
    r = Socket.__recvmsg(@__io_fd, cap, fl, ccap)
    if r.is_a?(Integer)
      if IO.__again?(r)
        return :wait_readable unless exception
        raise IO::EAGAINWaitReadable, "recvmsg(2) would block"
      end
      raise SystemCallError.new("recvmsg(2)", -r)
    end
    head, data, ctls = r
    count, rflags, addr = head.split(" ", 3)
    # (the end of a stream -- the peer's orderly shutdown -- is nil)
    return nil if count == "0" && ctls.empty? && (@socktype.nil? || @socktype == Socket::SOCK_STREAM)
    fam = __opt_family
    # (no address from the kernel -- a connected stream -- is ruby's
    #  empty-sockaddr Addrinfo, AF_UNSPEC, of the socket's type)
    sender = addr.start_with?("none ") || addr.start_with?("other ") ?
      Addrinfo.allocate.__init("", 0, @socktype || Socket::SOCK_STREAM, 0, nil, nil) :
      Socket::Endpoint__.addrinfo(addr, "recvmsg(2)", @socktype || Socket::SOCK_STREAM)
    anc = ctls.map do |line|
      lv, ty, hex = line.split(" ", 3)
      a = Socket::AncillaryData.__new(fam, lv.to_i, ty.to_i, [hex.to_s].pack("H*"))
      if lv.to_i == Socket::SOL_SOCKET && ty.to_i == Socket::SCM_RIGHTS
        fds = a.data.unpack("i*")
        if scm_rights == true
          a.instance_variable_set(:@unix_rights, fds.map { |fd| IO.for_fd(fd) })
        elsif scm_rights != :keep
          fds.each { |fd| IO.__fdclose(fd) }
        end
      end
      a
    end
    [data, sender, rflags.to_i, *anc]
  end
  private :__recvmsg
  def __recvmsg_plain(dlen, flags, nonblock, exception)
    if @socktype == Socket::SOCK_DGRAM
      cap = dlen.nil? ? 65536 : IO.__fd_cint(dlen)
      pk = __dgram_take(cap, flags, nonblock, "recvmsg(2)")
      return __would_block("recvmsg(2)", exception) if pk.nil?
      data, addr, size = pk
      rflags = size && size > cap ? Socket::MSG_TRUNC : 0
      # (macOS hands MSG_DONTWAIT back in msg_flags for a non-blocking one)
      rflags |= Socket::MSG_DONTWAIT if nonblock && RUBY_PLATFORM.include?("darwin")
      return [data, __dgram_ai(addr, "recvmsg(2)"), rflags]
    end
    len = dlen.nil? ? 65536 : dlen
    data = nonblock ? recv_nonblock(len, flags, exception: exception) : recv(len, flags)
    return data if data == :wait_readable
    [data, (remote_address rescue nil), 0]
  end
  private :__recvmsg_plain
  # sendmsg(2) (Mere v0.1.724's sock_sendmsg) with control messages: each a
  # Socket::AncillaryData or [level, type, data]. A destination with control
  # data is not implemented (the runtime's sendmsg takes a connected socket);
  # without control data it is send(2) / sendto(2).
  def sendmsg(mesg, flags = 0, dest = nil, *controls)
    __sendmsg(mesg, flags, dest, controls, false, true)
  end
  def sendmsg_nonblock(mesg, flags = 0, dest = nil, *controls, exception: true)
    __sendmsg(mesg, flags, dest, controls, true, exception)
  end
  def __sendmsg(mesg, flags, dest, controls, nonblock, exception)
    fl = (flags.nil? ? 0 : IO.__fd_cint(flags))
    fl |= Socket::MSG_DONTWAIT if nonblock
    if controls.empty?
      begin
        return dest.nil? ? send(mesg, fl) : send(mesg, fl, dest)
      rescue Errno::EAGAIN
        raise unless nonblock
        return :wait_writable unless exception
        raise IO::EAGAINWaitWritable, "sendmsg(2) would block"
      end
    end
    raise NotImplementedError, "sendmsg(2) to a destination with ancillary data is not implemented" unless dest.nil?
    __check_open
    ctl = controls.map do |c|
      if c.is_a?(Socket::AncillaryData)
        lv, ty, data = c.level, c.type, c.data
      else
        c = c.to_ary
        raise ArgumentError, "unexpected ancillary data size" unless c.size == 3
        fam = __opt_family
        lv = Socket::Constants.__level_arg(fam, c[0])
        ty = Socket::Constants.__cmsg_type_arg(fam, lv, c[1])
        data = c[2].to_str
      end
      "#{lv} #{ty} #{data.unpack1('H*')}"
    end.join("\n")
    flush if respond_to?(:flush)
    r = Socket.__sendmsg(@__io_fd, IO.__fd_str(mesg).b, fl, ctl)
    if r < 0
      if nonblock && IO.__again?(r)
        return :wait_writable unless exception
        raise IO::EAGAINWaitWritable, "sendmsg(2) would block"
      end
      raise SystemCallError.new("sendmsg(2)", -r)
    end
    r
  end
  private :__sendmsg
  def recvfrom_nonblock(maxlen, flags = 0, outbuf = nil, exception: true)
    if @socktype == Socket::SOCK_DGRAM
      pk = __dgram_take(maxlen, flags, true)
      return __would_block("recvfrom(2)", exception) if pk.nil?
      data = outbuf ? __fd_into(__fd_buf!(outbuf), pk[0]) : pk[0]
      return [data, __dgram_ai(pk[1], "recvfrom(2)")]
    end
    data = recv_nonblock(maxlen, flags, outbuf, exception: exception)
    return data if data == :wait_readable || data.nil?
    [data, (remote_address rescue nil)]
  end
  def recv_nonblock(maxlen, flags = 0, buf = nil, exception: true)
    if @socktype == Socket::SOCK_DGRAM
      pk = __dgram_take(maxlen, flags, true)
      return __would_block("recvfrom(2)", exception) if pk.nil?
      return buf ? __fd_into(__fd_buf!(buf), pk[0]) : pk[0]
    end
    __fd_reading!
    if @__io_rbuf.empty?
      s = IO.__fdread(@__io_fd, 65536)
      return nil if s.nil?
      unless s.is_a?(String)
        IO.__fd_raise(s, "recvfrom(2)") unless IO.__again?(s)
        return :wait_readable unless exception
        raise IO::EAGAINWaitReadable, "recvfrom(2) would block"
      end
      @__io_rbuf << s
    end
    recv(maxlen, flags, buf)
  end
  # setsockopt(2) takes a pointer, which nothing here can pass; the options
  # are accepted and not applied, as before -- but they are READ as
  # bsock_setsockopt reads them (a Socket::Option, or level, name and a
  # value that is an Integer, a boolean or a String), so what ruby refuses
  # is refused here too.
  def setsockopt(*args)
    if args.size == 1
      opt = args[0]
      lev, name, val = opt.level, opt.optname, opt.data
    elsif args.size == 3
      lev, name, val = args
    else
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 3)"
    end
    __check_open
    fam = __opt_family
    level = Socket::Constants.__level_arg(fam, lev)
    option = Socket::Constants.__optname_arg(fam, level, name)
    data = case val
           when Integer
             raise RangeError, "integer #{val} too #{val < 0 ? 'small' : 'big'} to convert to 'int'" unless (-2**31...2**31).cover?(val)
             [val].pack("i")
           when true then [1].pack("i")
           when false then [0].pack("i")
           else IO.__fd_str(val)
           end
    __check_open
    r = Socket.__setopt(@__io_fd, level, option, data.unpack1("H*"))
    raise SystemCallError.new("setsockopt(2)", -r) if r < 0
    0
  end
  # getsockopt(2) (Mere v0.1.678): up to 256 bytes, as a Socket::Option of
  # this socket's family
  def getsockopt(lev, optname)
    __check_open
    fam = __opt_family
    level = Socket::Constants.__level_arg(fam, lev)
    option = Socket::Constants.__optname_arg(fam, level, optname)
    # (checked again: converting the arguments may have closed it)
    __check_open
    h = Socket.__getopt(@__io_fd, level, option)
    raise SystemCallError.new("getsockopt(2)", -h) if h.is_a?(Integer)
    Socket::Option.__new(fam, level, option, [h].pack("H*"))
  end
  # getpeereid(3): the peer's effective uid and gid (Mere v0.1.724's
  # sock_peer_ids: getpeereid, SO_PEERCRED on Linux)
  def getpeereid
    __check_open
    r = Socket.__peer_ids(@__io_fd)
    raise SystemCallError.new("getpeereid(3)", -r) if r.is_a?(Integer)
    r
  end
  # rsock_getfamily: the family of the socket's own address
  def __opt_family
    return @family if @family
    t = Socket.__sockname(@__io_fd)
    return Socket::AF_INET unless t.is_a?(String)
    case t[/\A\S+/]
    when "inet6" then Socket::AF_INET6
    when "unix" then Socket::AF_UNIX
    when "inet" then Socket::AF_INET
    else Socket::AF_UNSPEC
    end
  end
  # accept(2) waits for readability first, through IO's readiness loop, so
  # that under the thread scheduler the other threads run while this one
  # waits -- one of them may be the peer.
  def __wait_readable
    __fd_read_wait(@__io_fd)
  end
  # recv(2) on a stream: what has arrived, up to maxlen, and nil at end of
  # stream. MSG_PEEK leaves it in the buffer for the next read.
  # A DATAGRAM is one recv(2) and one send(2), never the stream buffer: an
  # empty one is a message (""), not an end of file, and an empty write
  # through the buffer would send nothing at all -- a peer waiting for it
  # would wait for ever (socket/recvfrom_spec did, once bind(2) was real).
  # MSG_PEEK keeps the whole datagram for the next recv, which is what the
  # kernel would have kept; a read without it takes the datagram and drops
  # whatever did not fit in maxlen, as recv(2) does.
  def recv(maxlen, flags = 0, outbuf = nil)
    if @socktype == Socket::SOCK_DGRAM && @__io_rbuf.empty?
      __check_open
      # Use the errno-preserving packet path, just like recvfrom/recvmsg.
      # Connected UDP reports ICMP errors here (notably ECONNREFUSED on Linux).
      # Buffering a packet separately would also discard recv flags.
      d, = __dgram_take(maxlen, flags, false, "recvfrom(2)")
      return outbuf ? __fd_into(outbuf, d) : d
    end
    __fd_reading!
    __fd_fill if @__io_rbuf.empty?
    # a stream at its end answers nil, not "" (rsock_s_recvfrom)
    return nil if @__io_rbuf.empty? && maxlen > 0
    out = @__io_rbuf.byteslice(0, maxlen) || "".b
    __fd_take(out.bytesize) if (flags.to_i & Socket::MSG_PEEK) == 0
    # a buffer given is filled and keeps its own encoding
    outbuf ? __fd_into(outbuf, out) : out
  end
  def send(data, flags = 0, *dest)
    # with flags (MSG_OOB) it is send(2) itself, after what is buffered
    if dest.empty? && flags.to_i != 0 && @socktype != Socket::SOCK_DGRAM
      __check_open
      flush
      n = Socket.__send_flag(@__io_fd, data.to_s, flags.to_i)
      IO.__fd_raise(n) if n < 0
      return n
    end
    if @socktype == Socket::SOCK_DGRAM
      __check_open
      unless dest.empty?
        # sendto(2): to the address given (an Addrinfo or a packed sockaddr)
        raise ArgumentError, "wrong number of arguments (given #{dest.size + 2}, expected 2..3)" if dest.size > 1
        ai = dest[0].is_a?(Addrinfo) ? dest[0] : Addrinfo.new(IO.__fd_str(dest[0]))
        loop do
          __check_open
          n = Socket.__udp_sendto(@__io_fd, IO.__fd_str(data), flags.to_i, ai.ip_address, ai.ip_port)
          Addrinfo.__gai_error("sendto(2)", 8) if n.nil?
          return n if n >= 0
          IO.__fd_raise(n, "sendto(2)") unless IO.__again?(n) && (flags.to_i & Socket::MSG_DONTWAIT) == 0
          IO.__sel_wait([[@__io_fd, 2, self]], -1)
        end
      end
      data = IO.__fd_str(data)
      flags = IO.__fd_cint(flags)
      loop do
        __check_open
        n = Socket.__udp_sendto(@__io_fd, data, flags, nil, 0)
        return n if n >= 0
        IO.__fd_raise(n, "send(2)") unless IO.__again?(n) && (flags & Socket::MSG_DONTWAIT) == 0
        IO.__sel_wait([[@__io_fd, 2, self]], -1)
      end
    end
    write(data)
  end
  # Inherit IO#timeout=: readiness waits use its per-stream value.
  def shutdown(how = Socket::SHUT_RDWR)
    __check_open
    h = how.is_a?(Integer) ? how : Socket::Constants.__name_to_int(how, /\ASHUT_/, /\ASHUT_/, "unknown shutdown argument")
    raise ArgumentError, "`how' should be either :SHUT_RD, :SHUT_WR, :SHUT_RDWR" unless (0..2).include?(h)
    if Socket.__shutdown(@__io_fd, h) < 0
      raise Errno::ENOTCONN, "shutdown(2)"
    end
    0
  end
  # rb_io_close_read / rb_io_close_write on a socket: shutdown(2) of that
  # half, and closing the second half closes the socket.
  def close_read
    __check_open
    Socket.__shutdown(@__io_fd, Socket::SHUT_RD)
    @__io_r = false
    return close unless @__io_w
    nil
  end
  def close_write
    __check_open
    __fd_flush_w if @__io_w
    Socket.__shutdown(@__io_fd, Socket::SHUT_WR)
    @__io_w = false
    return close unless @__io_r
    nil
  end
  # The kernel's own answer to getsockname(2) / getpeername(2) (compiler
  # v0.1.555 asks it; it was read from lsof(8) or /proc before).
  def local_address
    __check_open
    Socket::Endpoint__.addrinfo(Socket.__sockname(@__io_fd), "getsockname(2)", @socktype)
  end
  def remote_address
    __check_open
    Socket::Endpoint__.addrinfo(Socket.__peername(@__io_fd), "getpeername(2)", @socktype)
  end
  # Connect the existing datagram descriptor in the kernel so its bound port,
  # receive filtering and asynchronous error reporting stay intact.
  def __dgram_bound?
    return false unless @socktype == Socket::SOCK_DGRAM
    t = Socket.__sockname(@__io_fd)
    return false unless t.is_a?(String)
    _, port, = t.split(" ", 3)
    port.to_i != 0
  end
  private :__dgram_bound?
  def __dgram_peer!(ai)
    __check_open
    result = Socket.__udp_connect(@__io_fd, ai.ip_address, ai.ip_port)
    IO.__fd_raise(result, "connect(2)") if result < 0
    0
  end
  private :__dgram_peer!
  def getsockname
    local_address.to_sockaddr
  end
  def getpeername
    remote_address.to_sockaddr
  end
  def connect_address
    addr = local_address
    afamily = addr.afamily
    if afamily == Socket::AF_INET
      raise SocketError, "unbound IPv4 socket" if addr.ip_port == 0
      if addr.ip_address == "0.0.0.0"
        addr = Addrinfo.new(["AF_INET", addr.ip_port, nil, "127.0.0.1"], addr.pfamily, addr.socktype, addr.protocol)
      end
    elsif afamily == Socket::AF_INET6
      raise SocketError, "unbound IPv6 socket" if addr.ip_port == 0
      if addr.ip_address == "::" || addr.ip_address == "0.0.0.0" || addr.ip_address == "::ffff:0.0.0.0"
        addr = Addrinfo.new(["AF_INET6", addr.ip_port, nil, "::1"], addr.pfamily, addr.socktype, addr.protocol)
      end
    elsif afamily == Socket::AF_UNIX
      raise SocketError, "unbound Unix socket" if addr.unix_path == ""
    end
    addr
  end
end

class IPSocket < BasicSocket
  # ruby undefines it here (rsock_init_ipsocket): an IP socket has no peer
  # credentials to ask about
  undef_method :getpeereid
  def self.getaddress(host)
    Addrinfo.__getaddrinfo(host, nil, 0, 0, 0, 0, false)[0].ip_address
  end
  def __reverse?(arg)
    case arg
    when nil then !@do_not_reverse_lookup
    when true, :hostname then true
    when false, :numeric then false
    else raise ArgumentError, "invalid reverse_lookup flag: #{arg.inspect}"
    end
  end
  def __ipaddr(ai, reverse)
    host = reverse ? Addrinfo.__reverse_name(ai) : ai.ip_address
    [ai.ipv6? ? "AF_INET6" : "AF_INET", ai.ip_port, host, ai.ip_address]
  end
  def addr(reverse_lookup = nil)
    rev = __reverse?(reverse_lookup)
    __ipaddr(local_address, rev)
  end
  def peeraddr(reverse_lookup = nil)
    rev = __reverse?(reverse_lookup)
    __ipaddr(remote_address, rev)
  end
  def recvfrom(maxlen, flags = 0)
    data = recv(maxlen, flags)
    return nil if data.nil?
    [data, peeraddr]
  end
  def inspect
    return IO.__fdanystr(self) if @__io_fd.nil?
    return "#<#{self.class}:(closed)>" if closed?
    a = local_address
    "#<#{self.class}:fd #{@__io_fd}, #{a.ipv6? ? 'AF_INET6' : 'AF_INET'}, #{a.ip_address}, #{a.ip_port}>"
  end
end

class TCPSocket < IPSocket
  def recvfrom(maxlen, flags = 0)
    data = recv(maxlen, flags)
    data.nil? ? nil : [data, nil]
  end
  def self.gethostbyname(host)
    list = Addrinfo.__getaddrinfo(host, nil, 0, Socket::SOCK_STREAM, 0, Socket::AI_CANONNAME, false)
    names = [list[0].canonname || host, []]
    fam = list[0].afamily
    [names[0], [], fam, *list.map(&:ip_address)]
  end
  # getaddrinfo(3)'s answers are tried IN TURN, as ruby's connect does
  # (fast_fallback only races them): "localhost" is ::1 and then 127.0.0.1,
  # and a server on 127.0.0.1 is reached on the second. A name only DNS
  # knows (the files half has no answer for it) is left to the runtime's
  # own resolver, which tries its first address. (The port is asked too: a
  # nil host is the loopback addresses, but only when there is a service.)
  def self.__connect_any(host, port)
    addrs = begin
      Addrinfo.__getaddrinfo(host, port, 0, Socket::SOCK_STREAM, 0, 0, false).map(&:ip_address).uniq
    rescue SocketError
      [host.to_s]
    end
    addrs.each do |a|
      fd = Socket.__connect(a, port)
      return fd if fd >= 0
    end
    -1
  end
  # Resolution workers never run Ruby. This loop owns their lifetime and yields
  # while DNS or connect(2) is pending, including during timeout cleanup.
  def self.__connect_with_deadlines(host, port, local_host, local_port, connect_timeout, open_timeout, resolv_timeout, fast_fallback, settings)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    jobs = {}
    ready = {6 => [], 4 => []}
    active = []
    last_error = nil
    resolution_error = nil
    resolution_timeout_error = nil
    first_v4 = nil
    next_attempt = start
    last_family = 4
    local = local_host.nil? ? '' : Addrinfo.__getaddrinfo(local_host, nil, 0, 0, 0, 0, false)[0].ip_address
    families = host.include?(':') ? [6] : (host.match?(/\A[0-9.]+\z/) ? [4] : [6, 4])
    settings = {} unless settings.is_a?(Hash)
    delays = settings[:delay] || {}
    errors = settings[:error] || {}
    families.each do |family|
      key = family == 6 ? :ipv6 : :ipv4
      job = Socket.__resolve_start(host, port, family, Integer(delays[key] || 0), Integer(errors[key] || 0))
      raise SystemCallError.new('getaddrinfo worker', -job) if job < 0
      jobs[family] = job
    end
    loop do
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise IO::TimeoutError, 'user specified open timeout' if open_timeout && now - start >= open_timeout
      jobs.keys.each do |family|
        job = jobs[family]
        next if Socket.__resolve_done(job) == 0
        error = Socket.__resolve_error(job)
        if error != 0
          resolution_error = Socket::ResolutionError.new('getaddrinfo failed')
        else
          index = 0
          loop do
            address = Socket.__resolve_address(job, index)
            break if address.empty?
            ready[family] << address unless ready[family].include?(address)
            index += 1
          end
          first_v4 ||= now if family == 4
        end
        Socket.__resolve_release(job)
        jobs.delete(family)
      end
      active.dup.each do |entry|
        fd, since = entry
        if (IO.__poll([fd], [2], 0)[0] & 6) != 0
          error = Socket.__connect_error(fd)
          active.delete(entry)
          return fd if error == 0
          IO.__fdclose(fd)
          last_error = SystemCallError.new("connect(2) for #{host.inspect} port #{port}", error)
          next_attempt = now
        elsif connect_timeout && now - since >= connect_timeout
          active.delete(entry)
          IO.__fdclose(fd)
          last_error = IO::TimeoutError.new('user specified connect timeout')
          next_attempt = now
        end
      end
      if resolv_timeout && !jobs.empty? && now - start >= resolv_timeout
        jobs.each_value { |job| Socket.__resolve_release(job) }
        jobs.clear
        resolution_timeout_error = IO::TimeoutError.new('user specified resolution timeout')
        # Resolved addresses and active attempts can still connect. Removing
        # the pending jobs also ends the IPv6 preference wait.
      end
      if now >= next_attempt && (fast_fallback || active.empty?)
        family = last_family == 6 ? 4 : 6
        family = 10 - family if ready[family].empty?
        wait_v6 = family == 4 && jobs.key?(6) && first_v4 && now - first_v4 < 0.05
        unless ready[family].empty? || wait_v6
          address = ready[family].shift
          last_family = family
          fd = Socket.__connect_start(address, port, local, local_port || 0)
          if fd < 0
            context = local_host || local_port ? "bind/connect(2) for #{local_host.inspect} port #{local_port}" : "connect(2) for #{host.inspect} port #{port}"
            last_error = SystemCallError.new(context, -fd)
            next_attempt = now
          else
            active << [fd, now]
            next_attempt = now + 0.25
          end
          next
        end
      end
      if jobs.empty? && active.empty? && ready[4].empty? && ready[6].empty?
        raise(resolution_timeout_error || last_error || resolution_error || Socket::ResolutionError.new('getaddrinfo returned no addresses'))
      end
      sleep 0.001
    end
  ensure
    jobs&.each_value { |job| Socket.__resolve_release(job) }
    active&.each { |entry| IO.__fdclose(entry[0]) }
  end
  def initialize(host, port, local_host = nil, local_port = nil, connect_timeout: nil, open_timeout: nil, resolv_timeout: nil, fast_fallback: true, test_mode_settings: nil)
    __new_block_warn if block_given?
    if open_timeout && (connect_timeout || resolv_timeout)
      raise ArgumentError, 'open_timeout cannot be combined with connect_timeout or resolv_timeout'
    end
    raise Socket::ResolutionError, 'getaddrinfo: no service specified' if port.nil?
    @host = host
    @port = port
    [open_timeout, connect_timeout, resolv_timeout].each do |timeout|
      raise IO::TimeoutError, 'user specified timeout' if timeout && timeout <= 0
    end
    host = host.nil? ? '' : host.to_str
    fd = TCPSocket.__connect_with_deadlines(host, Addrinfo.__port_of(port, 'tcp'), local_host, local_port && Addrinfo.__port_of(local_port, 'tcp'), connect_timeout, open_timeout, resolv_timeout, fast_fallback, test_mode_settings)
    __setup(fd)
  end
end

class TCPServer < TCPSocket
  # init_inetsock_internal for a server: getaddrinfo(host, port, AI_PASSIVE)
  # and each answer in turn gets socket(2), SO_REUSEADDR and bind(2) -- the
  # first that binds is the listener, and when none does the error is the
  # last one's. That loop is the runtime's tcp_listen_at (compiler v0.1.555),
  # because bind(2) takes a sockaddr; see Endpoint__.listen_at for the host.
  # tcp_svr_init: ONE argument is the port; with two, a nil port is the
  # kernel's choice (the arity says which, not the nil)
  def initialize(*args)
    __new_block_warn if block_given?
    unless args.size == 1 || args.size == 2
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1..2)"
    end
    host, port = args.size == 1 ? [nil, args[0]] : args
    portnum = Addrinfo.__port_of(port, "tcp")
    fd = Socket::Endpoint__.listen_at(host, port, portnum, Socket::SOMAXCONN)
    __setup(fd)
    @listening = true
  end
  def accept
    __check_open
    __wait_readable
    fd = Socket.__accept(@__io_fd)
    raise SocketError, "accept failed" if fd < 0
    TCPSocket.for_fd(fd)
  end
  def accept_nonblock(exception: true)
    __check_open
    unless __ready?(1)
      return :wait_readable unless exception
      raise IO::EAGAINWaitReadable, "accept(2) would block"
    end
    accept
  end
  def sysaccept
    __check_open
    __wait_readable
    fd = Socket.__accept(@__io_fd)
    raise SocketError, "accept failed" if fd < 0
    fd
  end
  # listen(2) again on a listening socket changes its backlog; the backlog
  # is converted as NUM2INT converts it
  def listen(backlog)
    backlog = Socket::Constants.__int(backlog)
    __check_open
    raise Errno::EINVAL, "listen(2)" if Socket.__listenfd(@__io_fd, backlog) < 0
    0
  end
end

class UDPSocket < IPSocket
  def initialize(family = Socket::AF_INET)
    __new_block_warn if block_given?
    fam = Socket::Constants.__family_arg(family)
    fd = Socket.__socket(Socket::Endpoint__.kernel_family(fam), Socket::SOCK_DGRAM, 0)
    raise Errno::EAFNOSUPPORT, "socket(2) - udp" if fd < 0
    @family = fam
    __setup(fd, Socket::SOCK_DGRAM)
  end
  # udp_bind: the host resolved in the socket's own family, AI_PASSIVE, and
  # the first answer bound (bind(2) itself is the runtime's sock_bind)
  def bind(host, port)
    # (the host as a C string first -- #to_str, which may close the socket
    #  -- then the open check: ruby's order)
    h = host.nil? ? nil : Addrinfo.__host_str(host)
    __check_open
    h = "0.0.0.0" if h == ""
    ai = Addrinfo.__getaddrinfo(h, Addrinfo.__port_of(port, "udp"), @family, Socket::SOCK_DGRAM, 0, Socket::AI_PASSIVE, false)[0]
    r = Socket.__bind(@__io_fd, ai.ip_address, ai.ip_port)
    raise SystemCallError.new("bind(2) for #{host.inspect} port #{port}", -r) if r.is_a?(Integer) && r < 0
    0
  end
  def connect(host, port)
    h = Addrinfo.__host_str(host).to_s
    __check_open
    if __dgram_bound?
      ai = Addrinfo.__getaddrinfo(h, Addrinfo.__port_of(port, "udp"), @family, Socket::SOCK_DGRAM, 0, 0, false)[0]
      return __dgram_peer!(ai)
    end
    # connect(2) on this descriptor (Mere v0.1.724's sock_connect): the
    # socket keeps its family -- udp_open made one of its own, so an AF_INET
    # UDPSocket connected to "localhost" became an IPv6 one. No host is the
    # loopback address (getaddrinfo(NULL) without AI_PASSIVE).
    h = @family == Socket::AF_INET6 ? "::1" : "127.0.0.1" if h.empty?
    ai = Addrinfo.__getaddrinfo(h, Addrinfo.__port_of(port, "udp"), @family, Socket::SOCK_DGRAM, 0, 0, false)[0]
    r = Socket.__sock_connect(@__io_fd, ai.ip_address, ai.ip_port)
    raise SystemCallError.new("connect(2) for #{ai.inspect_sockaddr}", -r) if r.is_a?(Integer) && r < 0
    raise Errno::EAFNOSUPPORT, "connect(2) for #{ai.inspect_sockaddr}" if r.nil?
    0
  end
  def send(mesg, flags, *dest)
    raise ArgumentError, "wrong number of arguments" if dest.length > 2
    __check_open
    mesg = IO.__fd_str(mesg)
    flags = IO.__fd_cint(flags)
    if dest.length == 2
      ai = Addrinfo.__getaddrinfo(dest[0], Addrinfo.__port_of(dest[1], "udp"), @family, Socket::SOCK_DGRAM, 0, 0, false)[0]
    elsif dest.length == 1
      ai = dest[0].is_a?(Addrinfo) ? dest[0] : Addrinfo.new(IO.__fd_str(dest[0]))
    end
    host = ai ? ai.ip_address : nil
    port = ai ? ai.ip_port : 0
    loop do
      __check_open
      begin
        n = Socket.__udp_sendto(@__io_fd, mesg, flags, host, port)
      rescue Errno::EMSGSIZE
        # (named by the host and port it was given, rsock_syserr_fail_host_port)
        raise Errno::EMSGSIZE, "sendto(2) for #{dest[0].to_s.inspect} port #{dest[1]}" if dest.length == 2
        raise
      end
      Addrinfo.__gai_error("sendto(2)", 8) if n.nil?
      return n if n >= 0
      IO.__fd_raise(n, "sendto(2)") unless IO.__again?(n)
      IO.__sel_wait([[@__io_fd, 2, self]], -1)
    end
  end
  def write(mesg)
    send(mesg, 0)
  end
  def __udp_packet(maxlen, flags)
    __check_open
    flags = flags.nil? ? 0 : IO.__fd_cint(flags)
    maxlen = __fd_len!(IO.__fd_cint(maxlen))
    raise IOError, "recv for buffered IO" unless @__io_rbuf.empty?
    loop do
      __check_open
      packet = Socket.__udp_packet(@__io_fd, maxlen, flags)
      return packet unless packet.is_a?(Integer)
      IO.__fd_raise(packet, "recvfrom(2)") unless IO.__again?(packet)
      __wait_readable
    end
  end
  private :__udp_packet
  def recv(maxlen, flags = 0, outbuf = nil)
    outbuf = __fd_buf!(outbuf)
    data, _ = __udp_packet(maxlen, flags)
    outbuf ? __fd_into(outbuf, data) : data
  end
  def recvfrom(maxlen, flags = 0, outbuf = nil)
    outbuf = __fd_buf!(outbuf)
    data, address = __udp_packet(maxlen, flags)
    data = __fd_into(outbuf, data) if outbuf
    return [data, nil] if address.start_with?("other ")
    ai = Socket::Endpoint__.addrinfo(address, "recvfrom(2)", Socket::SOCK_DGRAM)
    [data, __ipaddr(ai, !@do_not_reverse_lookup)]
  end
  def recvfrom_nonblock(maxlen, flags = 0, outbuf = nil, exception: true)
    pk = __dgram_take(maxlen, flags, true)
    return __would_block("recvfrom(2)", exception) if pk.nil?
    data, address = pk
    data = __fd_into(__fd_buf!(outbuf), data) if outbuf
    return [data, nil] if address.start_with?("other ")
    ai = Socket::Endpoint__.addrinfo(address, "recvfrom(2)", Socket::SOCK_DGRAM)
    [data, __ipaddr(ai, !@do_not_reverse_lookup)]
  end
end

class UNIXSocket < BasicSocket
  # sun_path's size, which a path must fit (rsock_init_unixsock)
  def self.__sun_path_max
    RUBY_PLATFORM.include?("darwin") ? 104 : 108
  end
  # unixsock_path_value: #to_path, then a String
  def self.__path_value(path)
    path = path.to_path if !path.is_a?(String) && path.respond_to?(:to_path)
    unless path.is_a?(String)
      raise TypeError, "no implicit conversion of #{path.nil? ? 'nil' : path.class} into String" unless path.respond_to?(:to_str)
      path = path.to_str
    end
    raise ArgumentError, "path name contains null byte" if path.include?("\0")
    path
  end
  # rsock_init_unixsock: a stream socket, connected to the path (or, for a
  # server, bound to it and listening). Either refusal is reported as
  # connect(2), as ruby reports it.
  def __unix_init(path, server)
    path = UNIXSocket.__path_value(path)
    max = UNIXSocket.__sun_path_max
    if path.bytesize > max
      raise ArgumentError, "too long unix socket path (#{path.bytesize}bytes given but #{max}bytes max)"
    end
    fd = Socket.__socket(Socket::AF_UNIX, Socket::SOCK_STREAM, 0)
    raise SystemCallError.new("socket(2) for #{path}", Errno::EMFILE::Errno) if fd < 0
    __setup(fd)
    r = server ? Socket.__unix_bind(fd, path) : Socket.__unix_connect(fd, path)
    if r < 0
      close
      raise SystemCallError.new("connect(2) for #{path}", -r)
    end
    if server
      if Socket.__listenfd(fd, Socket::SOMAXCONN) < 0
        close
        raise SystemCallError.new("listen(2) for #{path}", Errno::EINVAL::Errno)
      end
      @listening = true
      @__unix_path = path.dup.freeze
    end
  end
  def initialize(path)
    __new_block_warn if block_given?
    __unix_init(path, false)
  end
  # a descriptor sent with SCM_RIGHTS beside one NUL byte, as ruby's
  # unix_send_io does (an IO, or an Integer descriptor)
  def send_io(io)
    fd = io.is_a?(Integer) ? io : (io.respond_to?(:to_io) ? io.to_io.fileno : nil)
    raise TypeError, "neither IO nor file descriptor" if fd.nil?
    sendmsg("\0", 0, nil, [Socket::SOL_SOCKET, Socket::SCM_RIGHTS, [fd].pack("i")])
    nil
  end
  # ...and the one received: klass.for_fd(fd[, mode]), the bare descriptor
  # when klass is nil (unix_recv_io)
  def recv_io(klass = IO, mode = nil)
    # (:keep: the descriptors stay open and stay Integers)
    _, _, _, *ctls = __recvmsg(1, 0, nil, :keep, false, true)
    fds = nil
    ctls.each do |c|
      next unless c.level == Socket::SOL_SOCKET && c.type == Socket::SCM_RIGHTS
      fds = c.data.unpack("i*")
    end
    raise SocketError, "file descriptor was not passed" if fds.nil? || fds.empty?
    fd = fds[0]
    return fd if klass.nil?
    mode.nil? ? klass.for_fd(fd) : klass.for_fd(fd, mode)
  end
  # the path this end has: a server's own, else what getsockname(2) says
  def path
    __check_open
    @__unix_path ||= __unix_path_of(Socket.__sockname(@__io_fd)).freeze
    @__unix_path.dup
  end
  def __unix_path_of(text)
    return "" unless text.is_a?(String) && text.start_with?("unix ")
    text.sub(/\Aunix 0 ?/, "")
  end
  def addr
    __check_open
    ["AF_UNIX", __unix_path_of(Socket.__sockname(@__io_fd))]
  end
  def peeraddr
    __check_open
    t = Socket.__peername(@__io_fd)
    IO.__fd_raise(t, "getpeername(2)") if t.is_a?(Integer)
    ["AF_UNIX", __unix_path_of(t)]
  end
  def recvfrom(maxlen, flags = 0, outbuf = nil)
    data = recv(maxlen, flags, outbuf)
    [data, ["AF_UNIX", ""]]
  end
  def inspect
    # (one that never got a descriptor -- a refused new -- is an object's)
    return Kernel.instance_method(:to_s).bind_call(self) unless @__io_fd
    return "#<#{self.class}:(closed)>" if closed?
    return "#<#{self.class}:#{@__unix_path}>" if @__unix_path
    "#<#{self.class}:fd #{@__io_fd}>"
  end
  # socketpair(2): two connected UNIXSockets (type :STREAM / :DGRAM /
  # :SEQPACKET, or Socket::SOCK_*)
  def self.pair(type = Socket::SOCK_STREAM, protocol = 0)
    t = type.is_a?(Symbol) || type.is_a?(String) ? Socket.const_get("SOCK_" + type.to_s.sub(/\ASOCK_/, "")) : type
    kind = t == Socket::SOCK_DGRAM ? 2 : (t == Socket::SOCK_SEQPACKET ? 5 : (t == Socket::SOCK_STREAM ? 1 : 0))
    r = Socket.__sockpair(kind)
    raise SystemCallError.new("socketpair(2)", -r) if r.is_a?(Integer)
    pair = r.map { |fd| s = allocate; s.__setup(fd, t); s }
    # (with a block: the pair is yielded and closed after, the block's value
    #  answered -- rsock_sock_s_socketpair)
    return pair unless block_given?
    begin
      yield(*pair)
    ensure
      pair.each { |x| x.close unless x.closed? }
    end
  end
  class << self
    alias socketpair pair
  end
end
class UNIXServer < UNIXSocket
  def initialize(path)
    __new_block_warn if block_given?
    __unix_init(path, true)
  end
  def __accept_fd
    __check_open
    __wait_readable
    fd = Socket.__accept(@__io_fd)
    IO.__fd_raise(-Errno::EINVAL::Errno, "accept(2)") if fd < 0
    fd
  end
  def __unix_client(fd)
    s = UNIXSocket.allocate
    s.__setup(fd)
    s
  end
  def accept
    __unix_client(__accept_fd)
  end
  def accept_nonblock(exception: true)
    __check_open
    unless __ready?(1)
      return :wait_readable unless exception
      raise IO::EAGAINWaitReadable, "accept(2) would block"
    end
    accept
  end
  def sysaccept
    __accept_fd
  end
  def listen(backlog)
    __check_open
    raise Errno::EOPNOTSUPP, "listen(2)" if Socket.__listenfd(@__io_fd, Socket::Constants.__int(backlog)) < 0
    0
  end
end

class Socket < BasicSocket
  def self.ip_address_list
    Socket.__ip_addresses.split.map { |address| Addrinfo.new([address].pack('H*'), nil, 0, 0) }
  end
  module Constants
    def self.__table
      @__table ||= begin
        h = {}
        Socket::Constants.__order.each { |n| h[n] = Socket::Constants.const_get(n) }
        h
      end
    end
    def self.__order
      @__order
    end
    @__order = []
    # (the platform's table, "NAME=value ...": Socket.__consts_text answers
    #  m_unicode.mere's sock_consts, Darwin's or Linux's)
    Socket.__consts_text.split.each do |kv|
      k, v = kv.split("=")
      const_set(k, v.to_i)
      @__order << k
    end
    # NUM2INT for the socket library: an Integer, a Float truncated, #to_int,
    # and otherwise the TypeError ruby's own conversion raises.
    def self.__int(v)
      return v if v.is_a?(Integer)
      return v.to_i if v.is_a?(Float)
      raise TypeError, "no implicit conversion from nil to integer" if v.nil?
      raise TypeError, "no implicit conversion of #{v.class} into Integer" unless v.respond_to?(:to_int)
      v.to_int
    end
    # constdefs.c's name_to_int: the full constant name, or (where the
    # table has an optional prefix) the name with that prefix taken off.
    def self.__lookup(name, pat, prefix)
      t = __table
      return t[name] if pat =~ name && t.key?(name)
      if prefix
        __order.each do |c|
          next unless pat =~ c
          m = prefix.match(c)
          return t[c] if m && m.post_match == name
        end
      end
      nil
    end
    # constants.c's constant_arg: a Symbol or a String (or anything with
    # #to_str) is a NAME and must be one; anything else is an Integer.
    def self.__name_to_int(arg, pat, prefix, errmsg)
      if arg.is_a?(Symbol)
        s = arg.to_s
      elsif arg.is_a?(String)
        s = arg
      elsif arg.respond_to?(:to_str)
        s = arg.to_str
        # rb_check_string_type's refusal of a #to_str that is not one
        raise TypeError, "can't convert #{arg.class} to String (#{arg.class}#to_str gives #{s.class})" unless s.is_a?(String)
      else
        return Socket::Constants.__int(arg)
      end
      v = __lookup(s, pat, prefix)
      raise SocketError, "#{errmsg}: #{s}" if v.nil?
      v
    end
    # ...and the reverse, constdefs.c's intern: the FIRST name (in the order
    # mkconstants lists them) that has the value, with the prefix taken off
    # when the table has one.
    def self.__intern(val, pat, prefix = nil)
      __order.each do |c|
        next unless pat =~ c && __table[c] == val
        if prefix
          m = prefix.match(c)
          next unless m
          return m.post_match
        end
        return c
      end
      nil
    end
    def self.__family_arg(v)
      __name_to_int(v, /\A(AF_|PF_)/, /\AAF_/, "unknown socket domain")
    end
    def self.__socktype_arg(v)
      __name_to_int(v, /\ASOCK_/, /\ASOCK_/, "unknown socket type")
    end
    def self.__ip_family?(f)
      f == Socket::AF_INET || f == Socket::AF_INET6
    end
    def self.__level_arg(family, v)
      if __ip_family?(family)
        __name_to_int(v, /\A(SOL_SOCKET\z|IPPROTO_)/, /\A(SOL_|IPPROTO_)/, "unknown protocol level")
      else
        __name_to_int(v, /\ASOL_SOCKET\z/, /\ASOL_/, "unknown protocol level")
      end
    end
    # the option-name table of each level, and what its error calls it
    def self.__opt_table(k)
      case k
      when "SO" then [/\ASO_/, "socket level option name", "UNIX control message"]
      when "IP" then [/\AIP_/, "IP level option name", "IP control message"]
      when "IPV6" then [/\AIPV6_/, "IPv6 level option name", "IPv6 control message"]
      when "TCP" then [/\ATCP_/, "TCP level option name", "TCP control message"]
      when "UDP" then [/\AUDP_/, "UDP level option name", "UDP control message"]
      end
    end
    def self.__level_kind(family, level)
      if __ip_family?(family)
        case level
        when Socket::SOL_SOCKET then "SO"
        when Socket::IPPROTO_IP then "IP"
        when Socket::IPPROTO_IPV6 then "IPV6"
        when Socket::IPPROTO_TCP then "TCP"
        when Socket::IPPROTO_UDP then "UDP"
        end
      else
        level == Socket::SOL_SOCKET ? "SO" : nil
      end
    end
    def self.__optname_arg(family, level, v)
      k = __level_kind(family, level)
      return Socket::Constants.__int(v) if k.nil?
      pat, what, = __opt_table(k)
      __name_to_int(v, pat, Regexp.new("\\A#{k}_"), "unknown #{what}")
    end
    def self.__cmsg_type_arg(family, level, v)
      k = __level_kind(family, level)
      return Socket::Constants.__int(v) if k.nil?
      if k == "SO"
        __name_to_int(v, /\ASCM_/, /\ASCM_/, "unknown UNIX control message")
      else
        pat, _, what = __opt_table(k)
        __name_to_int(v, pat, Regexp.new("\\A#{k}_"), "unknown #{what}")
      end
    end
  end
  Constants.__order.each { |n| const_set(n, Constants.const_get(n)) }

  class ResolutionError < SocketError
    def initialize(msg = nil, code = nil)
      super(msg)
      @error_code = code
    end
    attr_reader :error_code
  end

  def initialize(domain, socktype, protocol = nil)
    __new_block_warn if block_given?
    @family = Constants.__family_arg(domain)
    st = Constants.__socktype_arg(socktype)
    @protocol = protocol.nil? ? 0 : Socket::Constants.__int(protocol)
    fd = Socket.__socket(Socket::Endpoint__.kernel_family(@family), st, @protocol)
    raise Errno::EAFNOSUPPORT, "socket(2)" if fd < 0
    __setup(fd, st)
  end
  def __sockaddr_ai(addr)
    return addr if addr.is_a?(Addrinfo)
    raise TypeError, "no implicit conversion of #{addr.nil? ? 'nil' : addr.class} into String" unless addr.respond_to?(:to_str)
    Addrinfo.new(addr.to_str, @family, @socktype, @protocol)
  end
  # socket.rb's own: IPV6_V6ONLY on, now that setsockopt sets it
  def ipv6only!
    if defined? Socket::IPV6_V6ONLY
      self.setsockopt(:IPV6, :V6ONLY, 1)
    end
  end
  # bind(2) is the runtime's sock_bind (compiler v0.1.555): the address and
  # port of the sockaddr, and the kernel's refusal raised as it named it.
  # (A connect afterwards is still the runtime's own socket -- see #connect.)
  def bind(addr)
    __check_open
    ai = __sockaddr_ai(addr)
    if ai.ip? && ai.afamily != @family
      raise Errno::EAFNOSUPPORT, "bind(2) for #{ai.inspect_sockaddr}"
    end
    if ai.unix?
      r = Socket.__unix_bind(@__io_fd, ai.unix_path)
      raise SystemCallError.new("bind(2) for #{ai.unix_path}", -r) if r < 0
      @bind_addr = ai
      return 0
    end
    r = Socket.__bind(@__io_fd, ai.ip_address, ai.ip_port)
    raise SystemCallError.new("bind(2) for #{ai.inspect_sockaddr}", -r) if r.is_a?(Integer) && r < 0
    @bind_addr = ai
    0
  end
  def listen(backlog = Socket::SOMAXCONN)
    backlog = Socket::Constants.__int(backlog)
    # (after the conversion, which may have closed it: ruby's order)
    __check_open
    # a datagram socket's own listen(2) is the refusal (EOPNOTSUPP)
    raise Errno::EOPNOTSUPP, "listen(2)" if Socket.__listenfd(@__io_fd, backlog) < 0
    @listening = true
    0
  end
  def connect(addr)
    __check_open
    ai = __sockaddr_ai(addr)
    if ai.unix?
      r = Socket.__unix_connect(@__io_fd, ai.unix_path)
      raise SystemCallError.new("connect(2) for #{ai.unix_path}", -r) if r < 0
      return 0
    end
    raise Errno::EISCONN, "connect(2) for #{ai.inspect_sockaddr}" if @__connected
    return __dgram_peer!(ai) if __dgram_bound?
    # connect(2) on this descriptor (Mere v0.1.724's sock_connect): it keeps
    # its family, its binding and its options. The socket is non-blocking,
    # so a connection under way is waited for here and its outcome is
    # SO_ERROR's.
    r = Socket.__sock_connect(@__io_fd, ai.ip_address, ai.ip_port)
    if r.is_a?(Integer) && r == -Errno::EINPROGRESS::Errno
      # (the IO's timeout bounds the wait, rsock_connect's IO::TimeoutError)
      if IO.select(nil, [self], nil, @__io_timeout).nil?
        raise IO::TimeoutError, "Connect timed out!"
      end
      h = Socket.__getopt(@__io_fd, Socket::SOL_SOCKET, Socket::SO_ERROR)
      r = h.is_a?(String) ? -[h].pack("H*").unpack1("i") : r
    end
    raise SystemCallError.new("connect(2) for #{ai.inspect_sockaddr}", -r) if r.is_a?(Integer) && r < 0
    raise Errno::EAFNOSUPPORT, "connect(2) for #{ai.inspect_sockaddr}" if r.nil?
    @__connected = true unless @socktype == Socket::SOCK_DGRAM
    0
  end
  def connect_nonblock(addr, exception: true)
    __check_open
    ai = __sockaddr_ai(addr)
    return connect(addr) if ai.unix? || __dgram_bound?
    r = Socket.__sock_connect(@__io_fd, ai.ip_address, ai.ip_port)
    if r.is_a?(Integer) && r < 0
      if r == -Errno::EINPROGRESS::Errno
        return :wait_writable unless exception
        raise IO::EINPROGRESSWaitWritable, "connect(2) would block"
      end
      # (connected already: 0 without exceptions, rsock_connect_nonblock)
      return 0 if r == -Errno::EISCONN::Errno && !exception
      raise SystemCallError.new("connect(2) for #{ai.inspect_sockaddr}", -r)
    end
    raise Errno::EAFNOSUPPORT, "connect(2) for #{ai.inspect_sockaddr}" if r.nil?
    @__connected = true unless @socktype == Socket::SOCK_DGRAM
    0
  end
  def accept
    __check_open
    raise Errno::EINVAL, "accept(2)" unless @listening
    __wait_readable
    fd = Socket.__accept(@__io_fd)
    raise SocketError, "accept failed" if fd < 0
    s = Socket.allocate
    s.__setup(fd, @socktype)
    s.instance_variable_set(:@family, @family)
    s.instance_variable_set(:@protocol, @protocol)
    [s, s.remote_address]
  end
  def accept_nonblock(exception: true)
    __check_open
    raise Errno::EINVAL, "accept(2)" unless @listening
    unless __ready?(1)
      return :wait_readable unless exception
      raise IO::EAGAINWaitReadable, "accept(2) would block"
    end
    accept
  end
  def sysaccept
    s, a = accept
    [s.fileno, a]
  end
  def recvfrom(maxlen, flags = 0)
    # a datagram's sender is the one recvfrom(2) names
    if @socktype == Socket::SOCK_DGRAM && @__io_rbuf.empty?
      data, addr = __dgram_take(maxlen, flags, false)
      return [data, __dgram_ai(addr, "recvfrom(2)")]
    end
    data = recv(maxlen, flags)
    # a stream at its end is nil, not [nil, addr] (rsock_s_recvfrom)
    return nil if data.nil?
    [data, remote_address]
  end
  def inspect
    return Kernel.instance_method(:to_s).bind_call(self) unless @__io_fd
    return "#<Socket:(closed)>" if closed?
    "#<Socket:fd #{@__io_fd}>"
  end

  # Socket.tcp_fast_fallback (socket.c keeps it as an ivar of Socket: on
  # unless RUBY_TCP_NO_FAST_FALLBACK is set to something other than "0")
  @tcp_fast_fallback = (ENV["RUBY_TCP_NO_FAST_FALLBACK"].nil? || ENV["RUBY_TCP_NO_FAST_FALLBACK"] == "0")
  def self.tcp_fast_fallback
    @tcp_fast_fallback
  end
  def self.tcp_fast_fallback=(value)
    @tcp_fast_fallback = value
  end
  # ---- ruby 4.0.9 ext/socket/lib/socket.rb, as it is (Ruby's license):
  #      Socket.tcp with Happy Eyeballs v2 ----
  # :stopdoc:
  RESOLUTION_DELAY = 0.05
  private_constant :RESOLUTION_DELAY

  CONNECTION_ATTEMPT_DELAY = 0.25
  private_constant :CONNECTION_ATTEMPT_DELAY

  ADDRESS_FAMILIES = {
    ipv6: Socket::AF_INET6,
    ipv4: Socket::AF_INET
  }.freeze
  private_constant :ADDRESS_FAMILIES

  HOSTNAME_RESOLUTION_QUEUE_UPDATED = 0
  private_constant :HOSTNAME_RESOLUTION_QUEUE_UPDATED

  IPV6_ADDRESS_FORMAT = /\A(?i:(?:(?:[0-9A-F]{1,4}:){7}(?:[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){6}(?:[0-9A-F]{1,4}|:(?:[0-9A-F]{1,4}:){1,5}[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){5}(?:(?::[0-9A-F]{1,4}){1,2}|:(?:[0-9A-F]{1,4}:){1,4}[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){4}(?:(?::[0-9A-F]{1,4}){1,3}|:(?:[0-9A-F]{1,4}:){1,3}[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){3}(?:(?::[0-9A-F]{1,4}){1,4}|:(?:[0-9A-F]{1,4}:){1,2}[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){2}(?:(?::[0-9A-F]{1,4}){1,5}|:(?:[0-9A-F]{1,4}:)[0-9A-F]{1,4}|:)|(?:[0-9A-F]{1,4}:){1}(?:(?::[0-9A-F]{1,4}){1,6}|:(?:[0-9A-F]{1,4}:){0,5}[0-9A-F]{1,4}|:)|(?:::(?:[0-9A-F]{1,4}:){0,7}[0-9A-F]{1,4}|::)))(?:%.+)?\z/
  private_constant :IPV6_ADDRESS_FORMAT
  # :startdoc:

  # :call-seq:
  #   Socket.tcp(host, port, local_host=nil, local_port=nil, [opts]) {|socket| ... }
  #   Socket.tcp(host, port, local_host=nil, local_port=nil, [opts])
  #
  # creates a new socket object connected to host:port using TCP/IP.
  #
  # Starting from Ruby 3.4, this method operates according to the
  # Happy Eyeballs Version 2 ({RFC 8305}[https://datatracker.ietf.org/doc/html/rfc8305])
  # algorithm by default.
  #
  # For details on Happy Eyeballs Version 2,
  # see {Socket.tcp_fast_fallback=}[rdoc-ref:Socket.tcp_fast_fallback=].
  #
  # To make it behave the same as in Ruby 3.3 and earlier,
  # explicitly specify the option fast_fallback:false.
  # Or, setting Socket.tcp_fast_fallback=false will disable
  # Happy Eyeballs Version 2 not only for this method but for all Socket globally.
  #
  # If local_host:local_port is given,
  # the socket is bound to it.
  #
  # The optional last argument _opts_ is options represented by a hash.
  # _opts_ may have following options:
  #
  # [:resolv_timeout] Specifies the timeout in seconds from when the hostname resolution starts.
  # [:connect_timeout] This method sequentially attempts connecting to all candidate destination addresses.<br>The +connect_timeout+ specifies the timeout in seconds from the start of the connection attempt to the last candidate.<br>By default, all connection attempts continue until the timeout occurs.<br>When +fast_fallback:false+ is explicitly specified,<br>a timeout is set for each connection attempt and any connection attempt that exceeds its timeout will be canceled.
  # [:open_timeout] Specifies the timeout in seconds from the start of the method execution.<br>If this timeout is reached while there are still addresses that have not yet been attempted for connection, no further attempts will be made.<br>If this option is specified together with other timeout options, an +ArgumentError+ will be raised.
  # [:fast_fallback] Enables the Happy Eyeballs Version 2 algorithm (enabled by default).
  #
  # If a block is given, the block is called with the socket.
  # The value of the block is returned.
  # The socket is closed when this method returns.
  #
  # If no block is given, the socket is returned.
  #
  #   Socket.tcp("www.ruby-lang.org", 80) {|sock|
  #     sock.print "GET / HTTP/1.0\r\nHost: www.ruby-lang.org\r\n\r\n"
  #     sock.close_write
  #     puts sock.read
  #   }
  def self.tcp(host, port, local_host = nil, local_port = nil, connect_timeout: nil, resolv_timeout: nil, open_timeout: nil, fast_fallback: tcp_fast_fallback, &) # :yield: socket

    if open_timeout && (connect_timeout || resolv_timeout)
      raise ArgumentError, "Cannot specify open_timeout along with connect_timeout or resolv_timeout"
    end

    sock = if fast_fallback && !(host && ip_address?(host))
      tcp_with_fast_fallback(host, port, local_host, local_port, connect_timeout:, resolv_timeout:, open_timeout:)
    else
      tcp_without_fast_fallback(host, port, local_host, local_port, connect_timeout:, resolv_timeout:, open_timeout:)
    end

    if block_given?
      begin
        yield sock
      ensure
        sock.close
      end
    else
      sock
    end
  end

  # :stopdoc:
  def self.tcp_with_fast_fallback(host, port, local_host = nil, local_port = nil, connect_timeout: nil, resolv_timeout: nil, open_timeout: nil)
    if local_host || local_port
      local_addrinfos = Addrinfo.getaddrinfo(local_host, local_port, nil, :STREAM, timeout: open_timeout || resolv_timeout)
      resolving_family_names = local_addrinfos.map { |lai| ADDRESS_FAMILIES.key(lai.afamily) }.uniq
    else
      local_addrinfos = []
      resolving_family_names = ADDRESS_FAMILIES.keys
    end

    hostname_resolution_threads = []
    resolution_store = HostnameResolutionStore.new(resolving_family_names)
    connecting_sockets = {}
    is_windows_environment ||= (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)

    now = current_clock_time
    starts_at = now
    resolution_delay_expires_at = nil
    connection_attempt_delay_expires_at = nil
    user_specified_connect_timeout_at = nil
    user_specified_open_timeout_at = open_timeout ? now + open_timeout : nil
    last_error = nil
    last_error_from_thread = false

    if resolving_family_names.size == 1
      family_name = resolving_family_names.first
      addrinfos = Addrinfo.getaddrinfo(host, port, ADDRESS_FAMILIES[:family_name], :STREAM, timeout: open_timeout || resolv_timeout)
      resolution_store.add_resolved(family_name, addrinfos)
      hostname_resolution_result = nil
      hostname_resolution_notifier = nil
      user_specified_resolv_timeout_at = nil
    else
      hostname_resolution_result = HostnameResolutionResult.new(resolving_family_names.size)
      hostname_resolution_notifier = hostname_resolution_result.notifier

      hostname_resolution_threads.concat(
        resolving_family_names.map { |family|
          thread_args = [family, host, port, hostname_resolution_result]
          thread = Thread.new(*thread_args) { |*thread_args| resolve_hostname(*thread_args) }
          Thread.pass
          thread
        }
      )
      user_specified_resolv_timeout_at = resolv_timeout ? now + resolv_timeout : Float::INFINITY
    end

    loop do
      if resolution_store.any_addrinfos? &&
          !resolution_delay_expires_at &&
          !connection_attempt_delay_expires_at
        while (addrinfo = resolution_store.get_addrinfo)
          if local_addrinfos.any?
            local_addrinfo = local_addrinfos.find { |lai| lai.afamily == addrinfo.afamily }

            if local_addrinfo.nil? # Connecting addrinfoと同じアドレスファミリのLocal addrinfoがない
              if resolution_store.any_addrinfos?
                # Try other Addrinfo in next "while"
                next
              elsif connecting_sockets.any? || resolution_store.any_unresolved_family?
                # Exit this "while" and wait for connections to be established or hostname resolution in next loop
                # Or exit this "while" and wait for hostname resolution in next loop
                break
              else
                raise SocketError.new 'no appropriate local address'
              end
            end
          end

          begin
            if resolution_store.any_addrinfos? ||
               connecting_sockets.any? ||
               resolution_store.any_unresolved_family?
              socket = Socket.new(addrinfo.pfamily, addrinfo.socktype, addrinfo.protocol)
              socket.bind(local_addrinfo) if local_addrinfo
              result = socket.connect_nonblock(addrinfo, exception: false)
            else
              timeout =
                if open_timeout
                  t = open_timeout - (current_clock_time - starts_at)
                  t.negative? ? 0 : t
                else
                  connect_timeout
                end
              result = socket = local_addrinfo ?
                addrinfo.connect_from(local_addrinfo, timeout:) :
                addrinfo.connect(timeout:)
            end

            if result == :wait_writable
              connection_attempt_delay_expires_at = now + CONNECTION_ATTEMPT_DELAY
              if resolution_store.empty_addrinfos?
                user_specified_connect_timeout_at = connect_timeout ? now + connect_timeout : Float::INFINITY
              end

              connecting_sockets[socket] = addrinfo
              break
            else
              return socket # connection established
            end
          rescue SystemCallError => e
            socket&.close
            last_error = e

            if resolution_store.any_addrinfos?
              # Try other Addrinfo in next "while"
              next
            elsif connecting_sockets.any? || resolution_store.any_unresolved_family?
              # Exit this "while" and wait for connections to be established or hostname resolution in next loop
              # Or exit this "while" and wait for hostname resolution in next loop
              break
            else
              raise last_error
            end
          end
        end
      end

      ends_at =
        if resolution_store.any_addrinfos?
          [(resolution_delay_expires_at || connection_attempt_delay_expires_at),
           user_specified_open_timeout_at].compact.min
        elsif user_specified_open_timeout_at
          user_specified_open_timeout_at
        else
          [user_specified_resolv_timeout_at, user_specified_connect_timeout_at].compact.max
        end

      hostname_resolved, writable_sockets, except_sockets = IO.select(
        hostname_resolution_notifier,
        connecting_sockets.keys,
        # Use errorfds to wait for non-blocking connect failures on Windows
        is_windows_environment ? connecting_sockets.keys : nil,
        second_to_timeout(current_clock_time, ends_at),
      )
      now = current_clock_time
      resolution_delay_expires_at = nil if expired?(now, resolution_delay_expires_at)
      connection_attempt_delay_expires_at = nil if expired?(now, connection_attempt_delay_expires_at)

      if writable_sockets&.any?
        while (writable_socket = writable_sockets.pop)
          is_connected = is_windows_environment || (
            sockopt = writable_socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR)
            sockopt.int.zero?
          )

          if is_connected
            connecting_sockets.delete writable_socket
            return writable_socket
          else
            failed_ai = connecting_sockets.delete writable_socket
            writable_socket.close
            ip_address = failed_ai.ipv6? ? "[#{failed_ai.ip_address}]" : failed_ai.ip_address
            last_error = SystemCallError.new("connect(2) for #{ip_address}:#{failed_ai.ip_port}", sockopt.int)

            if writable_sockets.any? || connecting_sockets.any?
              # Try other writable socket in next "while"
              # Or exit this "while" and wait for connections to be established or hostname resolution in next loop
            elsif resolution_store.any_addrinfos? || resolution_store.any_unresolved_family?
              # Exit this "while" and try other connection attempt
              # Or exit this "while" and wait for hostname resolution in next loop
              connection_attempt_delay_expires_at = nil
              user_specified_connect_timeout_at = nil
            else
              raise last_error
            end
          end
        end
      end

      if except_sockets&.any?
        except_sockets.each do |except_socket|
          failed_ai = connecting_sockets.delete except_socket
          sockopt = except_socket.getsockopt(Socket::SOL_SOCKET, Socket::SO_ERROR)
          except_socket.close
          ip_address = failed_ai.ipv6? ? "[#{failed_ai.ip_address}]" : failed_ai.ip_address
          last_error = SystemCallError.new("connect(2) for #{ip_address}:#{failed_ai.ip_port}", sockopt.int)

          if except_sockets.any? || connecting_sockets.any?
            # Cleanup other except socket in next "each"
            # Or exit this "while" and wait for connections to be established or hostname resolution in next loop
          elsif resolution_store.any_addrinfos? || resolution_store.any_unresolved_family?
            # Exit this "while" and try other connection attempt
            # Or exit this "while" and wait for hostname resolution in next loop
            connection_attempt_delay_expires_at = nil
            user_specified_connect_timeout_at = nil
          else
            raise last_error
          end
        end
      end

      if hostname_resolved&.any?
        while (family_and_result = hostname_resolution_result.get)
          family_name, result = family_and_result

          if result.is_a? Exception
            resolution_store.add_error(family_name, result)

            unless (Socket.const_defined?(:EAI_ADDRFAMILY)) &&
              (result.is_a?(Socket::ResolutionError)) &&
              (result.error_code == Socket::EAI_ADDRFAMILY)
              other = family_name == :ipv6 ? :ipv4 : :ipv6
              if !resolution_store.resolved?(other) || !resolution_store.resolved_successfully?(other)
                last_error = result
                last_error_from_thread = true
              end
            end
          else
            resolution_store.add_resolved(family_name, result)
          end
        end

        if resolution_store.resolved?(:ipv4)
          if resolution_store.resolved?(:ipv6)
            hostname_resolution_notifier = nil
            resolution_delay_expires_at = nil
            user_specified_resolv_timeout_at = nil
          elsif resolution_store.resolved_successfully?(:ipv4)
            resolution_delay_expires_at = now + RESOLUTION_DELAY
          end
        end
      end

      if expired?(now, user_specified_open_timeout_at)
        raise(IO::TimeoutError, "user specified timeout for #{host}:#{port}")
      end

      if resolution_store.empty_addrinfos?
        if connecting_sockets.empty? && resolution_store.resolved_all_families?
          if last_error_from_thread
            raise last_error.class, last_error.message, cause: last_error
          else
            raise last_error
          end
        end

        if (expired?(now, user_specified_resolv_timeout_at) || resolution_store.resolved_all_families?) &&
           (expired?(now, user_specified_connect_timeout_at) || connecting_sockets.empty?)
          raise(IO::TimeoutError, "user specified timeout for #{host}:#{port}")
        end
      end
    end
  ensure
    hostname_resolution_threads.each do |thread|
      thread.exit
    end

    hostname_resolution_result&.close

    connecting_sockets.each_key do |connecting_socket|
      connecting_socket.close
    end
  end
  private_class_method :tcp_with_fast_fallback

  def self.tcp_without_fast_fallback(host, port, local_host, local_port, connect_timeout:, resolv_timeout:, open_timeout:)
    last_error = nil
    ret = nil

    local_addr_list = nil
    if local_host != nil || local_port != nil
      local_addr_list = Addrinfo.getaddrinfo(local_host, local_port, nil, :STREAM, nil, timeout: open_timeout || resolv_timeout)
    end

    timeout = open_timeout ? open_timeout : resolv_timeout
    starts_at = current_clock_time

    Addrinfo.foreach(host, port, nil, :STREAM, timeout:) {|ai|
      if local_addr_list
        local_addr = local_addr_list.find {|local_ai| local_ai.afamily == ai.afamily }
        next unless local_addr
      else
        local_addr = nil
      end
      begin
        timeout =
          if open_timeout
            t = open_timeout - (current_clock_time - starts_at)
            t.negative? ? 0 : t
          else
            connect_timeout
          end

        sock = local_addr ?
          ai.connect_from(local_addr, timeout:) :
          ai.connect(timeout:)
      rescue SystemCallError
        last_error = $!
        next
      end
      ret = sock
      break
    }
    unless ret
      if last_error
        raise last_error
      else
        raise SocketError, "no appropriate local address"
      end
    end

    ret
  end
  private_class_method :tcp_without_fast_fallback

  def self.ip_address?(hostname)
    hostname.match?(IPV6_ADDRESS_FORMAT) || hostname.match?(/\A([0-9]{1,3}\.){3}[0-9]{1,3}\z/)
  end
  private_class_method :ip_address?

  def self.resolve_hostname(family, host, port, hostname_resolution_result)
    begin
      resolved_addrinfos = Addrinfo.getaddrinfo(host, port, ADDRESS_FAMILIES[family], :STREAM)
      hostname_resolution_result.add(family, resolved_addrinfos)
    rescue => e
      hostname_resolution_result.add(family, e)
    end
  end
  private_class_method :resolve_hostname

  def self.current_clock_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
  private_class_method :current_clock_time

  def self.second_to_timeout(started_at, ends_at)
    return nil if ends_at == Float::INFINITY || ends_at.nil?

    remaining = (ends_at - started_at)
    remaining.negative? ? 0 : remaining
  end
  private_class_method :second_to_timeout

  def self.expired?(started_at, ends_at)
    second_to_timeout(started_at, ends_at)&.zero?
  end
  private_class_method :expired?

  class HostnameResolutionResult
    def initialize(size)
      @size = size
      @taken_count = 0
      @rpipe, @wpipe = IO.pipe
      @results = []
      @mutex = Mutex.new
    end

    def notifier
      [@rpipe]
    end

    def add(family, result)
      @mutex.synchronize do
        @results.push [family, result]
        @wpipe.putc HOSTNAME_RESOLUTION_QUEUE_UPDATED
      end
    end

    def get
      return nil if @results.empty?

      res = nil

      @mutex.synchronize do
        @rpipe.getbyte
        res = @results.shift
      end

      @taken_count += 1
      close if @taken_count == @size
      res
    end

    def close
      @rpipe.close
      @wpipe.close
    end
  end
  private_constant :HostnameResolutionResult

  class HostnameResolutionStore
    PRIORITY_ON_V6 = [:ipv6, :ipv4].freeze
    PRIORITY_ON_V4 = [:ipv4, :ipv6].freeze

    def initialize(family_names)
      @family_names = family_names
      @addrinfo_dict = {}
      @error_dict = {}
      @last_family = nil
    end

    def add_resolved(family_name, addrinfos)
      @addrinfo_dict[family_name] = addrinfos
    end

    def add_error(family_name, error)
      @addrinfo_dict[family_name] = []
      @error_dict[family_name] = error
    end

    def get_addrinfo
      precedences =
        case @last_family
        when :ipv4, nil then PRIORITY_ON_V6
        when :ipv6      then PRIORITY_ON_V4
        end

      precedences.each do |family_name|
        addrinfo = @addrinfo_dict[family_name]&.shift
        next unless addrinfo

        @last_family = family_name
        return addrinfo
      end

      nil
    end

    def empty_addrinfos?
      @addrinfo_dict.all? { |_, addrinfos| addrinfos.empty? }
    end

    def any_addrinfos?
      !empty_addrinfos?
    end

    def resolved?(family)
      @addrinfo_dict.has_key? family
    end

    def resolved_successfully?(family)
      resolved?(family) && !@error_dict[family]
    end

    def resolved_all_families?
      (@family_names - @addrinfo_dict.keys).empty?
    end

    def any_unresolved_family?
      !resolved_all_families?
    end
  end
  private_constant :HostnameResolutionStore
  # ---- end of ruby's ----
  def self.gethostname
    @__hostname ||= `hostname 2>/dev/null`.chomp
  end
  def self.getaddrinfo(host, service, family = nil, socktype = nil, protocol = nil, flags = nil, reverse_lookup = nil)
    rev = case reverse_lookup
      when nil then !BasicSocket.do_not_reverse_lookup
      when true, :hostname then true
      when false, :numeric then false
      else raise ArgumentError, "invalid reverse_lookup flag: #{reverse_lookup.inspect}"
    end
    fam = family.nil? || family == 0 ? 0 : Constants.__family_arg(family)
    st = socktype.nil? || socktype == 0 ? 0 : Constants.__socktype_arg(socktype)
    pr = protocol.nil? ? 0 : Socket::Constants.__int(protocol)
    fl = flags.nil? ? 0 : Socket::Constants.__int(flags)
    Addrinfo.__getaddrinfo(host, service, fam, st, pr, fl, false).map do |ai|
      h = rev ? Addrinfo.__reverse_name(ai) : ai.ip_address
      [ai.ipv6? ? "AF_INET6" : "AF_INET", ai.ip_port, h, ai.ip_address, ai.afamily, ai.socktype, ai.protocol]
    end
  end
  def self.getnameinfo(sockaddr, flags = 0)
    if sockaddr.is_a?(Array)
      # sock_s_getnameinfo: [family, port, host] or [family, port, name,
      # numeric host], and the host is resolved IN the family named
      n = sockaddr.length
      raise ArgumentError, "array size should be 3 or 4, #{n} given" if n < 3
      fam, port, host = n == 3 ? sockaddr : [sockaddr[0], sockaddr[1], sockaddr[3] || sockaddr[2]]
      f = fam.nil? ? 0 : Constants.__family_arg(fam)
      ai = Addrinfo.__getaddrinfo(host, port, f, 0, 0, 0, false)[0]
    elsif sockaddr.is_a?(Addrinfo)
      ai = sockaddr
    else
      ai = Addrinfo.new(sockaddr)
    end
    ai.getnameinfo(flags)
  end
  # getservbyname(3) / getservbyport(3), over the /etc/services Addrinfo
  # reads; a numeric service is its number, as ruby's fallback has it
  def self.getservbyname(service, proto = "tcp")
    name = IO.__fd_str(service)
    pr = IO.__fd_str(proto)
    port = Addrinfo.__service_port(name, pr)
    port = name.to_i if port.nil? && name =~ /\A\d+\z/
    raise SocketError, "no such service #{name}/#{pr}" if port.nil?
    port
  end
  def self.getservbyport(port, proto = "tcp")
    n = Constants.__int(port)
    if n < -32768 || n > 65535
      raise RangeError, "integer #{n} too #{n > 0 ? 'big' : 'small'} to convert into `int16_t'"
    end
    pr = IO.__fd_str(proto)
    name = Addrinfo.__service_name(n & 0xffff, pr)
    raise SocketError, "no such service for port #{n}/#{pr}" if name.nil?
    name.b
  end
  # ext/socket/lib/socket.rb's accept_loop: accept on whichever listener
  # is readable, for ever
  def self.accept_loop(*sockets)
    sockets.flatten!(1)
    raise ArgumentError, "no sockets" if sockets.empty?
    loop do
      readable, = IO.select(sockets)
      readable.each do |r|
        sock, addr = r.accept_nonblock(exception: false)
        next if sock == :wait_readable
        yield sock, addr
      end
    end
  end
  # ---- ruby 4.0.9 ext/socket/lib/socket.rb, as it is (Ruby's license) ----
  def self.ip_sockets_port0(ai_list, reuseaddr)
    sockets = []
    begin
      sockets.clear
      port = nil
      ai_list.each {|ai|
        begin
          s = Socket.new(ai.pfamily, ai.socktype, ai.protocol)
        rescue SystemCallError
          next
        end
        sockets << s
        s.ipv6only! if ai.ipv6?
        if reuseaddr
          s.setsockopt(:SOCKET, :REUSEADDR, 1)
        end
        unless port
          s.bind(ai)
          port = s.local_address.ip_port
        else
          s.bind(ai.family_addrinfo(ai.ip_address, port))
        end
      }
    rescue Errno::EADDRINUSE
      sockets.each(&:close)
      retry
    rescue Exception
      sockets.each(&:close)
      raise
    end
    sockets
  end

  def self.tcp_server_sockets_port0(host)
    ai_list = Addrinfo.getaddrinfo(host, 0, nil, :STREAM, nil, Socket::AI_PASSIVE)
    sockets = ip_sockets_port0(ai_list, true)
    begin
      sockets.each {|s|
        s.listen(Socket::SOMAXCONN)
      }
    rescue Exception
      sockets.each(&:close)
      raise
    end
    sockets
  end

  # creates TCP/IP server sockets for _host_ and _port_.
  # _host_ is optional.
  #
  # If no block given,
  # it returns an array of listening sockets.
  #
  # If a block is given, the block is called with the sockets.
  # The value of the block is returned.
  # The socket is closed when this method returns.
  #
  # If _port_ is 0, actual port number is chosen dynamically.
  # However all sockets in the result has same port number.
  #
  #   # tcp_server_sockets returns two sockets.
  #   sockets = Socket.tcp_server_sockets(1296)
  #   p sockets #=> [#<Socket:fd 3>, #<Socket:fd 4>]
  #
  #   # The sockets contains IPv6 and IPv4 sockets.
  #   sockets.each {|s| p s.local_address }
  #   #=> #<Addrinfo: [::]:1296 TCP>
  #   #   #<Addrinfo: 0.0.0.0:1296 TCP>
  #
  #   # IPv6 and IPv4 socket has same port number, 53114, even if it is chosen dynamically.
  #   sockets = Socket.tcp_server_sockets(0)
  #   sockets.each {|s| p s.local_address }
  #   #=> #<Addrinfo: [::]:53114 TCP>
  #   #   #<Addrinfo: 0.0.0.0:53114 TCP>
  #
  #   # The block is called with the sockets.
  #   Socket.tcp_server_sockets(0) {|sockets|
  #     p sockets #=> [#<Socket:fd 3>, #<Socket:fd 4>]
  #   }
  #
  def self.tcp_server_sockets(host=nil, port)
    if port == 0
      sockets = tcp_server_sockets_port0(host)
    else
      last_error = nil
      sockets = []
      begin
        Addrinfo.foreach(host, port, nil, :STREAM, nil, Socket::AI_PASSIVE) {|ai|
          begin
            s = ai.listen
          rescue SystemCallError
            last_error = $!
            next
          end
          sockets << s
        }
        if sockets.empty?
          raise last_error
        end
      rescue Exception
        sockets.each(&:close)
        raise
      end
    end
    if block_given?
      begin
        yield sockets
      ensure
        sockets.each(&:close)
      end
    else
      sockets
    end
  end

  # creates a TCP/IP server on _port_ and calls the block for each connection accepted.
  # The block is called with a socket and a client_address as an Addrinfo object.
  #
  # If _host_ is specified, it is used with _port_ to determine the server addresses.
  #
  # The socket is *not* closed when the block returns.
  # So application should close it explicitly.
  #
  # This method calls the block sequentially.
  # It means that the next connection is not accepted until the block returns.
  # So concurrent mechanism, thread for example, should be used to service multiple clients at a time.
  #
  # Note that Addrinfo.getaddrinfo is used to determine the server socket addresses.
  # When Addrinfo.getaddrinfo returns two or more addresses,
  # IPv4 and IPv6 address for example,
  # all of them are used.
  # Socket.tcp_server_loop succeeds if one socket can be used at least.
  #
  #   # Sequential echo server.
  #   # It services only one client at a time.
  #   Socket.tcp_server_loop(16807) {|sock, client_addrinfo|
  #     begin
  #       IO.copy_stream(sock, sock)
  #     ensure
  #       sock.close
  #     end
  #   }
  #
  #   # Threaded echo server
  #   # It services multiple clients at a time.
  #   # Note that it may accept connections too much.
  #   Socket.tcp_server_loop(16807) {|sock, client_addrinfo|
  #     Thread.new {
  #       begin
  #         IO.copy_stream(sock, sock)
  #       ensure
  #         sock.close
  #       end
  #     }
  #   }
  #
  def self.tcp_server_loop(host=nil, port, &b) # :yield: socket, client_addrinfo
    tcp_server_sockets(host, port) {|sockets|
      accept_loop(sockets, &b)
    }
  end

  # :call-seq:
  #   Socket.udp_server_sockets([host, ] port)
  #
  # Creates UDP/IP sockets for a UDP server.
  #
  # If no block given, it returns an array of sockets.
  #
  # If a block is given, the block is called with the sockets.
  # The value of the block is returned.
  # The sockets are closed when this method returns.
  #
  # If _port_ is zero, some port is chosen.
  # But the chosen port is used for the all sockets.
  #
  #   # UDP/IP echo server
  #   Socket.udp_server_sockets(0) {|sockets|
  #     p sockets.first.local_address.ip_port     #=> 32963
  #     Socket.udp_server_loop_on(sockets) {|msg, msg_src|
  #       msg_src.reply msg
  #     }
  #   }
  #
  def self.udp_server_sockets(host=nil, port)
    last_error = nil
    sockets = []

    ipv6_recvpktinfo = nil
    if defined? Socket::AncillaryData
      if defined? Socket::IPV6_RECVPKTINFO # RFC 3542
        ipv6_recvpktinfo = Socket::IPV6_RECVPKTINFO
      elsif defined? Socket::IPV6_PKTINFO # RFC 2292
        ipv6_recvpktinfo = Socket::IPV6_PKTINFO
      end
    end

    local_addrs = Socket.ip_address_list

    ip_list = []
    Addrinfo.foreach(host, port, nil, :DGRAM, nil, Socket::AI_PASSIVE) {|ai|
      if ai.ipv4? && ai.ip_address == "0.0.0.0"
        local_addrs.each {|a|
          next unless a.ipv4?
          ip_list << Addrinfo.new(a.to_sockaddr, :INET, :DGRAM, 0);
        }
      elsif ai.ipv6? && ai.ip_address == "::" && !ipv6_recvpktinfo
        local_addrs.each {|a|
          next unless a.ipv6?
          ip_list << Addrinfo.new(a.to_sockaddr, :INET6, :DGRAM, 0);
        }
      else
        ip_list << ai
      end
    }
    ip_list.uniq!(&:to_sockaddr)

    if port == 0
      sockets = ip_sockets_port0(ip_list, false)
    else
      ip_list.each {|ip|
        ai = Addrinfo.udp(ip.ip_address, port)
        begin
          s = ai.bind
        rescue SystemCallError
          last_error = $!
          next
        end
        sockets << s
      }
      if sockets.empty?
        raise last_error
      end
    end

    sockets.each {|s|
      ai = s.local_address
      if ipv6_recvpktinfo && ai.ipv6? && ai.ip_address == "::"
        s.setsockopt(:IPV6, ipv6_recvpktinfo, 1)
      end
    }

    if block_given?
      begin
        yield sockets
      ensure
        sockets.each(&:close) if sockets
      end
    else
      sockets
    end
  end

  # :call-seq:
  #   Socket.udp_server_recv(sockets) {|msg, msg_src| ... }
  #
  # Receive UDP/IP packets from the given _sockets_.
  # For each packet received, the block is called.
  #
  # The block receives _msg_ and _msg_src_.
  # _msg_ is a string which is the payload of the received packet.
  # _msg_src_ is a Socket::UDPSource object which is used for reply.
  #
  # Socket.udp_server_loop can be implemented using this method as follows.
  #
  #   udp_server_sockets(host, port) {|sockets|
  #     loop {
  #       readable, _, _ = IO.select(sockets)
  #       udp_server_recv(readable) {|msg, msg_src| ... }
  #     }
  #   }
  #
  def self.udp_server_recv(sockets)
    sockets.each {|r|
      msg, sender_addrinfo, _, *controls = r.recvmsg_nonblock(exception: false)
      next if msg == :wait_readable
      ai = r.local_address
      if ai.ipv6? and pktinfo = controls.find {|c| c.cmsg_is?(:IPV6, :PKTINFO) }
        ai = Addrinfo.udp(pktinfo.ipv6_pktinfo_addr.ip_address, ai.ip_port)
        yield msg, UDPSource.new(sender_addrinfo, ai) {|reply_msg|
          r.sendmsg reply_msg, 0, sender_addrinfo, pktinfo
        }
      else
        yield msg, UDPSource.new(sender_addrinfo, ai) {|reply_msg|
          r.send reply_msg, 0, sender_addrinfo
        }
      end
    }
  end

  # :call-seq:
  #   Socket.udp_server_loop_on(sockets) {|msg, msg_src| ... }
  #
  # Run UDP/IP server loop on the given sockets.
  #
  # The return value of Socket.udp_server_sockets is appropriate for the argument.
  #
  # It calls the block for each message received.
  #
  def self.udp_server_loop_on(sockets, &b) # :yield: msg, msg_src
    loop {
      readable, _, _ = IO.select(sockets)
      udp_server_recv(readable, &b)
    }
  end

  # :call-seq:
  #   Socket.udp_server_loop(port) {|msg, msg_src| ... }
  #   Socket.udp_server_loop(host, port) {|msg, msg_src| ... }
  #
  # creates a UDP/IP server on _port_ and calls the block for each message arrived.
  # The block is called with the message and its source information.
  #
  # This method allocates sockets internally using _port_.
  # If _host_ is specified, it is used conjunction with _port_ to determine the server addresses.
  #
  # The _msg_ is a string.
  #
  # The _msg_src_ is a Socket::UDPSource object.
  # It is used for reply.
  #
  #   # UDP/IP echo server.
  #   Socket.udp_server_loop(9261) {|msg, msg_src|
  #     msg_src.reply msg
  #   }
  #
  def self.udp_server_loop(host=nil, port, &b) # :yield: message, message_source
    udp_server_sockets(host, port) {|sockets|
      udp_server_loop_on(sockets, &b)
    }
  end

  # UDP/IP address information used by Socket.udp_server_loop.
  class UDPSource
    # +remote_address+ is an Addrinfo object.
    #
    # +local_address+ is an Addrinfo object.
    #
    # +reply_proc+ is a Proc used to send reply back to the source.
    def initialize(remote_address, local_address, &reply_proc)
      @remote_address = remote_address
      @local_address = local_address
      @reply_proc = reply_proc
    end

    # Address of the source
    attr_reader :remote_address

    # Local address
    attr_reader :local_address

    def inspect # :nodoc:
      "\#<#{self.class}: #{@remote_address.inspect_sockaddr} to #{@local_address.inspect_sockaddr}>".dup
    end

    # Sends the String +msg+ to the source
    def reply(msg)
      @reply_proc.call msg
    end
  end
  # ---- end of ruby's ----

  # getifaddrs(3) needs the interfaces' names, flags and masks, which the
  # runtime does not give (Socket.__ip_addresses is the addresses alone):
  # ruby's own answer where the function is missing
  # the deprecated hostent lookups (sock_s_gethostbyname / _gethostbyaddr):
  # [name, aliases, family, *addresses as packed bytes]
  def self.gethostbyname(name)
    warn("Socket.gethostbyname is deprecated; use Addrinfo.getaddrinfo instead.", uplevel: 1, category: :deprecated)
    host = name.is_a?(String) ? name : name.to_str
    host = "255.255.255.255" if host == "<broadcast>"
    host = "0.0.0.0" if host == "<any>"
    ais = Addrinfo.getaddrinfo(host, nil, nil, :STREAM, nil, Socket::AI_CANONNAME)
    fam = ais[0].afamily
    addrs = ais.select { |a| a.afamily == fam }.map { |a| fam == Socket::AF_INET ? a.to_sockaddr.b[4, 4] : a.to_sockaddr.b[8, 16] }.uniq
    [ais[0].canonname || host, [], fam, *addrs]
  end
  def self.gethostbyaddr(addr, family = nil)
    warn("Socket.gethostbyaddr is deprecated; use Addrinfo#getnameinfo instead.", uplevel: 1, category: :deprecated)
    raw = (addr.is_a?(String) ? addr : addr.to_str).b
    fam = family.nil? ? (raw.bytesize == 16 ? Socket::AF_INET6 : Socket::AF_INET) : Constants.__family_arg(family)
    need = fam == Socket::AF_INET6 ? 16 : (fam == Socket::AF_INET ? 4 : nil)
    raise SocketError, "unknown address family: #{fam}" if need.nil?
    raise SocketError, "host not found" unless raw.bytesize == need
    ip = fam == Socket::AF_INET ? raw.unpack("C4").join(".") : Addrinfo.__ntop6(raw)
    [Addrinfo.ip(ip).getnameinfo[0], [], fam, raw]
  end

  # getifaddrs(3) (Mere v0.1.724's sock_ifaddrs), an entry a Socket::Ifaddr
  def self.getifaddrs
    t = Socket.__ifaddrs
    raise SystemCallError.new("getifaddrs", -t) if t.is_a?(Integer)
    t.split("\n").map do |line|
      name, idx, flags, *addrs = line.split("\t", -1)
      Socket::Ifaddr.__new(name, idx.to_i, flags.to_i, *addrs.map { |a| Socket::Ifaddr.__addr(a, name, idx.to_i) })
    end
  end
  def self.sockaddr_in(port, host)
    Addrinfo.__getaddrinfo(host, port, 0, 0, 0, 0, true)[0].to_sockaddr
  end
  def self.unpack_sockaddr_in(addr)
    ai = addr.is_a?(Addrinfo) ? addr : Addrinfo.new(addr.to_str)
    raise ArgumentError, "not an AF_INET/AF_INET6 sockaddr" unless ai.ip?
    [ai.ip_port, ai.ip_address]
  end
  def self.sockaddr_un(path)
    Addrinfo.__unix_sockaddr(path.to_str)
  end
  def self.unpack_sockaddr_un(addr)
    ai = addr.is_a?(Addrinfo) ? addr : Addrinfo.new(addr.to_str)
    raise ArgumentError, "not an AF_UNIX sockaddr" unless ai.unix?
    ai.unix_path
  end
  # (a pair of Sockets, not UNIXSockets: the class asked)
  def self.socketpair(domain, type, protocol = 0, &b)
    # (a domain and a type as ruby reads them: an unknown name is SocketError,
    #  a #to_str that is no String TypeError)
    Socket::Constants.__family_arg(domain)
    t = Socket::Constants.__socktype_arg(type)
    kind = t == Socket::SOCK_DGRAM ? 2 : (t == Socket::SOCK_SEQPACKET ? 5 : (t == Socket::SOCK_STREAM ? 1 : 0))
    r = Socket.__sockpair(kind)
    raise SystemCallError.new("socketpair(2)", -r) if r.is_a?(Integer)
    pair = r.map do |fd|
      s = allocate
      s.__setup(fd, t)
      s.instance_variable_set(:@family, Socket::AF_UNIX)
      s.instance_variable_set(:@protocol, 0)
      s
    end
    return pair unless b
    begin
      yield(*pair)
    ensure
      pair.each { |x| x.close unless x.closed? }
    end
  end
  class << self
    alias pack_sockaddr_in sockaddr_in
    alias pack_sockaddr_un sockaddr_un
    alias pair socketpair
  end
  # socket.rb's own
  def self.unix(path)
    addr = Addrinfo.unix(path)
    sock = addr.connect
    if block_given?
      begin
        yield sock
      ensure
        sock.close
      end
    else
      sock
    end
  end
  def self.unix_server_socket(path)
    unless unix_socket_abstract_name?(path)
      begin
        st = File.lstat(path)
      rescue Errno::ENOENT
      end
      if st&.socket? && st.owned?
        File.unlink path
      end
    end
    s = Addrinfo.unix(path).listen
    if block_given?
      begin
        yield s
      ensure
        s.close
        unless unix_socket_abstract_name?(path)
          File.unlink path
        end
      end
    else
      s
    end
  end
  if RUBY_PLATFORM.include?("linux")
    def self.unix_socket_abstract_name?(path)
      path.empty? or path.start_with?("\0")
    end
  else
    def self.unix_socket_abstract_name?(path)
      false
    end
  end
  private_class_method :unix_socket_abstract_name?
  def self.unix_server_loop(path, &b)
    unix_server_socket(path) {|serv|
      accept_loop(serv, &b)
    }
  end

  # What the socket classes need from the runtime's sockaddr half: a
  # listener on a host, and getsockname(2) / getpeername(2) as an Addrinfo.
  # (Both used to be read from OUTSIDE the process -- lsof(8), /proc -- about
  # 35 ms a socket; compiler v0.1.555 asks the kernel.)
  module Endpoint__
    # A local address asked for before a connect is honoured only when it is
    # the one the kernel chose anyway: a chosen port cannot be (bind(2)), and
    # a different address is refused, the socket closed, rather than reported
    # as bound.
    def self.check_local(sock, host, port)
      if port && port != 0 && port != "0"
        sock.close
        raise NotImplementedError, "connecting from a chosen local port is not implemented (bind(2) takes a sockaddr)"
      end
      return if host.nil? || host == "" || host == "0.0.0.0" || host == "::"
      want = Addrinfo.__getaddrinfo(host, nil, 0, 0, 0, 0, false)[0].ip_address
      got = sock.local_address.ip_address
      if got != want
        sock.close
        raise NotImplementedError, "the kernel connected from #{got}, not the requested #{want} (bind(2) takes a sockaddr)"
      end
    end
    # The address family the KERNEL means. The constants above are the values
    # of the platform they were read from (macOS); AF_INET is 2 everywhere, but
    # AF_INET6 is 30 on macOS and 10 on Linux, and socket(2) is asked in the
    # host's own numbers.
    def self.kernel_family(f)
      return f unless f == Socket::AF_INET6
      RUBY_PLATFORM.include?("linux") ? 10 : f
    end

    # TCPServer's host, as rsock_addrinfo's host_str reads it: nil is NULL
    # (every wildcard, :: first), "" and "<any>" are INADDR_ANY and
    # "<broadcast>" INADDR_BROADCAST; anything else goes to getaddrinfo(3)
    # as it is. A host that does not resolve is this library's own resolver's
    # error (the runtime's is a code without text).
    def self.listen_at(host, port, portnum, backlog)
      h = case host
          when nil then ""
          when "", "<any>" then "0.0.0.0"
          when "<broadcast>" then "255.255.255.255"
          else host.to_s
          end
      fd = Socket.__listen_at(h, portnum, backlog)
      if fd.nil?
        Addrinfo.__getaddrinfo(h, portnum, 0, Socket::SOCK_STREAM, 0, Socket::AI_PASSIVE, false)
        raise SocketError, "getaddrinfo(3): nodename nor servname provided, or not known"
      end
      raise SystemCallError.new("bind(2) for #{host.inspect} port #{port}", -fd) if fd < 0
      fd
    end
    # "<family> <port> <address>" -- the runtime's getsockname(2) /
    # getpeername(2) -- as an Addrinfo, or the errno it came back with
    def self.addrinfo(t, what, socktype)
      raise SystemCallError.new(what, -t) if t.is_a?(Integer)
      fam, port, host = t.split(" ", 3)
      return Addrinfo.unix(host.to_s, socktype) if fam == "unix"
      family = fam == "inet6" ? Socket::AF_INET6 : Socket::AF_INET
      sa = Addrinfo.__getaddrinfo(host, port.to_i, family, 0, 0, Socket::AI_NUMERICHOST, true)[0].to_sockaddr
      Addrinfo.new(sa, family, socktype, 0)
    end
  end
end

class Addrinfo
  # The sockaddr is kept as the C struct's BYTES, as CRuby keeps it, in the
  # BSD layout the constants come from: sin_len and sin_family are one byte
  # each, then the port big-endian.
  SIN_LEN__ = 16
  SIN6_LEN__ = 28
  SUN_LEN__ = 106
  GAI_MSG__ = {
    1 => "Address family for nodename not supported", 2 => "Temporary failure in name resolution",
    3 => "Invalid value for ai_flags", 4 => "Non-recoverable failure in name resolution",
    5 => "ai_family not supported", 6 => "Memory allocation failure",
    7 => "No address associated with nodename", 8 => "nodename nor servname provided, or not known",
    9 => "servname not supported for ai_socktype", 10 => "ai_socktype not supported",
    11 => "System error", 12 => "Bad hints", 13 => "Resolved protocol is unknown",
    14 => "Argument buffer overflow",
  }
  def self.__gai_error(what, code)
    raise Socket::ResolutionError.new("#{what}: #{GAI_MSG__[code]}", code)
  end

  # ---- the addresses themselves ----------------------------------------
  # inet_pton(3), strictly: four decimal octets, no leading zeros.
  def self.__pton4(s)
    parts = s.split(".", -1)
    return nil unless parts.length == 4
    out = []
    parts.each do |p|
      return nil unless p =~ /\A\d{1,3}\z/
      return nil if p.length > 1 && p[0] == "0"
      v = p.to_i
      return nil if v > 255
      out << v
    end
    out.pack("C4")
  end
  # inet_aton(3), which getaddrinfo(3) also accepts for a numeric host:
  # one to four parts, each decimal, 0-octal or 0x-hex, the last one filling
  # the bytes that remain.
  def self.__aton(s)
    parts = s.split(".", -1)
    return nil if parts.empty? || parts.length > 4
    vals = parts.map do |p|
      if p =~ /\A0[xX]\h*\z/ then p[2..-1].to_i(16)
      elsif p =~ /\A0[0-7]*\z/ then p.to_i(8)
      elsif p =~ /\A[1-9]\d*\z/ then p.to_i
      else return nil
      end
    end
    last = vals.pop
    return nil if vals.any? { |v| v > 255 }
    rest = 4 - vals.length
    return nil if last >= 256 ** rest
    n = 0
    vals.each { |v| n = n * 256 + v }
    n = n * (256 ** rest) + last
    [n].pack("N")
  end
  # inet_pton(3) for AF_INET6, with the dotted IPv4 tail it allows.
  def self.__pton6(s)
    return nil if s.empty? || s.count(":") < 2
    tail = nil
    if s.include?(".")
      i = s.rindex(":")
      tail = __pton4(s[(i + 1)..-1])
      return nil if tail.nil?
      s = s[0..i] + "0:0"
    end
    halves = s.split("::", -1)
    return nil if halves.length > 2
    parse = lambda do |part|
      return [] if part.empty?
      g = part.split(":", -1)
      g.map { |x| return nil unless x =~ /\A\h{1,4}\z/; x.to_i(16) }
    end
    if halves.length == 2
      a = parse.call(halves[0])
      b = parse.call(halves[1])
      return nil if a.nil? || b.nil? || a.length + b.length > 7
      words = a + [0] * (8 - a.length - b.length) + b
    else
      words = parse.call(halves[0])
      return nil if words.nil? || words.length != 8
    end
    raw = words.pack("n8")
    raw = raw[0, 12] + tail if tail
    raw
  end
  # inet_ntop(3) for AF_INET6, BSD's: the longest run of two or more zero
  # words becomes "::" (the first, on a tie), and an address whose first 96
  # bits are zero -- or ::ffff: before its last 32 -- ends in dotted IPv4,
  # except when that would spell ::1 or ::a.b (the run is then 7 words).
  def self.__ntop6(raw)
    w = raw.unpack("n8")
    best = -1
    bestlen = 0
    i = 0
    while i < 8
      if w[i] == 0
        j = i
        j += 1 while j < 8 && w[j] == 0
        if j - i > bestlen
          best = i
          bestlen = j - i
        end
        i = j
      else
        i += 1
      end
    end
    if bestlen < 2
      best = -1
      bestlen = 0
    end
    out = +""
    i = 0
    while i < 8
      if best >= 0 && i >= best && i < best + bestlen
        out << ":" if i == best
        i += 1
        next
      end
      out << ":" if i != 0
      if i == 6 && best == 0 && (bestlen == 6 || (bestlen == 5 && w[5] == 0xffff))
        out << raw[12, 4].unpack("C4").join(".")
        break
      end
      out << w[i].to_s(16)
      i += 1
    end
    out << ":" if best >= 0 && best + bestlen == 8
    out
  end
  def self.__sin(addr4, port)
    [SIN_LEN__, Socket::AF_INET, port].pack("CCn") + addr4 + ("\0" * 8)
  end
  def self.__sin6(addr16, port, scope = 0)
    [SIN6_LEN__, Socket::AF_INET6, port, 0].pack("CCnN") + addr16 + [scope].pack("L")
  end
  def self.__unix_sockaddr(path)
    if path.bytesize > SUN_LEN__ - 2
      raise ArgumentError, "too long unix socket path (#{path.bytesize} bytes given but #{SUN_LEN__ - 2} bytes max)"
    end
    ([SUN_LEN__, Socket::AF_UNIX].pack("CC") + path.b + ("\0" * (SUN_LEN__ - 2 - path.bytesize))).b
  end

  # ---- getaddrinfo(3) ----------------------------------------------------
  # /etc/hosts and /etc/services are the "files" half of what the C library
  # resolves through. A name neither answers is not looked up anywhere else:
  # there is no DNS client in here, and saying "not known" is the refusal
  # getaddrinfo itself gives.
  def self.__hosts
    @__hosts ||= begin
      list = []
      (File.read("/etc/hosts") rescue "").each_line do |l|
        l = l.sub(/#.*/, "").strip
        next if l.empty?
        f = l.split
        list << [f[0], f[1..-1]]
      end
      list
    end
  end
  def self.__services
    @__services ||= begin
      list = []
      (File.read("/etc/services") rescue "").each_line do |l|
        l = l.sub(/#.*/, "").strip
        next if l.empty?
        f = l.split
        port, proto = f[1].to_s.split("/")
        next unless proto
        list << [f[0], port.to_i, proto, f[2..-1]]
      end
      list
    end
  end
  def self.__service_port(name, proto)
    __services.each do |n, port, pr, aliases|
      return port if pr == proto && (n == name || aliases.include?(name))
    end
    nil
  end
  def self.__service_name(port, proto)
    __services.each { |n, p, pr, _| return n if p == port && pr == proto }
    nil
  end
  # A port argument as the socket methods take one: an Integer, or a
  # service name looked up in /etc/services.
  def self.__port_of(port, proto)
    return 0 if port.nil?
    return port if port.is_a?(Integer)
    # a service is StringValue'd, as rsock_getaddrinfo's port_str does: an
    # object with #to_str is that string, not its #to_s, and one without is
    # refused. An empty service is no service -- the port is the kernel's.
    s = IO.__fd_str(port)
    return 0 if s.empty?
    return s.to_i if s =~ /\A\d+\z/
    p = __service_port(s, proto)
    __gai_error("getaddrinfo", 8) if p.nil?
    p
  end
  def self.__reverse_name(ai)
    ip = ai.ip_address
    __hosts.each { |addr, names| return names[0] if addr == ip }
    ip
  end

  # One result: [family, socktype, protocol, sockaddr, canonname].
  NUMERIC_LIST__ = [[1, 6], [2, 17], [3, 0]]
  def self.__numeric_port(service)
    return 0 if service.nil?
    return nil unless service =~ /\A\d*\z/
    v = service.to_i
    v >= 0x10000 ? nil : v
  end
  # raddrinfo.c's numeric_getaddrinfo: the fast path CRuby takes before the
  # C library, for a numeric host and a numeric (or no) service.
  def self.__numeric_gai(node, service, family, socktype, protocol)
    return nil if node.nil?
    port = __numeric_port(service)
    return nil if port.nil?
    res = []
    if (family == 0 || family == Socket::AF_INET6) && node =~ /\A[0-9a-fA-F.:]*\z/ && (a6 = __pton6(node))
      NUMERIC_LIST__.each do |st, pr|
        if (socktype == 0 || socktype == st) && (protocol == 0 || pr == 0 || protocol == pr)
          res << [Socket::AF_INET6, st, protocol != 0 ? protocol : pr, __sin6(a6, port), nil]
        end
      end
    elsif (family == 0 || family == Socket::AF_INET) && node =~ /\A[0-9.]*\z/ && (a4 = __pton4(node))
      NUMERIC_LIST__.each do |st, pr|
        if (socktype == 0 || socktype == st) && (protocol == 0 || pr == 0 || protocol == pr)
          res << [Socket::AF_INET, st, protocol != 0 ? protocol : pr, __sin(a4, port), nil]
        end
      end
    end
    res.empty? ? nil : res
  end
  # ...and what the C library answers when the fast path does not: the
  # socket types it knows (DGRAM before STREAM when none is asked for, as
  # macOS lists them), the protocol each one allows, the service looked up
  # per protocol, then the host as a number or a name in /etc/hosts.
  def self.__system_gai(node, service, family, socktype, protocol, flags)
    unless family == 0 || family == Socket::AF_INET || family == Socket::AF_INET6
      __gai_error("getaddrinfo", 5)
    end
    __gai_error("getaddrinfo", 8) if node.nil? && service.nil?
    types = case socktype
      when 0
        t = [[2, 17], [1, 6]]
        if protocol != 0
          t = t.select { |_, pr| pr == protocol }
          __gai_error("getaddrinfo", 12) if t.empty?
        end
        t
      when 1 then (protocol == 0 || protocol == 6) ? [[1, 6]] : __gai_error("getaddrinfo", 12)
      when 2 then (protocol == 0 || protocol == 17) ? [[2, 17]] : __gai_error("getaddrinfo", 12)
      when 3 then [[3, protocol]]
      else __gai_error("getaddrinfo", 12)
    end
    ports = {}
    types.each do |st, pr|
      if service.nil?
        ports[st] = 0
      elsif service =~ /\A\d+\z/
        v = service.to_i
        __gai_error("getaddrinfo", 8) if v >= 0x10000
        ports[st] = v
      elsif st == 3
        __gai_error("getaddrinfo", 9)
      else
        v = __service_port(service, st == 1 ? "tcp" : "udp")
        ports[st] = v if v
      end
    end
    __gai_error("getaddrinfo", 8) if ports.empty?
    addrs = []
    canon = nil
    if node.nil?
      passive = (flags & Socket::AI_PASSIVE) != 0
      addrs << [Socket::AF_INET6, passive ? ("\0" * 16).b : __pton6("::1")]
      addrs << [Socket::AF_INET, passive ? ("\0" * 4).b : __pton4("127.0.0.1")]
    elsif (a6 = __pton6(node))
      addrs << [Socket::AF_INET6, a6]
    elsif (a4 = __aton(node))
      addrs << [Socket::AF_INET, a4]
    elsif (flags & Socket::AI_NUMERICHOST) != 0
      __gai_error("getaddrinfo", 8)
    else
      v6 = []
      v4 = []
      __hosts.each do |addr, names|
        next unless names.include?(node)
        canon ||= names[0]
        if (a = __pton6(addr))
          v6 << [Socket::AF_INET6, a]
        elsif (a = __pton4(addr))
          v4 << [Socket::AF_INET, a]
        end
      end
      addrs = v6 + v4
    end
    addrs = addrs.select { |f, _| family == 0 || f == family }
    __gai_error("getaddrinfo", 8) if addrs.empty?
    res = []
    addrs.each do |f, a|
      types.each do |st, pr|
        next unless ports.key?(st)
        sa = f == Socket::AF_INET6 ? __sin6(a, ports[st]) : __sin(a, ports[st])
        res << [f, st, pr, sa, nil]
      end
    end
    if (flags & Socket::AI_CANONNAME) != 0 && !res.empty?
      res[0][4] = canon || node
    end
    res
  end
  def self.__host_str(host)
    return nil if host.nil?
    if host.is_a?(Integer)
      return [host].pack("N").unpack("C4").join(".")
    end
    s = host.respond_to?(:to_str) ? host.to_str : (raise TypeError, "no implicit conversion of #{host.class} into String")
    # (a C string: StringValueCStr refuses a NUL in it)
    raise ArgumentError, "string contains null byte" if s.include?("\0")
    return "0.0.0.0" if s.empty? || s == "<any>"
    return "255.255.255.255" if s == "<broadcast>"
    s
  end
  def self.__port_str(port)
    return nil if port.nil?
    return port.to_s if port.is_a?(Integer)
    s = port.to_str
    raise ArgumentError, "string contains null byte" if s.include?("\0")
    s
  end
  # rsock_getaddrinfo: the list of results, each [family, socktype, protocol,
  # sockaddr, canonname].
  def self.__gai(host, port, family, socktype, protocol, flags, socktype_hack)
    node = __host_str(host)
    service = __port_str(port)
    socktype = 2 if socktype_hack && socktype == 0 && service =~ /\A\d+\z/
    res = __numeric_gai(node, service, family, socktype, protocol)
    return res if res
    if node && node.end_with?("\n")
      raise SocketError, "newline at the end of hostname"
    end
    # a Fiber scheduler's #address_resolve answers for a name, as
    # rb_scheduler_getaddrinfo asks it: each address it gives is looked up
    # as a number (one that does not fit the hints is skipped), nil or
    # none left is EAI_NONAME; a scheduler without the hook is not asked
    if node && (flags & Socket::AI_NUMERICHOST) == 0 && (sch = Fiber.current_scheduler) && sch.respond_to?(:address_resolve)
      addrs = sch.address_resolve(node)
      __gai_error("getaddrinfo", 8) if addrs.nil?
      res = []
      addrs.each { |a| r = __numeric_gai(a.to_str, service, family, socktype, protocol); res.concat(r) if r }
      __gai_error("getaddrinfo", 8) if res.empty?
      return res
    end
    # macOS: a service of "0" is passed as none at all.
    service = nil if node && service =~ /\A\d+\z/ && service.to_i == 0
    res = __system_gai(node, service, family, socktype, protocol, flags)
    res.each do |r|
      r[1] = socktype if r[1] == 0
      r[2] = (r[1] == 2 ? 17 : r[1] == 1 ? 6 : 0) if r[2] == 0
    end
    res
  end
  def self.__getaddrinfo(host, port, family, socktype, protocol, flags, socktype_hack)
    __gai(host, port, family, socktype, protocol, flags, socktype_hack).map do |f, st, pr, sa, canon|
      ai = allocate
      ai.__init(sa, f, st, pr, canon, nil)
      ai
    end
  end
  # make_inspectname: what the caller wrote, where it differs from what the
  # numeric address and port already show.
  def self.__inspectname(node, service, sa)
    ai = allocate
    ai.__init(sa, 0, 0, 0, nil, nil)
    h, p = ai.__numeric_pair
    node = nil if node.is_a?(String) && h == node
    if service.is_a?(String) && p == service
      service = nil
    elsif service.is_a?(Integer) && p.to_i == service
      service = nil
    end
    name = node.is_a?(String) ? node.dup : nil
    if service.is_a?(String)
      name = (name || "") + ":" + service
    elsif service.is_a?(Integer) && service != 0
      name = (name || "") + ":" + service.to_s
    end
    name && name.freeze
  end

  def self.getaddrinfo(node, service, family = nil, socktype = nil, protocol = nil, flags = nil, timeout: nil)
    fam = family.nil? ? 0 : Socket::Constants.__family_arg(family)
    st = socktype.nil? ? 0 : Socket::Constants.__socktype_arg(socktype)
    pr = protocol.nil? ? 0 : Socket::Constants.__int(protocol)
    fl = flags.nil? ? 0 : Socket::Constants.__int(flags)
    res = __gai(node, service, fam, st, pr, fl, false)
    iname = __inspectname(node, service, res[0][3])
    res.map do |f, s, p, sa, canon|
      ai = allocate
      ai.__init(sa, f, s, p, canon && canon.dup.freeze, iname)
      ai
    end
  end
  def self.__firstonly(node, service, family, socktype, protocol, flags)
    res = __gai(node, service, family, socktype, protocol, flags, false)
    f, s, p, sa, canon = res[0]
    ai = allocate
    ai.__init(sa, f, s, p, canon && canon.dup.freeze, __inspectname(node, service, sa))
    ai
  end
  def self.ip(host)
    ai = __firstonly(host, nil, 0, 0, 0, 0)
    ai.__init(ai.to_sockaddr, ai.afamily, 0, 0, ai.canonname, ai.__inspect_name)
    ai
  end
  def self.tcp(host, port)
    __firstonly(host, port, 0, Socket::SOCK_STREAM, Socket::IPPROTO_TCP, 0)
  end
  def self.udp(host, port)
    __firstonly(host, port, 0, Socket::SOCK_DGRAM, Socket::IPPROTO_UDP, 0)
  end
  def self.unix(path, socktype = nil)
    st = socktype.nil? ? Socket::SOCK_STREAM : Socket::Constants.__socktype_arg(socktype)
    ai = allocate
    ai.__init(__unix_sockaddr(path.to_str), Socket::PF_UNIX, st, 0, nil, nil)
    ai
  end
  def self.foreach(nodename, service, family = nil, socktype = nil, protocol = nil, flags = nil, timeout: nil, &block)
    getaddrinfo(nodename, service, family, socktype, protocol, flags, timeout: timeout).each(&block)
  end

  def __init(sa, pfamily, socktype, protocol, canonname, inspectname)
    @sockaddr = sa.b
    @pfamily = pfamily
    @socktype = socktype
    @protocol = protocol
    @canonname = canonname
    @inspectname = inspectname
    self
  end
  def __inspect_name
    @inspectname
  end

  def initialize(sockaddr, family = nil, socktype = nil, protocol = nil)
    raise TypeError, "already initialized socket address" if @sockaddr
    pf = family.nil? ? 0 : Socket::Constants.__family_arg(family)
    st = socktype.nil? ? 0 : Socket::Constants.__socktype_arg(socktype)
    pr = protocol.nil? ? 0 : Socket::Constants.__int(protocol)
    ary = sockaddr.is_a?(Array) ? sockaddr : (sockaddr.respond_to?(:to_ary) ? sockaddr.to_ary : nil)
    if ary
      afs = ary[0]
      afs = afs.to_str unless afs.is_a?(String)
      af = Socket::Constants.__lookup(afs, /\A(AF_|PF_)/, /\AAF_/)
      raise SocketError, "unknown address family: #{afs}" if af.nil?
      if af == Socket::AF_INET || af == Socket::AF_INET6
        service = Socket::Constants.__int(ary[1])
        nodename = ary[2]
        nodename = nodename.to_str unless nodename.nil? || nodename.is_a?(String)
        numeric = ary[3]
        numeric = numeric.to_str unless numeric.is_a?(String)
        fam = pf != 0 ? pf : af
        res = Addrinfo.__gai(numeric, service, fam, st, pr, Socket::AI_NUMERICHOST | Socket::AI_NUMERICSERV, true)
        iname = numeric == nodename ? nil : Addrinfo.__inspectname(nodename, service, res[0][3])
        canon = res[0][4]
        __init(res[0][3], fam, st, pr, canon && canon.dup.freeze, iname)
      elsif af == Socket::AF_UNIX
        path = ary[1]
        path = path.to_str unless path.is_a?(String)
        __init(Addrinfo.__unix_sockaddr(path), Socket::PF_UNIX, Socket::SOCK_STREAM, 0, nil, nil)
      else
        raise SocketError, "unexpected address family"
      end
    else
      s = sockaddr.is_a?(String) ? sockaddr : sockaddr.to_str
      __init(s, pf, st, pr, nil, nil)
    end
  end

  def afamily
    @sockaddr.bytesize >= 2 ? @sockaddr.getbyte(1) : Socket::AF_UNSPEC
  end
  attr_reader :pfamily, :socktype, :protocol, :canonname
  def to_sockaddr
    @sockaddr.dup
  end
  alias to_s to_sockaddr
  def ip?
    f = afamily
    f == Socket::AF_INET || f == Socket::AF_INET6
  end
  def ipv4?
    afamily == Socket::AF_INET
  end
  def ipv6?
    afamily == Socket::AF_INET6
  end
  def unix?
    afamily == Socket::AF_UNIX
  end

  # getnameinfo(NI_NUMERICHOST|NI_NUMERICSERV): the address and port text.
  def __numeric_pair
    case afamily
    when Socket::AF_INET
      Addrinfo.__gai_error("getnameinfo", 5) if @sockaddr.bytesize < SIN_LEN__
      [@sockaddr[4, 4].unpack("C4").join("."), @sockaddr[2, 2].unpack1("n").to_s]
    when Socket::AF_INET6
      Addrinfo.__gai_error("getnameinfo", 5) if @sockaddr.bytesize < SIN6_LEN__
      h = __ntop6_text
      [h, @sockaddr[2, 2].unpack1("n").to_s]
    else
      Addrinfo.__gai_error("getnameinfo", 5)
    end
  end
  def __ntop6_text
    raw = @sockaddr[8, 16]
    h = Addrinfo.__ntop6(raw)
    scope = @sockaddr[24, 4].unpack1("L")
    h += "%" + (Addrinfo.__ifname(scope) || scope.to_s) if scope != 0
    h
  end
  # the interface a scope id names, as getnameinfo(3) writes it (its
  # if_indextoname), from the interface list; nil for an index none has
  def self.__ifname(idx)
    t = Socket.__ifaddrs
    return nil unless t.is_a?(String)
    t.each_line do |l|
      n, i, = l.split("\t", 3)
      return n if i.to_i == idx
    end
    nil
  end
  def getnameinfo(flags = 0)
    fl = Socket::Constants.__int(flags)
    fl |= Socket::NI_DGRAM if @socktype == Socket::SOCK_DGRAM
    h, p = __numeric_pair
    if (fl & Socket::NI_NUMERICHOST) == 0
      name = nil
      Addrinfo.__hosts.each { |addr, names| (name = names[0]; break) if addr == h }
      Addrinfo.__gai_error("getnameinfo", 8) if name.nil? && (fl & Socket::NI_NAMEREQD) != 0
      h = name if name
    end
    if (fl & Socket::NI_NUMERICSERV) == 0
      s = Addrinfo.__service_name(p.to_i, (fl & Socket::NI_DGRAM) != 0 ? "udp" : "tcp")
      p = s if s
    end
    [h, p]
  end
  def ip_unpack
    raise SocketError, "need IPv4 or IPv6 address" unless ip?
    h, p = __numeric_pair
    [h, p.to_i]
  end
  def ip_address
    raise SocketError, "need IPv4 or IPv6 address" unless ip?
    __numeric_pair[0]
  end
  def ip_port
    raise SocketError, "need IPv4 or IPv6 address" unless ip?
    if afamily == Socket::AF_INET
      raise SocketError, "unexpected sockaddr size for IPv4" if @sockaddr.bytesize != SIN_LEN__
    else
      raise SocketError, "unexpected sockaddr size for IPv6" if @sockaddr.bytesize != SIN6_LEN__
    end
    @sockaddr[2, 2].unpack1("n")
  end

  def __in4
    ipv4? && @sockaddr.bytesize >= 8 ? @sockaddr[4, 4].unpack1("N") : nil
  end
  def __in6
    ipv6? && @sockaddr.bytesize >= 24 ? @sockaddr[8, 16].unpack("C16") : nil
  end
  def ipv4_private?
    a = __in4
    return false unless a
    (a & 0xff000000) == 0x0a000000 || (a & 0xfff00000) == 0xac100000 || (a & 0xffff0000) == 0xc0a80000
  end
  def ipv4_loopback?
    a = __in4
    a ? (a & 0xff000000) == 0x7f000000 : false
  end
  def ipv4_multicast?
    a = __in4
    a ? (a & 0xf0000000) == 0xe0000000 : false
  end
  def ipv6_unspecified?
    b = __in6
    b ? b.all?(&:zero?) : false
  end
  def ipv6_loopback?
    b = __in6
    b ? b[0, 15].all?(&:zero?) && b[15] == 1 : false
  end
  def ipv6_multicast?
    b = __in6
    b ? b[0] == 0xff : false
  end
  def ipv6_linklocal?
    b = __in6
    b ? b[0] == 0xfe && (b[1] & 0xc0) == 0x80 : false
  end
  def ipv6_sitelocal?
    b = __in6
    b ? b[0] == 0xfe && (b[1] & 0xc0) == 0xc0 : false
  end
  def ipv6_unique_local?
    b = __in6
    b ? (b[0] & 0xfe) == 0xfc : false
  end
  def ipv6_v4mapped?
    b = __in6
    b ? b[0, 10].all?(&:zero?) && b[10] == 0xff && b[11] == 0xff : false
  end
  def ipv6_v4compat?
    b = __in6
    return false unless b && b[0, 12].all?(&:zero?)
    v = (b[12] << 24) | (b[13] << 16) | (b[14] << 8) | b[15]
    v != 0 && v != 1
  end
  def __mc_scope?(scope)
    b = __in6
    b ? b[0] == 0xff && (b[1] & 0x0f) == scope : false
  end
  def ipv6_mc_nodelocal?
    __mc_scope?(1)
  end
  def ipv6_mc_linklocal?
    __mc_scope?(2)
  end
  def ipv6_mc_sitelocal?
    __mc_scope?(5)
  end
  def ipv6_mc_orglocal?
    __mc_scope?(8)
  end
  def ipv6_mc_global?
    __mc_scope?(0x0e)
  end
  def ipv6_to_ipv4
    return nil unless ipv6?
    return nil unless ipv6_v4mapped? || ipv6_v4compat?
    ai = Addrinfo.allocate
    ai.__init(Addrinfo.__sin(@sockaddr[20, 4], 0), Socket::PF_INET, @socktype, @protocol, @canonname, @inspectname)
    ai
  end

  # unixsocket_len: the path is what is left once the trailing NULs go.
  def __unix_len
    return -1 if @sockaddr.bytesize < 2
    e = @sockaddr.bytesize
    e -= 1 while e > 2 && @sockaddr.getbyte(e - 1) == 0
    e - 2
  end
  def unix_path
    raise SocketError, "need AF_UNIX address" unless unix?
    n = __unix_len
    @sockaddr[2, n]
  end

  def inspect_sockaddr
    sa = @sockaddr
    len = sa.bytesize
    return "empty-sockaddr" if len == 0
    return "too-short-sockaddr" if len < 2
    case sa.getbyte(1)
    when Socket::AF_UNSPEC
      "UNSPEC"
    when Socket::AF_INET
      out = +""
      out << (len >= 5 ? sa.getbyte(4).to_s : "?")
      out << (len >= 6 ? ".#{sa.getbyte(5)}" : ".?")
      out << (len >= 7 ? ".#{sa.getbyte(6)}" : ".?")
      out << (len >= 8 ? ".#{sa.getbyte(7)}" : ".?")
      if len > 4
        port = sa[2, 2].unpack1("n")
        out << ":#{port}" if port != 0
      else
        out << ":?"
      end
      out << " (#{len} bytes for #{SIN_LEN__} bytes sockaddr_in)" if len != SIN_LEN__
      out
    when Socket::AF_INET6
      return "too-short-AF_INET6-sockaddr #{len} bytes" if len < SIN6_LEN__
      h = __ntop6_text
      port = sa[2, 2].unpack1("n")
      out = port == 0 ? h : "[#{h}]:#{port}"
      out += "(sockaddr #{len - SIN6_LEN__} bytes too long)" if len > SIN6_LEN__
      out
    when Socket::AF_UNIX
      n = __unix_len
      return "too-short-AF_UNIX-sockaddr" if n < 0
      return "empty-path-AF_UNIX-sockaddr" if n == 0
      path = sa[2, n]
      if path.bytes.all? { |c| c > 0x20 && c < 0x7f }
        (path.getbyte(0) == 0x2f ? "" : "UNIX ") + path
      else
        "UNIX" + path.bytes.map { |c| format(":%02x", c) }.join
      end
    else
      id = Socket::Constants.__intern(sa.getbyte(1), /\AAF_/)
      id ? "#{id} address format unknown" : "unknown address family #{sa.getbyte(1)}"
    end
  end
  def inspect
    out = "#<#{self.class}: " + inspect_sockaddr
    if @pfamily != 0 && afamily != @pfamily
      id = Socket::Constants.__intern(@pfamily, /\APF_/)
      out << (id ? " #{id}" : " PF_???(#{@pfamily})")
    end
    internet = @pfamily == Socket::PF_INET || @pfamily == Socket::PF_INET6
    if internet && @socktype == Socket::SOCK_STREAM && (@protocol == 0 || @protocol == Socket::IPPROTO_TCP)
      out << " TCP"
    elsif internet && @socktype == Socket::SOCK_DGRAM && (@protocol == 0 || @protocol == Socket::IPPROTO_UDP)
      out << " UDP"
    else
      if @socktype != 0
        id = Socket::Constants.__intern(@socktype, /\ASOCK_/)
        out << (id ? " #{id}" : " SOCK_???(#{@socktype})")
      end
      if @protocol != 0
        id = internet ? Socket::Constants.__intern(@protocol, /\AIPPROTO_/) : nil
        out << (id ? " #{id}" : " UNKNOWN_PROTOCOL(#{@protocol})")
      end
    end
    out << " #{@canonname}" if @canonname
    out << " (#{@inspectname})" if @inspectname
    out << ">"
  end

  def marshal_dump
    af = afamily
    pf = Socket::Constants.__intern(@pfamily, /\APF_/)
    raise SocketError, "unknown protocol family: #{@pfamily}" if pf.nil?
    st = 0
    if @socktype != 0
      st = Socket::Constants.__intern(@socktype, /\ASOCK_/)
      raise SocketError, "unknown socktype: #{@socktype}" if st.nil?
    end
    pr = 0
    if @protocol != 0
      raise SocketError, "unknown protocol: #{@protocol}" unless Socket::Constants.__ip_family?(af)
      pr = Socket::Constants.__intern(@protocol, /\AIPPROTO_/)
      raise SocketError, "unknown IP protocol: #{@protocol}" if pr.nil?
    end
    afs = Socket::Constants.__intern(af, /\AAF_/)
    raise SocketError, "unknown address family: #{af}" if afs.nil?
    sa = af == Socket::AF_UNIX ? unix_path : __numeric_pair
    [afs, sa, pf, st, pr, @canonname, @inspectname]
  end
  def marshal_load(ary)
    raise TypeError, "already initialized socket address" if @sockaddr
    ary = ary.to_ary
    af = Socket::Constants.__lookup(ary[0].to_str, /\A(AF_|PF_)/, /\AAF_/)
    raise TypeError, "unexpected address family" if af.nil?
    pf = Socket::Constants.__lookup(ary[2].to_str, /\A(AF_|PF_)/, /\AAF_/)
    raise TypeError, "unexpected protocol family" if pf.nil?
    st = ary[3] == 0 ? 0 : Socket::Constants.__lookup(ary[3].to_str, /\ASOCK_/, /\ASOCK_/)
    raise TypeError, "unexpected socktype" if st.nil?
    pr = 0
    if ary[4] != 0
      raise TypeError, "unexpected protocol" unless Socket::Constants.__ip_family?(af)
      pr = Socket::Constants.__lookup(ary[4].to_str, /\AIPPROTO_/, /\AIPPROTO_/)
      raise TypeError, "unexpected protocol" if pr.nil?
    end
    canon = ary[5].nil? ? nil : ary[5].to_str
    iname = ary[6].nil? ? nil : ary[6].to_str
    if af == Socket::AF_UNIX
      sa = Addrinfo.__unix_sockaddr(ary[1].to_str)
    else
      pair = ary[1].to_ary
      sa = Addrinfo.__gai(pair[0], pair[1], pf, st, pr, Socket::AI_NUMERICHOST | Socket::AI_NUMERICSERV, true)[0][3]
    end
    __init(sa, pf, st, pr, canon, iname)
  end

  def family_addrinfo(*args)
    if args.empty?
      raise ArgumentError, "no address specified"
    elsif Addrinfo === args.first
      raise ArgumentError, "too many arguments" if args.length != 1
      addrinfo = args.first
      if (self.pfamily != addrinfo.pfamily) || (self.socktype != addrinfo.socktype)
        raise ArgumentError, "Addrinfo type mismatch"
      end
      addrinfo
    elsif self.ip?
      raise ArgumentError, "IP address needs host and port but #{args.length} arguments given" if args.length != 2
      host, port = args
      Addrinfo.getaddrinfo(host, port, self.pfamily, self.socktype, self.protocol)[0]
    elsif self.unix?
      raise ArgumentError, "UNIX socket needs single path argument but #{args.length} arguments given" if args.length != 1
      path, = args
      Addrinfo.unix(path)
    else
      raise ArgumentError, "unexpected family"
    end
  end
  def connect_internal(local_addrinfo, timeout = nil)
    if timeout && timeout <= 0
      raise Errno::ETIMEDOUT, "user specified timeout for #{ip_address}:#{ip_port}"
    end
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.bind(local_addrinfo) if local_addrinfo
      sock.connect(self)
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close
      end
    else
      sock
    end
  end
  protected :connect_internal
  def connect_from(*args, timeout: nil, &block)
    connect_internal(family_addrinfo(*args), timeout, &block)
  end
  def connect(timeout: nil, &block)
    connect_internal(nil, timeout, &block)
  end
  def connect_to(*args, timeout: nil, &block)
    remote_addrinfo = family_addrinfo(*args)
    remote_addrinfo.connect_internal(self, timeout, &block)
  end
  def bind
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.setsockopt(:SOCKET, :REUSEADDR, 1)
      sock.bind(self)
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close
      end
    else
      sock
    end
  end
  def listen(backlog = Socket::SOMAXCONN)
    sock = Socket.new(self.pfamily, self.socktype, self.protocol)
    begin
      sock.bind(self)
      sock.listen(backlog)
    rescue Exception
      sock.close
      raise
    end
    if block_given?
      begin
        yield sock
      ensure
        sock.close
      end
    else
      sock
    end
  end
end

class Socket < BasicSocket
  class Option
    def initialize(family, level, optname, data)
      @family = Constants.__family_arg(family)
      @level = Constants.__level_arg(@family, level)
      @optname = Constants.__optname_arg(@family, @level, optname)
      @data = data.is_a?(String) ? data : data.to_str
    end
    attr_reader :family, :level, :optname, :data
    alias to_s data
    def self.__new(family, level, optname, data)
      o = allocate
      o.instance_variable_set(:@family, family)
      o.instance_variable_set(:@level, level)
      o.instance_variable_set(:@optname, optname)
      o.instance_variable_set(:@data, data)
      o
    end
    def self.__args(family, level, optname)
      f = Constants.__family_arg(family)
      l = Constants.__level_arg(f, level)
      [f, l, Constants.__optname_arg(f, l, optname)]
    end
    def self.int(family, level, optname, integer)
      f, l, o = __args(family, level, optname)
      __new(f, l, o, [Socket::Constants.__int(integer)].pack("i"))
    end
    def self.byte(family, level, optname, integer)
      f, l, o = __args(family, level, optname)
      __new(f, l, o, [Socket::Constants.__int(integer)].pack("c"))
    end
    def self.bool(family, level, optname, bool)
      f, l, o = __args(family, level, optname)
      __new(f, l, o, [bool ? 1 : 0].pack("i"))
    end
    # IP_MULTICAST_LOOP / IP_MULTICAST_TTL: an int here (rsock's
    # sockopt_ipv4_multicast_*; a byte on the BSDs that take one)
    def self.ipv4_multicast_loop(value)
      int(:INET, :IP, :MULTICAST_LOOP, value)
    end
    def self.ipv4_multicast_ttl(value)
      int(:INET, :IP, :MULTICAST_TTL, value)
    end
    def ipv4_multicast_loop
      unless @family == Socket::AF_INET && @level == Socket::IPPROTO_IP && @optname == Socket::IP_MULTICAST_LOOP
        raise TypeError, "ipv4_multicast_loop socket option expected"
      end
      int
    end
    def ipv4_multicast_ttl
      unless @family == Socket::AF_INET && @level == Socket::IPPROTO_IP && @optname == Socket::IP_MULTICAST_TTL
        raise TypeError, "ipv4_multicast_ttl socket option expected"
      end
      int
    end
    def self.linger(onoff, secs)
      on = onoff.respond_to?(:to_int) ? onoff.to_int : (onoff ? 1 : 0)
      __new(Socket::AF_UNSPEC, Socket::SOL_SOCKET, Socket::SO_LINGER, [on, Socket::Constants.__int(secs)].pack("i2"))
    end
    def __check_size(size, what)
      if @data.bytesize != size
        raise TypeError, "size differ.  expected as #{what}=#{size} but #{@data.bytesize}"
      end
    end
    def int
      __check_size(4, "sizeof(int)")
      @data.unpack1("i")
    end
    def byte
      __check_size(1, "sizeof(char)")
      @data.unpack1("c")
    end
    def bool
      return @data.getbyte(0) != 0 if @data.bytesize == 1
      __check_size(4, "sizeof(int)")
      @data.unpack1("i") != 0
    end
    def linger
      if @level != Socket::SOL_SOCKET || @optname != Socket::SO_LINGER
        raise TypeError, "linger socket option expected"
      end
      __check_size(8, "sizeof(struct linger)")
      on, secs = @data.unpack("i2")
      [on == 0 ? false : on == 1 ? true : on, secs]
    end
    def unpack(template)
      @data.unpack(template)
    end
    INT_SO__ = %w[SO_DEBUG SO_ACCEPTCONN SO_BROADCAST SO_REUSEADDR SO_KEEPALIVE SO_OOBINLINE
                  SO_SNDBUF SO_RCVBUF SO_DONTROUTE SO_RCVLOWAT SO_SNDLOWAT]
    def inspect
      out = "#<#{self.class}:"
      fid = Constants.__intern(@family, /\AAF_/, /\AAF_/)
      out << (fid ? " #{fid}" : " family:#{@family}")
      kind = nil
      if @level == Socket::SOL_SOCKET
        out << " SOCKET"
        oid = Constants.__intern(@optname, /\ASO_/, /\ASO_/)
        out << (oid ? " #{oid}" : " optname:#{@optname}")
        kind = "SO_#{oid}" if oid
      elsif Constants.__ip_family?(@family)
        lid = Constants.__intern(@level, /\A(SOL_SOCKET\z|IPPROTO_)/, /\A(SOL_|IPPROTO_)/)
        out << (lid ? " #{lid}" : " level:#{@level}")
        k = Constants.__level_kind(@family, @level)
        oid = k && Constants.__intern(@optname, Constants.__opt_table(k)[0], Regexp.new("\\A#{k}_"))
        out << (oid ? " #{oid}" : " optname:#{@optname}")
      elsif @family == Socket::AF_UNIX && @level == 0 && defined?(Socket::LOCAL_PEERCRED) &&
            @optname == Socket::LOCAL_PEERCRED && @data.bytesize >= 12
        # (macOS's struct xucred: inspect_local_peercred)
        ver, uid = @data.unpack("L2")
        n = @data.unpack1("s", offset: 8)
        groups = @data.byteslice(12, 4 * n).unpack("L*")
        return out << " level:0 PEERCRED version=#{ver} euid=#{uid} groups=#{groups.join(",")} (xucred)>"
      else
        out << " level:#{@level} optname:#{@optname}"
      end
      if kind == "SO_LINGER" && @data.bytesize == 8
        on, secs = @data.unpack("i2")
        out << (on == 0 ? " off" : on == 1 ? " on" : " on(#{on})")
        out << " #{secs}sec"
      elsif kind && INT_SO__.include?(kind) && @data.bytesize == 4
        out << " #{@data.unpack1('i')}"
      # (IP_MULTICAST_LOOP / _TTL as an int, inspect_ipv4_multicast_*; a
      #  byte where the platform takes one)
      elsif @family == Socket::AF_INET && @level == Socket::IPPROTO_IP &&
            (@optname == Socket::IP_MULTICAST_LOOP || @optname == Socket::IP_MULTICAST_TTL) &&
            (@data.bytesize == 4 || @data.bytesize == 1)
        out << " #{@data.bytesize == 4 ? @data.unpack1('i') : @data.unpack1('C')}"
      else
        out << " " << @data.dump
      end
      out << ">"
    end
  end

  # an interface's entry (ext/socket/ifaddr.c): its name, index, IFF_* flags
  # and the addresses, as Addrinfo or nil
  class Ifaddr
    attr_reader :name, :ifindex, :flags, :addr, :netmask
    def self.__new(name, idx, flags, addr, netmask, broad, dst)
      i = allocate
      i.instance_variable_set(:@name, name)
      i.instance_variable_set(:@ifindex, idx)
      i.instance_variable_set(:@flags, flags)
      i.instance_variable_set(:@addr, addr)
      i.instance_variable_set(:@netmask, netmask)
      i.instance_variable_set(:@broadaddr, broad)
      i.instance_variable_set(:@dstaddr, dst)
      i
    end
    def broadaddr = (@flags & Socket::IFF_BROADCAST) != 0 ? @broadaddr : nil
    def dstaddr = (@flags & Socket::IFF_POINTOPOINT) != 0 ? @dstaddr : nil

    # the runtime's address text as an Addrinfo: an IP address, or a
    # link-layer one as the platform's sockaddr (sockaddr_dl on BSD,
    # sockaddr_ll on Linux) -- nil for none
    def self.__addr(t, name, ifindex)
      return nil if t.nil? || t.empty?
      fam, idx, rest = t.split(" ", 3)
      if fam == "link"
        hw = rest.to_s.split(":").map { |h| h.to_i(16) }
        if RUBY_PLATFORM.include?("linux")
          sa = [Socket::AF_PACKET, 0, idx.to_i, 0, 0, hw.size].pack("S n l S C C") + hw.pack("C*").ljust(8, "\0")
        else
          body = name.b + hw.pack("C*")
          len = [8 + body.bytesize, 20].max
          sa = ([len, Socket::AF_LINK, idx.to_i, 0, name.bytesize, hw.size, 0].pack("C C S C C C C") + body).ljust(len, "\0")
        end
        a = Addrinfo.new(sa)
        a.instance_variable_set(:@__link, [name, hw])
        return a
      end
      return nil unless fam == "inet" || fam == "inet6"
      host, zone = rest.to_s.split("%", 2)
      a = Socket::Endpoint__.addrinfo("#{fam} #{idx} #{host}", "getifaddrs", 0)
      return a if zone.nil?
      # a scoped (link-local) address: the zone is the entry's interface,
      # sin6_scope_id at the same offset on both hosts
      sa = a.to_sockaddr.b
      sa[24, 4] = [ifindex].pack("L")
      Addrinfo.new(sa, Socket::AF_INET6, 0, 0)
    end

    # ruby's ifaddr_inspect_flags order, then any bit it has no name for
    FLAG_NAMES = %w[UP BROADCAST DEBUG LOOPBACK POINTOPOINT RUNNING NOARP PROMISC
                    NOTRAILERS ALLMULTI MASTER SLAVE MULTICAST PORTSEL AUTOMEDIA
                    DYNAMIC LOWER_UP DORMANT ECHO OACTIVE SIMPLEX LINK0 LINK1 LINK2
                    ALTPHYS CANTCONFIG]
    def self.__sockaddr_text(a)
      if (l = a.instance_variable_get(:@__link))
        hw = l[1].map { |b| format("%02x", b) }.join(":")
        return RUBY_PLATFORM.include?("linux") ? "PACKET[#{l[0]}#{hw.empty? ? '' : ' hwaddr=' + hw}]" : "LINK[#{l[0]}#{hw.empty? ? '' : ' ' + hw}]"
      end
      a.inspect_sockaddr
    end
    def inspect
      out = +"#<#{self.class} #{@name}"
      f = @flags
      names = []
      FLAG_NAMES.each do |n|
        next unless Socket.const_defined?("IFF_" + n)
        bit = Socket.const_get("IFF_" + n)
        next if bit == 0 || (f & bit) == 0
        names << n
        f &= ~bit
      end
      names << format("0x%x", f) if f != 0
      out << " " << names.join(",") unless names.empty?
      out << " " << Ifaddr.__sockaddr_text(@addr) if @addr
      out << " netmask=" << Ifaddr.__sockaddr_text(@netmask) if @netmask
      out << " broadcast=" << Ifaddr.__sockaddr_text(broadaddr) if broadaddr
      out << " dstaddr=" << Ifaddr.__sockaddr_text(dstaddr) if dstaddr
      out << ">"
    end
  end

  class AncillaryData
    def initialize(family, level, type, data)
      @family = Constants.__family_arg(family)
      @level = Constants.__level_arg(@family, level)
      @type = Constants.__cmsg_type_arg(@family, @level, type)
      @data = data.is_a?(String) ? data : data.to_str
    end
    attr_reader :family, :level, :type, :data
    def self.__new(family, level, type, data)
      a = allocate
      a.instance_variable_set(:@family, family)
      a.instance_variable_set(:@level, level)
      a.instance_variable_set(:@type, type)
      a.instance_variable_set(:@data, data)
      a
    end
    def self.int(family, level, type, integer)
      f = Constants.__family_arg(family)
      l = Constants.__level_arg(f, level)
      t = Constants.__cmsg_type_arg(f, l, type)
      __new(f, l, t, [Socket::Constants.__int(integer)].pack("i"))
    end
    def int
      if @data.bytesize != 4
        raise TypeError, "size differ.  expected as sizeof(int)=4 but #{@data.bytesize}"
      end
      @data.unpack1("i")
    end
    def cmsg_is?(level, type)
      l = Constants.__level_arg(@family, level)
      t = Constants.__cmsg_type_arg(@family, l, type)
      @level == l && @type == t
    end
    def self.unix_rights(*ios)
      ios.each { |io| raise TypeError, "IO expected" unless io.is_a?(IO) }
      a = __new(Socket::AF_UNIX, Socket::SOL_SOCKET, Socket::SCM_RIGHTS, ios.map(&:fileno).pack("i*"))
      a.instance_variable_set(:@unix_rights, ios)
      a
    end
    def unix_rights
      if @level != Socket::SOL_SOCKET || @type != Socket::SCM_RIGHTS
        raise TypeError, "SCM_RIGHTS ancillary data expected"
      end
      @unix_rights
    end
    def self.__sa(v)
      v.is_a?(Addrinfo) ? v.to_sockaddr : v.to_str
    end
    # struct in_pktinfo is { ifindex, spec_dst, addr }: 4 + 4 + 4 bytes.
    def self.ip_pktinfo(addr, ifindex, spec_dst = nil)
      a = __sa(addr)
      idx = Socket::Constants.__int(ifindex)
      d = spec_dst.nil? ? a : __sa(spec_dst)
      raise ArgumentError, "addr size different to AF_INET sockaddr" if a.bytesize != 16
      raise ArgumentError, "addr is not AF_INET sockaddr" if a.getbyte(1) != Socket::AF_INET
      raise ArgumentError, "spec_dat size different to AF_INET sockaddr" if d.bytesize != 16
      raise ArgumentError, "spec_dst is not AF_INET sockaddr" if d.getbyte(1) != Socket::AF_INET
      __new(Socket::AF_INET, Socket::IPPROTO_IP, Socket::IP_PKTINFO, [idx].pack("L") + d[4, 4] + a[4, 4])
    end
    def ip_pktinfo
      if @level != Socket::IPPROTO_IP || @type != Socket::IP_PKTINFO || @data.bytesize != 12
        raise TypeError, "IP_PKTINFO ancillary data expected"
      end
      idx = @data[0, 4].unpack1("L")
      addr = Addrinfo.allocate.__init(Addrinfo.__sin(@data[8, 4], 0), Socket::PF_INET, 0, 0, nil, nil)
      dst = Addrinfo.allocate.__init(Addrinfo.__sin(@data[4, 4], 0), Socket::PF_INET, 0, 0, nil, nil)
      [addr, idx, dst]
    end
    # struct in6_pktinfo is { addr[16], ifindex }.
    def self.ipv6_pktinfo(addr, ifindex)
      a = __sa(addr)
      idx = Socket::Constants.__int(ifindex)
      raise ArgumentError, "addr size different to AF_INET6 sockaddr" if a.bytesize != 28
      raise ArgumentError, "addr is not AF_INET6 sockaddr" if a.getbyte(1) != Socket::AF_INET6
      __new(Socket::AF_INET6, Socket::IPPROTO_IPV6, Socket::IPV6_PKTINFO, a[8, 16] + [idx].pack("L"))
    end
    def __ipv6_pktinfo
      if @level != Socket::IPPROTO_IPV6 || @type != Socket::IPV6_PKTINFO || @data.bytesize != 20
        raise TypeError, "IPV6_PKTINFO ancillary data expected"
      end
      raw = @data[0, 16]
      idx = @data[16, 4].unpack1("L")
      linklocal = raw.getbyte(0) == 0xfe && (raw.getbyte(1) & 0xc0) == 0x80
      sa = Addrinfo.__sin6(raw, 0, linklocal ? idx : 0)
      [Addrinfo.allocate.__init(sa, Socket::PF_INET6, 0, 0, nil, nil), idx]
    end
    def ipv6_pktinfo
      __ipv6_pktinfo
    end
    def ipv6_pktinfo_addr
      __ipv6_pktinfo[0]
    end
    def ipv6_pktinfo_ifindex
      __ipv6_pktinfo[1]
    end
    # SCM_TIMESTAMP's struct timeval (a long and a suseconds_t: 4 bytes and
    # padding on macOS, 8 on Linux) as a Time
    def timestamp
      unless @level == Socket::SOL_SOCKET && @type == Socket::SCM_TIMESTAMP
        raise TypeError, "SCM_TIMESTAMP ancillary data expected"
      end
      sec, usec = @data.unpack(RUBY_PLATFORM.include?("linux") ? "q q" : "q l")
      Time.at(sec, usec)
    end
    # (anc_inspect: the level and the type by name where they have one, the
    #  descriptors of SCM_RIGHTS, the time of SCM_TIMESTAMP)
    LEVEL_NAMES__ = { "SOL_SOCKET" => "SOCKET", "IPPROTO_IP" => "IP", "IPPROTO_IPV6" => "IPV6",
                      "IPPROTO_TCP" => "TCP", "IPPROTO_UDP" => "UDP" }
    def __level_name
      LEVEL_NAMES__.each { |c, n| return n if Socket.const_defined?(c) && Socket.const_get(c) == @level }
      nil
    end
    def __type_name(lname)
      pre = { "SOCKET" => "SCM_", "IP" => "IP_", "IPV6" => "IPV6_", "TCP" => "TCP_", "UDP" => "UDP_" }[lname]
      return nil unless pre
      c = Socket.constants.map(&:to_s).find { |k| k.start_with?(pre) && Socket.const_get(k) == @type }
      c && c.delete_prefix(pre)
    end
    def inspect
      fid = Constants.__intern(@family, /\AAF_/, /\AAF_/)
      lname = __level_name
      tname = lname && __type_name(lname)
      out = "#<#{self.class}: #{fid || "family:#{@family}"} #{lname || "level:#{@level}"} #{tname || "type:#{@type}"}"
      if lname == "SOCKET" && tname == "RIGHTS" && @data.bytesize % 4 == 0
        out << " " << @data.unpack("i*").join(" ")
      elsif lname == "SOCKET" && tname == "TIMESTAMP" && @data.bytesize >= 12
        t = timestamp
        out << " " << t.strftime("%Y-%m-%d %H:%M:%S") << format(".%06d", t.usec)
      else
        out << " " << @data.inspect
      end
      out << ">"
    end
  end
end
