class Note < ApplicationRecord
  validates :title, presence: true

  scope :active,   -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  # Les plus récentes d'abord, mais les tâches en retard remontent.
  scope :sorted,   -> { order(Arel.sql("done ASC, created_at DESC")) }

  def archived?
    archived_at.present?
  end

  def archive!(at: Time.current)
    update!(archived_at: at)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  # Échéance dépassée et tâche non faite.
  def overdue?
    deadline.present? && !done? && deadline < Date.current
  end
end
