class Booking < ApplicationRecord
  # Plus strict que URI::MailTo::EMAIL_REGEXP : exige un domaine avec point + TLD ≥ 2 caractères,
  # ce qui rejette « jean@benoist » mais accepte « jean@benoist.fr ».
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\.[^@\s.]{2,}\z/i

  # Taux de TVA par catégorie de ligne (location meublée de tourisme + prestations).
  VAT_RATES = { accommodation: 10.0, cleaning: 20.0, tourist_tax: 0.0 }.freeze

  belongs_to :user, optional: true
  belongs_to :client, optional: true
  has_many :invoices, dependent: :destroy
  has_secure_token

  # Champ virtuel : l'adresse vit sur le Client (synchronisée à la sauvegarde).
  attr_accessor :address

  before_save :sync_client

  enum :status, { pending: 0, confirmed: 1, rejected: 2, cancelled: 3 }, default: :pending

  validates :check_in, :check_out, presence: true
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT, allow_blank: true }
  validates :guests_count, numericality: { greater_than: 0 }, allow_nil: true
  validate :dates_must_be_saturdays
  validate :check_out_after_check_in

  scope :blocking, -> { where(status: :confirmed) }

  validate :no_overlap_with_other_confirmed, if: -> { confirmed? && check_in && check_out }

  # Renvoie l'ensemble des dates (inclus) bloquées par les réservations confirmées
  # qui chevauchent la fenêtre [from, to]. Le check_out n'est pas bloqué
  # (départ matin = chalet libre, autorise les enchaînements samedi→samedi).
  def self.blocked_dates_between(from, to)
    confirmed
      .where("check_in < ? AND check_out > ?", to + 1, from)
      .each_with_object(Set.new) { |b, set| (b.check_in...b.check_out).each { |d| set << d } }
  end

  # Existe-t-il une réservation confirmée qui chevauche [check_in, check_out) ?
  def self.confirmed_overlap?(check_in, check_out, except_id: nil)
    rel = confirmed.where("check_in < ? AND check_out > ?", check_out, check_in)
    rel = rel.where.not(id: except_id) if except_id
    rel.exists?
  end

  # Autres réservations actives (pending ou confirmed) chevauchant cette période.
  def conflicting_bookings
    return Booking.none unless check_in && check_out

    Booking.where(status: %i[pending confirmed])
           .where("check_in < ? AND check_out > ?", check_out, check_in)
           .where.not(id: id)
           .order(:check_in)
  end

  def nights
    return 0 unless check_in && check_out

    (check_out - check_in).to_i
  end

  def weeks
    nights / 7
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  # Nombre de nuitées (voyageurs × nuits) pour la taxe de séjour.
  def nuitees
    guests_count.to_i * nights
  end

  # Montants unitaires (HT) reconstitués depuis les snapshots du décompte.
  def accommodation_per_night_cents
    nights.positive? ? (accommodation_cents.to_f / nights).round : 0
  end

  def cleaning_per_week_cents
    weeks.positive? ? (cleaning_fee_cents.to_f / weeks).round : 0
  end

  def tax_per_person_per_night_cents
    nuitees.positive? ? (tourist_tax_cents.to_f / nuitees).round : 0
  end

  # Taux de TVA appliqué à une catégorie de ligne.
  def vat_rate_for(category)
    VAT_RATES.fetch(category)
  end

  # Montant TVA inclus dans le TTC d'une catégorie de ligne.
  def vat_cents_for(category)
    ttc = case category
          when :accommodation then accommodation_cents.to_i
          when :cleaning      then cleaning_fee_cents.to_i
          when :tourist_tax   then tourist_tax_cents.to_i
          end
    rate = vat_rate_for(category)
    return 0 if rate.zero?

    (ttc.to_f * rate / (100.0 + rate)).round
  end

  # Montant total de TVA (somme des TVA hébergement + ménage + taxe).
  def vat_cents
    VAT_RATES.keys.sum { |cat| vat_cents_for(cat) }
  end

  # Variantes HT par unité (utilisées dans la colonne « Montant HT » du décompte).
  def accommodation_per_night_ht_cents
    ht = accommodation_cents.to_i - vat_cents_for(:accommodation)
    nights.positive? ? (ht.to_f / nights).round : 0
  end

  def cleaning_per_week_ht_cents
    ht = cleaning_fee_cents.to_i - vat_cents_for(:cleaning)
    weeks.positive? ? (ht.to_f / weeks).round : 0
  end

  def tax_per_person_per_night_ht_cents
    # TVA 0 % sur la taxe de séjour : HT == TTC.
    tax_per_person_per_night_cents
  end

  # Saisie/affichage en euros pour les champs admin d'override.
  def accommodation_euros
    accommodation_cents && accommodation_cents / 100.0
  end

  def accommodation_euros=(value)
    self.accommodation_cents = (value.to_d * 100).round if value.present?
  end

  def cleaning_fee_euros
    cleaning_fee_cents && cleaning_fee_cents / 100.0
  end

  def cleaning_fee_euros=(value)
    self.cleaning_fee_cents = (value.to_d * 100).round if value.present?
  end

  def deposit_euros
    deposit_cents && deposit_cents / 100.0
  end

  def deposit_euros=(value)
    self.deposit_cents = (value.to_d * 100).round if value.present?
  end

  # Part des arrhes par rapport au prix d'hébergement (en %, 1 décimale).
  def deposit_percent_of_accommodation
    return 0.0 if accommodation_cents.to_i.zero?

    (deposit_cents.to_f / accommodation_cents * 100).round(1)
  end

  # Libellé prêt à afficher : « 30 % de l'hébergement » ou « 41,7 % de l'hébergement ».
  def deposit_percent_label
    pct = deposit_percent_of_accommodation
    formatted = pct.to_s.sub(/\.0$/, "").tr(".", ",")
    "#{formatted} % de l'hébergement"
  end

  # Le séjour est passé (date de départ < aujourd'hui).
  def past_stay?
    check_out.present? && check_out < Date.current
  end

  # Archivage explicite déclenché par l'admin après réception complète des paiements.
  def invoicing_archived?
    invoicing_archived_at.present?
  end

  # Les montants sont verrouillés si le séjour est passé, si la facturation est archivée
  # explicitement, ou si le solde a déjà été encaissé (déverrouillable en décochant).
  def amounts_locked?
    past_stay? || invoicing_archived? || (balance_invoice&.payment_received?)
  end

  def deposit_invoice
    invoices.detect(&:kind_deposit?) || invoices.kind_deposit.first
  end

  def balance_invoice
    invoices.detect(&:kind_balance?) || invoices.kind_balance.first
  end

  def fully_paid?
    deposit_invoice&.payment_received? && balance_invoice&.payment_received?
  end

  def archive_invoicing!(at: Time.current)
    update!(invoicing_archived_at: at)
  end

  # Met à jour le décompte (hébergement + ménage + taxe de séjour) puis recalcule total/arrhes.
  # Snapshote les frais courants depuis BookingSetting au moment de l'appel, sauf override admin.
  def apply_breakdown!(accommodation_cents: nil, cleaning_override_cents: nil, deposit_override_cents: nil, setting: BookingSetting.current)
    self.accommodation_cents = accommodation_cents if accommodation_cents
    self.cleaning_fee_cents  = cleaning_override_cents || (setting.cleaning_fee_cents * weeks)
    self.tourist_tax_cents   = setting.tourist_tax_per_person_per_night_cents * guests_count.to_i * nights
    recompute_total(deposit_override: deposit_override_cents)
  end

  def recompute_total(deposit_override: nil)
    self.total_price_cents = self.accommodation_cents.to_i + cleaning_fee_cents.to_i + tourist_tax_cents.to_i
    self.deposit_cents     = deposit_override || (accommodation_cents.to_i * effective_deposit_rate).round
  end

  # Conserve le pourcentage d'arrhes précédemment défini (ex. 41,7 %) plutôt que
  # de retomber sur le défaut 30 % à chaque recalcul. Cas d'usage : l'admin a saisi
  # un montant manuel, puis modifie d'autres champs (dates, voyageurs…) — les arrhes
  # restent au même ratio par rapport à l'hébergement.
  def effective_deposit_rate
    if persisted? && accommodation_cents_was.to_i.positive? && deposit_cents_was.to_i.positive?
      deposit_cents_was.to_f / accommodation_cents_was
    else
      Pricing.deposit_rate
    end
  end

  private

  def dates_must_be_saturdays
    errors.add(:check_in, "doit être un samedi") if check_in && !check_in.saturday?
    errors.add(:check_out, "doit être un samedi") if check_out && !check_out.saturday?
  end

  def check_out_after_check_in
    return unless check_in && check_out

    errors.add(:check_out, "doit suivre l'arrivée") if check_out <= check_in
  end

  def no_overlap_with_other_confirmed
    return unless Booking.confirmed_overlap?(check_in, check_out, except_id: id)

    errors.add(:base, "La période chevauche une autre réservation confirmée.")
  end

  # Synchronise les coordonnées du client à chaque sauvegarde de la réservation.
  # Crée le Client s'il n'existe pas encore pour cet email.
  def sync_client
    return if email.blank?

    c = Client.find_or_initialize_by(email: email.to_s.downcase.strip)
    c.first_name = first_name if first_name.present?
    c.last_name  = last_name  if last_name.present?
    c.phone      = phone      if phone.present?
    c.address    = address    if address.present?
    c.save!
    self.client = c
  end
end
