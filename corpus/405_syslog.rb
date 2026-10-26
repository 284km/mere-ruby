# Syslog, which ruby ships as a C extension and mere-ruby as Ruby over the
# runtime's openlog / syslog / closelog / setlogmask: the state the module
# keeps, its refusals, the masks and the macros. Nothing reaches the system
# log: every message is at LOG_DEBUG with the mask set to LOG_UPTO(LOG_ERR).
require "syslog"
require "syslog/logger"

def try405
  yield
rescue StandardError => e
  [e.class, e.message]
end

p Syslog.opened?, Syslog.ident, Syslog.mask, Syslog.inspect
p try405 { Syslog.close }, try405 { Syslog.debug("x") }, try405 { Syslog.mask = 1 }
p Syslog::LOG_UPTO(Syslog::LOG_ERR), Syslog::LOG_MASK(Syslog::LOG_INFO), Syslog::VERSION
p Syslog::Constants::LOG_USER, Syslog::Option::LOG_PERROR, Syslog::Level::LOG_WARNING
p Syslog.instance.equal?(Syslog), Syslog.method(:open!) == Syslog.method(:reopen)

Syslog.open("mr405", Syslog::LOG_PID, Syslog::LOG_LOCAL0) do |s|
  p s.equal?(Syslog), s.opened?, s.ident, s.options, s.facility
  s.mask = Syslog::LOG_UPTO(Syslog::LOG_ERR)
  p s.mask, s.inspect
  p s.debug("masked %s %d", "out", 1).equal?(Syslog)
  p try405 { s.log(nil, "x") }, try405 { s.log(Syslog::LOG_DEBUG) }, try405 { s.debug }
  p try405 { s.log(Syslog::LOG_DEBUG, nil) }
  p try405 { Syslog.open("again") }
  p try405 { s.mask = "1" }
end
p Syslog.opened?, Syslog.facility

Syslog.open
p Syslog.ident == $0, Syslog.options == (Syslog::LOG_PID | Syslog::LOG_CONS), Syslog.facility == Syslog::LOG_USER
Syslog.reopen("mr405b", 0)
p Syslog.ident, Syslog.options
Syslog.close

class Holder405
  include Syslog::Constants
end
p Holder405::LOG_ERR, Holder405.LOG_UPTO(1)

logger = Syslog::Logger.new("mr405c")
p logger.level, Syslog::Logger::VERSION.class
logger.level = ::Logger::ERROR
logger.debug("not sent")
p Syslog.opened?
Syslog.close if Syslog.opened?
