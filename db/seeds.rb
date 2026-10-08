# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

User.destroy_all
# Le statut admin ne dépend plus du drapeau en base mais de la liste blanche
# ADMIN_EMAILS (.env) : pour être admin, l'adresse doit y figurer.
User.create!(email_address: "admin@prestige.com", password: "password123")
User.create!(email_address: "client@prestige.com", password: "password123")
puts "Utilisateurs créés !"
