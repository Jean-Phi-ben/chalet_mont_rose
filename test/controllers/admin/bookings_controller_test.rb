require "test_helper"

class Admin::BookingsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    travel_to Date.new(2025, 12, 1)
    @admin = User.create!(email_address: "admin@example.com", password: "password", admin: true)
    sign_in_as(@admin)

    WeeklyRate.create!(week_start: Date.new(2026, 1, 3),  price_cents: 100_000)
    WeeklyRate.create!(week_start: Date.new(2026, 1, 10), price_cents: 120_000)
    @booking = Booking.create!(
      check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 17),
      first_name: "Jean", last_name: "Dupont", email: "jean@example.com",
      guests_count: 4, total_price_cents: 220_000, deposit_cents: 66_000
    )
  end

  teardown { travel_back }

  test "index lists bookings" do
    get admin_bookings_url
    assert_response :success
    assert_select "td", text: /Jean Dupont/
  end

  test "index filters by status" do
    Booking.create!(
      check_in: Date.new(2026, 1, 17), check_out: Date.new(2026, 1, 24),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000, status: :confirmed
    )
    get admin_bookings_url, params: { status: "confirmed" }
    assert_response :success
    assert_match "Marie Curie", response.body
    assert_no_match(/Jean Dupont/, response.body)
  end

  test "index shows status chips with counts" do
    get admin_bookings_url
    assert_response :success
    assert_match "Toutes", response.body
    assert_match "En attente", response.body
  end

  test "index sorts by check_in ascending when requested" do
    Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000
    )
    get admin_bookings_url, params: { sort: "check_in", dir: "asc" }
    assert_response :success
    # Jean (3 jan.) doit apparaître avant Marie (4 juil.).
    assert response.body.index("Jean Dupont") < response.body.index("Marie Curie")
  end

  test "index sorts by check_in ascending by default" do
    Booking.create!(
      check_in: Date.new(2026, 7, 4), check_out: Date.new(2026, 7, 11),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000
    )
    get admin_bookings_url
    assert_response :success
    # Jean (3 jan.) avant Marie (4 juil.) — ordre chronologique.
    assert response.body.index("Jean Dupont") < response.body.index("Marie Curie")
    # Flèche ascendante active sur la colonne Période.
    assert_match "fa-arrow-up-short-wide", response.body
  end

  test "index shows the contextual empty state when a status filter returns nothing" do
    get admin_bookings_url, params: { status: "confirmed" }
    assert_response :success
    assert_match "Aucun résultat ne correspond à ces filtres", response.body
  end

  test "index excludes bookings whose check_out is past" do
    # On revient au présent : le booking de janvier 2026 devient passé.
    travel_back
    get admin_bookings_url
    assert_response :success
    assert_no_match(/Jean Dupont/, response.body)
  end

  test "archived shows bookings whose check_out is past" do
    travel_back
    get archived_admin_bookings_url
    assert_response :success
    assert_match "Archives", response.body
    assert_match "Jean Dupont", response.body
  end

  test "archived link is visible from the active list" do
    get admin_bookings_url
    assert_select "a[href=?]", archived_admin_bookings_path
  end

  test "index filters by from/to date range (excludes periods outside)" do
    # Le booking existant a check_in 2026-01-03 → check_out 2026-01-17.
    # Une fenêtre 2026-02-01..2026-02-28 doit l'exclure.
    get admin_bookings_url(from: "2026-02-01", to: "2026-02-28")
    assert_response :success
    assert_no_match(/Jean Dupont/, response.body)
  end

  test "index keeps bookings whose period overlaps the filter window" do
    get admin_bookings_url(from: "2026-01-10", to: "2026-01-12")
    assert_response :success
    assert_match "Jean Dupont", response.body
  end

  test "index shows the date range filter form" do
    get admin_bookings_url
    assert_select "input[type=date][name=from]"
    assert_select "input[type=date][name=to]"
  end

  test "index renders payment pills (Arrhes / Solde / Caution)" do
    get admin_bookings_url
    assert_response :success
    assert_match "Arrhes", response.body
    assert_match "Solde", response.body
    assert_match "Caution", response.body
  end

  test "show renders the booking" do
    get admin_booking_url(@booking)
    assert_response :success
    assert_select "h1", text: /Jean Dupont/
  end

  test "new renders the manual creation form with the calendar in a modal trigger" do
    get new_admin_booking_url
    assert_response :success
    assert_select "h1", text: /Nouvelle réservation/
    assert_select "form[action=?]", admin_bookings_path
    # Un bouton ouvre le calendrier en surimpression.
    assert_select "[data-action=?]", "click->calendar#openPicker", 1
    # Le calendrier (jours cliquables) est présent dans l'overlay.
    assert_select "[data-calendar-target='picker']"
    assert_select "[data-calendar-target='day']", minimum: 1
    # Select voyageurs au format « X voyageurs ».
    assert_select "option", text: /4 voyageurs/
    # Le prix d'hébergement reste facultatif.
    assert_select "input[name='booking[accommodation_euros]']"
  end

  test "create persists a booking with computed breakdown and redirects to its page" do
    WeeklyRate.create!(week_start: Date.new(2026, 7, 4), price_cents: 100_000)
    assert_difference "Booking.count", 1 do
      post admin_bookings_url, params: {
        booking: {
          check_in: "2026-07-04", check_out: "2026-07-11",
          guests_count: 4,
          first_name: "Sophie", last_name: "Marceau", email: "sophie@example.com"
        }
      }
    end
    booking = Booking.last
    assert_equal "Sophie Marceau", booking.full_name
    assert booking.pending?
    assert_equal 100_000, booking.accommodation_cents          # 1 semaine
    assert_equal 40_000, booking.cleaning_fee_cents           # 1 × 40 000
    assert_equal 7_280, booking.tourist_tax_cents            # 260 × 4 × 7
    assert_redirected_to admin_booking_path(booking)
  end

  test "create rejects an unpriced period" do
    # Aucun WeeklyRate seedé pour février 2026 dans le setup.
    assert_no_difference "Booking.count" do
      post admin_bookings_url, params: {
        booking: {
          check_in: "2026-02-07", check_out: "2026-02-14",
          first_name: "Sophie", last_name: "Marceau", email: "sophie@example.com"
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "show lists overlapping bookings as conflicts" do
    overlap = Booking.create!(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000
    )
    get admin_booking_url(@booking)
    assert_response :success
    assert_match "Marie Curie", response.body
    assert_match "Autres demandes sur la même période", response.body
    overlap.destroy
  end

  test "show flags a confirmed conflict with a red banner" do
    Booking.create!(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000, status: :confirmed
    )
    get admin_booking_url(@booking)
    assert_response :success
    assert_match "Conflit avec une réservation confirmée", response.body
  end

  test "show hides the Confirmer button and prompts to release the existing confirmation" do
    Booking.create!(
      check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17),
      first_name: "Marie", last_name: "Curie", email: "marie@example.com",
      total_price_cents: 120_000, deposit_cents: 36_000, status: :confirmed
    )
    get admin_booking_url(@booking)
    assert_response :success
    assert_match "Veuillez libérer la confirmation en cours", response.body
    # plus de bouton Confirmer (formulaire POST/PATCH vers confirm_admin_booking_path)
    assert_select "form[action=?]", confirm_admin_booking_path(@booking), count: 0
  end

  test "confirm flips status, generates invoice + contract and emails the client (without caution)" do
    # 1 seul email à la confirmation : confirmation client (qui contient le lien de signature).
    assert_emails 1 do
      patch confirm_admin_booking_url(@booking)
    end
    assert_redirected_to admin_booking_path(@booking)
    @booking.reload
    assert @booking.confirmed?
    assert @booking.deposit_invoice&.pdf&.attached?, "la facture d'arrhes doit être attachée"
    assert_not_nil @booking.contract, "un contrat doit avoir été créé"
    assert @booking.contract.status_sent?
    assert @booking.contract.token.present?
    assert @booking.contract.signer_email.present?
    # La caution n'est PAS créée à la confirmation — elle est différée au J-10.
    assert_nil @booking.caution, "la caution doit être créée seulement avec le rappel solde"
  end

  test "reject flips status and notifies the client" do
    assert_emails 1 do
      patch reject_admin_booking_url(@booking)
    end
    assert_redirected_to admin_booking_path(@booking)
    assert @booking.reload.rejected?
  end

  test "cancel flips a confirmed booking to cancelled" do
    @booking.update!(status: :confirmed)
    patch cancel_admin_booking_url(@booking)
    assert_redirected_to admin_booking_path(@booking)
    assert @booking.reload.cancelled?
  end

  test "show on a confirmed booking renders Annuler instead of Refuser" do
    @booking.update!(status: :confirmed)
    get admin_booking_url(@booking)
    assert_response :success
    assert_select "form[action=?]", cancel_admin_booking_path(@booking)
    assert_select "form[action=?]", reject_admin_booking_path(@booking), count: 0
  end

  test "update recomputes the full breakdown from the new dates" do
    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17) } }
    assert_redirected_to admin_booking_path(@booking)
    @booking.reload
    assert_equal Date.new(2026, 1, 10), @booking.check_in
    assert_equal 120_000, @booking.accommodation_cents
    assert_equal 40_000, @booking.cleaning_fee_cents       # 40 000 × 1 sem.
    assert_equal   7_280, @booking.tourist_tax_cents        # 260 × 4 voy. × 7 nuits
    assert_equal 167_280, @booking.total_price_cents
    assert_equal 36_000, @booking.deposit_cents            # 30 % de l'hébergement
  end

  test "destroy removes the booking and its invoices, then redirects to the index" do
    Invoice.from_booking(@booking).each(&:save!)
    assert_difference -> { Booking.count }, -1 do
      assert_difference -> { Invoice.count }, -2 do
        delete admin_booking_url(@booking)
      end
    end
    assert_redirected_to admin_bookings_path
  end

  test "update keeps the admin override on the accommodation amount" do
    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17), accommodation_euros: 1500 } }
    assert_redirected_to admin_booking_path(@booking)
    @booking.reload
    assert_equal 150_000, @booking.accommodation_cents      # 1500 € forcés par l'admin
    assert_equal  40_000, @booking.cleaning_fee_cents       # ménage toujours recalculé
    assert_equal  45_000, @booking.deposit_cents            # 30 % de 1500 €
  end

  test "update keeps the admin override on the cleaning fee" do
    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17), cleaning_fee_euros: 600 } }
    assert_redirected_to admin_booking_path(@booking)
    @booking.reload
    assert_equal 60_000, @booking.cleaning_fee_cents        # 600 € forcés
    assert_equal 120_000, @booking.accommodation_cents      # auto-recalculé
  end

  test "update keeps the admin override on the deposit amount" do
    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17), deposit_euros: 500 } }
    assert_redirected_to admin_booking_path(@booking)
    @booking.reload
    assert_equal 50_000, @booking.deposit_cents             # 500 € forcés (au lieu de 30 % auto)
    assert_in_delta 41.7, @booking.deposit_percent_of_accommodation, 0.1   # 500/1200 ≈ 41.7 %
  end

  test "update preserves the existing deposit ratio when only the dates change" do
    # Sets deposit 500 € on accommodation 1200 € → ratio 41,7 %.
    @booking.update_columns(accommodation_cents: 120_000, deposit_cents: 50_000)

    # Édition des dates uniquement → accommodation recalculé, ratio préservé.
    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17) } }
    @booking.reload
    assert_equal 120_000, @booking.accommodation_cents  # 1 semaine du 10 jan
    # 120 000 × (50 000 / 120 000) = 50 000 — ratio 41,7 % préservé.
    assert_in_delta 41.7, @booking.deposit_percent_of_accommodation, 0.1
  end

  test "update on a confirmed booking regenerates both invoice PDFs synchronously" do
    @booking.update!(status: :confirmed)
    Invoice.from_booking(@booking).each(&:save!)
    # Vide les PDF pour vérifier la régénération.
    @booking.invoices.each { |inv| inv.pdf.purge if inv.pdf.attached? }

    patch admin_booking_url(@booking),
          params: { booking: { check_in: Date.new(2026, 1, 10), check_out: Date.new(2026, 1, 17) } }

    assert @booking.reload.invoices.all? { |inv| inv.pdf.attached? }
  end

  test "edit and update are blocked once the stay is past (archived)" do
    travel_back  # retour au présent : le booking de janvier 2026 devient passé.

    get edit_admin_booking_url(@booking)
    assert_response :redirect

    patch admin_booking_url(@booking),
          params: { booking: { accommodation_euros: 9999 } }
    assert_response :redirect
    refute_equal 999_900, @booking.reload.accommodation_cents
  end

  test "edit and update are blocked once the balance invoice has been received" do
    @booking.update!(status: :confirmed)
    Invoice.from_booking(@booking).each(&:save!)
    @booking.balance_invoice.mark_received!

    get edit_admin_booking_url(@booking)
    assert_response :redirect

    patch admin_booking_url(@booking),
          params: { booking: { accommodation_euros: 9999 } }
    assert_response :redirect
    refute_equal 999_900, @booking.reload.accommodation_cents
  end

  test "update rejects dates that overlap a confirmed booking" do
    @booking.update!(status: :confirmed)
    other = Booking.create!(
      check_in: Date.new(2026, 1, 17), check_out: Date.new(2026, 1, 24),
      first_name: "Marie", last_name: "Curie", email: "m@example.com",
      total_price_cents: 100_000, deposit_cents: 30_000
    )

    # Tentative de tirer Marie sur la même semaine que Jean → refus.
    patch admin_booking_url(other),
          params: { booking: { check_in: Date.new(2026, 1, 3), check_out: Date.new(2026, 1, 10) } }
    assert_response :unprocessable_entity
    assert_equal Date.new(2026, 1, 17), other.reload.check_in
  end
end
