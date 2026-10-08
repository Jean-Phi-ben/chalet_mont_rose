class Account::DocumentsController < Account::BaseController
  # Documents du chalet (CGU, livret) — lecture seule pour tout client connecté.
  def index
    @documents = Document.order(:kind)
  end

  def show
    doc = Document.find_by(id: params[:id])
    unless doc&.file&.attached?
      redirect_to account_documents_path, alert: "Document indisponible." and return
    end
    redirect_to rails_blob_path(doc.file, disposition: "attachment"), allow_other_host: false
  end
end
