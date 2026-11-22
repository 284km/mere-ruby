class SymbolSink
  def take(*args, **keywords)
    [args, keywords]
  end
  alias take? take
  alias take! take
end

sink = SymbolSink.new
value = sink.take:Name, 7
p value
value = sink.take:'quoted name'
p value
word = 'dynamic'
value = sink.take:"#{word} name"
p value
value = sink.take?:Question
p value
value = sink.take!:'bang'
p value
value = sink&.take:Safe
p value
value = nil&.take:Unused
p value
value = sink. take:Spaced
p value
value = sink.take:Name, label: nil
p value
p sink.take(label: :value)
p({label: 'string', other: nil})
p(true ? (sink.take:Inside) : :unused)
['true ? sink.take:other', 'false ? sink.take:other', 'true ? sink.take:First : :other'].each do |source|
  begin
    eval(source)
  rescue SyntaxError
    p :syntax_error
  end
end
