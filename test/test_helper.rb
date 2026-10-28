ENV["RAILS_ENV"] ||= "test"

# Les tests doivent toujours tourner en mode stub des providers externes,
# indépendamment du .env de dev. On purge les clés avant de charger Rails
# pour que DropboxSignProvider.enabled? / SwiklyProvider.enabled? soient false.
%w[SWIKLY_API_KEY SWIKLY_API_SECRET SWIKLY_ACCOUNT_ID CAUTION_AMOUNT
   MAILER_OWNER_EMAIL BALANCE_REMINDER_DAYS].each { |k| ENV.delete(k) }

# Liste blanche admin déterministe pour les tests (le statut admin dépend de
# ADMIN_EMAILS via AdminAccess). Défini AVANT dotenv, qui n'écrase pas une
# variable déjà présente → les emails de test ci-dessous sont bien admins.
ENV["ADMIN_EMAILS"] = "admin@example.com,patron@example.com"

# Identité société minimale : le contrat refuse de se générer sans adresse ni SIRET.
ENV["COMPANY_ADDRESS"] ||= "2417 route de Cupelin, 74170 Saint-Gervais-les-Bains"
ENV["COMPANY_SIRET"]   ||= "000 000 000 00000"

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Cache mémoire vidé entre les tests : les compteurs de rate_limit ne doivent
    # pas fuir d'un test à l'autre.
    setup { Rails.cache.clear }
  end
end
