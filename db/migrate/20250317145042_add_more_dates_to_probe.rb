class AddMoreDatesToProbe < ActiveRecord::Migration[8.0]
  def change
    add_column :probes, :release_date, :datetime
    add_column :probes, :modified_date, :datetime
  end
end
