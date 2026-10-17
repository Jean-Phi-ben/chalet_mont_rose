namespace :invoices do
  desc "Met à jour les factures non verrouillées des réservations confirmées (montants + PDF) et affiche avant/après. FORCE=1 régénère aussi les PDF inchangés."
  task refresh: :environment do
    force = ENV["FORCE"] == "1"
    Booking.confirmed.where(invoicing_archived_at: nil).includes(:invoices).find_each do |booking|
      next if booking.invoices.none?

      before = booking.invoices.ordered.map { |i| [ i.number, i.amount_cents, i.pdf.attached? ? i.pdf.blob_id : nil ] }
      GenerateInvoiceJob.perform_now(booking, force: force)
      after = booking.reload.invoices.ordered.map { |i| [ i.number, i.amount_cents, i.pdf.attached? ? i.pdf.blob_id : nil ] }

      puts "Réservation ##{booking.id} — #{booking.full_name} (#{booking.check_in} → #{booking.check_out})"
      before.zip(after).each do |(num, amt_before, blob_before), (_, amt_after, blob_after)|
        amount = amt_before == amt_after ? "#{amt_after / 100.0} €" : "#{amt_before / 100.0} € → #{amt_after / 100.0} €"
        pdf    = blob_before == blob_after ? "PDF inchangé" : "PDF régénéré"
        puts "  #{num} : #{amount} · #{pdf}"
      end
    end
  end
end
