require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
    assert_select "h1", "Mot de passe oublié"
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with UserMailer, :reset, args: [ @user ]
    assert_redirected_to login_path

    follow_redirect!
    assert_notice "email de réinitialisation"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to login_path

    follow_redirect!
    assert_notice "email de réinitialisation"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
    assert_select "h1", "Nouveau mot de passe"
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "invalide ou a expiré"
  end

  test "update changes the password and marks the email as verified" do
    @user.update_columns(email_verified_at: nil)
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "nouveau-mdp-123", password_confirmation: "nouveau-mdp-123" }
      assert_redirected_to login_path
    end
    assert @user.reload.verified?, "réinitialiser depuis la boîte email prouve l'adresse"

    follow_redirect!
    assert_notice "mot de passe a été modifié"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "nouveau-mdp-123", password_confirmation: "autre-mdp-123" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_select "[role=alert]" # message de validation (traduit en français au lot i18n)
  end

  test "update refuses a password shorter than the minimum" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "court", password_confirmation: "court" }
    end
    follow_redirect!
    assert_select "[role=alert]"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
