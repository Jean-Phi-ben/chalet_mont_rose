class ApplicationJob < ActiveJob::Base
  # Nouvelle tentative en cas de verrou base de données.
  retry_on ActiveRecord::Deadlocked

  # Un job dont l'enregistrement a disparu (réservation supprimée…) est abandonné.
  discard_on ActiveJob::DeserializationError
end
