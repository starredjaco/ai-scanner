module ScanVariantDefaults
  extend ActiveSupport::Concern

  def has_threat_variants?
    false
  end
end
