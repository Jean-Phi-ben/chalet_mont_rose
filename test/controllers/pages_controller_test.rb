require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home renders the reservation modal wired to a single dates picker (public access)" do
    get root_path
    assert_response :success

    # Un seul bouton « Dates » qui ouvre le calendrier en surimpression.
    assert_select "[data-action=?]", "click->calendar#openPicker", 1
    # Plus de double champ date manuel.
    assert_select "input[type=date]", false
    # Le calendrier empilé est embarqué dans le sélecteur (jours cliquables).
    assert_select "[data-calendar-target='day']", minimum: 1
    # Le formulaire poste bien vers la création de réservation.
    assert_select "form[action=?]", reservations_path
  end

  test "legal pages are public and linked from the footer" do
    get root_path
    assert_select "footer a[href=?]", privacy_path
    assert_select "footer a[href=?]", legal_path
    assert_select "footer a[href=?]", terms_path

    get legal_path
    assert_response :success
    assert_select "h1", "Mentions légales"
    assert_match CompanyIdentity.legal_name, response.body
    assert_match "Médiation de la consommation", response.body

    get terms_path
    assert_response :success
    assert_select "h1", "Conditions générales de location"
    assert_match "article 1590 du Code civil", response.body
    assert_match Booking::TERMS_VERSION, response.body
  end

  test "the reservation form carries the terms checkbox, the privacy notice and the honeypot" do
    get root_path
    assert_select "#reservation-modal input[type=checkbox][name='booking[terms_accepted]'][required]"
    assert_select "#reservation-modal a[href=?]", terms_path
    assert_select "#reservation-modal a[href=?]", privacy_path
    assert_select "#reservation-modal input[name=website]"
  end

  test "privacy policy is public and linked from the home page footer" do
    get root_path
    assert_select "footer a[href=?]", privacy_path

    get privacy_path
    assert_response :success
    assert_select "h1", "Politique de confidentialité"
    assert_select "h2", "Connexion avec Google"
  end

  test "home exposes SEO tags and structured data" do
    get root_path
    assert_select "html[lang=fr]"
    assert_select "meta[name=description][content*=?]", "Megève"
    assert_select "link[rel=canonical][href=?]", "https://www.chaletmontrose.fr/"
    assert_select "meta[property='og:image']"
    assert_select "meta[name=robots]", false

    types = css_select("script[type='application/ld+json']").map { |s| JSON.parse(s.text)["@type"] }
    assert_equal %w[VacationRental FAQPage], types
  end

  test "private pages are noindex" do
    get login_path
    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
    assert_select "link[rel=canonical]", false
  end

  test "robots, sitemap and llms files are served with a short cache" do
    { "/robots.txt" => [ "text/plain", "Sitemap: https://www.chaletmontrose.fr/sitemap.xml" ],
      "/sitemap.xml" => [ "application/xml", "<loc>https://www.chaletmontrose.fr/</loc>" ],
      "/llms.txt" => [ "text/plain", "# Chalet Mont Rose" ] }.each do |path, (media_type, content)|
      get path
      assert_response :success
      assert_equal media_type, response.media_type
      assert_includes response.body, content
      assert_equal "max-age=3600, public", response.headers["Cache-Control"]
    end
  end

  test "bare domain and http redirect permanently to https://www" do
    host! "chaletmontrose.fr"
    get "/confidentialite?x=1"
    assert_response :moved_permanently
    assert_redirected_to "https://www.chaletmontrose.fr/confidentialite?x=1"

    host! "www.chaletmontrose.fr"
    get root_path
    assert_redirected_to "https://www.chaletmontrose.fr/"

    https!
    get root_path
    assert_response :success
  end
end
