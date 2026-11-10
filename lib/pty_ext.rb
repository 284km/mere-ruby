# PTY, as ruby's ext/pty answers it, over the runtime's pseudo-terminal
# (Mere v0.1.724's pty_open: posix_openpt, the slave opened O_NOCTTY).
#
# A child gets the slave as its controlling terminal the way pty.c's child
# does -- a new session, then the slave opened by its path as 0, 1 and 2 --
# through Process.spawn's direct path with a new session asked of
# posix_spawn (proc_spawn's group -2), so no fork runs here.
module PTY
  class ChildExited < RuntimeError
    def status = @status
  end

  # [master, slave, the slave's path] from the runtime, or ruby's error
  def self.__fds
    r = IO.__fdpty
    raise SystemCallError.new("openpty", -r) if r.is_a?(Integer)
    r
  end
  private_class_method :__fds

  # a File over a descriptor, named by the path (rb_io_t's pathv)
  def self.__file(fd, mode, path)
    f = File.new(fd, mode)
    f.instance_variable_set(:@__io_path, path)
    f
  end
  private_class_method :__file

  # [master IO, slave File]; with a block, its value, both closed after it.
  # The slave is its owner's alone (pty.c's no_mesg: mode 0600)
  def self.open
    m, s, path = __fds
    File.chmod(0600, path)
    # both ends non-blocking, as IO.pipe's are: a read that would block waits
    # in the layer's readiness loop, so the other threads run meanwhile
    IO.__fdnonblock(m)
    IO.__fdnonblock(s)
    master = IO.new(m, "r+", path: "masterpty:" + path)
    master.sync = true
    slave = __file(s, "r+", path)
    slave.sync = true
    pair = [master, slave]
    return pair unless block_given?
    begin
      yield pair
    ensure
      master.close unless master.closed?
      slave.close unless slave.closed?
    end
  end

  # [read File, write File, pid] of a command run on a new pty's slave; with
  # a block, its value, and the child is detached after it (pty.c's
  # pty_detach_process)
  def self.spawn(*cmd)
    raise ArgumentError, "wrong number of arguments (given 0, expected 1+)" if cmd.empty?
    m, s, path = __fds
    IO.__fdclose(s)
    begin
      # (the master closed in the child: holding it there, the slave never
      #  hangs up when the parent closes its end, and the child never sees
      #  the end of its input -- ruby's master is close-on-exec)
      pid = Process.spawn(*cmd, in: [path, "r+"], out: [:child, 0], err: [:child, 0], m => :close, __pty_session: true)
    rescue SystemCallError => e
      IO.__fdclose(m)
      raise e.class, "fork failed"
    end
    IO.__fdnonblock(m)
    r = __file(m, "r", path)
    w = __file(IO.__fddup(m), "w", path)
    w.sync = true
    res = [r, w, pid]
    return res unless block_given?
    begin
      yield(*res)
    ensure
      Process.detach(pid)
    end
  end

  class << self
    alias getpty spawn
  end

  # the child's status once it has exited or stopped, nil while it runs; with
  # raise, ChildExited carrying it
  def self.check(pid, raise_on_exit = false)
    r = Process.waitpid(pid, Process::WNOHANG | Process::WUNTRACED)
    return nil if r.nil?
    st = $?
    return st unless raise_on_exit
    what = st.stopped? ? "stopped" : st.exited? || st.signaled? ? "exited" : "changed"
    e = ChildExited.new("pty - #{what}: #{pid}")
    e.instance_variable_set(:@status, st)
    raise e
  end
end
