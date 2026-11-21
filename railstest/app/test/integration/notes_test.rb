require_relative "../test_helper"
class NotesTest < ActionDispatch::IntegrationTest
  test "routing erb and html escaping" do
    Note.create!(body: "<script>unsafe</script>")
    get notes_path
    assert_response :success
    assert_includes response.body, "fixture note"
    assert_includes response.body, "&lt;script&gt;unsafe&lt;/script&gt;"
    assert_not_includes response.body, "<script>unsafe</script>"
  end
  test "http create cookie session update and delete" do
    assert_difference("Note.count", 1) do
      post notes_path, params: { note: { body: "created through HTTP" } }
    end
    assert_redirected_to notes_path
    note = Note.order(:id).last
    get "/remembered"
    assert_response :success
    assert_equal note.id.to_s, response.body
    patch note_path(note), params: { note: { body: "updated through HTTP" } }
    assert_redirected_to notes_path
    assert_equal "updated through HTTP", note.reload.body
    assert_difference("Note.count", -1) { delete note_path(note) }
    assert_redirected_to notes_path
  end
end
