require 'ripper'
require 'stringio'

class StaticRegexp1131 < Ripper
  attr_reader :events
  def initialize(source)
    @events = []
    super(source)
  end
  %i[regexp_beg regexp_new tstring_content regexp_add regexp_end regexp_literal].each do |event|
    define_method("on_#{event}") do |*args|
      @events << [event, args, lineno, column]
      [event, *args]
    end
  end
  def compile_error(message)
    @events << [:compile_error, message, lineno, column, state, token, error?]
  end
  def on_stmts_new = []
  def on_stmts_add(statements, value) = statements << value
  def on_program(statements) = statements
end

class MutateRegexp1131 < Ripper
  attr_reader :errors, :literal
  def initialize(source)
    @errors = []
    super(source)
  end
  def on_tstring_content(token)
    token.replace('a')
    :content
  end
  def on_regexp_end(token)
    token.replace('/n')
    :closing
  end
  def compile_error(message) = @errors << message
  def on_regexp_literal(*arguments)
    @literal = arguments
    nil
  end
end
parser = MutateRegexp1131.new(%q{/[\xC0-\xF0]/u})
parser.parse
p [:callback_mutation, parser.error?, parser.errors, parser.literal]

sources = [
  %q{/a/}, %q{//}, %q{/[z-a]/}, %q{/[\xC0-\xF0]/u},
  %q{/[\xC0-\xF0]/n}, %q{/[\xC0-\xF0]/}, %q{/\xff/u},
  %q{/\xff/n}, %q{/\xC2\xA1/u}, %q{%r{[z-a]}im},
  "\n  /[z-a]/", %q{/[z-a]/; /\xff/u},
  %q{/[z-a]/mix}, %q{/[z-a]/n}, %q{/[z-a]/u}, %q{/[z-a]/e},
  %q{/[z-a]/s}, %q{/[z-a]/o}
]
sources.each do |source|
  parser = StaticRegexp1131.new(source)
  before = parser.error?
  value = parser.parse
  p [source, before, value, parser.error?, parser.events]
end

parser = Ripper.new(%q{/a#{1}[z-a]/})
parser.parse
p [:dynamic, parser.error?]

[%q{/[\xC0-\xF0]/u}, %q{/[\xC0-\xF0]/n}].each do |source|
  parser = Ripper.new(StringIO.new(source))
  parser.parse
  p [:input, source, parser.error?]
  p [:sexp, source, Ripper.sexp(source)]
  begin
    Ripper.sexp(source, raise_errors: true)
    p [:raise_errors, source, :ok]
  rescue SyntaxError => error
    p [:raise_errors, source, error.class.name, error.message]
  end
end

class RaiseRegexp1131 < Ripper
  def compile_error(message) = raise(message)
end
parser = RaiseRegexp1131.new(%q{/[z-a]/})
begin
  parser.parse
rescue RuntimeError => error
  p [:callback, error.message, parser.error?, parser.lineno, parser.column, parser.state, parser.token]
end

class << Regexp
  alias original_new1131 new
  def new(*) = raise('Regexp.new called')
end
begin
  parser = Ripper.new(%q{/[\xC0-\xF0]/u})
  parser.parse
  p [:native_validation, parser.error?]
ensure
  class << Regexp
    alias new original_new1131
    remove_method :original_new1131
  end
end
