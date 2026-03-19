class AddInputTokensToProbes < ActiveRecord::Migration[8.1]
  def up
    add_column :probes, :input_tokens, :integer, default: 0, null: false

    # Backfill existing probes from their stored prompts
    Probe.reset_column_information
    Probe.find_each do |probe|
      prompts = probe.prompts || []
      tokens = prompts.sum { |p| TokenEstimator.estimate_tokens(p) }
      probe.update_column(:input_tokens, tokens)
    end
  end

  def down
    remove_column :probes, :input_tokens
  end
end
