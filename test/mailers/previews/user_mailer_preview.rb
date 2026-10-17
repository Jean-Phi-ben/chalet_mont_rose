# Aperçus : http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def reset
    UserMailer.reset(User.take)
  end

  def verification
    UserMailer.verification(User.take)
  end
end
