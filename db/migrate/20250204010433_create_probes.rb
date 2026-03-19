class CreateProbes < ActiveRecord::Migration[8.0]
  def change
    create_table :probes do |t|
      t.string :name
      t.string :category
      t.string :tag
      t.string :detector
      t.text :description

      t.timestamps
    end
  end
end
