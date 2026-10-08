# Liste blanche des administrateurs : seules ces adresses email ont accès au
# back-office. Elle est définie via la variable d'environnement ADMIN_EMAILS
# (adresses séparées par des virgules). Sans configuration, personne n'est admin.
module AdminAccess
  module_function

  def emails
    ENV.fetch("ADMIN_EMAILS", "")
       .split(",")
       .map { |e| e.strip.downcase }
       .reject(&:blank?)
  end

  def authorized?(email)
    return false if email.blank?

    emails.include?(email.to_s.strip.downcase)
  end
end
