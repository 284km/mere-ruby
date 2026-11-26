require 'ripper'

class CallbackAudit1129 < Ripper
  attr_reader :events
  def initialize(source)
    super(source)
    @events = []
  end
  %i[heredoc_beg heredoc_end ignored_nl ident tstring_content].each do |event|
    define_method("on_#{event}") do |value|
      @events << [event, value, lineno, column]
      value
    end
  end
  %i[string_content string_add string_literal blockarg params].each do |event|
    define_method("on_#{event}") do |*values|
      @events << [event, values]
      [event, *values]
    end
  end
end

[
  "<<EOS\nheredoc\nEOS\n",
  "<<-EOS\nheredoc1\nheredoc2\n\tEOS\n",
  "<<~EOS\n heredoc\nEOS\n",
  "<<EOS\nEOS\n",
  '<<EOS' + "\na#{1}b\nEOS\n",
  '<<EOS' + "\na" + '#{1}' + "b\nEOS\n",
  '<<-EOS' + "\na" + '#{1}' + "b\n  EOS\n",
  "<<EOS\na\\\nb\nEOS\n",
  "<<'EOS'\n\\n\nEOS\n",
  "proc{|&b,x;y|}",
  "proc do |&b, x;y| end",
  "proc{|x,&b,y|}",
  "def f(x, &b, y); end",
  "proc{|&b|}",
  "def f(x, &b); end"
].each do |source|
  parser = CallbackAudit1129.new(source)
  parser.parse
  p [source, parser.events]
end

["foo # comment\n...\n", "foo # comment\n...\n\n", "foo # comment\n...\n# tail\n"].each do |source|
  parser = CallbackAudit1129.new(source)
  parser.parse
  p [source, parser.events.select { |event| event[0] == :ignored_nl }]
end
