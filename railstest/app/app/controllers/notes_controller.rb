class NotesController < ApplicationController
  def index
    @notes = Note.order(:id)
  end
  def create
    note = Note.create!(note_params)
    session[:last_note_id] = note.id
    redirect_to notes_path
  end
  def update
    Note.find(params[:id]).update!(note_params)
    redirect_to notes_path
  end
  def destroy
    Note.find(params[:id]).destroy!
    redirect_to notes_path
  end
  def remembered
    render plain: session[:last_note_id].to_s
  end
  private
  def note_params
    params.require(:note).permit(:body)
  end
end
