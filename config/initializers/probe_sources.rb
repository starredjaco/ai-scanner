Rails.application.config.to_prepare do
  ProbeSourceRegistry.register(GarakCommunityProbeSource)
  ProbeSourceRegistry.register(OdinProbeSource)
end
