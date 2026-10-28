# Texte du contrat de location saisonnière, source unique pour :
#   - la page de signature (le partial HTML rend `sections`) ;
#   - le PDF signé et le hash SHA-256 (`canonical_text`, gelé à la signature).
#
# Toute modification du texte doit incrémenter VERSION : les contrats déjà signés
# conservent leur texte gelé (Contract#canonical_text) et leur hash.
class ContractTemplate
  VERSION = "1.2".freeze

  Section = Struct.new(:number, :title, :body, keyword_init: true)

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
    check_in_time:        "16 h",
    check_out_time:       "10 h",
    description: [
      "Séjour avec cheminée",
      "Cuisine équipée ouverte sur la salle à manger, cellier",
      "5 chambres spacieuses (3 chambres doubles avec lits 180 × 200, 1 chambre avec lits jumeaux, 1 dortoir avec 4 lits simples)",
      "6 salles de bain (dont 2 avec baignoires), 5 WC (dont 3 indépendants)",
      "Salle de cinéma (projecteur laser et écran)",
      "Mezzanine avec TV, bureau et salle de jeux pour enfants",
      "Sauna",
      "Bain nordique",
      "Buanderie avec lave-linge et sèche-linge",
      "Garage"
    ].freeze
  }.freeze

  class << self
    # La société doit être identifiable pour engager un contrat.
    def ready?
      CompanyIdentity.ready?
    end

    # Texte canonique (hash + PDF). Déterministe : même entrée → même texte.
    def canonical_text(booking, contract)
      lines = [ "CONTRAT DE LOCATION SAISONNIÈRE — #{CompanyIdentity.legal_name}", "Version du contrat : #{VERSION}", "" ]
      sections(booking, contract).each do |section|
        lines << "#{section.number}. #{section.title.upcase}" << section.body.strip << ""
      end
      lines.join("\n")
    end

    def sections(booking, contract)
      [
        Section.new(number: 1, title: "Parties",                                   body: parties(contract)),
        Section.new(number: 2, title: "Objet",                                     body: object),
        Section.new(number: 3, title: "Désignation et consistance du logement",    body: premises),
        Section.new(number: 4, title: "Durée et occupation",                       body: period(booking)),
        Section.new(number: 5, title: "Prix et paiement",                          body: price(booking)),
        Section.new(number: 6, title: "Caution (empreinte bancaire)",              body: caution(booking)),
        Section.new(number: 7, title: "Obligations du Locataire",                  body: obligations),
        Section.new(number: 8, title: "Annulation",                                body: cancellation),
        Section.new(number: 9, title: "Médiation, litiges et droit applicable",    body: jurisdiction)
      ]
    end

    private

    def parties(contract)
      c = CompanyIdentity
      bailleur = [ "#{c.legal_name}, #{c.address}", "SIRET #{c.siret}" ]
      bailleur << "RCS #{c.rcs}" if c.rcs.present?
      bailleur << "représentée par #{c.representative}" if c.representative.present?
      bailleur << "email #{c.email}, téléphone #{c.phone}"
      <<~TXT
        Bailleur : #{bailleur.join(', ')} (« le Bailleur »).
        Locataire : #{contract.signer_first_name} #{contract.signer_last_name}, demeurant #{contract.signer_address.presence || '[adresse à compléter]'}, email #{contract.signer_email}, téléphone #{contract.signer_phone.presence || 'non communiqué'} (« le Locataire »).
      TXT
    end

    def object
      <<~TXT
        Le présent contrat a pour objet la location, à usage exclusivement saisonnier et d'habitation, du logement meublé désigné à l'article 3 ci-après (« le Logement »).
        Toute sous-location, cession ou usage commercial est strictement interdit.
      TXT
    end

    def premises
      p = PROPERTY
      desc_lines = p[:description].map { |item| "  • #{item}" }.join("\n")
      <<~TXT
        Nom : #{p[:name]}
        Adresse : #{p[:address]}, #{p[:postal_code]} #{p[:city]}
        Code porte : #{p[:door_code]}
        Étages : #{p[:floors]}
        Parking : #{p[:parking]}
        Type d'habitat : #{p[:habitat_type]}
        Régime juridique : #{p[:legal_regime]}
        Période de construction : #{p[:construction_period]}
        Surface habitable : #{p[:living_area_sqm]} m²
        Nombre de pièces : #{p[:rooms_count]}
        Capacité maximale d'accueil : #{p[:max_occupants]} personnes

        Description du bien loué — chalet de montagne comprenant :
        #{desc_lines}
      TXT
    end

    def period(booking)
      p = PROPERTY
      guests = booking.guests_count
      <<~TXT
        Arrivée : #{date_full(booking.check_in)} à partir de #{p[:check_in_time]}.
        Départ : #{date_full(booking.check_out)} avant #{p[:check_out_time]}.
        Durée : #{plural(booking.weeks, 'semaine')}, soit #{plural(booking.nights, 'nuit')}.
        Nombre de voyageurs pour le présent séjour : #{guests ? plural(guests, 'personne') : 'à préciser'}, dans la limite de la capacité maximale du Logement (#{p[:max_occupants]} personnes).
        Les horaires d'arrivée et de départ ne peuvent être modifiés que par accord écrit du Bailleur.
      TXT
    end

    def price(booking)
      total   = booking.total_price_cents.to_i
      deposit = booking.deposit_cents.to_i
      <<~TXT
        Hébergement : #{eur(booking.accommodation_cents)} TTC (TVA #{Booking::VAT_RATES[:accommodation].to_i} % incluse).
        Frais de ménage : #{eur(booking.cleaning_fee_cents)} TTC (TVA #{Booking::VAT_RATES[:cleaning].to_i} % incluse).
        Taxe de séjour : #{eur(booking.tourist_tax_cents)} (#{plural(booking.guests_count.to_i, 'voyageur')} × #{plural(booking.nights, 'nuit')}), reversée à la commune.
        Montant total du séjour : #{eur(total)} TTC.
        Arrhes : #{eur(deposit)} (#{booking.deposit_percent_label}), à régler par virement dans les #{Invoice::DEPOSIT_DUE_DAYS} jours suivant l'émission de la facture d'arrhes.
        Solde : #{eur(total - deposit)}, à régler par virement au plus tard #{Invoice::BALANCE_DUE_DAYS} jours avant l'arrivée ; la facture de solde est adressée au Locataire #{Invoice::BALANCE_REMINDER_DAYS} jours avant l'arrivée.
        Les coordonnées bancaires figurent sur chaque facture.
      TXT
    end

    def caution(booking)
      <<~TXT
        Une caution de #{eur(Caution.amount_for(booking))} est demandée sous forme d'empreinte bancaire dématérialisée (pré-autorisation, aucun montant prélevé) via le prestataire Swikly.
        Le lien de dépôt est transmis avec la facture de solde, #{Invoice::BALANCE_REMINDER_DAYS} jours avant l'arrivée.
        L'empreinte est libérée au plus tard #{SwiklyProvider.hold_days} jours après le départ si aucun dégât ni manquement n'est constaté ; à défaut, le Bailleur peut y prélever le coût justifié des réparations ou remplacements, dans la limite de la caution.
      TXT
    end

    def obligations
      <<~TXT
        Le Locataire s'engage à occuper le Logement raisonnablement et à l'usage exclusif d'habitation, à respecter la capacité maximale de #{PROPERTY[:max_occupants]} personnes, à ne pas fumer à l'intérieur, à respecter le voisinage et à laisser les lieux propres au départ.
        Un état des lieux et un inventaire sont établis à l'arrivée et au départ ; toute dégradation ou perte est signalée au Bailleur sans délai.
        Le ménage de sortie est compris dans les frais de ménage facturés, sauf détérioration manifeste.
        Le Locataire déclare disposer d'une assurance villégiature couvrant les risques locatifs durant son séjour.
      TXT
    end

    def cancellation
      <<~TXT
        Les sommes versées à la réservation constituent des arrhes au sens de l'article 1590 du Code civil.
        Annulation par le Locataire : les arrhes restent acquises au Bailleur ; toute autre somme déjà versée est remboursée.
        Annulation par le Bailleur : le Bailleur restitue au Locataire le double des arrhes.
        En cas de force majeure dûment justifiée, les parties s'efforcent de reporter le séjour sans pénalité.
      TXT
    end

    def jurisdiction
      c = CompanyIdentity
      mediator = [ c.mediator_name.presence || "[médiateur à désigner]", c.mediator_address.presence, c.mediator_url.presence ].compact.join(", ")
      <<~TXT
        Le présent contrat est régi par le droit français.
        En cas de différend, le Locataire adresse d'abord une réclamation écrite au Bailleur. À défaut de réponse satisfaisante dans un délai de 60 jours, il peut recourir gratuitement au médiateur de la consommation (articles L611-1 et suivants du Code de la consommation) : #{mediator}.
        À défaut de règlement amiable, le litige relève des juridictions compétentes selon les règles du Code de procédure civile.
      TXT
    end

    def date_full(date)
      I18n.l(date, format: :full, locale: :fr)
    end

    def plural(count, word)
      "#{count} #{word}#{'s' if count.to_i > 1}"
    end

    def eur(cents)
      ActiveSupport::NumberHelper.number_to_currency(cents.to_i / 100.0, unit: "€", separator: ",", delimiter: " ",
                                                      format: "%n %u", precision: 2)
    end
  end
end
