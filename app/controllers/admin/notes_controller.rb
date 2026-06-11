class Admin::NotesController < Admin::BaseController
  before_action :set_note, only: %i[update destroy toggle archive unarchive]

  def archived
    @notes = Note.archived.order(archived_at: :desc)
  end

  def create
    @note = Note.new(note_params)
    if @note.save
      redirect_to admin_root_path, notice: "Note ajoutée."
    else
      redirect_to admin_root_path, alert: @note.errors.full_messages.to_sentence
    end
  end

  def update
    if @note.update(note_params)
      redirect_back fallback_location: admin_root_path, notice: "Note mise à jour."
    else
      redirect_back fallback_location: admin_root_path, alert: @note.errors.full_messages.to_sentence
    end
  end

  # Coche / décoche la tâche depuis la liste.
  def toggle
    @note.update(done: !@note.done?)
    redirect_to admin_root_path
  end

  def archive
    @note.archive!
    redirect_back fallback_location: admin_root_path, notice: "Note archivée."
  end

  def unarchive
    @note.unarchive!
    redirect_back fallback_location: archived_admin_notes_path, notice: "Note rétablie."
  end

  def destroy
    @note.destroy
    redirect_back fallback_location: archived_admin_notes_path, notice: "Note supprimée."
  end

  private

  def set_note
    @note = Note.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:title, :body, :deadline, :done)
  end
end
