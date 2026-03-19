class CreateProbeResults < ActiveRecord::Migration[8.0]
  def up
    create_table :probe_results do |t|
      t.references :report, null: false, foreign_key: true
      t.references :probe, null: false, foreign_key: true
      t.json :attempts, default: []
      t.integer :max_score
      t.integer :passed, default: 0
      t.integer :total, default: 0
      t.string :detector, null: false
      t.timestamps
    end

    add_index :probe_results, [ :report_id, :probe_id ], unique: true, name: "index_probe_results_on_report_id_and_probe_id"

    Report.find_in_batches(batch_size: 10) do |reports|
      reports.each do |report|
        report.report_data.to_h.each do |name, data|
          ProbeResult.create!(
            report: report,
            probe: Probe.find_by!(name: name.split(".").last),
            attempts: data["attempts"] || [],
            max_score: data.dig("stats", "max_score"),
            passed: data.dig("eval", "passed") || 0,
            total: data.dig("eval", "total") || 0,
            detector: data.dig("eval", "detector"),
            created_at: report.created_at,
            updated_at: report.updated_at
          )
        end
      end
    end

    remove_column :reports, :report_data
  end

  def down
    drop_table :probe_results
    add_column :reports, :report_data, :json, default: {}
  end
end
