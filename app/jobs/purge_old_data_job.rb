# Durées de conservation annoncées dans la politique de confidentialité :
#   - demandes de réservation jamais facturées (en attente, refusées, annulées sans
#     facture) : 3 ans après le dernier contact ;
#   - journal des emails : 3 ans.
# Les réservations facturées, leurs contrats et factures sont conservés (obligation
# comptable : 10 ans) et ne sont jamais touchés ici.
class PurgeOldDataJob < ApplicationJob
  queue_as :default

  RETENTION = 3.years

  def perform(now: Time.current)
    cutoff = now - RETENTION

    stale = Booking.where.not(status: :confirmed)
                   .where("bookings.updated_at < ?", cutoff)
                   .where.missing(:invoices)
                   .left_joins(:contract).where(contracts: { id: nil })
    purged_bookings = stale.find_each.count { |b| b.destroy }

    purged_logs = EmailLog.where("sent_at < ?", cutoff).destroy_all.size

    Rails.logger.info "[PurgeOldDataJob] #{purged_bookings} demande(s) et #{purged_logs} email(s) de plus de 3 ans purgés"
    { bookings: purged_bookings, email_logs: purged_logs }
  end
end
