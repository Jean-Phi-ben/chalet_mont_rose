class Account::InvoicesController < Account::BaseController
  # Téléchargement du PDF d'une facture — uniquement si elle appartient à une
  # réservation du client connecté.
  def show
    invoice = Invoice.includes(:booking).find_by(id: params[:id])

    unless invoice&.booking && invoice.booking.email.to_s.downcase == current_email
      redirect_to account_root_path, alert: "Facture introuvable." and return
    end
    unless invoice.pdf.attached?
      redirect_to account_root_path, alert: "Le PDF de cette facture n'est pas encore disponible." and return
    end

    redirect_to rails_blob_path(invoice.pdf, disposition: "attachment"), allow_other_host: false
  end
end
