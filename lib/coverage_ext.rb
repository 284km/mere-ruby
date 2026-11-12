# Coverage, as mere-ruby answers `require "coverage"` (and "coverage.so"):
# ruby's ext/coverage over the interpreter's own counts -- a line is counted
# where TracePoint's :line fires (the parser's SLine), a method where its
# frame starts. The positions ruby reports for a method (its first and last
# line and column) are its definition's in the source, as Prism reads it.
module Coverage
  def self.supported?(mode)
    raise TypeError, "wrong argument type #{mode.class} (expected Symbol)" unless Symbol === mode
    mode == :lines || mode == :oneshot_lines || mode == :branches || mode == :methods || mode == :eval
  end

  def self.setup(opt = (none = true; nil))
    raise RuntimeError, "coverage measurement is already setup" unless __st == 0
    mode = 0
    if none
    elsif opt == :all
      mode = 1 | 2 | 4 | 16
    else
      h = Hash.try_convert(opt)
      raise TypeError, "no implicit conversion of #{opt.class} into Hash" unless h
      mode |= 1 if h[:lines]
      mode |= 2 if h[:branches]
      mode |= 4 if h[:methods]
      if h[:oneshot_lines]
        raise RuntimeError, "cannot enable lines and oneshot_lines simultaneously" if mode & 1 != 0
        mode |= 1 | 8
      end
      mode |= 16 if h[:eval]
    end
    __set(1, mode)
    nil
  end

  def self.resume
    raise RuntimeError, "coverage measurement is not set up yet" if __st == 0
    raise RuntimeError, "coverage measurement is already running" if __st == 2
    __set(2, __mode)
    nil
  end

  def self.suspend
    raise RuntimeError, "coverage measurement is not running" unless __st == 2
    __set(1, __mode)
    nil
  end

  def self.start(*args)
    setup(*args)
    resume
    nil
  end

  def self.state = [:idle, :suspended, :running][__st]

  def self.running? = __st == 2

  def self.peek_result
    raise RuntimeError, "coverage measurement is not enabled" if __st == 0
    mode = __mode
    res = {}
    __files.each do |f|
      if mode == 0
        res[f] = __lines(f).freeze
      else
        h = {}
        if mode & 1 != 0
          if mode & 8 != 0
            h[:oneshot_lines] = __oneshot(f).freeze
          else
            h[:lines] = __lines(f).freeze
          end
        end
        h[:branches] = {} if mode & 2 != 0
        h[:methods] = {} if mode & 4 != 0
        res[f] = h
      end
    end
    __methods_into(res) if mode & 4 != 0
    res.freeze
  end

  def self.result(opt = (none = true; nil))
    raise RuntimeError, "coverage measurement is not enabled" if __st == 0
    stop = clear = true
    unless none
      h = Hash.try_convert(opt)
      raise TypeError, "no implicit conversion of #{opt.class} into Hash" unless h
      stop = h[:stop] ? true : false
      clear = h[:clear] ? true : false
    end
    if stop && !clear
      warn "stop implies clear", uplevel: 1, category: nil
      clear = true
    end
    r = peek_result
    __clear if clear
    if stop
      __reset
      __set(0, 0)
    end
    r
  end

  def self.line_stub(file) = __stub(file.respond_to?(:to_path) ? file.to_path : file)

  # [owner, name, first line, first column, last line, last column] => calls,
  # for each method a covered file defined -- not an alias (its definition is
  # the original's, which the calls through it count for)
  def self.__methods_into(res)
    st = __st
    __set(0, __mode)
    begin
      require "prism"
    ensure
      __set(st, __mode)
    end
    locs = {}
    __meths.each do |owner, name, file, line, count|
      next unless File.file?(file)
      at = (locs[file] ||= __def_locations(file))[[line, name]]
      next unless at
      res[file][:methods][[owner, name, *at]] = count
    end
  end

  def self.__def_locations(file)
    at = {}
    blocks = {}
    todo = [Prism.parse_file(file).value]
    until todo.empty?
      n = todo.pop
      case n
      when Prism::DefNode
        l = n.location
        at[[l.start_line, n.name]] = [l.start_line, l.start_column, l.end_line, l.end_column]
      when Prism::CallNode
        if n.name == :define_method && n.block.is_a?(Prism::BlockNode) &&
           (a = n.arguments&.arguments&.first).is_a?(Prism::SymbolNode)
          l = n.block.location
          at[[n.location.start_line, a.unescaped.to_sym]] = [l.start_line, l.start_column, l.end_line, l.end_column]
        end
      when Prism::BlockNode, Prism::LambdaNode
        l = n.location
        blocks[l.start_line] ||= [l.start_line, l.start_column, l.end_line, l.end_column]
      end
      todo.concat(n.compact_child_nodes)
    end
    # (a method define_method made from a proc is where the proc was written)
    Hash.new { |h, (line, _)| blocks[line] }.update(at)
  end
end
