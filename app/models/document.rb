class Document < ApplicationRecord
  has_one_attached :file

  enum :kind, { cgu: 0, livret: 1 }, prefix: true

  validates :title, :kind, presence: true
  validates :kind, uniqueness: true   # un seul Document par catégorie

  KIND_LABELS = { "cgu" => "Conditions générales", "livret" => "Livret du chalet" }.freeze

  def kind_label
    KIND_LABELS.fetch(kind, kind.to_s.humanize)
  end
end
