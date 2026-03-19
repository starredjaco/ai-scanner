# Ensure Active Storage directory exists
Rails.application.config.after_initialize do
  storage_path = Rails.root.join("storage", "attached_files")
  FileUtils.mkdir_p(storage_path) unless Dir.exist?(storage_path)
end
