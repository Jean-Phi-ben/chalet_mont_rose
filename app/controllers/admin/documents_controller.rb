class Admin::DocumentsController < Admin::BaseController
  before_action :set_document, only: %i[edit update destroy]

  def index
    authorize Document
    @documents = Document.order(:kind)
  end

  def new
    @document = Document.new
    authorize @document
  end

  def create
    @document = Document.new(document_params)
    authorize @document
    if @document.save
      redirect_to admin_documents_path, notice: "Document enregistré."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @document
  end

  def update
    authorize @document
    if @document.update(document_params)
      redirect_to admin_documents_path, notice: "Document mis à jour."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @document
    @document.destroy
    redirect_to admin_documents_path, notice: "Document supprimé."
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :kind, :file)
  end
end
