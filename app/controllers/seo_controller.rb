# robots.txt, sitemap.xml et llms.txt : servis par Rails et non depuis public/,
# où ils hériteraient du cache d'un an des assets (config.public_file_server) —
# Cloudflare garderait alors une version périmée. Ici : cache public d'une heure.
# Hérite d'ActionController::Base : ni authentification, ni filtre navigateur pour les robots.
class SeoController < ActionController::Base
  before_action { expires_in 1.hour, public: true }

  def robots
  end

  def sitemap
  end

  def llms
  end
end
