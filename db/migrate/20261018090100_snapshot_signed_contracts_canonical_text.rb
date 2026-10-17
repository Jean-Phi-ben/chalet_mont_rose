# Reconstitue le texte canonique des contrats déjà signés (template 1.1, locale
# anglaise de l'époque) et ne le stocke QUE s'il reproduit exactement le hash
# enregistré à la signature. Sinon on laisse nil (le PDF signé reste la preuve)
# et on journalise. Cette migration ne lève jamais : elle tourne au démarrage
# du conteneur de production (db:prepare) et ne doit pas provoquer de rollback.
class SnapshotSignedContractsCanonicalText < ActiveRecord::Migration[8.1]
  def up
    Contract.reset_column_information
    Contract.where(status: Contract.statuses[:signed], canonical_text: nil).find_each do |contract|
      text = I18n.with_locale(:en) { ContractTemplate.canonical_text(contract.booking, contract) }
      if contract.compute_document_hash(text) == contract.document_hash
        contract.update_columns(canonical_text: text, template_version: ContractTemplate::VERSION)
        say "contrat #{contract.id} : texte canonique gelé (hash vérifié)"
      else
        say "contrat #{contract.id} : hash non reproduit, texte non gelé (PDF signé = preuve)", true
      end
    rescue StandardError => e
      say "contrat #{contract.id} : #{e.class} #{e.message}", true
    end
  end

  def down
    # Rien à défaire : la colonne est supprimée par la migration précédente.
  end
end
