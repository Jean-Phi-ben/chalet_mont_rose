class Sessions::OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[new create failure]

  # Page de connexion client (bouton « Se connecter avec Google »).
  def new
    redirect_to account_root_path if authenticated?
  end

  # Callback OmniAuth (Google) : crée/retrouve un User NON-admin par email,
  # puis ouvre une session Rails 8.
  def create
    auth  = request.env["omniauth.auth"]
    email = auth&.dig("info", "email").to_s.strip.downcase

    if email.blank?
      redirect_to login_path, alert: "Connexion impossible : Google n'a pas fourni d'adresse email." and return
    end

    user = User.find_or_create_by!(email_address: email) do |u|
      u.password = SecureRandom.base58(48) # connexion par Google : mot de passe aléatoire inutilisé
      u.admin    = false
    end

    upsert_client_from(auth, email)
    start_new_session_for(user)
    redirect_to after_authentication_url, notice: "Bienvenue, vous êtes connecté."
  end

  def failure
    redirect_to login_path, alert: "La connexion a échoué ou a été annulée."
  end

  private

  # Crée une fiche Client à partir du profil Google si aucune n'existe pour cet
  # email (best-effort : n'écrase rien, ne fait jamais échouer la connexion).
  def upsert_client_from(auth, email)
    return if Client.exists?(["lower(email) = ?", email])

    info  = auth["info"] || {}
    names = info["name"].to_s.split
    Client.create(
      email:      email,
      first_name: info["first_name"].presence || names.first || "Client",
      last_name:  info["last_name"].presence  || names[1..].to_a.join(" ").presence || email.split("@").first
    )
  rescue StandardError => e
    Rails.logger.warn("[omniauth] création fiche client échouée : #{e.message}")
  end
end
