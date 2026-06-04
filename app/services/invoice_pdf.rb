require "prawn"
require "prawn/table"

Prawn::Fonts::AFM.hide_m17n_warning = true

# Génère le PDF d'une facture — arrhes ou solde — pour un Invoice donné.
# Format conforme aux obligations françaises de facturation d'acompte :
#   - la facture d'arrhes ne facture QUE le montant encaissé (TTC) + sa TVA propre ;
#   - la facture de solde reprend l'intégralité du séjour et déduit explicitement
#     la facture d'arrhes pour ne réclamer que le net à payer.
class InvoicePdf
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper
  include MoneyHelper

  STONE_900 = "1c1917"
  STONE_500 = "78716c"
  STONE_300 = "d6d3d1"

  # Délais de règlement.
  DEPOSIT_DUE_DAYS = 7   # arrhes à régler dans les 7 jours suivant l'émission
  BALANCE_DUE_DAYS = 10  # solde dû J-10 du séjour (à régler au plus tard à cette date)

  def self.render(invoice)
    new(invoice).render
  end

  def initialize(invoice)
    @invoice = invoice
    @booking = invoice.booking
    @doc     = Prawn::Document.new(margin: 50, page_size: "A4")
  end

  def render
    company_header
    invoice_meta_and_client
    stay_block
    if @invoice.kind_deposit?
      deposit_breakdown
      deposit_totals
    else
      balance_breakdown
      balance_totals
    end
    payment_terms
    rib_box
    legal_mentions
    @doc.render
  end

  private

  def company_header
    @doc.font "Helvetica", style: :bold, size: 18
    @doc.fill_color STONE_900
    @doc.text "Chalet Mont Rose"
    @doc.font "Helvetica", style: :normal, size: 9
    @doc.fill_color STONE_500
    @doc.text ENV["COMPANY_ADDRESS"] if ENV["COMPANY_ADDRESS"].present?
    @doc.text ENV["COMPANY_EMAIL"]   if ENV["COMPANY_EMAIL"].present?
    siret = ENV["COMPANY_SIRET"]
    vat_no = ENV["COMPANY_VAT_NUMBER"]
    extras = []
    extras << "SIRET : #{siret}"             if siret.present?
    extras << "TVA intracom. : #{vat_no}"    if vat_no.present?
    @doc.text extras.join(" · ") if extras.any?
    @doc.fill_color STONE_900
    @doc.move_down 24
  end

  def invoice_meta_and_client
    title = @invoice.kind_deposit? ? "Facture d'arrhes n° #{@invoice.number}" : "Facture de solde n° #{@invoice.number}"
    @doc.font_size 14
    @doc.text title, style: :bold
    @doc.font_size 9
    @doc.fill_color STONE_500
    @doc.text "Émise le #{fr_date(@invoice.issued_on)}"
    @doc.fill_color STONE_900
    @doc.move_down 16

    @doc.font_size 10
    @doc.text "<b>Client</b>", inline_format: true
    @doc.text @booking.full_name
    @doc.text @booking.email
    @doc.text @booking.phone if @booking.phone.present?
    @doc.text @booking.client.address if @booking.client&.address.present?
    @doc.move_down 16
  end

  def stay_block
    @doc.font_size 10
    @doc.text "<b>Séjour</b>", inline_format: true
    @doc.text "Du #{fr_date_full(@booking.check_in)} au #{fr_date_full(@booking.check_out)}"
    @doc.fill_color STONE_500
    @doc.text "#{@booking.weeks} semaine(s) · #{@booking.nights} nuits" + (@booking.guests_count ? " · #{@booking.guests_count} voyageur(s)" : "")
    @doc.fill_color STONE_900
    @doc.move_down 16
  end

  # ---- Facture d'arrhes : une seule ligne. ------------------------------------

  def deposit_breakdown
    ttc = @invoice.amount_cents.to_i
    ht  = ht_for(ttc, vat_rate_accommodation)

    designation = "Arrhes (#{@booking.deposit_percent_label}) pour le séjour du #{fr_date(@booking.check_in)} au #{fr_date(@booking.check_out)}"

    rows = [
      [ "Désignation", "Montant HT", "Quantité", "TVA", "Montant TTC" ],
      [ designation, money(ht), "1", "#{vat_rate_accommodation.to_i} %", money(ttc) ]
    ]
    draw_table(rows)
  end

  def deposit_totals
    ttc = @invoice.amount_cents.to_i
    ht  = ht_for(ttc, vat_rate_accommodation)
    vat = ttc - ht
    draw_totals([
      [ "Total HT",                            money(ht) ],
      [ "TVA (#{vat_rate_accommodation.to_i} %)", money(vat) ]
    ], bottom: [ "Total à payer", money(ttc) ])
  end

  # ---- Facture de solde : décompte complet + déduction arrhes. ----------------

  def balance_breakdown
    rows = [
      [ "Désignation", "Montant HT", "Quantité", "TVA", "Montant TTC" ],
      [ "Hébergement",     money(@booking.accommodation_per_night_ht_cents),  "#{@booking.nights} nuits",    "#{vat_rate_accommodation.to_i} %", money(@booking.accommodation_cents) ],
      [ "Frais de ménage", money(@booking.cleaning_per_week_ht_cents),        "#{@booking.weeks} sem.",      "#{vat_rate_cleaning.to_i} %",      money(@booking.cleaning_fee_cents) ]
    ]

    deposit = @booking.deposit_invoice
    if deposit&.payment_received?
      dep_ttc = deposit.amount_cents.to_i
      dep_ht  = ht_for(dep_ttc, vat_rate_accommodation)
      rows << [ "Déduction arrhes (réf. #{deposit.number})", "-#{money(dep_ht)}", "1", "#{vat_rate_accommodation.to_i} %", "-#{money(dep_ttc)}" ]
    end

    rows << [ "Taxe de séjour", money(@booking.tax_per_person_per_night_ht_cents), "#{@booking.nuitees} nuitées", "#{vat_rate_tourist_tax.to_i} %", money(@booking.tourist_tax_cents) ]
    draw_table(rows)
  end

  def balance_totals
    deposit = @booking.deposit_invoice
    deposit_paid = deposit&.payment_received? ? deposit.amount_cents.to_i : 0
    dep_vat = deposit_paid.zero? ? 0 : (deposit_paid - ht_for(deposit_paid, vat_rate_accommodation))

    acc_vat_full = @booking.vat_cents_for(:accommodation)
    cln_vat      = @booking.vat_cents_for(:cleaning)
    acc_vat_left = acc_vat_full - dep_vat
    ht_left      = (@booking.accommodation_cents.to_i + @booking.cleaning_fee_cents.to_i - deposit_paid) - (acc_vat_left + cln_vat)
    net          = @booking.total_price_cents.to_i - deposit_paid

    lines = [
      [ "Total HT restant (hors taxe de séjour)", money(ht_left) ],
      [ "TVA #{vat_rate_accommodation.to_i} %" + (deposit_paid.positive? ? " restante" : ""), money(acc_vat_left) ],
      [ "TVA #{vat_rate_cleaning.to_i} %",                                                     money(cln_vat) ],
      [ "Taxe de séjour (hors TVA)",                                                            money(@booking.tourist_tax_cents) ]
    ]
    draw_totals(lines, bottom: [ "Net à payer", money(net) ])
  end

  # ---- Helpers de mise en forme. ----------------------------------------------

  def draw_table(rows)
    @doc.table(rows, width: @doc.bounds.width, cell_style: { borders: %i[bottom], border_color: STONE_300, padding: [ 8, 6 ] }) do
      row(0).font_style = :bold
      row(0).background_color = "f5f5f4"
      columns(1..4).align = :right
    end
    @doc.move_down 16
  end

  def draw_totals(lines, bottom:)
    table_width = 260
    rows = lines + [ bottom ]
    @doc.bounding_box([ @doc.bounds.width - table_width, @doc.cursor ], width: table_width) do
      @doc.table(rows, width: table_width, cell_style: { borders: [], padding: [ 4, 8 ], size: 10 }) do
        column(1).align = :right
        row(-1).font_style = :bold
        row(-1).borders = %i[top]
        row(-1).border_color = STONE_500
        row(-1).padding_top = 8
      end
    end
    @doc.move_down 18
  end

  def payment_terms
    @doc.font_size 10
    if @invoice.kind_deposit?
      due = (@invoice.issued_on + DEPOSIT_DUE_DAYS).then { |d| fr_date(d) }
      @doc.text "<b>À régler au plus tard le #{due}</b> par virement bancaire (RIB ci-dessous).", inline_format: true
    else
      due_date = @booking.check_in - BALANCE_DUE_DAYS
      @doc.text "<b>Solde à régler au plus tard le #{fr_date(due_date)}</b> (10 jours avant l'arrivée) par virement bancaire.", inline_format: true
    end
    @doc.move_down 14
  end

  def rib_box
    @doc.stroke_color STONE_300
    @doc.bounding_box([ 0, @doc.cursor ], width: @doc.bounds.width, height: 80) do
      @doc.stroke_bounds
      @doc.indent(10) do
        @doc.move_down 8
        @doc.font_size 10
        @doc.text "<b>Coordonnées bancaires pour le virement</b>", inline_format: true
        @doc.font_size 9
        @doc.text "Titulaire : #{ENV['COMPANY_ACCOUNT_HOLDER']}" if ENV["COMPANY_ACCOUNT_HOLDER"].present?
        @doc.text "IBAN : #{ENV['COMPANY_IBAN']}"               if ENV["COMPANY_IBAN"].present?
        @doc.text "BIC : #{ENV['COMPANY_BIC']}"                 if ENV["COMPANY_BIC"].present?
      end
    end
    @doc.move_down 12
  end

  def legal_mentions
    @doc.font_size 8
    @doc.fill_color STONE_500
    capital = ENV["COMPANY_CAPITAL"]
    @doc.text "Capital social : #{capital}" if capital.present?
    @doc.text "TVA exigible sur les encaissements (art. 269 du CGI). Référence à indiquer en virement : #{@invoice.number}."
    if @invoice.kind_deposit?
      @doc.text "Arrhes (art. 1590 du Code civil) : leur perte par le client, ou leur restitution au double par le propriétaire, libère du contrat."
    end
    @doc.text "En cas de retard de paiement, indemnité forfaitaire pour frais de recouvrement de 40 € (art. L441-10 du Code de commerce) et pénalités égales à trois fois le taux d'intérêt légal."
    @doc.fill_color STONE_900
  end

  # ---- Calculs TVA. -----------------------------------------------------------

  def ht_for(ttc_cents, vat_rate)
    return ttc_cents.to_i if vat_rate.zero?
    (ttc_cents.to_f * 100 / (100 + vat_rate)).round
  end

  def vat_rate_accommodation = Booking::VAT_RATES[:accommodation]
  def vat_rate_cleaning      = Booking::VAT_RATES[:cleaning]
  def vat_rate_tourist_tax   = Booking::VAT_RATES[:tourist_tax]
end
