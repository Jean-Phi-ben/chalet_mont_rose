class Sessions::OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[new create failure]

  # Page de connexion client (bouton « Se connecter avec Google »).
  def new
    redirect_to account_root_path if authenticated?
  end

  # Callback OmniAuth (Google) : crée/retrouve un User par email (vérifié par
  # Google), puis ouvre une session Rails 8.
  def create
    auth  = request.env["omniauth.auth"]
    email = auth&.dig("info", "email").to_s.strip.downcase

    if email.blank?
      redirect_to login_path, alert: "Connexion impossible : Google n'a pas fourni d'adresse email." and return
    end
    unless google_email_verified?(auth)
      redirect_to login_path, alert: "Connexion impossible : Google n'a pas confirmé cette adresse email." and return
    end

    user = User.find_by(email_address: email)
    if user.nil?
      user = User.create!(email_address: email, email_verified_at: Time.current,
                          password: SecureRandom.base58(48)) # connexion par Google : mot de passe aléatoire inutilisé
    elsif !user.verified?
      # Compte créé par mot de passe sans jamais avoir été vérifié (peut-être par un
      # tiers) : Google prouve la boîte, on reprend le compte et on coupe les
      # sessions et le mot de passe existants.
      user.update!(email_verified_at: Time.current, password: SecureRandom.base58(48))
      user.sessions.destroy_all
    end

    upsert_client_from(auth, email)
    start_new_session_for(user)
    redirect_to after_authentication_url, notice: "Bienvenue, vous êtes connecté."
  end

  def failure
    redirect_to login_path, alert: "La connexion a échoué ou a été annulée."
  end

  private

  # Google signale si l'adresse est vérifiée (extra.raw_info.email_verified).
  def google_email_verified?(auth)
    value = auth.dig("extra", "raw_info", "email_verified")
    value = auth.dig("info", "email_verified") if value.nil?
    ActiveModel::Type::Boolean.new.cast(value) == true
  end

  # Crée une fiche Client à partir du profil Google si aucune n'existe pour cet
  # email (best-effort : n'écrase rien, ne fait jamais échouer la connexion).
  def upsert_client_from(auth, email)
    return if Client.exists?([ "lower(email) = ?", email ])

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
