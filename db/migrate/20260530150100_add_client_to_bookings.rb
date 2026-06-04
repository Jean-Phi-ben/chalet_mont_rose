class AddClientToBookings < ActiveRecord::Migration[8.1]
  def up
    add_reference :bookings, :client, foreign_key: true, index: true

    say_with_time "Reprise des bookings existants vers la table clients" do
      Booking.reset_column_information
      Client.reset_column_information

      Booking.unscoped.where(client_id: nil).find_each do |booking|
        next if booking.email.blank?
        normalized = booking.email.to_s.downcase.strip
        client = Client.unscoped.find_or_create_by!(email: normalized) do |c|
          c.first_name = booking.first_name
          c.last_name  = booking.last_name
          c.phone      = booking.phone
        end
        booking.update_column(:client_id, client.id)
      end
    end
  end

  def down
    remove_reference :bookings, :client, foreign_key: true
  end
end
