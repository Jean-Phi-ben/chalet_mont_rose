# Preuve d'acceptation des conditions générales de location au moment de la demande.
class AddTermsAcceptanceToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :terms_accepted_at, :datetime
    add_column :bookings, :terms_version, :string
  end
end
