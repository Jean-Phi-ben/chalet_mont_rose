class EmailLog < ApplicationRecord
  belongs_to :booking, optional: true
  has_many_attached :attachments

  scope :recent, -> { order(sent_at: :desc) }

  # Crée une entrée EmailLog à partir d'un Mail::Message (post-livraison).
  # Appelé explicitement depuis le code qui envoie l'email — c'est plus
  # fiable qu'un observer/callback qui peut rater les exécutions async.
  def self.record!(message, mailer:, action:, booking: nil)
    return if message.nil?

    # Idempotence : si le même Message-ID est déjà en base, on ne recrée pas.
    if message.message_id.present? && (existing = find_by(message_id: message.message_id))
      return existing
    end

    log = create!(
      booking_id:    booking&.id,
      mailer:        mailer.to_s,
      action:        action.to_s,
      to_addresses:  Array(message.to).join(", "),
      cc_addresses:  Array(message.cc).join(", ").presence,
      bcc_addresses: Array(message.bcc).join(", ").presence,
      from_address:  Array(message.from).first,
      subject:       message.subject.to_s,
      sent_at:       Time.current,
      message_id:    message.message_id
    )

    message.attachments.each do |att|
      log.attachments.attach(
        io: StringIO.new(att.body.to_s),
        filename: att.filename,
        content_type: att.mime_type
      )
    end

    Rails.logger.info "[EmailLog] ##{log.id} #{log.mailer}##{log.action} → #{log.to_addresses}"
    log
  end

  # Mapping Mailer/action → libellé humain pour les vues admin.
  LABELS = {
    %w[BookingMailer new_request_to_owner]      => "Nouvelle demande (propriétaire)",
    %w[BookingMailer acknowledgement_to_client] => "Accusé de réception client",
    %w[BookingMailer confirmation]              => "Confirmation (facture arrhes + lien signature)",
    %w[BookingMailer contract_otp]              => "Code de signature (OTP)",
    %w[BookingMailer signed_contract]           => "Contrat signé (PDF)",
    %w[BookingMailer rejected]                  => "Demande refusée",
    %w[BookingMailer balance_reminder]          => "Rappel solde J-10 (facture solde + caution + livret)",
    %w[PasswordsMailer reset]                   => "Réinitialisation mot de passe"
  }.freeze

  def label
    LABELS.fetch([ mailer, action ], "#{mailer}##{action}")
  end

  def to_list
    parse_addresses(to_addresses)
  end

  def cc_list
    parse_addresses(cc_addresses)
  end

  private

  def parse_addresses(csv)
    csv.to_s.split(",").map(&:strip).reject(&:blank?)
  end
end
