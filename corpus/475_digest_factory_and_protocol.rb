require 'digest'
p [Object.private_method_defined?(:Digest), Kernel.private_method_defined?(:Digest)]
p [Digest(:SHA256) == Digest::SHA256, Digest('SHA512') == Digest::SHA512]
begin
  Digest(:MissingImplementation)
rescue LoadError => error
  p error.class
end
class Digest::Custom < Digest::Class
  def initialize; @buffer = []; end
  def initialize_copy(other); @buffer = other.instance_variable_get(:@buffer).dup; end
  def update(string); @buffer << string; self; end
  alias << update
  def reset; @buffer.clear; self; end
  def finish; [@buffer.join.bytesize % 256].pack('C'); end
end
p Digest(:Custom) == Digest::Custom
p [Digest::Base.superclass, Digest::Class.ancestors.include?(Digest::Instance)]
digest = Digest::Custom.new << 'abc'
p [digest.hexdigest, digest.hexdigest('xy'), digest.hexdigest, digest.digest_length]
digest << 'abcd'
copy = digest.new
p [copy.hexdigest, digest.hexdigest, digest.hexdigest!, digest.hexdigest]
p Digest::Custom.hexdigest('hello')
module IncludedResult; end
class IncludeReceiver; end
p IncludeReceiver.class_eval { include IncludedResult }
p IncludeReceiver.class_eval { prepend Enumerable }
