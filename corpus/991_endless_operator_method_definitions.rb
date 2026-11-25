cases = [
  ['-@', '', '-o', ':neg'],
  ['+@', '', '+o', ':pos'],
  ['!', '', '!o', ':bang'],
  ['~', '', '~o', ':tilde'],
  ['+', '(other)', 'o + 2', ':plus'],
  ['==', '(other)', 'o == 2', ':equal'],
  ['[]', '(key)', 'o[2]', ':index'],
  ['[]', '', 'o[]', ':empty_index'],
  ['<=>', '(other)', 'o <=> 2', ':compare']
]
cases.each do |operator, parameters, call, result|
  [:endless, :body].each do |form|
    suffix = form == :endless ? " = #{result}" : "; #{result}; end"
    [:singleton, :instance, :parenthesized].each do |kind|
      source = case kind
               when :singleton
                 "o = Object.new\ndef o.#{operator}#{parameters}#{suffix}\n#{call}"
               when :instance
                 "klass = Class.new do\n def #{operator}#{parameters}#{suffix}\nend\no = klass.new\n#{call}"
               when :parenthesized
                 "o = Object.new\ndef (o).#{operator}#{parameters}#{suffix}\n#{call}"
               end
      begin
        p [operator, form, kind, eval(source)]
      rescue SyntaxError, StandardError => error
        p [operator, form, kind, error.class]
      end
    end
  end
end
puts :source_after_definitions
