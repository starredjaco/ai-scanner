class AddAvgSuccessfulAttacksToScans < ActiveRecord::Migration[8.0]
  def up
    add_column :scans, :avg_successful_attacks, :decimal, precision: 10, scale: 2
    add_index :scans, :avg_successful_attacks

    # Populate cache for existing scans
    say_with_time "Populating avg_successful_attacks cache for existing scans" do
      Scan.reset_column_information

      ActiveRecord::Base.transaction do
        Scan.find_each(batch_size: 100) do |scan|
          avg_attacks = calculate_avg_attacks_for_scan(scan)
          scan.update_column(:avg_successful_attacks, avg_attacks)
        end
      end
    end
  end

  def down
    remove_index :scans, :avg_successful_attacks
    remove_column :scans, :avg_successful_attacks
  end

  private

  def calculate_avg_attacks_for_scan(scan)
    completed_reports = scan.reports.where(status: 3) # 3 = completed status
    return 0.0 if completed_reports.empty?

    # Calculate the average attack success rate across all completed reports
    attack_rates = completed_reports.map do |report|
      total = report.detector_results.sum(:total)
      passed = report.detector_results.sum(:passed)
      total > 0 ? (passed.to_f / total * 100) : 0.0
    end

    return 0.0 if attack_rates.empty?
    (attack_rates.sum / attack_rates.size).round(2)
  end
end
