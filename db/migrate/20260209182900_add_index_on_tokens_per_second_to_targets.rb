class AddIndexOnTokensPerSecondToTargets < ActiveRecord::Migration[8.1]
  def change
    add_index :targets, :tokens_per_second,
              where: "tokens_per_second IS NOT NULL",
              name: "index_targets_on_tokens_per_second"
  end
end
