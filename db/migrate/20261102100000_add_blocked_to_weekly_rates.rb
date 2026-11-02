# Semaine réservée par la famille : pas de réservation ni de facture, mais
# affichée occupée sur le calendrier public et refusée au devis.
class AddBlockedToWeeklyRates < ActiveRecord::Migration[8.1]
  def change
    add_column :weekly_rates, :blocked, :boolean, default: false, null: false
    add_index  :weekly_rates, :blocked
  end
end
