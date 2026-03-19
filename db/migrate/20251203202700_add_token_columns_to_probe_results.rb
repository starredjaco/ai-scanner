# frozen_string_literal: true

class AddTokenColumnsToProbeResults < ActiveRecord::Migration[8.0]
  def change
    add_column :probe_results, :input_tokens, :integer, default: 0, null: false
    add_column :probe_results, :output_tokens, :integer, default: 0, null: false
  end
end
