class CreateDetectorResults < ActiveRecord::Migration[8.0]
  def change
    create_table :detectors do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :detectors, :name, unique: true

    create_table :detector_results do |t|
      t.references :detector, null: false, foreign_key: true
      t.references :report, null: false, foreign_key: true, index: true
      t.integer :passed
      t.integer :total
      t.integer :max_score
    end
    add_index :detector_results, [ :detector_id, :report_id ], unique: true

    add_column :reports, :start_time, :datetime
    add_column :reports, :end_time, :datetime

    add_reference :probe_results, :detector, foreign_key: true, index: true
    add_reference :probes, :detector, foreign_key: true, index: true

    Report.find_each do |report|
      next unless report.stats.present?

      if report.stats["detectors"].present?
        report.stats["detectors"].each do |detector_name, data|
          detector = Detector.find_or_create_by(name: detector_name)
          DetectorResult.create!(
            detector: detector,
            report: report,
            passed: data["passed"],
            total: data["total"],
            max_score: data["max_score"]
          )
        end
      end

      report.start_time = Time.parse(report.stats["start_time"]) rescue nil if report.stats["start_time"].present?
      report.end_time = Time.parse(report.stats["end_time"]) rescue nil if report.stats["end_time"].present?
      report.save! if report.changed?
    end

    execute <<-SQL
      UPDATE probe_results
      SET detector_id = (
        SELECT id FROM detectors
        WHERE name = probe_results.detector
      )
      WHERE detector IS NOT NULL
    SQL

    execute <<-SQL
      UPDATE probes
      SET detector_id = (
        SELECT id FROM detectors
        WHERE name = probes.detector
      )
      WHERE detector IS NOT NULL
    SQL

    remove_column :reports, :stats
    remove_column :probe_results, :detector
    remove_column :probes, :detector
  end
end
