class AddTokensPerSecondToTargets < ActiveRecord::Migration[8.0]
  def change
    add_column :targets, :tokens_per_second, :decimal, precision: 10, scale: 2
    add_column :targets, :tokens_per_second_sample_count, :integer, default: 0, null: false
  end
end
