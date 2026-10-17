require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new redirige vers la connexion client (/connexion)" do
    get new_session_path
    assert_redirected_to login_path
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "motdepasse" }

    assert_redirected_to account_root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to login_path
    assert_nil cookies[:session_id]

    # La bannière d'alerte est bien rendue, avec son bouton de fermeture.
    follow_redirect!
    assert_select "[role=alert]", text: /incorrect/ do
      assert_select "button[aria-label=Fermer][data-action='flash#dismiss']"
    end
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end
end
