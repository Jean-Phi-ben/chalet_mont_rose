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
end
