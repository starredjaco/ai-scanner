class ChangeParentChildReportRelationship < ActiveRecord::Migration[8.1]
  def up
    # Find parent reports with multiple child reports and clean them up
    say "Cleaning up parent reports with multiple child reports..."

    # Use raw SQL to find parents with multiple children efficiently
    parents_with_multiple_children = connection.execute(<<~SQL)
      SELECT parent_report_id, COUNT(*) as child_count
      FROM reports
      WHERE parent_report_id IS NOT NULL
      GROUP BY parent_report_id
      HAVING COUNT(*) > 1
    SQL

    cleanup_count = 0
    parents_with_multiple_children.each do |row|
      parent_id = row['parent_report_id']

      # Get child report IDs with raw SQL to avoid model issues
      child_reports_data = connection.execute(<<~SQL)
        SELECT id, created_at
        FROM reports
        WHERE parent_report_id = #{parent_id}
        ORDER BY created_at DESC
      SQL

      child_ids = child_reports_data.map { |child| child['id'] }

      if child_ids.size > 1
        most_recent_id = child_ids.first
        ids_to_delete = child_ids[1..]

        say "Parent #{parent_id}: keeping most recent child (#{most_recent_id}), deleting #{ids_to_delete.size} older children (IDs: #{ids_to_delete.join(', ')})"

        # Delete dependent records first, then the reports
        ids_to_delete.each do |report_id|
          # Delete probe results
          connection.execute("DELETE FROM probe_results WHERE report_id = #{report_id}")

          # Delete detector results
          connection.execute("DELETE FROM detector_results WHERE report_id = #{report_id}")

          # Delete report variant probes
          connection.execute("DELETE FROM report_variant_probes WHERE report_id = #{report_id}")

          # Finally delete the report
          connection.execute("DELETE FROM reports WHERE id = #{report_id}")
        end

        cleanup_count += ids_to_delete.size
      end
    end

    say "Cleaned up #{cleanup_count} duplicate child reports"

    # Add unique constraint to prevent multiple children per parent in the future
    say "Adding unique constraint to enforce has_one relationship..."
    add_index :reports, :parent_report_id, unique: true, where: "parent_report_id IS NOT NULL", name: "index_reports_on_unique_parent_report_id"

    say "Migration completed successfully!"
  end

  def down
    # Remove the unique constraint
    remove_index :reports, name: "index_reports_on_unique_parent_report_id"
    say "Removed unique constraint. Note: This doesn't restore deleted child reports."
  end
end
