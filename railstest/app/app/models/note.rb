class Note < ApplicationRecord
  validates :body, presence: true
  before_validation :trim_body
  private
  def trim_body
    self.body = body.strip if body
  end
end
