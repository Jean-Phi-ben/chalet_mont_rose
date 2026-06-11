class CreateNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :notes do |t|
      t.string   :title,    null: false
      t.text     :body
      t.boolean  :done,     null: false, default: false
      t.date     :deadline
      t.datetime :archived_at

      t.timestamps
    end

    add_index :notes, :archived_at
    add_index :notes, :deadline
  end
end
