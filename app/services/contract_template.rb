# Texte canonique du contrat de location, utilisé à la fois pour :
#   - le rendu HTML de la page de signature ;
#   - le rendu PDF post-signature ;
#   - le calcul du hash SHA-256 (preuve d'intégrité — cf. eIDAS).
#
# Toutes les sections sont en français et figées dans le code. Pour modifier le
# contrat, on ajuste ici et on incrémente VERSION (les contrats déjà signés
# conservent leur ancien hash, prouvant qu'ils ont vu cette version).
class ContractTemplate
  VERSION = "1.1".freeze

  COMPANY = {
    name:     "Chalet Mont Rose",
    address:  ENV["COMPANY_ADDRESS"].presence  || "56 rue de Passy, 75016 Paris",
    siret:    ENV["COMPANY_SIRET"].presence    || "n.c.",
    email:    ENV["COMPANY_EMAIL"].presence    || "chaletmontrose74@gmail.com"
  }.freeze

  PROPERTY = {
    name:                 "Chalet Mont Rose",
    address:              "2417 route de Cupelin",
    postal_code:          "74170",
    city:                 "Saint-Gervais-les-Bains",
    door_code:            "néant",
    floors:               "Rez-de-chaussée + 2 étages",
    parking:              "4 places devant la maison",
    habitat_type:         "Maison individuelle",
    legal_regime:         "Mono-propriété",
    construction_period:  "2024",
    living_area_sqm:      260,
    rooms_count:          10,
    max_occupants:        12,
    description: [
      "Séjour avec cheminée",
      "Cuisine équipée ouverte sur la salle à manger, cellier",
      "5 chambres spacieuses (3 chambres doubles avec lits 180 × 200, 1 chambre avec lits jumeaux, 1 dortoir avec 4 lits simples)",
      "6 salles de bain (dont 2 avec baignoires), 5 WC (dont 3 indépendants)",
      "Salle cinéma (projecteur laser et écran)",
      "Mezzanine avec TV, bureau et salle de jeux pour enfants",
      "Sauna",
      "Bain nordique",
      "Buanderie avec lave-linge et sèche-linge",
      "Garage"
    ].freeze
  }.freeze

  # Renvoie le texte canonique (utilisé pour le hash et le PDF).
  # Sections : (1..9). Toute modification d'une section change le hash.
  def self.canonical_text(booking, contract)
    [
      "CONTRAT DE LOCATION SAISONNIÈRE — #{COMPANY[:name]}",
      "Version du contrat : #{VERSION}",
      "",
      section_parties(contract),
      section_object,
      section_premises,
      section_period(booking),
      section_price(booking),
      section_caution,
      section_obligations,
      section_cancellation,
      section_jurisdiction
    ].join("\n\n")
  end

  def self.section_parties(contract)
    <<~TXT
      1. PARTIES
      Bailleur : #{COMPANY[:name]} — #{COMPANY[:address]} — SIRET #{COMPANY[:siret]} (« le Bailleur »).
      Locataire : #{contract.signer_first_name} #{contract.signer_last_name}, demeurant #{contract.signer_address.presence || 'à compléter'},
      email #{contract.signer_email}, téléphone #{contract.signer_phone.presence || 'n.c.'} (« le Locataire »).
    TXT
  end

  def self.section_object
    <<~TXT
      2. OBJET
      Le présent contrat a pour objet la location, à usage exclusivement saisonnier et d'habitation, du logement meublé désigné à l'article 3 ci-après (« le Logement »).
      Toute sous-location, cession ou usage commercial est strictement interdit.
    TXT
  end

  def self.section_premises
    desc_lines = PROPERTY[:description].map { |item| "  • #{item}" }.join("\n")
    <<~TXT
      3. DÉSIGNATION ET CONSISTANCE DU LOGEMENT
      Nom         : #{PROPERTY[:name]}
      Adresse     : #{PROPERTY[:address]}
      Code postal : #{PROPERTY[:postal_code]}
      Ville       : #{PROPERTY[:city]}
      Code porte  : #{PROPERTY[:door_code]}
      Étages      : #{PROPERTY[:floors]}
      Parking     : #{PROPERTY[:parking]}

      Type d'habitat              : #{PROPERTY[:habitat_type]}
      Régime juridique            : #{PROPERTY[:legal_regime]}
      Période de construction     : #{PROPERTY[:construction_period]}
      Surface habitable           : #{PROPERTY[:living_area_sqm]} m²
      Nombre de pièces            : #{PROPERTY[:rooms_count]}
      Capacité maximale d'accueil : #{PROPERTY[:max_occupants]} personnes

      Description du bien loué — chalet de montagne comprenant :
      #{desc_lines}
    TXT
  end

  def self.section_period(booking)
    <<~TXT
      4. DURÉE & OCCUPATION
      Arrivée : #{I18n.l(booking.check_in, format: :long) rescue booking.check_in}.
      Départ  : #{I18n.l(booking.check_out, format: :long) rescue booking.check_out}.
      Durée   : #{booking.weeks} semaine(s), soit #{booking.nights} nuit(s).
      Nombre de voyageurs pour le présent séjour : #{booking.guests_count || 'à préciser'} personne(s), dans la limite de la capacité maximale du Logement (#{PROPERTY[:max_occupants]}).
      Toute arrivée s'effectue le samedi à partir de 16 h, départ le samedi suivant avant 10 h, sauf accord écrit du Bailleur.
    TXT
  end

  def self.section_price(booking)
    deposit = booking.deposit_cents.to_i
    total   = booking.total_price_cents.to_i
    <<~TXT
      5. PRIX & PAIEMENT
      Montant total du séjour : #{format_eur(total)} TTC, taxe de séjour incluse.
      Acompte (arrhes) : #{format_eur(deposit)}, à verser dans les 7 jours suivant la signature.
      Solde : #{format_eur(total - deposit)} à régler au plus tard 10 jours avant l'arrivée.
      Le paiement s'effectue par virement bancaire sur le compte indiqué sur la facture.
    TXT
  end

  def self.section_caution
    <<~TXT
      6. CAUTION (EMPREINTE BANCAIRE)
      Une caution est demandée par empreinte bancaire dématérialisée via le prestataire Swikly.
      Aucun montant n'est prélevé : il s'agit d'une pré-autorisation, libérée à la fin du séjour si aucun dégât ni manquement n'est constaté.
      Le lien Swikly sera transmis avec le rappel du solde, 10 jours avant l'arrivée.
    TXT
  end

  def self.section_obligations
    <<~TXT
      7. OBLIGATIONS DU LOCATAIRE
      Le Locataire s'engage à occuper le Logement en « bon père de famille », à respecter la capacité maximale de #{PROPERTY[:max_occupants]} personnes,
      à ne pas fumer à l'intérieur, à respecter le voisinage, et à laisser les lieux propres au départ.
      Le ménage de sortie est inclus dans le forfait ménage facturé, sauf détérioration manifeste.
      Le Locataire déclare disposer d'une assurance villégiature couvrant les risques locatifs durant son séjour.
    TXT
  end

  def self.section_cancellation
    <<~TXT
      8. ANNULATION
      En cas d'annulation par le Locataire :
        - jusqu'à 30 jours avant l'arrivée : les arrhes sont conservées par le Bailleur (article 1590 du Code civil) ;
        - moins de 30 jours avant l'arrivée : la totalité du séjour reste due.
      En cas d'annulation par le Bailleur : restitution intégrale des sommes versées, le cas échéant doublement des arrhes selon les conditions de l'article 1590 du Code civil.
      En cas de force majeure dûment justifiée, les parties s'efforceront de reporter le séjour sans pénalité.
    TXT
  end

  def self.section_jurisdiction
    <<~TXT
      9. LITIGES & DROIT APPLICABLE
      Le présent contrat est régi par le droit français.
      Avant toute action judiciaire, les parties s'engagent à rechercher une solution amiable.
      À défaut, tout litige relève de la juridiction des tribunaux du ressort du lieu de situation du Logement.
    TXT
  end

  def self.format_eur(cents)
    "#{format('%.2f', cents.to_i / 100.0).tr('.', ',')} €"
  end
end
