# Nombre d'envois de code OTP : plafonné (comme les essais) pour qu'un renvoi
# ne remette pas le compteur d'essais à zéro indéfiniment.
class AddOtpSendsCountToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :otp_sends_count, :integer, default: 0, null: false
  end
end
