# frozen_string_literal: true

# Remove the claimable index that was added for FOR UPDATE SKIP LOCKED pattern.
# This pattern is no longer needed since Solid Queue's limits_concurrency
# handles job uniqueness at the job level.
class RemoveClaimableIndexFromRawReportData < ActiveRecord::Migration[8.1]
  def change
    remove_index :raw_report_data, name: "index_raw_report_data_claimable"
  end
end
