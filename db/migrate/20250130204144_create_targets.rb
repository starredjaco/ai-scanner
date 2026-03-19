class CreateTargets < ActiveRecord::Migration[8.0]
  def change
    create_table :targets do |t|
      t.string :name, null: false
      t.string :model_type, null: false
      t.string :model, null: false
      t.string :endpoint_url
      t.text :description

      t.timestamps
    end
    add_index :targets, :name, unique: true
  end
end
