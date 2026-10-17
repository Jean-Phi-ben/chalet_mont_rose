# Le texte exact haché à la signature est conservé en base : le hash reste
# vérifiable même si le template, la locale ou la réservation changent ensuite.
class AddCanonicalTextToContracts < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :canonical_text, :text
    add_column :contracts, :template_version, :string
  end
end
