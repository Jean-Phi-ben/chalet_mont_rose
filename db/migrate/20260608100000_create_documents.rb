class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.integer :kind, null: false   # 0 = cgu, 1 = livret
      t.string  :title, null: false
      t.timestamps
    end
    add_index :documents, :kind, unique: true
  end
end
