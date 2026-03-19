class RemoveActiveStorageFromProbeUploads < ActiveRecord::Migration[8.1]
  def up
    # Add metadata columns to store file info without ActiveStorage
    add_column :probe_uploads, :original_filename, :string
    add_column :probe_uploads, :original_size, :integer

    # Migrate existing data from ActiveStorage blobs
    execute <<-SQL.squish
      UPDATE probe_uploads
      SET original_filename = blobs.filename,
          original_size = blobs.byte_size
      FROM active_storage_attachments AS attachments
      JOIN active_storage_blobs AS blobs ON blobs.id = attachments.blob_id
      WHERE attachments.record_type = 'ProbeUpload'
        AND attachments.record_id = probe_uploads.id
        AND attachments.name = 'zip_file'
    SQL

    # Remove ActiveStorage attachments for ProbeUpload
    execute <<-SQL.squish
      DELETE FROM active_storage_attachments
      WHERE record_type = 'ProbeUpload'
    SQL

    # Clean up orphaned blobs (blobs with no attachments)
    execute <<-SQL.squish
      DELETE FROM active_storage_blobs
      WHERE id NOT IN (SELECT blob_id FROM active_storage_attachments)
    SQL
  end

  def down
    # Note: Cannot restore ActiveStorage files - they are deleted
    remove_column :probe_uploads, :original_filename
    remove_column :probe_uploads, :original_size
  end
end
