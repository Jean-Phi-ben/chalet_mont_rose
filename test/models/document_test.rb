require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  def pdf_document(kind:, title:, content_type: "application/pdf", size: 10)
    header = content_type == "application/pdf" ? "%PDF-1.4 " : "\x89PNG\r\n"
    Document.new(kind: kind, title: title).tap do |d|
      d.file.attach(io: StringIO.new(header + ("x" * size)), filename: "doc.pdf", content_type: content_type)
    end
  end

  test "kind must be unique" do
    pdf_document(kind: :cgu, title: "CGL 2026").save!
    dup = pdf_document(kind: :cgu, title: "Autre")
    assert_not dup.save
  end

  test "kind_label returns the humanized label" do
    assert_equal "Conditions générales de location", Document.new(kind: :cgu, title: "x").kind_label
    assert_equal "Livret du chalet", Document.new(kind: :livret, title: "x").kind_label
  end

  test "requires an attached PDF of reasonable size" do
    assert_not Document.new(kind: :livret, title: "Sans fichier").valid?
    assert_not pdf_document(kind: :livret, title: "Image", content_type: "image/png").valid?
    assert pdf_document(kind: :livret, title: "OK").valid?
  end
end
