module ProbeOssDefaults
  extend ActiveSupport::Concern

  # OSS stubs for methods the engine overrides with richer implementations.
  # Defined in a module (not the class body) so the engine's probe extension
  # can override them via include (Ruby MRO: last included module wins).

  def short_guid
    guid.present? ? "0x#{guid.split('-').first.upcase}" : "N/A"
  end

  def successful_targets_last_90_days
    []
  end
end
