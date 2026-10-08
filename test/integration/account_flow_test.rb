require "test_helper"

class AccountFlowTest < ActionDispatch::IntegrationTest
  test "la connexion publique propose email/mot de passe, Google et l'inscription, sans mention de l'admin" do
    get login_path
    assert_response :success
    assert_select "form[action=?][method='post']", session_path            # connexion email/mot de passe
    assert_select "form[action='/auth/google_oauth2'][method='post']"      # connexion Google
    assert_select "a[href=?]", signup_path                                 # lien « Créer un compte »
    assert_match "Se connecter avec Google", response.body
    assert_no_match %r{/admin}, response.body
  end

  test "inscription : crée un compte client non-admin, ouvre une session et redirige vers l'espace" do
    assert_difference -> { User.count } => 1 do
      post signup_path, params: { user: {
        email_address: "Nouveau@Example.com", password: "secret123", password_confirmation: "secret123"
      } }
    end
    assert_redirected_to account_root_path
    user = User.find_by(email_address: "nouveau@example.com")
    assert user, "le compte doit être créé (email normalisé)"
    assert_not user.admin?, "un compte créé publiquement n'est jamais admin"
  end

  test "inscription refusée si les mots de passe ne correspondent pas" do
    assert_no_difference -> { User.count } do
      post signup_path, params: { user: {
        email_address: "x@example.com", password: "secret123", password_confirmation: "different"
      } }
    end
    assert_response :unprocessable_entity
  end

  test "connexion email/mot de passe d'un client mène à l'espace" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }
    assert_redirected_to account_root_path
    assert cookies[:session_id]
  end

  test "l'espace client exige une connexion et redirige vers la connexion client (pas l'admin)" do
    get account_root_path
    assert_redirected_to login_path # et surtout PAS new_session_path
  end

  test "le callback Google crée un User non-admin et ouvre une session" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      info: { email: "Nina@Example.com", first_name: "Nina", last_name: "Test" }
    )

    assert_difference -> { User.count } => 1, -> { Client.count } => 1 do
      get "/auth/google_oauth2/callback"
    end

    assert_redirected_to account_root_path
    user = User.find_by(email_address: "nina@example.com")
    assert user, "le User doit être créé (email normalisé)"
    assert_not user.admin?, "un client connecté via Google ne doit jamais être admin"
    assert Client.exists?(["lower(email) = ?", "nina@example.com"])
  ensure
    OmniAuth.config.test_mode = false
  end

  test "l'espace client se rend pour un utilisateur connecté (tableau de bord, profil, documents)" do
    sign_in_as(users(:one))

    get account_root_path
    assert_response :success

    get account_profile_path
    assert_response :success

    get account_documents_path
    assert_response :success
  end

  test "le tableau de bord affiche une réservation confirmée avec contrat et facture" do
    user = users(:one)
    booking = Booking.create!(
      check_in: Date.new(2026, 6, 6), check_out: Date.new(2026, 6, 13), # samedi → samedi
      guests_count: 2, first_name: "Client", last_name: "Test",
      email: user.email_address, total_price_cents: 310_000, deposit_cents: 93_000,
      status: :confirmed
    )
    booking.create_contract!(status: :sent)
    invoice = booking.invoices.create!(kind: :deposit, amount_cents: 93_000, status: :awaiting)
    invoice.pdf.attach(io: StringIO.new("%PDF-1.4 test"), filename: "facture.pdf", content_type: "application/pdf")

    sign_in_as(user)
    get account_root_path

    assert_response :success
    assert_match "2026", response.body              # dates de la réservation
    assert_select "a[href=?]", contract_reservation_path(booking.token) # lien « Signer le contrat »
    assert_select "a[href=?]", account_invoice_path(Invoice.last)       # lien téléchargement facture
  end

  test "menu navbar : socle public toujours ; + espace client si connecté ; + Administration si admin" do
    # Visiteur non connecté : socle grand public + connexion, aucune catégorie admin.
    get root_path
    assert_response :success
    assert_match "Grand public", response.body
    assert_match "Se connecter", response.body
    assert_no_match(/Administration/, response.body)
    assert_no_match(/Mes réservations/, response.body)

    # Client connecté (non admin) : + pages espace client, toujours pas d'admin.
    sign_in_as(users(:one))
    get root_path
    assert_match "Mes réservations", response.body
    assert_match "Déconnexion", response.body
    assert_no_match(/Administration/, response.body)
    assert_select "a[href=?]", admin_root_path, false

    # Admin (email dans ADMIN_EMAILS) : + catégorie Administration et liens admin.
    sign_out
    admin = User.create!(email_address: "admin@example.com", password: "password")
    sign_in_as(admin)
    get root_path
    assert_match "Administration", response.body
    assert_select "a[href=?]", admin_root_path
    assert_select "a[href=?]", admin_weekly_rates_path
  end

  test "aucun lien vers l'admin n'apparaît dans l'espace client, même pour un admin connecté" do
    admin = User.create!(email_address: "patron@example.com", password: "password", admin: true)
    sign_in_as(admin)

    get account_root_path
    assert_response :success
    assert_select "a[href='/admin']", false, "l'espace client ne doit jamais lier vers /admin"
    assert_no_match(/Dashboard Admin/i, response.body)
  end
end
