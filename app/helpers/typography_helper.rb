# Typographie française : espaces insécables et accords.
module TypographyHelper
  NBSP = " ".freeze

  # Espace insécable avant « : ; ? ! » et dans « 30 % », « 260 m² ».
  def nbsp_punct(text)
    text.to_s
        .gsub(/ ([:;?!])/, "#{NBSP}\\1")
        .gsub(/(\d) (%|m²|€)/, "\\1#{NBSP}\\2")
  end

  # « 1 nuit », « 2 nuits ». Pluriel régulier par défaut.
  def fr_plural(count, singular, plural = "#{singular}s")
    "#{count} #{count.to_i > 1 ? plural : singular}"
  end
end
