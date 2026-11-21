# Existing constant-lookup gap: module_eval does not add outer lexical nesting.
# Reference prints :missing; the preceding main and this candidate print :found.
module LexicalDefinitionControl
  class Base; end
  module Inner; end
end
begin
  LexicalDefinitionControl::Inner.module_eval('class Base::Wrong; end')
  p :found
rescue NameError
  p :missing
end
