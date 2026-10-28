class Document < ApplicationRecord
  has_one_attached :file

  enum :kind, { cgu: 0, livret: 1 }, prefix: true

  validates :title, :kind, presence: true
  validates :kind, uniqueness: true   # un seul Document par catégorie
  validate  :file_must_be_a_small_pdf

  MAX_FILE_SIZE = 10.megabytes

  KIND_LABELS = { "cgu" => "Conditions générales de location", "livret" => "Livret du chalet" }.freeze

  def kind_label
    KIND_LABELS.fetch(kind, kind.to_s.humanize)
  end

  private

  # Joint tel quel aux emails des clients : un PDF lisible, de taille raisonnable.
  def file_must_be_a_small_pdf
    return errors.add(:file, "doit être joint (PDF)") unless file.attached?

    errors.add(:file, "doit être un PDF") unless file.content_type == "application/pdf"
    errors.add(:file, "doit faire moins de #{MAX_FILE_SIZE / 1.megabyte} Mo") if file.byte_size.to_i > MAX_FILE_SIZE
  end
end
