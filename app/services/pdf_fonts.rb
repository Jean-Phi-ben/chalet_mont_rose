# Police TrueType embarquée pour les PDF (factures, contrat) : les polices AFM
# de base de Prawn ne couvrent que Windows-1252 et plantent sur un nom comme
# « Łukasz » ou « Øyvind ». DejaVu Sans (vendor/fonts, licence Bitstream/DejaVu)
# couvre latin étendu, grec, cyrillique et le symbole €.
module PdfFonts
  FAMILY = "DejaVu".freeze
  DIR    = Rails.root.join("vendor/fonts")

  def self.register(doc)
    doc.font_families.update(
      FAMILY => {
        normal: DIR.join("DejaVuSans.ttf").to_s,
        bold:   DIR.join("DejaVuSans-Bold.ttf").to_s
      }
    )
    doc.font FAMILY
  end
end
