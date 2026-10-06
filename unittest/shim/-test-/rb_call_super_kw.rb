# frozen_string_literal: true
# A Ruby stand-in for CRuby's ext/-test-/rb_call_super_kw (see -test-/file.rb).
module Bug
  # rb_call_super_kw(argc, argv, RB_PASS_CALLED_KEYWORDS): super with the
  # arguments as they were passed, keywords as keywords
  module RbCallSuperKw
    def m(...) = super(...)
  end
end
