require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true

# Génère le PDF du contrat signé. Le PDF comprend :
#   - le texte du contrat (ContractTemplate.canonical_text)
#   - le tracé de signature embarqué (image PNG décodée du base64)
#   - un bloc « Dossier de preuves » final (date, IP, user agent, hash SHA-256)
class ContractPdf
  STONE_900 = "1c1917"
  STONE_500 = "78716c"
  STONE_300 = "d6d3d1"

  def self.render(contract)
    new(contract).render
  end

  def initialize(contract)
    @contract = contract
    @booking  = contract.booking
    @doc      = Prawn::Document.new(margin: 50, page_size: "A4")
  end

  def render
    header
    contract_body
    signature_block
    proof_block
    @doc.render
  end

  private

  def header
    @doc.font "Helvetica", style: :bold, size: 16
    @doc.fill_color STONE_900
    @doc.text "Contrat de location saisonnière"
    @doc.font "Helvetica", style: :normal, size: 9
    @doc.fill_color STONE_500
    @doc.text "Version #{ContractTemplate::VERSION} · Émis le #{fr(@contract.sent_at || Time.current)}"
    @doc.fill_color STONE_900
    @doc.move_down 16
  end

  def contract_body
    @doc.font "Helvetica", size: 10
    text = ContractTemplate.canonical_text(@booking, @contract)
    text.split("\n").each do |line|
      if line =~ /^\d+\.\s/
        @doc.move_down 6
        @doc.font "Helvetica", style: :bold, size: 11
        @doc.text line
        @doc.font "Helvetica", style: :normal, size: 10
      elsif line.strip.empty?
        @doc.move_down 4
      else
        @doc.text line, leading: 1
      end
    end
    @doc.move_down 18
  end

  def signature_block
    @doc.stroke_color STONE_300
    @doc.stroke_horizontal_rule
    @doc.move_down 12
    @doc.font "Helvetica", style: :bold, size: 11
    @doc.text "Signature du Locataire"
    @doc.font "Helvetica", style: :normal, size: 9
    @doc.fill_color STONE_500
    @doc.text "#{@contract.signer_full_name} — signé électroniquement le #{fr(@contract.signed_at)}"
    @doc.fill_color STONE_900
    @doc.move_down 8

    if @contract.signature_image.present?
      embed_signature_image
    else
      @doc.text "[signature non capturée]"
    end
  end

  def embed_signature_image
    data = @contract.signature_image.to_s
    base64 = data.split(",", 2).last
    return if base64.blank?
    io = StringIO.new(Base64.decode64(base64))
    @doc.image io, width: 220, fit: [ 220, 90 ]
  rescue StandardError => e
    Rails.logger.warn "[ContractPdf] signature image embed failed: #{e.message}"
    @doc.text "[signature illisible]"
  end

  def proof_block
    @doc.move_down 24
    @doc.stroke_color STONE_500
    @doc.bounding_box([ 0, @doc.cursor ], width: @doc.bounds.width) do
      @doc.stroke_bounds
      @doc.pad(10) do
        @doc.indent(10, 10) do
          @doc.font "Helvetica", style: :bold, size: 10
          @doc.text "Dossier de preuve — Signature Électronique Simple (SES)"
          @doc.font "Helvetica", style: :normal, size: 8
          @doc.fill_color STONE_500
          @doc.move_down 6
          @doc.text "Document signé électroniquement le #{fr(@contract.signed_at)} par #{@contract.signer_full_name}."
          @doc.text "Validé par double authentification email (code OTP à 6 chiffres, vérifié, à usage unique, expirant après #{Contract::OTP_TTL.in_minutes.to_i} minutes)."
          @doc.text "IP du signataire : #{@contract.signed_ip}"
          @doc.text "User agent : #{@contract.signed_user_agent.to_s[0, 200]}"
          @doc.text "Empreinte numérique (SHA-256) : #{@contract.document_hash}"
          @doc.fill_color STONE_900
        end
      end
    end
  end

  def fr(time)
    return "—" if time.blank?
    I18n.l(time, format: :long) rescue time.strftime("%d/%m/%Y %H:%M")
  end
end
