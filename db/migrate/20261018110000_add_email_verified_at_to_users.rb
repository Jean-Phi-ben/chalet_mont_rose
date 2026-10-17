# Vérification de l'adresse email à l'inscription : tant qu'elle n'est pas
# prouvée (lien reçu par email, connexion Google ou réinitialisation du mot de
# passe), l'espace client reste vide. Les comptes déjà existants sont considérés
# vérifiés (décision du propriétaire : ce sont les siens).
class AddEmailVerifiedAtToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_verified_at, :datetime
    execute "UPDATE users SET email_verified_at = created_at"
  end

  def down
    remove_column :users, :email_verified_at
  end
end
