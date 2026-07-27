# A tiny Lisp interpreter in Ruby: reader, evaluator, and a small prelude.
# Supports integers, symbols, lists, quote, if, define, lambda, let, and a
# handful of primitives. Deep recursion and closures are the point.

class Reader
  def initialize(src)
    @toks = tokenize(src)
    @pos = 0
  end

  def tokenize(src)
    src.gsub("(", " ( ").gsub(")", " ) ").split
  end

  def eof?
    @pos >= @toks.length
  end

  def read
    tok = @toks[@pos]
    @pos += 1
    case tok
    when "("
      list = []
      until @toks[@pos] == ")"
        raise "unexpected EOF" if eof?
        list << read
      end
      @pos += 1
      list
    when ")"
      raise "unexpected )"
    when /\A-?\d+\z/
      tok.to_i
    else
      tok.to_sym
    end
  end

  def read_all
    forms = []
    forms << read until eof?
    forms
  end
end

class Env
  def initialize(vars = {}, parent = nil)
    @vars = vars
    @parent = parent
  end

  def [](name)
    if @vars.key?(name)
      @vars[name]
    elsif @parent
      @parent[name]
    else
      raise "unbound variable: #{name}"
    end
  end

  def define(name, value)
    @vars[name] = value
  end

  def child(vars)
    Env.new(vars, self)
  end
end

Lambda = Struct.new(:params, :body, :env) do
  def call(args, interp)
    frame = {}
    params.each_with_index { |p, i| frame[p] = args[i] }
    interp.eval(body, env.child(frame))
  end
end

class Interp
  def initialize
    @global = Env.new(prelude)
  end

  def prelude
    {
      :+ => ->(a, b) { a + b },
      :- => ->(a, b) { a - b },
      :* => ->(a, b) { a * b },
      :< => ->(a, b) { a < b },
      :> => ->(a, b) { a > b },
      :"=" => ->(a, b) { a == b },
      :cons => ->(a, b) { [a] + b },
      :car => ->(xs) { xs.first },
      :cdr => ->(xs) { xs.drop(1) },
      :list => ->(*xs) { xs },
      :null? => ->(xs) { xs.empty? },
    }
  end

  def run(src)
    result = nil
    Reader.new(src).read_all.each { |form| result = eval(form, @global) }
    result
  end

  def eval(form, env)
    case form
    when Integer
      form
    when Symbol
      env[form]
    when Array
      head = form.first
      case head
      when :quote
        form[1]
      when :if
        eval(form[1], env) ? eval(form[2], env) : eval(form[3], env)
      when :define
        env.define(form[1], eval(form[2], env))
        form[1]
      when :lambda
        Lambda.new(form[1], form[2], env)
      when :let
        frame = {}
        form[1].each { |pair| frame[pair[0]] = eval(pair[1], env) }
        eval(form[2], env.child(frame))
      else
        fn = eval(head, env)
        args = form.drop(1).map { |a| eval(a, env) }
        apply(fn, args)
      end
    else
      raise "cannot eval: #{form.inspect}"
    end
  end

  def apply(fn, args)
    if fn.is_a?(Lambda)
      fn.call(args, self)
    elsif fn.respond_to?(:call)
      fn.call(*args)
    else
      raise "not callable: #{fn.inspect}"
    end
  end
end

program = <<~'LISP'
  (define fact
    (lambda (n)
      (if (< n 2) 1 (* n (fact (- n 1))))))

  (define fib
    (lambda (n)
      (if (< n 2) n (+ (fib (- n 1)) (fib (- n 2))))))

  (define map
    (lambda (f xs)
      (if (null? xs)
          (quote ())
          (cons (f (car xs)) (map f (cdr xs))))))

  (define range
    (lambda (lo hi)
      (if (> lo hi) (quote ()) (cons lo (range (+ lo 1) hi)))))

  (define double (lambda (x) (* x 2)))

  (list
    (fact 10)
    (fib 15)
    (map double (range 1 8))
    (let ((a 3) (b 4)) (+ (* a a) (* b b))))
LISP

interp = Interp.new
result = interp.run(program)
p result
