class AddBeds24BookingIdToBookingsAndWeeklyRates < ActiveRecord::Migration[8.1]
  def change
    # Identifiant de la réservation miroir dans Beds24 (réservation directe confirmée,
    # ou blocage « black » pour une semaine réservée par la famille).
    add_column :bookings, :beds24_booking_id, :bigint
    add_index  :bookings, :beds24_booking_id, unique: true
    add_column :weekly_rates, :beds24_booking_id, :bigint
    add_index  :weekly_rates, :beds24_booking_id, unique: true
  end
end
