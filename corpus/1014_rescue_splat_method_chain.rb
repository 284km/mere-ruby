class RescueSource1014
  def driver = self
  def invalid_errors = [ArgumentError]
end
class RescueHandler1014
  def session = RescueSource1014.new
  def run
    raise ArgumentError, 'handled'
  rescue *session.driver.invalid_errors => error
    [error.class, error.message]
  end
end
p RescueHandler1014.new.run
errors = [ArgumentError]
begin
  raise ArgumentError
rescue *errors.reverse
  p :reverse
end
begin
  raise TypeError
rescue *RescueSource1014.new.invalid_errors, TypeError
  p :second
end
