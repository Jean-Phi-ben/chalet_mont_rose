# Connexion des clients via Google (OmniAuth).
# La phase de requête (POST /auth/google_oauth2) est protégée par CSRF grâce à
# omniauth-rails_csrf_protection. Identifiants fournis par ENV.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"],
           ENV["GOOGLE_CLIENT_SECRET"],
           {
             scope: "email,profile",
             prompt: "select_account",
             access_type: "online"
           }
end

# OmniAuth 2 : seules les requêtes POST déclenchent l'authentification.
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.logger = Rails.logger

# En cas d'échec (annulation, erreur fournisseur), rediriger proprement.
OmniAuth.config.on_failure = proc do |env|
  Sessions::OmniauthController.action(:failure).call(env)
end
