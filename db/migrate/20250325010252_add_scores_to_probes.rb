class AddScoresToProbes < ActiveRecord::Migration[8.0]
  def change
    add_column :probes, :scores, :json, default: {}
  end
end
