# En production, l'expéditeur des emails doit être configuré explicitement :
# sans MAILER_FROM, Rails enverrait depuis « noreply@example.com ». On refuse de
# démarrer (le healthcheck du déploiement échoue → rollback automatique).
# Pas de contrôle pendant le build de l'image (assets:precompile tourne avec
# SECRET_KEY_BASE_DUMMY et sans les secrets du serveur).
MailerConfig = Module.new do
  def self.check!(env = ENV)
    return unless Rails.env.production?
    return if env["STAGING"].present? || env["SECRET_KEY_BASE_DUMMY"].present?
    return if env["MAILER_FROM"].present?

    raise "MAILER_FROM manquant : définissez l'expéditeur des emails (ex. « Chalet Mont Rose <contact@…> ») dans ~/.chalet_env"
  end
end

MailerConfig.check!
