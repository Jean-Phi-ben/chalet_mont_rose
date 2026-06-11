require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "kind must be unique" do
    Document.create!(kind: :cgu, title: "CGU 2026")
    dup = Document.new(kind: :cgu, title: "Autre")
    assert_not dup.save
  end

  test "kind_label returns the humanized label" do
    cgu = Document.new(kind: :cgu, title: "x")
    livret = Document.new(kind: :livret, title: "x")
    assert_equal "Conditions générales", cgu.kind_label
    assert_equal "Livret du chalet", livret.kind_label
  end
end
