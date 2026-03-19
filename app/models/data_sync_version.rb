class DataSyncVersion < ApplicationRecord
  validates :sync_type, presence: true
  validates :file_path, presence: true
  validates :file_checksum, presence: true

  scope :for_type, ->(type) { where(sync_type: type) }

  def self.latest_for_type(type)
    for_type(type).order(created_at: :desc).first
  end

  def self.needs_sync?(sync_type, file_path)
    return true unless table_exists?

    current_checksum = calculate_checksum(file_path)
    return false if current_checksum.nil? # File doesn't exist, nothing to sync

    latest_version = latest_for_type(sync_type)

    latest_version.nil? || latest_version.file_checksum != current_checksum
  rescue ActiveRecord::StatementInvalid
    # Table doesn't exist yet, sync is needed
    true
  end

  def self.record_sync(sync_type, file_path, record_count, metadata = {})
    checksum = calculate_checksum(file_path)

    existing = find_by(sync_type: sync_type, file_checksum: checksum)
    if existing
      existing.update!(record_count: record_count, synced_at: Time.current, metadata: metadata)
      existing
    else
      create!(
        sync_type: sync_type,
        file_path: file_path,
        file_checksum: checksum,
        record_count: record_count,
        synced_at: Time.current,
        metadata: metadata
      )
    end
  end

  private

  def self.calculate_checksum(file_path)
    full_path = Rails.root.join(file_path)
    return nil unless File.exist?(full_path)
    Digest::SHA256.file(full_path).hexdigest
  end
end
