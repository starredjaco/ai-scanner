class AddProbesToProbe < ActiveRecord::Migration[8.0]
  def change
    add_column :probes, :prompts, :jsonb, default: []
  end
end
