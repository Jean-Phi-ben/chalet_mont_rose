# Rendu HTML du corps d'une section du contrat (ContractTemplate::Section#body) :
# paragraphes séparés par une ligne vide, puces « • » en liste, sauts de ligne conservés.
module ContractsHelper
  def contract_body_html(body)
    blocks = []
    paragraph = []
    bullets = []

    flush = lambda do
      blocks << tag.p(safe_join(paragraph, tag.br), class: "text-sm leading-relaxed") if paragraph.any?
      blocks << tag.ul(safe_join(bullets.map { |b| tag.li(b) }), class: "text-sm list-disc list-inside space-y-0.5 my-1") if bullets.any?
      paragraph = []
      bullets = []
    end

    body.to_s.split("\n").each do |line|
      stripped = line.strip
      if stripped.empty?
        flush.call
      elsif stripped.start_with?("• ")
        bullets << stripped.delete_prefix("• ")
      else
        flush.call if bullets.any?
        paragraph << stripped
      end
    end
    flush.call
    safe_join(blocks)
  end
end
