namespace :probes do
  desc "Extract community probe metadata from installed garak package"
  task extract_community: :environment do
    script_path = Rails.root.join("script", "extract_community_probes.py")
    output_path = Rails.root.join("config", "probes", "community_probes.json")

    unless system("python3", "--version", out: File::NULL, err: File::NULL)
      Rails.logger.warn "python3 not found, skipping community probe extraction"
      next
    end

    puts "Extracting community probes from garak..."
    success = system("python3", script_path.to_s, output_path.to_s)

    if success
      puts "Community probes extracted successfully"
    else
      Rails.logger.warn "Community probe extraction failed (garak may not be installed)"
    end
  end
end
