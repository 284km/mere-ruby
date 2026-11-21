require_relative "../test_helper"
class NoteTest < ActiveSupport::TestCase
  test "fixtures and model autoload" do
    assert_equal "fixture note", notes(:one).body
    assert_equal "Note", Note.name
  end
  test "validation and callback" do
    assert_not Note.new(body: " ").valid?
    assert_equal "trimmed", Note.create!(body: "  trimmed  ").body
  end
  test "create read update delete" do
    note = Note.create!(body: "before")
    assert_equal "before", Note.find(note.id).body
    note.update!(body: "after")
    assert_equal "after", note.reload.body
    note.destroy!
    assert_not Note.exists?(note.id)
  end
  test "transaction rollback" do
    before = Note.count
    Note.transaction do
      Note.create!(body: "rolled back")
      raise ActiveRecord::Rollback
    end
    assert_equal before, Note.count
  end
end
